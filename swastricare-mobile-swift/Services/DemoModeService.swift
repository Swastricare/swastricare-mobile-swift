//
//  DemoModeService.swift
//  swastricare-mobile-swift
//
//  Demo Mode Service - Provides demo health data for App Store review
//

import Foundation
import Combine

@MainActor
final class DemoModeService: ObservableObject {
    
    static let shared = DemoModeService()
    
    // MARK: - Published State
    
    @Published var isDemoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDemoModeEnabled, forKey: "isDemoModeEnabled")
        }
    }
    
    // MARK: - UserDefaults Key
    
    private let demoModeKey = "isDemoModeEnabled"
    
    // MARK: - Thread-safe property access
    
    /// Thread-safe check for demo mode status (can be called from any context)
    nonisolated static var isDemoModeEnabledValue: Bool {
        UserDefaults.standard.bool(forKey: "isDemoModeEnabled")
    }
    
    // MARK: - Init
    
    private init() {
        self.isDemoModeEnabled = UserDefaults.standard.bool(forKey: demoModeKey)
    }
    
    // MARK: - Demo Data Generation
    
    /// Generates realistic demo health metrics for a given date
    func generateDemoHealthMetrics(for date: Date) -> HealthMetrics {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let dayOfWeek = calendar.component(.weekday, from: date)
        
        // Generate realistic demo data with some variation
        // Weekends typically have different activity patterns
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        // Base values (more active on weekdays)
        let baseSteps = isWeekend ? 6500 : 8500
        let stepsVariation = Int.random(in: -1500...2000)
        let steps = max(0, baseSteps + stepsVariation)
        
        // Heart rate: resting heart rate + some variation
        let heartRate = Int.random(in: 65...85)
        
        // Sleep: 7-9 hours with some variation
        let sleepHours = Int.random(in: 7...9)
        let sleepMinutes = Int.random(in: 0...59)
        let sleep = "\(sleepHours)h \(sleepMinutes)m"
        
        // Active calories: proportional to steps
        let activeCalories = Int(Double(steps) * 0.04) + Int.random(in: -50...100)
        
        // Exercise minutes: 20-45 minutes
        let exerciseMinutes = Int.random(in: 20...45)
        
        // Stand hours: 8-12 hours
        let standHours = Int.random(in: 8...12)
        
        // Distance: proportional to steps (average stride length ~0.7m)
        let distance = Double(steps) * 0.0007 + Double.random(in: -0.5...0.5)
        
        // Blood pressure: normal range
        let systolic = Int.random(in: 110...130)
        let diastolic = Int.random(in: 70...85)
        let bloodPressure = "\(systolic)/\(diastolic)"
        
        // Weight: 65-75 kg (demo value)
        let weight = String(format: "%.1f", Double.random(in: 65.0...75.0))
        
        return HealthMetrics(
            steps: steps,
            heartRate: heartRate,
            sleep: sleep,
            activeCalories: max(0, activeCalories),
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            distance: max(0, distance),
            bloodPressure: bloodPressure,
            weight: weight,
            timestamp: date
        )
    }
    
    /// Generates demo weekly steps data
    func generateDemoWeeklySteps() -> [DailyMetric] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var metrics: [DailyMetric] = []
        
        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let demoMetrics = generateDemoHealthMetrics(for: date)
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                metrics.append(DailyMetric(date: date, dayName: dayName, steps: demoMetrics.steps))
            }
        }
        
        return metrics
    }
    
    /// Generates demo health metrics history
    func generateDemoHealthMetricsHistory(days: Int) -> [HealthMetrics] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var history: [HealthMetrics] = []
        
        for dayOffset in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                history.append(generateDemoHealthMetrics(for: date))
            }
        }
        
        return history
    }
    
    // MARK: - Demo Mode Toggle
    
    func toggleDemoMode() {
        isDemoModeEnabled.toggle()
    }
    
    func enableDemoMode() {
        isDemoModeEnabled = true
    }
    
    func disableDemoMode() {
        isDemoModeEnabled = false
    }
}
