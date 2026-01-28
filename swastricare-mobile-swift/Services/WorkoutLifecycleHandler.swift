//
//  WorkoutLifecycleHandler.swift
//  swastricare-mobile-swift
//
//  Handles all app lifecycle events during workout tracking
//  Ensures workout continues in background and survives app termination
//

import Foundation
import UIKit
import BackgroundTasks
import Combine

// MARK: - Workout Lifecycle Events

enum WorkoutLifecycleEvent {
    case appEnterBackground
    case appEnterForeground
    case appWillTerminate
    case appDidCrash
    case systemMemoryWarning
    case workoutPausedBySystem
    case locationAuthorizationChanged
}

// MARK: - Workout Lifecycle Handler

@MainActor
final class WorkoutLifecycleHandler: ObservableObject {
    
    static let shared = WorkoutLifecycleHandler()
    
    // Dependencies
    private let workoutManager: WorkoutSessionManagerProtocol
    private let locationService: LocationTrackingServiceProtocol
    private let liveActivityManager: WorkoutLiveActivityManager
    private let stateManager: WorkoutStateManager
    
    // State
    @Published private(set) var isInBackground = false
    @Published private(set) var backgroundTimeRemaining: TimeInterval = 0
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()
    
    // Observers
    private var lifecycleObservers: [NSObjectProtocol] = []
    
    private init(
        workoutManager: WorkoutSessionManagerProtocol = WorkoutSessionManager.shared,
        locationService: LocationTrackingServiceProtocol = LocationTrackingService.shared,
        liveActivityManager: WorkoutLiveActivityManager = WorkoutLiveActivityManager.shared,
        stateManager: WorkoutStateManager = WorkoutStateManager.shared
    ) {
        self.workoutManager = workoutManager
        self.locationService = locationService
        self.liveActivityManager = liveActivityManager
        self.stateManager = stateManager
        
        setupLifecycleObservers()
    }
    
    // MARK: - Setup
    
    private func setupLifecycleObservers() {
        // App will enter background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppEnterBackground()
            }
        }
        lifecycleObservers.append(backgroundObserver)
        
        // App will enter foreground
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppEnterForeground()
            }
        }
        lifecycleObservers.append(foregroundObserver)
        
        // App will terminate
        let terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppWillTerminate()
            }
        }
        lifecycleObservers.append(terminateObserver)
        
        // Memory warning
        let memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        lifecycleObservers.append(memoryWarningObserver)
    }
    
    private func removeLifecycleObservers() {
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers.removeAll()
    }
    
    // MARK: - Lifecycle Event Handlers
    
    private func handleAppEnterBackground() async {
        guard workoutManager.state.isActive else { return }
        
        isInBackground = true
        print("📱 App entering background during workout")
        
        // Save current state immediately
        saveWorkoutState()
        
        // Start background task to keep app alive longer
        startBackgroundTask()
        
        // Start auto-save timer
        startAutoSave()
        
        // Ensure location tracking continues in background
        // (already configured in LocationTrackingService with allowsBackgroundLocationUpdates)
        
        print("✅ Background mode activated - workout will continue")
        print("⏱️ Background time remaining: \(UIApplication.shared.backgroundTimeRemaining)s")
    }
    
    private func handleAppEnterForeground() async {
        print("📱 App entering foreground")
        
        isInBackground = false
        
        // End background task
        endBackgroundTask()
        
        // Stop auto-save (normal operation resumes)
        stateManager.stopAutoSave()
        
        // Check if workout is still active
        if workoutManager.state.isActive {
            print("✅ Workout still active after backgrounding")
            
            // Update live activity with latest data
            let metrics = getCurrentMetrics()
            let isPaused = workoutManager.state == .paused
            await liveActivityManager.updateIfPossible(metrics: metrics, isPaused: isPaused)
        } else {
            print("⚠️ Workout no longer active")
        }
    }
    
    private func handleAppWillTerminate() async {
        print("📱 App will terminate")
        
        // Save final state if workout is active
        if workoutManager.state.isActive {
            print("💾 Saving workout state before termination")
            saveWorkoutState()
            
            // Keep live activity running - it will persist even after app termination
            print("🔴 Live Activity will continue after termination")
            
            // User can:
            // 1. Resume workout by tapping on Live Activity
            // 2. End workout from Live Activity
            // 3. Reopen app to see workout continue
        }
        
        endBackgroundTask()
    }
    
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received")
        
        // Save state immediately in case of crash
        if workoutManager.state.isActive {
            saveWorkoutState()
        }
        
        // Could clear non-essential caches here if needed
    }
    
    // MARK: - Crash Recovery
    
    /// Check for crashed workout and offer recovery
    func checkForCrashedWorkout() async -> WorkoutState? {
        guard let (state, timeElapsed) = stateManager.getCrashRecoveryInfo() else {
            stateManager.markAppLaunched()
            return nil
        }
        
        print("🔄 Found crashed workout from \(timeElapsed/60) minutes ago")
        print("   Activity: \(state.activityType)")
        print("   Distance: \(state.lastMetrics.totalDistance/1000) km")
        print("   Duration: \(state.lastMetrics.elapsedTime/60) minutes")
        
        return state
    }
    
    /// Recover workout from saved state
    func recoverWorkout(from state: WorkoutState) async throws {
        print("🔄 Recovering workout...")
        
        // Restore activity type
        guard let activityType = WorkoutActivityType(rawValue: state.activityType) else {
            throw WorkoutLifecycleError.invalidActivityType
        }
        
        // Note: Full recovery would require restoring session state in WorkoutSessionManager
        // For now, we'll offer to restart or discard
        
        print("✅ Workout recovery prepared")
    }
    
    /// Discard crashed workout
    func discardCrashedWorkout() {
        print("🗑️ Discarding crashed workout")
        stateManager.clearWorkoutState()
        
        // Clean up any orphaned live activities
        Task {
            await liveActivityManager.endIfPossible()
        }
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("⏰ Background task expiring")
            Task { @MainActor in
                await self?.handleBackgroundTaskExpiring()
            }
        }
        
        if backgroundTask != .invalid {
            print("✅ Background task started: \(backgroundTask)")
            stateManager.saveBackgroundTaskId(String(backgroundTask.rawValue))
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        print("🛑 Ending background task: \(backgroundTask)")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        stateManager.clearBackgroundTaskId()
    }
    
    private func handleBackgroundTaskExpiring() async {
        print("⏰ Background task expiring - saving final state")
        
        // Save final state before task expires
        if workoutManager.state.isActive {
            saveWorkoutState()
        }
        
        endBackgroundTask()
        
        // Note: Location tracking will continue even after background task expires
        // thanks to allowsBackgroundLocationUpdates = true
        print("📍 Location tracking continues (background mode enabled)")
    }
    
    // MARK: - State Management
    
    private func saveWorkoutState() {
        guard let state = WorkoutState.from(
            sessionManager: workoutManager,
            locationService: locationService,
            liveActivityId: nil // Could store activity ID if needed
        ) else {
            return
        }
        
        stateManager.saveWorkoutState(state)
    }
    
    private func startAutoSave() {
        stateManager.startAutoSave { [weak self] in
            guard let self = self else { return nil }
            
            return WorkoutState.from(
                sessionManager: self.workoutManager,
                locationService: self.locationService
            )
        }
    }
    
    private func getCurrentMetrics() -> WorkoutMetrics {
        return WorkoutMetrics(
            elapsedTime: workoutManager.elapsedTime,
            totalDistance: workoutManager.totalDistance,
            currentPace: workoutManager.currentPace,
            averagePace: workoutManager.averagePace,
            currentSpeed: workoutManager.currentSpeed,
            calories: workoutManager.caloriesBurned,
            elevationGain: workoutManager.elevationGain,
            currentHeartRate: nil
        )
    }
    
    // MARK: - Public Interface
    
    /// Start monitoring lifecycle for active workout
    func startMonitoring() {
        print("👁️ Workout lifecycle monitoring started")
        stateManager.markAppLaunched()
    }
    
    /// Stop monitoring lifecycle
    func stopMonitoring() {
        print("👁️ Workout lifecycle monitoring stopped")
        stateManager.stopAutoSave()
        endBackgroundTask()
        stateManager.clearWorkoutState()
    }
}

// MARK: - Errors

enum WorkoutLifecycleError: LocalizedError {
    case invalidActivityType
    case recoveryFailed
    case stateCorrupted
    
    var errorDescription: String? {
        switch self {
        case .invalidActivityType:
            return "Invalid activity type in saved state"
        case .recoveryFailed:
            return "Failed to recover workout from saved state"
        case .stateCorrupted:
            return "Saved workout state is corrupted"
        }
    }
}
