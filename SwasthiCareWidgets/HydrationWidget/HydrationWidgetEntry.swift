//
//  HydrationWidgetEntry.swift
//  SwasthiCareWidgets
//
//  Timeline entry for hydration widget
//

import WidgetKit
import Foundation

struct HydrationWidgetEntry: TimelineEntry {
    let date: Date
    let hydrationData: WidgetHydrationData
    let configuration: HydrationWidgetConfigurationIntent?
    
    init(
        date: Date = Date(),
        hydrationData: WidgetHydrationData = .empty,
        configuration: HydrationWidgetConfigurationIntent? = nil
    ) {
        self.date = date
        self.hydrationData = hydrationData
        self.configuration = configuration
    }
    
    // Convenience properties
    var currentIntake: Int { hydrationData.currentIntake }
    var dailyGoal: Int { hydrationData.dailyGoal }
    var percentage: Double { hydrationData.percentage }
    var remainingMl: Int { hydrationData.remainingMl }
    var isGoalMet: Bool { hydrationData.isGoalMet }
    var lastLoggedTime: Date? { hydrationData.lastLoggedTime }
    
    // Status color based on progress
    var statusLevel: HydrationStatusLevel {
        switch percentage {
        case 0..<0.25:
            return .critical
        case 0.25..<0.5:
            return .warning
        case 0.5..<0.75:
            return .good
        case 0.75..<1.0:
            return .great
        default:
            return .excellent
        }
    }
    
    // Formatted strings
    var formattedIntake: String {
        if currentIntake >= 1000 {
            return String(format: "%.1fL", Double(currentIntake) / 1000.0)
        }
        return "\(currentIntake)ml"
    }
    
    var formattedGoal: String {
        if dailyGoal >= 1000 {
            return String(format: "%.1fL", Double(dailyGoal) / 1000.0)
        }
        return "\(dailyGoal)ml"
    }
    
    var formattedRemaining: String {
        if remainingMl >= 1000 {
            return String(format: "%.1fL", Double(remainingMl) / 1000.0)
        }
        return "\(remainingMl)ml"
    }
    
    var formattedLastLogged: String? {
        guard let lastTime = lastLoggedTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastTime, relativeTo: Date())
    }
    
    // Placeholder/preview entry
    static let placeholder = HydrationWidgetEntry(
        date: Date(),
        hydrationData: .placeholder
    )
    
    static let empty = HydrationWidgetEntry(
        date: Date(),
        hydrationData: .empty
    )
}

// MARK: - Status Level

enum HydrationStatusLevel {
    case critical   // < 25%
    case warning    // 25-50%
    case good       // 50-75%
    case great      // 75-100%
    case excellent  // 100%+
    
    var message: String {
        switch self {
        case .critical:
            return "Drink water now!"
        case .warning:
            return "Keep drinking"
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

struct HydrationWidgetConfigurationIntent {
    // Placeholder for future widget configuration options
    // e.g., show/hide remaining, preferred unit (ml/L)
}
