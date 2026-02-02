//
//  DietModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Diet Chart and Nutritional Tracking System
//

import Foundation
import SwiftUI

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "breakfast"
    case morningSnack = "morning_snack"
    case lunch = "lunch"
    case eveningSnack = "evening_snack"
    case dinner = "dinner"
    case lateNight = "late_night"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .morningSnack: return "Morning Snack"
        case .lunch: return "Lunch"
        case .eveningSnack: return "Evening Snack"
        case .dinner: return "Dinner"
        case .lateNight: return "Late Night"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .morningSnack: return "cup.and.saucer.fill"
        case .lunch: return "sun.max.fill"
        case .eveningSnack: return "leaf.fill"
        case .dinner: return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .morningSnack: return .brown
        case .lunch: return .yellow
        case .eveningSnack: return .green
        case .dinner: return .blue
        case .lateNight: return .purple
        }
    }
    
    var typicalTime: String {
        switch self {
        case .breakfast: return "7:00 AM - 9:00 AM"
        case .morningSnack: return "10:00 AM - 11:00 AM"
        case .lunch: return "12:00 PM - 2:00 PM"
        case .eveningSnack: return "4:00 PM - 5:00 PM"
        case .dinner: return "7:00 PM - 9:00 PM"
        case .lateNight: return "10:00 PM - 11:00 PM"
        }
    }
}

// MARK: - Goal Type

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case weightLoss = "weight_loss"
    case weightGain = "weight_gain"
    case maintenance = "maintenance"
    case muscleBuilding = "muscle_building"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .weightLoss: return "Weight Loss"
        case .weightGain: return "Weight Gain"
        case .maintenance: return "Maintenance"
        case .muscleBuilding: return "Muscle Building"
        }
    }
    
    var description: String {
        switch self {
        case .weightLoss: return "Reduce body weight through calorie deficit"
        case .weightGain: return "Increase body weight through calorie surplus"
        case .maintenance: return "Maintain current weight"
        case .muscleBuilding: return "Build muscle mass with high protein"
        }
    }
    
    var icon: String {
        switch self {
        case .weightLoss: return "arrow.down.circle.fill"
        case .weightGain: return "arrow.up.circle.fill"
        case .maintenance: return "equal.circle.fill"
        case .muscleBuilding: return "figure.strengthtraining.traditional"
        }
    }
    
    var color: Color {
        switch self {
        case .weightLoss: return .red
        case .weightGain: return .green
        case .maintenance: return .blue
        case .muscleBuilding: return .orange
        }
    }
}

// MARK: - Food Category

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case fruits = "fruits"
    case vegetables = "vegetables"
    case grains = "grains"
    case protein = "protein"
    case dairy = "dairy"
    case beverages = "beverages"
    case snacks = "snacks"
    case sweets = "sweets"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fruits: return "Fruits"
        case .vegetables: return "Vegetables"
        case .grains: return "Grains"
        case .protein: return "Protein"
        case .dairy: return "Dairy"
        case .beverages: return "Beverages"
        case .snacks: return "Snacks"
        case .sweets: return "Sweets"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .fruits: return "🍎"
        case .vegetables: return "🥗"
        case .grains: return "🌾"
        case .protein: return "🍗"
        case .dairy: return "🥛"
        case .beverages: return "☕"
        case .snacks: return "🍿"
        case .sweets: return "🍰"
        case .other: return "🍽️"
        }
    }
}

// MARK: - Serving Unit

enum ServingUnit: String, Codable, CaseIterable, Identifiable {
    case g = "g"
    case ml = "ml"
    case piece = "piece"
    case cup = "cup"
    case tbsp = "tbsp"
    case tsp = "tsp"
    case oz = "oz"
    case bowl = "bowl"
    case plate = "plate"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .g: return "grams"
        case .ml: return "ml"
        case .piece: return "piece"
        case .cup: return "cup"
        case .tbsp: return "tbsp"
        case .tsp: return "tsp"
        case .oz: return "oz"
        case .bowl: return "bowl"
        case .plate: return "plate"
        }
    }
}

// MARK: - Food Item

struct FoodItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let brand: String?
    let servingSize: Double
    let servingUnit: ServingUnit
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let isVegetarian: Bool
    let isVegan: Bool
    let category: FoodCategory
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        servingSize: Double,
        servingUnit: ServingUnit,
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double? = nil,
        sugarG: Double? = nil,
        sodiumMg: Double? = nil,
        isVegetarian: Bool = true,
        isVegan: Bool = false,
        category: FoodCategory,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.isVegetarian = isVegetarian
        self.isVegan = isVegan
        self.category = category
        self.createdAt = createdAt
    }
    
    var displayServingSize: String {
        "\(Int(servingSize)) \(servingUnit.displayName)"
    }
    
    var caloriesPerServing: String {
        "\(Int(calories)) cal"
    }
    
    var macroSummary: String {
        "P: \(Int(proteinG))g • C: \(Int(carbsG))g • F: \(Int(fatG))g"
    }
}

// MARK: - Diet Log Entry

struct DietLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let foodItemId: UUID?
    let mealType: MealType
    let foodName: String
    let quantity: Double
    let servingUnit: ServingUnit
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let loggedAt: Date
    let notes: String?
    var synced: Bool
    
    init(
        id: UUID = UUID(),
        foodItemId: UUID? = nil,
        mealType: MealType,
        foodName: String,
        quantity: Double,
        servingUnit: ServingUnit,
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double? = nil,
        loggedAt: Date = Date(),
        notes: String? = nil,
        synced: Bool = false
    ) {
        self.id = id
        self.foodItemId = foodItemId
        self.mealType = mealType
        self.foodName = foodName
        self.quantity = quantity
        self.servingUnit = servingUnit
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.loggedAt = loggedAt
        self.notes = notes
        self.synced = synced
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: loggedAt)
    }
    
    var displayQuantity: String {
        "\(quantity.formatted(.number.precision(.fractionLength(0...1)))) \(servingUnit.displayName)"
    }
}

// MARK: - Diet Goals

struct DietGoals: Codable, Equatable {
    var userId: UUID?
    var dailyCalories: Int
    var proteinPercent: Int
    var carbsPercent: Int
    var fatPercent: Int
    var waterGoalMl: Int
    var mealRemindersEnabled: Bool
    var updatedAt: Date?
    
    init(
        userId: UUID? = nil,
        dailyCalories: Int = 2000,
        proteinPercent: Int = 25,
        carbsPercent: Int = 50,
        fatPercent: Int = 25,
        waterGoalMl: Int = 2500,
        mealRemindersEnabled: Bool = true,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.dailyCalories = dailyCalories
        self.proteinPercent = proteinPercent
        self.carbsPercent = carbsPercent
        self.fatPercent = fatPercent
        self.waterGoalMl = waterGoalMl
        self.mealRemindersEnabled = mealRemindersEnabled
        self.updatedAt = updatedAt
    }
    
    var proteinGrams: Int {
        Int(Double(dailyCalories) * Double(proteinPercent) / 100.0 / 4.0)
    }
    
    var carbsGrams: Int {
        Int(Double(dailyCalories) * Double(carbsPercent) / 100.0 / 4.0)
    }
    
    var fatGrams: Int {
        Int(Double(dailyCalories) * Double(fatPercent) / 100.0 / 9.0)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case dailyCalories = "daily_calories"
        case proteinPercent = "protein_percent"
        case carbsPercent = "carbs_percent"
        case fatPercent = "fat_percent"
        case waterGoalMl = "water_goal_ml"
        case mealRemindersEnabled = "meal_reminders_enabled"
        case updatedAt = "updated_at"
    }
}

// MARK: - Nutrition Summary

struct NutritionSummary: Equatable {
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let totalFiberG: Double
    let mealCount: Int
    
    var caloriesFormatted: String {
        "\(Int(totalCalories))"
    }
    
    var proteinFormatted: String {
        "\(Int(totalProteinG))g"
    }
    
    var carbsFormatted: String {
        "\(Int(totalCarbsG))g"
    }
    
    var fatFormatted: String {
        "\(Int(totalFatG))g"
    }
    
    var fiberFormatted: String {
        "\(Int(totalFiberG))g"
    }
    
    static var empty: NutritionSummary {
        NutritionSummary(
            totalCalories: 0,
            totalProteinG: 0,
            totalCarbsG: 0,
            totalFatG: 0,
            totalFiberG: 0,
            mealCount: 0
        )
    }
}

// MARK: - Macro Breakdown

struct MacroBreakdown: Equatable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let proteinCalories: Double
    let carbsCalories: Double
    let fatCalories: Double
    
    var totalCalories: Double {
        proteinCalories + carbsCalories + fatCalories
    }
    
    var proteinPercent: Double {
        guard totalCalories > 0 else { return 0 }
        return (proteinCalories / totalCalories) * 100
    }
    
    var carbsPercent: Double {
        guard totalCalories > 0 else { return 0 }
        return (carbsCalories / totalCalories) * 100
    }
    
    var fatPercent: Double {
        guard totalCalories > 0 else { return 0 }
        return (fatCalories / totalCalories) * 100
    }
    
    init(proteinG: Double, carbsG: Double, fatG: Double) {
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.proteinCalories = proteinG * 4.0
        self.carbsCalories = carbsG * 4.0
        self.fatCalories = fatG * 9.0
    }
    
    static var empty: MacroBreakdown {
        MacroBreakdown(proteinG: 0, carbsG: 0, fatG: 0)
    }
}

// MARK: - Diet Plan

struct DietPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let healthProfileId: UUID
    let name: String
    let goalType: GoalType
    let targetCalories: Int
    let targetProteinG: Int
    let targetCarbsG: Int
    let targetFatG: Int
    let isActive: Bool
    let startDate: Date
    let endDate: Date?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: UUID = UUID(),
        healthProfileId: UUID,
        name: String,
        goalType: GoalType,
        targetCalories: Int,
        targetProteinG: Int,
        targetCarbsG: Int,
        targetFatG: Int,
        isActive: Bool = true,
        startDate: Date = Date(),
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.healthProfileId = healthProfileId
        self.name = name
        self.goalType = goalType
        self.targetCalories = targetCalories
        self.targetProteinG = targetProteinG
        self.targetCarbsG = targetCarbsG
        self.targetFatG = targetFatG
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case name
        case goalType = "goal_type"
        case targetCalories = "target_calories"
        case targetProteinG = "target_protein_g"
        case targetCarbsG = "target_carbs_g"
        case targetFatG = "target_fat_g"
        case isActive = "is_active"
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Diet Insights

struct DietInsights: Equatable {
    let weeklyAverageCalories: Int
    let currentStreak: Int
    let bestDay: (date: Date, calories: Int)?
    let topFoods: [String]
    let macroBalance: String
    
    static func == (lhs: DietInsights, rhs: DietInsights) -> Bool {
        lhs.weeklyAverageCalories == rhs.weeklyAverageCalories &&
        lhs.currentStreak == rhs.currentStreak &&
        lhs.topFoods == rhs.topFoods &&
        lhs.macroBalance == rhs.macroBalance
    }
}

// MARK: - Supabase Record Models

struct DietLogRecord: Codable {
    let id: UUID?
    let healthProfileId: UUID
    let foodItemId: UUID?
    let mealType: String
    let foodName: String
    let quantity: Double
    let servingUnit: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let loggedAt: Date
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case foodItemId = "food_item_id"
        case mealType = "meal_type"
        case foodName = "food_name"
        case quantity
        case servingUnit = "serving_unit"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case loggedAt = "logged_at"
        case notes
    }
    
    init(from entry: DietLogEntry, healthProfileId: UUID) {
        self.id = entry.id
        self.healthProfileId = healthProfileId
        self.foodItemId = entry.foodItemId
        self.mealType = entry.mealType.rawValue
        self.foodName = entry.foodName
        self.quantity = entry.quantity
        self.servingUnit = entry.servingUnit.rawValue
        self.calories = entry.calories
        self.proteinG = entry.proteinG
        self.carbsG = entry.carbsG
        self.fatG = entry.fatG
        self.fiberG = entry.fiberG
        self.loggedAt = entry.loggedAt
        self.notes = entry.notes
    }
    
    func toDietLogEntry() -> DietLogEntry {
        DietLogEntry(
            id: id ?? UUID(),
            foodItemId: foodItemId,
            mealType: MealType(rawValue: mealType) ?? .breakfast,
            foodName: foodName,
            quantity: quantity,
            servingUnit: ServingUnit(rawValue: servingUnit) ?? .g,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            loggedAt: loggedAt,
            notes: notes,
            synced: true
        )
    }
}

struct FoodItemRecord: Codable {
    let id: UUID
    let name: String
    let brand: String?
    let servingSize: Double
    let servingUnit: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let isVegetarian: Bool
    let isVegan: Bool
    let category: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case isVegetarian = "is_vegetarian"
        case isVegan = "is_vegan"
        case category
        case createdAt = "created_at"
    }
    
    func toFoodItem() -> FoodItem {
        FoodItem(
            id: id,
            name: name,
            brand: brand,
            servingSize: servingSize,
            servingUnit: ServingUnit(rawValue: servingUnit) ?? .g,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            sugarG: sugarG,
            sodiumMg: sodiumMg,
            isVegetarian: isVegetarian,
            isVegan: isVegan,
            category: FoodCategory(rawValue: category) ?? .other,
            createdAt: createdAt
        )
    }
}

// MARK: - Calorie Calculator

struct CalorieCalculator {
    
    /// Calculate BMR using Mifflin-St Jeor Equation
    static func calculateBMR(weightKg: Double, heightCm: Int, age: Int, gender: String) -> Int {
        let weight = 10 * weightKg
        let height = 6.25 * Double(heightCm)
        let ageCalc = 5 * Double(age)
        
        let bmr: Double
        if gender.lowercased() == "male" {
            bmr = weight + height - ageCalc + 5
        } else {
            bmr = weight + height - ageCalc - 161
        }
        
        return Int(bmr)
    }
    
    /// Calculate TDEE (Total Daily Energy Expenditure)
    static func calculateTDEE(bmr: Int, activityLevel: ActivityLevel) -> Int {
        let multiplier = activityLevel.multiplier
        return Int(Double(bmr) * multiplier)
    }
    
    /// Calculate calorie goal based on goal type
    static func calculateCalorieGoal(tdee: Int, goalType: GoalType) -> Int {
        switch goalType {
        case .weightLoss:
            return tdee - 500 // 500 cal deficit for ~0.5kg/week loss
        case .weightGain:
            return tdee + 500 // 500 cal surplus for ~0.5kg/week gain
        case .maintenance:
            return tdee
        case .muscleBuilding:
            return tdee + 300 // Slight surplus for muscle building
        }
    }
    
    /// Calculate macro targets based on goal type
    static func calculateMacros(calories: Int, goalType: GoalType) -> (protein: Int, carbs: Int, fat: Int) {
        let proteinPercent: Double
        let carbsPercent: Double
        let fatPercent: Double
        
        switch goalType {
        case .weightLoss:
            proteinPercent = 0.30
            carbsPercent = 0.40
            fatPercent = 0.30
        case .weightGain:
            proteinPercent = 0.25
            carbsPercent = 0.50
            fatPercent = 0.25
        case .maintenance:
            proteinPercent = 0.25
            carbsPercent = 0.50
            fatPercent = 0.25
        case .muscleBuilding:
            proteinPercent = 0.35
            carbsPercent = 0.45
            fatPercent = 0.20
        }
        
        let proteinCal = Double(calories) * proteinPercent
        let carbsCal = Double(calories) * carbsPercent
        let fatCal = Double(calories) * fatPercent
        
        return (
            protein: Int(proteinCal / 4.0),
            carbs: Int(carbsCal / 4.0),
            fat: Int(fatCal / 9.0)
        )
    }
}
