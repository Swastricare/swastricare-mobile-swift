//
//  StepsWidgetEntry.swift
//  SwasthiCareWidgets
//
//  Timeline entry for steps widget
//

import WidgetKit
import Foundation

struct StepsWidgetEntry: TimelineEntry {
    let date: Date
    let stepsData: WidgetStepsData
    let configuration: StepsWidgetConfigurationIntent?
    
    init(
        date: Date = Date(),
        stepsData: WidgetStepsData = .empty,
        configuration: StepsWidgetConfigurationIntent? = nil
    ) {
        self.date = date
        self.stepsData = stepsData
        self.configuration = configuration
    }
    
    // Convenience properties
    var currentSteps: Int { stepsData.currentSteps }
    var dailyGoal: Int { stepsData.dailyGoal }
    var percentage: Double { stepsData.percentage }
    var remainingSteps: Int { stepsData.remainingSteps }
    var isGoalMet: Bool { stepsData.isGoalMet }
    var distance: Double { stepsData.distance }
    var calories: Int { stepsData.calories }
    
    // Status color based on progress
    var statusLevel: StepsStatusLevel {
        switch percentage {
        case 0..<0.25:
            return .low
        case 0.25..<0.5:
            return .moderate
        case 0.5..<0.75:
            return .good
        case 0.75..<1.0:
            return .great
        default:
            return .excellent
        }
    }
    
    // Formatted strings
    var formattedSteps: String {
        if currentSteps >= 1000 {
            return String(format: "%.1fK", Double(currentSteps) / 1000.0)
        }
        return "\(currentSteps)"
    }
    
    var formattedGoal: String {
        if dailyGoal >= 1000 {
            return String(format: "%.1fK", Double(dailyGoal) / 1000.0)
        }
        return "\(dailyGoal)"
    }
    
    var formattedDistance: String {
        String(format: "%.2f km", distance)
    }
    
    var formattedCalories: String {
        "\(calories) cal"
    }
    
    // Placeholder/preview entry
    static let placeholder = StepsWidgetEntry(
        date: Date(),
        stepsData: .placeholder
    )
    
    static let empty = StepsWidgetEntry(
        date: Date(),
        stepsData: .empty
    )
}

// MARK: - Status Level

enum StepsStatusLevel {
    case low        // < 25%
    case moderate   // 25-50%
    case good       // 50-75%
    case great      // 75-100%
    case excellent  // 100%+
    
    var message: String {
        switch self {
        case .low:
            return "Time to move!"
        case .moderate:
            return "Keep going"
        case .good:
            return "Good progress"
        case .great:
            return "Almost there!"
        case .excellent:
            return "Goal reached! 🎉"
        }
    }
}

// MARK: - Configuration Intent (for future customization)

struct StepsWidgetConfigurationIntent {
    // Placeholder for future widget configuration options
    // e.g., show/hide distance, custom goal
}
