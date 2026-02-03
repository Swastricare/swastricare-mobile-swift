//
//  WidgetDataManager+Integration.swift
//  SwasthiCareWidgets
//
//  Helper extension for easier integration with main app
//

import Foundation

// MARK: - Integration Helpers

extension WidgetDataManager {
    
    /// Update steps widget with current data
    /// Call this from your HealthKitService or StepsViewModel
    func updateStepsWidget(
        currentSteps: Int,
        dailyGoal: Int = 10000,
        distance: Double,
        calories: Int
    ) {
        let data = WidgetStepsData(
            currentSteps: currentSteps,
            dailyGoal: dailyGoal,
            distance: distance,
            calories: calories,
            lastUpdated: Date()
        )
        
        saveStepsData(data)
        refreshStepsWidget()
        
        print("👣 Updated Steps Widget: \(currentSteps)/\(dailyGoal) steps")
    }
    
    /// Update run widget with latest activity
    /// Call this from your RunActivityViewModel after loading activities
    func updateRunWidget(
        activityName: String,
        activityType: String, // "walk", "run", "commute"
        distance: Double, // in km
        duration: TimeInterval, // in seconds
        calories: Int,
        activityDate: Date,
        weeklyDistance: Double? = nil,
        weeklyActivities: Int? = nil,
        weeklyCalories: Int? = nil
    ) {
        let activity = WidgetRunActivity(
            name: activityName,
            type: activityType,
            distance: distance,
            duration: duration,
            calories: calories,
            date: activityDate
        )
        
        var weeklyStats: WidgetWeeklyRunStats?
        if let totalDistance = weeklyDistance,
           let totalActivities = weeklyActivities,
           let totalCalories = weeklyCalories {
            weeklyStats = WidgetWeeklyRunStats(
                totalDistance: totalDistance,
                totalActivities: totalActivities,
                totalCalories: totalCalories
            )
        }
        
        let data = WidgetRunData(
            lastActivity: activity,
            weeklyStats: weeklyStats,
            lastUpdated: Date()
        )
        
        saveRunData(data)
        refreshRunWidget()
        
        print("🏃 Updated Run Widget: \(activityName) - \(distance)km")
    }
    
    /// Clear run widget data (e.g., when no activities exist)
    func clearRunWidget() {
        saveRunData(.empty)
        refreshRunWidget()
        print("🏃 Cleared Run Widget")
    }
    
    /// Update all widgets at once (call on app launch or when entering foreground)
    func updateAllWidgets() {
        refreshAllWidgets()
        print("🔄 Refreshed all widgets")
    }
}

// MARK: - RouteActivity Extension (for easy conversion)

#if canImport(SwiftUI)
import SwiftUI

/// Extension to make it easier to update run widget from RouteActivity model
extension WidgetDataManager {
    
    /// Update run widget directly from a RouteActivity
    /// This is a convenience method that extracts the necessary data
    fileprivate func updateRunWidget(from activity: RouteActivity, weeklyStats: (distance: Double, count: Int, calories: Int)? = nil) {
        var weeklyStatsData: WidgetWeeklyRunStats?
        if let stats = weeklyStats {
            weeklyStatsData = WidgetWeeklyRunStats(
                totalDistance: stats.distance,
                totalActivities: stats.count,
                totalCalories: stats.calories
            )
        }
        
        let widgetActivity = WidgetRunActivity(
            name: activity.name,
            type: activity.type.rawValue.lowercased(),
            distance: activity.distance,
            duration: activity.duration,
            calories: activity.calories,
            date: activity.startTime
        )
        
        let data = WidgetRunData(
            lastActivity: widgetActivity,
            weeklyStats: weeklyStatsData,
            lastUpdated: Date()
        )
        
        saveRunData(data)
        refreshRunWidget()
    }
    
    /// Update run widget from multiple activities (gets the most recent)
    fileprivate func updateRunWidget(from activities: [RouteActivity], weeklyStats: (distance: Double, count: Int, calories: Int)? = nil) {
        guard let lastActivity = activities.sorted(by: { $0.startTime > $1.startTime }).first else {
            clearRunWidget()
            return
        }
        
        updateRunWidget(from: lastActivity, weeklyStats: weeklyStats)
    }
}

// Placeholder for RouteActivity if not in scope
// This will be replaced by the actual RouteActivity from your main app
private struct RouteActivity {
    let name: String
    let type: ActivityType
    let distance: Double
    let duration: TimeInterval
    let calories: Int
    let startTime: Date
    
    enum ActivityType: String {
        case walk = "Walk"
        case run = "Run"
        case commute = "Commute"
    }
}

#endif
