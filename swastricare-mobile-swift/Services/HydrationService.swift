//
//  HydrationService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Business logic for hydration calculations and tracking
//

import Foundation

// MARK: - Hydration Service Protocol

protocol HydrationServiceProtocol {
    func calculateDailyGoal(
        preferences: HydrationPreferences,
        temperature: Double?,
        exerciseMinutes: Int
    ) -> HydrationGoal.GoalBreakdown
    
    func calculateEffectiveIntake(entries: [HydrationEntry]) -> Int
    func getTotalIntake(entries: [HydrationEntry]) -> Int
    func getCaffeineIntake(entries: [HydrationEntry]) -> (count: Int, totalMl: Int)
    func getUrineColorAdvice(for color: UrineColor) -> (status: HydrationStatus, recommendation: String)
    func calculateInsights(
        entries: [HydrationEntry],
        weeklyData: [[HydrationEntry]],
        dailyGoal: Int
    ) -> HydrationInsights
}

// MARK: - Hydration Service Implementation

final class HydrationService: HydrationServiceProtocol {
    
    static let shared = HydrationService()
    
    private init() {}
    
    // MARK: - Goal Calculation
    
    /// Calculates the daily hydration goal based on preferences and conditions
    func calculateDailyGoal(
        preferences: HydrationPreferences,
        temperature: Double?,
        exerciseMinutes: Int
    ) -> HydrationGoal.GoalBreakdown {
        
        // If user has set a custom goal, use that
        if let customGoal = preferences.customGoalMl, customGoal > 0 {
            return HydrationGoal.GoalBreakdown(
                baseAmount: customGoal,
                activityAdjustment: 0,
                weatherAdjustment: 0,
                pregnancyAddition: 0,
                breastfeedingAddition: 0,
                exerciseAddition: 0
            )
        }
        
        // Use the calculator from HydrationModels
        let (_, breakdown) = HydrationCalculator.calculateDailyGoal(
            weightKg: preferences.weightKg,
            activityLevel: preferences.activityLevel,
            temperature: preferences.useWeatherAdjustment ? temperature : nil,
            isPregnant: preferences.isPregnant,
            isBreastfeeding: preferences.isBreastfeeding,
            exerciseMinutes: exerciseMinutes,
            useWeatherAdjustment: preferences.useWeatherAdjustment
        )
        
        return breakdown
    }
    
    /// Calculates the total goal amount from a breakdown
    func calculateTotalGoal(from breakdown: HydrationGoal.GoalBreakdown) -> Int {
        breakdown.baseAmount +
        breakdown.activityAdjustment +
        breakdown.weatherAdjustment +
        breakdown.pregnancyAddition +
        breakdown.breastfeedingAddition +
        breakdown.exerciseAddition
    }
    
    // MARK: - Intake Calculations
    
    /// Calculates effective hydration considering drink type multipliers
    func calculateEffectiveIntake(entries: [HydrationEntry]) -> Int {
        entries.reduce(0) { $0 + $1.effectiveHydration }
    }
    
    /// Gets total raw intake without multipliers
    func getTotalIntake(entries: [HydrationEntry]) -> Int {
        entries.reduce(0) { $0 + $1.amountMl }
    }
    
    /// Gets caffeine drink statistics
    func getCaffeineIntake(entries: [HydrationEntry]) -> (count: Int, totalMl: Int) {
        let caffeineEntries = entries.filter { $0.drinkType.containsCaffeine }
        let count = caffeineEntries.count
        let total = caffeineEntries.reduce(0) { $0 + $1.amountMl }
        return (count, total)
    }
    
    // MARK: - Urine Color Guide
    
    /// Returns hydration status and recommendation for a urine color
    func getUrineColorAdvice(for color: UrineColor) -> (status: HydrationStatus, recommendation: String) {
        let status = color.status
        return (status, status.recommendation)
    }
    
    // MARK: - Insights
    
    /// Calculates hydration insights from historical data
    func calculateInsights(
        entries: [HydrationEntry],
        weeklyData: [[HydrationEntry]],
        dailyGoal: Int
    ) -> HydrationInsights {
        
        // Calculate current streak
        let streak = calculateStreak(weeklyData: weeklyData, dailyGoal: dailyGoal)
        
        // Calculate 7-day average
        let weeklyTotals = weeklyData.map { getTotalIntake(entries: $0) }
        let average = weeklyTotals.isEmpty ? 0 : weeklyTotals.reduce(0, +) / max(1, weeklyTotals.count)
        
        // Find best day this week
        var bestDay: (date: Date, amount: Int)?
        let calendar = Calendar.current
        for (index, dayEntries) in weeklyData.enumerated() {
            let total = getTotalIntake(entries: dayEntries)
            if let current = bestDay {
                if total > current.amount {
                    let date = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
                    bestDay = (date, total)
                }
            } else if total > 0 {
                let date = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
                bestDay = (date, total)
            }
        }
        
        // Caffeine tracking
        let (caffeineCount, _) = getCaffeineIntake(entries: entries)
        var caffeineWarning: String?
        if caffeineCount >= 3 {
            caffeineWarning = "You've had \(caffeineCount) caffeinated drinks today. Consider drinking extra water."
        }
        
        return HydrationInsights(
            currentStreak: streak,
            averageDailyIntake: average,
            bestDayThisWeek: bestDay,
            caffeineCount: caffeineCount,
            caffeineWarning: caffeineWarning
        )
    }
    
    // MARK: - Private Helpers
    
    private func calculateStreak(weeklyData: [[HydrationEntry]], dailyGoal: Int) -> Int {
        var streak = 0
        
        // Start from yesterday (index 1) going backwards
        for dayEntries in weeklyData.dropFirst() {
            let total = getTotalIntake(entries: dayEntries)
            if total >= dailyGoal {
                streak += 1
            } else {
                break
            }
        }
        
        // Check if today also meets goal
        if let todayEntries = weeklyData.first {
            let todayTotal = getTotalIntake(entries: todayEntries)
            if todayTotal >= dailyGoal {
                streak += 1
            }
        }
        
        return streak
    }
}

// MARK: - Local Storage Manager

final class HydrationLocalStorage {
    
    static let shared = HydrationLocalStorage()
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "hydration_entries"
    private let preferencesKey = "hydration_preferences"
    
    private init() {}
    
    // MARK: - Entries
    
    func saveEntries(_ entries: [HydrationEntry]) {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: entriesKey)
        }
    }
    
    func loadEntries() -> [HydrationEntry] {
        guard let data = userDefaults.data(forKey: entriesKey),
              let entries = try? JSONDecoder().decode([HydrationEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    func addEntry(_ entry: HydrationEntry) {
        var entries = loadEntries()
        entries.append(entry)
        saveEntries(entries)
    }
    
    func deleteEntry(id: UUID) {
        var entries = loadEntries()
        entries.removeAll { $0.id == id }
        saveEntries(entries)
    }
    
    func getEntriesForDate(_ date: Date) -> [HydrationEntry] {
        let calendar = Calendar.current
        return loadEntries().filter { entry in
            calendar.isDate(entry.timestamp, inSameDayAs: date)
        }
    }
    
    func getWeeklyEntries() -> [[HydrationEntry]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weeklyData: [[HydrationEntry]] = []
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let entries = getEntriesForDate(date)
                weeklyData.append(entries)
            }
        }
        
        return weeklyData
    }
    
    // MARK: - Preferences
    
    func savePreferences(_ preferences: HydrationPreferences) {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: preferencesKey)
        }
    }
    
    func loadPreferences() -> HydrationPreferences {
        guard let data = userDefaults.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(HydrationPreferences.self, from: data) else {
            return HydrationPreferences()
        }
        return preferences
    }
    
    // MARK: - Sync Status
    
    func markEntriesAsSynced(ids: [UUID]) {
        var entries = loadEntries()
        for i in entries.indices {
            if ids.contains(entries[i].id) {
                entries[i].synced = true
            }
        }
        saveEntries(entries)
    }
    
    func getUnsyncedEntries() -> [HydrationEntry] {
        loadEntries().filter { !$0.synced }
    }
}
