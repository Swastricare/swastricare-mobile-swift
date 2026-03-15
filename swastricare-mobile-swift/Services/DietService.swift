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
    func calculateWeeklyTrend(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> [DailyCalorieTrend]
    func calculateGoalAdherence(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> GoalAdherence
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
    
    // MARK: - Search (Fuzzy + Ranked)

    func searchFoods(query: String, in foodItems: [FoodItem]) -> [FoodItem] {
        guard !query.isEmpty else { return foodItems }

        let lowercasedQuery = query.lowercased()
        let queryTokens = lowercasedQuery.split(separator: " ").map(String.init)

        // Score each food item for relevance
        var scored: [(food: FoodItem, score: Int)] = []

        for food in foodItems {
            let name = food.name.lowercased()
            let brand = food.brand?.lowercased() ?? ""
            let category = food.category.displayName.lowercased()
            var score = 0

            // Exact name match (highest priority)
            if name == lowercasedQuery {
                score += 100
            }
            // Name starts with query
            else if name.hasPrefix(lowercasedQuery) {
                score += 80
            }
            // Name contains query as substring
            else if name.contains(lowercasedQuery) {
                score += 60
            }

            // Token-based matching (fuzzy): each token that matches adds score
            for token in queryTokens {
                if name.contains(token) {
                    score += 30
                }
                if brand.contains(token) {
                    score += 15
                }
                if category.contains(token) {
                    score += 10
                }
                // Prefix match on word boundaries in food name
                let nameWords = name.split(separator: " ").map(String.init)
                for word in nameWords {
                    if word.hasPrefix(token) && token.count >= 2 {
                        score += 20
                    }
                }
            }

            // Levenshtein-like: short edit distance boost for single-token queries
            if queryTokens.count == 1 {
                let nameWords = name.split(separator: " ").map(String.init)
                for word in nameWords {
                    if word.count > 2 && lowercasedQuery.count > 2 {
                        let common = Set(word).intersection(Set(lowercasedQuery))
                        let similarity = Double(common.count) / Double(max(word.count, lowercasedQuery.count))
                        if similarity >= 0.6 {
                            score += Int(similarity * 25)
                        }
                    }
                }
            }

            if score > 0 {
                scored.append((food: food, score: score))
            }
        }

        // Sort by score descending, then alphabetically
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.food.name < $1.food.name }
            .map(\.food)
    }

    // MARK: - Weekly Trend

    func calculateWeeklyTrend(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> [DailyCalorieTrend] {
        let calendar = Calendar.current
        let today = Date()
        var trends: [DailyCalorieTrend] = []

        for (index, dayEntries) in weeklyData.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: -index, to: today) else { continue }
            let totalCalories = Int(dayEntries.reduce(0.0) { $0 + $1.calories })
            let progress = dailyGoal > 0 ? min(Double(totalCalories) / Double(dailyGoal), 1.5) : 0

            trends.append(DailyCalorieTrend(
                date: date,
                calories: totalCalories,
                goal: dailyGoal,
                progress: progress
            ))
        }

        return trends.reversed() // Oldest first
    }

    // MARK: - Goal Adherence

    func calculateGoalAdherence(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> GoalAdherence {
        guard !weeklyData.isEmpty else {
            return GoalAdherence(daysTracked: 0, daysOnTarget: 0, adherencePercent: 0, rating: .needsWork)
        }

        let daysTracked = weeklyData.filter { !$0.isEmpty }.count
        let daysOnTarget = weeklyData.filter { dayEntries in
            let dayCalories = dayEntries.reduce(0.0) { $0 + $1.calories }
            // Within 10% of goal (above or below)
            let lowerBound = Double(dailyGoal) * 0.9
            let upperBound = Double(dailyGoal) * 1.1
            return dayCalories >= lowerBound && dayCalories <= upperBound
        }.count

        let adherencePercent = daysTracked > 0 ? Int((Double(daysOnTarget) / Double(daysTracked)) * 100) : 0

        let rating: GoalAdherence.Rating
        switch adherencePercent {
        case 80...100: rating = .excellent
        case 60..<80: rating = .good
        case 40..<60: rating = .fair
        default: rating = .needsWork
        }

        return GoalAdherence(
            daysTracked: daysTracked,
            daysOnTarget: daysOnTarget,
            adherencePercent: adherencePercent,
            rating: rating
        )
    }
}
