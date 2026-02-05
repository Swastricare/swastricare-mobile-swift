//
//  FoodTrackingModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Food and nutrition tracking data structures
//

import Foundation
import SwiftUI

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        case .snack: return .green
        }
    }

    var suggestedTimeRange: String {
        switch self {
        case .breakfast: return "6:00 AM – 10:00 AM"
        case .lunch: return "11:00 AM – 2:00 PM"
        case .dinner: return "6:00 PM – 9:00 PM"
        case .snack: return "Anytime"
        }
    }
}

// MARK: - Food Category

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case grain = "grain"
    case protein = "protein"
    case dairy = "dairy"
    case fruit = "fruit"
    case vegetable = "vegetable"
    case fat = "fat"
    case beverage = "beverage"
    case sweet = "sweet"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grain: return "Grains & Cereals"
        case .protein: return "Protein"
        case .dairy: return "Dairy"
        case .fruit: return "Fruits"
        case .vegetable: return "Vegetables"
        case .fat: return "Fats & Oils"
        case .beverage: return "Beverages"
        case .sweet: return "Sweets & Desserts"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .grain: return "leaf.fill"
        case .protein: return "fish.fill"
        case .dairy: return "mug.fill"
        case .fruit: return "apple.logo"
        case .vegetable: return "carrot.fill"
        case .fat: return "drop.halffull"
        case .beverage: return "cup.and.saucer.fill"
        case .sweet: return "birthday.cake.fill"
        case .other: return "fork.knife"
        }
    }

    var color: Color {
        switch self {
        case .grain: return .brown
        case .protein: return .red
        case .dairy: return Color(red: 0.9, green: 0.9, blue: 1.0)
        case .fruit: return .pink
        case .vegetable: return .green
        case .fat: return .yellow
        case .beverage: return .cyan
        case .sweet: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - Serving Unit

enum ServingUnit: String, Codable, CaseIterable, Identifiable {
    case gram = "g"
    case milligram = "mg"
    case kilogram = "kg"
    case ounce = "oz"
    case cup = "cup"
    case tablespoon = "tbsp"
    case teaspoon = "tsp"
    case piece = "piece"
    case slice = "slice"
    case bowl = "bowl"
    case plate = "plate"
    case milliliter = "ml"
    case liter = "L"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gram: return "Grams (g)"
        case .milligram: return "Milligrams (mg)"
        case .kilogram: return "Kilograms (kg)"
        case .ounce: return "Ounces (oz)"
        case .cup: return "Cup"
        case .tablespoon: return "Tablespoon (tbsp)"
        case .teaspoon: return "Teaspoon (tsp)"
        case .piece: return "Piece"
        case .slice: return "Slice"
        case .bowl: return "Bowl"
        case .plate: return "Plate"
        case .milliliter: return "Milliliters (ml)"
        case .liter: return "Liters (L)"
        }
    }

    var abbreviation: String { rawValue }
}

// MARK: - Nutrition Info

struct NutritionInfo: Codable, Equatable {
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var sugarGrams: Double?
    var sodiumMg: Double?

    init(
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        sodiumMg: Double? = nil
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMg = sodiumMg
    }

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case fiberGrams = "fiber_grams"
        case sugarGrams = "sugar_grams"
        case sodiumMg = "sodium_mg"
    }

    /// Total macronutrient grams (protein + carbs + fat)
    var totalMacroGrams: Double {
        proteinGrams + carbsGrams + fatGrams
    }

    /// Percentage of calories from protein
    var proteinPercentage: Double {
        guard calories > 0 else { return 0 }
        return (proteinGrams * 4.0) / calories * 100
    }

    /// Percentage of calories from carbs
    var carbsPercentage: Double {
        guard calories > 0 else { return 0 }
        return (carbsGrams * 4.0) / calories * 100
    }

    /// Percentage of calories from fat
    var fatPercentage: Double {
        guard calories > 0 else { return 0 }
        return (fatGrams * 9.0) / calories * 100
    }

    /// Add two nutrition infos together
    static func + (lhs: NutritionInfo, rhs: NutritionInfo) -> NutritionInfo {
        NutritionInfo(
            calories: lhs.calories + rhs.calories,
            proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
            carbsGrams: lhs.carbsGrams + rhs.carbsGrams,
            fatGrams: lhs.fatGrams + rhs.fatGrams,
            fiberGrams: (lhs.fiberGrams ?? 0) + (rhs.fiberGrams ?? 0),
            sugarGrams: (lhs.sugarGrams ?? 0) + (rhs.sugarGrams ?? 0),
            sodiumMg: (lhs.sodiumMg ?? 0) + (rhs.sodiumMg ?? 0)
        )
    }
}

// MARK: - Food Entry

struct FoodEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var mealType: MealType
    var category: FoodCategory
    var servingSize: Double
    var servingUnit: ServingUnit
    var numberOfServings: Double
    var nutrition: NutritionInfo
    let consumedAt: Date
    var notes: String?
    var imageURL: String?
    var isSynced: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType,
        category: FoodCategory = .other,
        servingSize: Double = 1,
        servingUnit: ServingUnit = .piece,
        numberOfServings: Double = 1,
        nutrition: NutritionInfo = NutritionInfo(),
        consumedAt: Date = Date(),
        notes: String? = nil,
        imageURL: String? = nil,
        isSynced: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.category = category
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.numberOfServings = numberOfServings
        self.nutrition = nutrition
        self.consumedAt = consumedAt
        self.notes = notes
        self.imageURL = imageURL
        self.isSynced = isSynced
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Total nutrition based on number of servings
    var totalNutrition: NutritionInfo {
        NutritionInfo(
            calories: nutrition.calories * numberOfServings,
            proteinGrams: nutrition.proteinGrams * numberOfServings,
            carbsGrams: nutrition.carbsGrams * numberOfServings,
            fatGrams: nutrition.fatGrams * numberOfServings,
            fiberGrams: (nutrition.fiberGrams ?? 0) * numberOfServings,
            sugarGrams: (nutrition.sugarGrams ?? 0) * numberOfServings,
            sodiumMg: (nutrition.sodiumMg ?? 0) * numberOfServings
        )
    }

    /// Formatted serving description
    var servingDescription: String {
        let servingText = numberOfServings == 1
            ? "\(formatted(servingSize)) \(servingUnit.abbreviation)"
            : "\(formatted(numberOfServings)) x \(formatted(servingSize)) \(servingUnit.abbreviation)"
        return servingText
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: consumedAt)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Daily Nutrition Goal

struct DailyNutritionGoal: Codable, Equatable {
    var calorieTarget: Int
    var proteinTargetGrams: Int
    var carbsTargetGrams: Int
    var fatTargetGrams: Int
    var fiberTargetGrams: Int?

    init(
        calorieTarget: Int = 2000,
        proteinTargetGrams: Int = 50,
        carbsTargetGrams: Int = 250,
        fatTargetGrams: Int = 65,
        fiberTargetGrams: Int? = 25
    ) {
        self.calorieTarget = calorieTarget
        self.proteinTargetGrams = proteinTargetGrams
        self.carbsTargetGrams = carbsTargetGrams
        self.fatTargetGrams = fatTargetGrams
        self.fiberTargetGrams = fiberTargetGrams
    }

    enum CodingKeys: String, CodingKey {
        case calorieTarget = "calorie_target"
        case proteinTargetGrams = "protein_target_grams"
        case carbsTargetGrams = "carbs_target_grams"
        case fatTargetGrams = "fat_target_grams"
        case fiberTargetGrams = "fiber_target_grams"
    }
}

// MARK: - Daily Nutrition Summary

struct DailyNutritionSummary: Equatable {
    let date: Date
    let entries: [FoodEntry]
    let goal: DailyNutritionGoal

    /// Combined nutrition from all entries
    var totalNutrition: NutritionInfo {
        entries.reduce(NutritionInfo()) { $0 + $1.totalNutrition }
    }

    var totalCalories: Double { totalNutrition.calories }
    var totalProtein: Double { totalNutrition.proteinGrams }
    var totalCarbs: Double { totalNutrition.carbsGrams }
    var totalFat: Double { totalNutrition.fatGrams }

    var caloriesRemaining: Int {
        max(0, goal.calorieTarget - Int(totalCalories))
    }

    var calorieProgress: Double {
        guard goal.calorieTarget > 0 else { return 0 }
        return min(1.0, totalCalories / Double(goal.calorieTarget))
    }

    var proteinProgress: Double {
        guard goal.proteinTargetGrams > 0 else { return 0 }
        return min(1.0, totalProtein / Double(goal.proteinTargetGrams))
    }

    var carbsProgress: Double {
        guard goal.carbsTargetGrams > 0 else { return 0 }
        return min(1.0, totalCarbs / Double(goal.carbsTargetGrams))
    }

    var fatProgress: Double {
        guard goal.fatTargetGrams > 0 else { return 0 }
        return min(1.0, totalFat / Double(goal.fatTargetGrams))
    }

    /// Entries grouped by meal type
    var entriesByMeal: [MealType: [FoodEntry]] {
        Dictionary(grouping: entries, by: \.mealType)
    }

    /// Calories per meal type
    func calories(for mealType: MealType) -> Double {
        entriesByMeal[mealType]?.reduce(0) { $0 + $1.totalNutrition.calories } ?? 0
    }

    /// Number of entries for a meal type
    func entryCount(for mealType: MealType) -> Int {
        entriesByMeal[mealType]?.count ?? 0
    }
}

// MARK: - Food Data State

enum FoodDataState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Quick Add Food Preset

struct QuickAddFoodPreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let mealType: MealType
    let category: FoodCategory
    let servingSize: Double
    let servingUnit: ServingUnit
    let nutrition: NutritionInfo

    static let defaults: [QuickAddFoodPreset] = [
        QuickAddFoodPreset(
            name: "Apple",
            icon: "apple.logo",
            mealType: .snack,
            category: .fruit,
            servingSize: 1,
            servingUnit: .piece,
            nutrition: NutritionInfo(calories: 95, proteinGrams: 0.5, carbsGrams: 25, fatGrams: 0.3, fiberGrams: 4.4)
        ),
        QuickAddFoodPreset(
            name: "Boiled Egg",
            icon: "oval.fill",
            mealType: .breakfast,
            category: .protein,
            servingSize: 1,
            servingUnit: .piece,
            nutrition: NutritionInfo(calories: 78, proteinGrams: 6, carbsGrams: 0.6, fatGrams: 5)
        ),
        QuickAddFoodPreset(
            name: "Rice (1 cup)",
            icon: "leaf.fill",
            mealType: .lunch,
            category: .grain,
            servingSize: 1,
            servingUnit: .cup,
            nutrition: NutritionInfo(calories: 206, proteinGrams: 4.3, carbsGrams: 45, fatGrams: 0.4)
        ),
        QuickAddFoodPreset(
            name: "Chicken Breast",
            icon: "fish.fill",
            mealType: .lunch,
            category: .protein,
            servingSize: 100,
            servingUnit: .gram,
            nutrition: NutritionInfo(calories: 165, proteinGrams: 31, carbsGrams: 0, fatGrams: 3.6)
        ),
        QuickAddFoodPreset(
            name: "Banana",
            icon: "leaf.fill",
            mealType: .snack,
            category: .fruit,
            servingSize: 1,
            servingUnit: .piece,
            nutrition: NutritionInfo(calories: 105, proteinGrams: 1.3, carbsGrams: 27, fatGrams: 0.4, fiberGrams: 3.1)
        ),
        QuickAddFoodPreset(
            name: "Greek Yogurt",
            icon: "mug.fill",
            mealType: .breakfast,
            category: .dairy,
            servingSize: 1,
            servingUnit: .cup,
            nutrition: NutritionInfo(calories: 100, proteinGrams: 17, carbsGrams: 6, fatGrams: 0.7)
        )
    ]
}

// MARK: - Database Record Models

struct FoodEntryRecord: Codable {
    let id: UUID?
    let healthProfileId: UUID
    let name: String
    let mealType: String
    let category: String
    let servingSize: Double
    let servingUnit: String
    let numberOfServings: Double
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let sugarGrams: Double?
    let sodiumMg: Double?
    let consumedAt: Date
    let notes: String?
    let imageUrl: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case name
        case mealType = "meal_type"
        case category
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case numberOfServings = "number_of_servings"
        case calories
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case fiberGrams = "fiber_grams"
        case sugarGrams = "sugar_grams"
        case sodiumMg = "sodium_mg"
        case consumedAt = "consumed_at"
        case notes
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from entry: FoodEntry, healthProfileId: UUID) {
        self.id = entry.id
        self.healthProfileId = healthProfileId
        self.name = entry.name
        self.mealType = entry.mealType.rawValue
        self.category = entry.category.rawValue
        self.servingSize = entry.servingSize
        self.servingUnit = entry.servingUnit.rawValue
        self.numberOfServings = entry.numberOfServings
        self.calories = entry.totalNutrition.calories
        self.proteinGrams = entry.totalNutrition.proteinGrams
        self.carbsGrams = entry.totalNutrition.carbsGrams
        self.fatGrams = entry.totalNutrition.fatGrams
        self.fiberGrams = entry.totalNutrition.fiberGrams
        self.sugarGrams = entry.totalNutrition.sugarGrams
        self.sodiumMg = entry.totalNutrition.sodiumMg
        self.consumedAt = entry.consumedAt
        self.notes = entry.notes
        self.imageUrl = entry.imageURL
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
    }

    func toFoodEntry() -> FoodEntry {
        FoodEntry(
            id: id ?? UUID(),
            name: name,
            mealType: MealType(rawValue: mealType) ?? .snack,
            category: FoodCategory(rawValue: category) ?? .other,
            servingSize: servingSize,
            servingUnit: ServingUnit(rawValue: servingUnit) ?? .piece,
            numberOfServings: numberOfServings,
            nutrition: NutritionInfo(
                calories: numberOfServings > 0 ? calories / numberOfServings : calories,
                proteinGrams: numberOfServings > 0 ? proteinGrams / numberOfServings : proteinGrams,
                carbsGrams: numberOfServings > 0 ? carbsGrams / numberOfServings : carbsGrams,
                fatGrams: numberOfServings > 0 ? fatGrams / numberOfServings : fatGrams,
                fiberGrams: fiberGrams.map { numberOfServings > 0 ? $0 / numberOfServings : $0 },
                sugarGrams: sugarGrams.map { numberOfServings > 0 ? $0 / numberOfServings : $0 },
                sodiumMg: sodiumMg.map { numberOfServings > 0 ? $0 / numberOfServings : $0 }
            ),
            consumedAt: consumedAt,
            notes: notes,
            imageURL: imageUrl,
            isSynced: true,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

struct DailyNutritionGoalRecord: Codable {
    let id: UUID?
    let healthProfileId: UUID
    let calorieTarget: Int
    let proteinTargetGrams: Int
    let carbsTargetGrams: Int
    let fatTargetGrams: Int
    let fiberTargetGrams: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case calorieTarget = "calorie_target"
        case proteinTargetGrams = "protein_target_grams"
        case carbsTargetGrams = "carbs_target_grams"
        case fatTargetGrams = "fat_target_grams"
        case fiberTargetGrams = "fiber_target_grams"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from goal: DailyNutritionGoal, healthProfileId: UUID) {
        self.id = nil
        self.healthProfileId = healthProfileId
        self.calorieTarget = goal.calorieTarget
        self.proteinTargetGrams = goal.proteinTargetGrams
        self.carbsTargetGrams = goal.carbsTargetGrams
        self.fatTargetGrams = goal.fatTargetGrams
        self.fiberTargetGrams = goal.fiberTargetGrams
        self.createdAt = nil
        self.updatedAt = nil
    }

    func toDailyNutritionGoal() -> DailyNutritionGoal {
        DailyNutritionGoal(
            calorieTarget: calorieTarget,
            proteinTargetGrams: proteinTargetGrams,
            carbsTargetGrams: carbsTargetGrams,
            fatTargetGrams: fatTargetGrams,
            fiberTargetGrams: fiberTargetGrams
        )
    }
}
