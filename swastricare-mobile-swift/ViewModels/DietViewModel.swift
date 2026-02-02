//
//  DietViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  State management for diet tracking
//

import Foundation
import Combine

@MainActor
final class DietViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var dietLogs: [DietLogEntry] = []
    @Published private(set) var dietGoals: DietGoals = DietGoals()
    @Published private(set) var nutritionSummary: NutritionSummary = NutritionSummary.empty
    @Published private(set) var macroBreakdown: MacroBreakdown = MacroBreakdown.empty
    @Published private(set) var insights: DietInsights?
    @Published private(set) var foodItemsCache: [FoodItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedDate = Date()
    @Published var showAddFood = false
    @Published var showSettings = false
    @Published var searchQuery = ""
    
    // MARK: - Computed Properties
    
    var todaysLogs: [DietLogEntry] {
        let calendar = Calendar.current
        return dietLogs.filter { entry in
            calendar.isDate(entry.loggedAt, inSameDayAs: selectedDate)
        }.sorted { $0.loggedAt > $1.loggedAt }
    }
    
    var totalCalories: Int {
        Int(nutritionSummary.totalCalories)
    }
    
    var remainingCalories: Int {
        max(0, dietGoals.dailyCalories - totalCalories)
    }
    
    var calorieProgress: Double {
        guard dietGoals.dailyCalories > 0 else { return 0 }
        return min(1.0, Double(totalCalories) / Double(dietGoals.dailyCalories))
    }
    
    var isGoalMet: Bool {
        totalCalories >= dietGoals.dailyCalories
    }
    
    var proteinProgress: Double {
        guard dietGoals.proteinGrams > 0 else { return 0 }
        return min(1.0, nutritionSummary.totalProteinG / Double(dietGoals.proteinGrams))
    }
    
    var carbsProgress: Double {
        guard dietGoals.carbsGrams > 0 else { return 0 }
        return min(1.0, nutritionSummary.totalCarbsG / Double(dietGoals.carbsGrams))
    }
    
    var fatProgress: Double {
        guard dietGoals.fatGrams > 0 else { return 0 }
        return min(1.0, nutritionSummary.totalFatG / Double(dietGoals.fatGrams))
    }
    
    var goalDescription: String {
        "Daily goal: \(dietGoals.dailyCalories) cal"
    }
    
    // MARK: - Dependencies
    
    private let dietService: DietServiceProtocol
    private let localStorage: DietLocalStorage
    
    // MARK: - Init
    
    init(
        dietService: DietServiceProtocol = DietService.shared,
        localStorage: DietLocalStorage = DietLocalStorage.shared
    ) {
        self.dietService = dietService
        self.localStorage = localStorage
    }
    
    // MARK: - Lifecycle
    
    func onAppear() async {
        await loadData()
    }
    
    func loadData() async {
        isLoading = true
        
        // Load from local storage
        dietLogs = localStorage.loadLogs()
        dietGoals = localStorage.loadGoals()
        foodItemsCache = localStorage.loadFoodItemsCache()
        
        // Calculate nutrition for selected date
        calculateNutrition()
        
        // Calculate insights
        calculateInsights()
        
        // Schedule diet reminders (if enabled)
        await NotificationService.shared.scheduleDietReminders()
        
        // Try to sync with cloud in background
        Task {
            await syncWithCloud()
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    /// Log a food item
    func logFood(
        item: FoodItem,
        quantity: Double,
        mealType: MealType,
        notes: String? = nil,
        source: String = "in_app"
    ) async {
        // Calculate nutrition based on quantity
        let multiplier = quantity / item.servingSize
        
        let entry = DietLogEntry(
            foodItemId: item.id,
            mealType: mealType,
            foodName: item.name,
            quantity: quantity,
            servingUnit: item.servingUnit,
            calories: item.calories * multiplier,
            proteinG: item.proteinG * multiplier,
            carbsG: item.carbsG * multiplier,
            fatG: item.fatG * multiplier,
            fiberG: item.fiberG != nil ? item.fiberG! * multiplier : nil,
            loggedAt: Date(),
            notes: notes
        )
        
        // Save locally
        localStorage.addLog(entry)
        dietLogs = localStorage.loadLogs()
        
        // Recalculate
        calculateNutrition()
        calculateInsights()
        
        // Analytics
        AppAnalyticsService.shared.logDietLogged(
            foodName: item.name,
            calories: Int(entry.calories),
            mealType: mealType.rawValue,
            source: source
        )
        
        if isGoalMet {
            AppAnalyticsService.shared.logDietGoalMet(
                dailyGoalCal: dietGoals.dailyCalories,
                totalCal: totalCalories
            )
        }
        
        // Sync to cloud
        Task {
            await syncLogToCloud(entry)
        }
    }
    
    /// Log custom food
    func logCustomFood(
        name: String,
        mealType: MealType,
        quantity: Double,
        servingUnit: ServingUnit,
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        notes: String? = nil
    ) async {
        let entry = DietLogEntry(
            mealType: mealType,
            foodName: name,
            quantity: quantity,
            servingUnit: servingUnit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            loggedAt: Date(),
            notes: notes
        )
        
        // Save locally
        localStorage.addLog(entry)
        dietLogs = localStorage.loadLogs()
        
        // Recalculate
        calculateNutrition()
        calculateInsights()
        
        // Analytics
        AppAnalyticsService.shared.logDietLogged(
            foodName: name,
            calories: Int(calories),
            mealType: mealType.rawValue,
            source: "custom"
        )
        
        // Sync to cloud
        Task {
            await syncLogToCloud(entry)
        }
    }
    
    /// Delete a log entry
    func deleteLog(_ entry: DietLogEntry) async {
        localStorage.deleteLog(id: entry.id)
        dietLogs = localStorage.loadLogs()
        
        calculateNutrition()
        calculateInsights()
        
        // Delete from cloud
        Task {
            do {
                try await SupabaseManager.shared.deleteDietLog(id: entry.id)
            } catch {
                print("🍎 DietVM: Failed to delete from cloud - \(error.localizedDescription)")
            }
        }
    }
    
    /// Update goals
    func updateGoals(_ newGoals: DietGoals) async {
        dietGoals = newGoals
        localStorage.saveGoals(dietGoals)
        
        // Recalculate with new goals
        calculateNutrition()
        
        // Sync to cloud
        Task {
            do {
                try await SupabaseManager.shared.saveDietGoals(dietGoals)
            } catch {
                print("🍎 DietVM: Failed to save goals to cloud - \(error.localizedDescription)")
            }
        }
    }
    
    /// Refresh data
    func refresh() async {
        await loadData()
    }
    
    /// Get logs for specific meal type
    func getMealLogs(for mealType: MealType) -> [DietLogEntry] {
        dietService.getMealLogs(from: todaysLogs, for: mealType)
    }
    
    /// Search foods
    func searchFoods(query: String) -> [FoodItem] {
        dietService.searchFoods(query: query, in: foodItemsCache)
    }
    
    // MARK: - Private Methods
    
    private func calculateNutrition() {
        nutritionSummary = dietService.calculateDailyNutrition(entries: todaysLogs)
        macroBreakdown = dietService.calculateMacroBreakdown(entries: todaysLogs)
    }
    
    private func calculateInsights() {
        let weeklyData = localStorage.getWeeklyLogs()
        insights = dietService.calculateInsights(
            entries: todaysLogs,
            weeklyData: weeklyData,
            dailyGoal: dietGoals.dailyCalories
        )
    }
    
    private func syncWithCloud() async {
        // Sync unsynced logs
        let unsyncedLogs = localStorage.getUnsyncedLogs()
        guard !unsyncedLogs.isEmpty else { return }
        
        do {
            try await SupabaseManager.shared.syncDietLogs(unsyncedLogs)
            localStorage.markLogsAsSynced(ids: unsyncedLogs.map { $0.id })
        } catch {
            print("🍎 DietVM: Failed to sync logs - \(error.localizedDescription)")
        }
        
        // Try to fetch cloud goals
        do {
            if let cloudGoals = try await SupabaseManager.shared.fetchDietGoals() {
                // Use cloud goals if they're newer
                if let cloudUpdated = cloudGoals.updatedAt,
                   let localUpdated = dietGoals.updatedAt,
                   cloudUpdated > localUpdated {
                    dietGoals = cloudGoals
                    localStorage.saveGoals(dietGoals)
                    calculateNutrition()
                }
            }
        } catch {
            print("🍎 DietVM: Failed to fetch cloud goals - \(error.localizedDescription)")
        }
        
        // Fetch food items from cloud
        do {
            let cloudFoodItems = try await SupabaseManager.shared.fetchFoodItems(limit: 100)
            if !cloudFoodItems.isEmpty {
                foodItemsCache = cloudFoodItems
                localStorage.saveFoodItemsCache(cloudFoodItems)
            }
        } catch {
            print("🍎 DietVM: Failed to fetch food items - \(error.localizedDescription)")
        }
    }
    
    private func syncLogToCloud(_ entry: DietLogEntry) async {
        do {
            try await SupabaseManager.shared.syncDietLog(entry)
            localStorage.markLogsAsSynced(ids: [entry.id])
        } catch {
            print("🍎 DietVM: Failed to sync log to cloud - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Analytics Extension

extension AppAnalyticsService {
    func logDietLogged(foodName: String, calories: Int, mealType: String, source: String) {
        log(eventName: "diet_logged", eventType: "action", properties: [
            "food_name": foodName,
            "calories": calories,
            "meal_type": mealType,
            "source": source
        ])
    }
    
    func logDietGoalMet(dailyGoalCal: Int, totalCal: Int) {
        log(eventName: "diet_goal_met", eventType: "action", properties: [
            "daily_goal_cal": dailyGoalCal,
            "total_cal": totalCal
        ])
    }
}
