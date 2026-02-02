//
//  AddFoodView.swift
//  swastricare-mobile-swift
//
//  Add food to diet log
//

import SwiftUI

struct AddFoodView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    let selectedMealType: MealType
    
    @State private var showSearch = false
    @State private var showCustomEntry = false
    @State private var selectedFood: FoodItem?
    @State private var quantity: String = "1"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Meal Type Selector
                mealTypeSelector
                
                // Quick Actions
                VStack(spacing: 16) {
                    Button(action: { showSearch = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Search Food Database")
                                    .font(.system(size: 17, weight: .semibold))
                                
                                Text("Find from \(viewModel.foodItemsCache.count) items")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showCustomEntry = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Custom Food")
                                    .font(.system(size: 17, weight: .semibold))
                                
                                Text("Enter nutrition manually")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                FoodSearchView(
                    viewModel: viewModel,
                    selectedMealType: selectedMealType,
                    onFoodSelected: { food in
                        selectedFood = food
                        showSearch = false
                        // Could show quantity picker here
                        Task {
                            await viewModel.logFood(
                                item: food,
                                quantity: food.servingSize,
                                mealType: selectedMealType
                            )
                            dismiss()
                        }
                    }
                )
            }
            .sheet(isPresented: $showCustomEntry) {
                CustomFoodEntryView(
                    viewModel: viewModel,
                    selectedMealType: selectedMealType,
                    onSave: {
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Meal Type Selector
    
    @State private var currentMealType: MealType
    
    init(viewModel: DietViewModel, selectedMealType: MealType) {
        self.viewModel = viewModel
        self.selectedMealType = selectedMealType
        self._currentMealType = State(initialValue: selectedMealType)
    }
    
    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Meal")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MealType.allCases) { mealType in
                        Button(action: {
                            currentMealType = mealType
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mealType.icon)
                                    .font(.system(size: 14))
                                
                                Text(mealType.displayName)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                currentMealType == mealType ?
                                mealType.color.opacity(0.15) :
                                Color(UIColor.tertiarySystemBackground)
                            )
                            .foregroundColor(
                                currentMealType == mealType ?
                                mealType.color :
                                .primary
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        currentMealType == mealType ?
                                        mealType.color :
                                        Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    AddFoodView(viewModel: DietViewModel(), selectedMealType: .breakfast)
}
