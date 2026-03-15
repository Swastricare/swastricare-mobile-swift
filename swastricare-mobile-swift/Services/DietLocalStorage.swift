//
//  DietLocalStorage.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Local persistence for diet data
//

import Foundation

// MARK: - Storage Errors

enum DietStorageError: Error, CustomStringConvertible {
    case encodingFailed(String)
    case writeFailed(String)
    case corruptedData(String)
    case validationFailed([DietValidationError])

    var description: String {
        switch self {
        case .encodingFailed(let detail):
            return "Failed to encode diet data: \(detail)"
        case .writeFailed(let detail):
            return "Failed to write diet data: \(detail)"
        case .corruptedData(let detail):
            return "Corrupted diet data: \(detail)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.map(\.description).joined(separator: ", "))"
        }
    }
}

@MainActor
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

    private var backupDirectory: URL {
        documentsDirectory.appendingPathComponent("diet_backups")
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

        do {
            let logs = try decoder.decode([DietLogEntry].self, from: data)
            cachedLogs = logs
            return logs
        } catch {
            print("\u{1F34E} DietLocalStorage: Corrupted logs file, attempting recovery - \(error.localizedDescription)")
            backupCorruptFile(at: logsFileURL, label: "diet_logs")
            cachedLogs = []
            return []
        }
    }

    func saveLogs(_ logs: [DietLogEntry]) throws {
        cachedLogs = logs

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data: Data
        do {
            data = try encoder.encode(logs)
        } catch {
            let storageError = DietStorageError.encodingFailed(error.localizedDescription)
            print("\u{1F34E} DietLocalStorage: \(storageError)")
            throw storageError
        }

        do {
            try data.write(to: logsFileURL, options: .atomic)
            print("\u{1F34E} DietLocalStorage: Saved \(logs.count) logs")
        } catch {
            let storageError = DietStorageError.writeFailed(error.localizedDescription)
            print("\u{1F34E} DietLocalStorage: \(storageError)")
            throw storageError
        }
    }

    /// Adds a log entry after validation. Throws on validation or storage failure.
    func addLog(_ log: DietLogEntry) throws {
        // Validate entry before saving
        let validationErrors = log.validate()
        if !validationErrors.isEmpty {
            let storageError = DietStorageError.validationFailed(validationErrors)
            print("\u{1F34E} DietLocalStorage: \(storageError)")
            throw storageError
        }

        var logs = loadLogs()
        logs.append(log)
        try saveLogs(logs)
    }

    func deleteLog(id: UUID) throws {
        var logs = loadLogs()
        logs.removeAll { $0.id == id }
        try saveLogs(logs)
    }

    func updateLog(_ log: DietLogEntry) throws {
        var logs = loadLogs()
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
            try saveLogs(logs)
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
        try? saveLogs(logs)
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
        let allLogs = loadLogs() // Single cache hit
        var weeklyData = Array(repeating: [DietLogEntry](), count: 7)

        for log in allLogs {
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                if calendar.isDate(log.loggedAt, inSameDayAs: date) {
                    weeklyData[dayOffset].append(log)
                    break
                }
            }
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

        do {
            let goals = try decoder.decode(DietGoals.self, from: data)
            cachedGoals = goals
            return goals
        } catch {
            print("\u{1F34E} DietLocalStorage: Corrupted goals file, using defaults - \(error.localizedDescription)")
            backupCorruptFile(at: goalsFileURL, label: "diet_goals")
            let defaults = DietGoals()
            cachedGoals = defaults
            return defaults
        }
    }

    func saveGoals(_ goals: DietGoals) {
        cachedGoals = goals

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(goals) else {
            print("\u{1F34E} DietLocalStorage: Failed to encode goals")
            return
        }

        do {
            try data.write(to: goalsFileURL, options: .atomic)
            print("\u{1F34E} DietLocalStorage: Saved goals")
        } catch {
            print("\u{1F34E} DietLocalStorage: Failed to save goals - \(error.localizedDescription)")
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

        do {
            let items = try decoder.decode([FoodItem].self, from: data)
            cachedFoodItems = items
            return items
        } catch {
            print("\u{1F34E} DietLocalStorage: Corrupted food items cache, clearing - \(error.localizedDescription)")
            backupCorruptFile(at: foodItemsFileURL, label: "food_items")
            cachedFoodItems = []
            return []
        }
    }

    func saveFoodItemsCache(_ items: [FoodItem]) {
        cachedFoodItems = items

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(items) else {
            print("\u{1F34E} DietLocalStorage: Failed to encode food items")
            return
        }

        do {
            try data.write(to: foodItemsFileURL, options: .atomic)
            print("\u{1F34E} DietLocalStorage: Cached \(items.count) food items")
        } catch {
            print("\u{1F34E} DietLocalStorage: Failed to cache food items - \(error.localizedDescription)")
        }
    }

    // MARK: - Validate and Repair

    /// Scans all log entries for integrity issues, removes invalid entries, and returns a report.
    @discardableResult
    func validateAndRepair() -> (total: Int, removed: Int, errors: [String]) {
        var logs = loadLogs()
        let originalCount = logs.count
        var errorMessages: [String] = []

        logs = logs.filter { entry in
            let issues = entry.validate()
            if !issues.isEmpty {
                let detail = issues.map(\.description).joined(separator: "; ")
                errorMessages.append("Entry \(entry.id): \(detail)")
                return false
            }
            return true
        }

        let removedCount = originalCount - logs.count

        if removedCount > 0 {
            try? saveLogs(logs)
            print("\u{1F34E} DietLocalStorage: Repaired data \u{2014} removed \(removedCount) invalid entries out of \(originalCount)")
        } else {
            print("\u{1F34E} DietLocalStorage: All \(originalCount) entries passed validation")
        }

        return (total: originalCount, removed: removedCount, errors: errorMessages)
    }

    // MARK: - Clear Data

    func clearAllData() {
        cachedLogs = nil
        cachedGoals = nil
        cachedFoodItems = nil
        try? fileManager.removeItem(at: logsFileURL)
        try? fileManager.removeItem(at: goalsFileURL)
        try? fileManager.removeItem(at: foodItemsFileURL)
        print("\u{1F34E} DietLocalStorage: Cleared all data")
    }

    // MARK: - Corruption Recovery

    /// Backs up a corrupted file before replacing it, so data can potentially be recovered manually.
    private func backupCorruptFile(at url: URL, label: String) {
        do {
            if !fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let backupName = "\(label)_corrupt_\(timestamp).json"
            let backupURL = backupDirectory.appendingPathComponent(backupName)

            try fileManager.copyItem(at: url, to: backupURL)
            try fileManager.removeItem(at: url)
            print("\u{1F34E} DietLocalStorage: Backed up corrupt file to \(backupName)")
        } catch {
            // If backup fails, just remove the corrupt file to allow fresh start
            try? fileManager.removeItem(at: url)
            print("\u{1F34E} DietLocalStorage: Could not backup corrupt file, removed it - \(error.localizedDescription)")
        }
    }
}
