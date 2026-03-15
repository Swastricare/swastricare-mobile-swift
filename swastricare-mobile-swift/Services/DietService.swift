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
    func calculateInsights(entries: [DietLogEntry], weeklyData: [[DietLogEntry]], dailyGoal: Int, goals: DietGoals, patternLearner: DietPatternLearnerProtocol?) -> DietInsights
    func getMealLogs(from entries: [DietLogEntry], for mealType: MealType) -> [DietLogEntry]
    func searchFoods(query: String, in foodItems: [FoodItem]) -> [FoodItem]
    func searchFoodsOnline(query: String) async throws -> [FoodItem]
    func calculateWeeklyTrend(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> [DailyCalorieTrend]
    func calculateGoalAdherence(weeklyData: [[DietLogEntry]], dailyGoal: Int) -> GoalAdherence
    func calculateNutrientGaps(weeklyData: [[DietLogEntry]], goals: DietGoals) -> [NutrientGap]
    func getMacroCoachingTips(breakdown: MacroBreakdown, goals: DietGoals) -> [String]
    func generateWeeklyReport(weeklyData: [[DietLogEntry]], goals: DietGoals, currentStreak: Int, bestStreak: Int, patternLearner: DietPatternLearnerProtocol?) -> WeeklyDietReport
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
        // Delegate to the enhanced version with nil pattern learner
        return calculateInsights(
            entries: entries,
            weeklyData: weeklyData,
            dailyGoal: dailyGoal,
            goals: DietGoals(dailyCalories: dailyGoal),
            patternLearner: nil
        )
    }

    func calculateInsights(
        entries: [DietLogEntry],
        weeklyData: [[DietLogEntry]],
        dailyGoal: Int,
        goals: DietGoals,
        patternLearner: DietPatternLearnerProtocol?
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

        // Pattern-based insights
        let mealTimingInsights = patternLearner?.getMealTimingInsights() ?? []
        let nutrientGaps = calculateNutrientGaps(weeklyData: weeklyData, goals: goals)

        // Macro coaching tips
        let breakdown = calculateMacroBreakdown(entries: entries)
        let coachingTips = getMacroCoachingTips(breakdown: breakdown, goals: goals)

        // Best streak from UserDefaults
        let bestStreak = loadBestStreak(currentStreak: streak)

        // Weekly report
        let weeklyReport = generateWeeklyReport(
            weeklyData: weeklyData,
            goals: goals,
            currentStreak: streak,
            bestStreak: bestStreak,
            patternLearner: patternLearner
        )

        return DietInsights(
            weeklyAverageCalories: weeklyAverage,
            currentStreak: streak,
            bestDay: bestDay,
            topFoods: topFoods,
            macroBalance: macroBalance,
            mealTimingInsights: mealTimingInsights,
            nutrientGaps: nutrientGaps,
            coachingTips: coachingTips,
            weeklyReport: weeklyReport,
            bestStreak: bestStreak
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

    // MARK: - Frequency Ranking

    /// Rank foods by usage frequency across all diet log entries.
    func frequencyRankedFoods(from logs: [DietLogEntry], limit: Int = 20) -> [String] {
        let counts = Dictionary(grouping: logs, by: { $0.foodName })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        return Array(counts.prefix(limit).map(\.key))
    }

    // MARK: - Search (Fuzzy + Ranked + Frequency Boost)

    func searchFoods(query: String, in foodItems: [FoodItem]) -> [FoodItem] {
        guard !query.isEmpty else { return foodItems }

        let lowercasedQuery = query.lowercased()
        let queryTokens = lowercasedQuery.split(separator: " ").map(String.init)

        // Get frequency data for boosting (done once per search)
        let frequencyRanks = MealSuggestionEngine.shared.frequencyRankedFoodNames(limit: 50)

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

            // Frequency boost: foods the user eats often get a relevance bump
            if score > 0, let freq = frequencyRanks[food.name], freq > 0 {
                score += min(freq * 5, 30) // Cap at +30
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

    // MARK: - Online Search

    func searchFoodsOnline(query: String) async throws -> [FoodItem] {
        guard !query.isEmpty, query.count >= 2 else { return [] }
        print("🍎 DietService: Searching online for '\(query)'")
        return try await SupabaseManager.shared.fetchFoodItems(query: query, limit: 30)
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

    // MARK: - Nutrient Gap Detection

    func calculateNutrientGaps(weeklyData: [[DietLogEntry]], goals: DietGoals) -> [NutrientGap] {
        let daysWithData = weeklyData.filter { !$0.isEmpty }
        guard !daysWithData.isEmpty else { return [] }

        let dayCount = Double(daysWithData.count)
        var gaps: [NutrientGap] = []

        let allEntries = daysWithData.flatMap { $0 }

        // Average daily intakes
        let avgProtein = allEntries.reduce(0.0) { $0 + $1.proteinG } / dayCount
        let avgFat = allEntries.reduce(0.0) { $0 + $1.fatG } / dayCount
        let avgFiber = allEntries.reduce(0.0) { $0 + ($1.fiberG ?? 0) } / dayCount
        let avgCalories = allEntries.reduce(0.0) { $0 + $1.calories } / dayCount

        // Protein check
        let proteinGoal = Double(goals.proteinGrams)
        if proteinGoal > 0 && avgProtein < proteinGoal * 0.8 {
            let deficit = ((proteinGoal - avgProtein) / proteinGoal) * 100
            gaps.append(NutrientGap(
                nutrient: "Protein",
                averageIntake: avgProtein,
                recommendedIntake: proteinGoal,
                deficitPercent: deficit,
                suggestion: "Add dal, paneer, curd, or eggs to your meals. A glass of buttermilk or a handful of chana also helps."
            ))
        }

        // Fat check
        let fatGoal = Double(goals.fatGrams)
        if fatGoal > 0 && avgFat < fatGoal * 0.8 {
            let deficit = ((fatGoal - avgFat) / fatGoal) * 100
            gaps.append(NutrientGap(
                nutrient: "Healthy Fats",
                averageIntake: avgFat,
                recommendedIntake: fatGoal,
                deficitPercent: deficit,
                suggestion: "Include a handful of almonds or walnuts, or add a teaspoon of ghee to your dal or roti."
            ))
        }

        // Fiber check (recommended ~25g/day)
        let fiberGoal = 25.0
        if avgFiber < fiberGoal * 0.8 {
            let deficit = ((fiberGoal - avgFiber) / fiberGoal) * 100
            gaps.append(NutrientGap(
                nutrient: "Fiber",
                averageIntake: avgFiber,
                recommendedIntake: fiberGoal,
                deficitPercent: deficit,
                suggestion: "Switch to brown rice or whole wheat roti. Add more sabzi, salads, and fruits like guava or apple."
            ))
        }

        // Calorie under-eating check
        let calorieGoal = Double(goals.dailyCalories)
        if calorieGoal > 0 && avgCalories < calorieGoal * 0.75 {
            let deficit = ((calorieGoal - avgCalories) / calorieGoal) * 100
            gaps.append(NutrientGap(
                nutrient: "Calories",
                averageIntake: avgCalories,
                recommendedIntake: calorieGoal,
                deficitPercent: deficit,
                suggestion: "You're eating significantly below your goal. Add a mid-morning snack like a banana or a paratha."
            ))
        }

        return gaps
    }

    // MARK: - Macro Coaching Tips

    func getMacroCoachingTips(breakdown: MacroBreakdown, goals: DietGoals) -> [String] {
        var tips: [String] = []

        guard breakdown.totalCalories > 0 else { return tips }

        let proteinPercent = breakdown.proteinPercent
        let carbsPercent = breakdown.carbsPercent
        let fatPercent = breakdown.fatPercent

        // Protein coaching
        if proteinPercent < 20 {
            tips.append("Your protein is low at \(Int(proteinPercent))%. Add dal, paneer, or curd to your meals for better muscle recovery.")
        } else if proteinPercent > 35 {
            tips.append("Protein is high at \(Int(proteinPercent))%. Balance with more whole grains like brown rice or chapati.")
        }

        // Carbs coaching
        if carbsPercent > 65 {
            tips.append("Carbs are high at \(Int(carbsPercent))%. Try replacing white rice with brown rice or adding more protein-rich sides.")
        } else if carbsPercent < 40 {
            tips.append("Carbs are low at \(Int(carbsPercent))%. Add whole grains like jowar roti, oats porridge, or sweet potato.")
        }

        // Fat coaching
        if fatPercent < 15 {
            tips.append("Healthy fats are very low. Add a handful of almonds, walnuts, or a teaspoon of ghee to your meals.")
        } else if fatPercent > 40 {
            tips.append("Fat intake is high at \(Int(fatPercent))%. Try grilling instead of frying, and reduce oil in curries.")
        }

        // Positive reinforcement
        if proteinPercent >= 20 && proteinPercent <= 35 &&
           carbsPercent >= 45 && carbsPercent <= 65 &&
           fatPercent >= 20 && fatPercent <= 35 {
            tips.append("Your macros are well balanced today. Keep up the great work!")
        }

        return tips
    }

    // MARK: - Weekly Report Generation

    func generateWeeklyReport(
        weeklyData: [[DietLogEntry]],
        goals: DietGoals,
        currentStreak: Int,
        bestStreak: Int,
        patternLearner: DietPatternLearnerProtocol?
    ) -> WeeklyDietReport {
        let mealTimingInsights = patternLearner?.getMealTimingInsights() ?? []
        let nutrientGaps = calculateNutrientGaps(weeklyData: weeklyData, goals: goals)

        return DietReportGenerator.shared.generateWeeklyReport(
            weeklyData: weeklyData,
            goals: goals,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            mealTimingInsights: mealTimingInsights,
            nutrientGaps: nutrientGaps
        )
    }

    // MARK: - Best Streak Persistence

    private func loadBestStreak(currentStreak: Int) -> Int {
        let storedBest = UserDefaults.standard.integer(forKey: "diet_best_streak")
        let best = max(storedBest, currentStreak)
        if best > storedBest {
            UserDefaults.standard.set(best, forKey: "diet_best_streak")
        }
        return best
    }
}
