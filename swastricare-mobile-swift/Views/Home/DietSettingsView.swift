//
//  DietSettingsView.swift
//  swastricare-mobile-swift
//
//  Diet goals and preferences configuration
//

import SwiftUI

struct DietSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    
    @State private var dailyCalories: Double
    @State private var proteinPercent: Double
    @State private var carbsPercent: Double
    @State private var fatPercent: Double
    @State private var mealRemindersEnabled: Bool
    
    init(viewModel: DietViewModel) {
        self.viewModel = viewModel
        _dailyCalories = State(initialValue: Double(viewModel.dietGoals.dailyCalories))
        _proteinPercent = State(initialValue: Double(viewModel.dietGoals.proteinPercent))
        _carbsPercent = State(initialValue: Double(viewModel.dietGoals.carbsPercent))
        _fatPercent = State(initialValue: Double(viewModel.dietGoals.fatPercent))
        _mealRemindersEnabled = State(initialValue: viewModel.dietGoals.mealRemindersEnabled)
    }
    
    private var totalPercent: Int {
        Int(proteinPercent + carbsPercent + fatPercent)
    }
    
    private var isValidMacroSplit: Bool {
        totalPercent == 100
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Calorie Goal Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daily Calorie Goal")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(dailyCalories)) cal")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Slider(value: $dailyCalories, in: 1200...4000, step: 50)
                            .tint(.green)
                        
                        HStack {
                            Text("1200")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("4000")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Calorie Target")
                } footer: {
                    Text("Your daily calorie goal based on your activity level and goals")
                }
                
                // Macro Split Section
                Section {
                    VStack(alignment: .leading, spacing: 20) {
                        // Protein
                        macroSlider(
                            label: "Protein",
                            value: $proteinPercent,
                            color: .orange,
                            grams: calculateGrams(percent: proteinPercent, caloriesPerGram: 4)
                        )
                        
                        // Carbs
                        macroSlider(
                            label: "Carbs",
                            value: $carbsPercent,
                            color: .blue,
                            grams: calculateGrams(percent: carbsPercent, caloriesPerGram: 4)
                        )
                        
                        // Fat
                        macroSlider(
                            label: "Fat",
                            value: $fatPercent,
                            color: .purple,
                            grams: calculateGrams(percent: fatPercent, caloriesPerGram: 9)
                        )
                        
                        // Total validation
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text("\(totalPercent)%")
                                .font(.headline)
                                .foregroundColor(isValidMacroSplit ? .green : .red)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Macro Distribution")
                } footer: {
                    if !isValidMacroSplit {
                        Text("⚠️ Macro percentages must total 100%")
                            .foregroundColor(.red)
                    } else {
                        Text("Protein: \(calculateGrams(percent: proteinPercent, caloriesPerGram: 4))g • Carbs: \(calculateGrams(percent: carbsPercent, caloriesPerGram: 4))g • Fat: \(calculateGrams(percent: fatPercent, caloriesPerGram: 9))g")
                    }
                }
                
                // Preset Macro Splits
                Section("Quick Presets") {
                    Button(action: { applyPreset(.balanced) }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Balanced")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("25% P • 50% C • 25% F")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    Button(action: { applyPreset(.highProtein) }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("High Protein")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("35% P • 40% C • 25% F")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    Button(action: { applyPreset(.lowCarb) }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Low Carb")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("30% P • 30% C • 40% F")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Reminders Section
                Section {
                    Toggle("Meal Reminders", isOn: $mealRemindersEnabled)
                } footer: {
                    Text("Get notified to log your meals throughout the day")
                }
            }
            .navigationTitle("Diet Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveGoals()
                    }
                    .disabled(!isValidMacroSplit)
                }
            }
        }
    }
    
    // MARK: - Macro Slider
    
    private func macroSlider(label: String, value: Binding<Double>, color: Color, grams: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(value.wrappedValue))% (\(grams)g)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            Slider(value: value, in: 0...100, step: 5)
                .tint(color)
        }
    }
    
    // MARK: - Helpers
    
    private func calculateGrams(percent: Double, caloriesPerGram: Double) -> Int {
        let calories = dailyCalories * (percent / 100.0)
        return Int(calories / caloriesPerGram)
    }
    
    private enum MacroPreset {
        case balanced
        case highProtein
        case lowCarb
    }
    
    private func applyPreset(_ preset: MacroPreset) {
        withAnimation {
            switch preset {
            case .balanced:
                proteinPercent = 25
                carbsPercent = 50
                fatPercent = 25
            case .highProtein:
                proteinPercent = 35
                carbsPercent = 40
                fatPercent = 25
            case .lowCarb:
                proteinPercent = 30
                carbsPercent = 30
                fatPercent = 40
            }
        }
    }
    
    private func saveGoals() {
        let newGoals = DietGoals(
            dailyCalories: Int(dailyCalories),
            proteinPercent: Int(proteinPercent),
            carbsPercent: Int(carbsPercent),
            fatPercent: Int(fatPercent),
            waterGoalMl: viewModel.dietGoals.waterGoalMl,
            mealRemindersEnabled: mealRemindersEnabled,
            updatedAt: Date()
        )
        
        Task {
            await viewModel.updateGoals(newGoals)
            dismiss()
        }
    }
}

#Preview {
    DietSettingsView(viewModel: DietViewModel())
}
