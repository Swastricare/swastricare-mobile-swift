//
//  WorkoutLiveActivityManager.swift
//  swastricare-mobile-swift
//
//  Starts/updates/ends ActivityKit Live Activities for workouts.
//  Enhanced with comprehensive error handling and state management
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Activity Error

enum LiveActivityError: LocalizedError {
    case notAvailable
    case notEnabled
    case startFailed(String)
    case updateFailed(String)
    case endFailed(String)
    case activityNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Live Activities not available on this device"
        case .notEnabled:
            return "Live Activities are disabled in Settings"
        case .startFailed(let reason):
            return "Failed to start Live Activity: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update Live Activity: \(reason)"
        case .endFailed(let reason):
            return "Failed to end Live Activity: \(reason)"
        case .activityNotFound:
            return "No active Live Activity found"
        }
    }
}

// MARK: - Live Activity Manager

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private init() {}

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var activity: Activity<WorkoutActivityAttributes>?
    
    @available(iOS 16.1, *)
    private var activityId: String? {
        activity?.id
    }
    #endif
    
    // Track last update to prevent excessive updates
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 1.0 // Throttle to 1 update per second

    // MARK: - Start Live Activity
    
    func startIfPossible(activityType: WorkoutActivityType, startTime: Date) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else {
            print("⚠️ Live Activities not available (iOS 16.1+ required)")
            return
        }
        
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities are disabled in Settings")
            return
        }

        // End any previous activity (avoid duplicates)
        if let activity {
            print("🔄 Ending previous Live Activity before starting new one")
            await activity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }

        let attributes = WorkoutActivityAttributes(
            activityType: activityType.rawValue,
            activityIcon: activityType.liveActivityIcon,
            startTime: startTime
        )

        let state = WorkoutActivityAttributes.ContentState.initial
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            self.activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            
            if let activityId = activity?.id {
                print("✅ Live Activity started successfully: \(activityId)")
            }
        } catch let error as ActivityAuthorizationError {
            handleActivityError(.startFailed("Authorization error: \(error.localizedDescription)"))
        } catch {
            handleActivityError(.startFailed(error.localizedDescription))
        }
        #endif
    }
    
    // MARK: - Update Live Activity

    func updateIfPossible(metrics: WorkoutMetrics, isPaused: Bool) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard let activity else {
            print("⚠️ Cannot update: No active Live Activity")
            return
        }
        
        // Throttle updates to prevent excessive API calls
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }

        let newState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: max(0, Int(metrics.elapsedTime.rounded())),
            distanceMeters: max(0, metrics.totalDistance),
            currentPaceSecondsPerKm: max(0, Int(metrics.currentPace.rounded())),
            averagePaceSecondsPerKm: max(0, Int(metrics.averagePace.rounded())),
            caloriesBurned: max(0, Int(metrics.calories.rounded())),
            currentHeartRate: metrics.currentHeartRate,
            isPaused: isPaused
        )
        
        do {
            await activity.update(ActivityContent(state: newState, staleDate: nil))
            lastUpdateTime = Date()
        } catch {
            handleActivityError(.updateFailed(error.localizedDescription))
        }
        #endif
    }
    
    // MARK: - End Live Activity

    func endIfPossible(finalMetrics: WorkoutMetrics? = nil) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard let activity else {
            print("⚠️ Cannot end: No active Live Activity")
            return
        }

        do {
            if let finalMetrics {
                let finalState = WorkoutActivityAttributes.ContentState(
                    elapsedSeconds: max(0, Int(finalMetrics.elapsedTime.rounded())),
                    distanceMeters: max(0, finalMetrics.totalDistance),
                    currentPaceSecondsPerKm: max(0, Int(finalMetrics.currentPace.rounded())),
                    averagePaceSecondsPerKm: max(0, Int(finalMetrics.averagePace.rounded())),
                    caloriesBurned: max(0, Int(finalMetrics.calories.rounded())),
                    currentHeartRate: finalMetrics.currentHeartRate,
                    isPaused: false
                )

                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .default
                )
            } else {
                await activity.end(nil, dismissalPolicy: .default)
            }

            print("✅ Live Activity ended successfully")
            self.activity = nil
            lastUpdateTime = nil
        } catch {
            handleActivityError(.endFailed(error.localizedDescription))
            self.activity = nil // Clear even if end failed
        }
        #endif
    }
    
    // MARK: - Discard Immediately

    func discardImmediately() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard let activity else { return }
        
        do {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("🗑️ Live Activity discarded immediately")
        } catch {
            print("⚠️ Failed to discard Live Activity: \(error)")
        }
        
        self.activity = nil
        lastUpdateTime = nil
        #endif
    }
    
    // MARK: - State Queries
    
    var isActive: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return activity != nil
        }
        #endif
        return false
    }
    
    var canStartActivities: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }
    
    // MARK: - Error Handling
    
    private func handleActivityError(_ error: LiveActivityError) {
        print("❌ Live Activity Error: \(error.localizedDescription ?? "Unknown error")")
        
        // Post notification for UI to handle if needed
        NotificationCenter.default.post(
            name: .liveActivityError,
            object: nil,
            userInfo: ["error": error]
        )
    }
    
    // MARK: - Cleanup Orphaned Activities
    
    /// Clean up any orphaned live activities (useful after crash recovery)
    func cleanupOrphanedActivities() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        // End current activity if it exists
        if activity != nil {
            print("🧹 Cleaning up orphaned Live Activity")
            await discardImmediately()
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let liveActivityError = Notification.Name("com.swasthicare.liveActivityError")
}

