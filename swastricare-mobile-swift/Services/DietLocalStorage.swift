//
//  DietLocalStorage.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Local persistence for diet data
//

import Foundation

final class DietLocalStorage {
    
    // MARK: - Singleton
    
    static let shared = DietLocalStorage()
    
    private init() {}
    
    // MARK: - Keys
    
    private enum Keys {
        static let dietLogs = "diet_logs"
        static let dietGoals = "diet_goals"
        static let foodItems = "food_items_cache"
    }
    
    // MARK: - In-Memory Caches

    private var cachedLogs: [DietLogEntry]?
    private var cachedGoals: DietGoals?
    private var cachedFoodItems: [FoodItem]?

    // MARK: - File Manager

    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var logsFileURL: URL {
        documentsDirectory.appendingPathComponent("diet_logs.json")
    }
    
    private var goalsFileURL: URL {
        documentsDirectory.appendingPathComponent("diet_goals.json")
    }
    
    private var foodItemsFileURL: URL {
        documentsDirectory.appendingPathComponent("food_items_cache.json")
    }
    
    // MARK: - Diet Logs
    
    func loadLogs() -> [DietLogEntry] {
        if let cached = cachedLogs {
            return cached
        }

        guard let data = try? Data(contentsOf: logsFileURL) else {
            cachedLogs = []
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let logs = try? decoder.decode([DietLogEntry].self, from: data) else {
            cachedLogs = []
            return []
        }

        cachedLogs = logs
        return logs
    }

    func saveLogs(_ logs: [DietLogEntry]) {
        cachedLogs = logs

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(logs) else {
            print("🍎 DietLocalStorage: Failed to encode logs")
            return
        }

        do {
            try data.write(to: logsFileURL, options: .atomic)
            print("🍎 DietLocalStorage: Saved \(logs.count) logs")
        } catch {
            print("🍎 DietLocalStorage: Failed to save logs - \(error.localizedDescription)")
        }
    }
    
    func addLog(_ log: DietLogEntry) {
        var logs = loadLogs()
        logs.append(log)
        saveLogs(logs)
    }
    
    func deleteLog(id: UUID) {
        var logs = loadLogs()
        logs.removeAll { $0.id == id }
        saveLogs(logs)
    }
    
    func updateLog(_ log: DietLogEntry) {
        var logs = loadLogs()
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
            saveLogs(logs)
        }
    }
    
    func getUnsyncedLogs() -> [DietLogEntry] {
        loadLogs().filter { !$0.synced }
    }
    
    func markLogsAsSynced(ids: [UUID]) {
        var logs = loadLogs()
        for id in ids {
            if let index = logs.firstIndex(where: { $0.id == id }) {
                var log = logs[index]
                log.synced = true
                logs[index] = log
            }
        }
        saveLogs(logs)
    }
    
    // MARK: - Date-based Queries
    
    func getLogsForDate(_ date: Date) -> [DietLogEntry] {
        let calendar = Calendar.current
        return loadLogs().filter { entry in
            calendar.isDate(entry.loggedAt, inSameDayAs: date)
        }
    }
    
    func getWeeklyLogs() -> [[DietLogEntry]] {
        let calendar = Calendar.current
        let today = Date()
        var weeklyData: [[DietLogEntry]] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let dayLogs = getLogsForDate(date)
            weeklyData.append(dayLogs)
        }
        
        return weeklyData
    }
    
    // MARK: - Diet Goals
    
    func loadGoals() -> DietGoals {
        if let cached = cachedGoals {
            return cached
        }

        guard let data = try? Data(contentsOf: goalsFileURL) else {
            let defaults = DietGoals()
            cachedGoals = defaults
            return defaults
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let goals = try? decoder.decode(DietGoals.self, from: data) else {
            let defaults = DietGoals()
            cachedGoals = defaults
            return defaults
        }

        cachedGoals = goals
        return goals
    }

    func saveGoals(_ goals: DietGoals) {
        cachedGoals = goals

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(goals) else {
            print("🍎 DietLocalStorage: Failed to encode goals")
            return
        }

        do {
            try data.write(to: goalsFileURL, options: .atomic)
            print("🍎 DietLocalStorage: Saved goals")
        } catch {
            print("🍎 DietLocalStorage: Failed to save goals - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Food Items Cache
    
    func loadFoodItemsCache() -> [FoodItem] {
        if let cached = cachedFoodItems {
            return cached
        }

        guard let data = try? Data(contentsOf: foodItemsFileURL) else {
            cachedFoodItems = []
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let items = try? decoder.decode([FoodItem].self, from: data) else {
            cachedFoodItems = []
            return []
        }

        cachedFoodItems = items
        return items
    }

    func saveFoodItemsCache(_ items: [FoodItem]) {
        cachedFoodItems = items

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(items) else {
            print("🍎 DietLocalStorage: Failed to encode food items")
            return
        }

        do {
            try data.write(to: foodItemsFileURL, options: .atomic)
            print("🍎 DietLocalStorage: Cached \(items.count) food items")
        } catch {
            print("🍎 DietLocalStorage: Failed to cache food items - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Clear Data
    
    func clearAllData() {
        cachedLogs = nil
        cachedGoals = nil
        cachedFoodItems = nil
        try? fileManager.removeItem(at: logsFileURL)
        try? fileManager.removeItem(at: goalsFileURL)
        try? fileManager.removeItem(at: foodItemsFileURL)
        print("🍎 DietLocalStorage: Cleared all data")
    }
}
