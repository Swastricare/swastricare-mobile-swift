//
//  SwasthiCareWidgets.swift
//  SwasthiCareWidgets
//
//  Main widget bundle - registers all SwasthiCare widgets
//

import WidgetKit
import SwiftUI
import Foundation

// #region agent log helper
func logDebug(_ location: String, _ message: String, _ data: [String: Any] = [:], hypothesisId: String = "") {
    let logPath = "/Users/onwords/i do coding/i do flutter coding/swastricare-mobile-swift/.cursor/debug.log"
    let payload: [String: Any] = ["location": location, "message": message, "data": data, "timestamp": Date().timeIntervalSince1970 * 1000, "sessionId": "debug-session", "runId": "run1", "hypothesisId": hypothesisId]
    if let jsonData = try? JSONSerialization.data(withJSONObject: payload), let jsonString = String(data: jsonData, encoding: .utf8) {
        if let fileHandle = FileHandle(forWritingAtPath: logPath) ?? (try? FileHandle(forUpdating: URL(fileURLWithPath: logPath))) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            if let data = (jsonString + "\n").data(using: .utf8) { fileHandle.write(data) }
        } else if let data = (jsonString + "\n").data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: logPath), options: .atomic)
        }
    }
}
// #endregion

// MARK: - Hydration Widget

struct HydrationWidget: Widget {
    let kind: String = "HydrationWidget"
    
    // #region agent log
    init() { logDebug("SwasthiCareWidgets.swift:28", "HydrationWidget init", [:], hypothesisId: "H2,H3") }
    // #endregion
    
    var body: some WidgetConfiguration {
        // #region agent log
        let _ = logDebug("SwasthiCareWidgets.swift:33", "HydrationWidget body computed", ["kind": kind], hypothesisId: "H2")
        // #endregion
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
    
    // #region agent log
    init() { logDebug("SwasthiCareWidgets.swift:44", "MedicationWidget init", [:], hypothesisId: "H2,H3") }
    // #endregion
    
    var body: some WidgetConfiguration {
        // #region agent log
        let _ = logDebug("SwasthiCareWidgets.swift:49", "MedicationWidget body computed", ["kind": kind], hypothesisId: "H2")
        // #endregion
        return StaticConfiguration(kind: kind, provider: MedicationWidgetProvider()) { entry in
            MedicationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Medication Reminder")
        .description("Track your daily medications and never miss a dose.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct SwasthiCareWidgetsBundle: WidgetBundle {
    // #region agent log
    init() { logDebug("SwasthiCareWidgets.swift:62", "SwasthiCareWidgetsBundle @main init - ENTRY POINT", [:], hypothesisId: "H2") }
    // #endregion
    
    var body: some Widget {
        // #region agent log
        let _ = logDebug("SwasthiCareWidgets.swift:67", "WidgetBundle body computed", [:], hypothesisId: "H2")
        // #endregion
        HydrationWidget()
        MedicationWidget()
    }
}

