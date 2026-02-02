//
//  DietService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Business logic for diet tracking and nutrition calculations
//

import Foundation

// MARK: - Protocol

protocol DietServiceProtocol {
    func calculateDailyNutrition(entries: [DietLogEntry]) -> NutritionSummary
    func calculateMacroBreakdown(entries: [DietLogEntry]) -> MacroBreakdown
    func suggestCalorieGoal(weight: Double, height: Int, age: Int, gender: String, activityLevel: ActivityLevel, goal: GoalType) -> Int
    func calculateInsights(entries: [DietLogEntry], weeklyData: [[DietLogEntry]], dailyGoal: Int) -> DietInsights
    func getMealLogs(from entries: [DietLogEntry], for mealType: MealType) -> [DietLogEntry]
    func searchFoods(query: String, in foodItems: [FoodItem]) -> [FoodItem]
}

// MARK: - Implementation

final class DietService: DietServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = DietService()
    
    private init() {}
    
    // MARK: - Nutrition Calculations
    
    func calculateDailyNutrition(entries: [DietLogEntry]) -> NutritionSummary {
        guard !entries.isEmpty else {
            return NutritionSummary.empty
        }
        
        let totalCalories = entries.reduce(0.0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0.0) { $0 + $1.proteinG }
        let totalCarbs = entries.reduce(0.0) { $0 + $1.carbsG }
        let totalFat = entries.reduce(0.0) { $0 + $1.fatG }
        let totalFiber = entries.reduce(0.0) { $0 + ($1.fiberG ?? 0) }
        
        return NutritionSummary(
            totalCalories: totalCalories,
            totalProteinG: totalProtein,
            totalCarbsG: totalCarbs,
            totalFatG: totalFat,
            totalFiberG: totalFiber,
            mealCount: entries.count
        )
    }
    
    func calculateMacroBreakdown(entries: [DietLogEntry]) -> MacroBreakdown {
        guard !entries.isEmpty else {
            return MacroBreakdown.empty
        }
        
        let totalProtein = entries.reduce(0.0) { $0 + $1.proteinG }
        let totalCarbs = entries.reduce(0.0) { $0 + $1.carbsG }
        let totalFat = entries.reduce(0.0) { $0 + $1.fatG }
        
        return MacroBreakdown(
            proteinG: totalProtein,
            carbsG: totalCarbs,
            fatG: totalFat
        )
    }
    
    // MARK: - Goal Calculations
    
    func suggestCalorieGoal(
        weight: Double,
        height: Int,
        age: Int,
        gender: String,
        activityLevel: ActivityLevel,
        goal: GoalType
    ) -> Int {
        // Calculate BMR
        let bmr = CalorieCalculator.calculateBMR(
            weightKg: weight,
            heightCm: height,
            age: age,
            gender: gender
        )
        
        // Calculate TDEE
        let tdee = CalorieCalculator.calculateTDEE(
            bmr: bmr,
            activityLevel: activityLevel
        )
        
        // Calculate goal-based calories
        return CalorieCalculator.calculateCalorieGoal(
            tdee: tdee,
            goalType: goal
        )
    }
    
    // MARK: - Insights
    
    func calculateInsights(
        entries: [DietLogEntry],
        weeklyData: [[DietLogEntry]],
        dailyGoal: Int
    ) -> DietInsights {
        // Calculate weekly average
        let weeklyCalories = weeklyData.map { dayEntries in
            dayEntries.reduce(0.0) { $0 + $1.calories }
        }
        let weeklyAverage = weeklyCalories.isEmpty ? 0 : Int(weeklyCalories.reduce(0, +) / Double(weeklyCalories.count))
        
        // Calculate streak
        let streak = calculateStreak(weeklyData: weeklyData, dailyGoal: dailyGoal)
        
        // Find best day
        let bestDay = findBestDay(weeklyData: weeklyData)
        
        // Get top foods
        let topFoods = getTopFoods(entries: entries)
        
        // Macro balance assessment
        let macroBalance = assessMacroBalance(entries: entries)
        
        return DietInsights(
            weeklyAverageCalories: weeklyAverage,
            currentStreak: streak,
            bestDay: bestDay,
            topFoods: topFoods,
            macroBalance: macroBalance
        )
    }
    
    private func calculateStreak(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> Int {
        var streak = 0
        
        for dayEntries in weeklyData.reversed() {
            let dayCalories = dayEntries.reduce(0.0) { $0 + $1.calories }
            if dayCalories >= Double(dailyGoal) * 0.9 { // 90% of goal counts
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func findBestDay(weeklyData: [[DietLogEntry]]) -> (date: Date, calories: Int)? {
        var bestDay: (date: Date, calories: Int)?
        
        for dayEntries in weeklyData {
            guard let firstEntry = dayEntries.first else { continue }
            let dayCalories = Int(dayEntries.reduce(0.0) { $0 + $1.calories })
            
            if bestDay == nil || dayCalories > bestDay!.calories {
                bestDay = (date: firstEntry.loggedAt, calories: dayCalories)
            }
        }
        
        return bestDay
    }
    
    private func getTopFoods(entries: [DietLogEntry]) -> [String] {
        let foodCounts = Dictionary(grouping: entries, by: { $0.foodName })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(foodCounts.prefix(3).map { $0.key })
    }
    
    private func assessMacroBalance(entries: [DietLogEntry]) -> String {
        let breakdown = calculateMacroBreakdown(entries: entries)
        
        let proteinPercent = breakdown.proteinPercent
        let carbsPercent = breakdown.carbsPercent
        let fatPercent = breakdown.fatPercent
        
        // Ideal ranges: Protein 20-35%, Carbs 45-65%, Fat 20-35%
        if proteinPercent >= 20 && proteinPercent <= 35 &&
           carbsPercent >= 45 && carbsPercent <= 65 &&
           fatPercent >= 20 && fatPercent <= 35 {
            return "Well balanced"
        } else if proteinPercent < 20 {
            return "Low protein"
        } else if proteinPercent > 35 {
            return "High protein"
        } else if carbsPercent < 45 {
            return "Low carbs"
        } else if carbsPercent > 65 {
            return "High carbs"
        } else if fatPercent < 20 {
            return "Low fat"
        } else {
            return "High fat"
        }
    }
    
    // MARK: - Filtering
    
    func getMealLogs(from entries: [DietLogEntry], for mealType: MealType) -> [DietLogEntry] {
        entries.filter { $0.mealType == mealType }
            .sorted { $0.loggedAt > $1.loggedAt }
    }
    
    // MARK: - Search
    
    func searchFoods(query: String, in foodItems: [FoodItem]) -> [FoodItem] {
        guard !query.isEmpty else { return foodItems }
        
        let lowercasedQuery = query.lowercased()
        return foodItems.filter { food in
            food.name.lowercased().contains(lowercasedQuery) ||
            (food.brand?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
}
