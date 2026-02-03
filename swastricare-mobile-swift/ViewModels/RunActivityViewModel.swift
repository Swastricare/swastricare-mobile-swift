//
//  RunActivityViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  Steps & Walk/Run Activity Tracking with HealthKit & API Integration
//

import Foundation
import Combine
import HealthKit

@MainActor
final class RunActivityViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var selectedTimeRange: ActivityTimeRange = .twoWeeks
    @Published private(set) var statistics: ActivityStatistics = ActivityStatistics()
    @Published private(set) var activities: [RouteActivity] = []
    @Published private(set) var dailySummaries: [DailyActivitySummary] = []
    @Published private(set) var weeklyComparison: WeeklyComparison?
    @Published private(set) var activityGoal: ActivityGoal = ActivityGoal()
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSyncDate: Date?
    
    /// IDs the user deleted locally in this session (prevents reappearing after reload/merge)
    @Published private(set) var hiddenActivityIds: Set<UUID> = []
    
    /// External IDs (e.g. HealthKit workout UUID strings) the user deleted locally in this session.
    /// This prevents re-appearance across API-vs-HealthKit representations of the same workout.
    @Published private(set) var hiddenExternalIds: Set<String> = []
    
    private static let hiddenActivityIdsKey = "RunActivityViewModel.hiddenActivityIds"
    private static let hiddenExternalIdsKey = "RunActivityViewModel.hiddenExternalIds"
    
    // MARK: - Computed Properties
    
    var totalSteps: Int { statistics.totalSteps }
    var totalDistance: Double { statistics.totalDistance }
    var totalCalories: Int { statistics.totalCalories }
    var totalPoints: Int { statistics.totalPoints }
    var percentageChange: Double { statistics.percentageChange }
    var yesterdayDistance: Double { statistics.yesterdayDistance }
    
    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: statistics.totalSteps)) ?? "\(statistics.totalSteps)"
    }
    
    /// Progress toward daily steps goal (0-1). Uses the best available steps count
    /// so the progress ring stays consistent with the displayed total steps.
    var stepsGoalProgress: Double {
        guard activityGoal.dailyStepsGoal > 0 else { return 0 }
        let steps = max(activityGoal.currentSteps, statistics.totalSteps)
        return min(Double(steps) / Double(activityGoal.dailyStepsGoal), 1.0)
    }
    
    var hasActivities: Bool {
        !activities.isEmpty
    }
    
    var todayActivities: [RouteActivity] {
        let calendar = Calendar.current
        return activities.filter { calendar.isDateInToday($0.startTime) }
    }
    
    // MARK: - Dependencies
    
    private let healthService: HealthKitServiceProtocol
    private let activityService: RunActivityServiceProtocol
    private let userDefaultsKey = "hasRequestedHealthAuthorization"
    private let lastSyncKey = "lastRunActivitySyncDate"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(
        healthService: HealthKitServiceProtocol = HealthKitService.shared,
        activityService: RunActivityServiceProtocol = RunActivityService.shared
    ) {
        self.healthService = healthService
        self.activityService = activityService
        self.isAuthorized = UserDefaults.standard.bool(forKey: userDefaultsKey)
        self.lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        self.hiddenActivityIds = Self.loadHiddenActivityIds()
        self.hiddenExternalIds = Self.loadHiddenExternalIds()
        
        setupBindings()
    }
    
    private static func loadHiddenActivityIds() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: hiddenActivityIdsKey),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
    
    private static func loadHiddenExternalIds() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: hiddenExternalIdsKey),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(strings)
    }
    
    private func persistHiddenIds() {
        let activityStrings = hiddenActivityIds.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(activityStrings) {
            UserDefaults.standard.set(data, forKey: Self.hiddenActivityIdsKey)
        }
        let externalStrings = Array(hiddenExternalIds)
        if let data = try? JSONEncoder().encode(externalStrings) {
            UserDefaults.standard.set(data, forKey: Self.hiddenExternalIdsKey)
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // React to time range changes
        $selectedTimeRange
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main Data Loading
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate date range
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
            
            // Load data in parallel
            async let statsTask = loadStatistics()
            async let activitiesTask = loadActivities(startDate: startDate, endDate: endDate)
            async let comparisonTask = loadWeeklyComparison()
            async let goalsTask = loadGoals()
            
            // Also load from HealthKit if authorized
            if isAuthorized {
                async let healthKitTask = loadFromHealthKit(startDate: startDate, endDate: endDate)
                let (stats, apiActivities, comparison, goals, healthKitActivities) = await (statsTask, activitiesTask, comparisonTask, goalsTask, healthKitTask)
                
                // Merge HealthKit activities with API activities (prioritize API for synced items)
                mergeActivities(apiActivities: apiActivities, healthKitActivities: healthKitActivities)
                
                if let stats = stats {
                    statistics = stats
                }
                weeklyComparison = comparison
                if let goals = goals {
                    activityGoal = goals
                }
            } else {
                // Just load from API/mock
                let (stats, apiActivities, comparison, goals) = await (statsTask, activitiesTask, comparisonTask, goalsTask)
                activities = apiActivities
                if let stats = stats {
                    statistics = stats
                }
                weeklyComparison = comparison
                if let goals = goals {
                    activityGoal = goals
                }
            }
            
            // Don't load mock data - show empty state when there's no real data
            // if statistics.totalSteps == 0 && activities.isEmpty {
            //     await loadMockData()
            // }

            // Keep Run widget in sync with latest activities
            updateRunWidgetSnapshot()
            
        } catch {
            errorMessage = error.localizedDescription
            // Don't fall back to mock data - show empty state on error
            // await loadMockData()
        }
        
        isLoading = false
    }

    private func updateRunWidgetSnapshot() {
        let last = activities.sorted(by: { $0.startTime > $1.startTime }).first

        let lastWidgetActivity: WidgetRunActivity? = last.map { activity in
            WidgetRunActivity(
                name: activity.name,
                type: activity.type.rawValue.lowercased(),
                distance: activity.distance,
                duration: activity.duration,
                calories: activity.calories,
                date: activity.startTime
            )
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekly = activities.filter { $0.startTime >= sevenDaysAgo }
        let weeklyStats = WidgetWeeklyRunStats(
            totalDistance: weekly.reduce(0.0) { $0 + $1.distance },
            totalActivities: weekly.count,
            totalCalories: weekly.reduce(0) { $0 + $1.calories }
        )

        WidgetService.shared.saveRunData(lastActivity: lastWidgetActivity, weeklyStats: weeklyStats)
    }
    
    func refresh() async {
        await loadData()
        
        // Sync with API if authorized
        if isAuthorized {
            await syncToAPI()
        }
    }
    
    func selectTimeRange(_ timeRange: ActivityTimeRange) {
        selectedTimeRange = timeRange
    }
    
    // MARK: - API Data Loading
    
    private func loadStatistics() async -> ActivityStatistics? {
        do {
            let stats = try await activityService.fetchStats(days: selectedTimeRange.days)
            return ActivityStatistics(from: stats)
        } catch {
            print("Failed to load statistics: \(error)")
            return nil
        }
    }
    
    private func loadActivities(startDate: Date, endDate: Date) async -> [RouteActivity] {
        do {
            let records = try await activityService.fetchActivities(
                startDate: startDate,
                endDate: endDate,
                activityType: nil,
                limit: 50
            )
            return records
                .map { RouteActivity(from: $0) }
                .filter { activity in
                    if hiddenActivityIds.contains(activity.id) { return false }
                    if let externalId = activity.externalId, hiddenExternalIds.contains(externalId) { return false }
                    return true
                }
        } catch {
            print("Failed to load activities: \(error)")
            return []
        }
    }
    
    private func loadWeeklyComparison() async -> WeeklyComparison? {
        do {
            let response = try await activityService.fetchWeeklyComparison()
            return WeeklyComparison(from: response.comparison)
        } catch {
            print("Failed to load weekly comparison: \(error)")
            return nil
        }
    }
    
    private func loadGoals() async -> ActivityGoal? {
        do {
            let goalsRecord = try await activityService.fetchGoals()
            let stats = try? await activityService.fetchStats(days: 1)
            return ActivityGoal(from: goalsRecord, currentStats: stats)
        } catch {
            print("Failed to load goals: \(error)")
            return nil
        }
    }
    
    // MARK: - HealthKit Integration
    
    func requestHealthAuthorization() async {
        do {
            try await healthService.requestAuthorization()
            isAuthorized = true
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            
            // Load data from HealthKit
            await loadData()
            
            // Sync to API
            await syncToAPI()
        } catch {
            isAuthorized = false
            UserDefaults.standard.set(false, forKey: userDefaultsKey)
            errorMessage = "Failed to get health authorization: \(error.localizedDescription)"
        }
    }
    
    private func loadFromHealthKit(startDate: Date, endDate: Date) async -> [RouteActivity] {
        guard isAuthorized else { return [] }
        
        // Fetch workouts from HealthKit
        let workouts = await healthService.fetchWalkingRunningWorkouts(startDate: startDate, endDate: endDate)
        
        // Fetch routes and heart rate for each workout
        var activitiesWithRoutes: [RouteActivity] = []
        
        for workout in workouts {
            // Fetch route data
            let route = await healthService.fetchWorkoutRoute(workout: workout.workout)
            
            // Fetch heart rate data
            let heartRateData = await healthService.fetchWorkoutHeartRate(workout: workout.workout)
            
            // Create updated workout with heart rate and route
            var updatedWorkout = workout
            updatedWorkout.route = route
            updatedWorkout.averageHeartRate = heartRateData.avg
            updatedWorkout.maxHeartRate = heartRateData.max
            updatedWorkout.minHeartRate = heartRateData.min
            
            activitiesWithRoutes.append(RouteActivity(from: updatedWorkout))
        }
        
        // Also get today's step count and update statistics
        let todaySteps = await healthService.fetchStepCount(for: Date())
        let todayMetrics = await healthService.fetchHealthMetrics(for: Date())
        
        // Update statistics with HealthKit data if API didn't have data
        if statistics.totalSteps == 0 {
            statistics = ActivityStatistics(
                totalSteps: todaySteps,
                totalDistance: todayMetrics.distance,
                totalCalories: todayMetrics.activeCalories,
                totalPoints: Int(Double(todaySteps) * 0.1),
                averageStepsPerDay: todaySteps,
                averageDistancePerDay: todayMetrics.distance,
                percentageChange: 0,
                yesterdayDistance: await fetchYesterdayDistance()
            )
        }
        
        return activitiesWithRoutes.filter { activity in
            if hiddenActivityIds.contains(activity.id) { return false }
            if let externalId = activity.externalId, hiddenExternalIds.contains(externalId) { return false }
            return true
        }
    }
    
    private func fetchYesterdayDistance() async -> Double {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            return 0
        }
        
        let metrics = await healthService.fetchHealthMetrics(for: yesterday)
        return metrics.distance
    }
    
    // MARK: - Sync to API
    
    func syncToAPI() async {
        guard isAuthorized, !isSyncing else { return }
        
        isSyncing = true
        
        // Get workouts since last sync
        let calendar = Calendar.current
        let startDate = lastSyncDate ?? calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let endDate = Date()
        
        // Fetch from HealthKit
        let workouts = await healthService.fetchWalkingRunningWorkouts(startDate: startDate, endDate: endDate)
        
        // Convert to records
        var records: [RunActivityRecord] = []
        for workout in workouts {
            let route = await healthService.fetchWorkoutRoute(workout: workout.workout)
            let heartRate = await healthService.fetchWorkoutHeartRate(workout: workout.workout)
            
            var updatedWorkout = workout
            updatedWorkout.averageHeartRate = heartRate.avg
            updatedWorkout.maxHeartRate = heartRate.max
            updatedWorkout.minHeartRate = heartRate.min
            
            records.append(updatedWorkout.toRecord(route: route))
        }
        
        // Sync to API
        if !records.isEmpty {
            do {
                let result = try await activityService.syncActivities(records)
                print("Sync result: \(result.synced) synced, \(result.duplicates) duplicates")
                
                // Update last sync date
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
            } catch {
                print("Sync failed: \(error)")
            }
        }
        
        isSyncing = false
    }
    
    // MARK: - Activity Management
    
    private func mergeActivities(apiActivities: [RouteActivity], healthKitActivities: [RouteActivity]) {
        // De-duplicate: if an API record exists for a HealthKit workout, prefer the API one.
        // Use the API record's `externalId` (which stores the HealthKit workout UUID string).
        let apiExternalIds = Set(apiActivities.compactMap { $0.externalId })
        
        let unsyncedHealthKit = healthKitActivities.filter { activity in
            if hiddenActivityIds.contains(activity.id) { return false }
            if let externalId = activity.externalId, hiddenExternalIds.contains(externalId) { return false }
            if let externalId = activity.externalId, apiExternalIds.contains(externalId) { return false }
            return true
        }
        
        // Merge: API activities first (they're synced), then unsynced HealthKit
        activities = (apiActivities + unsyncedHealthKit).filter { activity in
            if hiddenActivityIds.contains(activity.id) { return false }
            if let externalId = activity.externalId, hiddenExternalIds.contains(externalId) { return false }
            return true
        }
        
        // Sort by start time (newest first)
        activities.sort { $0.startTime > $1.startTime }
    }
    
    /// Call after deleting run activities from Apple Health (e.g. from Profile). Adds external IDs to hidden set and persists so they stay hidden after app restart; then refreshes the list.
    func addHiddenExternalIdsAndRefresh(_ externalIds: Set<String>) {
        guard !externalIds.isEmpty else { return }
        hiddenExternalIds.formUnion(externalIds)
        persistHiddenIds()
        Task { await loadData() }
    }
    
    func getActivity(by id: UUID) -> RouteActivity? {
        activities.first { $0.id == id }
    }
    
    func getSummary(for date: Date) -> DailyActivitySummary? {
        let calendar = Calendar.current
        return dailySummaries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    // MARK: - Delete Activity
    
    func deleteActivity(_ activity: RouteActivity) async -> Bool {
        // #region agent log
        let logData: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "A",
            "location": "RunActivityViewModel.swift:390",
            "message": "deleteActivity called",
            "data": [
                "activityId": activity.id.uuidString,
                "apiId": activity.apiId?.uuidString ?? "nil",
                "externalId": activity.externalId ?? "nil",
                "source": activity.source ?? "nil"
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
        
        // Remove from local list immediately and persist so they stay hidden after app restart
        hiddenActivityIds.insert(activity.id)
        if let externalId = activity.externalId {
            hiddenExternalIds.insert(externalId)
        }
        persistHiddenIds()
        let wasInList = activities.contains { $0.id == activity.id }
        activities.removeAll { $0.id == activity.id }
        
        // #region agent log
        let logData2: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "B",
            "location": "RunActivityViewModel.swift:410",
            "message": "Before backend delete check",
            "data": [
                "hasApiId": activity.apiId != nil,
                "wasInList": wasInList,
                "hiddenIdsCount": hiddenActivityIds.count,
                "hiddenExternalIdsCount": hiddenExternalIds.count
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData2),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
        
        // Only attempt backend delete for activities that have a backend id.
        // HealthKit-only activities won't have an API record to delete.
        if let apiId = activity.apiId {
            do {
                // #region agent log
                let logData3: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "pre-fix",
                    "hypothesisId": "C",
                    "location": "RunActivityViewModel.swift:425",
                    "message": "Calling activityService.deleteActivity",
                    "data": ["apiId": apiId.uuidString],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
                   let jsonData = try? JSONSerialization.data(withJSONObject: logData3),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? logFile.seekToEnd()
                    try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    try? logFile.close()
                }
                // #endregion
                
                try await activityService.deleteActivity(id: apiId)
                
                // #region agent log
                let logData4: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "pre-fix",
                    "hypothesisId": "D",
                    "location": "RunActivityViewModel.swift:443",
                    "message": "Successfully deleted from API",
                    "data": ["apiId": apiId.uuidString],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
                   let jsonData = try? JSONSerialization.data(withJSONObject: logData4),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? logFile.seekToEnd()
                    try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    try? logFile.close()
                }
                // #endregion
                
                print("✅ Successfully deleted activity from API: \(apiId)")
            } catch {
                // #region agent log
                let logData5: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "pre-fix",
                    "hypothesisId": "E",
                    "location": "RunActivityViewModel.swift:459",
                    "message": "Delete failed with error",
                    "data": [
                        "apiId": apiId.uuidString,
                        "error": error.localizedDescription,
                        "errorType": String(describing: type(of: error))
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
                   let jsonData = try? JSONSerialization.data(withJSONObject: logData5),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? logFile.seekToEnd()
                    try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    try? logFile.close()
                }
                // #endregion
                
                print("❌ Failed to delete activity from API: \(error.localizedDescription)")
                // Surface the error (helps debug "delete not working")
                errorMessage = "Delete failed: \(error.localizedDescription)"
                return false
            }
        } else {
            // #region agent log
            let logData6: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "pre-fix",
                "hypothesisId": "A",
                "location": "RunActivityViewModel.swift:477",
                "message": "Skipping backend delete - no apiId",
                "data": [
                    "activityId": activity.id.uuidString,
                    "externalId": activity.externalId ?? "nil"
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
               let jsonData = try? JSONSerialization.data(withJSONObject: logData6),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                try? logFile.close()
            }
            // #endregion
        }
        
        // Reload data to update statistics (only if we actually had the activity)
        // NOTE: With `hiddenActivityIds`, the deleted activity won't reappear after reload.
        if wasInList {
            // #region agent log
            let logData7: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "pre-fix",
                "hypothesisId": "C",
                "location": "RunActivityViewModel.swift:496",
                "message": "Reloading data after delete",
                "data": ["wasInList": wasInList],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
               let jsonData = try? JSONSerialization.data(withJSONObject: logData7),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                try? logFile.close()
            }
            // #endregion
            
            await loadData()
            
            // #region agent log
            let logData8: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "pre-fix",
                "hypothesisId": "C",
                "location": "RunActivityViewModel.swift:512",
                "message": "Data reloaded after delete",
                "data": [
                    "activitiesCount": activities.count,
                    "hiddenIdsCount": hiddenActivityIds.count
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
               let jsonData = try? JSONSerialization.data(withJSONObject: logData8),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                try? logFile.close()
            }
            // #endregion
        }
        
        return true
    }
    
    func deleteActivity(at indexSet: IndexSet) async {
        for index in indexSet {
            guard index < activities.count else { continue }
            let activity = activities[index]
            _ = await deleteActivity(activity)
        }
    }
    
    // MARK: - Goal Management
    
    func updateGoals(steps: Int? = nil, distance: Int? = nil, calories: Int? = nil) async {
        do {
            let updatedGoals = ActivityGoalsRecord(
                dailyStepsGoal: steps ?? activityGoal.dailyStepsGoal,
                dailyDistanceMeters: distance ?? Int(activityGoal.dailyDistanceGoal * 1000),
                dailyCaloriesGoal: calories ?? activityGoal.dailyCaloriesGoal
            )
            
            let savedGoals = try await activityService.updateGoals(updatedGoals)
            activityGoal = ActivityGoal(from: savedGoals, currentStats: nil)
            
            // Update with current progress
            activityGoal.currentSteps = statistics.totalSteps
            activityGoal.currentDistance = statistics.totalDistance
            activityGoal.currentCalories = statistics.totalCalories
        } catch {
            errorMessage = "Failed to update goals: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Mock Data (Fallback)
    
    private func loadMockData() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let multiplier = Double(selectedTimeRange.days) / 14.0
        
        statistics = ActivityStatistics(
            totalSteps: Int(8792 * multiplier),
            totalDistance: 7.356 * multiplier,
            totalCalories: Int(2100 * multiplier),
            totalPoints: Int(1234 * multiplier),
            averageStepsPerDay: 8500,
            averageDistancePerDay: 3.2,
            percentageChange: Double.random(in: 10...50),
            yesterdayDistance: 2.8
        )
        
        activities = MockRunActivityData.generateMockActivities()
        dailySummaries = MockRunActivityData.generateDailySummaries(for: selectedTimeRange)
        weeklyComparison = MockRunActivityData.generateMockWeeklyComparison()
        
        activityGoal = ActivityGoal(
            dailyStepsGoal: 10000,
            dailyDistanceGoal: 8.0,
            dailyCaloriesGoal: 500,
            currentSteps: statistics.totalSteps,
            currentDistance: statistics.totalDistance,
            currentCalories: statistics.totalCalories
        )
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    
    func formatDistance(_ distance: Double) -> String {
        String(format: "%.2f km", distance)
    }
}
