//
//  MedicationWidgetProvider.swift
//  SwasthiCareWidgets
//
//  Timeline provider for medication widget
//

import WidgetKit
import SwiftUI

struct MedicationWidgetProvider: TimelineProvider {
    
    typealias Entry = MedicationWidgetEntry
    
    // MARK: - Placeholder
    
    func placeholder(in context: Context) -> MedicationWidgetEntry {
        MedicationWidgetEntry.placeholder
    }
    
    // MARK: - Snapshot
    
    func getSnapshot(in context: Context, completion: @escaping (MedicationWidgetEntry) -> Void) {
        if context.isPreview {
            // Show placeholder data in widget gallery
            completion(.placeholder)
        } else {
            // Load real data for snapshot
            let data = WidgetDataManager.shared.loadMedicationData()
            let entry = MedicationWidgetEntry(date: Date(), medicationData: data)
            completion(entry)
        }
    }
    
    // MARK: - Timeline
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MedicationWidgetEntry>) -> Void) {
        let currentDate = Date()
        let data = WidgetDataManager.shared.loadMedicationData()
        
        // Create entries for the timeline
        var entries: [MedicationWidgetEntry] = []
        
        // Current entry
        let currentEntry = MedicationWidgetEntry(date: currentDate, medicationData: data)
        entries.append(currentEntry)
        
        // Add entries for upcoming medication times for better timeline experience
        let upcomingTimes = getUpcomingMedicationTimes(from: data.medications, after: currentDate)
        for time in upcomingTimes.prefix(5) { // Max 5 future entries
            let futureEntry = MedicationWidgetEntry(date: time, medicationData: data)
            entries.append(futureEntry)
        }
        
        // Calculate next refresh time
        let refreshDate = calculateNextRefresh(currentDate: currentDate, upcomingTimes: upcomingTimes)
        
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
    
    // MARK: - Helpers
    
    /// Get upcoming medication times for timeline entries
    private func getUpcomingMedicationTimes(from medications: [WidgetMedicationItem], after date: Date) -> [Date] {
        medications
            .filter { $0.status == .pending && $0.scheduledTime > date }
            .map { $0.scheduledTime }
            .sorted()
    }
    
    /// Calculate when to refresh the timeline
    private func calculateNextRefresh(currentDate: Date, upcomingTimes: [Date]) -> Date {
        // If there's an upcoming medication in the next hour, refresh at that time
        if let nextMedTime = upcomingTimes.first,
           nextMedTime.timeIntervalSince(currentDate) < 3600 {
            return nextMedTime.addingTimeInterval(60) // Refresh 1 minute after
        }
        
        // Otherwise, refresh every 5 minutes during active hours
        let hour = Calendar.current.component(.hour, from: currentDate)
        if hour >= 6 && hour < 22 {
            return currentDate.addingTimeInterval(5 * 60) // 5 minutes
        } else {
            return currentDate.addingTimeInterval(30 * 60) // 30 minutes at night
        }
    }
}

