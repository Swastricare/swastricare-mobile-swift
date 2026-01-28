//
//  LiveActivityTrackingView.swift
//  swastricare-mobile-swift
//
//  Live GPS Activity Tracking View
//  Strava-like real-time workout tracking UI
//

import SwiftUI
import MapKit

// MARK: - Live Activity Tracking View

struct LiveActivityTrackingView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = LiveActivityViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDiscardConfirmation = false
    @State private var isMapExpanded = false
    
    private let accentGreen = Color(hex: "22C55E")
    private let accentBlue = Color(hex: "4F46E5")
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
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
        VStack(spacing: 32) {
            Spacer()
            
            // Title
            VStack(spacing: 8) {
                Text("Choose Activity")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Select the type of workout you want to track")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Activity Type Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Location Permission Warning
            if !viewModel.locationAuthStatus.canTrack {
                locationPermissionCard
            }
            
            // Start Button
            Button(action: {
                Task {
                    await viewModel.startWorkout()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Start Workout")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Location Permission Card
    
    private var locationPermissionCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                    .foregroundColor(.orange)
                
                Text("Location Access Required")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Text("Enable location access to track your route and distance.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button("Enable Location") {
                Task {
                    await viewModel.requestLocationPermission()
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.orange)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }
    
    // MARK: - Countdown View
    
    private func countdownView(_ value: Int) -> some View {
        VStack {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(accentGreen.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 3.0)
                    .stroke(accentGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: value)
                
                Text("\(value)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
            
            Text("Get Ready!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Active Tracking View
    
    private var activeTrackingView: some View {
        VStack(spacing: 0) {
            // Map Section
            if isMapExpanded {
                expandedMapView
            } else {
                compactMapView
            }
            
            // Metrics Section
            metricsSection
            
            // Control Buttons
            controlButtons
        }
    }
    
    // MARK: - Compact Map View
    
    private var compactMapView: some View {
        ZStack(alignment: .topTrailing) {
            LiveTrackingMapView(routeCoordinates: viewModel.routeCoordinates)
                .frame(height: 200)
            
            Button(action: {
                withAnimation(.spring()) {
                    isMapExpanded = true
                }
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
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
                withAnimation(.spring()) {
                    isMapExpanded = false
                }
            }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(12)
        }
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(spacing: 24) {
            // Primary Metrics - Time and Distance
            HStack(spacing: 0) {
                // Time
                VStack(spacing: 4) {
                    Text(viewModel.formattedElapsedTime)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 60)
                
                // Distance
                VStack(spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.formattedDistance)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        Text(viewModel.distanceUnit)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 24)
            
            // Secondary Metrics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                MetricTile(
                    value: viewModel.formattedAveragePace,
                    unit: "/km",
                    label: "Avg Pace",
                    icon: "speedometer"
                )
                
                MetricTile(
                    value: viewModel.formattedCalories,
                    unit: "kcal",
                    label: "Calories",
                    icon: "flame.fill"
                )
                
                MetricTile(
                    value: viewModel.formattedElevation,
                    unit: "m",
                    label: "Elevation",
                    icon: "arrow.up.right"
                )
            }
            .padding(.horizontal, 24)
            
            // Current Pace (if moving)
            if viewModel.currentPace > 0 {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(accentGreen)
                    
                    Text("Current Pace: \(viewModel.formattedCurrentPace)/km")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            // Discard Button
            Button(action: {
                showDiscardConfirmation = true
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
            }
            
            // Pause/Resume Button
            Button(action: {
                withAnimation {
                    if viewModel.isPaused {
                        viewModel.resumeWorkout()
                    } else {
                        viewModel.pauseWorkout()
                    }
                }
            }) {
                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 80, height: 80)
                    .background(viewModel.isPaused ? accentGreen : Color.white)
                    .clipShape(Circle())
            }
            
            // Finish Button
            Button(action: {
                Task {
                    await viewModel.finishWorkout()
                }
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(accentBlue)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 24)
        .padding(.bottom, 20)
        .background(Color.black)
    }
    
    // MARK: - Finishing View
    
    private var finishingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Saving Workout...")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                viewModel.dismissError()
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Activity Type Card

struct ActivityTypeCard: View {
    let type: WorkoutActivityType
    let isSelected: Bool
    let action: () -> Void
    
    private let accentGreen = Color(hex: "22C55E")
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(isSelected ? accentGreen : .white.opacity(0.7))
                
                Text(type.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? accentGreen : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
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
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void
    
    private let accentGreen = Color(hex: "22C55E")
    private let accentBlue = Color(hex: "4F46E5")
    
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(accentGreen.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(accentGreen)
                }
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                
                // Title
                VStack(spacing: 8) {
                    Text("Workout Complete!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(summary.activityType.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                
                // Primary Stats
                HStack(spacing: 0) {
                    SummaryStatView(
                        value: summary.formattedDistance,
                        label: "Distance"
                    )
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 50)
                    
                    SummaryStatView(
                        value: summary.formattedDuration,
                        label: "Duration"
                    )
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 50)
                    
                    SummaryStatView(
                        value: summary.formattedPace,
                        label: "Avg Pace"
                    )
                }
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 30)
                
                // Secondary Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SummaryDetailCard(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: summary.formattedCalories,
                        label: "Calories"
                    )
                    
                    SummaryDetailCard(
                        icon: "arrow.up.right",
                        iconColor: accentGreen,
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
                .padding(.horizontal, 24)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 40)
                
                // Route Map
                if !summary.routePoints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Route")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        SummaryMapView(routePoints: summary.routePoints)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 50)
                }
                
                // Done Button
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 60)
            }
            .padding(.vertical, 40)
        }
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
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
