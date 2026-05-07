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
    @State private var showVegOnly = false
    @State private var lastSearchTrigger = ""

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

        // Filter by veg only
        if showVegOnly {
            foods = foods.filter { $0.isVegetarian }
        }

        return foods
    }

    /// Online results filtered by category and veg-only setting
    private var filteredOnlineResults: [FoodItem] {
        var foods = viewModel.onlineSearchResults

        if let category = selectedCategory {
            foods = foods.filter { $0.category == category }
        }
        if showVegOnly {
            foods = foods.filter { $0.isVegetarian }
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
                    if filteredFoods.isEmpty && filteredOnlineResults.isEmpty && !viewModel.isSearchingOnline {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Local results
                                ForEach(filteredFoods) { food in
                                    FoodItemRow(
                                        food: food,
                                        onSelect: { onFoodSelected(food) },
                                        isFavorite: viewModel.isFavorite(foodId: food.id),
                                        onToggleFavorite: { viewModel.toggleFavorite(foodId: food.id) }
                                    )
                                }

                                // Online search indicator
                                if viewModel.isSearchingOnline {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(AppColors.accentBlue)
                                        Text("Searching online...")
                                            .font(.poppins(.medium, size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }

                                // Online results section
                                if !filteredOnlineResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "globe")
                                                .font(.poppins(.semiBold, size: 12))
                                                .foregroundColor(AppColors.accentBlue)
                                            Text("From Database")
                                                .font(.poppins(.semiBold, size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 8)
                                    }

                                    ForEach(filteredOnlineResults) { food in
                                        FoodItemRow(
                                            food: food,
                                            onSelect: { onFoodSelected(food) },
                                            isFavorite: viewModel.isFavorite(foodId: food.id),
                                            onToggleFavorite: { viewModel.toggleFavorite(foodId: food.id) }
                                        )
                                    }
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
            .onChange(of: searchText) { _, newValue in
                // Trigger online search when local results are sparse
                viewModel.searchFoodsOnline(query: newValue)
                AppAnalyticsService.shared.logFoodSearched(
                    queryLength: newValue.count,
                    resultsCount: filteredFoods.count
                )
            }
        }
        .trackScreen("FoodSearch")
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
                        .font(.poppins(.medium, size: 14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil
                                ? AppColors.aiTeal
                                : AppColors.aiTeal.opacity(0.07)
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
                                        : AppColors.aiTeal.opacity(0.10),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                // Veg Only toggle pill
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showVegOnly.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        VegIndicator(isVegetarian: true)
                        Text("Veg Only")
                            .font(.poppins(.medium, size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        showVegOnly
                            ? Color.green
                            : Color.green.opacity(0.07)
                    )
                    .foregroundColor(
                        showVegOnly ? .white : .primary
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                showVegOnly
                                    ? Color.clear
                                    : Color.green.opacity(0.20),
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
                                .font(.poppins(.regular, size: 12))

                            Text(category.displayName)
                                .font(.poppins(.medium, size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                                ? AppColors.aiTeal
                                : AppColors.aiTeal.opacity(0.07)
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
                                        : AppColors.aiTeal.opacity(0.10),
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
                    .fill(AppColors.aiTeal.opacity(0.10))
                    .frame(width: 100, height: 100)

                Image(systemName: "magnifyingglass")
                    .font(.poppins(.light, size: 44))
                    .foregroundColor(AppColors.aiTeal)
            }

            VStack(spacing: 8) {
                Text("No foods found")
                    .font(.poppins(.semiBold, size: 20))
                    .foregroundColor(.primary)

                if !searchText.isEmpty {
                    Text("Try a different search term")
                        .font(.poppins(.regular, size: 15))
                        .foregroundColor(.secondary)
                } else {
                    Text("Search above to discover foods")
                        .font(.poppins(.regular, size: 15))
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
                        .fill(AppColors.aiTeal.opacity(0.07))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.aiTeal.opacity(0.10), lineWidth: 1)
                        )

                    Text(food.category.icon)
                        .font(.poppins(.regular, size: 28))
                }

                // Food details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        VegIndicator(isVegetarian: food.isVegetarian)
                        Text(food.name)
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.primary)
                    }

                    if let brand = food.brand {
                        Text(brand)
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(food.displayServingSize)
                            .font(.poppins(.regular, size: 13))
                            .foregroundColor(.secondary)

                        Text("\u{2022}")
                            .foregroundColor(.secondary)

                        Text(food.caloriesPerServing)
                            .font(.poppins(.bold, size: 13))
                            .foregroundColor(AppColors.aiTeal)
                    }

                    Text(food.macroSummary)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Favorite toggle
                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.poppins(.regular, size: 18))
                                .foregroundColor(isFavorite ? AppColors.accentRed : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Plus button with filled circle background
                    ZStack {
                        Circle()
                            .fill(AppColors.aiTeal)
                            .frame(width: 30, height: 30)

                        Image(systemName: "plus")
                            .font(.poppins(.bold, size: 14))
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

// MARK: - Veg/Non-Veg Indicator (FSSAI standard)

struct VegIndicator: View {
    let isVegetarian: Bool

    private var color: Color {
        isVegetarian ? AppColors.aiTeal : AppColors.accentRed
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(color, lineWidth: 1.5)
                .frame(width: 14, height: 14)
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
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
