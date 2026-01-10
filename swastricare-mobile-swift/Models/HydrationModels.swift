//
//  HydrationModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Smart Hydration Tracking System
//

import Foundation
import SwiftUI

// MARK: - Activity Level

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary = "sedentary"
    case moderate = "moderate"
    case high = "high"
    case outdoor = "outdoor"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .moderate: return "Moderate Activity"
        case .high: return "High Activity"
        case .outdoor: return "Outdoor/Hot Climate"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Desk job, minimal exercise"
        case .moderate: return "Regular exercise, active lifestyle"
        case .high: return "Intense workouts, athlete"
        case .outdoor: return "Outdoor work, hot climate exposure"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 0.9
        case .moderate: return 1.0
        case .high: return 1.15
        case .outdoor: return 1.2
        }
    }
    
    var icon: String {
        switch self {
        case .sedentary: return "figure.seated.side"
        case .moderate: return "figure.walk"
        case .high: return "figure.run"
        case .outdoor: return "sun.max.fill"
        }
    }
}

// MARK: - Drink Type

enum DrinkType: String, Codable, CaseIterable, Identifiable {
    case water = "water"
    case tea = "tea"
    case coffee = "coffee"
    case juice = "juice"
    case milk = "milk"
    case sportsDrink = "sports_drink"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .water: return "Water"
        case .tea: return "Tea"
        case .coffee: return "Coffee"
        case .juice: return "Juice"
        case .milk: return "Milk"
        case .sportsDrink: return "Sports Drink"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .tea: return "cup.and.saucer.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .juice: return "wineglass.fill"
        case .milk: return "mug.fill"
        case .sportsDrink: return "waterbottle.fill"
        case .other: return "drop.halffull"
        }
    }
    
    var color: Color {
        switch self {
        case .water: return .cyan
        case .tea: return .brown
        case .coffee: return Color(red: 0.4, green: 0.26, blue: 0.13)
        case .juice: return .orange
        case .milk: return Color(white: 0.95)
        case .sportsDrink: return .green
        case .other: return .gray
        }
    }
    
    /// Hydration effectiveness multiplier (caffeine is a mild diuretic)
    var hydrationMultiplier: Double {
        switch self {
        case .water: return 1.0
        case .tea: return 0.85
        case .coffee: return 0.8
        case .juice: return 0.9
        case .milk: return 0.9
        case .sportsDrink: return 1.0
        case .other: return 0.9
        }
    }
    
    /// Whether this drink contains caffeine
    var containsCaffeine: Bool {
        switch self {
        case .coffee, .tea: return true
        default: return false
        }
    }
}

// MARK: - Hydration Entry

struct HydrationEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let amountMl: Int
    let drinkType: DrinkType
    let notes: String?
    var synced: Bool
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        amountMl: Int,
        drinkType: DrinkType = .water,
        notes: String? = nil,
        synced: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.amountMl = amountMl
        self.drinkType = drinkType
        self.notes = notes
        self.synced = synced
    }
    
    /// Effective hydration amount after applying drink type multiplier
    var effectiveHydration: Int {
        Int(Double(amountMl) * drinkType.hydrationMultiplier)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Hydration Preferences

struct HydrationPreferences: Codable, Equatable {
    var userId: UUID?
    var weightKg: Double?
    var heightCm: Int?
    var activityLevel: ActivityLevel
    var climateAdjustment: Double
    var isPregnant: Bool
    var isBreastfeeding: Bool
    var customGoalMl: Int?
    var useHealthKitWeight: Bool
    var useWeatherAdjustment: Bool
    var syncToHealthKit: Bool
    var updatedAt: Date?
    
    init(
        userId: UUID? = nil,
        weightKg: Double? = nil,
        heightCm: Int? = nil,
        activityLevel: ActivityLevel = .moderate,
        climateAdjustment: Double = 1.0,
        isPregnant: Bool = false,
        isBreastfeeding: Bool = false,
        customGoalMl: Int? = nil,
        useHealthKitWeight: Bool = true,
        useWeatherAdjustment: Bool = true,
        syncToHealthKit: Bool = true,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.activityLevel = activityLevel
        self.climateAdjustment = climateAdjustment
        self.isPregnant = isPregnant
        self.isBreastfeeding = isBreastfeeding
        self.customGoalMl = customGoalMl
        self.useHealthKitWeight = useHealthKitWeight
        self.useWeatherAdjustment = useWeatherAdjustment
        self.syncToHealthKit = syncToHealthKit
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case activityLevel = "activity_level"
        case climateAdjustment = "climate_adjustment"
        case isPregnant = "is_pregnant"
        case isBreastfeeding = "is_breastfeeding"
        case customGoalMl = "custom_goal_ml"
        case useHealthKitWeight = "use_healthkit_weight"
        case useWeatherAdjustment = "use_weather_adjustment"
        case syncToHealthKit = "sync_to_healthkit"
        case updatedAt = "updated_at"
    }
}

// MARK: - Hydration Goal

struct HydrationGoal: Equatable {
    let dailyTargetMl: Int
    let currentIntakeMl: Int
    let effectiveIntakeMl: Int
    let breakdown: GoalBreakdown
    
    var remainingMl: Int {
        max(0, dailyTargetMl - effectiveIntakeMl)
    }
    
    var percentComplete: Double {
        guard dailyTargetMl > 0 else { return 0 }
        return min(1.0, Double(effectiveIntakeMl) / Double(dailyTargetMl))
    }
    
    var isGoalMet: Bool {
        effectiveIntakeMl >= dailyTargetMl
    }
    
    struct GoalBreakdown: Equatable {
        let baseAmount: Int
        let activityAdjustment: Int
        let weatherAdjustment: Int
        let pregnancyAddition: Int
        let breastfeedingAddition: Int
        let exerciseAddition: Int
        
        var description: String {
            var parts: [String] = []
            parts.append("\(baseAmount)ml base")
            
            if activityAdjustment != 0 {
                let sign = activityAdjustment > 0 ? "+" : ""
                parts.append("\(sign)\(activityAdjustment)ml activity")
            }
            if weatherAdjustment > 0 {
                parts.append("+\(weatherAdjustment)ml weather")
            }
            if pregnancyAddition > 0 {
                parts.append("+\(pregnancyAddition)ml pregnancy")
            }
            if breastfeedingAddition > 0 {
                parts.append("+\(breastfeedingAddition)ml breastfeeding")
            }
            if exerciseAddition > 0 {
                parts.append("+\(exerciseAddition)ml exercise")
            }
            
            return parts.joined(separator: ", ")
        }
    }
}

// MARK: - Hydration Calculator

struct HydrationCalculator {
    
    /// Base multiplier: 33ml per kg of body weight
    static let baseMultiplier: Double = 33.0
    
    /// Additional water for pregnancy (ml)
    static let pregnancyAddition: Int = 300
    
    /// Additional water for breastfeeding (ml)
    static let breastfeedingAddition: Int = 700
    
    /// Additional water per hour of exercise (ml)
    static let exerciseAdditionPerHour: Int = 500
    
    /// Weather threshold for heat adjustment (Celsius)
    static let heatThreshold: Double = 30.0
    
    /// Weather heat multiplier
    static let heatMultiplier: Double = 1.2
    
    /// Default goal if no weight available (ml)
    static let defaultGoal: Int = 2500
    
    /// Calculate daily hydration goal
    static func calculateDailyGoal(
        weightKg: Double?,
        activityLevel: ActivityLevel,
        temperature: Double? = nil,
        isPregnant: Bool = false,
        isBreastfeeding: Bool = false,
        exerciseMinutes: Int = 0,
        useWeatherAdjustment: Bool = true
    ) -> (goal: Int, breakdown: HydrationGoal.GoalBreakdown) {
        
        // Base calculation
        let weight = weightKg ?? 70.0 // Default to 70kg if not available
        let baseAmount = Int(weight * baseMultiplier)
        
        // Activity adjustment
        let activityAdjusted = Double(baseAmount) * activityLevel.multiplier
        let activityAdjustment = Int(activityAdjusted) - baseAmount
        
        // Weather adjustment
        var weatherAdjustment = 0
        var weatherMultiplied = activityAdjusted
        if useWeatherAdjustment, let temp = temperature, temp > heatThreshold {
            weatherMultiplied = activityAdjusted * heatMultiplier
            weatherAdjustment = Int(weatherMultiplied - activityAdjusted)
        }
        
        // Special conditions
        let pregnancyAdd = isPregnant ? pregnancyAddition : 0
        let breastfeedingAdd = isBreastfeeding ? breastfeedingAddition : 0
        
        // Exercise adjustment
        let exerciseHours = Double(exerciseMinutes) / 60.0
        let exerciseAdd = Int(exerciseHours * Double(exerciseAdditionPerHour))
        
        // Total
        let totalGoal = Int(weatherMultiplied) + pregnancyAdd + breastfeedingAdd + exerciseAdd
        
        let breakdown = HydrationGoal.GoalBreakdown(
            baseAmount: baseAmount,
            activityAdjustment: activityAdjustment,
            weatherAdjustment: weatherAdjustment,
            pregnancyAddition: pregnancyAdd,
            breastfeedingAddition: breastfeedingAdd,
            exerciseAddition: exerciseAdd
        )
        
        return (totalGoal, breakdown)
    }
}

// MARK: - Urine Color Guide

enum UrineColor: Int, CaseIterable, Identifiable {
    case clear = 0
    case paleYellow = 1
    case lightYellow = 2
    case yellow = 3
    case darkYellow = 4
    case amber = 5
    case honey = 6
    case brown = 7
    
    var id: Int { rawValue }
    
    var color: Color {
        switch self {
        case .clear: return Color(red: 0.98, green: 0.98, blue: 0.95)
        case .paleYellow: return Color(red: 0.98, green: 0.97, blue: 0.8)
        case .lightYellow: return Color(red: 0.98, green: 0.95, blue: 0.6)
        case .yellow: return Color(red: 0.98, green: 0.9, blue: 0.4)
        case .darkYellow: return Color(red: 0.95, green: 0.85, blue: 0.3)
        case .amber: return Color(red: 0.9, green: 0.7, blue: 0.2)
        case .honey: return Color(red: 0.8, green: 0.55, blue: 0.15)
        case .brown: return Color(red: 0.6, green: 0.35, blue: 0.1)
        }
    }
    
    var status: HydrationStatus {
        switch self {
        case .clear, .paleYellow: return .overHydrated
        case .lightYellow, .yellow: return .wellHydrated
        case .darkYellow: return .mildlyDehydrated
        case .amber, .honey: return .dehydrated
        case .brown: return .severelyDehydrated
        }
    }
    
    var displayName: String {
        switch self {
        case .clear: return "Clear"
        case .paleYellow: return "Pale Yellow"
        case .lightYellow: return "Light Yellow"
        case .yellow: return "Yellow"
        case .darkYellow: return "Dark Yellow"
        case .amber: return "Amber"
        case .honey: return "Honey"
        case .brown: return "Brown"
        }
    }
}

enum HydrationStatus: String {
    case overHydrated = "over_hydrated"
    case wellHydrated = "well_hydrated"
    case mildlyDehydrated = "mildly_dehydrated"
    case dehydrated = "dehydrated"
    case severelyDehydrated = "severely_dehydrated"
    
    var displayName: String {
        switch self {
        case .overHydrated: return "Over Hydrated"
        case .wellHydrated: return "Well Hydrated"
        case .mildlyDehydrated: return "Mildly Dehydrated"
        case .dehydrated: return "Dehydrated"
        case .severelyDehydrated: return "Severely Dehydrated"
        }
    }
    
    var recommendation: String {
        switch self {
        case .overHydrated:
            return "You might be drinking too much water. Slow down a bit unless you're exercising heavily."
        case .wellHydrated:
            return "Great job! You're well hydrated. Keep up the good work."
        case .mildlyDehydrated:
            return "Time to drink some water. Have a glass now."
        case .dehydrated:
            return "You need to drink water soon. Aim for 2-3 glasses in the next hour."
        case .severelyDehydrated:
            return "Drink water immediately. If this persists, consult a healthcare provider."
        }
    }
    
    var color: Color {
        switch self {
        case .overHydrated: return .blue
        case .wellHydrated: return .green
        case .mildlyDehydrated: return .yellow
        case .dehydrated: return .orange
        case .severelyDehydrated: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .overHydrated: return "drop.fill"
        case .wellHydrated: return "checkmark.circle.fill"
        case .mildlyDehydrated: return "exclamationmark.circle.fill"
        case .dehydrated: return "exclamationmark.triangle.fill"
        case .severelyDehydrated: return "xmark.circle.fill"
        }
    }
}

// MARK: - Hydration Insights

struct HydrationInsights: Equatable {
    let currentStreak: Int
    let averageDailyIntake: Int
    let bestDayThisWeek: (date: Date, amount: Int)?
    let caffeineCount: Int
    let caffeineWarning: String?
    
    static func == (lhs: HydrationInsights, rhs: HydrationInsights) -> Bool {
        lhs.currentStreak == rhs.currentStreak &&
        lhs.averageDailyIntake == rhs.averageDailyIntake &&
        lhs.caffeineCount == rhs.caffeineCount
    }
}

// MARK: - Quick Add Presets

struct QuickAddPreset: Identifiable {
    let id = UUID()
    let amountMl: Int
    let label: String
    let icon: String
    
    static let defaults: [QuickAddPreset] = [
        QuickAddPreset(amountMl: 100, label: "100ml", icon: "drop"),
        QuickAddPreset(amountMl: 250, label: "250ml", icon: "drop.fill"),
        QuickAddPreset(amountMl: 500, label: "500ml", icon: "waterbottle"),
        QuickAddPreset(amountMl: 750, label: "750ml", icon: "waterbottle.fill"),
        QuickAddPreset(amountMl: 1000, label: "1L", icon: "rectangle.stack.fill")
    ]
}

// MARK: - Supabase Record Models

struct HydrationEntryRecord: Codable {
    let id: UUID?
    let healthProfileId: UUID
    let beverageType: String
    let amountMl: Int
    let consumedAt: Date
    let notes: String?
    let hydrationFactor: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case beverageType = "beverage_type"
        case amountMl = "amount_ml"
        case consumedAt = "consumed_at"
        case notes
        case hydrationFactor = "hydration_factor"
    }
    
    init(from entry: HydrationEntry, healthProfileId: UUID) {
        self.id = entry.id
        self.healthProfileId = healthProfileId
        self.consumedAt = entry.timestamp
        self.amountMl = entry.amountMl
        self.beverageType = entry.drinkType.rawValue
        self.notes = entry.notes
        self.hydrationFactor = entry.drinkType.hydrationMultiplier
    }
    
    func toHydrationEntry() -> HydrationEntry {
        HydrationEntry(
            id: id ?? UUID(),
            timestamp: consumedAt,
            amountMl: amountMl,
            drinkType: DrinkType(rawValue: beverageType) ?? .water,
            notes: notes,
            synced: true
        )
    }
}
