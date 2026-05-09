//
//  AddFoodView.swift
//  swastricare-mobile-swift
//
//  Add food to diet log — unified food discovery hub
//

import SwiftUI

struct AddFoodView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    let selectedMealType: MealType

    @State private var searchText = ""
    @State private var currentMealType: MealType
    @State private var showCustomEntry = false
    @State private var showBarcodeScanner = false
    @State private var selectedFoodForQuantity: FoodItem?
    @State private var showCategorySearch = false
    @State private var selectedCategory: FoodCategory?
    @State private var showVegOnly = false
    // Fast Logging state
    @State private var showQuickLogToast = false
    @State private var quickLoggedName = ""

    init(viewModel: DietViewModel, selectedMealType: MealType) {
        self.viewModel = viewModel
        self.selectedMealType = selectedMealType
        self._currentMealType = State(initialValue: selectedMealType)
    }

    // Filtering is active when there's text OR a selected category
    private var isFiltering: Bool {
        !searchText.isEmpty || selectedCategory != nil
    }

    // Filtered + (optional) category-filtered results
    private var searchResults: [FoodItem] {
        var results: [FoodItem] = searchText.isEmpty
            ? viewModel.foodItemsCache
            : viewModel.searchFoods(query: searchText)

        if let cat = selectedCategory {
            results = results.filter { $0.category == cat }
        }
        if showVegOnly {
            results = results.filter { $0.isVegetarian }
        }
        return results
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Always-visible category filter chips (Android style)
                    categoryChipsRow
                        .background(Color.white)

                    Divider().background(Color.primary.opacity(0.06))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if isFiltering {
                                searchResultsSection
                            } else {
                                yourUsualSection

                                if !viewModel.recentFoods.isEmpty {
                                    recentFoodsSection
                                }

                                if !viewModel.favoriteFoods.isEmpty {
                                    favoriteFoodsSection
                                }

                                scanBarcodeButton

                                customFoodButton

                                allFoodsSection
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        // Barcode scanner button (from Discovery branch)
                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.poppins(.medium, size: 18))
                                .foregroundColor(AppColors.aiTeal)
                        }

                        // Meal type pill with semantic color tint
                        HStack(spacing: 4) {
                            Image(systemName: currentMealType.icon)
                                .font(.poppins(.semiBold, size: 11))
                            Text(currentMealType.displayName)
                                .font(.poppins(.semiBold, size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(currentMealType.color.opacity(0.15))
                        .foregroundColor(currentMealType.color)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(currentMealType.color.opacity(0.30), lineWidth: 0.8)
                        )
                    }
                }
            }
            .sheet(item: $selectedFoodForQuantity) { food in
                FoodQuantitySheet(
                    viewModel: viewModel,
                    food: food,
                    mealType: currentMealType,
                    onLog: { dismiss() }
                )
            }
            .sheet(isPresented: $showCategorySearch) {
                FoodSearchView(
                    viewModel: viewModel,
                    selectedMealType: currentMealType,
                    onFoodSelected: { food in
                        showCategorySearch = false
                        selectedFoodForQuantity = food
                    }
                )
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(
                    viewModel: viewModel,
                    mealType: currentMealType
                )
            }
            .sheet(isPresented: $showCustomEntry) {
                CustomFoodEntryView(
                    viewModel: viewModel,
                    selectedMealType: currentMealType,
                    onSave: { dismiss() }
                )
            }
            .onAppear {
                viewModel.refreshSuggestions(for: currentMealType)
            }
            .overlay(alignment: .bottom) {
                if showQuickLogToast {
                    quickLogToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
        }
        .trackScreen("AddFood")
    }

    // MARK: - Category Filter Chips (Android-style, always visible)

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: "All", icon: nil, isSelected: selectedCategory == nil) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedCategory = nil
                    }
                }
                ForEach(FoodCategory.allCases) { cat in
                    categoryChip(label: cat.displayName, icon: cat.icon, isSelected: selectedCategory == cat) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func categoryChip(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Text(icon).font(.poppins(.regular, size: 12)) }
                Text(label)
                    .font(.poppins(.medium, size: 14))
                    .foregroundColor(isSelected ? AppColors.aiTeal : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.aiTeal.opacity(0.15) : Color(hex: "F6F7F9"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Foods Section

    private var recentFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(AppColors.aiTeal)
                Text("Recent")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.recentFoods) { food in
                        Button {
                            selectedFoodForQuantity = food
                        } label: {
                            HStack(spacing: 6) {
                                Text(food.category.icon)
                                    .font(.poppins(.regular, size: 14))
                                VegIndicator(isVegetarian: food.isVegetarian)
                                Text(food.name)
                                    .font(.poppins(.medium, size: 14))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppColors.aiTeal.opacity(0.08))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.aiTeal.opacity(0.20), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Favorites Section

    private var favoriteFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.poppins(.semiBold, size: 13))
                    .foregroundColor(.pink)
                Text("Favorites")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.favoriteFoods) { food in
                        Button {
                            selectedFoodForQuantity = food
                        } label: {
                            HStack(spacing: 6) {
                                Text(food.category.icon)
                                    .font(.poppins(.regular, size: 14))
                                Text(food.name)
                                    .font(.poppins(.medium, size: 14))
                                    .lineLimit(1)
                                Image(systemName: "heart.fill")
                                    .font(.poppins(.regular, size: 10))
                                    .foregroundColor(.pink)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.pink.opacity(0.08))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.pink.opacity(0.20), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Category Grid Section

    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Category")
                .font(.poppins(.semiBold, size: 15))
                .foregroundColor(.secondary)
                .padding(.horizontal)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(FoodCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        showCategorySearch = true
                    } label: {
                        VStack(spacing: 8) {
                            Text(category.icon)
                                .font(.poppins(.regular, size: 36))
                            Text(category.displayName)
                                .font(.poppins(.medium, size: 13))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.poppins(.regular, size: 40))
                        .foregroundColor(.secondary)
                    Text("No foods found")
                        .font(.poppins(.medium, size: 16))
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                HStack(spacing: 10) {
                    Text("\(searchResults.count) results")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Veg Only toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showVegOnly.toggle()
                        }
                    }) {
                        HStack(spacing: 5) {
                            VegIndicator(isVegetarian: true)
                            Text("Veg Only")
                                .font(.poppins(.medium, size: 13))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(showVegOnly ? Color.green : Color.green.opacity(0.08))
                        .foregroundColor(showVegOnly ? .white : .primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(showVegOnly ? Color.clear : Color.green.opacity(0.25), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    ForEach(searchResults) { food in
                        Button {
                            selectedFoodForQuantity = food
                        } label: {
                            HStack(spacing: 12) {
                                Text(food.category.icon)
                                    .font(.poppins(.regular, size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(AppColors.aiTeal.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(AppColors.aiTeal.opacity(0.15), lineWidth: 0.8)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        VegIndicator(isVegetarian: food.isVegetarian)
                                        Text(food.name)
                                            .font(.poppins(.medium, size: 15))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 6) {
                                        Text(food.displayServingSize)
                                            .font(.poppins(.regular, size: 12))
                                            .foregroundColor(.secondary)
                                        Text("\u{00B7}")
                                            .foregroundColor(.secondary)
                                        Text(food.caloriesPerServing)
                                            .font(.poppins(.semiBold, size: 12))
                                            .foregroundColor(AppColors.aiTeal)
                                    }
                                }

                                Spacer()

                                Button {
                                    selectedFoodForQuantity = food
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.poppins(.regular, size: 22))
                                        .foregroundColor(AppColors.aiTeal)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - All Foods Section (full catalog browse, mirrors Android)

    @ViewBuilder
    private var allFoodsSection: some View {
        let foods = viewModel.foodItemsCache
        if !foods.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("All Foods")
                    .font(.poppins(.semiBold, size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

                VStack(spacing: 6) {
                    ForEach(foods) { food in
                        Button {
                            selectedFoodForQuantity = food
                        } label: {
                            HStack(spacing: 12) {
                                Text(food.category.icon)
                                    .font(.poppins(.regular, size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(AppColors.aiTeal.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(AppColors.aiTeal.opacity(0.15), lineWidth: 0.8)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        VegIndicator(isVegetarian: food.isVegetarian)
                                        Text(food.name)
                                            .font(.poppins(.medium, size: 15))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 6) {
                                        Text(food.displayServingSize)
                                            .font(.poppins(.regular, size: 12))
                                            .foregroundColor(.secondary)
                                        Text("\u{00B7}")
                                            .foregroundColor(.secondary)
                                        Text(food.caloriesPerServing)
                                            .font(.poppins(.semiBold, size: 12))
                                            .foregroundColor(AppColors.aiTeal)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.poppins(.regular, size: 22))
                                    .foregroundColor(AppColors.aiTeal)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Your Usual Section (from Fast Logging branch)

    @ViewBuilder
    private var yourUsualSection: some View {
        let suggestions = viewModel.suggestedFoods
        let templates = viewModel.templates(for: currentMealType)

        if !suggestions.isEmpty || !templates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundColor(AppColors.accentBlue)
                    Text("Your Usual \(currentMealType.displayName)")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Suggested foods -- one-tap quick log
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions) { food in
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    quickLoggedName = food.name
                                    Task {
                                        await viewModel.quickLogFood(food, mealType: currentMealType)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            showQuickLogToast = true
                                        }
                                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                                        withAnimation {
                                            showQuickLogToast = false
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(food.category.icon)
                                            .font(.poppins(.regular, size: 24))

                                        Text(food.name)
                                            .font(.poppins(.medium, size: 12))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)

                                        Text("\(Int(food.calories)) cal")
                                            .font(.poppins(.semiBold, size: 11))
                                            .foregroundColor(AppColors.aiTeal)
                                    }
                                    .frame(width: 80, height: 90)
                                    .background(AppColors.accentBlue.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.accentBlue.opacity(0.15), lineWidth: 0.8)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Saved templates with "Log all" button
                if !templates.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(templates) { template in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(template.mealType.color.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "doc.text.fill")
                                        .font(.poppins(.medium, size: 16))
                                        .foregroundColor(template.mealType.color)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.poppins(.medium, size: 15))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(template.summary)
                                        .font(.poppins(.regular, size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task {
                                        await viewModel.logTemplate(template)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        dismiss()
                                    }
                                } label: {
                                    Text("Log all")
                                        .font(.poppins(.semiBold, size: 13))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(AppColors.aiTeal)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Log Toast (from Fast Logging branch)

    private var quickLogToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.poppins(.medium, size: 18))
                .foregroundColor(AppColors.aiTeal)

            Text("Logged \(quickLoggedName)")
                .font(.poppins(.medium, size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Scan Barcode Button (from Discovery branch)

    private var scanBarcodeButton: some View {
        Button {
            showBarcodeScanner = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentBlue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "barcode.viewfinder")
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(AppColors.accentBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Barcode")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(AppColors.accentBlue)
                    Text("Scan packaged food products")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(AppColors.accentBlue.opacity(0.6))
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal)
    }

    // MARK: - Custom Food Button

    private var customFoodButton: some View {
        Button {
            showCustomEntry = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.aiTeal)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(.white)
                }
                Text("Add Custom Food")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(AppColors.aiTeal)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(AppColors.aiTeal.opacity(0.6))
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal)
    }
}

// MARK: - Food Quantity Sheet

struct FoodQuantitySheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    let food: FoodItem
    let mealType: MealType
    let onLog: () -> Void

    @State private var quantity: Double = 1.0
    @State private var isLogging = false
    @State private var showKeyboardInput = false
    @State private var keyboardQuantityText = "1"
    @FocusState private var isKeyboardFocused: Bool

    private var adjustedCalories: Int { Int(food.calories * quantity) }
    private var adjustedProtein: Int { Int(food.proteinG * quantity) }
    private var adjustedCarbs: Int { Int(food.carbsG * quantity) }
    private var adjustedFat: Int { Int(food.fatG * quantity) }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Food header
                    foodHeader

                    // Quantity stepper
                    quantityStepper

                    // Nutrition preview
                    nutritionPreview

                    Spacer()

                    // Log Food button
                    logButton
                }
                .padding()
                .padding(.top, 8)
            }
            .navigationTitle("Adjust Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Food Header

    private var foodHeader: some View {
        HStack(spacing: 14) {
            Text(food.category.icon)
                .font(.poppins(.regular, size: 40))
                .frame(width: 60, height: 60)
                .background(AppColors.aiTeal.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.aiTeal.opacity(0.20), lineWidth: 0.8)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.poppins(.semiBold, size: 18))
                    .lineLimit(2)

                Text(food.displayServingSize + " per serving")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Heart toggle
            Button {
                viewModel.toggleFavorite(foodId: food.id)
            } label: {
                Image(systemName: viewModel.isFavorite(foodId: food.id) ? "heart.fill" : "heart")
                    .font(.poppins(.regular, size: 22))
                    .foregroundColor(viewModel.isFavorite(foodId: food.id) ? .pink : .secondary)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Quantity Stepper

    private var quantityStepper: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Servings")
                    .font(.poppins(.medium, size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                // Toggle keyboard input
                Button {
                    showKeyboardInput.toggle()
                    if showKeyboardInput {
                        keyboardQuantityText = quantity.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(quantity))"
                            : String(format: "%.2f", quantity)
                        isKeyboardFocused = true
                    } else {
                        if let parsed = Double(keyboardQuantityText), parsed > 0, parsed <= 20 {
                            quantity = parsed
                        }
                        isKeyboardFocused = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showKeyboardInput ? "minus.circle.fill" : "keyboard")
                            .font(.poppins(.medium, size: 12))
                        Text(showKeyboardInput ? "Use Stepper" : "Type Amount")
                            .font(.poppins(.medium, size: 12))
                    }
                    .foregroundColor(AppColors.accentBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.accentBlue.opacity(0.10))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            if showKeyboardInput {
                // Keyboard input mode
                HStack(spacing: 8) {
                    TextField("1.0", text: $keyboardQuantityText)
                        .keyboardType(.decimalPad)
                        .font(.poppins(.bold, size: 36))
                        .multilineTextAlignment(.center)
                        .focused($isKeyboardFocused)
                        .onChange(of: keyboardQuantityText) { _, newValue in
                            if let parsed = Double(newValue), parsed > 0, parsed <= 20 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    quantity = parsed
                                }
                            }
                        }
                        .frame(maxWidth: 120)

                    Text("servings")
                        .font(.poppins(.medium, size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                // Quick amount chips
                HStack(spacing: 8) {
                    ForEach([0.25, 0.5, 1.0, 1.5, 2.0], id: \.self) { amount in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            quantity = amount
                            keyboardQuantityText = amount.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(amount))"
                                : String(format: "%.2g", amount)
                        } label: {
                            Text(amount.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(amount))"
                                : String(format: "%.2g", amount))
                                .font(.poppins(.semiBold, size: 14))
                                .foregroundColor(quantity == amount ? .white : AppColors.aiTeal)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(quantity == amount ? AppColors.aiTeal : AppColors.aiTeal.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }
            } else {
                // Stepper mode (now with 0.25 increments)
                HStack(spacing: 24) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if quantity > 0.25 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                quantity = max(0.25, quantity - 0.25)
                                quantity = (quantity * 4).rounded() / 4 // snap to 0.25
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(quantity > 0.25 ? AppColors.aiTeal.opacity(0.15) : Color.secondary.opacity(0.08))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .stroke(quantity > 0.25 ? AppColors.aiTeal.opacity(0.30) : Color.clear, lineWidth: 1)
                                )
                            Image(systemName: "minus")
                                .font(.poppins(.semiBold, size: 18))
                                .foregroundColor(quantity > 0.25 ? AppColors.aiTeal : .secondary.opacity(0.4))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(quantity <= 0.25)

                    Text(formatQuantity(quantity))
                        .font(.poppins(.bold, size: 40))
                        .foregroundColor(.primary)
                        .frame(minWidth: 60)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: quantity)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if quantity < 10 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                quantity += 0.25
                                quantity = (quantity * 4).rounded() / 4 // snap to 0.25
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(quantity < 10 ? AppColors.aiTeal.opacity(0.15) : Color.secondary.opacity(0.08))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .stroke(quantity < 10 ? AppColors.aiTeal.opacity(0.30) : Color.clear, lineWidth: 1)
                                )
                            Image(systemName: "plus")
                                .font(.poppins(.semiBold, size: 18))
                                .foregroundColor(quantity < 10 ? AppColors.aiTeal : .secondary.opacity(0.4))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(quantity >= 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else if (value * 4).truncatingRemainder(dividingBy: 1) == 0 {
            // Show as fraction-like: 0.25, 0.5, 0.75
            return String(format: "%.2g", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Nutrition Preview

    private var nutritionPreview: some View {
        HStack(spacing: 10) {
            nutritionPill(label: "Cal", value: "\(adjustedCalories)", color: AppColors.accentOrange)
            nutritionPill(label: "Protein", value: "\(adjustedProtein)g", color: AppColors.accentRed)
            nutritionPill(label: "Carbs", value: "\(adjustedCarbs)g", color: AppColors.accentBlue)
            nutritionPill(label: "Fat", value: "\(adjustedFat)g", color: AppColors.accentYellow)
        }
    }

    private func nutritionPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.poppins(.bold, size: 16))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: quantity)
            Text(label)
                .font(.poppins(.medium, size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.20), lineWidth: 0.8)
        )
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isLogging = true
            Task {
                await viewModel.logFood(
                    item: food,
                    quantity: food.servingSize * quantity,
                    mealType: mealType
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isLogging = false
                onLog()
            }
        } label: {
            HStack(spacing: 8) {
                if isLogging {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.poppins(.regular, size: 18))
                }
                Text("Log Food")
                    .font(.poppins(.semiBold, size: 17))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLogging ? AppColors.aiTeal.opacity(0.6) : AppColors.aiTeal)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLogging)
    }
}

#Preview {
    AddFoodView(viewModel: DietViewModel(), selectedMealType: .breakfast)
}
