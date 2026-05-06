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
                            .font(.poppins(.regular, size: 22))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .trackScreen("DietSettings")
    }
    
    // MARK: - Calorie Section
    
    private var calorieSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Calorie Target")
                .font(.poppins(.semiBold, size: 16))
            
            // Big number
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(dailyCalories))")
                    .font(.poppins(.bold, size: 48))
                    .foregroundColor(AppColors.accentGreen)
                Text("cal")
                    .font(.poppins(.regular, size: 20))
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
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text("4,000")
                    .font(.poppins(.regular, size: 12))
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
                .font(.poppins(.semiBold, size: 16))
            
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
                        .font(.poppins(.medium, size: 14))
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.accentRed)
                    Text("Total must be 100%")
                        .font(.poppins(.medium, size: 14))
                        .foregroundColor(AppColors.accentRed)
                }
                
                Spacer()
                
                Text("\(totalPercent)%")
                    .font(.poppins(.bold, size: 16))
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
                    .font(.poppins(.medium, size: 14))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(value.wrappedValue))%")
                    .font(.poppins(.bold, size: 13))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
                
                Text("\(grams)g")
                    .font(.poppins(.medium, size: 13))
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
                .font(.poppins(.semiBold, size: 16))
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
                        .font(.poppins(.medium, size: 15))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.poppins(.regular, size: 20))
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
                    .font(.poppins(.medium, size: 15))
                    .foregroundColor(.primary)
                Text("Get notified to log meals")
                    .font(.poppins(.regular, size: 12))
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
                    .font(.poppins(.semiBold, size: 16))
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
