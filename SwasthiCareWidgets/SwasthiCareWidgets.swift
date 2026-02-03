//
//  SwasthiCareWidgets.swift
//  SwasthiCareWidgets
//
//  Main widget bundle - registers all SwasthiCare widgets
//

import WidgetKit
import SwiftUI

// MARK: - Hydration Widget

struct HydrationWidget: Widget {
    let kind: String = "HydrationWidget"
    
    var body: some WidgetConfiguration {
        return StaticConfiguration(kind: kind, provider: HydrationWidgetProvider()) { entry in
            HydrationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hydration Tracker")
        .description("Track your daily water intake and stay hydrated.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Medication Widget

struct MedicationWidget: Widget {
    let kind: String = "MedicationWidget"
    
    var body: some WidgetConfiguration {
        return StaticConfiguration(kind: kind, provider: MedicationWidgetProvider()) { entry in
            MedicationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Medication Reminder")
        .description("Track your daily medications and never miss a dose.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Steps Widget

struct StepsWidget: Widget {
    let kind: String = "StepsWidget"
    
    var body: some WidgetConfiguration {
        return StaticConfiguration(kind: kind, provider: StepsWidgetProvider()) { entry in
            StepsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Steps Tracker")
        .description("Track your daily steps and distance toward your goal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Run Widget

struct RunWidget: Widget {
    let kind: String = "RunWidget"
    
    var body: some WidgetConfiguration {
        return StaticConfiguration(kind: kind, provider: RunWidgetProvider()) { entry in
            RunWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Run Activity")
        .description("View your latest run or walk activity stats.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct SwasthiCareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HydrationWidget()
        MedicationWidget()
        StepsWidget()
        RunWidget()
        WorkoutLiveActivityWidget()
    }
}

