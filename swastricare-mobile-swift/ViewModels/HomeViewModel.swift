//
//  HomeViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var healthMetrics = HealthMetrics()
    @Published private(set) var weeklySteps: [DailyMetric] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var hasRequestedAuth = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSyncTime: Date?
    @Published var isSyncing = false
    @Published private(set) var serverNudges: [ServerNudge] = []
    
    // MARK: - Computed Properties
    
    var stepCount: Int { healthMetrics.steps }
    var heartRate: Int { healthMetrics.heartRate }
    var activeCalories: Int { healthMetrics.activeCalories }
    var exerciseMinutes: Int { healthMetrics.exerciseMinutes }
    var standHours: Int { healthMetrics.standHours }
    var sleepHours: String { healthMetrics.sleep }
    var distance: Double { healthMetrics.distance }
    var bloodPressure: String { healthMetrics.bloodPressure }
    var weight: String { healthMetrics.weight }
    
    var stepProgress: Double {
        min(Double(stepCount) / 10000.0, 1.0)
    }
    
    var calorieProgress: Double {
        min(Double(activeCalories) / 500.0, 1.0)
    }
    
    var exerciseProgress: Double {
        min(Double(exerciseMinutes) / 30.0, 1.0)
    }
    
    var maxWeeklySteps: Int {
        weeklySteps.map { $0.steps }.max() ?? 1
    }
    
    // MARK: - Dependencies
    
    private let healthService: HealthKitServiceProtocol
    private let nudgeService: NudgeServiceProtocol
    private let userDefaultsKey = "hasRequestedHealthAuthorization"

    // MARK: - Init

    init(healthService: HealthKitServiceProtocol = HealthKitService.shared, nudgeService: NudgeServiceProtocol = NudgeService.shared) {
        self.healthService = healthService
        self.nudgeService = nudgeService
        self.hasRequestedAuth = UserDefaults.standard.bool(forKey: userDefaultsKey)
        self.isAuthorized = hasRequestedAuth // For read permissions, assume authorized if requested
    }
    
    // MARK: - Actions
    
    func requestAuthorization() async {
        guard healthService.isHealthDataAvailable else {
            errorMessage = "Health data is not available on this device"
            return
        }
        
        do {
            try await healthService.requestAuthorization()
            hasRequestedAuth = true
            isAuthorized = true
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            
            // Fetch data after authorization
            await loadTodaysData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadTodaysData() async {
        guard isAuthorized else {
            print("🏠 HomeVM: Not authorized, skipping fetch")
            return
        }
        
        isLoading = true
        print("🏠 HomeVM: Loading today's data...")
        
        let today = Date()
        var metrics = await healthService.fetchHealthMetrics(for: today)

        // Fallback: if Apple Health returns no HR data (0), show last locally measured value.
        if metrics.heartRate == 0, let fallbackBpm = HeartRateLocalStorage.shared.loadLastMeasuredBpmIfRecent() {
            metrics = HealthMetrics(
                steps: metrics.steps,
                heartRate: fallbackBpm,
                sleep: metrics.sleep,
                activeCalories: metrics.activeCalories,
                exerciseMinutes: metrics.exerciseMinutes,
                standHours: metrics.standHours,
                distance: metrics.distance,
                bloodPressure: metrics.bloodPressure,
                weight: metrics.weight,
                timestamp: metrics.timestamp
            )
        }

        healthMetrics = metrics
        weeklySteps = await healthService.fetchWeeklySteps()

        // Keep Steps widget in sync with latest HealthKit totals
        WidgetService.shared.saveStepsData(
            currentSteps: metrics.steps,
            dailyGoal: 10000,
            distanceKm: metrics.distance,
            calories: metrics.activeCalories
        )
        
        lastSyncTime = Date()
        isLoading = false

        // Update Health Dynamic Island if active
        if HealthLiveActivityManager.shared.isActive {
            await HealthLiveActivityManager.shared.update(
                steps: metrics.steps,
                heartRate: metrics.heartRate,
                calories: metrics.activeCalories,
                hydrationMl: 0, // Hydration is updated separately
                hydrationGoalMl: 2500,
                stepGoal: 10000
            )
        }

        print("🏠 HomeVM: Data loaded - Steps: \(healthMetrics.steps), HR: \(healthMetrics.heartRate)")

        // Load server-side nudges
        await loadNudges()
    }
    
    func refresh() async {
        await loadTodaysData()
    }
    
    func syncToCloud() async {
        isSyncing = true
        
        // First refresh local data
        await loadTodaysData()
        
        // Then sync to Supabase
        do {
            let _ = try await SupabaseManager.shared.syncHealthData(
                steps: stepCount,
                heartRate: heartRate,
                sleepDuration: sleepHours,
                activeCalories: activeCalories,
                exerciseMinutes: exerciseMinutes,
                standHours: standHours,
                distance: distance
            )
            lastSyncTime = Date()
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    // MARK: - Nudges

    func loadNudges() async {
        do {
            serverNudges = try await nudgeService.fetchActiveNudges()
        } catch {
            print("🏠 HomeVM: Failed to load nudges: \(error.localizedDescription)")
        }
    }

    func dismissNudge(_ nudge: ServerNudge) async {
        serverNudges.removeAll { $0.id == nudge.id }
        try? await nudgeService.dismissNudge(id: nudge.id)
    }

    func actOnNudge(_ nudge: ServerNudge) async {
        try? await nudgeService.markActedOn(id: nudge.id)
    }

    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    func formatSyncTime() -> String {
        guard let time = lastSyncTime else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: time, relativeTo: Date())
    }
}

