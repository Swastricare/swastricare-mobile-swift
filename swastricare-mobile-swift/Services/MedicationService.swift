//
//  MedicationService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Medication management and local storage
//

import Foundation
import UserNotifications

// MARK: - Medication Service Protocol

protocol MedicationServiceProtocol {
    func loadMedications() -> [Medication]
    func saveMedication(_ medication: Medication) async throws
    func updateMedication(_ medication: Medication) async throws
    func deleteMedication(id: UUID) async throws
    func loadAdherenceRecords(for medicationId: UUID?, date: Date) -> [MedicationAdherence]
    func saveAdherence(_ adherence: MedicationAdherence) async throws
    func markAsTaken(medicationId: UUID, scheduledTime: Date) async throws
    func markAsSkipped(medicationId: UUID, scheduledTime: Date, notes: String?) async throws
    func getActiveMedications(for date: Date) -> [Medication]
    func getTodaysMedications() -> [MedicationWithAdherence]
    func getAdherenceStatistics(for date: Date) -> AdherenceStatistics
    func checkAndUpdateMissedDoses() async
}

// MARK: - Medication Service Implementation

@MainActor
final class MedicationService: MedicationServiceProtocol {
    
    static let shared = MedicationService()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let medicationsKey = "medications_storage_v1"
    private let adherenceKey = "medication_adherence_v1"
    private let notificationService: NotificationServiceProtocol
    
    // MARK: - Init
    
    private init(notificationService: NotificationServiceProtocol = NotificationService.shared) {
        self.notificationService = notificationService
    }
    
    // MARK: - Load Operations
    
    /// Load all medications from local storage
    func loadMedications() -> [Medication] {
        guard let data = userDefaults.data(forKey: medicationsKey) else {
            return []
        }
        
        do {
            let medications = try JSONDecoder().decode([Medication].self, from: data)
            print("💊 MedicationService: Loaded \(medications.count) medications")
            return medications
        } catch {
            print("💊 MedicationService: Failed to decode medications - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Load adherence records for a medication and date
    func loadAdherenceRecords(for medicationId: UUID? = nil, date: Date = Date()) -> [MedicationAdherence] {
        guard let data = userDefaults.data(forKey: adherenceKey) else {
            return []
        }
        
        do {
            var records = try JSONDecoder().decode([MedicationAdherence].self, from: data)
            
            // Filter by medication ID if provided
            if let medId = medicationId {
                records = records.filter { $0.medicationId == medId }
            }
            
            // Filter by date
            let calendar = Calendar.current
            let targetDay = calendar.startOfDay(for: date)
            records = records.filter {
                let recordDay = calendar.startOfDay(for: $0.scheduledTime)
                return recordDay == targetDay
            }
            
            return records
        } catch {
            print("💊 MedicationService: Failed to decode adherence - \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Save Operations
    
    /// Save a new medication
    func saveMedication(_ medication: Medication) async throws {
        var medications = loadMedications()
        
        // Check if already exists
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
        } else {
            medications.append(medication)
        }
        
        // Save to storage
        try saveMedicationsToStorage(medications)
        
        // Create adherence records for today
        await createTodayAdherenceRecords(for: medication)
        
        // Schedule notifications
        await scheduleMedicationNotifications(for: medication)
        
        print("💊 MedicationService: Saved medication '\(medication.name)'")
    }
    
    /// Update an existing medication
    func updateMedication(_ medication: Medication) async throws {
        var medications = loadMedications()
        
        guard let index = medications.firstIndex(where: { $0.id == medication.id }) else {
            throw MedicationError.notFound
        }
        
        let oldMedication = medications[index]
        medications[index] = medication
        
        try saveMedicationsToStorage(medications)
        
        // If schedule changed, reschedule notifications
        if oldMedication.scheduledTimes != medication.scheduledTimes {
            await cancelMedicationNotifications(for: medication.id)
            await scheduleMedicationNotifications(for: medication)
            
            // Update today's adherence records if times changed
            await updateTodayAdherenceRecords(for: medication)
        }
        
        print("💊 MedicationService: Updated medication '\(medication.name)'")
    }
    
    /// Delete a medication
    func deleteMedication(id: UUID) async throws {
        var medications = loadMedications()
        
        guard let index = medications.firstIndex(where: { $0.id == id }) else {
            throw MedicationError.notFound
        }
        
        medications.remove(at: index)
        try saveMedicationsToStorage(medications)
        
        // Cancel notifications
        await cancelMedicationNotifications(for: id)
        
        // Delete adherence records
        deleteAdherenceRecords(for: id)
        
        print("💊 MedicationService: Deleted medication")
    }
    
    /// Save adherence record
    func saveAdherence(_ adherence: MedicationAdherence) async throws {
        var records = loadAllAdherenceRecords()
        
        // Update if exists, add if new
        if let index = records.firstIndex(where: { $0.id == adherence.id }) {
            records[index] = adherence
        } else {
            records.append(adherence)
        }
        
        try saveAdherenceToStorage(records)
        print("💊 MedicationService: Saved adherence record")
    }
    
    // MARK: - Adherence Actions
    
    /// Mark medication as taken at scheduled time
    func markAsTaken(medicationId: UUID, scheduledTime: Date) async throws {
        var records = loadAllAdherenceRecords()
        
        guard let index = records.firstIndex(where: {
            $0.medicationId == medicationId && areSameScheduledTime($0.scheduledTime, scheduledTime)
        }) else {
            // Create new record if not found
            let newRecord = MedicationAdherence(
                medicationId: medicationId,
                scheduledTime: scheduledTime,
                takenAt: Date(),
                status: .taken
            )
            try await saveAdherence(newRecord)
            return
        }
        
        records[index].status = .taken
        records[index].takenAt = Date()
        records[index].isSynced = false
        
        try saveAdherenceToStorage(records)
        print("💊 MedicationService: Marked as taken")
    }
    
    /// Mark medication as skipped
    func markAsSkipped(medicationId: UUID, scheduledTime: Date, notes: String? = nil) async throws {
        var records = loadAllAdherenceRecords()
        
        guard let index = records.firstIndex(where: {
            $0.medicationId == medicationId && areSameScheduledTime($0.scheduledTime, scheduledTime)
        }) else {
            // Create new record if not found
            let newRecord = MedicationAdherence(
                medicationId: medicationId,
                scheduledTime: scheduledTime,
                status: .skipped,
                notes: notes
            )
            try await saveAdherence(newRecord)
            return
        }
        
        records[index].status = .skipped
        records[index].notes = notes
        records[index].isSynced = false
        
        try saveAdherenceToStorage(records)
        print("💊 MedicationService: Marked as skipped")
    }
    
    // MARK: - Query Operations
    
    /// Get active medications for a specific date
    func getActiveMedications(for date: Date = Date()) -> [Medication] {
        let medications = loadMedications()
        return medications.filter { $0.isActive(on: date) }
    }
    
    /// Get today's medications with adherence info
    func getTodaysMedications() -> [MedicationWithAdherence] {
        let medications = getActiveMedications(for: Date())
        
        return medications.map { medication in
            let adherence = loadAdherenceRecords(for: medication.id, date: Date())
            return MedicationWithAdherence(medication: medication, todayDoses: adherence)
        }
    }
    
    /// Get adherence statistics for a date
    func getAdherenceStatistics(for date: Date = Date()) -> AdherenceStatistics {
        let records = loadAdherenceRecords(for: nil, date: date)
        return AdherenceStatistics(adherenceRecords: records)
    }
    
    // MARK: - Missed Doses Check
    
    /// Check and mark missed doses
    func checkAndUpdateMissedDoses() async {
        var records = loadAllAdherenceRecords()
        var updated = false
        
        for index in records.indices {
            if records[index].isOverdue() && records[index].status == .pending {
                records[index].status = .missed
                records[index].isSynced = false
                updated = true
            }
        }
        
        if updated {
            do {
                try saveAdherenceToStorage(records)
                print("💊 MedicationService: Updated missed doses")
            } catch {
                print("💊 MedicationService: Failed to update missed doses - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule notifications for a medication (next 7 days)
    private func scheduleMedicationNotifications(for medication: Medication) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Schedule for next 7 days (iOS limit: 64 notifications)
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            
            // Skip if medication not active on this date
            guard medication.isActive(on: targetDate) else { continue }
            
            // Schedule notification for each time
            for time in medication.scheduledTimes {
                let components = calendar.dateComponents([.hour, .minute], from: time)
                var notificationDate = calendar.date(bySettingHour: components.hour ?? 0,
                                                    minute: components.minute ?? 0,
                                                    second: 0,
                                                    of: targetDate) ?? targetDate
                
                // Skip past times on today
                if calendar.isDateInToday(targetDate) && notificationDate < Date() {
                    continue
                }
                
                await scheduleNotification(
                    for: medication,
                    at: notificationDate
                )
            }
        }
    }
    
    /// Schedule a single notification
    private func scheduleNotification(for medication: Medication, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "💊 Time for \(medication.name)"
        content.body = "\(medication.dosage) • Tap to mark as taken"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.medicationReminder.identifier
        content.badge = 1
        
        // Add user info
        content.userInfo = [
            "type": "medication_reminder",
            "medication_id": medication.id.uuidString,
            "medication_name": medication.name,
            "scheduled_time": date.timeIntervalSince1970
        ]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "medication_\(medication.id.uuidString)_\(date.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("💊 MedicationService: Scheduled notification for \(medication.name) at \(date)")
        } catch {
            print("💊 MedicationService: Failed to schedule notification - \(error.localizedDescription)")
        }
    }
    
    /// Cancel all notifications for a medication
    private func cancelMedicationNotifications(for medicationId: UUID) async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        let medicationIds = requests
            .filter { $0.identifier.starts(with: "medication_\(medicationId.uuidString)") }
            .map { $0.identifier }
        
        if !medicationIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: medicationIds)
            print("💊 MedicationService: Cancelled \(medicationIds.count) notifications")
        }
    }
    
    // MARK: - Adherence Record Management
    
    /// Create adherence records for today
    private func createTodayAdherenceRecords(for medication: Medication) async {
        let todayTimes = medication.getTodayScheduledTimes()
        var existingRecords = loadAdherenceRecords(for: medication.id, date: Date())
        
        for time in todayTimes {
            // Check if record already exists
            let exists = existingRecords.contains { areSameScheduledTime($0.scheduledTime, time) }
            
            if !exists {
                let record = MedicationAdherence(
                    medicationId: medication.id,
                    scheduledTime: time,
                    status: .pending
                )
                
                do {
                    try await saveAdherence(record)
                } catch {
                    print("💊 MedicationService: Failed to create adherence record - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Update today's adherence records when schedule changes
    private func updateTodayAdherenceRecords(for medication: Medication) async {
        // Remove old pending records for today
        var records = loadAllAdherenceRecords()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        records.removeAll { record in
            let isToday = calendar.startOfDay(for: record.scheduledTime) == today
            let isPending = record.status == .pending
            let isThisMed = record.medicationId == medication.id
            return isToday && isPending && isThisMed
        }
        
        do {
            try saveAdherenceToStorage(records)
            // Create new records
            await createTodayAdherenceRecords(for: medication)
        } catch {
            print("💊 MedicationService: Failed to update adherence records - \(error.localizedDescription)")
        }
    }
    
    /// Delete all adherence records for a medication
    private func deleteAdherenceRecords(for medicationId: UUID) {
        var records = loadAllAdherenceRecords()
        records.removeAll { $0.medicationId == medicationId }
        
        do {
            try saveAdherenceToStorage(records)
        } catch {
            print("💊 MedicationService: Failed to delete adherence records - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Storage Helpers
    
    private func saveMedicationsToStorage(_ medications: [Medication]) throws {
        let data = try JSONEncoder().encode(medications)
        userDefaults.set(data, forKey: medicationsKey)
    }
    
    private func loadAllAdherenceRecords() -> [MedicationAdherence] {
        guard let data = userDefaults.data(forKey: adherenceKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([MedicationAdherence].self, from: data)
        } catch {
            print("💊 MedicationService: Failed to decode adherence - \(error.localizedDescription)")
            return []
        }
    }
    
    private func saveAdherenceToStorage(_ records: [MedicationAdherence]) throws {
        let data = try JSONEncoder().encode(records)
        userDefaults.set(data, forKey: adherenceKey)
    }
    
    private func areSameScheduledTime(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date1)
        let components2 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date2)
        return components1 == components2
    }
}

// MARK: - Medication Error

enum MedicationError: Error, LocalizedError {
    case notFound
    case invalidData
    case saveFailed(String)
    case notificationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Medication not found"
        case .invalidData:
            return "Invalid medication data"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .notificationError(let message):
            return "Notification error: \(message)"
        }
    }
}
