//
//  ActivityLogger.swift
//  swastricare-mobile-swift
//
//  Created by AI Assistant on 06/01/26.
//

import Foundation
import SwiftUI

@MainActor
class ActivityLogger: ObservableObject {
    static let shared = ActivityLogger()
    
    @Published var activities: [ManualActivity] = []
    @Published var todayActivities: [ManualActivity] = []
    
    private let userDefaults = UserDefaults.standard
    private let activitiesKey = "manual_activities"
    
    private init() {
        loadActivities()
        updateTodayActivities()
    }
    
    // MARK: - Load & Save
    
    private func loadActivities() {
        guard let data = userDefaults.data(forKey: activitiesKey) else {
            activities = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            activities = try decoder.decode([ManualActivity].self, from: data)
        } catch {
            print("Failed to load activities: \(error)")
            activities = []
        }
    }
    
    private func saveActivities() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(activities)
            userDefaults.set(data, forKey: activitiesKey)
        } catch {
            print("Failed to save activities: \(error)")
        }
    }
    
    private func updateTodayActivities() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        todayActivities = activities.filter { activity in
            calendar.isDate(activity.loggedAt, inSameDayAs: today)
        }.sorted { $0.loggedAt > $1.loggedAt }
    }
    
    // MARK: - Public Methods
    
    func logActivity(_ activity: ManualActivity) {
        activities.append(activity)
        saveActivities()
        updateTodayActivities()
    }
    
    func logWater(amount: Int) {
        let activity = ManualActivity(
            type: .water,
            value: Double(amount),
            unit: "ml",
            notes: nil
        )
        logActivity(activity)
    }
    
    func logWorkout(type: String, duration: Int, notes: String? = nil) {
        let activity = ManualActivity(
            type: .workout,
            value: Double(duration),
            unit: "min",
            notes: notes ?? type
        )
        logActivity(activity)
    }
    
    func logMeal(name: String, calories: Int? = nil) {
        let activity = ManualActivity(
            type: .meal,
            value: Double(calories ?? 0),
            unit: "kcal",
            notes: name
        )
        logActivity(activity)
    }
    
    func logMeditation(duration: Int) {
        let activity = ManualActivity(
            type: .meditation,
            value: Double(duration),
            unit: "min",
            notes: nil
        )
        logActivity(activity)
    }
    
    func deleteActivity(_ activity: ManualActivity) {
        activities.removeAll { $0.id == activity.id }
        saveActivities()
        updateTodayActivities()
    }
    
    func getActivitiesForDate(_ date: Date) -> [ManualActivity] {
        let calendar = Calendar.current
        return activities.filter { activity in
            calendar.isDate(activity.loggedAt, inSameDayAs: date)
        }.sorted { $0.loggedAt > $1.loggedAt }
    }
    
    func getTodayWaterIntake() -> Int {
        return todayActivities
            .filter { $0.type == .water }
            .reduce(0) { $0 + Int($1.value) }
    }
    
    func getTodayWorkoutMinutes() -> Int {
        return todayActivities
            .filter { $0.type == .workout }
            .reduce(0) { $0 + Int($1.value) }
    }
    
    func getTodayMeditationMinutes() -> Int {
        return todayActivities
            .filter { $0.type == .meditation }
            .reduce(0) { $0 + Int($1.value) }
    }
    
    func getTodayMeals() -> [ManualActivity] {
        return todayActivities.filter { $0.type == .meal }
    }
}

// MARK: - Data Models

struct ManualActivity: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ActivityType
    let value: Double
    let unit: String
    let notes: String?
    let loggedAt: Date
    
    init(id: UUID = UUID(), type: ActivityType, value: Double, unit: String, notes: String?, loggedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.notes = notes
        self.loggedAt = loggedAt
    }
    
    var displayValue: String {
        switch type {
        case .water:
            return "\(Int(value)) \(unit)"
        case .workout:
            return "\(Int(value)) \(unit)"
        case .meal:
            return value > 0 ? "\(Int(value)) \(unit)" : "Logged"
        case .meditation:
            return "\(Int(value)) \(unit)"
        }
    }
    
    var icon: String {
        switch type {
        case .water:
            return "drop.fill"
        case .workout:
            return "figure.run"
        case .meal:
            return "fork.knife"
        case .meditation:
            return "brain.head.profile"
        }
    }
    
    var color: Color {
        switch type {
        case .water:
            return .cyan
        case .workout:
            return .orange
        case .meal:
            return .green
        case .meditation:
            return .purple
        }
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case water = "Water"
    case workout = "Workout"
    case meal = "Meal"
    case meditation = "Meditation"
    
    var displayName: String {
        return self.rawValue
    }
}
