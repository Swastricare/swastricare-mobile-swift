//
//  ActivityDetailView.swift
//  swastricare-mobile-swift
//
//  Detailed view for a single walking/running activity with analytics
//

import SwiftUI
import MapKit

// MARK: - Detail Tab Enum

enum ActivityDetailTab: String, CaseIterable {
    case overview = "Overview"
    case splits = "Splits"
    case pace = "Pace"
    case heartRate = "Heart Rate"
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .splits: return "ruler"
        case .pace: return "speedometer"
        case .heartRate: return "heart.fill"
        }
    }
}

struct ActivityDetailView: View {
    
    // MARK: - Properties
    
    let activity: RouteActivity
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    @State private var isAnimating = false
    @State private var mapRegion: MKCoordinateRegion
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var shareImage: UIImage?
    
    // Analytics state
    @State private var selectedTab: ActivityDetailTab = .overview
    @State private var analytics: ActivityAnalytics?
    @State private var isLoadingAnalytics = false
    
    private let accentBlue = AppColors.accentBlue
    private let accentRed = AppColors.accentRed
    private let analyticsService = RunAnalyticsService.shared
    
    // MARK: - Init
    
    init(activity: RouteActivity) {
        self.activity = activity
        
        if let firstCoord = activity.routeCoordinates.first {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: firstCoord.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            ))
        } else {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            ))
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            PremiumBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Map View (compact when not on overview)
                    mapSection
                        .frame(height: selectedTab == .overview ? 280 : 160)
                    
                    // Activity Info Header
                    activityHeader
                    
                    // Tab Selector
                    tabSelector
                    
                    // Tab Content
                    tabContent
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: shareActivity) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("Delete Activity", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteActivity()
            }
        } message: {
            Text("Are you sure you want to delete this activity? This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityShareSheet(image: image, activity: activity)
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        
                        Text("Deleting...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
            loadAnalytics()
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityDetailTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = tab
                            }
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
        .animation(.spring(response: 0.5).delay(0.15), value: isAnimating)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .splits:
            splitsContent
        case .pace:
            paceContent
        case .heartRate:
            heartRateContent
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 24) {
            mainStatsGrid
            detailedMetricsSection
            timeAnalysisSection
            actionButtonsSection
        }
    }
    
    // MARK: - Splits Content
    
    private var splitsContent: some View {
        VStack(spacing: 16) {
            if isLoadingAnalytics {
                loadingView
            } else if let analytics = analytics, !analytics.splits.isEmpty {
                SplitsListView(
                    splits: analytics.splits,
                    bestSplitIndex: analytics.bestSplitIndex,
                    worstSplitIndex: analytics.worstSplitIndex
                )
            } else {
                emptyAnalyticsView(
                    icon: "ruler",
                    title: "No Splits Data",
                    message: "Splits are calculated for activities with GPS tracking over 1 km"
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Pace Content
    
    private var paceContent: some View {
        VStack(spacing: 16) {
            if isLoadingAnalytics {
                loadingView
            } else if let analytics = analytics, !analytics.paceSamples.isEmpty {
                PaceChartView(
                    paceSamples: analytics.paceSamples,
                    avgPaceSecondsPerKm: analytics.avgPaceSecondsPerKm,
                    bestPaceSecondsPerKm: analytics.bestPaceSecondsPerKm,
                    worstPaceSecondsPerKm: analytics.worstPaceSecondsPerKm
                )
            } else {
                emptyAnalyticsView(
                    icon: "speedometer",
                    title: "No Pace Data",
                    message: "Pace analysis requires GPS tracking during the activity"
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Heart Rate Content
    
    private var heartRateContent: some View {
        VStack(spacing: 16) {
            if isLoadingAnalytics {
                loadingView
            } else if let analytics = analytics, !analytics.heartRateSamples.isEmpty {
                RunHeartRateChartView(
                    heartRateSamples: analytics.heartRateSamples,
                    zoneDistribution: analytics.zoneDistribution,
                    avgHeartRate: analytics.avgHeartRate,
                    maxHeartRate: analytics.maxHeartRate,
                    minHeartRate: analytics.minHeartRate,
                    userMaxHR: 190 // Could be fetched from user profile
                )
            } else {
                emptyAnalyticsView(
                    icon: "heart.text.square",
                    title: "No Heart Rate Data",
                    message: "Heart rate data requires an Apple Watch or compatible monitor"
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading analytics...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty Analytics View
    
    private func emptyAnalyticsView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Load Analytics
    
    private func loadAnalytics() {
        isLoadingAnalytics = true
        
        Task {
            // Convert route coordinates to RouteCoordinate format
            let isoFormatter = ISO8601DateFormatter()
            let routeCoords = activity.routeCoordinates.enumerated().map { index, coord -> RouteCoordinate in
                // Use actual timestamp if available, otherwise estimate based on activity duration
                let timestamp: Date
                if let coordTimestamp = coord.timestamp {
                    timestamp = coordTimestamp
                } else {
                    let progress = Double(index) / Double(max(activity.routeCoordinates.count - 1, 1))
                    timestamp = activity.startTime.addingTimeInterval(activity.duration * progress)
                }
                
                return RouteCoordinate(
                    lat: coord.latitude,
                    lng: coord.longitude,
                    alt: coord.altitude,
                    ts: isoFormatter.string(from: timestamp)
                )
            }
            
            // Generate mock heart rate samples for demo (in production, fetch from HealthKit)
            let heartRateSamples = RunAnalyticsService.generateMockRunHeartRateSamples(
                durationMinutes: Int(activity.duration / 60)
            )
            
            // Calculate analytics
            let calculatedAnalytics = analyticsService.calculateActivityAnalytics(
                coordinates: routeCoords,
                heartRateSamples: heartRateSamples,
                maxHeartRate: 190
            )
            
            await MainActor.run {
                withAnimation {
                    self.analytics = calculatedAnalytics
                    self.isLoadingAnalytics = false
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func shareActivity() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Generate share image
        let shareView = ActivityShareCardView(activity: activity)
        let renderer = ImageRenderer(content: shareView.frame(width: 400))
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
    
    private func deleteActivity() {
        isDeleting = true
        
        Task {
            let success = await viewModel.deleteActivity(activity)
            
            await MainActor.run {
                isDeleting = false
                
                if success {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Small delay to show success feedback before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                } else {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    // Show error alert if there's an error message
                    if let errorMessage = viewModel.errorMessage {
                        // Error will be shown via the viewModel's errorMessage
                        print("Delete error: \(errorMessage)")
                    }
                }
            }
        }
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            ActivityRouteMapView(routeCoordinates: activity.routeCoordinates)
                .clipShape(RoundedRectangle(cornerRadius: selectedTab == .overview ? 24 : 16))
                .overlay(
                    RoundedRectangle(cornerRadius: selectedTab == .overview ? 24 : 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            // Expand Button (only show on overview)
            if selectedTab == .overview {
                Button(action: {
                    // Expand map action
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(16)
            }
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.3), value: selectedTab)
    }
    
    // MARK: - Activity Header
    
    private var activityHeader: some View {
        HStack(spacing: 16) {
            // Activity Type Icon
            ZStack {
                Circle()
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(activity.formattedTimeRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Duration Badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedDuration)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(accentBlue)
                
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Main Stats Grid
    
    private var mainStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                icon: "figure.walk",
                iconColor: .green,
                value: "\(activity.steps)",
                label: "Steps"
            )
            
            StatCard(
                icon: "map",
                iconColor: accentBlue,
                value: activity.formattedDistance,
                label: "Distance"
            )
            
            StatCard(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(activity.calories)",
                label: "Calories"
            )
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.15), value: isAnimating)
    }
    
    // MARK: - Detailed Metrics Section
    
    private var detailedMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Activity Metrics")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                DetailedMetricRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Average Heart Rate",
                    value: "\(activity.averageBPM) BPM"
                )
                
                Divider()
                
                DetailedMetricRow(
                    icon: "speedometer",
                    iconColor: accentBlue,
                    title: "Average Pace",
                    value: calculatePace()
                )
                
                Divider()
                
                DetailedMetricRow(
                    icon: "arrow.up.right",
                    iconColor: .green,
                    title: "Elevation Gain",
                    value: "12 m"
                )
                
                Divider()
                
                DetailedMetricRow(
                    icon: "figure.run",
                    iconColor: .purple,
                    title: "Cadence",
                    value: "\(Int.random(in: 150...180)) spm"
                )
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Time Analysis Section
    
    private var timeAnalysisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Time Analysis")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                TimeAnalysisRow(title: "Start Time", value: formatTime(activity.startTime))
                Divider()
                TimeAnalysisRow(title: "End Time", value: formatTime(activity.endTime))
                Divider()
                TimeAnalysisRow(title: "Active Time", value: activity.formattedDuration)
                Divider()
                TimeAnalysisRow(title: "Rest Time", value: "0 min")
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
        .animation(.spring(response: 0.5).delay(0.25), value: isAnimating)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Share Button
            Button(action: shareActivity) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Share Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Delete Button
            Button(action: {
                showDeleteAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Delete Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(accentRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accentRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentRed.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 35)
        .animation(.spring(response: 0.5).delay(0.3), value: isAnimating)
    }
    
    // MARK: - Helper Methods
    
    private func calculatePace() -> String {
        guard activity.distance > 0 else { return "--:--" }
        let minutesPerKm = activity.duration / 60.0 / activity.distance
        let mins = Int(minutesPerKm)
        let secs = Int((minutesPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d /km", mins, secs)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(iconColor)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Detailed Metric Row

struct DetailedMetricRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Time Analysis Row

struct TimeAnalysisRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: ActivityDetailTab
    let isSelected: Bool
    let action: () -> Void
    
    private let accentBlue = AppColors.accentBlue
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? accentBlue : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActivityDetailView(activity: MockRunActivityData.generateMockActivities()[0])
    }
}

// MARK: - Activity Share Card View

struct ActivityShareCardView: View {
    let activity: RouteActivity
    
    private let accentBlue = AppColors.accentBlue
    private let accentGreen = AppColors.accentGreen
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack(alignment: .topLeading) {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        activity.type.color,
                        activity.type.color.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 160)
                
                // Overlay pattern
                GeometryReader { geo in
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        path.move(to: CGPoint(x: width * 0.7, y: 0))
                        path.addLine(to: CGPoint(x: width, y: 0))
                        path.addLine(to: CGPoint(x: width, y: height * 0.6))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.1))
                }
                .frame(height: 160)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: activity.type.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // App branding
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                            Text("SwastricCare")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Text(activity.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(formattedDate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(20)
            }
            .frame(height: 160)
            
            // Stats section
            VStack(spacing: 20) {
                // Main stat - Distance
                VStack(spacing: 4) {
                    Text(activity.formattedDistance)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("DISTANCE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
                .padding(.top, 24)
                
                // Stats grid
                HStack(spacing: 0) {
                    ShareStatItem(
                        icon: "clock.fill",
                        value: activity.formattedDuration,
                        label: "Duration"
                    )
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 50)
                    
                    ShareStatItem(
                        icon: "figure.walk",
                        value: "\(activity.steps)",
                        label: "Steps"
                    )
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 50)
                    
                    ShareStatItem(
                        icon: "flame.fill",
                        value: "\(activity.calories)",
                        label: "Calories"
                    )
                }
                .padding(.horizontal, 16)
                
                // Additional stats row
                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        
                        Text("\(activity.averageBPM) BPM")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .foregroundColor(accentBlue)
                        
                        Text(calculatePace())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(UIColor.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy • h:mm a"
        return formatter.string(from: activity.startTime)
    }
    
    private func calculatePace() -> String {
        guard activity.distance > 0 else { return "--:--" }
        let minutesPerKm = activity.duration / 60.0 / activity.distance
        let mins = Int(minutesPerKm)
        let secs = Int((minutesPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d /km", mins, secs)
    }
}

// MARK: - Share Stat Item

struct ShareStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accentBlue)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Activity Share Sheet

struct ActivityShareSheet: View {
    let image: UIImage
    let activity: RouteActivity
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedToast = false
    @State private var showSavedToast = false
    
    private let accentBlue = AppColors.accentBlue
    private let accentGreen = AppColors.accentGreen
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    // Preview of the share card
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.top, 20)
                    
                    Text("Share your achievement!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Share options
                    VStack(spacing: 12) {
                        // Share to social
                        Button(action: shareToSocial) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text("Share to...")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .foregroundColor(.white)
                            .padding(16)
                            .background(accentBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Save to photos
                        Button(action: saveToPhotos) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(accentGreen)
                                
                                Text("Save to Photos")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if showSavedToast {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                        Text("Saved!")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(accentGreen)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(accentGreen)
                                }
                            }
                            .foregroundColor(.primary)
                            .padding(16)
                            .background(accentGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accentGreen.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Copy stats
                        Button(action: copyStats) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text("Copy Stats")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if showCopiedToast {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                        Text("Copied!")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(accentGreen)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                            .padding(16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                // Success Toast Overlay
                if showSavedToast {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text("Saved to Photos")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(accentGreen)
                        .clipShape(Capsule())
                        .shadow(color: accentGreen.opacity(0.4), radius: 10, x: 0, y: 5)
                        .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Share Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func shareToSocial() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let text = generateShareText()
        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func saveToPhotos() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4)) {
            showSavedToast = true
        }
        
        // Auto dismiss after showing toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    private func copyStats() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        let text = generateShareText()
        UIPasteboard.general.string = text
        
        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
    
    private func generateShareText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let dateStr = formatter.string(from: activity.startTime)
        
        return """
        🏃 \(activity.name)
        📅 \(dateStr)
        📏 Distance: \(activity.formattedDistance)
        ⏱️ Duration: \(activity.formattedDuration)
        👣 Steps: \(activity.steps)
        🔥 Calories: \(activity.calories)
        ❤️ Avg Heart Rate: \(activity.averageBPM) BPM
        
        Tracked with SwastricCare 💚
        """
    }
}
