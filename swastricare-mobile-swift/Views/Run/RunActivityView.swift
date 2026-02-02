//
//  RunActivityView.swift
//  swastricare-mobile-swift
//
//  Steps & Walk/Run Activity Tracking View
//  Designed following iOS-style minimal, clean UI
//

import SwiftUI
import MapKit

struct RunActivityView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    
    // MARK: - State
    
    @State private var isAnimating = false
    @State private var showActivityDetail: RouteActivity? = nil
    @State private var showLiveTracking = false
    @State private var showFullCalendar = false
    
    @Namespace private var namespace
    
    // MARK: - Constants
    
    private let accentBlue = AppColors.accentBlue
    private let accentGreen = AppColors.accentGreen
    private let backgroundGray = Color(hex: "F8F9FA")
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            PremiumBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Walk & Run Activity Header
                    walkRunActivityHeader
                    
                    // Start Workout Button
                    startWorkoutButton
                    
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Metrics Row
                    metricsRow
                    
                    // Weekly Progress Chart
                    // weeklyProgressSection
                    
                    // Run Calendar (compact)
//                    runCalendarSection
                    
                    // Route Activities
                    routeActivitiesSection
                    
                    // Highlights Section
                    highlightsSection
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showLiveTracking) {
            NavigationStack {
                LiveActivityTrackingView()
            }
        }
        .sheet(isPresented: $showFullCalendar) {
            NavigationStack {
                ScrollView {
                    RunCalendarView(activities: viewModel.activities)
                        .padding(.top, 8)
                }
                .navigationTitle("Run Calendar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showFullCalendar = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("Run")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Walk & Run Activity Header
    
    private var walkRunActivityHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Walk & Run Activity")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                // Running Icon
                Image(systemName: "figure.run")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(accentBlue)
                
                // Step Count
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(viewModel.totalSteps)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    Text("Steps")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }
    
    // MARK: - Start Workout Button
    
    private var startWorkoutButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showLiveTracking = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentGreen)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Workout")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Track GPS, distance, and route")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentGreen)
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [accentGreen.opacity(0.1), accentGreen.opacity(0.1)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: accentGreen.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.08), value: isAnimating)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ActivityTimeRange.allCases) { range in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.selectTimeRange(range)
                    }
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }) {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.selectedTimeRange == range ? .white : .primary.opacity(0.6))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if viewModel.selectedTimeRange == range {
                                    Capsule()
                                        .fill(Color(hex: "1F2937"))
                                        .matchedGeometryEffect(id: "TIME_RANGE_TAB", in: namespace)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(Color(UIColor.systemGray6))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Metrics Row
    
    private var metricsRow: some View {
        HStack(spacing: 0) {
            MetricItem(
                title: "Distance",
                value: String(format: "%.3f", viewModel.totalDistance),
                unit: "m",
                isLarge: true
            )
            
            Divider()
                .frame(height: 50)
            
            MetricItem(
                title: "Calories",
                value: String(format: "%.3f", Double(viewModel.totalCalories) / 1000.0),
                unit: "Kcal",
                isLarge: true
            )
            
            Divider()
                .frame(height: 50)
            
            MetricItem(
                title: "Points",
                value: String(format: "%.3f", Double(viewModel.totalPoints) / 1000.0),
                unit: "",
                isLarge: true
            )
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Route Activities Section
    
    private var routeActivitiesSection: some View {
        VStack(spacing: 12) {
            if viewModel.activities.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No activities yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Start a workout to track your activities")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Section Header
                HStack {
                    Text("Recent Activities")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if viewModel.activities.count > 5 {
                        NavigationLink(destination: RunStatsAnalyticsView()) {
                            HStack(spacing: 4) {
                                Text("See All")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(accentBlue)
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(accentBlue)
                            }
                        }
                    } else {
                        Text("\(viewModel.activities.count) activities")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
                
                ForEach(Array(viewModel.activities.prefix(5))) { activity in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            RouteActivityCardContent(activity: activity)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
        .animation(.spring(response: 0.5).delay(0.25), value: isAnimating)
    }
    
    // MARK: - Weekly Progress Section
    
    private var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CompactWeeklyProgressView(
                dailySummaries: viewModel.dailySummaries,
                goalDistanceKm: viewModel.activityGoal.dailyDistanceGoal * 7 // Weekly goal
            )
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 32)
        .animation(.spring(response: 0.5).delay(0.27), value: isAnimating)
    }
    
    // MARK: - Run Calendar Section
    
    private var runCalendarSection: some View {
        CompactRunCalendarView(
            activities: viewModel.activities,
            onViewFullCalendar: {
                showFullCalendar = true
            }
        )
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 34)
        .animation(.spring(response: 0.5).delay(0.29), value: isAnimating)
    }
    
    // MARK: - Highlights Section
    
    private var highlightsSection: some View {
        Group {
            if let weeklyComparison = viewModel.weeklyComparison {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Highlights")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            Text("See All")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(accentBlue)
                        }
                    }
                    
                    // Insight Text
                    Text(weeklyComparison.insightText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                    
                    // Weekly Comparison Bars
                    VStack(spacing: 12) {
                        // Current Week
                        WeeklyComparisonBar(
                            average: weeklyComparison.currentWeekAverage,
                            dateRange: weeklyComparison.currentWeekDateRange,
                            maxValue: max(weeklyComparison.currentWeekAverage, weeklyComparison.previousWeekAverage),
                            isCurrent: true,
                            accentColor: accentBlue
                        )
                        
                        // Previous Week
                        WeeklyComparisonBar(
                            average: weeklyComparison.previousWeekAverage,
                            dateRange: weeklyComparison.previousWeekDateRange,
                            maxValue: max(weeklyComparison.currentWeekAverage, weeklyComparison.previousWeekAverage),
                            isCurrent: false,
                            accentColor: accentBlue
                        )
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 35)
        .animation(.spring(response: 0.5).delay(0.3), value: isAnimating)
    }
}

// MARK: - Metric Item Component

struct MetricItem: View {
    let title: String
    let value: String
    let unit: String
    var isLarge: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: isLarge ? 28 : 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Route Activity Card Content

struct RouteActivityCardContent: View {
    let activity: RouteActivity
    
    @State private var mapRegion: MKCoordinateRegion
    
    init(activity: RouteActivity) {
        self.activity = activity
        
        // Initialize map region based on all route coordinates (bounding box)
        _mapRegion = State(initialValue: Self.calculateBoundingRegion(for: activity.routeCoordinates))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Map Preview
            ZStack {
                Map(coordinateRegion: $mapRegion, interactionModes: [])
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        // Route overlay simulation
                        RouteOverlayView(coordinates: activity.routeCoordinates)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )
            }
            .onAppear {
                // Update region when view appears to ensure correct display
                mapRegion = Self.calculateBoundingRegion(for: activity.routeCoordinates)
            }
            .onChange(of: activity.routeCoordinates) { newCoordinates in
                // Update region when coordinates change
                mapRegion = Self.calculateBoundingRegion(for: newCoordinates)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Time Range with icon
                HStack(spacing: 4) {
                    Image(systemName: activity.type.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(activity.formattedTimeRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Activity Name
                Text(activity.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                // BPM and Distance
                HStack(spacing: 8) {
                    Text("AVG \(activity.averageBPM) BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(activity.formattedDistance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Methods
    
    /// Calculates a bounding region that encompasses all route coordinates
    static func calculateBoundingRegion(for coordinates: [CoordinatePoint]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Default to a known location if no coordinates
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // If only one coordinate, center on it with a small span
        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: coordinates[0].coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Calculate bounding box from all coordinates
        let lats = coordinates.map { $0.latitude }
        let longs = coordinates.map { $0.longitude }
        
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLong = longs.min(),
              let maxLong = longs.max() else {
            // Fallback if calculation fails
            return MKCoordinateRegion(
                center: coordinates[0].coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2.0
        let centerLong = (minLong + maxLong) / 2.0
        
        // Calculate span with padding (add 20% padding)
        let latDelta = max((maxLat - minLat) * 1.2, 0.001) // Minimum span
        let longDelta = max((maxLong - minLong) * 1.2, 0.001) // Minimum span
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLong),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: longDelta)
        )
    }
}

// MARK: - Route Overlay View

struct RouteOverlayView: View {
    let coordinates: [CoordinatePoint]
    
    var body: some View {
        GeometryReader { geometry in
            if coordinates.count >= 2 {
                Path { path in
                    let points = normalizedPoints(in: geometry.size)
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(AppColors.accentBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
    
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !coordinates.isEmpty else { return [] }
        
        let lats = coordinates.map { $0.latitude }
        let longs = coordinates.map { $0.longitude }
        
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLong = longs.min(),
              let maxLong = longs.max() else { return [] }
        
        let latRange = max(maxLat - minLat, 0.001)
        let longRange = max(maxLong - minLong, 0.001)
        
        return coordinates.map { coord in
            let x = ((coord.longitude - minLong) / longRange) * (size.width - 20) + 10
            let y = (1 - ((coord.latitude - minLat) / latRange)) * (size.height - 20) + 10
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Weekly Comparison Bar

struct WeeklyComparisonBar: View {
    let average: Double
    let dateRange: String
    let maxValue: Double
    let isCurrent: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Average value
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", average))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Km / day")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 90, alignment: .leading)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.systemGray5))
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isCurrent ? accentColor : accentColor.opacity(0.4))
                        .frame(width: max(geometry.size.width * (average / maxValue), 0))
                    
                    // Date Range Label
                    Text(dateRange)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                }
            }
            .frame(height: 32)
        }
    }
}

// MARK: - Run Stats Analytics View

struct RunStatsAnalyticsView: View {
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    @State private var isAnimating = false
    @State private var selectedTab: AnalyticsTab = .overview
    
    private let accentBlue = AppColors.accentBlue
    private let accentGreen = AppColors.accentGreen
    
    enum AnalyticsTab: String, CaseIterable {
        case overview = "Overview"
        case performance = "Performance"
        case calendar = "Calendar"
        case activities = "Activities"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .performance: return "bolt.fill"
            case .calendar: return "calendar"
            case .activities: return "list.bullet"
            }
        }
    }
    
    var body: some View {
        ZStack {
            PremiumBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab Selector
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .performance:
                            performanceContent
                        case .calendar:
                            calendarContent
                        case .activities:
                            activitiesContent
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Stats & Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .semibold))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? accentBlue : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedTab == tab ? Color.clear : Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 20)
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 24) {
            // Enhanced Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                EnhancedStatCard(
                    title: "Total Steps",
                    value: "\(viewModel.totalSteps)",
                    subtitle: "steps",
                    icon: "figure.walk",
                    color: accentGreen,
                    trend: 12.5,
                    // progress: viewModel.stepsGoalProgress
                )
                
                EnhancedStatCard(
                    title: "Distance",
                    value: String(format: "%.1f", viewModel.totalDistance),
                    subtitle: "kilometers",
                    icon: "map",
                    color: accentBlue,
                    trend: 8.3
                )
                
                EnhancedStatCard(
                    title: "Calories",
                    value: String(format: "%.0f", Double(viewModel.totalCalories)),
                    subtitle: "kcal burned",
                    icon: "flame.fill",
                    color: .orange,
                    trend: 15.7
                )
                
                EnhancedStatCard(
                    title: "Points",
                    value: "\(viewModel.totalPoints)",
                    subtitle: "activity points",
                    icon: "star.fill",
                    color: .yellow,
                    trend: -2.1
                )
            }
            .padding(.horizontal, 20)
            
            // Weekly Distance Chart
            WeeklyDistanceChart(
                data: generateWeeklyData(),
                color: accentBlue
            )
            .padding(.horizontal, 20)
            
            // Activity Streak
            ActivityStreakCard(
                currentStreak: calculateCurrentStreak(),
                longestStreak: calculateLongestStreak(),
                color: accentGreen
            )
            .padding(.horizontal, 20)
            
            // Quick Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Stats")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                QuickStatsGrid(
                    avgPace: calculateAvgPace(),
                    avgHeartRate: calculateAvgHeartRate(),
                    totalTime: calculateTotalTime(),
                    avgDistance: viewModel.totalDistance / Double(max(viewModel.activities.count, 1))
                )
                .padding(.horizontal, 20)
            }
            
            // Weekly Comparison (if available)
            if let weeklyComparison = viewModel.weeklyComparison {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accentBlue)
                        
                        Text("Weekly Comparison")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text(weeklyComparison.insightText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                    
                    VStack(spacing: 12) {
                        WeeklyComparisonBar(
                            average: weeklyComparison.currentWeekAverage,
                            dateRange: weeklyComparison.currentWeekDateRange,
                            maxValue: max(weeklyComparison.currentWeekAverage, weeklyComparison.previousWeekAverage),
                            isCurrent: true,
                            accentColor: accentBlue
                        )
                        
                        WeeklyComparisonBar(
                            average: weeklyComparison.previousWeekAverage,
                            dateRange: weeklyComparison.previousWeekDateRange,
                            maxValue: max(weeklyComparison.currentWeekAverage, weeklyComparison.previousWeekAverage),
                            isCurrent: false,
                            accentColor: accentBlue
                        )
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5), value: isAnimating)
    }
    
    // MARK: - Performance Content
    
    private var performanceContent: some View {
        VStack(spacing: 24) {
            // Performance Insights
            PerformanceInsightsCard(insights: generateInsights())
                .padding(.horizontal, 20)
            
            // Personal Records
            PersonalRecordsSection(records: generatePersonalRecords())
                .padding(.horizontal, 20)
            
            // Pace Distribution
            PaceDistributionChart(
                paceRanges: generatePaceDistribution(),
                color: accentBlue
            )
            .padding(.horizontal, 20)
            
            // Time of Day Analysis
            TimeOfDayAnalysis(distribution: generateTimeDistribution())
                .padding(.horizontal, 20)
            
            // Goals Progress
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentBlue)
                    
                    Text("Goals Progress")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                GoalProgressRow(
                    title: "Steps",
                    current: viewModel.activityGoal.currentSteps,
                    goal: viewModel.activityGoal.dailyStepsGoal,
                    color: accentGreen
                )
                
                GoalProgressRow(
                    title: "Distance",
                    current: Int(viewModel.activityGoal.currentDistance * 1000),
                    goal: Int(viewModel.activityGoal.dailyDistanceGoal * 1000),
                    unit: "m",
                    color: accentBlue
                )
                
                GoalProgressRow(
                    title: "Calories",
                    current: viewModel.activityGoal.currentCalories,
                    goal: viewModel.activityGoal.dailyCaloriesGoal,
                    color: .orange
                )
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Calendar Content
    
    private var calendarContent: some View {
        VStack(spacing: 24) {
            RunCalendarView(activities: viewModel.activities)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Activities Content
    
    private var activitiesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Activities")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.activities.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            if viewModel.activities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No activities yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Start a workout to track your activities")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .padding(.horizontal, 20)
            } else {
                ForEach(viewModel.activities) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        RouteActivityCardContent(activity: activity)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                }
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Helper Methods
    
    private func generateWeeklyData() -> [(day: String, distance: Double)] {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let calendar = Calendar.current
        let today = Date()
        
        return days.enumerated().map { index, day in
            guard let date = calendar.date(byAdding: .day, value: -(6 - index), to: today) else {
                return (day: day, distance: 0.0)
            }
            
            let dayActivities = viewModel.activities.filter { activity in
                calendar.isDate(activity.startTime, inSameDayAs: date)
            }
            
            let distance = dayActivities.reduce(0.0) { $0 + $1.distance }
            return (day: day, distance: distance)
        }
    }
    
    private func calculateCurrentStreak() -> Int {
        guard !viewModel.activities.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        while true {
            let hasActivity = viewModel.activities.contains { activity in
                calendar.isDate(activity.startTime, inSameDayAs: currentDate)
            }
            
            if hasActivity {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        guard !viewModel.activities.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedDates = viewModel.activities.map { $0.startTime }.sorted()
        
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i - 1]
            let currentDate = sortedDates[i]
            
            if let daysDifference = calendar.dateComponents([.day], from: previousDate, to: currentDate).day {
                if daysDifference == 1 {
                    currentStreak += 1
                    longestStreak = max(longestStreak, currentStreak)
                } else if daysDifference > 1 {
                    currentStreak = 1
                }
            }
        }
        
        return longestStreak
    }
    
    private func calculateAvgPace() -> String {
        let activities = viewModel.activities.filter { $0.distance > 0 }
        guard !activities.isEmpty else { return "--:--" }
        
        let totalPace = activities.reduce(0.0) { result, activity in
            let pace = activity.duration / 60.0 / activity.distance
            return result + pace
        }
        
        let avgPace = totalPace / Double(activities.count)
        let mins = Int(avgPace)
        let secs = Int((avgPace - Double(mins)) * 60)
        
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func calculateAvgHeartRate() -> Int {
        let activities = viewModel.activities.filter { $0.averageBPM > 0 }
        guard !activities.isEmpty else { return 0 }
        
        let total = activities.reduce(0) { $0 + $1.averageBPM }
        return total / activities.count
    }
    
    private func calculateTotalTime() -> String {
        let totalSeconds = viewModel.activities.reduce(0.0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func generateInsights() -> [PerformanceInsight] {
        var insights: [PerformanceInsight] = []
        
        // Consistency insight
        let activeDays = Set(viewModel.activities.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        insights.append(PerformanceInsight(
            icon: "checkmark.circle.fill",
            title: "Consistency",
            description: "You've been active on \(activeDays) different days",
            color: accentGreen
        ))
        
        // Distance progress
        if viewModel.percentageChange > 0 {
            insights.append(PerformanceInsight(
                icon: "arrow.up.right.circle.fill",
                title: "Distance Improved",
                description: String(format: "Up %.1f%% compared to last period", viewModel.percentageChange),
                color: accentBlue
            ))
        }
        
        // Best time of day
        let morningCount = viewModel.activities.filter { Calendar.current.component(.hour, from: $0.startTime) < 12 }.count
        if morningCount > viewModel.activities.count / 2 {
            insights.append(PerformanceInsight(
                icon: "sunrise.fill",
                title: "Morning Person",
                description: "Most of your workouts are in the morning",
                color: .orange
            ))
        }
        
        return insights
    }
    
    private func generatePersonalRecords() -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        
        if let longestRun = viewModel.activities.max(by: { $0.distance < $1.distance }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            records.append(PersonalRecord(
                title: "Longest Distance",
                value: String(format: "%.2f km", longestRun.distance),
                date: formatter.string(from: longestRun.startTime),
                icon: "map.fill"
            ))
        }
        
        if let longestDuration = viewModel.activities.max(by: { $0.duration < $1.duration }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            let hours = Int(longestDuration.duration) / 3600
            let minutes = (Int(longestDuration.duration) % 3600) / 60
            records.append(PersonalRecord(
                title: "Longest Duration",
                value: hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m",
                date: formatter.string(from: longestDuration.startTime),
                icon: "clock.fill"
            ))
        }
        
        if let mostSteps = viewModel.activities.max(by: { $0.steps < $1.steps }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            records.append(PersonalRecord(
                title: "Most Steps",
                value: "\(mostSteps.steps)",
                date: formatter.string(from: mostSteps.startTime),
                icon: "figure.walk"
            ))
        }
        
        return records
    }
    
    private func generatePaceDistribution() -> [(range: String, count: Int)] {
        let paceRanges = [
            ("< 5:00", 0.0..<5.0),
            ("5:00-6:00", 5.0..<6.0),
            ("6:00-7:00", 6.0..<7.0),
            ("7:00-8:00", 7.0..<8.0),
            ("> 8:00", 8.0..<100.0)
        ]
        
        return paceRanges.map { range in
            let count = viewModel.activities.filter { activity in
                guard activity.distance > 0 else { return false }
                let pace = activity.duration / 60.0 / activity.distance
                return pace >= range.1.lowerBound && pace < range.1.upperBound
            }.count
            return (range: range.0, count: count)
        }
    }
    
    private func generateTimeDistribution() -> [(time: String, count: Int)] {
        let timeRanges = [
            ("Morning", 5..<12),
            ("Afternoon", 12..<17),
            ("Evening", 17..<21),
            ("Night", 21..<24)
        ]
        
        return timeRanges.map { range in
            let count = viewModel.activities.filter { activity in
                let hour = Calendar.current.component(.hour, from: activity.startTime)
                return range.1.contains(hour)
            }.count
            return (time: range.0, count: count)
        }
    }
}

// MARK: - Run Stat Card

private struct RunStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Goal Progress Row

struct GoalProgressRow: View {
    let title: String
    let current: Int
    let goal: Int
    var unit: String = ""
    let color: Color
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(current) / Double(goal))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(current)\(unit.isEmpty ? "" : " \(unit)") / \(goal)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RunActivityView()
    }
}
