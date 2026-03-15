//
//  MealTemplate.swift
//  swastricare-mobile-swift
//
//  Meal template model and storage for saving/reusing meal combinations.
//

import Foundation

// MARK: - Template Item

struct TemplateItem: Codable, Equatable, Identifiable {
    let id: UUID
    let foodItemId: UUID?
    let foodName: String
    let quantity: Double
    let servingUnit: ServingUnit
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}

// MARK: - Meal Template

struct MealTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var mealType: MealType
    var items: [TemplateItem]
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType,
        items: [TemplateItem],
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.items = items
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    /// Total calories for the template
    var totalCalories: Int {
        items.reduce(0) { $0 + $1.calories }
    }

    /// Summary string like "3 items - 520 cal"
    var summary: String {
        "\(items.count) item\(items.count == 1 ? "" : "s") \u{2022} \(totalCalories) cal"
    }
}

// MARK: - Meal Template Storage

@MainActor
final class MealTemplateStorage {

    // MARK: - Singleton

    static let shared = MealTemplateStorage()

    private init() {}

    // MARK: - In-Memory Cache

    private var cachedTemplates: [MealTemplate]?

    // MARK: - File URL

    private var templatesFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meal_templates.json")
    }

    // MARK: - CRUD

    func loadAll() -> [MealTemplate] {
        if let cached = cachedTemplates {
            return cached
        }

        guard let data = try? Data(contentsOf: templatesFileURL) else {
            cachedTemplates = []
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let templates = try? decoder.decode([MealTemplate].self, from: data) else {
            cachedTemplates = []
            return []
        }

        cachedTemplates = templates
        print("🍎 MealTemplateStorage: Loaded \(templates.count) templates")
        return templates
    }

    func save(_ template: MealTemplate) {
        var templates = loadAll()

        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }

        persist(templates)
        print("🍎 MealTemplateStorage: Saved template '\(template.name)'")
    }

    func delete(id: UUID) {
        var templates = loadAll()
        templates.removeAll { $0.id == id }
        persist(templates)
        print("🍎 MealTemplateStorage: Deleted template \(id)")
    }

    /// Mark a template as used (increment count and update lastUsedAt).
    func markUsed(id: UUID) {
        var templates = loadAll()
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return }
        var template = templates[index]
        template.useCount += 1
        template.lastUsedAt = Date()
        templates[index] = template
        persist(templates)
    }

    /// Get templates for a specific meal type, sorted by useCount descending.
    func templates(for mealType: MealType) -> [MealTemplate] {
        loadAll()
            .filter { $0.mealType == mealType }
            .sorted { $0.useCount > $1.useCount }
    }

    // MARK: - Persistence

    private func persist(_ templates: [MealTemplate]) {
        cachedTemplates = templates

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(templates) else {
            print("🍎 MealTemplateStorage: Failed to encode templates")
            return
        }

        do {
            try data.write(to: templatesFileURL, options: .atomic)
        } catch {
            print("🍎 MealTemplateStorage: Failed to save templates - \(error.localizedDescription)")
        }
    }
}
