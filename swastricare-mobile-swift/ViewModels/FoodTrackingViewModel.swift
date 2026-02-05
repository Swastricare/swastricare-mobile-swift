//
//  FoodTrackingViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  State management for food and nutrition tracking module
//

import Foundation
import SwiftUI

// MARK: - Food Tracking ViewModel

@MainActor
final class FoodTrackingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var dataState: FoodDataState = .idle
    @Published var entries: [FoodEntry] = []
    @Published var selectedDate: Date = Date()
    @Published var dailyGoal: DailyNutritionGoal = DailyNutritionGoal()
    @Published var weekSummary: [DailyNutritionSummary] = []

    // Sheet state
    @Published var showAddEntrySheet = false
    @Published var showGoalSheet = false
    @Published var selectedEntry: FoodEntry?
    @Published var showEntryDetail = false

    // Form state
    @Published var formName = ""
    @Published var formMealType: MealType = .lunch
    @Published var formCategory: FoodCategory = .other
    @Published var formCalories = ""
    @Published var formProtein = ""
    @Published var formCarbs = ""
    @Published var formFat = ""
    @Published var formServings = "1"
    @Published var formNotes = ""

    // Alert
    @Published var alertMessage: String?
    @Published var showAlert = false

    // MARK: - Dependencies

    private let foodService: FoodTrackingServiceProtocol

    // MARK: - Init

    init(foodService: FoodTrackingServiceProtocol = FoodTrackingService.shared) {
        self.foodService = foodService
    }

    // MARK: - Computed Properties

    var summary: DailyNutritionSummary {
        DailyNutritionSummary(date: selectedDate, entries: entries, goal: dailyGoal)
    }

    var hasEntries: Bool { !entries.isEmpty }

    var totalCalories: Int { Int(summary.totalCalories) }
    var caloriesRemaining: Int { summary.caloriesRemaining }
    var calorieProgress: Double { summary.calorieProgress }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var formattedDate: String {
        if isToday { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    var mealSuggestion: MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10: return .breakfast
        case 10..<14: return .lunch
        case 14..<17: return .snack
        case 17..<22: return .dinner
        default: return .snack
        }
    }

    // MARK: - Load Data

    func loadData() async {
        dataState = .loading

        do {
            async let entriesResult = foodService.fetchEntries(for: selectedDate)
            async let goalResult = foodService.fetchGoal()

            entries = try await entriesResult
            if let goal = try await goalResult {
                dailyGoal = goal
            }
            dataState = .loaded
        } catch {
            print("🍽️ Failed to load food data: \(error.localizedDescription)")
            dataState = .error(error.localizedDescription)
        }
    }

    func loadWeekSummary() async {
        do {
            weekSummary = try await foodService.fetchWeekSummary()
        } catch {
            print("🍽️ Failed to load week summary: \(error.localizedDescription)")
        }
    }

    // MARK: - Date Navigation

    func selectDate(_ date: Date) {
        selectedDate = date
        Task { await loadData() }
    }

    func goToToday() {
        selectDate(Date())
    }

    // MARK: - Add Entry

    func addEntry() async {
        let name = formName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            showError("Please enter a food name.")
            return
        }

        let calories = Double(formCalories) ?? 0
        let protein = Double(formProtein) ?? 0
        let carbs = Double(formCarbs) ?? 0
        let fat = Double(formFat) ?? 0
        let servings = Double(formServings) ?? 1

        let entry = FoodEntry(
            name: name,
            mealType: formMealType,
            category: formCategory,
            servingSize: 1,
            servingUnit: .piece,
            numberOfServings: servings,
            nutrition: NutritionInfo(
                calories: calories,
                proteinGrams: protein,
                carbsGrams: carbs,
                fatGrams: fat
            ),
            consumedAt: selectedDate == Calendar.current.startOfDay(for: Date()) ? Date() : selectedDate,
            notes: formNotes.isEmpty ? nil : formNotes
        )

        do {
            let saved = try await foodService.addEntry(entry)
            entries.append(saved)
            entries.sort { $0.consumedAt < $1.consumedAt }
            resetForm()
            showAddEntrySheet = false
            dataState = .loaded
        } catch {
            showError("Failed to add entry: \(error.localizedDescription)")
        }
    }

    func quickAdd(preset: QuickAddFoodPreset) async {
        let entry = FoodEntry(
            name: preset.name,
            mealType: mealSuggestion,
            category: preset.category,
            servingSize: preset.servingSize,
            servingUnit: preset.servingUnit,
            numberOfServings: 1,
            nutrition: preset.nutrition,
            consumedAt: Date()
        )

        do {
            let saved = try await foodService.addEntry(entry)
            entries.append(saved)
            entries.sort { $0.consumedAt < $1.consumedAt }
            dataState = .loaded
        } catch {
            showError("Failed to add \(preset.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Entry

    func deleteEntry(_ entry: FoodEntry) async {
        do {
            try await foodService.deleteEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch {
            showError("Failed to delete entry: \(error.localizedDescription)")
        }
    }

    // MARK: - Goal Management

    func saveGoal() async {
        do {
            try await foodService.saveGoal(dailyGoal)
            showGoalSheet = false
        } catch {
            showError("Failed to save goal: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    func resetForm() {
        formName = ""
        formMealType = mealSuggestion
        formCategory = .other
        formCalories = ""
        formProtein = ""
        formCarbs = ""
        formFat = ""
        formServings = "1"
        formNotes = ""
    }

    func prepareAddEntry() {
        resetForm()
        formMealType = mealSuggestion
        showAddEntrySheet = true
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
