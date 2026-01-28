//
//  WorkoutSessionManager.swift
//  swastricare-mobile-swift
//
//  HealthKit Workout Session Manager
//  Manages workout sessions with proper data collection and saving
//

import Foundation
import HealthKit
import CoreLocation
import Combine

// MARK: - Workout Activity Type

enum WorkoutActivityType: String, CaseIterable, Identifiable, Codable {
    case walking = "Walking"
    case running = "Running"
    case cycling = "Cycling"
    case hiking = "Hiking"
    
    var id: String { rawValue }
    
    var hkWorkoutType: HKWorkoutActivityType {
        switch self {
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .hiking: return .hiking
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        }
    }
    
    var locationType: HKWorkoutSessionLocationType {
        .outdoor
    }
    
    var metValue: Double {
        // MET values for calorie calculation
        switch self {
        case .walking: return 3.5
        case .running: return 8.0
        case .cycling: return 7.5
        case .hiking: return 6.0
        }
    }
}

// MARK: - Workout Session State

enum WorkoutSessionState: Equatable {
    case notStarted
    case active
    case paused
    case completed
    case failed(String)
    
    var isActive: Bool {
        self == .active || self == .paused
    }
    
    var displayText: String {
        switch self {
        case .notStarted: return "Ready"
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed(let error): return "Error: \(error)"
        }
    }
}

// MARK: - Workout Summary

struct WorkoutSummary: Identifiable, Equatable {
    let id: UUID
    let activityType: WorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalDistance: Double // meters
    let totalEnergyBurned: Double // kcal
    let totalElevationGain: Double // meters
    let averagePace: Double // seconds per km
    let averageSpeed: Double // m/s
    let routePoints: [LocationPoint]
    let heartRateSamples: [HeartRateSample]
    
    var distanceKm: Double {
        totalDistance / 1000.0
    }
    
    var formattedDistance: String {
        String(format: "%.2f km", distanceKm)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedPace: String {
        guard averagePace > 0 && averagePace < 3600 else { return "--:--" }
        let minutes = Int(averagePace) / 60
        let seconds = Int(averagePace) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
    
    var formattedCalories: String {
        String(format: "%.0f kcal", totalEnergyBurned)
    }
    
    var averageHeartRate: Int? {
        guard !heartRateSamples.isEmpty else { return nil }
        let total = heartRateSamples.reduce(0) { $0 + $1.bpm }
        return total / heartRateSamples.count
    }
    
    var maxHeartRate: Int? {
        heartRateSamples.map { $0.bpm }.max()
    }
}

// MARK: - Heart Rate Sample

struct HeartRateSample: Codable, Equatable {
    let bpm: Int
    let timestamp: Date
}

// MARK: - Workout Session Manager Protocol

protocol WorkoutSessionManagerProtocol: AnyObject {
    var state: WorkoutSessionState { get }
    var currentActivityType: WorkoutActivityType? { get }
    var startTime: Date? { get }
    var elapsedTime: TimeInterval { get }
    var totalDistance: Double { get }
    var currentPace: Double { get }
    var averagePace: Double { get }
    var currentSpeed: Double { get }
    var caloriesBurned: Double { get }
    var elevationGain: Double { get }
    var routePoints: [LocationPoint] { get }
    
    // Publishers
    var statePublisher: AnyPublisher<WorkoutSessionState, Never> { get }
    var metricsPublisher: AnyPublisher<WorkoutMetrics, Never> { get }
    
    func startWorkout(activityType: WorkoutActivityType) async throws
    func pauseWorkout()
    func resumeWorkout()
    func endWorkout() async throws -> WorkoutSummary
    func discardWorkout()
}

// MARK: - Workout Metrics

struct WorkoutMetrics: Equatable {
    let elapsedTime: TimeInterval
    let totalDistance: Double // meters
    let currentPace: Double // seconds per km
    let averagePace: Double // seconds per km
    let currentSpeed: Double // m/s
    let calories: Double // kcal
    let elevationGain: Double // meters
    let currentHeartRate: Int?
    
    static let zero = WorkoutMetrics(
        elapsedTime: 0,
        totalDistance: 0,
        currentPace: 0,
        averagePace: 0,
        currentSpeed: 0,
        calories: 0,
        elevationGain: 0,
        currentHeartRate: nil
    )
}

// MARK: - Workout Session Manager Implementation

final class WorkoutSessionManager: NSObject, WorkoutSessionManagerProtocol {
    
    // MARK: - Singleton
    
    static let shared = WorkoutSessionManager()
    
    // MARK: - Dependencies
    
    private let healthStore = HKHealthStore()
    private let locationService: LocationTrackingServiceProtocol
    
    // MARK: - State
    
    private(set) var state: WorkoutSessionState = .notStarted
    private(set) var currentActivityType: WorkoutActivityType?
    private(set) var startTime: Date?
    private var pausedTime: TimeInterval = 0
    private var pauseStartTime: Date?
    private var heartRateSamples: [HeartRateSample] = []
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var workoutBuilder: HKWorkoutBuilder?
    
    // Timer
    private var timer: Timer?
    
    // Publishers
    private let stateSubject = CurrentValueSubject<WorkoutSessionState, Never>(.notStarted)
    private let metricsSubject = CurrentValueSubject<WorkoutMetrics, Never>(.zero)
    private var cancellables = Set<AnyCancellable>()
    
    var statePublisher: AnyPublisher<WorkoutSessionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var metricsPublisher: AnyPublisher<WorkoutMetrics, Never> {
        metricsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    
    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        
        if state == .paused, let pauseStart = pauseStartTime {
            return pauseStart.timeIntervalSince(start) - pausedTime
        }
        
        return Date().timeIntervalSince(start) - pausedTime
    }
    
    var totalDistance: Double {
        locationService.locationPoints.totalDistance()
    }
    
    var currentPace: Double {
        // Pace in seconds per km based on current speed
        guard let lastPoint = locationService.currentLocation,
              lastPoint.speed > 0.5 else { return 0 }
        
        return 1000.0 / lastPoint.speed // Convert m/s to sec/km
    }
    
    var averagePace: Double {
        guard totalDistance > 0 && elapsedTime > 0 else { return 0 }
        return elapsedTime / (totalDistance / 1000.0) // sec/km
    }
    
    var currentSpeed: Double {
        locationService.currentLocation?.speed ?? 0
    }
    
    var caloriesBurned: Double {
        guard let activityType = currentActivityType else { return 0 }
        
        // MET-based calorie calculation
        // Calories = MET × weight (kg) × duration (hours)
        // Using average weight of 70kg as fallback
        let weightKg: Double = 70
        let durationHours = elapsedTime / 3600.0
        
        return activityType.metValue * weightKg * durationHours
    }
    
    var elevationGain: Double {
        locationService.locationPoints.totalElevationGain()
    }
    
    var routePoints: [LocationPoint] {
        locationService.locationPoints
    }
    
    // MARK: - Initialization
    
    private override init() {
        self.locationService = LocationTrackingService.shared
        super.init()
        setupBindings()
    }
    
    // For testing with mock location service
    init(locationService: LocationTrackingServiceProtocol) {
        self.locationService = locationService
        super.init()
        setupBindings()
    }
    
    private func setupBindings() {
        // Update metrics when location changes
        locationService.locationPublisher
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Workout Control
    
    func startWorkout(activityType: WorkoutActivityType) async throws {
        guard state == .notStarted || state == .completed else {
            throw WorkoutError.alreadyActive
        }
        
        // Request HealthKit authorization
        try await requestHealthKitAuthorization()
        
        // Request location authorization
        try await locationService.requestAuthorization()
        
        // Reset state
        resetState()
        
        // Set activity type
        currentActivityType = activityType
        
        // Create workout builder
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType.hkWorkoutType
        configuration.locationType = activityType.locationType
        
        workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        // Create route builder
        routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
        
        // Start collecting data
        try await workoutBuilder?.beginCollection(at: Date())
        
        // Start location tracking
        try locationService.startTracking()
        
        // Start timer
        startTimer()
        
        // Update state
        startTime = Date()
        updateState(.active)
        
        print("🏃 Workout started: \(activityType.rawValue)")
    }
    
    func pauseWorkout() {
        guard state == .active else { return }
        
        pauseStartTime = Date()
        locationService.pauseTracking()
        timer?.invalidate()
        
        updateState(.paused)
        
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        guard state == .paused else { return }
        
        // Calculate paused duration
        if let pauseStart = pauseStartTime {
            pausedTime += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        
        locationService.resumeTracking()
        startTimer()
        
        updateState(.active)
        
        print("▶️ Workout resumed")
    }
    
    func endWorkout() async throws -> WorkoutSummary {
        guard state.isActive else {
            throw WorkoutError.notActive
        }
        
        let endDate = Date()
        
        // Stop location tracking
        locationService.stopTracking()
        
        // Stop timer
        timer?.invalidate()
        timer = nil
        
        // Get final route points
        let finalRoutePoints = locationService.getValidLocationPoints()
        
        // Add route to HealthKit
        if let routeBuilder = routeBuilder, !finalRoutePoints.isEmpty {
            let locations = finalRoutePoints.map { point in
                CLLocation(
                    coordinate: point.coordinate,
                    altitude: point.altitude,
                    horizontalAccuracy: point.horizontalAccuracy,
                    verticalAccuracy: point.verticalAccuracy,
                    course: point.course,
                    speed: point.speed,
                    timestamp: point.timestamp
                )
            }
            
            try await routeBuilder.insertRouteData(locations)
        }
        
        // Build workout samples
        if let builder = workoutBuilder, let start = startTime {
            // Add distance sample
            if totalDistance > 0 {
                let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: start,
                    end: endDate
                )
                try await addSamplesToBuilder(builder, samples: [distanceSample])
            }
            
            // Add calories sample
            if caloriesBurned > 0 {
                let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: caloriesBurned)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: start,
                    end: endDate
                )
                try await addSamplesToBuilder(builder, samples: [calorieSample])
            }
            
            // End workout collection
            try await builder.endCollection(at: endDate)
            
            // Finish and save workout
            if let workout = try await builder.finishWorkout() {
                // Associate route with workout
                if let routeBuilder = routeBuilder, !finalRoutePoints.isEmpty {
                    try await routeBuilder.finishRoute(with: workout, metadata: nil)
                }
                
                print("✅ Workout saved to HealthKit: \(workout.uuid)")
            }
        }
        
        // Create summary
        let summary = WorkoutSummary(
            id: UUID(),
            activityType: currentActivityType ?? .walking,
            startDate: startTime ?? endDate,
            endDate: endDate,
            duration: elapsedTime,
            totalDistance: totalDistance,
            totalEnergyBurned: caloriesBurned,
            totalElevationGain: elevationGain,
            averagePace: averagePace,
            averageSpeed: finalRoutePoints.averageSpeed(),
            routePoints: finalRoutePoints,
            heartRateSamples: heartRateSamples
        )
        
        // Update state
        updateState(.completed)
        
        print("🏁 Workout completed: \(summary.formattedDistance) in \(summary.formattedDuration)")
        
        return summary
    }
    
    func discardWorkout() {
        // Stop everything without saving
        locationService.resetTracking()
        timer?.invalidate()
        timer = nil
        
        workoutBuilder = nil
        routeBuilder = nil
        
        resetState()
        updateState(.notStarted)
        
        print("🗑️ Workout discarded")
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        startTime = nil
        pausedTime = 0
        pauseStartTime = nil
        heartRateSamples = []
        currentActivityType = nil
    }
    
    private func updateState(_ newState: WorkoutSessionState) {
        state = newState
        stateSubject.send(newState)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        let metrics = WorkoutMetrics(
            elapsedTime: elapsedTime,
            totalDistance: totalDistance,
            currentPace: currentPace,
            averagePace: averagePace,
            currentSpeed: currentSpeed,
            calories: caloriesBurned,
            elevationGain: elevationGain,
            currentHeartRate: nil // Could integrate with Apple Watch
        )
        
        metricsSubject.send(metrics)
    }
    
    private func requestHealthKitAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutError.healthKitNotAvailable
        }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKSeriesType.workoutRoute()
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKSeriesType.workoutRoute()
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    /// Helper to add samples to workout builder with async/await
    private func addSamplesToBuilder(_ builder: HKWorkoutBuilder, samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WorkoutError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Workout Error

enum WorkoutError: LocalizedError {
    case alreadyActive
    case notActive
    case healthKitNotAvailable
    case saveFailed
    case locationNotAuthorized
    
    var errorDescription: String? {
        switch self {
        case .alreadyActive:
            return "A workout is already in progress"
        case .notActive:
            return "No workout is currently active"
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .saveFailed:
            return "Failed to save workout to Health"
        case .locationNotAuthorized:
            return "Location access is required to track your workout route"
        }
    }
}
