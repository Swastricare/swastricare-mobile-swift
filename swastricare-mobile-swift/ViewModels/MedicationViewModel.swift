//
//  MedicationViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  Medication reminder state management
//

import Foundation
import Combine
import WidgetKit

@MainActor
final class MedicationViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var todaysMedications: [MedicationWithAdherence] = []
    @Published private(set) var adherenceStatistics: AdherenceStatistics?
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var activeMedicationsCount: Int {
        medications.filter { $0.isActive() }.count
    }
    
    var todayAdherencePercentage: Double {
        adherenceStatistics?.adherencePercentage ?? 0
    }
    
    var takenCount: Int {
        adherenceStatistics?.takenDoses ?? 0
    }
    
    var totalCount: Int {
        adherenceStatistics?.totalDoses ?? 0
    }
    
    var hasOverdueDoses: Bool {
        todaysMedications.contains { $0.overdueDose != nil }
    }
    
    var upcomingDose: MedicationAdherence? {
        todaysMedications
            .compactMap { $0.nextDose }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .first
    }
    
    // MARK: - Dependencies
    
    private let medicationService: MedicationServiceProtocol
    private let supabaseManager = SupabaseManager.shared
    private let widgetService = WidgetService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(medicationService: MedicationServiceProtocol = MedicationService.shared) {
        self.medicationService = medicationService
        
        // Load data on init
        Task {
            await loadMedications()
            await checkMissedDoses()
        }
        
        // Set up periodic checks for missed doses (every 5 minutes)
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkMissedDoses()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Operations
    
    /// Load all medications from local storage
    func loadMedications() async {
        isLoading = true
        
        medications = medicationService.loadMedications()
        todaysMedications = medicationService.getTodaysMedications()
        adherenceStatistics = medicationService.getAdherenceStatistics(for: Date())
        
        // Update widget data
        updateWidgetData()
        
        // Process any pending widget actions
        await processPendingWidgetActions()
        
        isLoading = false
        
        print("💊 MedicationVM: Loaded \(medications.count) medications")
    }
    
    /// Refresh medications from cloud
    func refresh() async {
        await loadMedications()
        await syncFromCloud()
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new medication
    func addMedication(
        name: String,
        dosage: String,
        type: MedicationType,
        scheduleTemplate: MedicationSchedule,
        scheduledTimes: [Date],
        startDate: Date,
        endDate: Date?,
        isOngoing: Bool,
        notes: String?
    ) async throws {
        let medication = Medication(
            name: name,
            dosage: dosage,
            type: type,
            scheduleTemplate: scheduleTemplate,
            scheduledTimes: scheduledTimes,
            startDate: startDate,
            endDate: endDate,
            isOngoing: isOngoing,
            notes: notes
        )
        
        do {
            try await medicationService.saveMedication(medication)
            await loadMedications()
            
            // Background sync to cloud
            Task {
                await syncMedicationToCloud(medication)
            }
            
            print("💊 MedicationVM: Added medication '\(name)'")
        } catch {
            errorMessage = "Failed to add medication: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Update an existing medication
    func updateMedication(_ medication: Medication) async throws {
        do {
            var updatedMed = medication
            updatedMed.isSynced = false
            updatedMed.updatedAt = Date()
            
            try await medicationService.updateMedication(updatedMed)
            await loadMedications()
            
            // Background sync to cloud
            Task {
                await syncMedicationToCloud(updatedMed)
            }
            
            print("💊 MedicationVM: Updated medication '\(medication.name)'")
        } catch {
            errorMessage = "Failed to update medication: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Delete a medication
    func deleteMedication(id: UUID) async throws {
        do {
            try await medicationService.deleteMedication(id: id)
            await loadMedications()
            
            // Background delete from cloud
            Task {
                await deleteMedicationFromCloud(id: id)
            }
            
            print("💊 MedicationVM: Deleted medication")
        } catch {
            errorMessage = "Failed to delete medication: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Adherence Actions
    
    /// Mark medication as taken
    func markAsTaken(medicationId: UUID, scheduledTime: Date, source: String = "in_app") async throws {
        do {
            try await medicationService.markAsTaken(medicationId: medicationId, scheduledTime: scheduledTime)
            
            // Reload and update widget
            medications = medicationService.loadMedications()
            todaysMedications = medicationService.getTodaysMedications()
            adherenceStatistics = medicationService.getAdherenceStatistics(for: Date())
            updateWidgetData()
            
            // Background sync adherence
            Task {
                await syncAdherenceToCloud()
            }
            
            AppAnalyticsService.shared.logMedicationTaken(medicationId: medicationId, source: source)
            print("💊 MedicationVM: Marked medication as taken")
        } catch {
            errorMessage = "Failed to mark as taken: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Mark medication as skipped
    func markAsSkipped(medicationId: UUID, scheduledTime: Date, notes: String?, source: String = "in_app") async throws {
        do {
            try await medicationService.markAsSkipped(medicationId: medicationId, scheduledTime: scheduledTime, notes: notes)
            
            // Reload and update widget
            medications = medicationService.loadMedications()
            todaysMedications = medicationService.getTodaysMedications()
            adherenceStatistics = medicationService.getAdherenceStatistics(for: Date())
            updateWidgetData()
            
            // Background sync adherence
            Task {
                await syncAdherenceToCloud()
            }
            
            AppAnalyticsService.shared.logMedicationSkipped(medicationId: medicationId)
            print("💊 MedicationVM: Marked medication as skipped")
        } catch {
            errorMessage = "Failed to mark as skipped: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Quick mark as taken (from UI button)
    func quickMarkAsTaken(medicationWithAdherence: MedicationWithAdherence) async throws {
        // Find next pending or overdue dose
        let nextDose = medicationWithAdherence.overdueDose ?? medicationWithAdherence.nextDose
        
        guard let dose = nextDose else {
            errorMessage = "No pending dose to mark"
            return
        }
        
        try await markAsTaken(medicationId: medicationWithAdherence.medication.id, scheduledTime: dose.scheduledTime)
    }
    
    // MARK: - Missed Doses Check
    
    /// Check and update missed doses
    func checkMissedDoses() async {
        await medicationService.checkAndUpdateMissedDoses()
        await loadMedications()
    }
    
    // MARK: - Cloud Sync
    
    /// Sync all medications to cloud
    func syncToCloud() async {
        isSyncing = true
        
        // Sync medications
        let unsyncedMeds = medications.filter { !$0.isSynced }
        if !unsyncedMeds.isEmpty {
            do {
                try await supabaseManager.syncMedications(unsyncedMeds)
                
                // Update local sync status
                for med in unsyncedMeds {
                    var updated = med
                    updated.isSynced = true
                    try? await medicationService.updateMedication(updated)
                }
            } catch {
                print("💊 MedicationVM: Failed to sync medications - \(error.localizedDescription)")
                errorMessage = "Sync failed: \(error.localizedDescription)"
            }
        }
        
        // Sync adherence
        await syncAdherenceToCloud()
        
        isSyncing = false
        print("💊 MedicationVM: Cloud sync completed")
    }
    
    /// Sync from cloud
    func syncFromCloud() async {
        do {
            let cloudMedications = try await supabaseManager.fetchUserMedications()
            
            // Merge with local medications
            var localMeds = medicationService.loadMedications()
            
            for cloudMed in cloudMedications {
                if let index = localMeds.firstIndex(where: { $0.id == cloudMed.id }) {
                    // Update if cloud version is newer
                    if cloudMed.updatedAt > localMeds[index].updatedAt {
                        localMeds[index] = cloudMed
                    }
                } else {
                    // Add new medication from cloud
                    localMeds.append(cloudMed)
                }
            }
            
            // Save merged medications
            for med in localMeds {
                try? await medicationService.saveMedication(med)
            }
            
            await loadMedications()
            print("💊 MedicationVM: Synced from cloud")
        } catch {
            print("💊 MedicationVM: Failed to sync from cloud - \(error.localizedDescription)")
        }
    }
    
    private func syncMedicationToCloud(_ medication: Medication) async {
        do {
            _ = try await supabaseManager.syncMedication(medication)
            
            // Update local sync status
            var updated = medication
            updated.isSynced = true
            try? await medicationService.updateMedication(updated)
        } catch {
            print("💊 MedicationVM: Failed to sync medication to cloud - \(error.localizedDescription)")
        }
    }
    
    private func syncAdherenceToCloud() async {
        // Get unsynced adherence records from today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let allAdherence = medicationService.loadAdherenceRecords(for: nil, date: today)
        let unsyncedAdherence = allAdherence.filter { !$0.isSynced && $0.status != .pending }
        
        if !unsyncedAdherence.isEmpty {
            do {
                try await supabaseManager.syncMedicationAdherences(unsyncedAdherence)
                
                // Update local sync status
                for adherence in unsyncedAdherence {
                    var updated = adherence
                    updated.isSynced = true
                    try? await medicationService.saveAdherence(updated)
                }
                
                print("💊 MedicationVM: Synced \(unsyncedAdherence.count) adherence records")
            } catch {
                print("💊 MedicationVM: Failed to sync adherence - \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteMedicationFromCloud(id: UUID) async {
        do {
            try await supabaseManager.deleteMedicationRecord(id: id)
        } catch {
            print("💊 MedicationVM: Failed to delete from cloud - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    /// Get medication by ID
    func getMedication(by id: UUID) -> Medication? {
        medications.first { $0.id == id }
    }
    
    /// Get adherence for a specific medication and date
    func getAdherence(for medicationId: UUID, date: Date = Date()) -> [MedicationAdherence] {
        medicationService.loadAdherenceRecords(for: medicationId, date: date)
    }
    
    /// Format time for display
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Check if medication has dose at time
    func hasDose(medication: Medication, at time: Date) -> Bool {
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        return medication.scheduledTimes.contains { scheduledTime in
            let components = calendar.dateComponents([.hour, .minute], from: scheduledTime)
            return components.hour == targetComponents.hour && components.minute == targetComponents.minute
        }
    }
    
    // MARK: - Widget Integration
    
    /// Update widget with current medication data
    private func updateWidgetData() {
        widgetService.saveMedicationData(medications: todaysMedications)
    }
    
    /// Process any pending medication marks from widget quick actions
    private func processPendingWidgetActions() async {
        await widgetService.processPendingActions(
            hydrationHandler: nil,
            medicationHandler: { [weak self] medicationId in
                guard let self = self else { return }
                
                // Find the pending dose for this medication by matching the medication ID
                // The widget stores the adherence record ID, but we need to find the dose by medication
                if let medWithAdherence = self.todaysMedications.first(where: { 
                    // Check if any of the today's doses match this ID
                    $0.todayDoses.contains(where: { $0.id == medicationId })
                }) {
                    // Find the specific dose by ID
                    if let dose = medWithAdherence.todayDoses.first(where: { $0.id == medicationId && $0.status == .pending }) {
                        print("💊 MedicationVM: Processing widget action for \(medWithAdherence.medication.name)")
                        try? await self.markAsTaken(medicationId: medWithAdherence.medication.id, scheduledTime: dose.scheduledTime)
                    }
                }
            }
        )
    }
}
