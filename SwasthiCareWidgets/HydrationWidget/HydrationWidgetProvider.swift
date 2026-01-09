//
//  HydrationWidgetProvider.swift
//  SwasthiCareWidgets
//
//  Timeline provider for hydration widget
//

import WidgetKit
import SwiftUI
import Foundation

// #region agent log helper
func logDebugH(_ location: String, _ message: String, _ data: [String: Any] = [:], hypothesisId: String = "") {
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

struct HydrationWidgetProvider: TimelineProvider {
    
    typealias Entry = HydrationWidgetEntry
    
    // MARK: - Placeholder
    
    func placeholder(in context: Context) -> HydrationWidgetEntry {
        // #region agent log
        logDebugH("HydrationWidgetProvider.swift:31", "placeholder called", ["isPreview": context.isPreview], hypothesisId: "H3,H4")
        // #endregion
        return HydrationWidgetEntry.placeholder
    }
    
    // MARK: - Snapshot
    
    func getSnapshot(in context: Context, completion: @escaping (HydrationWidgetEntry) -> Void) {
        // #region agent log
        logDebugH("HydrationWidgetProvider.swift:40", "getSnapshot called", ["isPreview": context.isPreview], hypothesisId: "H3,H4")
        // #endregion
        if context.isPreview {
            // Show placeholder data in widget gallery
            completion(.placeholder)
        } else {
            // Load real data for snapshot
            let data = WidgetDataManager.shared.loadHydrationData()
            let entry = HydrationWidgetEntry(date: Date(), hydrationData: data)
            completion(entry)
        }
    }
    
    // MARK: - Timeline
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationWidgetEntry>) -> Void) {
        let currentDate = Date()
        let data = WidgetDataManager.shared.loadHydrationData()
        
        // Create entries for the timeline
        var entries: [HydrationWidgetEntry] = []
        
        // Current entry
        let currentEntry = HydrationWidgetEntry(date: currentDate, hydrationData: data)
        entries.append(currentEntry)
        
        // Schedule refresh based on time of day
        let refreshInterval = calculateRefreshInterval()
        let nextRefresh = currentDate.addingTimeInterval(refreshInterval)
        
        // Create timeline with refresh policy
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }
    
    // MARK: - Helpers
    
    /// Calculate refresh interval based on time of day
    private func calculateRefreshInterval() -> TimeInterval {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // More frequent updates during active hours (6 AM - 10 PM)
        if hour >= 6 && hour < 22 {
            return 15 * 60 // 15 minutes
        } else {
            // Less frequent at night
            return 60 * 60 // 1 hour
        }
    }
}

