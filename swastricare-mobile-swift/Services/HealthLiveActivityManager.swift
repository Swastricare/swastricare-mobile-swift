//
//  HealthLiveActivityManager.swift
//  swastricare-mobile-swift
//
//  Manages the health tracking Dynamic Island / Live Activity
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class HealthLiveActivityManager: ObservableObject {
    static let shared = HealthLiveActivityManager()

    @Published private(set) var isActive = false

    private init() {}

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private var activity: Activity<HealthActivityAttributes>?
    #endif

    // Throttle updates
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 30.0 // Update every 30s max

    // MARK: - Start

    func startHealthTracking(userName: String) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }

        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities disabled in Settings")
            return
        }

        // End any previous
        if let activity {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }

        let attributes = HealthActivityAttributes(
            userName: userName,
            startTime: Date()
        )

        let content = ActivityContent(
            state: HealthActivityAttributes.ContentState.initial,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        )

        do {
            self.activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            isActive = true
            print("✅ Health Live Activity started")
        } catch {
            print("❌ Failed to start Health Live Activity: \(error)")
        }
        #endif
    }

    // MARK: - Update

    func update(steps: Int, heartRate: Int, calories: Int, hydrationMl: Int, hydrationGoalMl: Int, stepGoal: Int) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let activity else { return }

        // Throttle
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }

        let state = HealthActivityAttributes.ContentState(
            steps: steps,
            heartRate: heartRate,
            calories: calories,
            hydrationMl: hydrationMl,
            hydrationGoalMl: hydrationGoalMl,
            stepGoal: stepGoal
        )

        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        )

        await activity.update(content)
        lastUpdateTime = Date()
        #endif
    }

    // MARK: - End

    func endHealthTracking() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let activity else { return }

        await activity.end(nil, dismissalPolicy: .default)
        self.activity = nil
        isActive = false
        lastUpdateTime = nil
        print("✅ Health Live Activity ended")
        #endif
    }

    // MARK: - Queries

    var canStartActivities: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }
}
