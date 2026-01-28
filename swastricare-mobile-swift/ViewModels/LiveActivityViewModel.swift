//
//  LiveActivityViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM ViewModel for Live Activity Tracking
//  Real-time workout metrics and state management
//

import Foundation
import Combine
import CoreLocation
import MapKit

// MARK: - Live Activity View State

enum LiveActivityViewState: Equatable {
    case idle
    case preparing
    case countdown(Int)
    case tracking
    case paused
    case finishing
    case summary(WorkoutSummary)
    case error(String)
    
    var isTracking: Bool {
        switch self {
        case .tracking, .paused:
            return true
        default:
            return false
        }
    }
    
    var canStart: Bool {
        switch self {
        case .idle, .summary:
            return true
        default:
            return false
        }
    }
    
    static func == (lhs: LiveActivityViewState, rhs: LiveActivityViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.tracking, .tracking),
             (.paused, .paused),
             (.finishing, .finishing):
            return true
        case (.countdown(let l), .countdown(let r)):
            return l == r
        case (.summary(let l), .summary(let r)):
            return l.id == r.id
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Live Activity ViewModel

@MainActor
final class LiveActivityViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var viewState: LiveActivityViewState = .idle
    @Published private(set) var selectedActivityType: WorkoutActivityType = .running
    @Published private(set) var locationAuthStatus: LocationAuthorizationStatus = .notDetermined
    
    // Live Metrics
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var totalDistance: Double = 0 // meters
    @Published private(set) var currentPace: Double = 0 // sec/km
    @Published private(set) var averagePace: Double = 0 // sec/km
    @Published private(set) var currentSpeed: Double = 0 // m/s
    @Published private(set) var caloriesBurned: Double = 0
    @Published private(set) var elevationGain: Double = 0 // meters
    @Published private(set) var currentHeartRate: Int?
    
    // Route Data
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // Workout Summary (after completion)
    @Published private(set) var workoutSummary: WorkoutSummary?
    
    // Error Handling
    @Published var showError = false
    @Published var errorMessage: String?
    
    // Countdown
    @Published private(set) var countdownValue: Int = 3
    
    // MARK: - Computed Properties
    
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f", totalDistance / 1000)
        }
        return String(format: "%.0f", totalDistance)
    }
    
    var distanceUnit: String {
        totalDistance >= 1000 ? "km" : "m"
    }
    
    var formattedCurrentPace: String {
        formatPace(currentPace)
    }
    
    var formattedAveragePace: String {
        formatPace(averagePace)
    }
    
    var formattedSpeed: String {
        String(format: "%.1f", currentSpeed * 3.6) // Convert to km/h
    }
    
    var formattedCalories: String {
        String(format: "%.0f", caloriesBurned)
    }
    
    var formattedElevation: String {
        String(format: "%.0f", elevationGain)
    }
    
    var isTrackingActive: Bool {
        viewState == .tracking
    }
    
    var isPaused: Bool {
        viewState == .paused
    }
    
    var canPause: Bool {
        viewState == .tracking
    }
    
    var canResume: Bool {
        viewState == .paused
    }
    
    var canFinish: Bool {
        viewState.isTracking
    }
    
    // MARK: - Dependencies
    
    private let workoutManager: WorkoutSessionManagerProtocol
    private let locationService: LocationTrackingServiceProtocol
    private let liveActivityManager: WorkoutLiveActivityManager
    private let lifecycleHandler: WorkoutLifecycleHandler
    private let stateManager: WorkoutStateManager
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    
    // Recovery state
    @Published var showRecoveryAlert = false
    @Published var recoveredWorkoutState: WorkoutState?
    
    // MARK: - Initialization
    
    init(
        workoutManager: WorkoutSessionManagerProtocol = WorkoutSessionManager.shared,
        locationService: LocationTrackingServiceProtocol = LocationTrackingService.shared,
        lifecycleHandler: WorkoutLifecycleHandler = WorkoutLifecycleHandler.shared,
        stateManager: WorkoutStateManager = WorkoutStateManager.shared
    ) {
        self.workoutManager = workoutManager
        self.locationService = locationService
        self.liveActivityManager = WorkoutLiveActivityManager.shared
        self.lifecycleHandler = lifecycleHandler
        self.stateManager = stateManager
        
        setupBindings()
        checkForCrashedWorkout()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to workout metrics
        workoutManager.metricsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.updateMetrics(metrics)
            }
            .store(in: &cancellables)
        
        // Subscribe to location updates
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] point in
                self?.handleLocationUpdate(point)
            }
            .store(in: &cancellables)
        
        // Subscribe to authorization status
        locationService.authorizationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthStatus = status
            }
            .store(in: &cancellables)
        
        // Subscribe to location errors
        locationService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        // Subscribe to workout state
        workoutManager.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleWorkoutStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func selectActivityType(_ type: WorkoutActivityType) {
        guard viewState.canStart else { return }
        selectedActivityType = type
    }
    
    func requestLocationPermission() async {
        do {
            try await locationService.requestAuthorization()
        } catch {
            handleError(error)
        }
    }
    
    func startWorkout() async {
        guard viewState.canStart else { return }
        
        viewState = .preparing
        
        // Start countdown
        countdownValue = 3
        viewState = .countdown(countdownValue)
        
        await runCountdown()
        
        // After countdown, start actual tracking
        do {
            try await workoutManager.startWorkout(activityType: selectedActivityType)
            viewState = .tracking

            // Start Live Activity (Dynamic Island) after workout begins
            let startTime = workoutManager.startTime ?? Date()
            await liveActivityManager.startIfPossible(activityType: selectedActivityType, startTime: startTime)
            
            // Start lifecycle monitoring
            lifecycleHandler.startMonitoring()
            
            print("✅ Workout started with lifecycle monitoring")
        } catch {
            handleError(error)
        }
    }
    
    func pauseWorkout() {
        guard canPause else { return }
        workoutManager.pauseWorkout()
        viewState = .paused

        Task { [metrics = WorkoutMetrics(
            elapsedTime: elapsedTime,
            totalDistance: totalDistance,
            currentPace: currentPace,
            averagePace: averagePace,
            currentSpeed: currentSpeed,
            calories: caloriesBurned,
            elevationGain: elevationGain,
            currentHeartRate: currentHeartRate
        )] in
            await self.liveActivityManager.updateIfPossible(metrics: metrics, isPaused: true)
        }
    }
    
    func resumeWorkout() {
        guard canResume else { return }
        workoutManager.resumeWorkout()
        viewState = .tracking

        Task { [metrics = WorkoutMetrics(
            elapsedTime: elapsedTime,
            totalDistance: totalDistance,
            currentPace: currentPace,
            averagePace: averagePace,
            currentSpeed: currentSpeed,
            calories: caloriesBurned,
            elevationGain: elevationGain,
            currentHeartRate: currentHeartRate
        )] in
            await self.liveActivityManager.updateIfPossible(metrics: metrics, isPaused: false)
        }
    }
    
    func finishWorkout() async {
        guard canFinish else { return }
        
        viewState = .finishing
        
        do {
            let summary = try await workoutManager.endWorkout()
            workoutSummary = summary
            viewState = .summary(summary)

            // End Live Activity
            let finalMetrics = WorkoutMetrics(
                elapsedTime: summary.duration,
                totalDistance: summary.totalDistance,
                currentPace: summary.averagePace,
                averagePace: summary.averagePace,
                currentSpeed: summary.averageSpeed,
                calories: summary.totalEnergyBurned,
                elevationGain: summary.totalElevationGain,
                currentHeartRate: summary.averageHeartRate
            )
            await liveActivityManager.endIfPossible(finalMetrics: finalMetrics)
            
            // Stop lifecycle monitoring
            lifecycleHandler.stopMonitoring()
            
            // Sync to backend
            await syncWorkoutToBackend(summary)
            
            print("✅ Workout finished successfully")
        } catch {
            handleError(error)
        }
    }
    
    func discardWorkout() {
        workoutManager.discardWorkout()
        resetState()

        Task {
            await liveActivityManager.discardImmediately()
            lifecycleHandler.stopMonitoring()
        }
    }
    
    func dismissSummary() {
        resetState()
    }
    
    func dismissError() {
        showError = false
        errorMessage = nil
        
        // If we were preparing, go back to idle
        if case .error = viewState {
            resetState()
        }
    }
    
    // MARK: - Private Methods
    
    private func runCountdown() async {
        for i in stride(from: 3, through: 1, by: -1) {
            countdownValue = i
            viewState = .countdown(i)
            
            // Haptic feedback
            await MainActor.run {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    private func updateMetrics(_ metrics: WorkoutMetrics) {
        elapsedTime = metrics.elapsedTime
        totalDistance = metrics.totalDistance
        currentPace = metrics.currentPace
        averagePace = metrics.averagePace
        currentSpeed = metrics.currentSpeed
        caloriesBurned = metrics.calories
        elevationGain = metrics.elevationGain
        currentHeartRate = metrics.currentHeartRate

        // Keep Dynamic Island in sync (throttling handled by ActivityKit/system)
        let isPaused = (viewState == .paused)
        Task { [metrics] in
            await self.liveActivityManager.updateIfPossible(metrics: metrics, isPaused: isPaused)
        }
    }
    
    private func handleLocationUpdate(_ point: LocationPoint) {
        // Update current location
        currentLocation = point.coordinate
        
        // Add to route
        routeCoordinates.append(point.coordinate)
        
        // Update map region to follow user
        updateMapRegion()
    }
    
    private func updateMapRegion() {
        guard let current = currentLocation else { return }
        
        // Center on user with appropriate zoom
        mapRegion = MKCoordinateRegion(
            center: current,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
    
    private func handleWorkoutStateChange(_ state: WorkoutSessionState) {
        switch state {
        case .active:
            if viewState != .tracking {
                viewState = .tracking
            }
        case .paused:
            viewState = .paused
        case .completed:
            // Handled in finishWorkout
            break
        case .failed(let error):
            viewState = .error(error)
        case .notStarted:
            break
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        viewState = .error(error.localizedDescription)
    }
    
    private func resetState() {
        viewState = .idle
        elapsedTime = 0
        totalDistance = 0
        currentPace = 0
        averagePace = 0
        currentSpeed = 0
        caloriesBurned = 0
        elevationGain = 0
        currentHeartRate = nil
        routeCoordinates = []
        currentLocation = nil
        workoutSummary = nil
        countdownValue = 3
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 3600 else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
    
    private func syncWorkoutToBackend(_ summary: WorkoutSummary) async {
        // Convert to API format and sync
        let record = RunActivityRecord(
            id: nil,
            healthProfileId: nil,
            externalId: summary.id.uuidString,
            source: "app",
            activityType: summary.activityType.rawValue.lowercased(),
            activityName: generateActivityName(type: summary.activityType, startTime: summary.startDate),
            startedAt: summary.startDate,
            endedAt: summary.endDate,
            durationSeconds: Int(summary.duration),
            distanceMeters: summary.totalDistance,
            steps: 0, // Would need pedometer integration
            caloriesBurned: Int(summary.totalEnergyBurned),
            avgHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            routeCoordinates: summary.routePoints.map { point in
                RouteCoordinate(
                    lat: point.latitude,
                    lng: point.longitude,
                    alt: point.altitude,
                    ts: ISO8601DateFormatter().string(from: point.timestamp)
                )
            },
            startLatitude: summary.routePoints.first?.latitude,
            startLongitude: summary.routePoints.first?.longitude,
            endLatitude: summary.routePoints.last?.latitude,
            endLongitude: summary.routePoints.last?.longitude
        )
        
        do {
            _ = try await RunActivityService.shared.createActivity(record)
            print("✅ Workout synced to backend")
        } catch {
            print("⚠️ Failed to sync workout: \(error)")
            // Don't show error to user - workout is saved locally in HealthKit
        }
    }
    
    private func generateActivityName(type: WorkoutActivityType, startTime: Date) -> String {
        let hour = Calendar.current.component(.hour, from: startTime)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "Morning"
        case 12..<17: timeOfDay = "Afternoon"
        case 17..<21: timeOfDay = "Evening"
        default: timeOfDay = "Night"
        }
        
        return "\(timeOfDay) \(type.rawValue)"
    }
    
    // MARK: - Crash Recovery
    
    private func checkForCrashedWorkout() {
        Task {
            if let crashedState = await lifecycleHandler.checkForCrashedWorkout() {
                recoveredWorkoutState = crashedState
                showRecoveryAlert = true
            }
        }
    }
    
    func recoverWorkout() {
        guard let state = recoveredWorkoutState else { return }
        
        Task {
            do {
                // Show recovery UI
                viewState = .preparing
                
                // Attempt recovery
                try await lifecycleHandler.recoverWorkout(from: state)
                
                // Restart workout with recovered type
                if let activityType = WorkoutActivityType(rawValue: state.activityType) {
                    selectedActivityType = activityType
                    
                    // Note: Full state restoration would require more work
                    // For now, we'll just start a fresh workout of the same type
                    await startWorkout()
                    
                    // Show message about recovery
                    errorMessage = "Workout recovered. Starting fresh session."
                    showError = true
                }
            } catch {
                handleError(error)
                lifecycleHandler.discardCrashedWorkout()
            }
            
            showRecoveryAlert = false
            recoveredWorkoutState = nil
        }
    }
    
    func discardRecoveredWorkout() {
        lifecycleHandler.discardCrashedWorkout()
        showRecoveryAlert = false
        recoveredWorkoutState = nil
    }
    
    // MARK: - Background State
    
    var isInBackground: Bool {
        lifecycleHandler.isInBackground
    }
}

// MARK: - UIKit Import for Haptics

import UIKit
