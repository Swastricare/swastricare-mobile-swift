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

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Calorie Target
                        calorieSection
                        
                        // Macros
                        macroSection
                        
                        // Quick Presets
                        presetsSection
                        
                        // Reminders
                        remindersSection
                        
                        // Save Button
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Goals & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Calorie Section
    
    private var calorieSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Calorie Target")
                .font(.system(size: 16, weight: .semibold))
            
            // Big number
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(dailyCalories))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
                Text("cal")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Slider
            Slider(value: $dailyCalories, in: 1200...4000, step: 50)
                .tint(AppColors.accentGreen)
            
            // Range labels
            HStack {
                Text("1,200")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text("4,000")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Macro Section
    
    private var macroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macro Split")
                .font(.system(size: 16, weight: .semibold))
            
            // Protein
            macroRow(
                label: "Protein",
                value: $proteinPercent,
                grams: calculateGrams(percent: proteinPercent, caloriesPerGram: 4),
                color: Color(hex: "4CAF50")
            )
            
            // Carbs
            macroRow(
                label: "Carbs",
                value: $carbsPercent,
                grams: calculateGrams(percent: carbsPercent, caloriesPerGram: 4),
                color: Color(hex: "FF9800")
            )
            
            // Fat
            macroRow(
                label: "Fat",
                value: $fatPercent,
                grams: calculateGrams(percent: fatPercent, caloriesPerGram: 9),
                color: Color(hex: "2196F3")
            )
            
            // Total validation
            Divider()
            
            HStack {
                if isValidMacroSplit {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accentGreen)
                    Text("Total: 100%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.accentRed)
                    Text("Total must be 100%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accentRed)
                }
                
                Spacer()
                
                Text("\(totalPercent)%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isValidMacroSplit ? AppColors.accentGreen : AppColors.accentRed)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func macroRow(label: String, value: Binding<Double>, grams: Int, color: Color) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(value.wrappedValue))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
                
                Text("\(grams)g")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: value, in: 0...100, step: 5)
                .tint(color)
        }
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Presets")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 4)
            
            presetCard(
                title: "Balanced",
                subtitle: "25P • 50C • 25F",
                preset: .balanced
            )
            
            presetCard(
                title: "High Protein",
                subtitle: "35P • 40C • 25F",
                preset: .highProtein
            )
            
            presetCard(
                title: "Low Carb",
                subtitle: "30P • 30C • 40F",
                preset: .lowCarb
            )
        }
    }
    
    private func presetCard(title: String, subtitle: String, preset: MacroPreset) -> some View {
        let isSelected = isPresetSelected(preset)
        
        return Button(action: { applyPreset(preset) }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppColors.accentGreen : .secondary)
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accentGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Reminders Section
    
    private var remindersSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meal Reminders")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text("Get notified to log meals")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $mealRemindersEnabled)
                .tint(AppColors.accentGreen)
                .labelsHidden()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveGoals) {
            HStack {
                Text("Save Changes")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isValidMacroSplit ? AppColors.accentGreen : Color.gray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isValidMacroSplit)
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

    private func isPresetSelected(_ preset: MacroPreset) -> Bool {
        switch preset {
        case .balanced:
            return Int(proteinPercent) == 25 && Int(carbsPercent) == 50 && Int(fatPercent) == 25
        case .highProtein:
            return Int(proteinPercent) == 35 && Int(carbsPercent) == 40 && Int(fatPercent) == 25
        case .lowCarb:
            return Int(proteinPercent) == 30 && Int(carbsPercent) == 30 && Int(fatPercent) == 40
        }
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
