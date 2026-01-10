//
//  MedicationModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Medication reminder data structures
//

import Foundation

// MARK: - Medication

struct Medication: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var dosage: String
    var type: MedicationType
    var scheduleTemplate: MedicationSchedule
    var scheduledTimes: [Date] // Daily times when medication should be taken
    var startDate: Date
    var endDate: Date?
    var isOngoing: Bool
    var notes: String?
    var userId: UUID?
    var isSynced: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        type: MedicationType = .pill,
        scheduleTemplate: MedicationSchedule = .onceDaily,
        scheduledTimes: [Date] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        isOngoing: Bool = true,
        notes: String? = nil,
        userId: UUID? = nil,
        isSynced: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.type = type
        self.scheduleTemplate = scheduleTemplate
        self.scheduledTimes = scheduledTimes
        self.startDate = startDate
        self.endDate = endDate
        self.isOngoing = isOngoing
        self.notes = notes
        self.userId = userId
        self.isSynced = isSynced
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Check if medication is active on a given date
    func isActive(on date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: startDate)
        
        // Check if date is after start
        guard targetDay >= startDay else { return false }
        
        // If ongoing, it's active
        if isOngoing { return true }
        
        // Check if date is before end
        if let end = endDate {
            let endDay = calendar.startOfDay(for: end)
            return targetDay <= endDay
        }
        
        return false
    }
    
    /// Get today's scheduled times for this medication
    func getTodayScheduledTimes() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        return scheduledTimes.compactMap { time in
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return calendar.date(bySettingHour: components.hour ?? 0,
                                minute: components.minute ?? 0,
                                second: 0,
                                of: now)
        }
    }
}

// MARK: - Medication Type

enum MedicationType: String, Codable, CaseIterable {
    case pill = "tablet"
    case liquid = "syrup"
    case injection = "injection"
    case inhaler = "inhaler"
    case drops = "drops"
    case cream = "cream"
    case other = "other"
    
    var icon: String {
        switch self {
        case .pill: return "pills.fill"
        case .liquid: return "drop.fill"
        case .injection: return "syringe.fill"
        case .inhaler: return "wind"
        case .drops: return "eyedropper.full"
        case .cream: return "bandage.fill"
        case .other: return "cross.case.fill"
        }
    }
    
    var displayName: String { rawValue.capitalized }
}

// MARK: - Medication Schedule

enum MedicationSchedule: Codable, Equatable {
    case onceDaily       // Morning
    case twiceDaily      // Morning & Evening
    case thriceDaily     // Morning, Afternoon & Evening
    case custom([Date])  // Custom times
    
    var displayName: String {
        switch self {
        case .onceDaily: return "Once Daily"
        case .twiceDaily: return "Twice Daily"
        case .thriceDaily: return "Thrice Daily"
        case .custom(let times): return "Custom (\(times.count)x daily)"
        }
    }
    
    var templateDescription: String {
        switch self {
        case .onceDaily: return "Morning (8:00 AM)"
        case .twiceDaily: return "Morning & Evening"
        case .thriceDaily: return "Morning, Afternoon & Evening"
        case .custom(let times): return "\(times.count) times daily"
        }
    }
    
    /// Get default times for schedule template
    var defaultTimes: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .onceDaily:
            // 8 AM
            return [calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today]
            
        case .twiceDaily:
            // 8 AM, 9 PM
            return [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today,
                calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today) ?? today
            ]
            
        case .thriceDaily:
            // 8 AM, 2 PM, 9 PM
            return [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today,
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) ?? today,
                calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today) ?? today
            ]
            
        case .custom(let times):
            return times
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case type
        case times
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "onceDaily":
            self = .onceDaily
        case "twiceDaily":
            self = .twiceDaily
        case "thriceDaily":
            self = .thriceDaily
        case "custom":
            let times = try container.decode([Date].self, forKey: .times)
            self = .custom(times)
        default:
            self = .onceDaily
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .onceDaily:
            try container.encode("onceDaily", forKey: .type)
        case .twiceDaily:
            try container.encode("twiceDaily", forKey: .type)
        case .thriceDaily:
            try container.encode("thriceDaily", forKey: .type)
        case .custom(let times):
            try container.encode("custom", forKey: .type)
            try container.encode(times, forKey: .times)
        }
    }
}

// MARK: - Medication Adherence

struct MedicationAdherence: Identifiable, Codable, Equatable {
    let id: UUID
    let medicationId: UUID
    var userId: UUID?
    let scheduledTime: Date
    var takenAt: Date?
    var status: AdherenceStatus
    var notes: String?
    var isSynced: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        medicationId: UUID,
        userId: UUID? = nil,
        scheduledTime: Date,
        takenAt: Date? = nil,
        status: AdherenceStatus = .pending,
        notes: String? = nil,
        isSynced: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.medicationId = medicationId
        self.userId = userId
        self.scheduledTime = scheduledTime
        self.takenAt = takenAt
        self.status = status
        self.notes = notes
        self.isSynced = isSynced
        self.createdAt = createdAt
    }
    
    /// Check if this dose is overdue
    func isOverdue() -> Bool {
        guard status == .pending else { return false }
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        return scheduledTime < twoHoursAgo
    }
    
    /// Check if this dose is upcoming (within next hour)
    func isUpcoming() -> Bool {
        guard status == .pending else { return false }
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        return scheduledTime > now && scheduledTime <= oneHourFromNow
    }
}

// MARK: - Adherence Status

enum AdherenceStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case taken = "taken"
    case missed = "missed"
    case skipped = "skipped"
    case late = "late"
    case early = "early"
    
    var displayName: String { rawValue.capitalized }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .taken: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .skipped: return "xmark.circle.fill"
        case .late: return "clock.badge.exclamationmark"
        case .early: return "clock.badge.checkmark"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "secondary"
        case .taken: return "green"
        case .missed: return "red"
        case .skipped: return "orange"
        case .late: return "yellow"
        case .early: return "blue"
        }
    }
}

// MARK: - Medication with Adherence Info

struct MedicationWithAdherence: Identifiable {
    let medication: Medication
    let todayDoses: [MedicationAdherence]
    
    var id: UUID { medication.id }
    
    var takenCount: Int {
        todayDoses.filter { $0.status == .taken || $0.status == .late || $0.status == .early }.count
    }
    
    var totalDoses: Int {
        todayDoses.count
    }
    
    var adherencePercentage: Double {
        guard totalDoses > 0 else { return 0 }
        return Double(takenCount) / Double(totalDoses)
    }
    
    var nextDose: MedicationAdherence? {
        todayDoses
            .filter { $0.status == .pending && $0.scheduledTime > Date() }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .first
    }
    
    var overdueDose: MedicationAdherence? {
        todayDoses
            .filter { $0.isOverdue() }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .first
    }
}

// MARK: - Adherence Statistics

struct AdherenceStatistics {
    let totalDoses: Int
    let takenDoses: Int
    let missedDoses: Int
    let skippedDoses: Int
    let pendingDoses: Int
    
    var adherencePercentage: Double {
        guard totalDoses > 0 else { return 0 }
        return Double(takenDoses) / Double(totalDoses) * 100
    }
    
    var adherenceRate: String {
        String(format: "%.0f%%", adherencePercentage)
    }
    
    init(adherenceRecords: [MedicationAdherence]) {
        self.totalDoses = adherenceRecords.count
        self.takenDoses = adherenceRecords.filter { $0.status == .taken || $0.status == .late || $0.status == .early }.count
        self.missedDoses = adherenceRecords.filter { $0.status == .missed }.count
        self.skippedDoses = adherenceRecords.filter { $0.status == .skipped }.count
        self.pendingDoses = adherenceRecords.filter { $0.status == .pending }.count
    }
}

// MARK: - Database Record Models

struct MedicationRecord: Codable {
    let id: UUID?
    let healthProfileId: UUID
    let name: String
    let dosage: String
    let form: String
    let startDate: Date
    let endDate: Date?
    let isOngoing: Bool
    let notes: String?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case name
        case dosage
        case form
        case startDate = "start_date"
        case endDate = "end_date"
        case isOngoing = "is_ongoing"
        case notes
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from medication: Medication, healthProfileId: UUID) {
        self.id = medication.id
        self.healthProfileId = healthProfileId
        self.name = medication.name
        self.dosage = medication.dosage
        self.form = medication.type.rawValue
        self.startDate = medication.startDate
        self.endDate = medication.endDate
        self.isOngoing = medication.isOngoing
        self.notes = medication.notes
        self.status = "active" // Default to active
        self.createdAt = medication.createdAt
        self.updatedAt = medication.updatedAt
    }
    
    // Convert back to Medication - requires fetching schedule separately or passing defaults
    func toMedication(schedules: [MedicationScheduleRecord]) -> Medication {
        // Simple reconstruction - in real app, we'd join with schedules
        let scheduledTimes = schedules.compactMap { schedule -> Date? in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            guard let timeDate = formatter.date(from: schedule.timeOfDay) else { return nil }
            
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
            return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: components.second ?? 0, of: now)
        }
        
        return Medication(
            id: id ?? UUID(),
            name: name,
            dosage: dosage,
            type: MedicationType(rawValue: form) ?? .pill,
            scheduleTemplate: .custom(scheduledTimes), // Simplified
            scheduledTimes: scheduledTimes,
            startDate: startDate,
            endDate: endDate,
            isOngoing: isOngoing,
            notes: notes,
            userId: nil, // Use healthProfileId in context
            isSynced: true,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

struct MedicationScheduleRecord: Codable {
    let id: UUID?
    let medicationId: UUID
    let healthProfileId: UUID
    let scheduleType: String
    let timeOfDay: String // SQL TIME type comes as string
    let frequencyPerDay: Int
    let daysOfWeek: [Int]?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case medicationId = "medication_id"
        case healthProfileId = "health_profile_id"
        case scheduleType = "schedule_type"
        case timeOfDay = "time_of_day"
        case frequencyPerDay = "frequency_per_day"
        case daysOfWeek = "days_of_week"
        case isActive = "is_active"
    }
}

struct MedicationLogRecord: Codable {
    let id: UUID?
    let medicationId: UUID
    let healthProfileId: UUID
    let scheduledTime: Date
    let takenTime: Date?
    let status: String
    let notes: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case medicationId = "medication_id"
        case healthProfileId = "health_profile_id"
        case scheduledTime = "scheduled_time"
        case takenTime = "taken_time"
        case status
        case notes
        case createdAt = "created_at"
    }
    
    init(from adherence: MedicationAdherence, healthProfileId: UUID) {
        self.id = adherence.id
        self.medicationId = adherence.medicationId
        self.healthProfileId = healthProfileId
        self.scheduledTime = adherence.scheduledTime
        self.takenTime = adherence.takenAt
        self.status = adherence.status.rawValue
        self.notes = adherence.notes
        self.createdAt = adherence.createdAt
    }
    
    func toMedicationAdherence() -> MedicationAdherence {
        MedicationAdherence(
            id: id ?? UUID(),
            medicationId: medicationId,
            userId: nil, // Contextual
            scheduledTime: scheduledTime,
            takenAt: takenTime,
            status: AdherenceStatus(rawValue: status) ?? .pending,
            notes: notes,
            isSynced: true,
            createdAt: createdAt ?? Date()
        )
    }
}
