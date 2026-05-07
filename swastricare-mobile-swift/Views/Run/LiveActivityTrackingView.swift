//
//  LiveActivityTrackingView.swift
//  swastricare-mobile-swift
//
//  Live GPS Activity Tracking View — Android-aligned redesign
//

import SwiftUI
import MapKit

// MARK: - Local Palette

private let liveScreenBg = Color.white
private let liveCardBg = Color.white
private let liveTextPrimary = Color(hex: "0F172A")
private let liveTextSecondary = Color(hex: "64748B")
private let liveSoftBorder = Color(hex: "E5EAF0")
private let liveMintTint = Color(hex: "E6F7F2")

// MARK: - Goal Type (UI only)

private enum WorkoutGoalType: String, CaseIterable, Identifiable {
    case distance = "Distance"
    case duration = "Duration"
    case calories = "Calories"
    case noGoal = "No Goal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .distance: return "scope"
        case .duration: return "timer"
        case .calories: return "flame.fill"
        case .noGoal: return "trophy.fill"
        }
    }

    var iconBg: Color {
        switch self {
        case .distance: return Color(hex: "E0EAFF")
        case .duration: return Color(hex: "EFE3FF")
        case .calories: return Color(hex: "FFE0EE")
        case .noGoal: return Color(hex: "FFE7D6")
        }
    }

    var iconTint: Color {
        switch self {
        case .distance: return Color(hex: "4F46E5")
        case .duration: return Color(hex: "7C3AED")
        case .calories: return Color(hex: "E11D74")
        case .noGoal: return Color(hex: "EA580C")
        }
    }

    var unitLabel: String {
        switch self {
        case .distance: return "km"
        case .duration: return "min"
        case .calories: return "kcal"
        case .noGoal: return ""
        }
    }
}

private struct WorkoutTypeOption: Identifiable {
    let type: WorkoutActivityType
    let title: String
    let subtitle: String
    let asset: String
    var id: String { type.rawValue }
}

private let workoutOptions: [WorkoutTypeOption] = [
    .init(type: .running, title: "Run", subtitle: "Track your run and improve your pace", asset: "run activity illustration"),
    .init(type: .walking, title: "Walk", subtitle: "Track your steps and stay active", asset: "walk illustration"),
    .init(type: .cycling, title: "Cycle", subtitle: "Track your ride and distance covered", asset: "cycle illustration"),
    .init(type: .hiking, title: "Hike", subtitle: "Explore trails and track your hike", asset: "hike illustration"),
]

// MARK: - Live Activity Tracking View

struct LiveActivityTrackingView: View {
    @StateObject private var viewModel = LiveActivityViewModel()
    @Environment(\.dismiss) private var dismiss

    let initialActivityType: WorkoutActivityType?

    @State private var showDiscardConfirmation = false
    @State private var selectedGoal: WorkoutGoalType? = nil
    @State private var goalValue: String? = nil

    init(initialActivityType: WorkoutActivityType? = nil) {
        self.initialActivityType = initialActivityType
    }

    var body: some View {
        ZStack {
            switch viewModel.viewState {
            case .idle, .preparing:
                idleScreen
            case .countdown(let value):
                countdownScreen(value)
            case .tracking, .paused:
                activeTrackingScreen
            case .finishing:
                finishingScreen
            case .summary(let summary):
                WorkoutSummaryView(summary: summary) {
                    viewModel.dismissSummary()
                    dismiss()
                }
            case .error(let message):
                errorScreen(message)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let initialActivityType, viewModel.viewState.canStart {
                viewModel.selectActivityType(initialActivityType)
            }
        }
        .alert("Discard Workout?", isPresented: $showDiscardConfirmation) {
            Button("Keep Going", role: .cancel) { }
            Button("Discard", role: .destructive) {
                viewModel.discardWorkout()
                dismiss()
            }
        } message: {
            Text("Your workout data will be lost.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: {
            if let m = viewModel.errorMessage { Text(m) }
        }
        .trackScreen("LiveActivityTracking")
    }

    // MARK: - Idle Screen

    private var idleScreen: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.poppins(.semiBold, size: 18))
                        .foregroundColor(liveTextPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Workout")
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(liveTextPrimary)
                    Text("Choose your activity and set your goal")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(liveTextSecondary)
                }

                Spacer()
            }
            .padding(.trailing, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Choose Activity")
                            .font(.poppins(.bold, size: 16))
                            .foregroundColor(liveTextPrimary)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(workoutOptions) { option in
                            WorkoutActivityCard(
                                option: option,
                                isSelected: viewModel.selectedActivityType == option.type
                            ) {
                                let gen = UISelectionFeedbackGenerator()
                                gen.selectionChanged()
                                viewModel.selectActivityType(option.type)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    HStack {
                        Text("Set Your Goal")
                            .font(.poppins(.bold, size: 16))
                            .foregroundColor(liveTextPrimary)
                        Spacer()
                        Button {
                            selectedGoal = nil
                            goalValue = nil
                        } label: {
                            Text("Skip")
                                .font(.poppins(.medium, size: 13))
                                .foregroundColor(AppColors.aiTeal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    HStack(spacing: 8) {
                        ForEach(WorkoutGoalType.allCases) { type in
                            GoalCard(
                                type: type,
                                value: selectedGoal == type ? goalValue : nil,
                                isSelected: selectedGoal == type,
                                onTap: {
                                    if type == .noGoal {
                                        selectedGoal = .noGoal
                                        goalValue = nil
                                    } else {
                                        selectedGoal = type
                                        goalValue = nil
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    if !viewModel.locationAuthStatus.canTrack {
                        locationWarningCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    Spacer().frame(height: 24)
                }
            }

            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                Task { await viewModel.startWorkout() }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 28, height: 28)
                        Image(systemName: "play.fill")
                            .font(.poppins(.semiBold, size: 12))
                            .foregroundColor(.white)
                    }
                    Text("Start Workout")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(AppColors.aiTeal))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(liveScreenBg.ignoresSafeArea())
    }

    private var locationWarningCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.poppins(.regular, size: 18))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Location Access Required")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(liveTextPrimary)
                Text("Enable location to track your route.")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(liveTextSecondary)
            }
            Spacer()
            Button("Enable") {
                Task { await viewModel.requestLocationPermission() }
            }
            .font(.poppins(.semiBold, size: 13))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.orange))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "FFF7ED"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "FED7AA"), lineWidth: 1)
        )
    }

    // MARK: - Countdown

    private func countdownScreen(_ value: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(AppColors.aiTeal.opacity(0.15), lineWidth: 10)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: CGFloat(value) / 3.0)
                    .stroke(AppColors.aiTeal, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: value)

                Text("\(value)")
                    .font(.poppins(.bold, size: 96))
                    .foregroundColor(liveTextPrimary)
                    .contentTransition(.numericText())
            }

            Text("Get Ready!")
                .font(.poppins(.semiBold, size: 22))
                .foregroundColor(liveTextSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(liveScreenBg.ignoresSafeArea())
    }

    // MARK: - Active Tracking

    private var activeTrackingScreen: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LiveTrackingMapView(routeCoordinates: viewModel.routeCoordinates)
                    .frame(maxWidth: .infinity)

                Button {
                    showDiscardConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(liveTextPrimary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.leading, 16)

                if viewModel.isPaused {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.fill")
                            .font(.poppins(.semiBold, size: 12))
                        Text("Paused")
                            .font(.poppins(.semiBold, size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "F59E0B")))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.42)

            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 0) {
                    VStack(spacing: 4) {
                        Text(viewModel.formattedElapsedTime)
                            .font(.poppins(.bold, size: 36))
                            .foregroundColor(liveTextPrimary)
                            .contentTransition(.numericText())
                        Text("Duration")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(liveTextSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(liveSoftBorder)
                        .frame(width: 1, height: 50)

                    VStack(spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(viewModel.formattedDistance)
                                .font(.poppins(.bold, size: 36))
                                .foregroundColor(liveTextPrimary)
                                .contentTransition(.numericText())
                            Text(viewModel.distanceUnit)
                                .font(.poppins(.semiBold, size: 14))
                                .foregroundColor(liveTextSecondary)
                        }
                        Text("Distance")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(liveTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    LiveMetricTile(
                        icon: "speedometer",
                        iconTint: AppColors.aiTeal,
                        bgTint: liveMintTint,
                        value: viewModel.formattedAveragePace,
                        unit: "/km",
                        label: "Avg Pace"
                    )
                    LiveMetricTile(
                        icon: "flame.fill",
                        iconTint: Color(hex: "EF8B3C"),
                        bgTint: Color(hex: "FFF1DC"),
                        value: viewModel.formattedCalories,
                        unit: "kcal",
                        label: "Calories"
                    )
                    LiveMetricTile(
                        icon: "arrow.up.right",
                        iconTint: Color(hex: "3B82F6"),
                        bgTint: Color(hex: "E6F0FF"),
                        value: viewModel.formattedElevation,
                        unit: "m",
                        label: "Elevation"
                    )
                }

                if viewModel.currentPace > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(AppColors.aiTeal)
                        Text("Current Pace: \(viewModel.formattedCurrentPace)/km")
                            .font(.poppins(.medium, size: 13))
                            .foregroundColor(liveTextPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(liveMintTint))
                }

                Spacer(minLength: 0)

                HStack(spacing: 18) {
                    Button {
                        showDiscardConfirmation = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.poppins(.semiBold, size: 22))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color(hex: "FF4757")))
                    }
                    .buttonStyle(.plain)

                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        if viewModel.isPaused {
                            viewModel.resumeWorkout()
                        } else {
                            viewModel.pauseWorkout()
                        }
                    } label: {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.poppins(.semiBold, size: 30))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(AppColors.aiTeal))
                            .shadow(color: AppColors.aiTeal.opacity(0.3), radius: 14, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await viewModel.finishWorkout() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.poppins(.semiBold, size: 22))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color(hex: "22C55E")))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .background(liveCardBg)
            .clipShape(RoundedCorners(radius: 28, corners: [.topLeft, .topRight]))
            .offset(y: -28)
        }
        .background(liveScreenBg.ignoresSafeArea())
    }

    // MARK: - Finishing / Error

    private var finishingScreen: some View {
        VStack(spacing: 18) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.aiTeal))
                .scaleEffect(1.5)
            Text("Saving Workout…")
                .font(.poppins(.semiBold, size: 18))
                .foregroundColor(liveTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(liveScreenBg.ignoresSafeArea())
    }

    private func errorScreen(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.poppins(.regular, size: 56))
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.poppins(.bold, size: 20))
                .foregroundColor(liveTextPrimary)
            Text(message)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(liveTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") {
                viewModel.dismissError()
            }
            .font(.poppins(.semiBold, size: 15))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Capsule().fill(AppColors.aiTeal))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(liveScreenBg.ignoresSafeArea())
    }
}

// MARK: - Workout Activity Card

private struct WorkoutActivityCard: View {
    let option: WorkoutTypeOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Image.androidIcon(option.asset)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(option.title)
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(liveTextPrimary)

                    Text(option.subtitle)
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(liveTextSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(liveCardBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? AppColors.aiTeal : liveSoftBorder, lineWidth: isSelected ? 1.5 : 1)
                )

                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.aiTeal : Color.white)
                        .frame(width: 22, height: 22)
                    Circle()
                        .stroke(isSelected ? AppColors.aiTeal : liveSoftBorder, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.poppins(.bold, size: 11))
                            .foregroundColor(.white)
                    }
                }
                .padding(10)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let type: WorkoutGoalType
    let value: String?
    let isSelected: Bool
    let onTap: () -> Void

    private var subtitle: String {
        if type == .noGoal { return "Just track your activity" }
        if let v = value, !v.isEmpty { return "\(v) \(type.unitLabel)" }
        switch type {
        case .distance: return "Set a target distance"
        case .duration: return "Set a target time"
        case .calories: return "Set a target calories"
        case .noGoal: return ""
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(type.iconBg)
                        .frame(width: 36, height: 36)
                    Image(systemName: type.icon)
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(type.iconTint)
                }
                Text(type.rawValue)
                    .font(.poppins(.semiBold, size: 12))
                    .foregroundColor(liveTextPrimary)
                Text(subtitle)
                    .font(.poppins(.regular, size: 10))
                    .foregroundColor(liveTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(liveCardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.aiTeal : liveSoftBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live Metric Tile

private struct LiveMetricTile: View {
    let icon: String
    let iconTint: Color
    let bgTint: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle()
                    .fill(bgTint)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(iconTint)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.poppins(.bold, size: 18))
                    .foregroundColor(liveTextPrimary)
                Text(unit)
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(liveTextSecondary)
            }
            Text(label)
                .font(.poppins(.regular, size: 11))
                .foregroundColor(liveTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(liveSoftBorder, lineWidth: 1)
        )
    }
}

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppColors.aiTeal.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.poppins(.regular, size: 56))
                            .foregroundColor(AppColors.aiTeal)
                    }
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0)

                    VStack(spacing: 4) {
                        Text("Workout Complete!")
                            .font(.poppins(.bold, size: 26))
                            .foregroundColor(liveTextPrimary)
                        Text(summary.activityType.rawValue)
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(liveTextSecondary)
                    }
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)

                    HStack(spacing: 0) {
                        SummaryStatView(value: summary.formattedDistance, label: "Distance")
                        Rectangle().fill(liveSoftBorder).frame(width: 1, height: 44)
                        SummaryStatView(value: summary.formattedDuration, label: "Duration")
                        Rectangle().fill(liveSoftBorder).frame(width: 1, height: 44)
                        SummaryStatView(value: summary.formattedPace, label: "Avg Pace")
                    }
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(liveSoftBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 30)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SummaryDetailCard(icon: "flame.fill", iconColor: Color(hex: "EF8B3C"), iconBg: Color(hex: "FFF1DC"), value: summary.formattedCalories, label: "Calories")
                        SummaryDetailCard(icon: "arrow.up.right", iconColor: Color(hex: "22C55E"), iconBg: Color(hex: "E6F4EA"), value: "\(Int(summary.totalElevationGain))m", label: "Elevation")
                        if let avgHR = summary.averageHeartRate {
                            SummaryDetailCard(icon: "heart.fill", iconColor: Color(hex: "EF4444"), iconBg: Color(hex: "FEE2E2"), value: "\(avgHR)", label: "Avg Heart Rate")
                        }
                        if let maxHR = summary.maxHeartRate {
                            SummaryDetailCard(icon: "heart.fill", iconColor: Color(hex: "EF4444"), iconBg: Color(hex: "FEE2E2"), value: "\(maxHR)", label: "Max Heart Rate")
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 36)

                    if !summary.routePoints.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Route")
                                .font(.poppins(.bold, size: 16))
                                .foregroundColor(liveTextPrimary)
                            SummaryRouteMapView(routePoints: summary.routePoints)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(liveSoftBorder, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 44)
                    }

                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(AppColors.aiTeal))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 52)
                }
                .padding(.vertical, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
}

private struct SummaryStatView: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.poppins(.bold, size: 22))
                .foregroundColor(liveTextPrimary)
            Text(label)
                .font(.poppins(.regular, size: 11))
                .foregroundColor(liveTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SummaryDetailCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(liveTextPrimary)
                Text(label)
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(liveTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(liveSoftBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveActivityTrackingView()
    }
}
