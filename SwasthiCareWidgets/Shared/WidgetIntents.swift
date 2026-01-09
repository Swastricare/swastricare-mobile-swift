//
//  WidgetIntents.swift
//  SwasthiCareWidgets
//
//  App Intents for widget quick actions (iOS 16+)
//

import AppIntents
import WidgetKit

// MARK: - Log Water Intent

@available(iOS 16.0, *)
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Log water intake from widget")
    
    @Parameter(title: "Amount (ml)", default: 250)
    var amount: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) ml of water")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Store the pending log for the main app to process
        WidgetDataManager.shared.storePendingWaterLog(amount: amount)
        
        // Update widget data optimistically
        var currentData = WidgetDataManager.shared.loadHydrationData()
        let updatedData = WidgetHydrationData(
            currentIntake: currentData.currentIntake + amount,
            dailyGoal: currentData.dailyGoal,
            lastLoggedTime: Date(),
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveHydrationData(updatedData)
        
        // Trigger widget refresh
        WidgetDataManager.shared.refreshHydrationWidget()
        
        return .result(dialog: "Logged \(amount)ml 💧")
    }
}

// MARK: - Quick Log 250ml Intent

@available(iOS 16.0, *)
struct QuickLog250mlIntent: AppIntent {
    static var title: LocalizedStringResource = "Log 250ml"
    static var description = IntentDescription("Quickly log 250ml of water")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetDataManager.shared.storePendingWaterLog(amount: 250)
        
        var currentData = WidgetDataManager.shared.loadHydrationData()
        let updatedData = WidgetHydrationData(
            currentIntake: currentData.currentIntake + 250,
            dailyGoal: currentData.dailyGoal,
            lastLoggedTime: Date(),
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveHydrationData(updatedData)
        WidgetDataManager.shared.refreshHydrationWidget()
        
        return .result(dialog: "+250ml 💧")
    }
}

// MARK: - Quick Log 500ml Intent

@available(iOS 16.0, *)
struct QuickLog500mlIntent: AppIntent {
    static var title: LocalizedStringResource = "Log 500ml"
    static var description = IntentDescription("Quickly log 500ml of water")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetDataManager.shared.storePendingWaterLog(amount: 500)
        
        var currentData = WidgetDataManager.shared.loadHydrationData()
        let updatedData = WidgetHydrationData(
            currentIntake: currentData.currentIntake + 500,
            dailyGoal: currentData.dailyGoal,
            lastLoggedTime: Date(),
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveHydrationData(updatedData)
        WidgetDataManager.shared.refreshHydrationWidget()
        
        return .result(dialog: "+500ml 💧")
    }
}

// MARK: - Mark Medication Taken Intent

@available(iOS 16.0, *)
struct MarkMedicationTakenIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Medication Taken"
    static var description = IntentDescription("Mark a medication as taken")
    
    @Parameter(title: "Medication ID")
    var medicationId: String
    
    init() {
        self.medicationId = ""
    }
    
    init(medicationId: String) {
        self.medicationId = medicationId
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uuid = UUID(uuidString: medicationId) else {
            return .result(dialog: "Invalid medication")
        }
        
        // Store pending mark for main app
        WidgetDataManager.shared.storePendingMedicationMark(medicationId: uuid)
        
        // Update widget data optimistically
        var currentData = WidgetDataManager.shared.loadMedicationData()
        let updatedMedications = currentData.medications.map { med -> WidgetMedicationItem in
            if med.id == uuid {
                return WidgetMedicationItem(
                    id: med.id,
                    name: med.name,
                    dosage: med.dosage,
                    scheduledTime: med.scheduledTime,
                    status: .taken,
                    typeIcon: med.typeIcon
                )
            }
            return med
        }
        
        let updatedData = WidgetMedicationData(
            medications: updatedMedications,
            takenCount: currentData.takenCount + 1,
            totalCount: currentData.totalCount,
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveMedicationData(updatedData)
        WidgetDataManager.shared.refreshMedicationWidget()
        
        // Find medication name for feedback
        let medName = currentData.medications.first { $0.id == uuid }?.name ?? "Medication"
        return .result(dialog: "\(medName) marked as taken ✓")
    }
}

// MARK: - Open Hydration View Intent

@available(iOS 16.0, *)
struct OpenHydrationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Hydration"
    static var description = IntentDescription("Open the hydration tracking view")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // This will open the app - deep linking handled by URL scheme
        return .result()
    }
}

// MARK: - Open Medications View Intent

@available(iOS 16.0, *)
struct OpenMedicationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Medications"
    static var description = IntentDescription("Open the medications tracking view")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
