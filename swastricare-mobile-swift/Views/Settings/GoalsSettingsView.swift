//
//  GoalsSettingsView.swift
//  swastricare-mobile-swift
//
//  Goals configuration - steps, distance, calories, hydration, diet
//

import SwiftUI

struct GoalsSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var runViewModel = DependencyContainer.shared.runActivityViewModel
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    @StateObject private var dietViewModel = DependencyContainer.shared.dietViewModel

    // Activity goals
    @State private var stepsGoal: Double = 10000
    @State private var distanceGoal: Double = 8.0
    @State private var activeCaloriesGoal: Double = 500

    // Hydration
    @State private var showHydrationSettings = false

    // Diet
    @State private var showDietSettings = false

    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    activitySection
                    hydrationSection
                    dietSection
                    saveButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            stepsGoal = Double(runViewModel.activityGoal.dailyStepsGoal)
            distanceGoal = runViewModel.activityGoal.dailyDistanceGoal
            activeCaloriesGoal = Double(runViewModel.activityGoal.dailyCaloriesGoal)
        }
        .sheet(isPresented: $showHydrationSettings) {
            HydrationSettingsView(viewModel: hydrationViewModel)
        }
        .sheet(isPresented: $showDietSettings) {
            DietSettingsView(viewModel: dietViewModel)
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Activity", systemImage: "figure.run")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            // Steps Goal
            goalRow(
                icon: "figure.walk",
                iconColor: Color(hex: "4CAF50"),
                title: "Daily Steps",
                value: Int(stepsGoal),
                unit: "steps"
            )

            Slider(value: $stepsGoal, in: 2000...30000, step: 500)
                .tint(Color(hex: "4CAF50"))

            HStack {
                Text("2,000")
                Spacer()
                Text("30,000")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            Divider()

            // Distance Goal
            goalRow(
                icon: "map.fill",
                iconColor: Color(hex: "2196F3"),
                title: "Daily Distance",
                value: nil,
                unit: "km",
                formattedValue: String(format: "%.1f", distanceGoal)
            )

            Slider(value: $distanceGoal, in: 1...30, step: 0.5)
                .tint(Color(hex: "2196F3"))

            HStack {
                Text("1 km")
                Spacer()
                Text("30 km")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            Divider()

            // Active Calories Goal
            goalRow(
                icon: "flame.fill",
                iconColor: Color(hex: "FF5722"),
                title: "Active Calories",
                value: Int(activeCaloriesGoal),
                unit: "cal"
            )

            Slider(value: $activeCaloriesGoal, in: 100...2000, step: 50)
                .tint(Color(hex: "FF5722"))

            HStack {
                Text("100")
                Spacer()
                Text("2,000")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Hydration Section

    private var hydrationSection: some View {
        Button(action: { showHydrationSettings = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hydration")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Daily goal: \(hydrationViewModel.dailyGoal) ml")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Diet Section

    private var dietSection: some View {
        Button(action: { showDietSettings = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentGreen.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.accentGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Diet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Daily goal: \(dietViewModel.dietGoals.dailyCalories) cal  |  P \(dietViewModel.dietGoals.proteinPercent)% C \(dietViewModel.dietGoals.carbsPercent)% F \(dietViewModel.dietGoals.fatPercent)%")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveActivityGoals) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text("Save Activity Goals")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isSaving)
    }

    // MARK: - Helpers

    private func goalRow(icon: String, iconColor: Color, title: String, value: Int?, unit: String, formattedValue: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 15, weight: .medium))

            Spacer()

            HStack(alignment: .bottom, spacing: 3) {
                Text(formattedValue ?? "\(value ?? 0)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(iconColor)
                Text(unit)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
            }
        }
    }

    private func saveActivityGoals() {
        isSaving = true
        Task {
            await runViewModel.updateGoals(
                steps: Int(stepsGoal),
                distance: Int(distanceGoal * 1000),
                calories: Int(activeCaloriesGoal)
            )
            await MainActor.run {
                isSaving = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        GoalsSettingsView()
    }
}
