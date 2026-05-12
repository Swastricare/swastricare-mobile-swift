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
    @State private var saveBanner: SaveBanner?

    private enum SaveBanner: Identifiable {
        case success, failure(String)
        var id: String {
            switch self {
            case .success: return "success"
            case .failure(let msg): return "failure-\(msg)"
            }
        }
    }

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
        .alert(item: $saveBanner) { banner in
            switch banner {
            case .success:
                return Alert(
                    title: Text("Goals saved"),
                    message: Text("Your activity goals have been updated."),
                    dismissButton: .default(Text("OK"))
                )
            case .failure(let message):
                return Alert(
                    title: Text("Couldn't save goals"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .trackScreen("GoalsSettings")
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Activity", systemImage: "figure.run")
                .font(.poppins(.semiBold, size: 16))
                .foregroundColor(.primary)

            // Steps Goal
            goalRow(
                icon: "figure.walk",
                iconColor: AppColors.accentBlue,
                title: "Daily Steps",
                value: Int(stepsGoal),
                unit: "steps"
            )

            Slider(value: $stepsGoal, in: 2000...30000, step: 500)
                .tint(AppColors.accentBlue)

            HStack {
                Text("2,000")
                Spacer()
                Text("30,000")
            }
            .font(.poppins(.regular, size: 11))
            .foregroundColor(.secondary)

            Divider()

            // Distance Goal
            goalRow(
                icon: "map.fill",
                iconColor: AppColors.accentBlue,
                title: "Daily Distance",
                value: nil,
                unit: "km",
                formattedValue: String(format: "%.1f", distanceGoal)
            )

            Slider(value: $distanceGoal, in: 1...30, step: 0.5)
                .tint(AppColors.accentBlue)

            HStack {
                Text("1 km")
                Spacer()
                Text("30 km")
            }
            .font(.poppins(.regular, size: 11))
            .foregroundColor(.secondary)

            Divider()

            // Active Calories Goal
            goalRow(
                icon: "flame.fill",
                iconColor: AppColors.accentBlue,
                title: "Active Calories",
                value: Int(activeCaloriesGoal),
                unit: "cal"
            )

            Slider(value: $activeCaloriesGoal, in: 100...2000, step: 50)
                .tint(AppColors.accentBlue)

            HStack {
                Text("100")
                Spacer()
                Text("2,000")
            }
            .font(.poppins(.regular, size: 11))
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
                        .fill(AppColors.accentBlue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "drop.fill")
                        .font(.poppins(.regular, size: 18))
                        .foregroundColor(AppColors.accentBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hydration")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(.primary)
                    Text("Daily goal: \(hydrationViewModel.dailyGoal) ml")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.poppins(.semiBold, size: 13))
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
                        .fill(AppColors.accentBlue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "fork.knife")
                        .font(.poppins(.regular, size: 18))
                        .foregroundColor(AppColors.accentBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Diet")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(.primary)
                    Text("Daily goal: \(dietViewModel.dietGoals.dailyCalories) cal  |  P \(dietViewModel.dietGoals.proteinPercent)% C \(dietViewModel.dietGoals.carbsPercent)% F \(dietViewModel.dietGoals.fatPercent)%")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.poppins(.semiBold, size: 13))
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
                    .font(.poppins(.semiBold, size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AppColors.aiTeal, Color(hex: "4A90E2")],
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
                .font(.poppins(.regular, size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.poppins(.medium, size: 15))

            Spacer()

            HStack(alignment: .bottom, spacing: 3) {
                Text(formattedValue ?? "\(value ?? 0)")
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(iconColor)
                Text(unit)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
            }
        }
    }

    private func saveActivityGoals() {
        isSaving = true
        runViewModel.clearError()
        Task {
            await runViewModel.updateGoals(
                steps: Int(stepsGoal),
                distance: Int(distanceGoal * 1000),
                calories: Int(activeCaloriesGoal)
            )
            await MainActor.run {
                isSaving = false
                if let error = runViewModel.errorMessage {
                    saveBanner = .failure(error)
                    runViewModel.clearError()
                } else {
                    saveBanner = .success
                    stepsGoal = Double(runViewModel.activityGoal.dailyStepsGoal)
                    distanceGoal = runViewModel.activityGoal.dailyDistanceGoal
                    activeCaloriesGoal = Double(runViewModel.activityGoal.dailyCaloriesGoal)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GoalsSettingsView()
    }
}
