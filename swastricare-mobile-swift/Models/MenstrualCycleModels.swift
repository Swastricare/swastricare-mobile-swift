//
//  MenstrualCycleModels.swift
//  swastricare-mobile-swift
//
//  Models for menstrual cycle tracking feature.
//

import Foundation
import SwiftUI

// MARK: - Flow Intensity

enum FlowIntensity: String, Codable, CaseIterable, Identifiable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    case veryHeavy = "very_heavy"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "drop"
        case .medium: return "drop.fill"
        case .heavy: return "drop.halffull"
        case .veryHeavy: return "drop.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .light: return .pink.opacity(0.5)
        case .medium: return .pink
        case .heavy: return .red
        case .veryHeavy: return .red.opacity(0.8)
        }
    }
}

// MARK: - Flow Level (for daily logs)

enum FlowLevel: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case spotting = "spotting"
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    case veryHeavy = "very_heavy"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "drop.degreesign"
        case .spotting: return "circle.dashed"
        case .light: return "drop"
        case .medium: return "drop.fill"
        case .heavy: return "drop.halffull"
        case .veryHeavy: return "drop.triangle.fill"
        }
    }
    
    var isPeriod: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }
}

// MARK: - Mood

enum CycleMood: String, Codable, CaseIterable, Identifiable {
    case happy = "happy"
    case calm = "calm"
    case sad = "sad"
    case anxious = "anxious"
    case irritable = "irritable"
    case moodSwings = "mood_swings"
    case sensitive = "sensitive"
    case energetic = "energetic"
    case tired = "tired"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .sad: return "Sad"
        case .anxious: return "Anxious"
        case .irritable: return "Irritable"
        case .moodSwings: return "Mood Swings"
        case .sensitive: return "Sensitive"
        case .energetic: return "Energetic"
        case .tired: return "Tired"
        }
    }
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "😌"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .irritable: return "😤"
        case .moodSwings: return "🎭"
        case .sensitive: return "🥺"
        case .energetic: return "⚡️"
        case .tired: return "😴"
        }
    }
}

// MARK: - Sleep Quality

enum SleepQuality: String, Codable, CaseIterable, Identifiable {
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
    
    var icon: String {
        switch self {
        case .poor: return "moon.zzz"
        case .fair: return "moon"
        case .good: return "moon.fill"
        case .excellent: return "moon.stars.fill"
        }
    }
}

// MARK: - Cervical Mucus

enum CervicalMucus: String, Codable, CaseIterable, Identifiable {
    case dry = "dry"
    case sticky = "sticky"
    case creamy = "creamy"
    case watery = "watery"
    case eggWhite = "egg_white"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dry: return "Dry"
        case .sticky: return "Sticky"
        case .creamy: return "Creamy"
        case .watery: return "Watery"
        case .eggWhite: return "Egg White"
        }
    }
    
    var fertilityIndicator: String {
        switch self {
        case .dry, .sticky: return "Low fertility"
        case .creamy: return "Medium fertility"
        case .watery, .eggWhite: return "High fertility"
        }
    }
    
    var isFertile: Bool {
        switch self {
        case .watery, .eggWhite: return true
        default: return false
        }
    }
}

// MARK: - Symptom Types

enum SymptomType: String, Codable, CaseIterable, Identifiable {
    // Physical symptoms
    case cramps = "cramps"
    case backache = "backache"
    case headache = "headache"
    case breastTenderness = "breast_tenderness"
    case bloating = "bloating"
    case acne = "acne"
    case nausea = "nausea"
    case fatigue = "fatigue"
    case insomnia = "insomnia"
    case hotFlashes = "hot_flashes"
    case dizziness = "dizziness"
    case cravings = "cravings"
    case constipation = "constipation"
    case diarrhea = "diarrhea"
    case jointPain = "joint_pain"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cramps: return "Cramps"
        case .backache: return "Backache"
        case .headache: return "Headache"
        case .breastTenderness: return "Breast Tenderness"
        case .bloating: return "Bloating"
        case .acne: return "Acne"
        case .nausea: return "Nausea"
        case .fatigue: return "Fatigue"
        case .insomnia: return "Insomnia"
        case .hotFlashes: return "Hot Flashes"
        case .dizziness: return "Dizziness"
        case .cravings: return "Cravings"
        case .constipation: return "Constipation"
        case .diarrhea: return "Diarrhea"
        case .jointPain: return "Joint Pain"
        }
    }
    
    var icon: String {
        switch self {
        case .cramps: return "waveform.path.ecg"
        case .backache: return "figure.stand"
        case .headache: return "brain.head.profile"
        case .breastTenderness: return "heart.circle"
        case .bloating: return "stomach"
        case .acne: return "face.dashed"
        case .nausea: return "tornado"
        case .fatigue: return "battery.25"
        case .insomnia: return "moon.zzz"
        case .hotFlashes: return "thermometer.sun"
        case .dizziness: return "arrow.triangle.2.circlepath"
        case .cravings: return "fork.knife"
        case .constipation: return "exclamationmark.triangle"
        case .diarrhea: return "exclamationmark.triangle.fill"
        case .jointPain: return "figure.arms.open"
        }
    }
    
    var category: SymptomCategory {
        switch self {
        case .cramps, .backache, .headache, .breastTenderness, .jointPain:
            return .pain
        case .bloating, .nausea, .constipation, .diarrhea, .cravings:
            return .digestive
        case .acne, .hotFlashes:
            return .skin
        case .fatigue, .insomnia, .dizziness:
            return .energy
        }
    }
}

enum SymptomCategory: String, CaseIterable {
    case pain = "Pain"
    case digestive = "Digestive"
    case skin = "Skin"
    case energy = "Energy"
}

// MARK: - Menstrual Cycle

struct MenstrualCycle: Codable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID?
    var startDate: Date
    var endDate: Date?
    var cycleLength: Int?
    var periodLength: Int?
    var flowIntensity: FlowIntensity?
    var isPredicted: Bool
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?
    var syncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case cycleLength = "cycle_length"
        case periodLength = "period_length"
        case flowIntensity = "flow_intensity"
        case isPredicted = "is_predicted"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncedAt = "synced_at"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        startDate: Date,
        endDate: Date? = nil,
        cycleLength: Int? = nil,
        periodLength: Int? = nil,
        flowIntensity: FlowIntensity? = nil,
        isPredicted: Bool = false,
        notes: String? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.startDate = startDate
        self.endDate = endDate
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.flowIntensity = flowIntensity
        self.isPredicted = isPredicted
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncedAt = syncedAt
    }
    
    // Custom decoder for date handling
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        cycleLength = try container.decodeIfPresent(Int.self, forKey: .cycleLength)
        periodLength = try container.decodeIfPresent(Int.self, forKey: .periodLength)
        isPredicted = try container.decodeIfPresent(Bool.self, forKey: .isPredicted) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Decode flow intensity
        if let flowString = try container.decodeIfPresent(String.self, forKey: .flowIntensity) {
            flowIntensity = FlowIntensity(rawValue: flowString)
        } else {
            flowIntensity = nil
        }
        
        // Decode dates with flexible format handling
        startDate = Self.decodeDate(from: container, forKey: .startDate) ?? Date()
        endDate = Self.decodeDate(from: container, forKey: .endDate)
        createdAt = Self.decodeTimestamp(from: container, forKey: .createdAt)
        updatedAt = Self.decodeTimestamp(from: container, forKey: .updatedAt)
        syncedAt = Self.decodeTimestamp(from: container, forKey: .syncedAt)
    }
    
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // Try as Date first
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        
        // Try as string
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else {
            return nil
        }
        
        // Try date-only format (YYYY-MM-DD)
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    private static func decodeTimestamp(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else {
            return nil
        }
        
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        return iso8601Formatter.date(from: dateString)
    }
    
    // Custom encoder for date handling
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(cycleLength, forKey: .cycleLength)
        try container.encodeIfPresent(periodLength, forKey: .periodLength)
        try container.encodeIfPresent(flowIntensity?.rawValue, forKey: .flowIntensity)
        try container.encode(isPredicted, forKey: .isPredicted)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(syncedAt, forKey: .syncedAt)
        
        // Encode dates as date-only strings
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        try container.encode(dateFormatter.string(from: startDate), forKey: .startDate)
        if let endDate = endDate {
            try container.encode(dateFormatter.string(from: endDate), forKey: .endDate)
        }
    }
    
    // Computed properties
    var calculatedPeriodLength: Int? {
        guard let endDate = endDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: startDate, to: endDate).day.map { $0 + 1 }
    }
    
    var isOngoing: Bool {
        endDate == nil && !isPredicted
    }
}

// MARK: - Menstrual Daily Log

struct MenstrualDailyLog: Codable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID?
    var logDate: Date
    var cycleId: UUID?
    var flowLevel: FlowLevel?
    var painLevel: Int?
    var mood: CycleMood?
    var energyLevel: Int?
    var sleepQuality: SleepQuality?
    var temperature: Double?
    var weight: Double?
    var cervicalMucus: CervicalMucus?
    var sexualActivity: Bool?
    var protectedSex: Bool?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?
    var symptoms: [MenstrualSymptom] = []
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case logDate = "log_date"
        case cycleId = "cycle_id"
        case flowLevel = "flow_level"
        case painLevel = "pain_level"
        case mood
        case energyLevel = "energy_level"
        case sleepQuality = "sleep_quality"
        case temperature
        case weight
        case cervicalMucus = "cervical_mucus"
        case sexualActivity = "sexual_activity"
        case protectedSex = "protected_sex"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        logDate: Date,
        cycleId: UUID? = nil,
        flowLevel: FlowLevel? = nil,
        painLevel: Int? = nil,
        mood: CycleMood? = nil,
        energyLevel: Int? = nil,
        sleepQuality: SleepQuality? = nil,
        temperature: Double? = nil,
        weight: Double? = nil,
        cervicalMucus: CervicalMucus? = nil,
        sexualActivity: Bool? = nil,
        protectedSex: Bool? = nil,
        notes: String? = nil,
        symptoms: [MenstrualSymptom] = []
    ) {
        self.id = id
        self.userId = userId
        self.logDate = logDate
        self.cycleId = cycleId
        self.flowLevel = flowLevel
        self.painLevel = painLevel
        self.mood = mood
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.temperature = temperature
        self.weight = weight
        self.cervicalMucus = cervicalMucus
        self.sexualActivity = sexualActivity
        self.protectedSex = protectedSex
        self.notes = notes
        self.symptoms = symptoms
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var isPeriodDay: Bool {
        flowLevel?.isPeriod ?? false
    }
}

// MARK: - Menstrual Symptom

struct MenstrualSymptom: Codable, Identifiable, Equatable {
    var id: UUID
    var dailyLogId: UUID?
    var symptomType: SymptomType
    var severity: Int // 1-5
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case dailyLogId = "daily_log_id"
        case symptomType = "symptom_type"
        case severity
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        dailyLogId: UUID? = nil,
        symptomType: SymptomType,
        severity: Int = 3
    ) {
        self.id = id
        self.dailyLogId = dailyLogId
        self.symptomType = symptomType
        self.severity = min(5, max(1, severity))
        self.createdAt = Date()
    }
}

// MARK: - Menstrual Settings

struct MenstrualSettings: Codable, Equatable {
    var id: UUID?
    var userId: UUID?
    var averageCycleLength: Int
    var averagePeriodLength: Int
    var reminderEnabled: Bool
    var reminderDaysBefore: Int
    var fertileWindowTracking: Bool
    var pmsTracking: Bool
    var ovulationTracking: Bool
    var lutealPhaseLength: Int
    var lastUpdated: Date?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case averageCycleLength = "average_cycle_length"
        case averagePeriodLength = "average_period_length"
        case reminderEnabled = "reminder_enabled"
        case reminderDaysBefore = "reminder_days_before"
        case fertileWindowTracking = "fertile_window_tracking"
        case pmsTracking = "pms_tracking"
        case ovulationTracking = "ovulation_tracking"
        case lutealPhaseLength = "luteal_phase_length"
        case lastUpdated = "last_updated"
        case createdAt = "created_at"
    }
    
    init(
        id: UUID? = nil,
        userId: UUID? = nil,
        averageCycleLength: Int = 28,
        averagePeriodLength: Int = 5,
        reminderEnabled: Bool = true,
        reminderDaysBefore: Int = 3,
        fertileWindowTracking: Bool = true,
        pmsTracking: Bool = true,
        ovulationTracking: Bool = true,
        lutealPhaseLength: Int = 14
    ) {
        self.id = id
        self.userId = userId
        self.averageCycleLength = averageCycleLength
        self.averagePeriodLength = averagePeriodLength
        self.reminderEnabled = reminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.fertileWindowTracking = fertileWindowTracking
        self.pmsTracking = pmsTracking
        self.ovulationTracking = ovulationTracking
        self.lutealPhaseLength = lutealPhaseLength
        self.lastUpdated = Date()
        self.createdAt = Date()
    }
}

// MARK: - Cycle Phase

enum CyclePhase: String, CaseIterable {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulation = "Ovulation"
    case luteal = "Luteal"
    case pms = "PMS"
    case unknown = "Unknown"
    
    var description: String {
        switch self {
        case .menstrual: return "Period days - your body is shedding the uterine lining"
        case .follicular: return "Pre-ovulation - energy levels typically rise"
        case .ovulation: return "Peak fertility window - highest chance of conception"
        case .luteal: return "Post-ovulation - progesterone levels are elevated"
        case .pms: return "Premenstrual phase - may experience PMS symptoms"
        case .unknown: return "Unable to determine cycle phase"
        }
    }
    
    var color: Color {
        switch self {
        case .menstrual: return .red
        case .follicular: return .orange
        case .ovulation: return .green
        case .luteal: return .purple
        case .pms: return .pink
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .menstrual: return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation: return "sparkles"
        case .luteal: return "moon.fill"
        case .pms: return "cloud.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Cycle Predictions

struct CyclePrediction: Identifiable {
    let id = UUID()
    let nextPeriodStart: Date
    let nextPeriodEnd: Date
    let ovulationDate: Date
    let fertileWindowStart: Date
    let fertileWindowEnd: Date
    let pmsStart: Date
    let confidence: Double // 0.0 - 1.0
    
    var daysUntilPeriod: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: nextPeriodStart).day ?? 0
    }
    
    var daysUntilOvulation: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: ovulationDate).day ?? 0
    }
    
    var isFertileToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let fertileStart = Calendar.current.startOfDay(for: fertileWindowStart)
        let fertileEnd = Calendar.current.startOfDay(for: fertileWindowEnd)
        return today >= fertileStart && today <= fertileEnd
    }
    
    var isPmsToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let pms = Calendar.current.startOfDay(for: pmsStart)
        let periodStart = Calendar.current.startOfDay(for: nextPeriodStart)
        return today >= pms && today < periodStart
    }
}

// MARK: - Cycle Statistics

struct CycleStatistics {
    let averageCycleLength: Double
    let averagePeriodLength: Double
    let shortestCycle: Int
    let longestCycle: Int
    let cycleVariation: Double // Standard deviation
    let totalCyclesTracked: Int
    let mostCommonSymptoms: [SymptomType]
    let averagePainLevel: Double?
    
    var cycleRegularity: String {
        if cycleVariation <= 2 {
            return "Very Regular"
        } else if cycleVariation <= 4 {
            return "Regular"
        } else if cycleVariation <= 7 {
            return "Somewhat Irregular"
        } else {
            return "Irregular"
        }
    }
}

// MARK: - Calendar Day Data

struct CalendarDayData: Identifiable {
    let id = UUID()
    let date: Date
    var isPeriodDay: Bool
    var isPredictedPeriod: Bool
    var isOvulationDay: Bool
    var isFertileDay: Bool
    var isPmsDay: Bool
    var flowLevel: FlowLevel?
    var hasLog: Bool
    var log: MenstrualDailyLog?
    
    var dayType: DayType {
        if isPeriodDay || isPredictedPeriod {
            return .period
        } else if isOvulationDay {
            return .ovulation
        } else if isFertileDay {
            return .fertile
        } else if isPmsDay {
            return .pms
        } else {
            return .normal
        }
    }
    
    enum DayType {
        case period
        case ovulation
        case fertile
        case pms
        case normal
        
        var color: Color {
            switch self {
            case .period: return .red
            case .ovulation: return .green
            case .fertile: return .teal
            case .pms: return .purple
            case .normal: return .clear
            }
        }
    }
}

// MARK: - Cycle Insights

struct CycleInsights {
    let currentPhase: CyclePhase
    let dayOfCycle: Int
    let prediction: CyclePrediction?
    let statistics: CycleStatistics?
    let tips: [String]
    
    static func getTips(for phase: CyclePhase) -> [String] {
        switch phase {
        case .menstrual:
            return [
                "Stay hydrated and get plenty of rest",
                "Iron-rich foods can help replenish what you lose",
                "Light exercise like yoga can help with cramps",
                "Use a heating pad for comfort"
            ]
        case .follicular:
            return [
                "Great time for high-intensity workouts",
                "Your energy levels are naturally higher",
                "Try new activities or projects",
                "Skin tends to be clearer during this phase"
            ]
        case .ovulation:
            return [
                "Peak fertility window",
                "You may notice increased energy and libido",
                "Cervical mucus becomes clear and stretchy",
                "Great time for important conversations"
            ]
        case .luteal:
            return [
                "Focus on self-care activities",
                "Complex carbs can help maintain energy",
                "You may experience food cravings",
                "Prioritize sleep and stress management"
            ]
        case .pms:
            return [
                "Reduce caffeine and salt intake",
                "Magnesium-rich foods may help",
                "Gentle exercise can improve mood",
                "Practice relaxation techniques"
            ]
        case .unknown:
            return [
                "Log your periods to get personalized insights",
                "Track symptoms to identify patterns",
                "Regular tracking improves predictions"
            ]
        }
    }
}

// MARK: - Error Types

enum MenstrualCycleError: Error, LocalizedError {
    case notAuthenticated
    case saveFailed(String)
    case loadFailed(String)
    case invalidData(String)
    case networkError(String)
    case predictionError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .loadFailed(let message):
            return "Failed to load: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .predictionError(let message):
            return "Prediction error: \(message)"
        }
    }
}
