//
//  HomeView.swift
//  swastricare-mobile-swift
//
//  iOS port of Android HomeScreenV3 — MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

// MARK: - Private Color Tokens (mirroring HomeScreenV3.kt)

private let darkText = Color(hex: "0F172A")
private let mutedText = Color(hex: "6B7280")
private let subtleBorder = Color.black.opacity(0.06)
private let ringTrack = Color(hex: "E5E7EB")

private let calorieAccent = Color(hex: "EF4444")
private let distanceAccent = Color(hex: "38BDF8")
private let activeAccent = Color(hex: "8B5CF6")

// MARK: - HomeView

struct HomeView: View {

    // MARK: - ViewModels

    @StateObject private var viewModel = DependencyContainer.shared.homeViewModel
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    @StateObject private var medicationViewModel = DependencyContainer.shared.medicationViewModel
    @StateObject private var dietViewModel = DependencyContainer.shared.dietViewModel
    @StateObject private var trackerViewModel = DependencyContainer.shared.trackerViewModel
    @StateObject private var runActivityViewModel = DependencyContainer.shared.runActivityViewModel
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel

    // MARK: - Local State

    @State private var hasAppeared = false
    @State private var showHeartRateMeasurement = false
    @State private var showReminders = false
    @State private var showARBodyScan = false
    @State private var showMedications = false
    @State private var showHydration = false
    @State private var showDiet = false
    @State private var showMenstrualCycle = false
    @State private var showFamily = false
    @State private var showSyncAlert = false
    @State private var syncMessage: String?
    @State private var hasAutoPromptedHealth = false

    // MARK: - Computed

    private var firstName: String {
        authViewModel.userName.components(separatedBy: " ").first?.isEmpty == false
            ? authViewModel.userName.components(separatedBy: " ").first!
            : "there"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        case 17..<21: return "Good Evening,"
        default: return "Good Night,"
        }
    }

    // Activity goal data — pulled from runActivityViewModel
    private var stepGoal: Int { runActivityViewModel.activityGoal.dailyStepsGoal }
    private var calorieGoal: Int { runActivityViewModel.activityGoal.dailyCaloriesGoal }
    // Distance goal in km
    private var distanceGoalKm: Double { runActivityViewModel.activityGoal.dailyDistanceGoal }
    // Active minutes goal — use iOS default of 30 min (no explicit field, matches HomeVM exerciseProgress /30)
    private var activeMinutesGoal: Int { 30 }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 1. Header
                HomeHeaderSection(
                    firstName: firstName,
                    greeting: greeting,
                    avatarURL: authViewModel.userPhotoURL,
                    onNotifications: { showReminders = true }
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 16)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: hasAppeared)

                // Nudge cards (non-critical, kept from existing logic)
                if !viewModel.serverNudges.isEmpty {
                    NudgeCardsView(
                        nudges: viewModel.serverNudges,
                        onDismiss: { nudge in Task { await viewModel.dismissNudge(nudge) } },
                        onAction: { nudge in
                            Task { await viewModel.actOnNudge(nudge) }
                            if let deeplink = nudge.actionDeeplink, let url = URL(string: deeplink) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                    .padding(.top, 4)
                }

                Spacer().frame(height: 12)

                // 2. Daily Activity Card
                DailyActivityCard(
                    steps: viewModel.stepCount,
                    stepGoal: stepGoal,
                    calories: viewModel.activeCalories,
                    calorieGoal: calorieGoal,
                    distance: viewModel.distance,
                    distanceGoalKm: distanceGoalKm,
                    activeMinutes: viewModel.exerciseMinutes,
                    activeMinutesGoal: activeMinutesGoal
                )
                .padding(.horizontal, 16)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1), value: hasAppeared)

                Spacer().frame(height: 18)

                // 3. Quick Actions
                HomeSectionHeader(title: "Quick Actions")
                Spacer().frame(height: 8)
                QuickActionsRow(
                    onHydration: { showHydration = true },
                    onMedication: { showMedications = true },
                    onCycle: { showMenstrualCycle = true },
                    onDiet: { showDiet = true }
                )
                .padding(.horizontal, 16)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.18), value: hasAppeared)

                Spacer().frame(height: 18)

                // 4. Health Vitals
                HomeSectionHeader(
                    title: "Health Vitals",
                    trailingLabel: "View All",
                    onTrailing: { showHealthAnalytics() }
                )
                Spacer().frame(height: 8)
                HealthVitalsRow(
                    heartRate: viewModel.heartRate,
                    sleepHours: viewModel.sleepHours,
                    weight: viewModel.weight,
                    onHeartRate: { showHeartRateMeasurement = true },
                    onSleep: { showAnalytics() },
                    onBodyScan: { showARBodyScan = true }
                )
                .padding(.horizontal, 16)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25), value: hasAppeared)

                Spacer().frame(height: 18)

                // 5. Swastri AI Banner
                SwastriAICard(onChat: { navigateToAI() })
                    .padding(.horizontal, 16)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.32), value: hasAppeared)

                Spacer().frame(height: 16)
            }
        }
        .background(Color.white)
        // HealthKit auth banner (preserved from original)
        .safeAreaInset(edge: .top) {
            if !viewModel.isAuthorized && !viewModel.hasRequestedAuth {
                HealthAuthBanner {
                    Task { await viewModel.requestAuthorization() }
                }
            }
        }
        // Sheets & covers
        .sheet(isPresented: $showHeartRateMeasurement) {
            NavigationStack { HeartRateView() }
        }
        .sheet(isPresented: $showReminders) {
            RemindersView()
        }
        .fullScreenCover(isPresented: $showARBodyScan) {
            ARBodyScanView()
        }
        .sheet(isPresented: $showMedications) {
            MedicationsView(viewModel: medicationViewModel)
        }
        .fullScreenCover(isPresented: $showHydration) {
            HydrationView(viewModel: hydrationViewModel)
        }
        .fullScreenCover(isPresented: $showDiet) {
            DietView(viewModel: dietViewModel)
        }
        .sheet(isPresented: $showMenstrualCycle) {
            MenstrualCycleView()
        }
        .sheet(isPresented: $showFamily) {
            NavigationStack { FamilyView() }
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncMessage ?? "")
        }
        // Deep links (preserved)
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenHydration)) { _ in
            showHydration = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenMedications)) { _ in
            showMedications = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenHeartRate)) { _ in
            showHeartRateMeasurement = true
        }
        // Screen tracking (preserved)
        .trackScreen("Home")
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
        }
        .task {
            // Auto-prompt Apple Health permission on first appear (mirrors Android HomeScreenV3).
            if !hasAutoPromptedHealth,
               !viewModel.isAuthorized,
               !viewModel.hasRequestedAuth,
               HealthKitService.shared.isHealthDataAvailable {
                hasAutoPromptedHealth = true
                try? await Task.sleep(nanoseconds: 400_000_000)
                await viewModel.requestAuthorization()
            }
            await viewModel.loadTodaysData()
            await trackerViewModel.loadData()
            await hydrationViewModel.loadData()
            await medicationViewModel.loadMedications()
            await dietViewModel.loadData()
            await runActivityViewModel.loadData()
            // Sync actual user goals to HomeViewModel (widget + live-activity)
            viewModel.dailyStepsGoal = runActivityViewModel.activityGoal.dailyStepsGoal
            viewModel.dailyCaloriesGoal = runActivityViewModel.activityGoal.dailyCaloriesGoal
        }
        .refreshable {
            await viewModel.refresh()
            await trackerViewModel.refresh()
            await hydrationViewModel.refresh()
            await medicationViewModel.refresh()
            await dietViewModel.refresh()
            await runActivityViewModel.loadData()
            viewModel.dailyStepsGoal = runActivityViewModel.activityGoal.dailyStepsGoal
            viewModel.dailyCaloriesGoal = runActivityViewModel.activityGoal.dailyCaloriesGoal
        }
    }

    // MARK: - Navigation helpers

    private func navigateToAI() {
        NotificationCenter.default.post(name: .init("NavigateToAI"), object: nil)
    }

    private func showHealthAnalytics() {
        // Uses the existing HealthAnalyticsView navigation — post a notification
        NotificationCenter.default.post(name: .init("NavigateToAnalytics"), object: nil)
    }

    private func showAnalytics() {
        showHealthAnalytics()
    }
}

// MARK: - Header Section

private struct HomeHeaderSection: View {
    let firstName: String
    let greeting: String
    let avatarURL: URL?
    let onNotifications: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar
            AvatarBubble(avatarURL: avatarURL)

            // Greeting column
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(mutedText)
                HStack(spacing: 6) {
                    Text(firstName)
                        .font(.poppins(.semiBold, size: 18))
                        .foregroundColor(darkText)
                        .lineLimit(1)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.aiTeal)
                }
                Text("Let's take a step towards a healthier you!")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(mutedText)
            }

            Spacer()

            // Bell button
            Button(action: onNotifications) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color(hex: "94A3B8").opacity(0.25), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(subtleBorder, lineWidth: 0.5)
                        )
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(darkText)
                        .frame(width: 40, height: 40)
                    // Notification dot
                    Circle()
                        .fill(AppColors.aiTeal)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: -2, y: 2)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Avatar Bubble

private struct AvatarBubble: View {
    let avatarURL: URL?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Circle background
            Circle()
                .fill(AppColors.aiTeal.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Group {
                        if let url = avatarURL {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.aiTeal)
                            }
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.aiTeal)
                        }
                    }
                )
                .clipShape(Circle())

            // Online badge
            Circle()
                .fill(AppColors.aiTeal)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                )
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - Daily Activity Card

private struct DailyActivityCard: View {
    let steps: Int
    let stepGoal: Int
    let calories: Int
    let calorieGoal: Int
    let distance: Double
    let distanceGoalKm: Double
    let activeMinutes: Int
    let activeMinutesGoal: Int

    var body: some View {
        let ringSize = min(max((UIScreen.main.bounds.width - 64) * 0.34, 110), 150)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Daily Activity")
                .font(.poppins(.semiBold, size: 13))
                .foregroundColor(darkText)

            HStack(alignment: .center, spacing: 14) {
                // Steps ring
                StepsRingView(steps: steps, goal: stepGoal, size: ringSize)
                    .frame(width: ringSize, height: ringSize)

                // Stat rows
                VStack(spacing: 0) {
                    MiniStatRow(
                        icon: "flame.fill",
                        iconColor: calorieAccent,
                        label: "Calories",
                        value: "\(calories)",
                        goalText: "\(calorieGoal) kcal",
                        progress: calorieGoal > 0
                            ? Float(min(Double(calories) / Double(calorieGoal), 1.0)) : 0,
                        accent: calorieAccent
                    )
                    Spacer(minLength: 0)
                    MiniStatRow(
                        icon: "figure.walk",
                        iconColor: distanceAccent,
                        label: "Distance",
                        value: String(format: "%.1f", distance),
                        goalText: "\(Int(distanceGoalKm)) km",
                        progress: distanceGoalKm > 0
                            ? Float(min(distance / distanceGoalKm, 1.0)) : 0,
                        accent: distanceAccent
                    )
                    Spacer(minLength: 0)
                    MiniStatRow(
                        icon: "bolt.fill",
                        iconColor: activeAccent,
                        label: "Active Minutes",
                        value: "\(activeMinutes)",
                        goalText: "\(activeMinutesGoal) min",
                        progress: activeMinutesGoal > 0
                            ? Float(min(Double(activeMinutes) / Double(activeMinutesGoal), 1.0)) : 0,
                        accent: activeAccent
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: ringSize)
            }

            // Goal label beneath ring
            HStack {
                Text("Goal \(formatSteps(stepGoal))")
                    .font(.poppins(.semiBold, size: 11))
                    .foregroundColor(AppColors.aiTeal)
                    .frame(width: ringSize, alignment: .center)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(hex: "94A3B8").opacity(0.25), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(subtleBorder, lineWidth: 0.5)
        )
    }

    private func formatSteps(_ value: Int) -> String {
        value >= 1000 ? String(format: "%d,%03d", value / 1000, value % 1000) : "\(value)"
    }
}

// MARK: - Steps Ring

private struct StepsRingView: View {
    let steps: Int
    let goal: Int
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    private var target: Double {
        goal > 0 ? min(Double(steps) / Double(goal), 1.0) : 0
    }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(ringTrack, style: StrokeStyle(lineWidth: 7, lineCap: .round))

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [AppColors.aiTeal, AppColors.accentGreen, AppColors.aiTeal]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.1), value: animatedProgress)

            // Center content
            VStack(spacing: 2) {
                Image.androidIcon("steps shoe icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(formatSteps(steps))
                    .font(.poppins(.bold, size: 20))
                    .foregroundColor(darkText)
                Text("Steps")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(mutedText)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animatedProgress = target
            }
        }
        .onChange(of: target) { _, newVal in
            withAnimation(.easeInOut(duration: 0.8)) { animatedProgress = newVal }
        }
    }

    private func formatSteps(_ value: Int) -> String {
        value >= 1000 ? String(format: "%d,%03d", value / 1000, value % 1000) : "\(value)"
    }
}

// MARK: - Mini Stat Row (Calories / Distance / Active)

private struct MiniStatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let goalText: String
    let progress: Float
    let accent: Color

    @State private var animatedProgress: Float = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(label)
                        .font(.poppins(.semiBold, size: 11))
                        .foregroundColor(darkText)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 0) {
                        Text(value)
                            .font(.poppins(.bold, size: 10))
                            .foregroundColor(darkText)
                        Text(" / \(goalText)")
                            .font(.poppins(.regular, size: 10))
                            .foregroundColor(mutedText)
                    }
                    .lineLimit(1)
                }
                // Thin progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ringTrack)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: geo.size.width * CGFloat(animatedProgress), height: 4)
                            .animation(.easeInOut(duration: 1.0).delay(0.2), value: animatedProgress)
                    }
                }
                .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newVal in
            withAnimation { animatedProgress = newVal }
        }
    }
}

// MARK: - Section Header

private struct HomeSectionHeader: View {
    let title: String
    var trailingLabel: String? = nil
    var onTrailing: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(darkText)
            Spacer()
            if let label = trailingLabel {
                Button(action: { onTrailing?() }) {
                    Text(label)
                        .font(.poppins(.semiBold, size: 13))
                        .foregroundColor(AppColors.aiTeal)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Quick Actions Row

private struct QuickActionsRow: View {
    let onHydration: () -> Void
    let onMedication: () -> Void
    let onCycle: () -> Void
    let onDiet: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            QuickActionTile(
                iconAsset: "hydration icon",
                label: "Hydration",
                bgColor: Color(hex: "E0F2FE"),
                onClick: onHydration
            )
            QuickActionTile(
                iconAsset: "medication icon",
                label: "Medication",
                bgColor: Color(hex: "DCFCE7"),
                onClick: onMedication
            )
            QuickActionTile(
                iconAsset: "cycle icon",
                label: "Cycle",
                bgColor: HomeThemeColors.cycleBg(.light),
                onClick: onCycle
            )
            QuickActionTile(
                iconAsset: "diet icon",
                label: "Diet",
                bgColor: Color(hex: "FEF8E1"),
                onClick: onDiet
            )
        }
    }
}

private struct QuickActionTile: View {
    let iconAsset: String
    let label: String
    let bgColor: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 4) {
                Image.androidIcon(iconAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 55, height: 55)
                Text(label)
                    .font(.poppins(.semiBold, size: 12))
                    .foregroundColor(darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bgColor)
                    .shadow(color: Color(hex: "94A3B8").opacity(0.20), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.3)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Health Vitals Row

private struct HealthVitalsRow: View {
    let heartRate: Int
    let sleepHours: String
    let weight: String
    let onHeartRate: () -> Void
    let onSleep: () -> Void
    let onBodyScan: () -> Void

    // BloodOxygen: static placeholder matching Android (no iOS HealthKit read for SpO2 in current VM)
    private let bloodOxygen = 98

    var body: some View {
        HStack(spacing: 0) {
            VitalCell(
                iconAsset: "heart rate icon",
                label: "Heart Rate",
                value: heartRate > 0 ? "\(heartRate)" : "--",
                unit: "bpm"
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onHeartRate() }

            vitalDivider

            VitalCell(
                iconAsset: "blood oxygen icon",
                label: "Blood Oxygen",
                value: "\(bloodOxygen)",
                unit: "%"
            )
            .frame(maxWidth: .infinity)

            vitalDivider

            VitalCell(
                iconAsset: "sleep icon",
                label: "Sleep",
                value: sleepHours == "0h 0m" ? "--" : sleepHours,
                unit: ""
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onSleep() }

            vitalDivider

            VitalCell(
                iconAsset: "weight icon",
                label: "Weight",
                value: weight.isEmpty ? "--" : weight,
                unit: "kg"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(hex: "94A3B8").opacity(0.25), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(subtleBorder, lineWidth: 0.5)
        )
    }

    private var vitalDivider: some View {
        Rectangle()
            .fill(subtleBorder)
            .frame(width: 1, height: 36)
    }
}

private struct VitalCell: View {
    let iconAsset: String
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Image.androidIcon(iconAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            Text(label)
                .font(.poppins(.regular, size: 11))
                .foregroundColor(mutedText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.poppins(.bold, size: 16))
                    .foregroundColor(darkText)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.poppins(.medium, size: 10))
                        .foregroundColor(mutedText)
                        .padding(.bottom, 2)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Swastri AI Card

private struct SwastriAICard: View {
    let onChat: () -> Void

    var body: some View {
        Button(action: onChat) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Swastri AI")
                        .font(.poppins(.bold, size: 11))
                        .foregroundColor(AppColors.accentGreen)
                        .tracking(0.5)
                    Text("Your health companion")
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(.white)
                    Text("Ask anything, get personalized insights and guidance.")
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(.white.opacity(0.65))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 16)

                Spacer()

                // AI mascot — uses Android `banner ai illustration.png`
                Image.androidIcon("banner ai illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0F172A"), Color(hex: "134E4A")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: "94A3B8").opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Health Auth Banner (preserved from original HomeView)

private struct HealthAuthBanner: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34))
                .foregroundColor(.red)
            Text("Enable Health Access")
                .font(.poppins(.semiBold, size: 17))
            Text("Allow Swastricare to read your health data for personalized insights")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onAllow) {
                Text("Allow Access")
                    .font(.poppins(.semiBold, size: 17))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PremiumColor.royalBlue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
        .background(Color.white.opacity(0.01)) // ensures safeAreaInset has a size
    }
}

// MARK: - Skeleton helpers (still available but not used in new layout)

private struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.12))
            .frame(width: width, height: height)
    }
}

// MARK: - Existing reusable components kept below (referenced by other views or sheets)
// WaterWave, RisingBubblesEffect, BottomRoundedRectangle, ScrollAnimationModifier,
// ScrollOffsetPreferenceKey, HealthLiveActivityToggle — moved here so they compile.

// MARK: - Scroll Animation Modifier

struct ScrollAnimationModifier: ViewModifier {
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let screenHeight = UIScreen.main.bounds.height
                if !isVisible && offset < screenHeight + 100 && offset > -100 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isVisible = true
                    }
                }
            }
            .onAppear {
                if !isVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isVisible = true
                        }
                    }
                }
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Water Wave Shape

struct RisingBubblesEffect: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12) { i in
                    BubbleView(
                        delay: Double(i) * 0.5,
                        size: CGFloat.random(in: 4...10),
                        xRange: 0...geo.size.width,
                        color: color
                    )
                }
            }
        }
    }

    struct BubbleView: View {
        let delay: Double
        let size: CGFloat
        let xRange: ClosedRange<CGFloat>
        let color: Color

        @State private var offset: CGFloat = 200
        @State private var xOffset: CGFloat = 0
        @State private var opacity: Double = 0

        var body: some View {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .offset(x: xOffset, y: offset)
                .opacity(opacity)
                .onAppear {
                    xOffset = CGFloat.random(in: xRange)
                    withAnimation(
                        .linear(duration: 4.0)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                    ) {
                        offset = -200
                        opacity = 1
                    }
                }
        }
    }
}

// MARK: - Bottom Rounded Rectangle Shape

struct BottomRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, rect.height / 2, rect.width / 2)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addArc(
            center: CGPoint(x: rect.width - radius, y: rect.height - radius),
            radius: radius,
            startAngle: .zero,
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        path.addArc(
            center: CGPoint(x: radius, y: rect.height - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Health Live Activity Toggle

private struct HealthLiveActivityToggle: View {
    let userName: String
    let steps: Int
    let heartRate: Int
    let calories: Int
    var stepGoal: Int = 10000

    @ObservedObject private var manager = HealthLiveActivityManager.shared

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                if manager.isActive {
                    await manager.endHealthTracking()
                } else {
                    await manager.startHealthTracking(userName: userName)
                    await manager.update(
                        steps: steps,
                        heartRate: heartRate,
                        calories: calories,
                        hydrationMl: 0,
                        hydrationGoalMl: 2500,
                        stepGoal: stepGoal
                    )
                }
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(manager.isActive ? Color.green.opacity(0.15) : AppColors.aiTeal.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(manager.isActive ? .green : AppColors.aiTeal)
                        .symbolEffect(.bounce, value: manager.isActive)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dynamic Island")
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundColor(.primary)
                    Text(manager.isActive ? "Health tracking live on your island" : "Show health stats on Dynamic Island")
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(manager.isActive ? "ON" : "OFF")
                    .font(.poppins(.bold, size: 11))
                    .foregroundColor(manager.isActive ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(manager.isActive ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
                    )
            }
            .padding(14)
            .glass(cornerRadius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!manager.canStartActivities)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
