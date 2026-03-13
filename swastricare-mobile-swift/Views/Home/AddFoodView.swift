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
    @State private var selectedFoodForQuantity: FoodItem?
    @State private var showCategorySearch = false
    @State private var selectedCategory: FoodCategory?
    @State private var showFoodSnap = false

    init(viewModel: DietViewModel, selectedMealType: MealType) {
        self.viewModel = viewModel
        self.selectedMealType = selectedMealType
        self._currentMealType = State(initialValue: selectedMealType)
    }

    // Filtered search results
    private var searchResults: [FoodItem] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.searchFoods(query: searchText)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Show search results when searching
                    if !searchText.isEmpty {
                        searchResultsSection
                    } else {
                        // Recent Foods (if any)
                        if !viewModel.recentFoods.isEmpty {
                            recentFoodsSection
                        }

                        // Favorites (if any)
                        if !viewModel.favoriteFoods.isEmpty {
                            favoriteFoodsSection
                        }

                        // AI Food Snap (prominent feature)
                        snapFoodButton

                        // Browse by Category
                        categoryGridSection

                        // Add Custom Food
                        customFoodButton
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Meal type pill
                    HStack(spacing: 4) {
                        Image(systemName: currentMealType.icon)
                            .font(.system(size: 11))
                        Text(currentMealType.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(currentMealType.color.opacity(0.15))
                    .foregroundColor(currentMealType.color)
                    .cornerRadius(12)
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
            .sheet(isPresented: $showCustomEntry) {
                CustomFoodEntryView(
                    viewModel: viewModel,
                    selectedMealType: currentMealType,
                    onSave: { dismiss() }
                )
            }
            .fullScreenCover(isPresented: $showFoodSnap) {
                FoodSnapView(viewModel: viewModel, suggestedMealType: currentMealType)
            }
        }
    }

    // MARK: - Recent Foods Section

    private var recentFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Recent")
                    .font(.system(size: 15, weight: .semibold))
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
                                    .font(.system(size: 14))
                                Text(food.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.pink)
                Text("Favorites")
                    .font(.system(size: 15, weight: .semibold))
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
                                    .font(.system(size: 14))
                                Text(food.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.pink)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.pink.opacity(0.08))
                            .foregroundColor(.primary)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Snap Food Button

    private var snapFoodButton: some View {
        Button {
            showFoodSnap = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Snap Food")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }

                    Text("AI-powered nutrition detection")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Category Grid Section

    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Category")
                .font(.system(size: 15, weight: .semibold))
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
                                .font(.system(size: 32))
                            Text(category.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
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
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No foods found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                Text("\(searchResults.count) results")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(searchResults) { food in
                        Button {
                            selectedFoodForQuantity = food
                        } label: {
                            HStack(spacing: 12) {
                                Text(food.category.icon)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(10)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(food.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Text(food.displayServingSize)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        Text("·")
                                            .foregroundColor(.secondary)
                                        Text(food.caloriesPerServing)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.green)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if food.id != searchResults.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Custom Food Button

    private var customFoodButton: some View {
        Button {
            showCustomEntry = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                Text("Add Custom Food")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    private var adjustedCalories: Int { Int(food.calories * quantity) }
    private var adjustedProtein: Int { Int(food.proteinG * quantity) }
    private var adjustedCarbs: Int { Int(food.carbsG * quantity) }
    private var adjustedFat: Int { Int(food.fatG * quantity) }

    var body: some View {
        NavigationView {
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
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(Color.green.opacity(0.1))
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(2)

                Text(food.displayServingSize + " per serving")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Heart toggle
            Button {
                viewModel.toggleFavorite(foodId: food.id)
            } label: {
                Image(systemName: viewModel.isFavorite(foodId: food.id) ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.isFavorite(foodId: food.id) ? .pink : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quantity Stepper

    private var quantityStepper: some View {
        VStack(spacing: 8) {
            Text("Servings")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                Button {
                    if quantity > 0.5 {
                        quantity -= 0.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(quantity > 0.5 ? .green : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(quantity <= 0.5)

                Text(quantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(quantity))" : String(format: "%.1f", quantity))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(minWidth: 60)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: quantity)

                Button {
                    if quantity < 10 {
                        quantity += 0.5
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(quantity < 10 ? .green : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(quantity >= 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Nutrition Preview

    private var nutritionPreview: some View {
        HStack(spacing: 10) {
            nutritionPill(label: "Cal", value: "\(adjustedCalories)", color: .orange)
            nutritionPill(label: "Protein", value: "\(adjustedProtein)g", color: .red)
            nutritionPill(label: "Carbs", value: "\(adjustedCarbs)g", color: .blue)
            nutritionPill(label: "Fat", value: "\(adjustedFat)g", color: .yellow)
        }
    }

    private func nutritionPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: quantity)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            isLogging = true
            Task {
                await viewModel.logFood(
                    item: food,
                    quantity: food.servingSize * quantity,
                    mealType: mealType
                )
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
                        .font(.system(size: 18))
                }
                Text("Log Food")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLogging ? Color.green.opacity(0.6) : Color.green)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(isLogging)
    }
}

#Preview {
    AddFoodView(viewModel: DietViewModel(), selectedMealType: .breakfast)
}
