//
//  WidgetIntents.swift
//  SwasthiCareWidgets
//
//  App Intents for widget quick actions (iOS 16+)
//

import AppIntents
import WidgetKit
import ActivityKit

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
        
        // Load medication data to get medication name
        let currentData = WidgetDataManager.shared.loadMedicationData()
        
        // Check if already marked to prevent duplicates
        let alreadyMarked = currentData.medications.first { $0.id == uuid }?.status == .taken
        if alreadyMarked {
            let medName = currentData.medications.first { $0.id == uuid }?.name ?? "Medication"
            return .result(dialog: "\(medName) already taken ✓")
        }
        
        // Get medication details for confirmation
        guard let medication = currentData.medications.first(where: { $0.id == uuid }) else {
            return .result(dialog: "Medication not found")
        }
        
        // Request confirmation before marking as taken
        try await requestConfirmation(
            result: .result(
                dialog: IntentDialog("Mark \(medication.name) (\(medication.dosage)) as taken?")
            )
        )
        
        // Store pending mark for main app
        WidgetDataManager.shared.storePendingMedicationMark(medicationId: uuid)
        
        // Update widget data optimistically
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
        
        // Trigger widget refresh
        WidgetDataManager.shared.refreshMedicationWidget()
        
        return .result(dialog: "\(medication.name) marked as taken ✓")
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

// MARK: - Start Run Activity Intent

@available(iOS 16.0, *)
struct StartRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Run"
    static var description = IntentDescription("Start a run activity in background")
    static var openAppWhenRun: Bool = false // Don't open app
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check if there's already an active workout
        if WidgetWorkoutManager.shared.hasActiveWorkout() {
            return .result(dialog: "Workout already in progress 🏃")
        }
        
        // Start workout in background with Live Activity
        let success = WidgetWorkoutManager.shared.startWorkout(type: "run")
        
        if success {
            return .result(dialog: "Run started! 🏃‍♂️")
        } else {
            return .result(dialog: "Run started! Open app to track.")
        }
    }
}

// MARK: - Start Walk Activity Intent

@available(iOS 16.0, *)
struct StartWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Walk"
    static var description = IntentDescription("Start a walk activity in background")
    static var openAppWhenRun: Bool = false // Don't open app
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check if there's already an active workout
        if WidgetWorkoutManager.shared.hasActiveWorkout() {
            return .result(dialog: "Workout already in progress 🚶")
        }
        
        // Start workout in background with Live Activity
        let success = WidgetWorkoutManager.shared.startWorkout(type: "walk")
        
        if success {
            return .result(dialog: "Walk started! 🚶‍♂️")
        } else {
            return .result(dialog: "Walk started! Open app to track.")
        }
    }
}

// MARK: - Start Activity Intent (Generic)

@available(iOS 16.0, *)
struct StartActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Activity"
    static var description = IntentDescription("Start a run or walk activity in background")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Activity Type", default: "run")
    var activityType: String
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let type = activityType.lowercased()
        let validType = ["run", "walk", "commute"].contains(type) ? type : "run"
        
        // Check if there's already an active workout
        if WidgetWorkoutManager.shared.hasActiveWorkout() {
            return .result(dialog: "Workout already in progress")
        }
        
        // Start workout in background with Live Activity
        let success = WidgetWorkoutManager.shared.startWorkout(type: validType)
        
        let emoji = validType == "run" ? "🏃‍♂️" : "🚶‍♂️"
        if success {
            return .result(dialog: "\(validType.capitalized) started! \(emoji)")
        } else {
            return .result(dialog: "\(validType.capitalized) started! Open app to track.")
        }
    }
}

// MARK: - Stop Workout Intent

@available(iOS 16.0, *)
struct StopWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Workout"
    static var description = IntentDescription("Stop the current workout")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard WidgetWorkoutManager.shared.hasActiveWorkout() else {
            return .result(dialog: "No active workout")
        }
        
        // Clear the workout state
        WidgetWorkoutManager.shared.clearWorkoutState()
        
        // End all Live Activities
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        // Refresh widget
        WidgetDataManager.shared.refreshRunWidget()
        
        return .result(dialog: "Workout stopped ✓")
    }
}
