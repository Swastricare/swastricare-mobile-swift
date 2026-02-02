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
            VStack(spacing: 0) {
                // Category Filter
                categoryFilter
                
                // Search Results
                if filteredFoods.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredFoods) { food in
                            FoodItemRow(food: food) {
                                onFoodSelected(food)
                            }
                        }
                    }
                    .listStyle(.plain)
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
                    selectedCategory = nil
                }) {
                    Text("All")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil ?
                            Color.green.opacity(0.15) :
                            Color(UIColor.tertiarySystemBackground)
                        )
                        .foregroundColor(
                            selectedCategory == nil ?
                            .green :
                            .primary
                        )
                        .cornerRadius(16)
                }
                
                ForEach(FoodCategory.allCases) { category in
                    Button(action: {
                        selectedCategory = category
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
                            selectedCategory == category ?
                            Color.green.opacity(0.15) :
                            Color(UIColor.tertiarySystemBackground)
                        )
                        .foregroundColor(
                            selectedCategory == category ?
                            .green :
                            .primary
                        )
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No foods found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FoodItemRow: View {
    let food: FoodItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Category icon
                Text(food.category.icon)
                    .font(.system(size: 32))
                    .frame(width: 50, height: 50)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                
                // Food details
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 16, weight: .medium))
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    Text(food.macroSummary)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Add button
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
