//
//  FoodTrackingService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles food entry CRUD operations with Supabase nutrition_logs table
//

import Foundation

// MARK: - Food Tracking Service Protocol

protocol FoodTrackingServiceProtocol {
    func fetchEntries(for date: Date) async throws -> [FoodEntry]
    func addEntry(_ entry: FoodEntry) async throws -> FoodEntry
    func updateEntry(_ entry: FoodEntry) async throws -> FoodEntry
    func deleteEntry(id: UUID) async throws
    func fetchGoal() async throws -> DailyNutritionGoal?
    func saveGoal(_ goal: DailyNutritionGoal) async throws
    func fetchWeekSummary() async throws -> [DailyNutritionSummary]
}

// MARK: - Food Tracking Service Implementation

final class FoodTrackingService: FoodTrackingServiceProtocol {

    static let shared = FoodTrackingService()

    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Helpers

    private func getHealthProfileId() async throws -> UUID {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            throw FoodTrackingError.notAuthenticated
        }

        struct ProfileId: Decodable { let id: UUID }

        let profiles: [ProfileId] = try await supabase.client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_primary", value: true)
            .limit(1)
            .execute()
            .value

        guard let profileId = profiles.first?.id else {
            throw FoodTrackingError.noHealthProfile
        }
        return profileId
    }

    // MARK: - Entries

    func fetchEntries(for date: Date) async throws -> [FoodEntry] {
        let profileId = try await getHealthProfileId()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct NutritionRecord: Decodable {
            let id: UUID
            let food_name: String
            let meal_type: String
            let serving_size: Double?
            let servings: Double?
            let calories: Double?
            let protein_g: Double?
            let carbs_g: Double?
            let fat_g: Double?
            let fiber_g: Double?
            let sugar_g: Double?
            let sodium_mg: Double?
            let meal_time: String?
            let notes: String?
            let image_url: String?
            let source: String?
            let created_at: String?
        }

        let records: [NutritionRecord] = try await supabase.client
            .from("nutrition_logs")
            .select()
            .eq("health_profile_id", value: profileId.uuidString)
            .gte("meal_time", value: formatter.string(from: startOfDay))
            .lt("meal_time", value: formatter.string(from: endOfDay))
            .order("meal_time", ascending: true)
            .execute()
            .value

        return records.map { record in
            let mealType = MealType(rawValue: record.meal_type) ?? .snack
            let servings = record.servings ?? 1
            let perServing = servings > 0 ? servings : 1

            return FoodEntry(
                id: record.id,
                name: record.food_name,
                mealType: mealType,
                category: .other,
                servingSize: record.serving_size ?? 1,
                servingUnit: .piece,
                numberOfServings: servings,
                nutrition: NutritionInfo(
                    calories: (record.calories ?? 0) / perServing,
                    proteinGrams: (record.protein_g ?? 0) / perServing,
                    carbsGrams: (record.carbs_g ?? 0) / perServing,
                    fatGrams: (record.fat_g ?? 0) / perServing,
                    fiberGrams: record.fiber_g.map { $0 / perServing },
                    sugarGrams: record.sugar_g.map { $0 / perServing },
                    sodiumMg: record.sodium_mg.map { $0 / perServing }
                ),
                consumedAt: {
                    if let t = record.meal_time { return formatter.date(from: t) ?? Date() }
                    return Date()
                }(),
                notes: record.notes,
                imageURL: record.image_url,
                isSynced: true,
                createdAt: {
                    if let t = record.created_at { return formatter.date(from: t) ?? Date() }
                    return Date()
                }(),
                updatedAt: Date()
            )
        }
    }

    func addEntry(_ entry: FoodEntry) async throws -> FoodEntry {
        let profileId = try await getHealthProfileId()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct InsertPayload: Encodable {
            let health_profile_id: UUID
            let food_name: String
            let meal_type: String
            let meal_time: String
            let serving_size: Double
            let servings: Double
            let calories: Double
            let protein_g: Double
            let carbs_g: Double
            let fat_g: Double
            let fiber_g: Double?
            let sugar_g: Double?
            let sodium_mg: Double?
            let notes: String?
            let source: String
        }

        let total = entry.totalNutrition
        let payload = InsertPayload(
            health_profile_id: profileId,
            food_name: entry.name,
            meal_type: entry.mealType.rawValue,
            meal_time: formatter.string(from: entry.consumedAt),
            serving_size: entry.servingSize,
            servings: entry.numberOfServings,
            calories: total.calories,
            protein_g: total.proteinGrams,
            carbs_g: total.carbsGrams,
            fat_g: total.fatGrams,
            fiber_g: total.fiberGrams,
            sugar_g: total.sugarGrams,
            sodium_mg: total.sodiumMg,
            notes: entry.notes,
            source: "manual"
        )

        struct InsertResponse: Decodable { let id: UUID }

        let response: InsertResponse = try await supabase.client
            .from("nutrition_logs")
            .insert(payload)
            .select("id")
            .single()
            .execute()
            .value

        var saved = entry
        saved.isSynced = true
        print("🍽️ Added food entry: \(entry.name) (\(Int(total.calories)) cal)")
        return FoodEntry(
            id: response.id,
            name: saved.name,
            mealType: saved.mealType,
            category: saved.category,
            servingSize: saved.servingSize,
            servingUnit: saved.servingUnit,
            numberOfServings: saved.numberOfServings,
            nutrition: saved.nutrition,
            consumedAt: saved.consumedAt,
            notes: saved.notes,
            imageURL: saved.imageURL,
            isSynced: true,
            createdAt: saved.createdAt,
            updatedAt: Date()
        )
    }

    func updateEntry(_ entry: FoodEntry) async throws -> FoodEntry {
        let total = entry.totalNutrition

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct UpdatePayload: Encodable {
            let food_name: String
            let meal_type: String
            let meal_time: String
            let serving_size: Double
            let servings: Double
            let calories: Double
            let protein_g: Double
            let carbs_g: Double
            let fat_g: Double
            let fiber_g: Double?
            let sugar_g: Double?
            let sodium_mg: Double?
            let notes: String?
        }

        let payload = UpdatePayload(
            food_name: entry.name,
            meal_type: entry.mealType.rawValue,
            meal_time: formatter.string(from: entry.consumedAt),
            serving_size: entry.servingSize,
            servings: entry.numberOfServings,
            calories: total.calories,
            protein_g: total.proteinGrams,
            carbs_g: total.carbsGrams,
            fat_g: total.fatGrams,
            fiber_g: total.fiberGrams,
            sugar_g: total.sugarGrams,
            sodium_mg: total.sodiumMg,
            notes: entry.notes
        )

        try await supabase.client
            .from("nutrition_logs")
            .update(payload)
            .eq("id", value: entry.id.uuidString)
            .execute()

        print("🍽️ Updated food entry: \(entry.name)")
        return entry
    }

    func deleteEntry(id: UUID) async throws {
        try await supabase.client
            .from("nutrition_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        print("🍽️ Deleted food entry: \(id)")
    }

    // MARK: - Goals (stored in UserDefaults for simplicity)

    func fetchGoal() async throws -> DailyNutritionGoal? {
        guard let data = UserDefaults.standard.data(forKey: "nutrition_daily_goal"),
              let goal = try? JSONDecoder().decode(DailyNutritionGoal.self, from: data) else {
            return nil
        }
        return goal
    }

    func saveGoal(_ goal: DailyNutritionGoal) async throws {
        let data = try JSONEncoder().encode(goal)
        UserDefaults.standard.set(data, forKey: "nutrition_daily_goal")
        print("🍽️ Saved nutrition goal: \(goal.calorieTarget) cal")
    }

    // MARK: - Week Summary

    func fetchWeekSummary() async throws -> [DailyNutritionSummary] {
        let goal = (try? await fetchGoal()) ?? DailyNutritionGoal()
        let calendar = Calendar.current
        var summaries: [DailyNutritionSummary] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let entries = try await fetchEntries(for: date)
            summaries.append(DailyNutritionSummary(date: date, entries: entries, goal: goal))
        }

        return summaries
    }
}

// MARK: - Food Tracking Error

enum FoodTrackingError: LocalizedError {
    case notAuthenticated
    case noHealthProfile
    case entryNotFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to track food."
        case .noHealthProfile: return "No health profile found. Complete your profile first."
        case .entryNotFound: return "Food entry not found."
        case .networkError(let msg): return msg
        }
    }
}
