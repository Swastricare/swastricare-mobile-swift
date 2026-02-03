//
//  RunWidgetEntry.swift
//  SwasthiCareWidgets
//
//  Timeline entry for run widget
//

import WidgetKit
import Foundation

struct RunWidgetEntry: TimelineEntry {
    let date: Date
    let runData: WidgetRunData
    let activeWorkout: WidgetWorkoutState?
    let configuration: RunWidgetConfigurationIntent?
    
    init(
        date: Date = Date(),
        runData: WidgetRunData = .empty,
        activeWorkout: WidgetWorkoutState? = nil,
        configuration: RunWidgetConfigurationIntent? = nil
    ) {
        self.date = date
        self.runData = runData
        self.activeWorkout = activeWorkout
        self.configuration = configuration
    }
    
    // Active workout properties
    var hasActiveWorkout: Bool { activeWorkout?.isActive ?? false }
    var activeWorkoutType: String { activeWorkout?.activityType ?? "run" }
    var activeWorkoutElapsed: Int { activeWorkout?.elapsedSeconds ?? 0 }
    var activeWorkoutDistance: Double { (activeWorkout?.distanceMeters ?? 0) / 1000.0 }
    var activeWorkoutStartTime: Date { activeWorkout?.startTime ?? date }
    
    var formattedActiveElapsed: String {
        let seconds = activeWorkoutElapsed
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    var activeWorkoutIcon: String {
        switch activeWorkoutType.lowercased() {
        case "run": return "figure.run"
        case "walk": return "figure.walk"
        case "commute": return "figure.walk.motion"
        default: return "figure.run"
        }
    }
    
    // Convenience properties
    var hasRecentActivity: Bool { runData.lastActivity != nil }
    var lastActivityName: String { runData.lastActivity?.name ?? "No recent activity" }
    var lastActivityType: String { runData.lastActivity?.type ?? "walk" }
    var lastActivityDistance: Double { runData.lastActivity?.distance ?? 0 }
    var lastActivityDuration: TimeInterval { runData.lastActivity?.duration ?? 0 }
    var lastActivityCalories: Int { runData.lastActivity?.calories ?? 0 }
    var lastActivityDate: Date? { runData.lastActivity?.date }
    
    var weeklyDistance: Double { runData.weeklyStats?.totalDistance ?? 0 }
    var weeklyActivities: Int { runData.weeklyStats?.totalActivities ?? 0 }
    var weeklyCalories: Int { runData.weeklyStats?.totalCalories ?? 0 }
    
    // Formatted strings
    var formattedDistance: String {
        String(format: "%.2f km", lastActivityDistance)
    }
    
    var formattedDuration: String {
        let minutes = Int(lastActivityDuration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
    
    var formattedCalories: String {
        "\(lastActivityCalories) cal"
    }
    
    var formattedWeeklyDistance: String {
        String(format: "%.1f km", weeklyDistance)
    }
    
    var formattedLastActivityTime: String? {
        guard let lastDate = lastActivityDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastDate, relativeTo: Date())
    }
    
    var activityIcon: String {
        switch lastActivityType.lowercased() {
        case "run":
            return "figure.run"
        case "walk":
            return "figure.walk"
        case "commute":
            return "figure.walk.motion"
        default:
            return "figure.walk"
        }
    }
    
    var activityColor: String {
        switch lastActivityType.lowercased() {
        case "run":
            return "green"
        case "walk":
            return "blue"
        case "commute":
            return "cyan"
        default:
            return "blue"
        }
    }
    
    // Placeholder/preview entry
    static let placeholder = RunWidgetEntry(
        date: Date(),
        runData: .placeholder,
        activeWorkout: nil
    )
    
    static let empty = RunWidgetEntry(
        date: Date(),
        runData: .empty,
        activeWorkout: nil
    )
    
    // Active workout preview
    static let activeRun = RunWidgetEntry(
        date: Date(),
        runData: .empty,
        activeWorkout: WidgetWorkoutState(
            id: UUID(),
            activityType: "run",
            startTime: Date().addingTimeInterval(-600),
            isActive: true,
            isPaused: false,
            elapsedSeconds: 600,
            distanceMeters: 1500,
            caloriesBurned: 85
        )
    )
}

// MARK: - Configuration Intent (for future customization)

struct RunWidgetConfigurationIntent {
    // Placeholder for future widget configuration options
    // e.g., show weekly stats, activity type filter
}
