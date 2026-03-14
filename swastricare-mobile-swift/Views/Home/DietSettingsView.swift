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
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: Calorie Target Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Calorie Target")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            // Hero calorie number
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(dailyCalories))")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.accentGreen)
                                Text("cal")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.accentGreen.opacity(0.7))
                                Spacer()
                            }

                            Slider(value: $dailyCalories, in: 1200...4000, step: 50)
                                .tint(AppColors.accentGreen)

                            HStack {
                                Text("1,200 cal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("4,000 cal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Based on your activity level and goals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .glass(cornerRadius: 16)
                        .padding(.horizontal)

                        // MARK: Macro Distribution Card
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Macro Distribution")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            // Protein
                            macroSlider(
                                label: "Protein",
                                value: $proteinPercent,
                                color: .orange,
                                grams: calculateGrams(percent: proteinPercent, caloriesPerGram: 4)
                            )

                            Divider().opacity(0.4)

                            // Carbs
                            macroSlider(
                                label: "Carbs",
                                value: $carbsPercent,
                                color: .blue,
                                grams: calculateGrams(percent: carbsPercent, caloriesPerGram: 4)
                            )

                            Divider().opacity(0.4)

                            // Fat
                            macroSlider(
                                label: "Fat",
                                value: $fatPercent,
                                color: .purple,
                                grams: calculateGrams(percent: fatPercent, caloriesPerGram: 9)
                            )

                            Divider().opacity(0.6)

                            // Total validation row
                            HStack(spacing: 10) {
                                if isValidMacroSplit {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.accentGreen)
                                    Text("Perfect split")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColors.accentGreen)
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(AppColors.accentRed)
                                    Text("Must total 100%")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColors.accentRed)
                                }
                                Spacer()
                                Text("\(totalPercent)%")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(isValidMacroSplit ? AppColors.accentGreen : AppColors.accentRed)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        (isValidMacroSplit ? AppColors.accentGreen : AppColors.accentRed)
                                            .opacity(0.12)
                                    )
                                    .clipShape(Capsule())
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isValidMacroSplit)
                        }
                        .padding(20)
                        .glass(cornerRadius: 16)
                        .padding(.horizontal)

                        // MARK: Quick Presets
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Presets")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            presetButton(
                                title: "Balanced",
                                subtitle: "25% P  •  50% C  •  25% F",
                                preset: .balanced,
                                color: AppColors.accentGreen
                            )

                            presetButton(
                                title: "High Protein",
                                subtitle: "35% P  •  40% C  •  25% F",
                                preset: .highProtein,
                                color: .orange
                            )

                            presetButton(
                                title: "Low Carb",
                                subtitle: "30% P  •  30% C  •  40% F",
                                preset: .lowCarb,
                                color: .purple
                            )
                        }
                        .padding(20)
                        .glass(cornerRadius: 16)
                        .padding(.horizontal)

                        // MARK: Reminders Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reminders")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Meal Reminders")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Get notified to log your meals throughout the day")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $mealRemindersEnabled)
                                    .tint(AppColors.accentGreen)
                                    .labelsHidden()
                            }
                        }
                        .padding(20)
                        .glass(cornerRadius: 16)
                        .padding(.horizontal)

                        // MARK: Save Button
                        Button(action: saveGoals) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                                Text("Save Goals")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isValidMacroSplit
                                    ? LinearGradient(
                                        colors: [AppColors.accentGreen, AppColors.accentGreen.opacity(0.75)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                            )
                            .clipShape(Capsule())
                            .shadow(
                                color: isValidMacroSplit ? AppColors.accentGreen.opacity(0.35) : .clear,
                                radius: 10,
                                x: 0,
                                y: 4
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(!isValidMacroSplit)
                        .padding(.horizontal)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isValidMacroSplit)

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 16)
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
            }
        }
    }

    // MARK: - Macro Slider

    private func macroSlider(label: String, value: Binding<Double>, color: Color, grams: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                // Percentage badge
                Text("\(Int(value.wrappedValue))%")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 0.5))

                // Grams badge
                Text("\(grams)g")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.07))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            }

            Slider(value: value, in: 0...100, step: 5)
                .tint(color)
        }
    }

    // MARK: - Preset Button

    private func presetButton(title: String, subtitle: String, preset: MacroPreset, color: Color) -> some View {
        let isSelected = isPresetSelected(preset)

        return Button(action: { applyPreset(preset) }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? color : color.opacity(0.5))
                            .font(.system(size: 18, weight: .semibold))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? color.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.4) : Color.secondary.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
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
