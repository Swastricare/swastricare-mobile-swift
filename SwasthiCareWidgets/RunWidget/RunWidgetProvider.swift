//
//  RunWidgetProvider.swift
//  SwasthiCareWidgets
//
//  Timeline provider for run widget
//

import WidgetKit
import SwiftUI
import Foundation

struct RunWidgetProvider: TimelineProvider {
    
    typealias Entry = RunWidgetEntry
    
    // MARK: - Placeholder
    
    func placeholder(in context: Context) -> RunWidgetEntry {
        return RunWidgetEntry.placeholder
    }
    
    // MARK: - Snapshot
    
    func getSnapshot(in context: Context, completion: @escaping (RunWidgetEntry) -> Void) {
        if context.isPreview {
            // Show placeholder data in widget gallery
            completion(.placeholder)
        } else {
            // Load real data for snapshot
            let data = WidgetDataManager.shared.loadRunData()
            let activeWorkout = WidgetWorkoutManager.shared.loadWorkoutState()
            let entry = RunWidgetEntry(date: Date(), runData: data, activeWorkout: activeWorkout?.isActive == true ? activeWorkout : nil)
            completion(entry)
        }
    }
    
    // MARK: - Timeline
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RunWidgetEntry>) -> Void) {
        let currentDate = Date()
        let data = WidgetDataManager.shared.loadRunData()
        let activeWorkout = WidgetWorkoutManager.shared.loadWorkoutState()
        
        // Create entries for the timeline
        var entries: [RunWidgetEntry] = []
        
        // Current entry - include active workout if exists
        let currentEntry = RunWidgetEntry(
            date: currentDate,
            runData: data,
            activeWorkout: activeWorkout?.isActive == true ? activeWorkout : nil
        )
        entries.append(currentEntry)
        
        // Schedule refresh based on whether there's an active workout
        let refreshInterval: TimeInterval
        if activeWorkout?.isActive == true {
            // Refresh more frequently during active workout
            refreshInterval = 30 // 30 seconds
        } else {
            refreshInterval = calculateRefreshInterval()
        }
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
            return 30 * 60 // 30 minutes
        } else {
            // Less frequent at night
            return 60 * 60 // 1 hour
        }
    }
}
