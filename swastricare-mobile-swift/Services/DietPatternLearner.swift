//
//  DietPatternLearner.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Learns user's diet patterns for intelligent insights and coaching
//

import Foundation

// MARK: - Diet Pattern Data Models

/// Insight types based on meal timing analysis
enum MealTimingInsightType: String, Codable, Equatable {
    case lateDinner
    case skippedBreakfast
    case irregularTiming
    case consistentSchedule
    case largeGapBetweenMeals
}

/// Severity of a timing insight
enum InsightSeverity: String, Codable, Equatable {
    case info
    case suggestion
    case warning
}

/// A single meal timing insight derived from pattern analysis
struct MealTimingInsight: Codable, Equatable, Identifiable {
    var id: String { type.rawValue }
    let type: MealTimingInsightType
    let message: String
    let severity: InsightSeverity
}

/// A detected nutrient gap based on weekly intake vs recommended levels
struct NutrientGap: Codable, Equatable, Identifiable {
    var id: String { nutrient }
    let nutrient: String
    let averageIntake: Double
    let recommendedIntake: Double
    let deficitPercent: Double
    let suggestion: String
}

/// Learned eating patterns from historical meal data
struct DietPattern: Codable, Equatable {
    /// Probability of eating each meal type at each hour (0-23)
    var mealTimeProbability: [String: [String: Double]]

    /// Average calories per meal type
    var averageCaloriesPerMeal: [String: Int]

    /// Preferred meal times (hour component) for each meal type
    var preferredMealHours: [String: Int]

    /// How often each meal is skipped (0.0 - 1.0)
    var skippedMealFrequency: [String: Double]

    /// Total days of data collected
    var daysOfData: Int

    /// Meal log count per meal type per day tracking
    var mealLogCounts: [String: Int]

    /// Total days each meal type was possible (days tracked)
    var totalDaysTracked: Int

    /// Last time patterns were updated
    var lastUpdated: Date

    init() {
        self.mealTimeProbability = [:]
        self.averageCaloriesPerMeal = [:]
        self.preferredMealHours = [:]
        self.skippedMealFrequency = [:]
        self.daysOfData = 0
        self.mealLogCounts = [:]
        self.totalDaysTracked = 0
        self.lastUpdated = Date()
    }

    /// Minimum 7 days of data for reliable patterns
    var hasEnoughData: Bool {
        daysOfData >= 7
    }
}

// MARK: - Diet Pattern Learner Protocol

protocol DietPatternLearnerProtocol {
    func recordMealLogged(mealType: MealType, at time: Date, calories: Int)
    func getPattern() -> DietPattern
    func getMealTimingInsights() -> [MealTimingInsight]
    func getNutrientGaps(weeklyData: [[DietLogEntry]], goals: DietGoals) -> [NutrientGap]
    func reset()
}

// MARK: - Diet Pattern Learner Implementation

final class DietPatternLearner: DietPatternLearnerProtocol {

    static let shared = DietPatternLearner()

    // MARK: - Properties

    private let userDefaults = UserDefaults.standard
    private let patternKey = "diet_pattern_data"

    private var pattern: DietPattern {
        didSet {
            savePattern()
        }
    }

    // MARK: - Init

    private init() {
        self.pattern = DietPatternLearner.loadPattern()
    }

    // MARK: - Recording Methods

    /// Record a meal being logged to learn timing and calorie patterns
    func recordMealLogged(mealType: MealType, at time: Date, calories: Int) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let mealKey = mealType.rawValue

        // Update meal time probability for this hour
        var hourMap = pattern.mealTimeProbability[mealKey] ?? [:]
        let hourKey = String(hour)
        let currentCount = hourMap[hourKey] ?? 0
        hourMap[hourKey] = currentCount + 1
        pattern.mealTimeProbability[mealKey] = hourMap

        // Update average calories per meal (exponential moving average)
        let currentAvg = pattern.averageCaloriesPerMeal[mealKey] ?? 0
        if currentAvg == 0 {
            pattern.averageCaloriesPerMeal[mealKey] = calories
        } else {
            let alpha = 0.3
            pattern.averageCaloriesPerMeal[mealKey] = Int(Double(currentAvg) * (1 - alpha) + Double(calories) * alpha)
        }

        // Update preferred meal time (most frequent hour)
        if let hourMap = pattern.mealTimeProbability[mealKey] {
            let bestHour = hourMap.max(by: { $0.value < $1.value })?.key
            if let bestHourStr = bestHour, let bestHourInt = Int(bestHourStr) {
                pattern.preferredMealHours[mealKey] = bestHourInt
            }
        }

        // Track meal log counts for skip frequency
        let logCount = pattern.mealLogCounts[mealKey] ?? 0
        pattern.mealLogCounts[mealKey] = logCount + 1

        // Update days tracked
        updateDaysTracked(timestamp: time)

        // Recalculate skip frequencies
        recalculateSkipFrequencies()

        pattern.lastUpdated = Date()

        print("🍎 DietPatternLearner: Recorded \(mealKey) at hour \(hour), \(calories) cal")
    }

    // MARK: - Query Methods

    /// Get the current learned pattern
    func getPattern() -> DietPattern {
        return pattern
    }

    /// Analyze meal timing patterns and return actionable insights
    func getMealTimingInsights() -> [MealTimingInsight] {
        guard pattern.hasEnoughData else {
            return [MealTimingInsight(
                type: .consistentSchedule,
                message: "Keep logging meals to learn your eating patterns! Need \(max(0, 7 - pattern.daysOfData)) more days of data.",
                severity: .info
            )]
        }

        var insights: [MealTimingInsight] = []

        // Check for late dinner pattern
        if let dinnerHour = pattern.preferredMealHours[MealType.dinner.rawValue], dinnerHour >= 21 {
            insights.append(MealTimingInsight(
                type: .lateDinner,
                message: "You tend to eat dinner after 9 PM. Try having dinner by 8 PM for better digestion.",
                severity: .warning
            ))
        }

        // Check for skipped breakfast
        let breakfastSkipRate = pattern.skippedMealFrequency[MealType.breakfast.rawValue] ?? 0
        if breakfastSkipRate > 0.4 {
            let skipPercent = Int(breakfastSkipRate * 100)
            insights.append(MealTimingInsight(
                type: .skippedBreakfast,
                message: "You skip breakfast \(skipPercent)% of the time. A light breakfast like idli or poha can boost your morning energy.",
                severity: .suggestion
            ))
        }

        // Check for large gap between meals
        let lunchHour = pattern.preferredMealHours[MealType.lunch.rawValue] ?? 13
        let dinnerHour = pattern.preferredMealHours[MealType.dinner.rawValue] ?? 20
        if dinnerHour - lunchHour >= 7 {
            insights.append(MealTimingInsight(
                type: .largeGapBetweenMeals,
                message: "There's a \(dinnerHour - lunchHour)-hour gap between your lunch and dinner. An evening snack like sprouts chaat or fruit can help maintain energy.",
                severity: .suggestion
            ))
        }

        // Check for irregular timing
        let hasIrregularTiming = checkIrregularTiming()
        if hasIrregularTiming {
            insights.append(MealTimingInsight(
                type: .irregularTiming,
                message: "Your meal times vary a lot day to day. Consistent meal timing helps regulate metabolism.",
                severity: .suggestion
            ))
        }

        // Positive reinforcement for consistent schedule
        if !hasIrregularTiming && breakfastSkipRate < 0.2 && insights.isEmpty {
            insights.append(MealTimingInsight(
                type: .consistentSchedule,
                message: "Great job! You have a consistent eating schedule. This helps maintain steady energy levels.",
                severity: .info
            ))
        }

        return insights
    }

    /// Detect nutrient gaps from weekly intake data
    func getNutrientGaps(weeklyData: [[DietLogEntry]], goals: DietGoals) -> [NutrientGap] {
        let daysWithData = weeklyData.filter { !$0.isEmpty }
        guard !daysWithData.isEmpty else { return [] }

        let dayCount = Double(daysWithData.count)
        var gaps: [NutrientGap] = []

        // Calculate average daily intakes
        let totalProtein = daysWithData.flatMap { $0 }.reduce(0.0) { $0 + $1.proteinG }
        let totalFat = daysWithData.flatMap { $0 }.reduce(0.0) { $0 + $1.fatG }
        let totalFiber = daysWithData.flatMap { $0 }.reduce(0.0) { $0 + ($1.fiberG ?? 0) }
        let totalCalories = daysWithData.flatMap { $0 }.reduce(0.0) { $0 + $1.calories }

        let avgProtein = totalProtein / dayCount
        let avgFat = totalFat / dayCount
        let avgFiber = totalFiber / dayCount
        let avgCalories = totalCalories / dayCount

        // Protein goal from DietGoals (grams)
        let proteinGoal = Double(goals.proteinGrams)
        if proteinGoal > 0 {
            let proteinPercent = (avgProtein / proteinGoal) * 100
            if proteinPercent < 80 {
                let deficit = 100 - proteinPercent
                gaps.append(NutrientGap(
                    nutrient: "Protein",
                    averageIntake: avgProtein,
                    recommendedIntake: proteinGoal,
                    deficitPercent: deficit,
                    suggestion: "Add dal, paneer, curd, or eggs to your meals. A glass of buttermilk or a handful of chana also helps."
                ))
            }
        }

        // Fat goal from DietGoals
        let fatGoal = Double(goals.fatGrams)
        if fatGoal > 0 {
            let fatPercent = (avgFat / fatGoal) * 100
            if fatPercent < 80 {
                let deficit = 100 - fatPercent
                gaps.append(NutrientGap(
                    nutrient: "Healthy Fats",
                    averageIntake: avgFat,
                    recommendedIntake: fatGoal,
                    deficitPercent: deficit,
                    suggestion: "Include a handful of almonds or walnuts, or add a teaspoon of ghee to your dal or roti."
                ))
            }
        }

        // Fiber: recommended ~25g/day
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

        // Calorie intake check (under-eating)
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

    /// Reset all learned patterns
    func reset() {
        pattern = DietPattern()
        savePattern()
        print("🍎 DietPatternLearner: Patterns reset")
    }

    // MARK: - Private Helpers

    private func checkIrregularTiming() -> Bool {
        // Check if meal times are spread across many different hours
        for mealType in [MealType.breakfast, .lunch, .dinner] {
            guard let hourMap = pattern.mealTimeProbability[mealType.rawValue] else { continue }
            let usedHours = hourMap.filter { $0.value > 0 }.count
            // If a meal is logged at more than 4 different hours, timing is irregular
            if usedHours > 4 {
                return true
            }
        }
        return false
    }

    private func recalculateSkipFrequencies() {
        guard pattern.totalDaysTracked > 0 else { return }

        for mealType in MealType.allCases {
            let mealKey = mealType.rawValue
            let logCount = pattern.mealLogCounts[mealKey] ?? 0
            // Skip rate = 1 - (days meal was logged / total days tracked)
            let skipRate = 1.0 - min(1.0, Double(logCount) / Double(pattern.totalDaysTracked))
            pattern.skippedMealFrequency[mealKey] = skipRate
        }
    }

    private func updateDaysTracked(timestamp: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: timestamp)
        let lastTrackedDay = calendar.startOfDay(for: pattern.lastUpdated)

        if today > lastTrackedDay {
            pattern.daysOfData += 1
            pattern.totalDaysTracked += 1
        }
    }

    // MARK: - Persistence

    private func savePattern() {
        if let encoded = try? JSONEncoder().encode(pattern) {
            userDefaults.set(encoded, forKey: patternKey)
        }
    }

    private static func loadPattern() -> DietPattern {
        guard let data = UserDefaults.standard.data(forKey: "diet_pattern_data"),
              let pattern = try? JSONDecoder().decode(DietPattern.self, from: data) else {
            return DietPattern()
        }
        return pattern
    }
}

// MARK: - Pattern Insights for UI

extension DietPatternLearner {

    /// Get human-readable insights about diet patterns
    func getPatternInsights() -> [String] {
        var insights: [String] = []

        guard pattern.hasEnoughData else {
            insights.append("Keep logging meals to learn your eating patterns!")
            return insights
        }

        // Preferred meal times
        for mealType in [MealType.breakfast, .lunch, .dinner] {
            if let hour = pattern.preferredMealHours[mealType.rawValue] {
                let period = hour < 12 ? "AM" : "PM"
                let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
                insights.append("You usually have \(mealType.displayName.lowercased()) around \(displayHour) \(period)")
            }
        }

        // Average calories per meal
        if let breakfastCal = pattern.averageCaloriesPerMeal[MealType.breakfast.rawValue],
           let lunchCal = pattern.averageCaloriesPerMeal[MealType.lunch.rawValue],
           let dinnerCal = pattern.averageCaloriesPerMeal[MealType.dinner.rawValue] {
            let heaviestMeal: String
            if lunchCal >= breakfastCal && lunchCal >= dinnerCal {
                heaviestMeal = "lunch"
            } else if dinnerCal >= breakfastCal {
                heaviestMeal = "dinner"
            } else {
                heaviestMeal = "breakfast"
            }
            insights.append("Your heaviest meal is usually \(heaviestMeal)")
        }

        // Days tracked
        insights.append("Based on \(pattern.daysOfData) days of data")

        return insights
    }
}
