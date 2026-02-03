//
//  WidgetWorkoutManager.swift
//  SwasthiCareWidgets
//
//  Manages starting workouts from widget in background
//

import Foundation
import ActivityKit
import WidgetKit

// MARK: - Widget Workout State

struct WidgetWorkoutState: Codable {
    let id: UUID
    let activityType: String // "run", "walk", "commute"
    let startTime: Date
    var isActive: Bool
    var isPaused: Bool
    var elapsedSeconds: Int
    var distanceMeters: Double
    var caloriesBurned: Int
    
    static let empty = WidgetWorkoutState(
        id: UUID(),
        activityType: "run",
        startTime: Date(),
        isActive: false,
        isPaused: false,
        elapsedSeconds: 0,
        distanceMeters: 0,
        caloriesBurned: 0
    )
}

// MARK: - Widget Workout Manager

final class WidgetWorkoutManager {
    
    static let shared = WidgetWorkoutManager()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private enum Keys {
        static let activeWorkout = "widget_active_workout"
        static let pendingStartWorkout = "widget_pending_start_workout"
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Start Workout from Widget
    
    /// Starts a workout from the widget
    /// - Returns: true if Live Activity started successfully
    @discardableResult
    func startWorkout(type: String) -> Bool {
        print("🏃 WidgetWorkoutManager: Starting \(type) workout from widget")
        
        let workoutId = UUID()
        let startTime = Date()
        
        // Create workout state
        let workoutState = WidgetWorkoutState(
            id: workoutId,
            activityType: type,
            startTime: startTime,
            isActive: true,
            isPaused: false,
            elapsedSeconds: 0,
            distanceMeters: 0,
            caloriesBurned: 0
        )
        
        // Save to App Group so main app can pick it up
        saveWorkoutState(workoutState)
        
        // Mark pending start for main app to handle
        savePendingStartWorkout(type: type, workoutId: workoutId, startTime: startTime)
        
        // Try to start Live Activity
        let liveActivityStarted = startLiveActivity(type: type, startTime: startTime)
        
        // Refresh widgets
        WidgetDataManager.shared.refreshRunWidget()
        
        print("🏃 WidgetWorkoutManager: Workout started - ID: \(workoutId), LiveActivity: \(liveActivityStarted)")
        
        return liveActivityStarted
    }
    
    // MARK: - Live Activity
    
    private func startLiveActivity(type: String, startTime: Date) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ WidgetWorkoutManager: Live Activities not enabled")
            return false
        }
        
        let icon: String
        switch type.lowercased() {
        case "run":
            icon = "figure.run"
        case "walk":
            icon = "figure.walk"
        case "commute":
            icon = "figure.walk.motion"
        default:
            icon = "figure.run"
        }
        
        let attributes = WorkoutActivityAttributes(
            activityType: type,
            activityIcon: icon,
            startTime: startTime
        )
        
        let initialState = WorkoutActivityAttributes.ContentState.initial
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            print("✅ WidgetWorkoutManager: Live Activity started - ID: \(activity.id)")
            return true
        } catch {
            print("❌ WidgetWorkoutManager: Failed to start Live Activity - \(error)")
            return false
        }
    }
    
    // MARK: - Workout State Management
    
    func saveWorkoutState(_ state: WidgetWorkoutState) {
        guard let defaults = AppGroupConfig.sharedDefaults else { return }
        
        do {
            let encoded = try encoder.encode(state)
            defaults.set(encoded, forKey: Keys.activeWorkout)
            defaults.synchronize()
            print("💾 WidgetWorkoutManager: Saved workout state")
        } catch {
            print("⚠️ WidgetWorkoutManager: Failed to save workout state - \(error)")
        }
    }
    
    func loadWorkoutState() -> WidgetWorkoutState? {
        guard let defaults = AppGroupConfig.sharedDefaults,
              let data = defaults.data(forKey: Keys.activeWorkout) else {
            return nil
        }
        
        return try? decoder.decode(WidgetWorkoutState.self, from: data)
    }
    
    func clearWorkoutState() {
        guard let defaults = AppGroupConfig.sharedDefaults else { return }
        defaults.removeObject(forKey: Keys.activeWorkout)
        defaults.synchronize()
        print("🧹 WidgetWorkoutManager: Cleared workout state")
    }
    
    func hasActiveWorkout() -> Bool {
        guard let state = loadWorkoutState() else { return false }
        return state.isActive
    }
    
    // MARK: - Pending Start (for main app to pick up)
    
    struct PendingStartWorkout: Codable {
        let type: String
        let workoutId: UUID
        let startTime: Date
    }
    
    private func savePendingStartWorkout(type: String, workoutId: UUID, startTime: Date) {
        guard let defaults = AppGroupConfig.sharedDefaults else { return }
        
        let pending = PendingStartWorkout(type: type, workoutId: workoutId, startTime: startTime)
        
        do {
            let encoded = try encoder.encode(pending)
            defaults.set(encoded, forKey: Keys.pendingStartWorkout)
            defaults.synchronize()
            print("📌 WidgetWorkoutManager: Saved pending workout start")
        } catch {
            print("⚠️ WidgetWorkoutManager: Failed to save pending start - \(error)")
        }
    }
    
    /// Get and clear pending start workout (called by main app)
    func getPendingStartWorkout() -> PendingStartWorkout? {
        guard let defaults = AppGroupConfig.sharedDefaults,
              let data = defaults.data(forKey: Keys.pendingStartWorkout) else {
            return nil
        }
        
        // Clear after reading
        defaults.removeObject(forKey: Keys.pendingStartWorkout)
        defaults.synchronize()
        
        return try? decoder.decode(PendingStartWorkout.self, from: data)
    }
    
    /// Check if there's a pending workout to start
    func hasPendingWorkout() -> Bool {
        guard let defaults = AppGroupConfig.sharedDefaults else { return false }
        return defaults.data(forKey: Keys.pendingStartWorkout) != nil
    }
}

// MARK: - WidgetDataManager Extension

extension WidgetDataManager {
    
    /// Refresh run widget with active workout state
    func updateRunWidgetWithActiveWorkout(_ state: WidgetWorkoutState) {
        let activity = WidgetRunActivity(
            name: "\(state.activityType.capitalized) in progress",
            type: state.activityType,
            distance: state.distanceMeters / 1000.0,
            duration: TimeInterval(state.elapsedSeconds),
            calories: state.caloriesBurned,
            date: state.startTime
        )
        
        let runData = WidgetRunData(
            lastActivity: activity,
            weeklyStats: nil,
            lastUpdated: Date()
        )
        
        saveRunData(runData)
        refreshRunWidget()
    }
}
