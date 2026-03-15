//
//  BarcodeScannerService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Service Layer
//  Barcode scanning and Open Food Facts API lookup
//

import Foundation

// MARK: - Protocol

protocol BarcodeScannerServiceProtocol {
    func lookupBarcode(_ barcode: String) async throws -> FoodItem?
}

// MARK: - Errors

enum BarcodeLookupError: Error, LocalizedError {
    case productNotFound
    case networkError(String)
    case incompleteData
    case invalidBarcode

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found in database"
        case .networkError(let message):
            return "Network error: \(message)"
        case .incompleteData:
            return "Product data is incomplete"
        case .invalidBarcode:
            return "Invalid barcode format"
        }
    }
}

// MARK: - Open Food Facts Response Models

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

private struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let nutriments: OpenFoodFactsNutriments?
    let categories: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriments
        case categories
        case imageUrl = "image_url"
    }
}

private struct OpenFoodFactsNutriments: Decodable {
    let energyKcalServing: Double?
    let energyKcal100g: Double?
    let proteinsServing: Double?
    let proteins100g: Double?
    let carbohydratesServing: Double?
    let carbohydrates100g: Double?
    let fatServing: Double?
    let fat100g: Double?
    let fiberServing: Double?
    let fiber100g: Double?
    let sugarsServing: Double?
    let sugars100g: Double?
    let sodiumServing: Double?
    let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcalServing = "energy-kcal_serving"
        case energyKcal100g = "energy-kcal_100g"
        case proteinsServing = "proteins_serving"
        case proteins100g = "proteins_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case carbohydrates100g = "carbohydrates_100g"
        case fatServing = "fat_serving"
        case fat100g = "fat_100g"
        case fiberServing = "fiber_serving"
        case fiber100g = "fiber_100g"
        case sugarsServing = "sugars_serving"
        case sugars100g = "sugars_100g"
        case sodiumServing = "sodium_serving"
        case sodium100g = "sodium_100g"
    }
}

// MARK: - Implementation

final class BarcodeScannerService: BarcodeScannerServiceProtocol {

    // MARK: - Singleton

    static let shared = BarcodeScannerService()

    private init() {}

    // MARK: - Constants

    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private let userAgent = "SwasthiCare-iOS/1.0"

    // MARK: - Local Cache

    private var barcodeCache: [String: FoodItem] = [:]

    // MARK: - Lookup

    func lookupBarcode(_ barcode: String) async throws -> FoodItem? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 8, trimmed.count <= 14 else {
            throw BarcodeLookupError.invalidBarcode
        }

        // Check local cache first
        if let cached = barcodeCache[trimmed] {
            print("🍎 BarcodeScannerService: Cache hit for barcode \(trimmed)")
            return cached
        }

        // Build request
        guard let url = URL(string: "\(baseURL)/\(trimmed).json") else {
            throw BarcodeLookupError.invalidBarcode
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        print("🍎 BarcodeScannerService: Looking up barcode \(trimmed)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BarcodeLookupError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BarcodeLookupError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw BarcodeLookupError.productNotFound
            }
            throw BarcodeLookupError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let offResponse: OpenFoodFactsResponse
        do {
            offResponse = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        } catch {
            print("🍎 BarcodeScannerService: Decode error - \(error.localizedDescription)")
            throw BarcodeLookupError.incompleteData
        }

        // status 0 means product not found in Open Food Facts
        guard offResponse.status == 1, let product = offResponse.product else {
            throw BarcodeLookupError.productNotFound
        }

        guard let foodItem = mapToFoodItem(product: product, barcode: trimmed) else {
            throw BarcodeLookupError.incompleteData
        }

        // Cache the result
        barcodeCache[trimmed] = foodItem
        print("🍎 BarcodeScannerService: Found product '\(foodItem.name)' for barcode \(trimmed)")

        return foodItem
    }

    // MARK: - Mapping

    private func mapToFoodItem(product: OpenFoodFactsProduct, barcode: String) -> FoodItem? {
        guard let name = product.productName, !name.isEmpty else {
            return nil
        }

        let nutriments = product.nutriments

        // Determine serving size: prefer per-serving data, fallback to per-100g
        let hasPerServing = nutriments?.energyKcalServing != nil
        let servingSize: Double
        let servingUnit: ServingUnit

        if hasPerServing, let sq = product.servingQuantity, sq > 0 {
            servingSize = sq
            servingUnit = parseServingUnit(from: product.servingSize)
        } else {
            // Use 100g as default serving
            servingSize = 100
            servingUnit = .g
        }

        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double?
        let sugar: Double?
        let sodium: Double?

        if hasPerServing {
            calories = nutriments?.energyKcalServing ?? 0
            protein = nutriments?.proteinsServing ?? 0
            carbs = nutriments?.carbohydratesServing ?? 0
            fat = nutriments?.fatServing ?? 0
            fiber = nutriments?.fiberServing
            sugar = nutriments?.sugarsServing
            sodium = nutriments?.sodiumServing.map { $0 * 1000 } // Convert g to mg
        } else {
            calories = nutriments?.energyKcal100g ?? 0
            protein = nutriments?.proteins100g ?? 0
            carbs = nutriments?.carbohydrates100g ?? 0
            fat = nutriments?.fat100g ?? 0
            fiber = nutriments?.fiber100g
            sugar = nutriments?.sugars100g
            sodium = nutriments?.sodium100g.map { $0 * 1000 }
        }

        // Must have at least a calorie value to be useful
        guard calories > 0 else {
            return nil
        }

        let category = inferCategory(from: product.categories)
        let isVegetarian = inferVegetarian(from: product.categories)

        return FoodItem(
            name: name.capitalized,
            brand: product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            servingSize: servingSize,
            servingUnit: servingUnit,
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            fiberG: fiber,
            sugarG: sugar,
            sodiumMg: sodium,
            isVegetarian: isVegetarian,
            isVegan: false,
            category: category
        )
    }

    private func parseServingUnit(from servingString: String?) -> ServingUnit {
        guard let s = servingString?.lowercased() else { return .g }
        if s.contains("ml") { return .ml }
        if s.contains("cup") { return .cup }
        if s.contains("tbsp") { return .tbsp }
        if s.contains("tsp") { return .tsp }
        if s.contains("oz") { return .oz }
        if s.contains("piece") || s.contains("pc") || s.contains("unit") { return .piece }
        return .g
    }

    private func inferCategory(from categories: String?) -> FoodCategory {
        guard let cats = categories?.lowercased() else { return .other }
        if cats.contains("beverage") || cats.contains("drink") || cats.contains("juice") || cats.contains("water") { return .beverages }
        if cats.contains("dairy") || cats.contains("milk") || cats.contains("cheese") || cats.contains("yogurt") { return .dairy }
        if cats.contains("fruit") { return .fruits }
        if cats.contains("vegetable") || cats.contains("salad") { return .vegetables }
        if cats.contains("grain") || cats.contains("cereal") || cats.contains("bread") || cats.contains("pasta") || cats.contains("rice") { return .grains }
        if cats.contains("meat") || cats.contains("fish") || cats.contains("chicken") || cats.contains("egg") || cats.contains("protein") { return .protein }
        if cats.contains("snack") || cats.contains("chip") || cats.contains("crisp") { return .snacks }
        if cats.contains("sweet") || cats.contains("chocolate") || cats.contains("candy") || cats.contains("dessert") || cats.contains("cookie") { return .sweets }
        return .other
    }

    private func inferVegetarian(from categories: String?) -> Bool {
        guard let cats = categories?.lowercased() else { return true }
        let nonVegKeywords = ["meat", "chicken", "fish", "seafood", "pork", "beef", "lamb", "mutton", "prawn", "shrimp"]
        return !nonVegKeywords.contains(where: { cats.contains($0) })
    }
}
