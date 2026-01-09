//
//  WidgetDataManager.swift
//  SwasthiCareWidgets
//
//  Manages data sharing between main app and widgets via App Group
//

import Foundation
import WidgetKit

// MARK: - App Group Configuration

enum AppGroupConfig {
    static let suiteName = "group.com.swasthicare.shared"
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

// MARK: - Widget Data Models

/// Simplified hydration data for widget display
struct WidgetHydrationData: Codable {
    let currentIntake: Int
    let dailyGoal: Int
    let lastLoggedTime: Date?
    let lastUpdated: Date
    
    var percentage: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(currentIntake) / Double(dailyGoal))
    }
    
    var remainingMl: Int {
        max(0, dailyGoal - currentIntake)
    }
    
    var isGoalMet: Bool {
        currentIntake >= dailyGoal
    }
    
    static let placeholder = WidgetHydrationData(
        currentIntake: 1250,
        dailyGoal: 2500,
        lastLoggedTime: Date(),
        lastUpdated: Date()
    )
    
    static let empty = WidgetHydrationData(
        currentIntake: 0,
        dailyGoal: 2500,
        lastLoggedTime: nil,
        lastUpdated: Date()
    )
}

/// Simplified medication data for widget display
struct WidgetMedicationItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let dosage: String
    let scheduledTime: Date
    let status: WidgetMedicationStatus
    let typeIcon: String
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
    
    var isOverdue: Bool {
        status == .pending && scheduledTime < Date().addingTimeInterval(-2 * 3600)
    }
    
    var isUpcoming: Bool {
        status == .pending && scheduledTime > Date() && scheduledTime <= Date().addingTimeInterval(3600)
    }
}

enum WidgetMedicationStatus: String, Codable {
    case pending
    case taken
    case missed
    case skipped
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .taken: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .skipped: return "xmark.circle.fill"
        }
    }
}

/// Container for all medication widget data
struct WidgetMedicationData: Codable {
    let medications: [WidgetMedicationItem]
    let takenCount: Int
    let totalCount: Int
    let lastUpdated: Date
    
    var adherencePercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(takenCount) / Double(totalCount)
    }
    
    var nextMedication: WidgetMedicationItem? {
        medications
            .filter { $0.status == .pending && $0.scheduledTime > Date() }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .first
    }
    
    var overdueMedication: WidgetMedicationItem? {
        medications.first { $0.isOverdue }
    }
    
    static let placeholder = WidgetMedicationData(
        medications: [
            WidgetMedicationItem(
                id: UUID(),
                name: "Vitamin D",
                dosage: "1000 IU",
                scheduledTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                status: .taken,
                typeIcon: "pills.fill"
            ),
            WidgetMedicationItem(
                id: UUID(),
                name: "Omega-3",
                dosage: "1 capsule",
                scheduledTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
                status: .pending,
                typeIcon: "pills.fill"
            )
        ],
        takenCount: 1,
        totalCount: 3,
        lastUpdated: Date()
    )
    
    static let empty = WidgetMedicationData(
        medications: [],
        takenCount: 0,
        totalCount: 0,
        lastUpdated: Date()
    )
}

// MARK: - Widget Data Manager

final class WidgetDataManager {
    
    static let shared = WidgetDataManager()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Storage keys
    private enum Keys {
        static let hydrationData = "widget_hydration_data"
        static let medicationData = "widget_medication_data"
        static let pendingWaterLog = "widget_pending_water_log"
        static let pendingMedicationMarks = "widget_pending_medication_marks"
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Hydration Data
    
    /// Save hydration data for widget consumption
    func saveHydrationData(_ data: WidgetHydrationData) {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            print("⚠️ WidgetDataManager: Failed to access App Group")
            return
        }
        
        do {
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: Keys.hydrationData)
            defaults.synchronize()
            print("💧 WidgetDataManager: Saved hydration data - \(data.currentIntake)/\(data.dailyGoal)ml")
        } catch {
            print("⚠️ WidgetDataManager: Failed to encode hydration data - \(error)")
        }
    }
    
    /// Load hydration data for widget display
    func loadHydrationData() -> WidgetHydrationData {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            print("⚠️ WidgetDataManager: Failed to access App Group")
            return .empty
        }
        
        guard let data = defaults.data(forKey: Keys.hydrationData) else {
            return .empty
        }
        
        do {
            let decoded = try decoder.decode(WidgetHydrationData.self, from: data)
            return decoded
        } catch {
            print("⚠️ WidgetDataManager: Failed to decode hydration data - \(error)")
            return .empty
        }
    }
    
    // MARK: - Medication Data
    
    /// Save medication data for widget consumption
    func saveMedicationData(_ data: WidgetMedicationData) {
        guard let defaults = AppGroupConfig.sharedDefaults else {
            print("⚠️ WidgetDataManager: Failed to access App Group")
            return
        }
        
        do {
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: Keys.medicationData)
            defaults.synchronize()
            print("💊 WidgetDataManager: Saved medication data - \(data.takenCount)/\(data.totalCount) taken")
        } catch {
            print("⚠️ WidgetDataManager: Failed to encode medication data - \(error)")
        }
    }
    
    /// Load medication data for widget display
    func loadMedicationData() -> WidgetMedicationData {
        guard let defaults = AppGroupConfig.sharedDefaults,
              let data = defaults.data(forKey: Keys.medicationData) else {
            return .empty
        }
        
        do {
            return try decoder.decode(WidgetMedicationData.self, from: data)
        } catch {
            print("⚠️ WidgetDataManager: Failed to decode medication data - \(error)")
            return .empty
        }
    }
    
    // MARK: - Quick Actions (Pending operations from widget)
    
    /// Store pending water log from widget quick action (accumulates if existing)
    func storePendingWaterLog(amount: Int) {
        guard let defaults = AppGroupConfig.sharedDefaults else { return }
        
        // Check for existing pending log and accumulate
        var totalAmount = amount
        if let existingData = defaults.data(forKey: Keys.pendingWaterLog),
           let existing = try? decoder.decode(PendingWaterLog.self, from: existingData) {
            totalAmount += existing.amount
            print("💧 WidgetDataManager: Accumulating pending water - \(existing.amount) + \(amount) = \(totalAmount)ml")
        }
        
        let pending = PendingWaterLog(amount: totalAmount, timestamp: Date())
        if let encoded = try? encoder.encode(pending) {
            defaults.set(encoded, forKey: Keys.pendingWaterLog)
            defaults.synchronize()
            print("💧 WidgetDataManager: Stored pending water log - \(totalAmount)ml")
        }
    }
    
    /// Get and clear pending water log
    func getPendingWaterLog() -> PendingWaterLog? {
        guard let defaults = AppGroupConfig.sharedDefaults,
              let data = defaults.data(forKey: Keys.pendingWaterLog) else {
            return nil
        }
        
        // Clear after reading
        defaults.removeObject(forKey: Keys.pendingWaterLog)
        defaults.synchronize()
        
        return try? decoder.decode(PendingWaterLog.self, from: data)
    }
    
    /// Store pending medication mark from widget quick action (accumulates multiple marks)
    func storePendingMedicationMark(medicationId: UUID) {
        guard let defaults = AppGroupConfig.sharedDefaults else { return }
        
        // Load existing pending marks and append new one
        var marks: [PendingMedicationMark] = []
        if let existingData = defaults.data(forKey: Keys.pendingMedicationMarks),
           let existing = try? decoder.decode([PendingMedicationMark].self, from: existingData) {
            marks = existing
            print("💊 WidgetDataManager: Found \(existing.count) existing pending medication mark(s)")
        }
        
        // Append new mark
        let newMark = PendingMedicationMark(medicationId: medicationId, timestamp: Date())
        marks.append(newMark)
        
        // Save accumulated marks
        if let encoded = try? encoder.encode(marks) {
            defaults.set(encoded, forKey: Keys.pendingMedicationMarks)
            defaults.synchronize()
            print("💊 WidgetDataManager: Stored \(marks.count) pending medication mark(s)")
        }
    }
    
    /// Get and clear all pending medication marks
    func getPendingMedicationMarks() -> [PendingMedicationMark] {
        guard let defaults = AppGroupConfig.sharedDefaults,
              let data = defaults.data(forKey: Keys.pendingMedicationMarks) else {
            return []
        }
        
        // Clear after reading
        defaults.removeObject(forKey: Keys.pendingMedicationMarks)
        defaults.synchronize()
        
        if let marks = try? decoder.decode([PendingMedicationMark].self, from: data) {
            print("💊 WidgetDataManager: Retrieved \(marks.count) pending medication mark(s)")
            return marks
        }
        
        return []
    }
    
    /// Legacy support - Get single pending medication mark (deprecated)
    @available(*, deprecated, message: "Use getPendingMedicationMarks() instead")
    func getPendingMedicationMark() -> PendingMedicationMark? {
        return getPendingMedicationMarks().first
    }
    
    // MARK: - Widget Refresh
    
    /// Trigger widget timeline refresh
    func refreshAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 WidgetDataManager: Triggered widget refresh")
    }
    
    /// Trigger specific widget refresh
    func refreshHydrationWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "HydrationWidget")
    }
    
    func refreshMedicationWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "MedicationWidget")
    }
}

// MARK: - Pending Action Models

struct PendingWaterLog: Codable {
    let amount: Int
    let timestamp: Date
}

struct PendingMedicationMark: Codable {
    let medicationId: UUID
    let timestamp: Date
}
