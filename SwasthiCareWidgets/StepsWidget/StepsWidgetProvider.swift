//
//  StepsWidgetProvider.swift
//  SwasthiCareWidgets
//
//  Timeline provider for steps widget
//

import WidgetKit
import SwiftUI
import Foundation

struct StepsWidgetProvider: TimelineProvider {
    
    typealias Entry = StepsWidgetEntry
    
    // MARK: - Placeholder
    
    func placeholder(in context: Context) -> StepsWidgetEntry {
        return StepsWidgetEntry.placeholder
    }
    
    // MARK: - Snapshot
    
    func getSnapshot(in context: Context, completion: @escaping (StepsWidgetEntry) -> Void) {
        if context.isPreview {
            // Show placeholder data in widget gallery
            completion(.placeholder)
        } else {
            // Load real data for snapshot
            let data = WidgetDataManager.shared.loadStepsData()
            let entry = StepsWidgetEntry(date: Date(), stepsData: data)
            completion(entry)
        }
    }
    
    // MARK: - Timeline
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsWidgetEntry>) -> Void) {
        let currentDate = Date()
        let data = WidgetDataManager.shared.loadStepsData()
        
        // Create entries for the timeline
        var entries: [StepsWidgetEntry] = []
        
        // Current entry
        let currentEntry = StepsWidgetEntry(date: currentDate, stepsData: data)
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
