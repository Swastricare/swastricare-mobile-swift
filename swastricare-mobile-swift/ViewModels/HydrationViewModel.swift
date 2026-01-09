//
//  HydrationViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  State management for hydration tracking
//

import Foundation
import Combine
import WidgetKit

@MainActor
final class HydrationViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var hydrationEntries: [HydrationEntry] = []
    @Published private(set) var preferences: HydrationPreferences = HydrationPreferences()
    @Published private(set) var dailyGoal: Int = HydrationCalculator.defaultGoal
    @Published private(set) var goalBreakdown: HydrationGoal.GoalBreakdown?
    @Published private(set) var insights: HydrationInsights?
    @Published private(set) var currentTemperature: Double?
    @Published private(set) var exerciseMinutes: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showUrineColorGuide = false
    @Published var showSettings = false
    @Published var showAddEntry = false
    @Published var selectedDate = Date()
    
    // MARK: - Computed Properties
    
    var totalIntake: Int {
        hydrationService.getTotalIntake(entries: todaysEntries)
    }
    
    var effectiveIntake: Int {
        hydrationService.calculateEffectiveIntake(entries: todaysEntries)
    }
    
    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(effectiveIntake) / Double(dailyGoal))
    }
    
    var remainingMl: Int {
        max(0, dailyGoal - effectiveIntake)
    }
    
    var isGoalMet: Bool {
        effectiveIntake >= dailyGoal
    }
    
    var todaysEntries: [HydrationEntry] {
        let calendar = Calendar.current
        return hydrationEntries.filter { entry in
            calendar.isDate(entry.timestamp, inSameDayAs: selectedDate)
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    var caffeineInfo: (count: Int, totalMl: Int) {
        hydrationService.getCaffeineIntake(entries: todaysEntries)
    }
    
    var goalDescription: String {
        guard let breakdown = goalBreakdown else {
            return "Your daily goal: \(dailyGoal) ml"
        }
        
        var parts: [String] = []
        
        if let weight = preferences.weightKg {
            parts.append("\(Int(weight))kg")
        }
        
        parts.append(preferences.activityLevel.displayName.lowercased())
        
        if let temp = currentTemperature, preferences.useWeatherAdjustment && temp > 30 {
            parts.append("\(Int(temp))°C")
        }
        
        if parts.isEmpty {
            return "Your daily goal: \(dailyGoal) ml"
        }
        
        return "Your goal: \(dailyGoal) ml (based on \(parts.joined(separator: ", ")))"
    }
    
    // MARK: - Dependencies
    
    private let hydrationService: HydrationServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let localStorage: HydrationLocalStorage
    private let notificationService: NotificationServiceProtocol
    private let patternLearner: DrinkingPatternLearnerProtocol
    private let widgetService = WidgetService.shared
    
    // MARK: - Init
    
    init(
        hydrationService: HydrationServiceProtocol = HydrationService.shared,
        healthKitService: HealthKitServiceProtocol = HealthKitService.shared,
        weatherService: WeatherServiceProtocol = WeatherService.shared,
        localStorage: HydrationLocalStorage = HydrationLocalStorage.shared,
        notificationService: NotificationServiceProtocol = NotificationService.shared,
        patternLearner: DrinkingPatternLearnerProtocol = DrinkingPatternLearner.shared
    ) {
        self.hydrationService = hydrationService
        self.healthKitService = healthKitService
        self.weatherService = weatherService
        self.localStorage = localStorage
        self.notificationService = notificationService
        self.patternLearner = patternLearner
        
        // Set up bidirectional reference for notifications
        Task { @MainActor in
            if let service = notificationService as? NotificationService {
                service.hydrationViewModel = self
            }
        }
    }
    
    // MARK: - Lifecycle
    
    func onAppear() async {
        await loadData()
    }
    
    func loadData() async {
        isLoading = true
        
        // Load preferences from local storage first
        preferences = localStorage.loadPreferences()
        
        // Load entries from local storage
        hydrationEntries = localStorage.loadEntries()
        
        // Fetch weight from HealthKit if enabled
        if preferences.useHealthKitWeight {
            if let weight = await healthKitService.fetchUserWeight() {
                preferences.weightKg = weight
            }
        }
        
        // Fetch exercise minutes for today
        exerciseMinutes = await healthKitService.fetchExerciseMinutesValue(for: Date())
        
        // Fetch weather if enabled
        if preferences.useWeatherAdjustment {
            currentTemperature = await weatherService.fetchCurrentTemperature()
        }
        
        // Calculate goal
        calculateGoal()
        
        // Calculate insights
        calculateInsights()
        
        // Schedule notifications
        await scheduleNextNotification()
        
        // Update widget data
        updateWidgetData()
        
        // Process any pending widget actions
        await processPendingWidgetActions()
        
        // Try to sync with cloud in background
        Task {
            await syncWithCloud()
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    /// Add a hydration entry
    func addWaterIntake(amount: Int, drinkType: DrinkType = .water, notes: String? = nil) async {
        let entry = HydrationEntry(
            timestamp: Date(),
            amountMl: amount,
            drinkType: drinkType,
            notes: notes
        )
        
        // Save locally immediately
        localStorage.addEntry(entry)
        hydrationEntries = localStorage.loadEntries()
        
        // Record to pattern learner for adaptive scheduling
        patternLearner.recordDrinkingEntry(at: entry.timestamp, amountMl: amount)
        
        // Recalculate insights
        calculateInsights()
        
        // Update widget data
        updateWidgetData()
        
        // Sync to HealthKit if enabled
        if preferences.syncToHealthKit {
            do {
                try await healthKitService.writeWaterIntake(amountMl: Double(amount), date: entry.timestamp)
            } catch {
                print("💧 HydrationVM: Failed to sync to HealthKit - \(error.localizedDescription)")
            }
        }
        
        // Sync to cloud
        Task {
            do {
                let _ = try await SupabaseManager.shared.syncHydrationEntry(entry)
                localStorage.markEntriesAsSynced(ids: [entry.id])
            } catch {
                print("💧 HydrationVM: Failed to sync to cloud - \(error.localizedDescription)")
            }
        }
        
        // Schedule next notification based on updated progress with context
        await scheduleNextNotification()
    }
    
    /// Schedule next notification based on current progress with context awareness
    func scheduleNextNotification() async {
        let streak = insights?.currentStreak ?? 0
        
        // Build context for smart scheduling
        let context = HydrationReminderContext(
            temperature: currentTemperature,
            exerciseMinutes: exerciseMinutes,
            patternLearner: patternLearner
        )
        
        await notificationService.scheduleSmartReminder(
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            streak: streak,
            context: context
        )
    }
    
    /// Delete a hydration entry
    func deleteEntry(_ entry: HydrationEntry) async {
        localStorage.deleteEntry(id: entry.id)
        hydrationEntries = localStorage.loadEntries()
        calculateInsights()
        
        // Update widget data
        updateWidgetData()
        
        // Delete from cloud
        Task {
            do {
                try await SupabaseManager.shared.deleteHydrationEntry(id: entry.id)
            } catch {
                print("💧 HydrationVM: Failed to delete from cloud - \(error.localizedDescription)")
            }
        }
    }
    
    /// Update preferences
    func updatePreferences(_ newPreferences: HydrationPreferences) async {
        preferences = newPreferences
        localStorage.savePreferences(preferences)
        
        // Recalculate goal with new preferences
        calculateGoal()
        
        // Update widget data (goal may have changed)
        updateWidgetData()
        
        // Sync to cloud
        Task {
            do {
                try await SupabaseManager.shared.saveHydrationPreferences(preferences)
            } catch {
                print("💧 HydrationVM: Failed to save preferences to cloud - \(error.localizedDescription)")
            }
        }
    }
    
    /// Refresh data
    func refresh() async {
        await loadData()
    }
    
    /// Get urine color advice
    func getUrineAdvice(for color: UrineColor) -> (status: HydrationStatus, recommendation: String) {
        hydrationService.getUrineColorAdvice(for: color)
    }
    
    // MARK: - Private Methods
    
    private func calculateGoal() {
        let breakdown = hydrationService.calculateDailyGoal(
            preferences: preferences,
            temperature: currentTemperature,
            exerciseMinutes: exerciseMinutes
        )
        
        goalBreakdown = breakdown
        dailyGoal = breakdown.baseAmount +
                    breakdown.activityAdjustment +
                    breakdown.weatherAdjustment +
                    breakdown.pregnancyAddition +
                    breakdown.breastfeedingAddition +
                    breakdown.exerciseAddition
    }
    
    private func calculateInsights() {
        let weeklyData = localStorage.getWeeklyEntries()
        insights = hydrationService.calculateInsights(
            entries: todaysEntries,
            weeklyData: weeklyData,
            dailyGoal: dailyGoal
        )
    }
    
    private func syncWithCloud() async {
        // Sync unsynced entries
        let unsyncedEntries = localStorage.getUnsyncedEntries()
        guard !unsyncedEntries.isEmpty else { return }
        
        do {
            try await SupabaseManager.shared.syncHydrationEntries(unsyncedEntries)
            localStorage.markEntriesAsSynced(ids: unsyncedEntries.map { $0.id })
        } catch {
            print("💧 HydrationVM: Failed to sync entries - \(error.localizedDescription)")
        }
        
        // Try to fetch cloud preferences
        do {
            if let cloudPrefs = try await SupabaseManager.shared.fetchHydrationPreferences() {
                // Use cloud prefs if they're newer
                if let cloudUpdated = cloudPrefs.updatedAt,
                   let localUpdated = preferences.updatedAt,
                   cloudUpdated > localUpdated {
                    preferences = cloudPrefs
                    localStorage.savePreferences(preferences)
                    calculateGoal()
                    updateWidgetData()
                }
            }
        } catch {
            print("💧 HydrationVM: Failed to fetch cloud preferences - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Widget Integration
    
    /// Update widget with current hydration data
    private func updateWidgetData() {
        let lastLogTime = todaysEntries.first?.timestamp
        widgetService.saveHydrationData(
            currentIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            lastLoggedTime: lastLogTime
        )
    }
    
    /// Process any pending water logs from widget quick actions
    private func processPendingWidgetActions() async {
        await widgetService.processPendingActions(
            hydrationHandler: { [weak self] amount in
                await self?.addWaterIntake(amount: amount, drinkType: .water, notes: "Added from widget")
            },
            medicationHandler: nil
        )
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
}
