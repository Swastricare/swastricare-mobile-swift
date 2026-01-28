//
//  LocationTrackingService.swift
//  swastricare-mobile-swift
//
//  GPS Location Tracking Service with Background Support
//  Production-ready implementation for fitness activity tracking
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Point Model

/// Represents a single GPS location point with all relevant metadata
struct LocationPoint: Codable, Equatable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double // meters per second
    let course: Double // degrees from north
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var speedKmh: Double {
        speed * 3.6 // Convert m/s to km/h
    }
    
    var isValid: Bool {
        // Filter out invalid readings
        horizontalAccuracy >= 0 &&
        horizontalAccuracy <= 50 && // Only accept readings within 50m accuracy
        speed >= 0 &&
        latitude != 0 && longitude != 0
    }
    
    init(from location: CLLocation) {
        self.id = UUID()
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.speed = max(location.speed, 0) // CLLocation returns -1 when speed is invalid
        self.course = location.course >= 0 ? location.course : 0
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
    }
    
    // For testing/mock data
    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        timestamp: Date = Date(),
        speed: Double = 0,
        course: Double = 0,
        horizontalAccuracy: Double = 5,
        verticalAccuracy: Double = 5
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
    }
}

// MARK: - Location Authorization Status

enum LocationAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
    
    var canTrack: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
    
    var canTrackInBackground: Bool {
        self == .authorizedAlways
    }
    
    init(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .notDetermined
        }
    }
}

// MARK: - Location Tracking Error

enum LocationTrackingError: LocalizedError {
    case notAuthorized
    case restricted
    case servicesDisabled
    case accuracyInsufficient
    case backgroundNotAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access not authorized. Please enable in Settings."
        case .restricted:
            return "Location services are restricted on this device."
        case .servicesDisabled:
            return "Location services are disabled. Please enable in Settings."
        case .accuracyInsufficient:
            return "Unable to get accurate location. Please move to an area with better GPS signal."
        case .backgroundNotAuthorized:
            return "Background location access required for continuous tracking. Please enable 'Always' access in Settings."
        }
    }
}

// MARK: - Location Tracking Service Protocol

protocol LocationTrackingServiceProtocol: AnyObject {
    var authorizationStatus: LocationAuthorizationStatus { get }
    var isTracking: Bool { get }
    var locationPoints: [LocationPoint] { get }
    var currentLocation: LocationPoint? { get }
    
    // Publishers
    var locationPublisher: AnyPublisher<LocationPoint, Never> { get }
    var authorizationPublisher: AnyPublisher<LocationAuthorizationStatus, Never> { get }
    var errorPublisher: AnyPublisher<LocationTrackingError, Never> { get }
    
    func requestAuthorization() async throws
    func requestAlwaysAuthorization() async throws
    func startTracking() throws
    func stopTracking()
    func pauseTracking()
    func resumeTracking()
    func resetTracking()
    func getCurrentLocation() async throws -> LocationPoint
    func getLocationPoints() -> [LocationPoint]
    func getValidLocationPoints() -> [LocationPoint]
}

// MARK: - Location Tracking Service Implementation

final class LocationTrackingService: NSObject, LocationTrackingServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = LocationTrackingService()
    
    // MARK: - Properties
    
    private let locationManager: CLLocationManager
    internal var locationPoints: [LocationPoint] = []
    private(set) var currentLocation: LocationPoint?
    private(set) var isTracking = false
    private var isPaused = false
    
    // Publishers
    private let locationSubject = PassthroughSubject<LocationPoint, Never>()
    private let authorizationSubject = CurrentValueSubject<LocationAuthorizationStatus, Never>(.notDetermined)
    private let errorSubject = PassthroughSubject<LocationTrackingError, Never>()
    
    var locationPublisher: AnyPublisher<LocationPoint, Never> {
        locationSubject.eraseToAnyPublisher()
    }
    
    var authorizationPublisher: AnyPublisher<LocationAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<LocationTrackingError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatus: LocationAuthorizationStatus {
        authorizationSubject.value
    }
    
    // Continuation for async authorization requests
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<LocationPoint, Error>?
    
    // MARK: - Initialization
    
    override private init() {
        locationManager = CLLocationManager()
        super.init()
        
        locationManager.delegate = self
        
        // Configure for fitness tracking - balance accuracy and battery
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.activityType = .fitness
        
        // Note: Background location updates are enabled when starting tracking
        // after verifying authorization status
        
        // Initial authorization status
        updateAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationTrackingError.servicesDisabled
        }
        
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                self.authorizationContinuation = continuation
                self.locationManager.requestWhenInUseAuthorization()
            }
            
        case .restricted:
            throw LocationTrackingError.restricted
            
        case .denied:
            throw LocationTrackingError.notAuthorized
            
        case .authorizedWhenInUse, .authorizedAlways:
            return // Already authorized
            
        @unknown default:
            throw LocationTrackingError.notAuthorized
        }
    }
    
    func requestAlwaysAuthorization() async throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationTrackingError.servicesDisabled
        }
        
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .authorizedAlways:
            return // Already have always authorization
            
        case .authorizedWhenInUse:
            return try await withCheckedThrowingContinuation { continuation in
                self.authorizationContinuation = continuation
                self.locationManager.requestAlwaysAuthorization()
            }
            
        case .notDetermined:
            // First request when in use, then always
            try await requestAuthorization()
            try await requestAlwaysAuthorization()
            
        case .restricted:
            throw LocationTrackingError.restricted
            
        case .denied:
            throw LocationTrackingError.notAuthorized
            
        @unknown default:
            throw LocationTrackingError.notAuthorized
        }
    }
    
    // MARK: - Tracking Control
    
    func startTracking() throws {
        guard authorizationStatus.canTrack else {
            throw LocationTrackingError.notAuthorized
        }
        
        guard !isTracking else { return }
        
        isTracking = true
        isPaused = false
        locationPoints = []
        
        // Enable background location updates if authorized
        // This must be done before starting updates to avoid crash
        configureBackgroundLocationIfNeeded()
        
        locationManager.startUpdatingLocation()
        
        print("📍 Location tracking started")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        locationManager.stopUpdatingLocation()
        
        // Disable background updates when not tracking
        locationManager.allowsBackgroundLocationUpdates = false
        
        isTracking = false
        isPaused = false
        
        print("📍 Location tracking stopped - \(locationPoints.count) points recorded")
    }
    
    func pauseTracking() {
        guard isTracking && !isPaused else { return }
        
        isPaused = true
        // We don't stop location updates, just stop recording
        
        print("📍 Location tracking paused")
    }
    
    func resumeTracking() {
        guard isTracking && isPaused else { return }
        
        isPaused = false
        
        print("📍 Location tracking resumed")
    }
    
    func resetTracking() {
        stopTracking()
        locationPoints = []
        currentLocation = nil
    }
    
    // MARK: - Single Location Request
    
    func getCurrentLocation() async throws -> LocationPoint {
        guard authorizationStatus.canTrack else {
            throw LocationTrackingError.notAuthorized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager.requestLocation()
        }
    }
    
    // MARK: - Data Access
    
    func getLocationPoints() -> [LocationPoint] {
        return locationPoints
    }
    
    func getValidLocationPoints() -> [LocationPoint] {
        return locationPoints.filter { $0.isValid }
    }
    
    // MARK: - Private Helpers
    
    private func updateAuthorizationStatus() {
        let status = LocationAuthorizationStatus(from: locationManager.authorizationStatus)
        authorizationSubject.send(status)
    }
    
    private func processLocation(_ location: CLLocation) {
        let point = LocationPoint(from: location)
        
        // Update current location
        currentLocation = point
        
        // Only record if tracking and not paused
        if isTracking && !isPaused {
            // Apply Kalman-like filtering - only add if significantly different
            if shouldRecordPoint(point) {
                locationPoints.append(point)
                locationSubject.send(point)
            }
        }
    }
    
    private func shouldRecordPoint(_ newPoint: LocationPoint) -> Bool {
        guard let lastPoint = locationPoints.last else {
            return true // Always record first point
        }
        
        // Skip if accuracy is too poor
        guard newPoint.horizontalAccuracy <= 50 else {
            return false
        }
        
        // Skip if time difference is too small (prevent duplicate points)
        let timeDiff = newPoint.timestamp.timeIntervalSince(lastPoint.timestamp)
        guard timeDiff >= 0.5 else {
            return false
        }
        
        // Calculate distance from last point
        let lastLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
        let newLocation = CLLocation(latitude: newPoint.latitude, longitude: newPoint.longitude)
        let distance = newLocation.distance(from: lastLocation)
        
        // Record if moved at least 2 meters or 5 seconds have passed
        return distance >= 2 || timeDiff >= 5
    }
    
    /// Configures background location updates if the app has the capability and proper authorization
    private func configureBackgroundLocationIfNeeded() {
        // Check if the app bundle has background location mode enabled
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
              backgroundModes.contains("location") else {
            print("📍 Background location mode not enabled in Info.plist")
            return
        }
        
        // Only enable background updates if we have always authorization or when in use
        // Note: On iOS, allowsBackgroundLocationUpdates can be set with When In Use authorization
        // as long as the app has the background location capability
        if authorizationStatus.canTrack {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.showsBackgroundLocationIndicator = true
            print("📍 Background location updates enabled")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorizationStatus()
        
        let status = authorizationStatus
        
        // Resume authorization continuation if waiting
        if let continuation = authorizationContinuation {
            authorizationContinuation = nil
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                continuation.resume()
            case .denied:
                continuation.resume(throwing: LocationTrackingError.notAuthorized)
            case .restricted:
                continuation.resume(throwing: LocationTrackingError.restricted)
            case .notDetermined:
                break // Still waiting
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle single location request
        if let continuation = locationContinuation, let location = locations.last {
            locationContinuation = nil
            let point = LocationPoint(from: location)
            continuation.resume(returning: point)
            return
        }
        
        // Process all locations for tracking
        for location in locations {
            processLocation(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
        
        // Handle single location request failure
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: LocationTrackingError.accuracyInsufficient)
        }
        
        // Emit error
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorSubject.send(.notAuthorized)
            case .locationUnknown:
                errorSubject.send(.accuracyInsufficient)
            default:
                errorSubject.send(.accuracyInsufficient)
            }
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("📍 Location updates paused by system")
        // The system paused updates - this shouldn't happen with pausesLocationUpdatesAutomatically = false
        // but if it does, we should resume
        if isTracking && !isPaused {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("📍 Location updates resumed")
    }
}

// MARK: - Distance Calculation Extension

extension Array where Element == LocationPoint {
    
    /// Calculate total distance in meters
    func totalDistance() -> Double {
        guard count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        
        for i in 1..<count {
            let previous = CLLocation(latitude: self[i-1].latitude, longitude: self[i-1].longitude)
            let current = CLLocation(latitude: self[i].latitude, longitude: self[i].longitude)
            totalDistance += current.distance(from: previous)
        }
        
        return totalDistance
    }
    
    /// Calculate total elevation gain in meters
    func totalElevationGain() -> Double {
        guard count > 1 else { return 0 }
        
        var totalGain: Double = 0
        
        for i in 1..<count {
            let elevationDiff = self[i].altitude - self[i-1].altitude
            if elevationDiff > 0 {
                totalGain += elevationDiff
            }
        }
        
        return totalGain
    }
    
    /// Calculate average speed in m/s
    func averageSpeed() -> Double {
        guard !isEmpty else { return 0 }
        
        let validSpeeds = filter { $0.speed > 0 }.map { $0.speed }
        guard !validSpeeds.isEmpty else { return 0 }
        
        return validSpeeds.reduce(0, +) / Double(validSpeeds.count)
    }
    
    /// Get bounding region for the route
    func boundingRegion(padding: Double = 1.2) -> (center: CLLocationCoordinate2D, span: (lat: Double, lon: Double))? {
        guard !isEmpty else { return nil }
        
        let lats = map { $0.latitude }
        let lons = map { $0.longitude }
        
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else { return nil }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let latSpan = (maxLat - minLat) * padding
        let lonSpan = (maxLon - minLon) * padding
        
        return (center, (Swift.max(latSpan, 0.005), Swift.max(lonSpan, 0.005)))
    }
}
