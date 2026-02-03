//
//  WidgetService.swift
//  swastricare-mobile-swift
//
//  Service to manage widget data sharing with App Group
//  This file should be added to BOTH main app and widget extension targets
//

import Foundation
import WidgetKit

// MARK: - App Group Configuration

enum WidgetAppGroup {
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
    
    init(from adherenceStatus: AdherenceStatus) {
        switch adherenceStatus {
        case .pending: self = .pending
        case .taken, .late, .early: self = .taken
        case .missed: self = .missed
        case .skipped: self = .skipped
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
        medications: [],
        takenCount: 0,
        totalCount: 0,
        lastUpdated: Date()
    )
    
    static let empty = WidgetMedicationData(
        medications: [],
        takenCount: 0,
        totalCount: 0,
        lastUpdated: Date()
    )
}

// MARK: - Steps / Run Widget Models (must match widget extension)

struct WidgetStepsData: Codable {
    let currentSteps: Int
    let dailyGoal: Int
    let distance: Double // in km
    let calories: Int
    let lastUpdated: Date
}

struct WidgetRunActivity: Codable {
    let name: String
    let type: String // "walk", "run", "commute"
    let distance: Double // in km
    let duration: TimeInterval // in seconds
    let calories: Int
    let date: Date
}

struct WidgetWeeklyRunStats: Codable {
    let totalDistance: Double
    let totalActivities: Int
    let totalCalories: Int
}

struct WidgetRunData: Codable {
    let lastActivity: WidgetRunActivity?
    let weeklyStats: WidgetWeeklyRunStats?
    let lastUpdated: Date
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

// MARK: - Widget Service

final class WidgetService {
    
    static let shared = WidgetService()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Storage keys
    private enum Keys {
        static let hydrationData = "widget_hydration_data"
        static let medicationData = "widget_medication_data"
        static let stepsData = "widget_steps_data"
        static let runData = "widget_run_data"
        static let pendingWaterLog = "widget_pending_water_log"
        static let pendingMedicationMarks = "widget_pending_medication_marks"
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Hydration Data
    
    /// Save hydration data for widget consumption
    func saveHydrationData(currentIntake: Int, dailyGoal: Int, lastLoggedTime: Date?) {
        guard let defaults = WidgetAppGroup.sharedDefaults else {
            print("⚠️ WidgetService: Failed to access App Group")
            return
        }
        
        let data = WidgetHydrationData(
            currentIntake: currentIntake,
            dailyGoal: dailyGoal,
            lastLoggedTime: lastLoggedTime,
            lastUpdated: Date()
        )
        
        do {
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: Keys.hydrationData)
            defaults.synchronize()
            print("💧 WidgetService: Saved hydration - \(currentIntake)/\(dailyGoal)ml")
            
            // Trigger widget refresh immediately
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("⚠️ WidgetService: Failed to encode hydration data - \(error)")
        }
    }
    
    /// Load hydration data
    func loadHydrationData() -> WidgetHydrationData {
        guard let defaults = WidgetAppGroup.sharedDefaults,
              let data = defaults.data(forKey: Keys.hydrationData) else {
            return .empty
        }
        
        do {
            return try decoder.decode(WidgetHydrationData.self, from: data)
        } catch {
            return .empty
        }
    }
    
    // MARK: - Medication Data
    
    /// Save medication data for widget consumption
    func saveMedicationData(medications: [MedicationWithAdherence]) {
        guard let defaults = WidgetAppGroup.sharedDefaults else {
            print("⚠️ WidgetService: Failed to access App Group")
            return
        }
        
        var widgetItems: [WidgetMedicationItem] = []
        var takenCount = 0
        var totalCount = 0
        
        for medWithAdherence in medications {
            for dose in medWithAdherence.todayDoses {
                totalCount += 1
                if dose.status == .taken {
                    takenCount += 1
                }
                
                let item = WidgetMedicationItem(
                    id: dose.id,
                    name: medWithAdherence.medication.name,
                    dosage: medWithAdherence.medication.dosage,
                    scheduledTime: dose.scheduledTime,
                    status: WidgetMedicationStatus(from: dose.status),
                    typeIcon: medWithAdherence.medication.type.icon
                )
                widgetItems.append(item)
            }
        }
        
        // Sort by scheduled time
        widgetItems.sort { $0.scheduledTime < $1.scheduledTime }
        
        let data = WidgetMedicationData(
            medications: widgetItems,
            takenCount: takenCount,
            totalCount: totalCount,
            lastUpdated: Date()
        )
        
        do {
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: Keys.medicationData)
            defaults.synchronize()
            print("💊 WidgetService: Saved medications - \(takenCount)/\(totalCount) taken")
            
            // Trigger widget refresh immediately
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("⚠️ WidgetService: Failed to encode medication data - \(error)")
        }
    }

    // MARK: - Steps Data

    /// Save steps data for Steps widget consumption
    func saveStepsData(currentSteps: Int, dailyGoal: Int = 10000, distanceKm: Double, calories: Int) {
        guard let defaults = WidgetAppGroup.sharedDefaults else {
            print("⚠️ WidgetService: Failed to access App Group")
            return
        }

        let data = WidgetStepsData(
            currentSteps: currentSteps,
            dailyGoal: dailyGoal,
            distance: distanceKm,
            calories: calories,
            lastUpdated: Date()
        )

        do {
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: Keys.stepsData)
            defaults.synchronize()
            WidgetCenter.shared.reloadTimelines(ofKind: "StepsWidget")
        } catch {
            print("⚠️ WidgetService: Failed to encode steps data - \(error)")
        }
    }

    // MARK: - Run Data

    /// Save run data for Run widget consumption
    func saveRunData(lastActivity: WidgetRunActivity?, weeklyStats: WidgetWeeklyRunStats?) {
        guard let defaults = WidgetAppGroup.sharedDefaults else {
            print("⚠️ WidgetService: Failed to access App Group")
            return
        }

        let data = WidgetRunData(
            lastActivity: lastActivity,
            weeklyStats: weeklyStats,
            lastUpdated: Date()
        )

        do {
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: Keys.runData)
            defaults.synchronize()
            WidgetCenter.shared.reloadTimelines(ofKind: "RunWidget")
        } catch {
            print("⚠️ WidgetService: Failed to encode run data - \(error)")
        }
    }
    
    /// Load medication data
    func loadMedicationData() -> WidgetMedicationData {
        guard let defaults = WidgetAppGroup.sharedDefaults,
              let data = defaults.data(forKey: Keys.medicationData) else {
            return .empty
        }
        
        do {
            return try decoder.decode(WidgetMedicationData.self, from: data)
        } catch {
            return .empty
        }
    }
    
    // MARK: - Quick Actions (Pending operations from widget)
    
    /// Get and clear pending water log from widget
    func getPendingWaterLog() -> PendingWaterLog? {
        guard let defaults = WidgetAppGroup.sharedDefaults,
              let data = defaults.data(forKey: Keys.pendingWaterLog) else {
            return nil
        }
        
        // Clear after reading
        defaults.removeObject(forKey: Keys.pendingWaterLog)
        defaults.synchronize()
        
        return try? decoder.decode(PendingWaterLog.self, from: data)
    }
    
    /// Get and clear all pending medication marks from widget
    func getPendingMedicationMarks() -> [PendingMedicationMark] {
        guard let defaults = WidgetAppGroup.sharedDefaults,
              let data = defaults.data(forKey: Keys.pendingMedicationMarks) else {
            return []
        }
        
        // Clear after reading
        defaults.removeObject(forKey: Keys.pendingMedicationMarks)
        defaults.synchronize()
        
        if let marks = try? decoder.decode([PendingMedicationMark].self, from: data) {
            print("💊 WidgetService: Retrieved \(marks.count) pending medication mark(s)")
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
    
    /// Trigger refresh for all widgets
    func refreshAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 WidgetService: Refreshed all widgets")
    }
    
    /// Trigger refresh for hydration widget only
    func refreshHydrationWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "HydrationWidget")
    }
    
    /// Trigger refresh for medication widget only
    func refreshMedicationWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "MedicationWidget")
    }

    func refreshStepsWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "StepsWidget")
    }

    func refreshRunWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "RunWidget")
    }
    
    // MARK: - Process Pending Actions
    
    /// Process any pending actions from widget (call on app launch/foreground)
    func processPendingActions(
        hydrationHandler: ((Int) async -> Void)?,
        medicationHandler: ((UUID) async -> Void)?
    ) async {
        // Process pending water logs
        if let pendingWater = getPendingWaterLog() {
            print("💧 WidgetService: Processing pending water log - \(pendingWater.amount)ml")
            await hydrationHandler?(pendingWater.amount)
        }
        
        // Process all pending medication marks
        let pendingMeds = getPendingMedicationMarks()
        if !pendingMeds.isEmpty {
            print("💊 WidgetService: Processing \(pendingMeds.count) pending medication mark(s)")
            for pendingMed in pendingMeds {
                print("💊 WidgetService: Processing medication mark - \(pendingMed.medicationId)")
                await medicationHandler?(pendingMed.medicationId)
            }
        }
    }
}
