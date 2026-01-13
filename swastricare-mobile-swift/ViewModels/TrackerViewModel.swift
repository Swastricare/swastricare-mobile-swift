//
//  TrackerViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class TrackerViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var selectedDate: Date = Date()
    @Published private(set) var healthMetrics = HealthMetrics()
    @Published private(set) var weeklySteps: [DailyMetric] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var analysisState: AnalysisState = .idle
    @Published var showAnalysisSheet = false
    
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
    
    var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }
    
    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var maxWeeklySteps: Int {
        weeklySteps.map { $0.steps }.max() ?? 1
    }
    
    // MARK: - Dependencies
    
    private let healthService: HealthKitServiceProtocol
    private let aiService: AIServiceProtocol
    private let userDefaultsKey = "hasRequestedHealthAuthorization"
    
    // MARK: - Init
    
    init(healthService: HealthKitServiceProtocol = HealthKitService.shared,
         aiService: AIServiceProtocol = AIService.shared) {
        self.healthService = healthService
        self.aiService = aiService
        self.isAuthorized = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    // MARK: - Actions
    
    func loadData() async {
        // Allow loading in demo mode even without authorization (thread-safe check)
        let isDemoMode = DemoModeService.isDemoModeEnabledValue
        
        guard isAuthorized || isDemoMode else { return }
        
        isLoading = true
        
        healthMetrics = await healthService.fetchHealthMetrics(for: selectedDate)
        weeklySteps = await healthService.fetchWeeklySteps()
        
        isLoading = false
    }
    
    func selectDate(_ date: Date) async {
        selectedDate = date
        await loadDataForSelectedDate()
    }
    
    func loadDataForSelectedDate() async {
        // Allow loading in demo mode even without authorization (thread-safe check)
        let isDemoMode = DemoModeService.isDemoModeEnabledValue
        
        guard isAuthorized || isDemoMode else { return }
        
        isLoading = true
        healthMetrics = await healthService.fetchHealthMetrics(for: selectedDate)
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - AI Analysis
    
    func requestAIAnalysis() async {
        guard !healthMetrics.isEmpty else {
            errorMessage = "No health data available to analyze"
            return
        }
        
        analysisState = .analyzing
        showAnalysisSheet = true
        
        do {
            let analysis = try await aiService.analyzeHealth(healthMetrics)
            let result = HealthAnalysisResult(
                metrics: healthMetrics,
                analysis: analysis
            )
            analysisState = .completed(result)
        } catch {
            analysisState = .error(error.localizedDescription)
            errorMessage = "Failed to analyze health data: \(error.localizedDescription)"
        }
    }
    
    func dismissAnalysis() {
        showAnalysisSheet = false
        analysisState = .idle
    }
    
    // MARK: - Helpers
    
    func dayName(for date: Date) -> String {
        let calendar = Calendar.current
        return calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
    }
    
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearDemoData() {
        // Reset health metrics to empty/default values
        healthMetrics = HealthMetrics()
        weeklySteps = []
    }
}

