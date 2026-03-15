//
//  MealSuggestionEngine.swift
//  swastricare-mobile-swift
//
//  Smart suggestion engine that tracks meal frequency per time-of-day
//  and suggests foods based on usage patterns.
//

import Foundation

// MARK: - Food Frequency Model

struct FoodFrequency: Codable, Equatable {
    let foodItemId: UUID?
    let name: String
    var count: Int
    var lastUsed: Date
}

// MARK: - Meal Suggestion Engine

@MainActor
final class MealSuggestionEngine {

    // MARK: - Singleton

    static let shared = MealSuggestionEngine()

    private init() {
        loadFrequencyData()
    }

    // MARK: - Storage

    private let userDefaultsKey = "meal_frequency_data"

    /// In-memory cache: [MealType.rawValue : [FoodFrequency]]
    private var frequencyMap: [String: [FoodFrequency]] = [:]

    // MARK: - Public API

    /// Suggest top foods for a given meal type, ranked by frequency then recency.
    func suggestFoods(for mealType: MealType, from foodCache: [FoodItem], limit: Int = 5) -> [FoodItem] {
        let frequencies = frequencyMap[mealType.rawValue] ?? []
        guard !frequencies.isEmpty else { return [] }

        // Sort by count descending, then by lastUsed descending
        let sorted = frequencies.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.lastUsed > rhs.lastUsed
        }

        var result: [FoodItem] = []
        for freq in sorted {
            // Try to match by id first, then by name
            if let id = freq.foodItemId,
               let item = foodCache.first(where: { $0.id == id }) {
                result.append(item)
            } else if let item = foodCache.first(where: { $0.name == freq.name }) {
                result.append(item)
            }
            if result.count >= limit { break }
        }
        return result
    }

    /// Record that a food item was logged for a specific meal type.
    func recordMealLogged(foodItem: FoodItem, mealType: MealType) {
        let key = mealType.rawValue
        var frequencies = frequencyMap[key] ?? []

        if let index = frequencies.firstIndex(where: { $0.name == foodItem.name }) {
            // Increment existing
            var freq = frequencies[index]
            freq.count += 1
            freq.lastUsed = Date()
            frequencies[index] = freq
        } else {
            // Add new entry
            let freq = FoodFrequency(
                foodItemId: foodItem.id,
                name: foodItem.name,
                count: 1,
                lastUsed: Date()
            )
            frequencies.append(freq)
        }

        frequencyMap[key] = frequencies
        saveFrequencyData()
        print("🍎 MealSuggestionEngine: Recorded \(foodItem.name) for \(mealType.displayName) (count: \(frequencies.first(where: { $0.name == foodItem.name })?.count ?? 1))")
    }

    /// Record a food logged by name (for custom foods or template items without a FoodItem).
    func recordMealLoggedByName(foodName: String, foodItemId: UUID?, mealType: MealType) {
        let key = mealType.rawValue
        var frequencies = frequencyMap[key] ?? []

        if let index = frequencies.firstIndex(where: { $0.name == foodName }) {
            var freq = frequencies[index]
            freq.count += 1
            freq.lastUsed = Date()
            frequencies[index] = freq
        } else {
            let freq = FoodFrequency(
                foodItemId: foodItemId,
                name: foodName,
                count: 1,
                lastUsed: Date()
            )
            frequencies.append(freq)
        }

        frequencyMap[key] = frequencies
        saveFrequencyData()
    }

    /// Get the most frequent meals across all meal types.
    /// Returns array of (MealType, top foods) sorted by frequency.
    func getMostFrequentMeals(from foodCache: [FoodItem]) -> [(MealType, [FoodItem])] {
        var result: [(MealType, [FoodItem])] = []

        for mealType in MealType.allCases {
            let suggestions = suggestFoods(for: mealType, from: foodCache, limit: 3)
            if !suggestions.isEmpty {
                result.append((mealType, suggestions))
            }
        }

        return result
    }

    /// Get frequency-ranked food names across all meal types.
    /// Useful for boosting search results.
    func frequencyRankedFoodNames(limit: Int = 20) -> [String: Int] {
        var combined: [String: Int] = [:]

        for (_, frequencies) in frequencyMap {
            for freq in frequencies {
                combined[freq.name, default: 0] += freq.count
            }
        }

        return combined
    }

    /// Auto-detect the current meal type based on time of day.
    static func currentMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return .breakfast
        case 10..<12: return .morningSnack
        case 12..<15: return .lunch
        case 15..<17: return .eveningSnack
        case 17..<22: return .dinner
        default: return .lateNight
        }
    }

    // MARK: - Persistence

    private func loadFrequencyData() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            frequencyMap = [:]
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            frequencyMap = try decoder.decode([String: [FoodFrequency]].self, from: data)
            print("🍎 MealSuggestionEngine: Loaded frequency data for \(frequencyMap.count) meal types")
        } catch {
            print("🍎 MealSuggestionEngine: Failed to decode frequency data - \(error.localizedDescription)")
            frequencyMap = [:]
        }
    }

    private func saveFrequencyData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(frequencyMap)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("🍎 MealSuggestionEngine: Failed to encode frequency data - \(error.localizedDescription)")
        }
    }
}
