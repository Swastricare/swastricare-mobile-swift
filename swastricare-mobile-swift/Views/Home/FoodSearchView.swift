//
//  FoodSearchView.swift
//  swastricare-mobile-swift
//
//  Search and select food from database
//

import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    let selectedMealType: MealType
    let onFoodSelected: (FoodItem) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory? = nil

    private var filteredFoods: [FoodItem] {
        var foods = viewModel.foodItemsCache

        // Filter by search text
        if !searchText.isEmpty {
            foods = viewModel.searchFoods(query: searchText)
        }

        // Filter by category
        if let category = selectedCategory {
            foods = foods.filter { $0.category == category }
        }

        return foods
    }

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category Filter
                    categoryFilter

                    // Search Results
                    if filteredFoods.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredFoods) { food in
                                    FoodItemRow(
                                        food: food,
                                        onSelect: { onFoodSelected(food) },
                                        isFavorite: viewModel.isFavorite(foodId: food.id),
                                        onToggleFavorite: { viewModel.toggleFavorite(foodId: food.id) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Search Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods...")
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All category
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = nil
                    }
                }) {
                    Text("All")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil
                                ? AppColors.accentGreen
                                : AppColors.accentGreen.opacity(0.07)
                        )
                        .foregroundColor(
                            selectedCategory == nil ? .white : .primary
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selectedCategory == nil
                                        ? Color.clear
                                        : AppColors.accentGreen.opacity(0.10),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                ForEach(FoodCategory.allCases) { category in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(category.icon)
                                .font(.system(size: 12))

                            Text(category.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                                ? AppColors.accentGreen
                                : AppColors.accentGreen.opacity(0.07)
                        )
                        .foregroundColor(
                            selectedCategory == category ? .white : .primary
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selectedCategory == category
                                        ? Color.clear
                                        : AppColors.accentGreen.opacity(0.10),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppColors.accentGreen.opacity(0.10))
                    .frame(width: 100, height: 100)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(AppColors.accentGreen)
            }

            VStack(spacing: 8) {
                Text("No foods found")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                if !searchText.isEmpty {
                    Text("Try a different search term")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("Search above to discover foods")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

struct FoodItemRow: View {
    let food: FoodItem
    let onSelect: () -> Void
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Category icon with green tint container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accentGreen.opacity(0.07))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accentGreen.opacity(0.10), lineWidth: 1)
                        )

                    Text(food.category.icon)
                        .font(.system(size: 28))
                }

                // Food details
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    if let brand = food.brand {
                        Text(brand)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(food.displayServingSize)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(food.caloriesPerServing)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.accentGreen)
                    }

                    Text(food.macroSummary)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Favorite toggle
                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(isFavorite ? AppColors.accentRed : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Plus button with filled circle background
                    ZStack {
                        Circle()
                            .fill(AppColors.accentGreen)
                            .frame(width: 30, height: 30)

                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
        .glass(cornerRadius: 16)
    }
}

// MARK: - Custom Food Entry

struct CustomFoodEntryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    let selectedMealType: MealType
    let onSave: () -> Void

    @State private var foodName = ""
    @State private var quantity = ""
    @State private var selectedUnit: ServingUnit = .g
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Food Details") {
                    TextField("Food name", text: $foodName)

                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(ServingUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Nutrition (per serving)") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("g")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("g")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveCustomFood()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !foodName.isEmpty &&
        !quantity.isEmpty &&
        !calories.isEmpty &&
        Double(quantity) != nil &&
        Double(calories) != nil
    }

    private func saveCustomFood() {
        guard let quantityValue = Double(quantity),
              let caloriesValue = Double(calories) else {
            return
        }

        let proteinValue = Double(protein) ?? 0
        let carbsValue = Double(carbs) ?? 0
        let fatValue = Double(fat) ?? 0

        Task {
            await viewModel.logCustomFood(
                name: foodName,
                mealType: selectedMealType,
                quantity: quantityValue,
                servingUnit: selectedUnit,
                calories: caloriesValue,
                proteinG: proteinValue,
                carbsG: carbsValue,
                fatG: fatValue
            )
            onSave()
        }
    }
}

#Preview {
    FoodSearchView(
        viewModel: DietViewModel(),
        selectedMealType: .breakfast,
        onFoodSelected: { _ in }
    )
}
