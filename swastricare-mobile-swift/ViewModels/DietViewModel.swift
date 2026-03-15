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
    @Published var errorMessage: String?
    @Published var selectedDate = Date() {
        didSet {
            guard !Calendar.current.isDate(oldValue, inSameDayAs: selectedDate) else { return }
            dateChanged()
        }
    }
    @Published var showAddFood = false
    @Published var showSettings = false
    @Published var searchQuery = ""
    @Published var favoriteFoodIds: Set<String> = []
    @Published private(set) var weeklyTrend: [DailyCalorieTrend] = []
    @Published private(set) var goalAdherence: GoalAdherence = GoalAdherence(daysTracked: 0, daysOnTarget: 0, adherencePercent: 0, rating: .needsWork)
    @Published var recentlyDeletedEntry: DietLogEntry?
    @Published var showUndoToast = false

    // MARK: - Sync Status (from DietSyncManager)

    @Published private(set) var syncStatus: DietSyncStatus = .synced

    // MARK: - Fast Logging State (from MealSuggestionEngine / MealTemplateStorage)

    @Published private(set) var mealTemplates: [MealTemplate] = []
    @Published private(set) var suggestedFoods: [FoodItem] = []

    // MARK: - Online Food Search State

    @Published private(set) var onlineSearchResults: [FoodItem] = []
    @Published private(set) var isSearchingOnline = false

    // MARK: - Intelligence State (from DietPatternLearner)

    @Published private(set) var weeklyReport: WeeklyDietReport?
    @Published private(set) var coachingTips: [String] = []
    @Published var showWeeklyReport = false

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

    /// Macro goals in grams (protein 4kcal/g, carbs 4kcal/g, fat 9kcal/g)
    var proteinGoalGrams: Double {
        Double(dietGoals.dailyCalories) * Double(dietGoals.proteinPercent) / 100.0 / 4.0
    }
    var carbsGoalGrams: Double {
        Double(dietGoals.dailyCalories) * Double(dietGoals.carbsPercent) / 100.0 / 4.0
    }
    var fatGoalGrams: Double {
        Double(dietGoals.dailyCalories) * Double(dietGoals.fatPercent) / 100.0 / 9.0
    }

    // MARK: - Dependencies

    private let dietService: DietServiceProtocol
    private let localStorage: DietLocalStorage
    private let syncManager: DietSyncManager
    private let suggestionEngine: MealSuggestionEngine
    private let templateStorage: MealTemplateStorage
    private let patternLearner: DietPatternLearnerProtocol
    private var undoTimer: Task<Void, Never>?
    private var undoEntryId: UUID?  // Track which entry the undo timer is for
    private var syncStatusCancellable: AnyCancellable?
    private var onlineSearchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        dietService: DietServiceProtocol = DietService.shared,
        localStorage: DietLocalStorage = DietLocalStorage.shared,
        syncManager: DietSyncManager = DietSyncManager.shared,
        suggestionEngine: MealSuggestionEngine = MealSuggestionEngine.shared,
        templateStorage: MealTemplateStorage = MealTemplateStorage.shared,
        patternLearner: DietPatternLearnerProtocol = DietPatternLearner.shared
    ) {
        self.dietService = dietService
        self.localStorage = localStorage
        self.syncManager = syncManager
        self.suggestionEngine = suggestionEngine
        self.templateStorage = templateStorage
        self.patternLearner = patternLearner
        self.favoriteFoodIds = Set(UserDefaults.standard.stringArray(forKey: "favoriteFoodIds") ?? [])

        // Observe sync status from the sync manager
        syncStatusCancellable = syncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
            }
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

        // Load templates and suggestions
        mealTemplates = templateStorage.loadAll()
        refreshSuggestions()

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

        // Save locally with validation
        do {
            try localStorage.addLog(entry)
        } catch {
            handleStorageError(error, context: "logging food")
            return
        }

        dietLogs = localStorage.loadLogs()

        // Record in suggestion engine for smart suggestions
        suggestionEngine.recordMealLogged(foodItem: item, mealType: mealType)
        refreshSuggestions()

        // Record pattern for learning
        patternLearner.recordMealLogged(mealType: mealType, at: entry.loggedAt, calories: Int(entry.calories))

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

        // Sync to cloud via sync manager
        Task {
            await syncManager.syncEntry(entry)
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

        // Save locally with validation
        do {
            try localStorage.addLog(entry)
        } catch {
            handleStorageError(error, context: "logging custom food")
            return
        }

        dietLogs = localStorage.loadLogs()

        // Record in suggestion engine
        suggestionEngine.recordMealLoggedByName(foodName: name, foodItemId: nil, mealType: mealType)
        refreshSuggestions()

        // Record pattern for learning
        patternLearner.recordMealLogged(mealType: mealType, at: entry.loggedAt, calories: Int(calories))

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

        // Sync to cloud via sync manager
        Task {
            await syncManager.syncEntry(entry)
        }
    }

    /// Delete a log entry with undo support (race-condition safe)
    func deleteLog(_ entry: DietLogEntry) async {
        // If there's an active undo timer for a DIFFERENT entry, finalize it first
        if let activeUndoId = undoEntryId, activeUndoId != entry.id {
            finalizeDelete()
        }

        // Store for undo
        recentlyDeletedEntry = entry
        undoEntryId = entry.id
        showUndoToast = true

        // Cancel any previous undo timer for the same entry
        undoTimer?.cancel()

        // Remove from local storage
        do {
            try localStorage.deleteLog(id: entry.id)
        } catch {
            handleStorageError(error, context: "deleting food log")
            return
        }

        dietLogs = localStorage.loadLogs()

        calculateNutrition()
        calculateInsights()

        // Start undo timer -- permanently delete from cloud after 5 seconds
        let entryToDelete = entry
        let trackedId = entry.id
        undoTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }

            // Only finalize if this is still the active undo entry
            guard self.undoEntryId == trackedId else { return }

            self.showUndoToast = false
            self.recentlyDeletedEntry = nil
            self.undoEntryId = nil

            do {
                try await SupabaseManager.shared.deleteDietLog(id: entryToDelete.id)
            } catch {
                print("🍎 DietVM: Failed to delete from cloud - \(error.localizedDescription)")
            }
        }
    }

    /// Undo the most recent delete
    func undoDelete() {
        guard let entry = recentlyDeletedEntry else { return }

        // Cancel the permanent delete timer
        undoTimer?.cancel()
        undoTimer = nil
        undoEntryId = nil

        // Restore the entry
        do {
            try localStorage.addLog(entry)
        } catch {
            handleStorageError(error, context: "restoring deleted food log")
            return
        }

        dietLogs = localStorage.loadLogs()

        // Clear undo state
        recentlyDeletedEntry = nil
        showUndoToast = false

        // Recalculate
        calculateNutrition()
        calculateInsights()
    }

    /// Copy yesterday's meals to today
    func copyYesterdaysMeals() async {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }

        let yesterdayLogs = localStorage.getLogsForDate(yesterday)
        guard !yesterdayLogs.isEmpty else { return }

        for log in yesterdayLogs {
            let newEntry = DietLogEntry(
                foodItemId: log.foodItemId,
                mealType: log.mealType,
                foodName: log.foodName,
                quantity: log.quantity,
                servingUnit: log.servingUnit,
                calories: log.calories,
                proteinG: log.proteinG,
                carbsG: log.carbsG,
                fatG: log.fatG,
                fiberG: log.fiberG,
                loggedAt: Date(),
                notes: log.notes
            )

            do {
                try localStorage.addLog(newEntry)
            } catch {
                handleStorageError(error, context: "copying yesterday's meals")
                continue
            }

            // Sync each to cloud via sync manager
            Task {
                await syncManager.syncEntry(newEntry)
            }
        }

        dietLogs = localStorage.loadLogs()
        calculateNutrition()
        calculateInsights()

        // Analytics
        AppAnalyticsService.shared.logDietCopiedYesterday(mealCount: yesterdayLogs.count)
    }

    /// Whether yesterday has any meals to copy
    var hasYesterdaysMeals: Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return !localStorage.getLogsForDate(yesterday).isEmpty
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
                errorMessage = "Failed to sync diet goals to cloud"
            }
        }
    }

    /// Refresh data
    func refresh() async {
        await loadData()
    }

    // MARK: - Sync Controls

    /// Manually trigger a retry of all failed/pending syncs
    func retrySync() async {
        errorMessage = nil
        await syncManager.retryFailedSync()
    }

    // MARK: - Online Food Search

    /// Search foods online via Supabase with debounce.
    /// Local results come immediately; online results append after a short delay.
    func searchFoodsOnline(query: String) {
        // Cancel any pending search
        onlineSearchTask?.cancel()
        onlineSearchResults = []

        guard !query.isEmpty, query.count >= 2 else {
            isSearchingOnline = false
            return
        }

        // Only search online if local results are sparse (< 3)
        let localCount = searchFoods(query: query).count
        guard localCount < 3 else {
            isSearchingOnline = false
            return
        }

        isSearchingOnline = true

        onlineSearchTask = Task {
            // Debounce: wait 1 second before firing online search
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            do {
                let results = try await dietService.searchFoodsOnline(query: query)
                guard !Task.isCancelled else { return }

                // Deduplicate: remove items already in local cache
                let localIds = Set(foodItemsCache.map { $0.id })
                let newResults = results.filter { !localIds.contains($0.id) }

                await MainActor.run {
                    onlineSearchResults = newResults
                    isSearchingOnline = false
                }
                print("🍎 DietVM: Online search returned \(newResults.count) new results for '\(query)'")
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isSearchingOnline = false
                }
                print("🍎 DietVM: Online search failed - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Food Snap (AI Photo Analysis)

    enum SnapAnalysisState {
        case idle
        case analyzing
        case result(SnapFoodResult)
        case error(String)
    }

    @Published var snapAnalysisState: SnapAnalysisState = .idle

    func analyzeFoodImage(_ imageData: Data) async {
        snapAnalysisState = .analyzing

        do {
            // Convert image data to base64 for the AI router
            let base64String = imageData.base64EncodedString()

            // Build the food analysis prompt
            let foodAnalysisPrompt = """
            Analyze this food image and estimate the nutritional content.

            Respond ONLY with a JSON object in this exact format (no markdown, no extra text):
            {
              "name": "Food name",
              "calories": 250,
              "protein_g": 10,
              "carbs_g": 30,
              "fat_g": 8,
              "fiber_g": 3,
              "serving_size": 200,
              "serving_unit": "g",
              "category": "grains"
            }

            Rules:
            - serving_unit must be one of: g, ml, piece, cup, tbsp, tsp, oz, bowl, plate
            - category must be one of: fruits, vegetables, grains, protein, dairy, beverages, snacks, sweets, other
            - All numeric values must be numbers, not strings
            - If you see multiple food items, describe the main dish
            - Use realistic nutritional estimates for Indian cuisine when applicable
            """

            // Call the AI router edge function with image data
            let payload: [String: Any] = [
                "message": foodAnalysisPrompt,
                "imageData": base64String,
                "forceModel": "vision",
                "systemContext": "food_analysis"
            ]

            let response = try await SupabaseManager.shared.invokeFunction(
                name: "ai-router",
                payload: payload
            )

            // Parse the AI response
            guard let responseText = response["response"] as? String else {
                print("🍎 DietVM: No response text from AI router")
                snapAnalysisState = .error("Could not analyze the food image. Please try again.")
                return
            }

            // Extract JSON from the response (handle possible markdown wrapping)
            let jsonString = extractJSON(from: responseText)

            guard let jsonData = jsonString.data(using: .utf8) else {
                print("🍎 DietVM: Failed to convert response to data")
                snapAnalysisState = .error("Could not parse the analysis result.")
                return
            }

            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let parsed = parsed,
                  let name = parsed["name"] as? String else {
                print("🍎 DietVM: Failed to parse JSON response")
                snapAnalysisState = .error("Could not understand the analysis result.")
                return
            }

            let calories = (parsed["calories"] as? Double) ?? (parsed["calories"] as? Int).map(Double.init) ?? 0
            let proteinG = (parsed["protein_g"] as? Double) ?? (parsed["protein_g"] as? Int).map(Double.init) ?? 0
            let carbsG = (parsed["carbs_g"] as? Double) ?? (parsed["carbs_g"] as? Int).map(Double.init) ?? 0
            let fatG = (parsed["fat_g"] as? Double) ?? (parsed["fat_g"] as? Int).map(Double.init) ?? 0
            let fiberG = (parsed["fiber_g"] as? Double) ?? (parsed["fiber_g"] as? Int).map(Double.init) ?? 0
            let servingSize = (parsed["serving_size"] as? Double) ?? (parsed["serving_size"] as? Int).map(Double.init) ?? 1.0
            let servingUnitStr = parsed["serving_unit"] as? String ?? "piece"
            let categoryStr = parsed["category"] as? String ?? "other"

            let result = SnapFoodResult(
                name: name,
                calories: calories,
                proteinG: proteinG,
                carbsG: carbsG,
                fatG: fatG,
                fiberG: fiberG,
                servingSize: servingSize,
                servingUnit: ServingUnit(rawValue: servingUnitStr) ?? .piece,
                category: FoodCategory(rawValue: categoryStr) ?? .other
            )

            print("🍎 DietVM: Food analysis complete - \(name) (\(Int(calories)) cal)")
            snapAnalysisState = .result(result)

        } catch {
            print("🍎 DietVM: Food analysis failed - \(error.localizedDescription)")
            snapAnalysisState = .error("Analysis failed: \(error.localizedDescription)")
        }
    }

    /// Extract JSON object from a string that may contain markdown code fences
    private func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fence if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resetSnapState() {
        snapAnalysisState = .idle
    }

    func logFoodFromSnap(result: SnapFoodResult, mealType: MealType, quantity: Double) async {
        await logCustomFood(
            name: result.name,
            mealType: mealType,
            quantity: quantity,
            servingUnit: result.servingUnit,
            calories: result.calories,
            proteinG: result.proteinG,
            carbsG: result.carbsG,
            fatG: result.fatG
        )
        resetSnapState()
    }

    /// Called whenever selectedDate changes so the calorie ring, macro bars,
    /// and insights reflect the newly selected day.
    private func dateChanged() {
        calculateNutrition()
        calculateInsights()
    }

    /// Get logs for specific meal type
    func getMealLogs(for mealType: MealType) -> [DietLogEntry] {
        dietService.getMealLogs(from: todaysLogs, for: mealType)
    }

    /// Search foods
    func searchFoods(query: String) -> [FoodItem] {
        dietService.searchFoods(query: query, in: foodItemsCache)
    }

    /// Recent foods ranked by usage frequency (from suggestion engine), falling
    /// back to recency-based ordering when no frequency data exists.
    var recentFoods: [FoodItem] {
        let frequencyRanks = suggestionEngine.frequencyRankedFoodNames(limit: 30)

        if !frequencyRanks.isEmpty {
            // Build list from frequency-ranked names, resolved against the food cache
            var seen = Set<String>()
            var result: [FoodItem] = []

            let ranked = frequencyRanks.sorted { $0.value > $1.value }
            for (name, _) in ranked {
                guard !seen.contains(name) else { continue }
                seen.insert(name)
                if let item = foodItemsCache.first(where: { $0.name == name }) {
                    result.append(item)
                }
                if result.count >= 15 { break }
            }
            return result
        }

        // Fallback: recency-based
        var seen = Set<String>()
        var result: [FoodItem] = []
        let sortedLogs = dietLogs.sorted { $0.loggedAt > $1.loggedAt }
        for log in sortedLogs {
            guard !seen.contains(log.foodName) else { continue }
            seen.insert(log.foodName)
            if let item = foodItemsCache.first(where: { $0.name == log.foodName }) {
                result.append(item)
            }
            if result.count >= 15 { break }
        }
        return result
    }

    /// Favorite food items resolved from cache
    var favoriteFoods: [FoodItem] {
        foodItemsCache.filter { favoriteFoodIds.contains($0.id.uuidString) }
    }

    /// Toggle favorite status for a food item
    func toggleFavorite(foodId: UUID) {
        let idString = foodId.uuidString
        if favoriteFoodIds.contains(idString) {
            favoriteFoodIds.remove(idString)
        } else {
            favoriteFoodIds.insert(idString)
        }
        UserDefaults.standard.set(Array(favoriteFoodIds), forKey: "favoriteFoodIds")
    }

    /// Check if a food item is favorited
    func isFavorite(foodId: UUID) -> Bool {
        favoriteFoodIds.contains(foodId.uuidString)
    }

    // MARK: - Templates

    /// Save the current meal's entries as a reusable template.
    func saveMealAsTemplate(mealType: MealType, name: String) {
        let entries = getMealLogs(for: mealType)
        guard !entries.isEmpty else { return }

        let items = entries.map { entry in
            TemplateItem(
                foodItemId: entry.foodItemId,
                foodName: entry.foodName,
                quantity: entry.quantity,
                servingUnit: entry.servingUnit,
                calories: Int(entry.calories),
                proteinG: entry.proteinG,
                carbsG: entry.carbsG,
                fatG: entry.fatG
            )
        }

        let template = MealTemplate(
            name: name,
            mealType: mealType,
            items: items
        )

        templateStorage.save(template)
        mealTemplates = templateStorage.loadAll()

        print("🍎 DietVM: Saved template '\(name)' with \(items.count) items")
    }

    /// Log all items in a template at once.
    func logTemplate(_ template: MealTemplate) async {
        for item in template.items {
            let entry = DietLogEntry(
                foodItemId: item.foodItemId,
                mealType: template.mealType,
                foodName: item.foodName,
                quantity: item.quantity,
                servingUnit: item.servingUnit,
                calories: Double(item.calories),
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                loggedAt: Date()
            )

            do {
                try localStorage.addLog(entry)
            } catch {
                handleStorageError(error, context: "logging template item")
                continue
            }

            // Record in suggestion engine
            suggestionEngine.recordMealLoggedByName(
                foodName: item.foodName,
                foodItemId: item.foodItemId,
                mealType: template.mealType
            )

            // Record pattern for learning
            patternLearner.recordMealLogged(mealType: template.mealType, at: entry.loggedAt, calories: item.calories)

            // Sync to cloud via sync manager
            Task {
                await syncManager.syncEntry(entry)
            }
        }

        // Mark template as used
        templateStorage.markUsed(id: template.id)
        mealTemplates = templateStorage.loadAll()

        // Refresh local state
        dietLogs = localStorage.loadLogs()
        calculateNutrition()
        calculateInsights()
        refreshSuggestions()

        // Analytics
        AppAnalyticsService.shared.logDietLogged(
            foodName: "template:\(template.name)",
            calories: template.totalCalories,
            mealType: template.mealType.rawValue,
            source: "template"
        )

        print("🍎 DietVM: Logged template '\(template.name)' (\(template.items.count) items)")
    }

    /// Delete a meal template.
    func deleteTemplate(_ template: MealTemplate) {
        templateStorage.delete(id: template.id)
        mealTemplates = templateStorage.loadAll()
    }

    /// Get templates for a specific meal type.
    func templates(for mealType: MealType) -> [MealTemplate] {
        templateStorage.templates(for: mealType)
    }

    // MARK: - Single Meal Copy

    /// Copy just one meal type from a specific date (default: yesterday).
    func copySingleMeal(_ mealType: MealType, from date: Date? = nil) async {
        let sourceDate = date ?? Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let sourceLogs = localStorage.getLogsForDate(sourceDate)
        let mealLogs = sourceLogs.filter { $0.mealType == mealType }

        guard !mealLogs.isEmpty else { return }

        for log in mealLogs {
            let newEntry = DietLogEntry(
                foodItemId: log.foodItemId,
                mealType: log.mealType,
                foodName: log.foodName,
                quantity: log.quantity,
                servingUnit: log.servingUnit,
                calories: log.calories,
                proteinG: log.proteinG,
                carbsG: log.carbsG,
                fatG: log.fatG,
                fiberG: log.fiberG,
                loggedAt: Date(),
                notes: log.notes
            )

            do {
                try localStorage.addLog(newEntry)
            } catch {
                handleStorageError(error, context: "copying single meal")
                continue
            }

            Task {
                await syncManager.syncEntry(newEntry)
            }
        }

        dietLogs = localStorage.loadLogs()
        calculateNutrition()
        calculateInsights()

        print("🍎 DietVM: Copied \(mealLogs.count) \(mealType.displayName) entries from \(sourceDate)")
    }

    /// Check if yesterday has entries for a specific meal type.
    func hasYesterdaysMeal(for mealType: MealType) -> Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return localStorage.getLogsForDate(yesterday).contains { $0.mealType == mealType }
    }

    // MARK: - Suggestions

    /// Refresh suggestions for the auto-detected current meal type.
    func refreshSuggestions() {
        let currentMeal = MealSuggestionEngine.currentMealType()
        suggestedFoods = suggestionEngine.suggestFoods(for: currentMeal, from: foodItemsCache, limit: 5)
    }

    /// Refresh suggestions for a specific meal type.
    func refreshSuggestions(for mealType: MealType) {
        suggestedFoods = suggestionEngine.suggestFoods(for: mealType, from: foodItemsCache, limit: 5)
    }

    /// Quick-log a suggested food with default serving size (1 serving).
    func quickLogFood(_ item: FoodItem, mealType: MealType? = nil) async {
        let meal = mealType ?? MealSuggestionEngine.currentMealType()
        await logFood(item: item, quantity: item.servingSize, mealType: meal, source: "quick_log")
    }

    // MARK: - Intelligence (Weekly Report & Coaching)

    /// Generate on-demand weekly report
    func generateWeeklyReport() {
        let weeklyData = localStorage.getWeeklyLogs()
        let streak = insights?.currentStreak ?? 0
        let bestStreak = insights?.bestStreak ?? 0
        weeklyReport = dietService.generateWeeklyReport(
            weeklyData: weeklyData,
            goals: dietGoals,
            currentStreak: streak,
            bestStreak: bestStreak,
            patternLearner: patternLearner
        )
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
            dailyGoal: dietGoals.dailyCalories,
            goals: dietGoals,
            patternLearner: patternLearner
        )
        weeklyTrend = dietService.calculateWeeklyTrend(
            weeklyData: weeklyData,
            dailyGoal: dietGoals.dailyCalories
        )
        goalAdherence = dietService.calculateGoalAdherence(
            weeklyData: weeklyData,
            dailyGoal: dietGoals.dailyCalories
        )

        // Update published report and coaching tips from insights
        weeklyReport = insights?.weeklyReport
        coachingTips = insights?.coachingTips ?? []
    }

    private func syncWithCloud() async {
        // Use the sync manager for pending entries
        await syncManager.syncAllPending()

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
            let cloudFoodItems = try await SupabaseManager.shared.fetchFoodItems(limit: 500)
            if !cloudFoodItems.isEmpty {
                foodItemsCache = cloudFoodItems
                localStorage.saveFoodItemsCache(cloudFoodItems)
            }
        } catch {
            print("🍎 DietVM: Failed to fetch food items - \(error.localizedDescription)")
        }
    }

    /// Finalizes a pending undo delete immediately (used when a second delete occurs)
    private func finalizeDelete() {
        undoTimer?.cancel()
        undoTimer = nil

        guard let entry = recentlyDeletedEntry else { return }

        recentlyDeletedEntry = nil
        undoEntryId = nil
        showUndoToast = false

        // Fire-and-forget cloud delete for the finalized entry
        let entryToDelete = entry
        Task {
            do {
                try await SupabaseManager.shared.deleteDietLog(id: entryToDelete.id)
            } catch {
                print("🍎 DietVM: Failed to delete finalized entry from cloud - \(error.localizedDescription)")
            }
        }
    }

    /// Handles storage errors by logging and surfacing user-visible messages.
    private func handleStorageError(_ error: Error, context: String) {
        if let storageError = error as? DietStorageError {
            switch storageError {
            case .validationFailed(let validationErrors):
                let detail = validationErrors.map(\.description).joined(separator: ". ")
                errorMessage = detail
                print("🍎 DietVM: Validation error while \(context) - \(detail)")
            case .encodingFailed, .writeFailed:
                errorMessage = "Failed to save data. Please try again."
                print("🍎 DietVM: Storage error while \(context) - \(storageError)")
            case .corruptedData:
                errorMessage = "Data corruption detected. Some data may have been lost."
                print("🍎 DietVM: Corruption error while \(context) - \(storageError)")
            }
        } else {
            errorMessage = "An unexpected error occurred. Please try again."
            print("🍎 DietVM: Unexpected error while \(context) - \(error.localizedDescription)")
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

    func logDietCopiedYesterday(mealCount: Int) {
        log(eventName: "diet_copied_yesterday", eventType: "action", properties: [
            "meal_count": mealCount
        ])
    }
}
