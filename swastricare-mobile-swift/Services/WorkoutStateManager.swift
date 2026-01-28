//
//  WorkoutStateManager.swift
//  swastricare-mobile-swift
//
//  Persistent workout state management for crash recovery and app lifecycle handling
//  Ensures workout data is preserved even if app is terminated
//

import Foundation
import CoreLocation

// MARK: - Workout State

struct WorkoutState: Codable, Equatable {
    let id: UUID
    let activityType: String
    let startTime: Date
    let isActive: Bool
    let isPaused: Bool
    let pausedDuration: TimeInterval
    let locationPoints: [LocationPoint]
    let heartRateSamples: [HeartRateSample]
    let lastMetrics: WorkoutMetricsSnapshot
    let liveActivityId: String?
    let savedAt: Date
    
    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(startTime) - pausedDuration
    }
}

// MARK: - Workout Metrics Snapshot

struct WorkoutMetricsSnapshot: Codable, Equatable {
    let elapsedTime: TimeInterval
    let totalDistance: Double
    let averagePace: Double
    let calories: Double
    let elevationGain: Double
}

// MARK: - Workout State Manager

@MainActor
final class WorkoutStateManager {
    
    static let shared = WorkoutStateManager()
    
    private let defaults = UserDefaults.standard
    private let workoutStateKey = "com.swasthicare.workoutState"
    private let lastCrashCheckKey = "com.swasthicare.lastCrashCheck"
    private let backgroundTaskKey = "com.swasthicare.backgroundTask"
    
    // Auto-save timer
    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 10 // Save every 10 seconds
    
    private init() {}
    
    // MARK: - State Persistence
    
    /// Save current workout state
    func saveWorkoutState(_ state: WorkoutState) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            defaults.set(data, forKey: workoutStateKey)
            defaults.synchronize() // Force immediate write
            print("💾 Workout state saved: \(state.id)")
        } catch {
            print("❌ Failed to save workout state: \(error)")
        }
    }
    
    /// Load saved workout state
    func loadWorkoutState() -> WorkoutState? {
        guard let data = defaults.data(forKey: workoutStateKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(WorkoutState.self, from: data)
            print("📂 Loaded workout state: \(state.id)")
            return state
        } catch {
            print("❌ Failed to load workout state: \(error)")
            return nil
        }
    }
    
    /// Clear saved workout state
    func clearWorkoutState() {
        defaults.removeObject(forKey: workoutStateKey)
        defaults.synchronize()
        print("🗑️ Workout state cleared")
    }
    
    /// Check if there's an active workout state
    func hasActiveWorkout() -> Bool {
        guard let state = loadWorkoutState() else { return false }
        
        // Check if workout is still considered active (within 24 hours)
        let hoursSinceStart = Date().timeIntervalSince(state.startTime) / 3600
        return state.isActive && hoursSinceStart < 24
    }
    
    // MARK: - Auto-Save Management
    
    /// Start auto-saving workout state periodically
    func startAutoSave(workoutProvider: @escaping () -> WorkoutState?) {
        stopAutoSave() // Stop any existing timer
        
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let state = workoutProvider() {
                    self?.saveWorkoutState(state)
                }
            }
        }
        
        print("⏰ Auto-save started (interval: \(autoSaveInterval)s)")
    }
    
    /// Stop auto-saving
    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        print("⏰ Auto-save stopped")
    }
    
    // MARK: - Crash Detection
    
    /// Mark that app launched successfully
    func markAppLaunched() {
        defaults.set(Date(), forKey: lastCrashCheckKey)
        defaults.synchronize()
    }
    
    /// Check if app crashed during last session
    func didCrashDuringLastSession() -> Bool {
        // If there's an active workout state but no last crash check, likely crashed
        guard hasActiveWorkout() else { return false }
        
        let lastCheck = defaults.object(forKey: lastCrashCheckKey) as? Date
        return lastCheck == nil
    }
    
    /// Get crash recovery info
    func getCrashRecoveryInfo() -> (state: WorkoutState, timeElapsed: TimeInterval)? {
        guard let state = loadWorkoutState(), state.isActive else { return nil }
        
        let timeElapsed = Date().timeIntervalSince(state.savedAt)
        
        // Only recover if crash was recent (within 1 hour)
        guard timeElapsed < 3600 else {
            print("⚠️ Workout state too old to recover (\(timeElapsed/60) minutes)")
            clearWorkoutState()
            return nil
        }
        
        return (state, timeElapsed)
    }
    
    // MARK: - Background Task Management
    
    /// Save background task identifier
    func saveBackgroundTaskId(_ identifier: String) {
        defaults.set(identifier, forKey: backgroundTaskKey)
        defaults.synchronize()
    }
    
    /// Load background task identifier
    func loadBackgroundTaskId() -> String? {
        return defaults.string(forKey: backgroundTaskKey)
    }
    
    /// Clear background task identifier
    func clearBackgroundTaskId() {
        defaults.removeObject(forKey: backgroundTaskKey)
        defaults.synchronize()
    }
}

// MARK: - Workout State Builder

extension WorkoutState {
    
    /// Create workout state from current session
    static func from(
        sessionManager: WorkoutSessionManagerProtocol,
        locationService: LocationTrackingServiceProtocol,
        liveActivityId: String? = nil
    ) -> WorkoutState? {
        
        guard let activityType = sessionManager.currentActivityType,
              let startTime = sessionManager.startTime else {
            return nil
        }
        
        let metrics = WorkoutMetricsSnapshot(
            elapsedTime: sessionManager.elapsedTime,
            totalDistance: sessionManager.totalDistance,
            averagePace: sessionManager.averagePace,
            calories: sessionManager.caloriesBurned,
            elevationGain: sessionManager.elevationGain
        )
        
        return WorkoutState(
            id: UUID(),
            activityType: activityType.rawValue,
            startTime: startTime,
            isActive: sessionManager.state.isActive,
            isPaused: sessionManager.state == .paused,
            pausedDuration: 0, // Would need to track in WorkoutSessionManager
            locationPoints: locationService.getValidLocationPoints(),
            heartRateSamples: [],
            lastMetrics: metrics,
            liveActivityId: liveActivityId,
            savedAt: Date()
        )
    }
}
