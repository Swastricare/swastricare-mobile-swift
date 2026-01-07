//
//  HealthModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//

import Foundation

// MARK: - Health Metrics Model

struct HealthMetrics: Codable, Equatable {
    let steps: Int
    let heartRate: Int
    let sleep: String
    let activeCalories: Int
    let exerciseMinutes: Int
    let standHours: Int
    let distance: Double
    let bloodPressure: String
    let weight: String
    let timestamp: Date
    
    init(
        steps: Int = 0,
        heartRate: Int = 0,
        sleep: String = "0h 0m",
        activeCalories: Int = 0,
        exerciseMinutes: Int = 0,
        standHours: Int = 0,
        distance: Double = 0.0,
        bloodPressure: String = "--/--",
        weight: String = "--",
        timestamp: Date = Date()
    ) {
        self.steps = steps
        self.heartRate = heartRate
        self.sleep = sleep
        self.activeCalories = activeCalories
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.distance = distance
        self.bloodPressure = bloodPressure
        self.weight = weight
        self.timestamp = timestamp
    }
}

// MARK: - Daily Metric (for charts/history)

struct DailyMetric: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let dayName: String
    let steps: Int
    
    static func == (lhs: DailyMetric, rhs: DailyMetric) -> Bool {
        lhs.date == rhs.date && lhs.steps == rhs.steps
    }
}

// MARK: - Health Data State

enum HealthDataState: Equatable {
    case idle
    case loading
    case loaded(HealthMetrics)
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var metrics: HealthMetrics? {
        if case .loaded(let metrics) = self { return metrics }
        return nil
    }
}

// MARK: - Authorization State

enum HealthAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

