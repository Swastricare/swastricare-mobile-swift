//
//  DietReport.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Weekly and monthly diet report models with improvement tip generation
//

import Foundation

// MARK: - Weekly Diet Report

struct WeeklyDietReport: Equatable {
    let startDate: Date
    let endDate: Date
    let averageDailyCalories: Int
    let calorieGoal: Int
    let adherencePercent: Double
    let totalMealsLogged: Int
    let bestDay: (date: Date, calories: Int)?
    let worstDay: (date: Date, calories: Int)?
    let macroAverages: MacroBreakdown
    let topFoods: [(name: String, count: Int)]
    let mealTimingInsights: [MealTimingInsight]
    let nutrientGaps: [NutrientGap]
    let streakInfo: (current: Int, best: Int)
    let improvementTips: [String]

    static func == (lhs: WeeklyDietReport, rhs: WeeklyDietReport) -> Bool {
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate &&
        lhs.averageDailyCalories == rhs.averageDailyCalories &&
        lhs.calorieGoal == rhs.calorieGoal &&
        lhs.totalMealsLogged == rhs.totalMealsLogged &&
        lhs.improvementTips == rhs.improvementTips
    }
}

// MARK: - Diet Report Generator

final class DietReportGenerator {

    static let shared = DietReportGenerator()

    private init() {}

    /// Build a weekly report from raw meal data, goals, and pattern insights
    func generateWeeklyReport(
        weeklyData: [[DietLogEntry]],
        goals: DietGoals,
        currentStreak: Int,
        bestStreak: Int,
        mealTimingInsights: [MealTimingInsight],
        nutrientGaps: [NutrientGap]
    ) -> WeeklyDietReport {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let endDate = today

        // Flatten all entries
        let allEntries = weeklyData.flatMap { $0 }
        let daysWithData = weeklyData.filter { !$0.isEmpty }

        // Average daily calories
        let dailyCalories = weeklyData.map { entries in
            Int(entries.reduce(0.0) { $0 + $1.calories })
        }
        let avgCalories = daysWithData.isEmpty ? 0 : dailyCalories.reduce(0, +) / daysWithData.count

        // Adherence (within 10% of goal)
        let daysOnTarget = weeklyData.filter { entries in
            let cal = entries.reduce(0.0) { $0 + $1.calories }
            let lower = Double(goals.dailyCalories) * 0.9
            let upper = Double(goals.dailyCalories) * 1.1
            return cal >= lower && cal <= upper
        }.count
        let adherence = daysWithData.isEmpty ? 0 : (Double(daysOnTarget) / Double(daysWithData.count)) * 100

        // Best and worst days
        var bestDay: (date: Date, calories: Int)?
        var worstDay: (date: Date, calories: Int)?

        for (index, dayEntries) in weeklyData.enumerated() {
            guard !dayEntries.isEmpty else { continue }
            guard let date = calendar.date(byAdding: .day, value: -index, to: today) else { continue }
            let dayCal = Int(dayEntries.reduce(0.0) { $0 + $1.calories })
            let deviation = abs(dayCal - goals.dailyCalories)

            if bestDay == nil || abs(dayCal - goals.dailyCalories) < abs(bestDay!.calories - goals.dailyCalories) {
                bestDay = (date: date, calories: dayCal)
            }
            if worstDay == nil || deviation > abs(worstDay!.calories - goals.dailyCalories) {
                worstDay = (date: date, calories: dayCal)
            }
        }

        // Macro averages
        let totalProtein = allEntries.reduce(0.0) { $0 + $1.proteinG }
        let totalCarbs = allEntries.reduce(0.0) { $0 + $1.carbsG }
        let totalFat = allEntries.reduce(0.0) { $0 + $1.fatG }
        let dayCount = max(1, Double(daysWithData.count))
        let macroAvg = MacroBreakdown(
            proteinG: totalProtein / dayCount,
            carbsG: totalCarbs / dayCount,
            fatG: totalFat / dayCount
        )

        // Top foods
        let foodCounts = Dictionary(grouping: allEntries, by: { $0.foodName })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        let topFoods = Array(foodCounts.prefix(5).map { (name: $0.key, count: $0.value) })

        // Generate improvement tips
        let tips = generateImprovementTips(
            avgCalories: avgCalories,
            goal: goals.dailyCalories,
            macroAvg: macroAvg,
            goals: goals,
            mealTimingInsights: mealTimingInsights,
            nutrientGaps: nutrientGaps,
            daysTracked: daysWithData.count
        )

        return WeeklyDietReport(
            startDate: startDate,
            endDate: endDate,
            averageDailyCalories: avgCalories,
            calorieGoal: goals.dailyCalories,
            adherencePercent: adherence,
            totalMealsLogged: allEntries.count,
            bestDay: bestDay,
            worstDay: worstDay,
            macroAverages: macroAvg,
            topFoods: topFoods,
            mealTimingInsights: mealTimingInsights,
            nutrientGaps: nutrientGaps,
            streakInfo: (current: currentStreak, best: bestStreak),
            improvementTips: tips
        )
    }

    // MARK: - Improvement Tip Generation

    private func generateImprovementTips(
        avgCalories: Int,
        goal: Int,
        macroAvg: MacroBreakdown,
        goals: DietGoals,
        mealTimingInsights: [MealTimingInsight],
        nutrientGaps: [NutrientGap],
        daysTracked: Int
    ) -> [String] {
        var tips: [String] = []

        // Calorie-based tips
        if goal > 0 {
            let ratio = Double(avgCalories) / Double(goal)
            if ratio < 0.8 {
                tips.append("You're averaging \(Int((1 - ratio) * 100))% below your calorie goal. Try adding a wholesome mid-morning snack like upma or a banana.")
            } else if ratio > 1.15 {
                tips.append("You're averaging \(Int((ratio - 1) * 100))% above your calorie goal. Consider smaller portions of rice or replacing fried snacks with grilled options.")
            }
        }

        // Protein tips
        let proteinGoal = Double(goals.proteinGrams)
        if proteinGoal > 0 && macroAvg.proteinG < proteinGoal * 0.8 {
            tips.append("Boost protein by adding dal, paneer, or sprouted moong to each meal. Curd with lunch is an easy addition.")
        }

        // Fat balance tips
        let fatGoal = Double(goals.fatGrams)
        if fatGoal > 0 && macroAvg.fatG < fatGoal * 0.7 {
            tips.append("Include healthy fats - a handful of almonds, a teaspoon of ghee on roti, or coconut chutney with dosa.")
        }

        // Timing-based tips
        for insight in mealTimingInsights {
            switch insight.type {
            case .lateDinner:
                tips.append("Try to finish dinner by 8 PM. A lighter dinner like khichdi or soup is easier to digest late.")
            case .skippedBreakfast:
                tips.append("Try eating breakfast before 9 AM. Even a quick option like poha, idli, or a glass of milk with banana works.")
            case .largeGapBetweenMeals:
                tips.append("Bridge the gap between lunch and dinner with a healthy snack - roasted makhana, fruit, or a small bowl of sprouts.")
            default:
                break
            }
        }

        // Logging consistency
        if daysTracked < 5 {
            tips.append("Log meals consistently for better insights. Try logging at least 5 days a week.")
        }

        // Fiber gap
        if nutrientGaps.contains(where: { $0.nutrient == "Fiber" }) {
            tips.append("Increase fiber with whole grains (brown rice, jowar roti), raw salads, and fruits like guava and papaya.")
        }

        // Limit to top 4 tips
        return Array(tips.prefix(4))
    }
}
