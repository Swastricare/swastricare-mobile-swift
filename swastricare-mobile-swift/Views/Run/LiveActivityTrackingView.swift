//
//  LiveActivityTrackingView.swift
//  swastricare-mobile-swift
//
//  Live GPS Activity Tracking View
//  Redesigned with Movements+ UI - Lime Green, Dark Theme
//

import SwiftUI
import MapKit

// MARK: - Live Activity Tracking View

struct LiveActivityTrackingView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = LiveActivityViewModel()
    @Environment(\.dismiss) private var dismiss

    let initialActivityType: WorkoutActivityType?
    
    @State private var showDiscardConfirmation = false
    @State private var isMapExpanded = false
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen

    init(initialActivityType: WorkoutActivityType? = nil) {
        self.initialActivityType = initialActivityType
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch viewModel.viewState {
            case .idle, .preparing:
                activityTypeSelection
                
            case .countdown(let value):
                countdownView(value)
                
            case .tracking, .paused:
                activeTrackingView
                
            case .finishing:
                finishingView
                
            case .summary(let summary):
                WorkoutSummaryView(summary: summary) {
                    viewModel.dismissSummary()
                    dismiss()
                }
                
            case .error(let message):
                errorView(message)
            }
        }
        .navigationBarBackButtonHidden(viewModel.viewState.isTracking)
        .onAppear {
            if let initialActivityType, viewModel.viewState.canStart {
                viewModel.selectActivityType(initialActivityType)
            }
        }
        .toolbar {
            if viewModel.viewState == .idle {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
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
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
    }
    
    // MARK: - Activity Type Selection
    
    private var activityTypeSelection: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Hero Section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(limeGreen)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "figure.run")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Text("Start Workout")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Choose your activity type")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 40)
            
            // Activity Type Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(WorkoutActivityType.allCases) { type in
                    ActivityTypeCard(
                        type: type,
                        isSelected: viewModel.selectedActivityType == type
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectActivityType(type)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Location Permission Warning
            if !viewModel.locationAuthStatus.canTrack {
                locationPermissionCard
                    .padding(.bottom, 16)
            }
            
            // Start Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                Task {
                    await viewModel.startWorkout()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("Start Workout")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(limeGreen)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Location Permission Card
    
    private var locationPermissionCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Location Required")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Enable to track route & distance")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button("Enable") {
                Task {
                    await viewModel.requestLocationPermission()
                }
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Countdown View
    
    private func countdownView(_ value: Int) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(limeGreen.opacity(0.2), lineWidth: 10)
                    .frame(width: 220, height: 220)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 3.0)
                    .stroke(limeGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: value)
                
                VStack(spacing: 4) {
                    Text("\(value)")
                        .font(.system(size: 90, weight: .bold, design: .rounded))
                        .foregroundColor(limeGreen)
                        .contentTransition(.numericText())
                }
            }
            
            VStack(spacing: 8) {
                Text("Get Ready!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your workout is about to begin")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Active Tracking View
    
    private var activeTrackingView: some View {
        VStack(spacing: 0) {
            if isMapExpanded {
                expandedMapView
            } else {
                compactMapView
            }
            
            metricsSection
            
            controlButtons
        }
    }
    
    // MARK: - Compact Map View
    
    private var compactMapView: some View {
        ZStack(alignment: .topTrailing) {
            LiveTrackingMapView(routeCoordinates: viewModel.routeCoordinates)
                .frame(height: 180)
            
            Button(action: {
                withAnimation(.spring(response: 0.4)) {
                    isMapExpanded = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Expanded Map View
    
    private var expandedMapView: some View {
        ZStack(alignment: .topTrailing) {
            LiveTrackingMapView(routeCoordinates: viewModel.routeCoordinates)
                .frame(height: UIScreen.main.bounds.height * 0.5)
            
            Button(action: {
                withAnimation(.spring(response: 0.4)) {
                    isMapExpanded = false
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(spacing: 20) {
            // Primary Metrics
            HStack(spacing: 0) {
                // Time
                VStack(spacing: 6) {
                    Text(viewModel.formattedElapsedTime)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(limeGreen)
                        .contentTransition(.numericText())
                    
                    Text("Duration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 50)
                
                // Distance
                VStack(spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.formattedDistance)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        Text(viewModel.distanceUnit)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Text("Distance")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 20)
            
            // Secondary Metrics
            HStack(spacing: 12) {
                LiveMetricTile(
                    value: viewModel.formattedAveragePace,
                    unit: "/km",
                    label: "Pace",
                    icon: "speedometer",
                    color: limeGreen
                )
                
                LiveMetricTile(
                    value: viewModel.formattedCalories,
                    unit: "kcal",
                    label: "Calories",
                    icon: "flame.fill",
                    color: .orange
                )
                
                LiveMetricTile(
                    value: viewModel.formattedElevation,
                    unit: "m",
                    label: "Elevation",
                    icon: "arrow.up.right",
                    color: Color(hex: "5AC8FA")
                )
            }
            .padding(.horizontal, 20)
            
            // Current Pace Badge
            if viewModel.currentPace > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(limeGreen)
                    
                    Text("Current: \(viewModel.formattedCurrentPace)/km")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(limeGreen.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            // Discard Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showDiscardConfirmation = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .stroke(Color.red, lineWidth: 3)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            // Pause/Resume Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.3)) {
                    if viewModel.isPaused {
                        viewModel.resumeWorkout()
                    } else {
                        viewModel.pauseWorkout()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isPaused ? limeGreen : Color.white)
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            
            // Finish Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await viewModel.finishWorkout()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(darkGreen)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(limeGreen)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.bottom, 24)
        .background(Color.black)
    }
    
    // MARK: - Finishing View
    
    private var finishingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(limeGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: limeGreen))
                    .scaleEffect(1.8)
            }
            
            VStack(spacing: 8) {
                Text("Saving Workout...")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Please wait")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Try Again") {
                viewModel.dismissError()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(limeGreen)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Live Metric Tile

private struct LiveMetricTile: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Activity Type Card

struct ActivityTypeCard: View {
    let type: WorkoutActivityType
    let isSelected: Bool
    let action: () -> Void
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? limeGreen : Color.white.opacity(0.1))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                }
                
                Text(type.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? limeGreen : Color.white.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Metric Tile

struct MetricTile: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(limeGreen.opacity(0.8))
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Success Hero
                ZStack {
                    Circle()
                        .fill(limeGreen)
                        .frame(width: 110, height: 110)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.black)
                }
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                
                // Title
                VStack(spacing: 8) {
                    Text("Workout Complete!")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Image(systemName: summary.activityType.icon)
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(summary.activityType.rawValue)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(limeGreen)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                
                // Primary Stats Card
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        SummaryStatView(
                            value: summary.formattedDistance,
                            label: "Distance"
                        )
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1, height: 50)
                        
                        SummaryStatView(
                            value: summary.formattedDuration,
                            label: "Duration"
                        )
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1, height: 50)
                        
                        SummaryStatView(
                            value: summary.formattedPace,
                            label: "Avg Pace"
                        )
                    }
                }
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 30)
                
                // Secondary Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    SummaryDetailCard(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: summary.formattedCalories,
                        label: "Calories"
                    )
                    
                    SummaryDetailCard(
                        icon: "arrow.up.right",
                        iconColor: limeGreen,
                        value: "\(Int(summary.totalElevationGain))m",
                        label: "Elevation"
                    )
                    
                    if let avgHR = summary.averageHeartRate {
                        SummaryDetailCard(
                            icon: "heart.fill",
                            iconColor: .red,
                            value: "\(avgHR)",
                            label: "Avg Heart Rate"
                        )
                    }
                    
                    if let maxHR = summary.maxHeartRate {
                        SummaryDetailCard(
                            icon: "heart.fill",
                            iconColor: .red,
                            value: "\(maxHR)",
                            label: "Max Heart Rate"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 40)
                
                // Route Map
                if !summary.routePoints.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "map.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(limeGreen)
                            
                            Text("Your Route")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        SummaryMapView(routePoints: summary.routePoints)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.horizontal, 20)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 50)
                }
                
                // Done Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(limeGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 60)
            }
            .padding(.vertical, 40)
        }
        .background(Color.black)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Summary Stat View

struct SummaryStatView: View {
    let value: String
    let label: String
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(limeGreen)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Summary Detail Card

struct SummaryDetailCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Summary Map View

struct SummaryMapView: View {
    let routePoints: [LocationPoint]
    
    var body: some View {
        SummaryRouteMapView(routePoints: routePoints)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveActivityTrackingView()
    }
}
