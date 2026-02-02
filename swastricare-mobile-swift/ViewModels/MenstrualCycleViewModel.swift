//
//  MenstrualCycleViewModel.swift
//  swastricare-mobile-swift
//
//  ViewModel for menstrual cycle tracking feature.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class MenstrualCycleViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var cycles: [MenstrualCycle] = []
    @Published private(set) var dailyLogs: [MenstrualDailyLog] = []
    @Published private(set) var settings: MenstrualSettings = MenstrualSettings()
    @Published private(set) var prediction: CyclePrediction?
    @Published private(set) var statistics: CycleStatistics?
    @Published private(set) var currentPhase: CyclePhase = .unknown
    @Published private(set) var dayOfCycle: Int = 0
    @Published private(set) var calendarData: [CalendarDayData] = []
    @Published private(set) var insights: CycleInsights?
    
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published var errorMessage: String?
    
    // UI State
    @Published var selectedDate = Date()
    @Published var selectedMonth = Date()
    @Published var showAddPeriodSheet = false
    @Published var showDailyLogSheet = false
    @Published var showSettingsSheet = false
    @Published var showStatsSheet = false
    @Published var selectedLog: MenstrualDailyLog?
    
    // MARK: - Computed Properties
    
    var activeCycle: MenstrualCycle? {
        cycles.first { $0.isOngoing }
    }
    
    var isOnPeriod: Bool {
        activeCycle != nil || todayData?.isPeriodDay == true
    }
    
    var todayData: CalendarDayData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendarData.first { calendar.startOfDay(for: $0.date) == today }
    }
    
    var todayLog: MenstrualDailyLog? {
        service.loadDailyLog(for: Date())
    }
    
    var daysUntilPeriod: Int {
        prediction?.daysUntilPeriod ?? 0
    }
    
    var daysUntilOvulation: Int {
        prediction?.daysUntilOvulation ?? 0
    }
    
    var isFertileToday: Bool {
        prediction?.isFertileToday ?? false
    }
    
    var cycleProgress: Double {
        guard let stats = statistics else { return 0 }
        let avgLength = Int(stats.averageCycleLength)
        guard avgLength > 0, dayOfCycle > 0 else { return 0 }
        return min(1.0, Double(dayOfCycle) / Double(avgLength))
    }
    
    var periodStatusText: String {
        if isOnPeriod {
            return "Day \(dayOfCycle) of your period"
        } else if let prediction = prediction {
            let days = prediction.daysUntilPeriod
            if days <= 0 {
                return "Period expected today"
            } else if days == 1 {
                return "Period expected tomorrow"
            } else {
                return "Period in \(days) days"
            }
        } else {
            return "Log your period to get predictions"
        }
    }
    
    var phaseDescription: String {
        currentPhase.description
    }
    
    var tips: [String] {
        CycleInsights.getTips(for: currentPhase)
    }
    
    // MARK: - Dependencies
    
    private let service: MenstrualCycleServiceProtocol
    private let supabaseManager = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(service: MenstrualCycleServiceProtocol = MenstrualCycleService.shared) {
        self.service = service
        
        // React to month changes
        $selectedMonth
            .dropFirst()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] month in
                Task { @MainActor in
                    self?.updateCalendarData(for: month)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle
    
    func onAppear() async {
        await loadData()
    }
    
    func loadData() async {
        isLoading = true
        
        // Load from local storage
        cycles = service.loadCycles()
        settings = service.loadSettings()
        
        // Load daily logs for current month
        dailyLogs = service.loadDailyLogs(for: selectedMonth)
        
        // Calculate predictions and statistics
        prediction = service.calculatePrediction(from: cycles, settings: settings)
        statistics = service.calculateStatistics(from: cycles, logs: loadAllLogs())
        
        // Get current phase
        let (phase, day) = service.getCurrentPhase(from: cycles, settings: settings)
        currentPhase = phase
        dayOfCycle = day
        
        // Update calendar data
        updateCalendarData(for: selectedMonth)
        
        // Create insights
        updateInsights()
        
        // Schedule reminders if enabled
        if settings.reminderEnabled, let prediction = prediction {
            // Use centralized scheduler (includes AI-generated check-ins + event reminders)
            await NotificationService.shared.scheduleMenstrualCycleNotifications()
        }
        
        isLoading = false
        
        // Sync with cloud in background
        Task {
            await syncWithCloud()
        }
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Period Actions
    
    /// Start a new period
    func startPeriod(date: Date = Date(), flowIntensity: FlowIntensity? = nil, notes: String? = nil) async {
        do {
            // End any ongoing period first
            if let activeCycle = activeCycle {
                var endedCycle = activeCycle
                let calendar = Calendar.current
                endedCycle.endDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
                try await service.updateCycle(endedCycle)
            }
            
            // Create new cycle
            let newCycle = MenstrualCycle(
                startDate: date,
                flowIntensity: flowIntensity,
                isPredicted: false,
                notes: notes
            )
            
            try await service.saveCycle(newCycle)
            
            // Also create a daily log for this day
            var log = MenstrualDailyLog(logDate: date)
            log.flowLevel = flowIntensityToFlowLevel(flowIntensity)
            try await service.saveDailyLog(log)
            
            await loadData()
            
            // Sync to cloud
            Task {
                await syncCycleToCloud(newCycle)
            }
            
            print("🩸 MenstrualVM: Started new period on \(date)")
        } catch {
            errorMessage = "Failed to start period: \(error.localizedDescription)"
        }
    }
    
    /// End the current period
    func endPeriod(date: Date = Date()) async {
        guard var activeCycle = activeCycle else {
            errorMessage = "No active period to end"
            return
        }
        
        do {
            activeCycle.endDate = date
            activeCycle.periodLength = activeCycle.calculatedPeriodLength
            
            try await service.updateCycle(activeCycle)
            await loadData()
            
            // Sync to cloud
            Task {
                await syncCycleToCloud(activeCycle)
            }
            
            print("🩸 MenstrualVM: Ended period on \(date)")
        } catch {
            errorMessage = "Failed to end period: \(error.localizedDescription)"
        }
    }
    
    /// Log period for a specific date (from calendar tap)
    func logPeriodDay(for date: Date, flowLevel: FlowLevel) async {
        do {
            var log = service.loadDailyLog(for: date) ?? MenstrualDailyLog(logDate: date)
            log.flowLevel = flowLevel
            
            try await service.saveDailyLog(log)
            
            // Reload to reflect changes
            await loadData()
            
            // Sync to cloud
            Task {
                _ = try? await supabaseManager.syncMenstrualDailyLog(log)
            }
            
            print("🩸 MenstrualVM: Logged period day \(date)")
        } catch {
            errorMessage = "Failed to log period: \(error.localizedDescription)"
        }
    }
    
    /// Delete a cycle
    func deleteCycle(_ cycle: MenstrualCycle) async {
        do {
            try await service.deleteCycle(id: cycle.id)
            await loadData()
            
            // Delete from cloud
            Task {
                try? await supabaseManager.deleteMenstrualCycle(id: cycle.id)
            }
            
            print("🩸 MenstrualVM: Deleted cycle")
        } catch {
            errorMessage = "Failed to delete cycle: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Daily Log Actions
    
    /// Save a daily log
    func saveDailyLog(_ log: MenstrualDailyLog) async {
        do {
            try await service.saveDailyLog(log)
            await loadData()
            
            // Sync to cloud
            Task {
                _ = try? await supabaseManager.syncMenstrualDailyLog(log)
            }
            
            print("🩸 MenstrualVM: Saved daily log for \(log.logDate)")
        } catch {
            errorMessage = "Failed to save log: \(error.localizedDescription)"
        }
    }
    
    /// Get or create daily log for a date
    func getOrCreateLog(for date: Date) -> MenstrualDailyLog {
        service.loadDailyLog(for: date) ?? MenstrualDailyLog(logDate: date)
    }
    
    /// Delete a daily log
    func deleteDailyLog(_ log: MenstrualDailyLog) async {
        do {
            try await service.deleteDailyLog(id: log.id)
            await loadData()
            
            // Delete from cloud
            Task {
                try? await supabaseManager.deleteMenstrualDailyLog(id: log.id)
            }
            
            print("🩸 MenstrualVM: Deleted daily log")
        } catch {
            errorMessage = "Failed to delete log: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Settings Actions
    
    /// Save settings
    func saveSettings(_ newSettings: MenstrualSettings) async {
        do {
            try await service.saveSettings(newSettings)
            settings = newSettings
            
            // Recalculate predictions with new settings
            prediction = service.calculatePrediction(from: cycles, settings: settings)
            let (phase, day) = service.getCurrentPhase(from: cycles, settings: settings)
            currentPhase = phase
            dayOfCycle = day
            
            updateCalendarData(for: selectedMonth)
            updateInsights()
            
            // Schedule new reminders
            if settings.reminderEnabled, let prediction = prediction {
                await scheduleReminders(for: prediction)
            }
            
            // Sync to cloud
            Task {
                _ = try? await supabaseManager.saveMenstrualSettings(newSettings)
            }
            
            print("🩸 MenstrualVM: Saved settings")
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Calendar Navigation
    
    func goToPreviousMonth() {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = newMonth
    }
    
    func goToNextMonth() {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        selectedMonth = newMonth
    }
    
    func goToToday() {
        selectedMonth = Date()
        selectedDate = Date()
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
        selectedLog = service.loadDailyLog(for: date)
    }
    
    // MARK: - Cloud Sync
    
    func syncWithCloud() async {
        isSyncing = true
        
        do {
            // Sync unsynced cycles
            let unsyncedCycles = service.getUnsyncedCycles()
            if !unsyncedCycles.isEmpty {
                try await supabaseManager.syncMenstrualCycles(unsyncedCycles)
                service.markCyclesAsSynced(ids: unsyncedCycles.map { $0.id })
            }
            
            // Fetch from cloud
            let cloudCycles = try await supabaseManager.fetchMenstrualCycles()
            
            // Merge with local (prefer local for recent changes)
            await mergeCycles(cloudCycles)
            
            // Fetch cloud settings
            if let cloudSettings = try await supabaseManager.fetchMenstrualSettings() {
                // Use cloud settings if they're newer
                if let cloudUpdated = cloudSettings.lastUpdated,
                   let localUpdated = settings.lastUpdated,
                   cloudUpdated > localUpdated {
                    try await service.saveSettings(cloudSettings)
                    settings = cloudSettings
                }
            }
            
            print("🩸 MenstrualVM: Cloud sync completed")
        } catch {
            print("🩸 MenstrualVM: Cloud sync failed - \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    private func syncCycleToCloud(_ cycle: MenstrualCycle) async {
        do {
            _ = try await supabaseManager.syncMenstrualCycle(cycle)
        } catch {
            print("🩸 MenstrualVM: Failed to sync cycle to cloud - \(error.localizedDescription)")
        }
    }
    
    private func mergeCycles(_ cloudCycles: [MenstrualCycle]) async {
        var localCycles = service.loadCycles()
        
        for cloudCycle in cloudCycles {
            if let index = localCycles.firstIndex(where: { $0.id == cloudCycle.id }) {
                // Update if cloud version is newer
                if let cloudUpdated = cloudCycle.updatedAt,
                   let localUpdated = localCycles[index].updatedAt,
                   cloudUpdated > localUpdated {
                    localCycles[index] = cloudCycle
                }
            } else {
                // Add new cycle from cloud
                localCycles.append(cloudCycle)
            }
        }
        
        // Save merged cycles
        for cycle in localCycles {
            try? await service.saveCycle(cycle)
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateCalendarData(for month: Date) {
        dailyLogs = service.loadDailyLogs(for: month)
        calendarData = service.getCalendarData(
            for: month,
            cycles: cycles,
            logs: dailyLogs,
            prediction: prediction
        )
    }
    
    private func loadAllLogs() -> [MenstrualDailyLog] {
        // Load logs for last 6 months for statistics
        let calendar = Calendar.current
        var allLogs: [MenstrualDailyLog] = []
        
        for monthOffset in 0..<6 {
            guard let month = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) else { continue }
            allLogs.append(contentsOf: service.loadDailyLogs(for: month))
        }
        
        return allLogs
    }
    
    private func updateInsights() {
        insights = CycleInsights(
            currentPhase: currentPhase,
            dayOfCycle: dayOfCycle,
            prediction: prediction,
            statistics: statistics,
            tips: CycleInsights.getTips(for: currentPhase)
        )
    }
    
    private func scheduleReminders(for prediction: CyclePrediction) async {
        // Kept for backward compatibility if referenced elsewhere.
        // Centralized scheduling lives in NotificationService.
        await NotificationService.shared.scheduleMenstrualCycleNotifications()
    }
    
    private func flowIntensityToFlowLevel(_ intensity: FlowIntensity?) -> FlowLevel {
        switch intensity {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        case .veryHeavy: return .veryHeavy
        case .none: return .medium
        }
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
}

// MARK: - Preview Helper

extension MenstrualCycleViewModel {
    static var preview: MenstrualCycleViewModel {
        let vm = MenstrualCycleViewModel()
        // Add sample data for previews
        return vm
    }
}
