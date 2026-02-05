//
//  MenstruationModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Menstrual cycle and period tracking data structures
//

import Foundation
import SwiftUI

// MARK: - Flow Intensity

enum FlowIntensity: String, Codable, CaseIterable, Identifiable {
    case spotting = "spotting"
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    case veryHeavy = "very_heavy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }

    var icon: String {
        switch self {
        case .spotting: return "drop"
        case .light: return "drop.fill"
        case .medium: return "drop.fill"
        case .heavy: return "drop.halffull"
        case .veryHeavy: return "drop.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .spotting: return Color(hex: "FFAA91")
        case .light: return Color(hex: "FF7043")
        case .medium: return Color(hex: "E53935")
        case .heavy: return Color(hex: "C62828")
        case .veryHeavy: return Color(hex: "8E0000")
        }
    }

    var dropCount: Int {
        switch self {
        case .spotting: return 1
        case .light: return 2
        case .medium: return 3
        case .heavy: return 4
        case .veryHeavy: return 5
        }
    }
}

// MARK: - Period Symptom

enum PeriodSymptom: String, Codable, CaseIterable, Identifiable {
    case cramps = "cramps"
    case headache = "headache"
    case bloating = "bloating"
    case fatigue = "fatigue"
    case moodSwings = "mood_swings"
    case backPain = "back_pain"
    case breastTenderness = "breast_tenderness"
    case acne = "acne"
    case nausea = "nausea"
    case insomnia = "insomnia"
    case cravings = "cravings"
    case dizziness = "dizziness"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cramps: return "Cramps"
        case .headache: return "Headache"
        case .bloating: return "Bloating"
        case .fatigue: return "Fatigue"
        case .moodSwings: return "Mood Swings"
        case .backPain: return "Back Pain"
        case .breastTenderness: return "Breast Tenderness"
        case .acne: return "Acne"
        case .nausea: return "Nausea"
        case .insomnia: return "Insomnia"
        case .cravings: return "Cravings"
        case .dizziness: return "Dizziness"
        }
    }

    var icon: String {
        switch self {
        case .cramps: return "bolt.fill"
        case .headache: return "brain.head.profile"
        case .bloating: return "circle.fill"
        case .fatigue: return "battery.25percent"
        case .moodSwings: return "theatermask.and.paintbrush.fill"
        case .backPain: return "figure.stand"
        case .breastTenderness: return "heart.fill"
        case .acne: return "face.smiling"
        case .nausea: return "stomach"
        case .insomnia: return "moon.zzz.fill"
        case .cravings: return "fork.knife"
        case .dizziness: return "tornado"
        }
    }
}

// MARK: - Mood Type

enum MoodType: String, Codable, CaseIterable, Identifiable {
    case happy = "happy"
    case calm = "calm"
    case sensitive = "sensitive"
    case irritable = "irritable"
    case anxious = "anxious"
    case sad = "sad"
    case energetic = "energetic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .sensitive: return "Sensitive"
        case .irritable: return "Irritable"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .energetic: return "Energetic"
        }
    }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "😌"
        case .sensitive: return "🥺"
        case .irritable: return "😤"
        case .anxious: return "😰"
        case .sad: return "😢"
        case .energetic: return "⚡"
        }
    }
}

// MARK: - Cervical Mucus Type

enum CervicalMucusType: String, Codable, CaseIterable, Identifiable {
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
}

// MARK: - Cycle Phase

enum CyclePhase: String, Codable, CaseIterable, Identifiable {
    case menstrual = "menstrual"
    case follicular = "follicular"
    case ovulation = "ovulation"
    case luteal = "luteal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .menstrual: return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation: return "Ovulation"
        case .luteal: return "Luteal"
        }
    }

    var description: String {
        switch self {
        case .menstrual: return "Period days"
        case .follicular: return "Body preparing to ovulate"
        case .ovulation: return "Most fertile window"
        case .luteal: return "Post-ovulation phase"
        }
    }

    var color: Color {
        switch self {
        case .menstrual: return Color(hex: "E53935")
        case .follicular: return Color(hex: "FF9800")
        case .ovulation: return Color(hex: "4CAF50")
        case .luteal: return Color(hex: "7C4DFF")
        }
    }

    var icon: String {
        switch self {
        case .menstrual: return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation: return "sparkles"
        case .luteal: return "moon.fill"
        }
    }
}

// MARK: - Menstrual Cycle

struct MenstrualCycle: Identifiable, Codable, Equatable {
    let id: UUID
    var periodStart: Date
    var periodEnd: Date?
    var cycleLength: Int?
    var periodLength: Int?
    var flowIntensity: FlowIntensity?
    var symptoms: [String]
    var painLevel: Int?
    var mood: String?
    var energyLevel: Int?
    var notes: String?

    // Predictions
    var predictedPeriodStart: Date?
    var predictedOvulation: Date?
    var fertileWindowStart: Date?
    var fertileWindowEnd: Date?

    // Fertility tracking
    var ovulationDate: Date?
    var basalBodyTemp: Double?
    var cervicalMucus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case cycleLength = "cycle_length"
        case periodLength = "period_length"
        case flowIntensity = "flow_intensity"
        case symptoms
        case painLevel = "pain_level"
        case mood
        case energyLevel = "energy_level"
        case notes
        case predictedPeriodStart = "predicted_period_start"
        case predictedOvulation = "predicted_ovulation"
        case fertileWindowStart = "fertile_window_start"
        case fertileWindowEnd = "fertile_window_end"
        case ovulationDate = "ovulation_date"
        case basalBodyTemp = "basal_body_temp"
        case cervicalMucus = "cervical_mucus"
    }

    init(
        id: UUID = UUID(),
        periodStart: Date,
        periodEnd: Date? = nil,
        cycleLength: Int? = nil,
        periodLength: Int? = nil,
        flowIntensity: FlowIntensity? = nil,
        symptoms: [String] = [],
        painLevel: Int? = nil,
        mood: String? = nil,
        energyLevel: Int? = nil,
        notes: String? = nil,
        predictedPeriodStart: Date? = nil,
        predictedOvulation: Date? = nil,
        fertileWindowStart: Date? = nil,
        fertileWindowEnd: Date? = nil,
        ovulationDate: Date? = nil,
        basalBodyTemp: Double? = nil,
        cervicalMucus: String? = nil
    ) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.flowIntensity = flowIntensity
        self.symptoms = symptoms
        self.painLevel = painLevel
        self.mood = mood
        self.energyLevel = energyLevel
        self.notes = notes
        self.predictedPeriodStart = predictedPeriodStart
        self.predictedOvulation = predictedOvulation
        self.fertileWindowStart = fertileWindowStart
        self.fertileWindowEnd = fertileWindowEnd
        self.ovulationDate = ovulationDate
        self.basalBodyTemp = basalBodyTemp
        self.cervicalMucus = cervicalMucus
    }

    var isActive: Bool {
        periodEnd == nil
    }

    var computedPeriodLength: Int? {
        guard let end = periodEnd else { return nil }
        return Calendar.current.dateComponents([.day], from: periodStart, to: end).day.map { $0 + 1 }
    }
}

// MARK: - Daily Log Entry (for day-by-day logging)

struct DailyPeriodLog: Identifiable, Equatable {
    let id: UUID
    let date: Date
    var flow: FlowIntensity?
    var symptoms: [PeriodSymptom]
    var mood: MoodType?
    var painLevel: Int // 0-10
    var energyLevel: Int // 1-5
    var notes: String?
    var cervicalMucus: CervicalMucusType?
    var basalBodyTemp: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        flow: FlowIntensity? = nil,
        symptoms: [PeriodSymptom] = [],
        mood: MoodType? = nil,
        painLevel: Int = 0,
        energyLevel: Int = 3,
        notes: String? = nil,
        cervicalMucus: CervicalMucusType? = nil,
        basalBodyTemp: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.flow = flow
        self.symptoms = symptoms
        self.mood = mood
        self.painLevel = painLevel
        self.energyLevel = energyLevel
        self.notes = notes
        self.cervicalMucus = cervicalMucus
        self.basalBodyTemp = basalBodyTemp
    }
}

// MARK: - Cycle Prediction

struct CyclePrediction: Equatable {
    let nextPeriodStart: Date
    let nextOvulation: Date?
    let fertileWindowStart: Date?
    let fertileWindowEnd: Date?
    let averageCycleLength: Int
    let averagePeriodLength: Int
    let confidence: Double // 0.0 to 1.0

    var daysUntilNextPeriod: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: nextPeriodStart).day ?? 0
    }

    var daysUntilOvulation: Int? {
        guard let ovulation = nextOvulation else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: ovulation).day
    }
}

// MARK: - Cycle Insights

struct CycleInsights: Equatable {
    let averageCycleLength: Int
    let averagePeriodLength: Int
    let mostCommonSymptoms: [PeriodSymptom]
    let averagePainLevel: Double
    let cycleRegularity: String // "Regular", "Slightly Irregular", "Irregular"
    let totalCyclesLogged: Int
}

// MARK: - Menstruation Data State

enum MenstruationDataState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(String)
}
