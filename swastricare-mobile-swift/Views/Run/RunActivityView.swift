//
//  RunActivityView.swift
//  swastricare-mobile-swift
//
//  Steps & Walk/Run Activity Tracking View
//  Redesigned with Movements+ UI - Lime Green, Dark Theme, Geometric Patterns
//

import SwiftUI
import MapKit

struct RunActivityView: View {
    
    enum PresentationStyle {
        case navigation
        case movementsModal
    }
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAnimating = false
    @State private var showActivityDetail: RouteActivity? = nil
    @State private var showLiveTracking = false
    @State private var showFullCalendar = false
    @State private var deepLinkWorkoutType: WorkoutActivityType? = nil
    private let presentationStyle: PresentationStyle
    
    @Namespace private var namespace
    
    // MARK: - Design Constants
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    
    init(presentationStyle: PresentationStyle = .navigation) {
        self.presentationStyle = presentationStyle
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            switch presentationStyle {
            case .navigation:
                navigationBody
            case .movementsModal:
                movementsModalBody
            }
        }
        .fullScreenCover(isPresented: $showLiveTracking) {
            NavigationStack {
                LiveActivityTrackingView(initialActivityType: deepLinkWorkoutType)
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
                        .foregroundColor(limeGreen)
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
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenLiveTracking)) { notification in
            if let typeString = notification.userInfo?[DeepLinkUserInfoKey.workoutType] as? String {
                deepLinkWorkoutType = mapToWorkoutActivityType(typeString)
            } else {
                deepLinkWorkoutType = nil
            }
            showLiveTracking = true
        }
    }
    
    private var navigationBody: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            mainScrollContent
        }
        .navigationTitle("Running")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var movementsModalBody: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                movementsModalHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                mainScrollContent
            }
        }
        .navigationBarHidden(true)
    }
    
    private var mainScrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero Stats Card
                heroStatsCard
                
                // Quick Actions Grid
                quickActionsGrid
                
                // Time Range Selector
                timeRangeSelector
                
                // Today's Progress Card
                todayProgressCard
                
                // Weekly Chart
                weeklyChartCard
                
                // Recent Activities
                recentActivitiesSection
            }
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }
    
    private var movementsModalHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(MovementsColors.card(for: colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            Text("Running")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: { showFullCalendar = true }) {
                ZStack {
                    Circle()
                        .fill(MovementsColors.card(for: colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(limeGreen)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func mapToWorkoutActivityType(_ raw: String) -> WorkoutActivityType {
        switch raw.lowercased() {
        case "walk", "walking":
            return .walking
        case "commute", "cycle", "cycling":
            return .cycling
        case "hike", "hiking":
            return .hiking
        default:
            return .running
        }
    }
    
    // MARK: - Hero Stats Card
    
    private var heroStatsCard: some View {
        ZStack {
            // Background with geometric pattern
            RoundedRectangle(cornerRadius: 28)
                .fill(limeGreen)
            
            // Geometric lines pattern
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 14
                    let startX = geo.size.width * 0.4
                    
                    for i in 0..<12 {
                        let x = startX + CGFloat(i) * spacing
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - geo.size.height * 0.6, y: geo.size.height))
                    }
                }
                .stroke(Color.black.opacity(0.08), lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Steps")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                        
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text("\(viewModel.totalSteps)")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .contentTransition(.numericText())
                            
                            Image(systemName: "figure.run")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.black.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: min(Double(viewModel.totalSteps) / 10000.0, 1.0))
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(Int(min(Double(viewModel.totalSteps) / 10000.0, 1.0) * 100))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                    }
                }
                
                // Stats Row
                HStack(spacing: 0) {
                    RunHeroStatItem(
                        value: String(format: "%.2f", viewModel.totalDistance),
                        unit: "km",
                        label: "Distance"
                    )
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 1, height: 40)
                    
                    RunHeroStatItem(
                        value: "\(viewModel.totalCalories)",
                        unit: "kcal",
                        label: "Calories"
                    )
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 1, height: 40)
                    
                    RunHeroStatItem(
                        value: "\(viewModel.totalPoints)",
                        unit: "pts",
                        label: "Points"
                    )
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(height: 220)
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAnimating)
    }
    
    // MARK: - Quick Actions Grid
    
    private var quickActionsGrid: some View {
        HStack(spacing: 12) {
            // Start Run Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showLiveTracking = true
            }) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(limeGreen)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    Text("Start Run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(MovementsColors.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Walk Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                deepLinkWorkoutType = .walking
                showLiveTracking = true
            }) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "5AC8FA").opacity(0.2))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "figure.walk")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "5AC8FA"))
                    }
                    
                    Text("Walk")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(MovementsColors.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Hike Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                deepLinkWorkoutType = .hiking
                showLiveTracking = true
            }) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(darkGreen.opacity(0.2))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(darkGreen)
                    }
                    
                    Text("Hike")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(MovementsColors.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: isAnimating)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ActivityTimeRange.allCases) { range in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.selectTimeRange(range)
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }) {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.selectedTimeRange == range ? .black : .primary.opacity(0.5))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if viewModel.selectedTimeRange == range {
                                    Capsule()
                                        .fill(limeGreen)
                                        .matchedGeometryEffect(id: "TIME_RANGE_TAB", in: namespace)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Today's Progress Card
    
    private var todayProgressCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                RunProgressMetricCard(
                    icon: "figure.walk",
                    iconColor: limeGreen,
                    value: "\(viewModel.totalSteps)",
                    label: "Steps",
                    progress: min(Double(viewModel.totalSteps) / 10000.0, 1.0),
                    progressColor: limeGreen,
                    colorScheme: colorScheme
                )
                
                RunProgressMetricCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(viewModel.totalCalories)",
                    label: "Calories",
                    progress: min(Double(viewModel.totalCalories) / 500.0, 1.0),
                    progressColor: .orange,
                    colorScheme: colorScheme
                )
                
                RunProgressMetricCard(
                    icon: "map.fill",
                    iconColor: Color(hex: "5AC8FA"),
                    value: String(format: "%.1f", viewModel.totalDistance),
                    label: "km",
                    progress: min(viewModel.totalDistance / 5.0, 1.0),
                    progressColor: Color(hex: "5AC8FA"),
                    colorScheme: colorScheme
                )
            }
        }
        .padding(20)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: isAnimating)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Weekly Chart Card
    
    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(limeGreen)
                        .frame(width: 8, height: 8)
                    
                    Text("Active")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            // Weekly Bar Chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyData, id: \.day) { data in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 36, height: 100)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    data.isToday
                                        ? limeGreen
                                        : limeGreen.opacity(0.4)
                                )
                                .frame(width: 36, height: max(CGFloat(data.steps) / 10000.0 * 100, 8))
                        }
                        
                        Text(data.day)
                            .font(.system(size: 12, weight: data.isToday ? .bold : .medium))
                            .foregroundColor(data.isToday ? limeGreen : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimating)
    }
    
    private var weeklyData: [(day: String, steps: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        
        return (0..<7).map { index in
            let dayIndex = (index + 1) % 7
            let isToday = dayIndex == (weekday - 1)
            let steps = isToday ? viewModel.totalSteps : Int.random(in: 2000...8000)
            return (day: days[dayIndex], steps: steps, isToday: isToday)
        }
    }
    
    // MARK: - Recent Activities Section
    
    private var recentActivitiesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Activities")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.activities.count > 3 {
                    NavigationLink(destination: RunStatsAnalyticsView()) {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(limeGreen)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(limeGreen)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if viewModel.activities.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(limeGreen.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(limeGreen)
                    }
                    
                    Text("No activities yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Start your first workout to track your progress")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showLiveTracking = true
                    }) {
                        Text("Start Running")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(limeGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
                .background(MovementsColors.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.activities.prefix(3))) { activity in
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            RunActivityCard(activity: activity, colorScheme: colorScheme)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: isAnimating)
    }
}

// MARK: - Hero Stat Item

private struct RunHeroStatItem: View {
    let value: String
    let unit: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress Metric Card

private struct RunProgressMetricCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let progress: Double
    let progressColor: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(progressColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 52, height: 52)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Run Activity Card (New Design)

private struct RunActivityCard: View {
    let activity: RouteActivity
    let colorScheme: ColorScheme
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 16) {
            // Activity Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(activity.formattedDistance)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(activity.formattedDuration)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(activity.formattedTimeRange)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
    @Environment(\.colorScheme) private var colorScheme
    let activity: RouteActivity
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 14) {
            // Activity Type Badge
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(activity.type.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(activity.formattedDistance, systemImage: "map")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Label(activity.formattedDuration, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text(activity.formattedTimeRange)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    Text("\(activity.averageBPM)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text("BPM")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Weekly Comparison Bar

struct WeeklyComparisonBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let average: Double
    let dateRange: String
    let maxValue: Double
    let isCurrent: Bool
    let accentColor: Color
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", average))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("km/day")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 85, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isCurrent
                                ? limeGreen
                                : limeGreen.opacity(0.4)
                        )
                        .frame(width: max(geometry.size.width * (average / max(maxValue, 1)), 20))
                    
                    Text(dateRange)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isCurrent ? .black : .white)
                        .padding(.horizontal, 10)
                }
            }
            .frame(height: 28)
        }
    }
}

// MARK: - Run Stats Analytics View

struct RunStatsAnalyticsView: View {
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    @State private var selectedTab: AnalyticsTab = .overview
    
    private let limeGreen = MovementsColors.limeGreen
    private let darkGreen = MovementsColors.darkGreen
    
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
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
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
            HStack(spacing: 10) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .bold))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(selectedTab == tab ? .black : .primary.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? limeGreen : MovementsColors.card(for: colorScheme))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.trailing, 20)
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Summary Hero Card
            summaryHeroCard
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                RunAnalyticsStatCard(
                    title: "Total Steps",
                    value: "\(viewModel.totalSteps)",
                    icon: "figure.walk",
                    color: limeGreen,
                    trend: 12.5,
                    colorScheme: colorScheme
                )
                
                RunAnalyticsStatCard(
                    title: "Distance",
                    value: String(format: "%.1f km", viewModel.totalDistance),
                    icon: "map.fill",
                    color: Color(hex: "5AC8FA"),
                    trend: 8.3,
                    colorScheme: colorScheme
                )
                
                RunAnalyticsStatCard(
                    title: "Calories",
                    value: "\(viewModel.totalCalories)",
                    icon: "flame.fill",
                    color: .orange,
                    trend: 15.7,
                    colorScheme: colorScheme
                )
                
                RunAnalyticsStatCard(
                    title: "Points",
                    value: "\(viewModel.totalPoints)",
                    icon: "star.fill",
                    color: .yellow,
                    trend: -2.1,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal, 20)
            
            // Weekly Chart
            weeklyDistanceChartCard
            
            // Streak Card
            streakCard
            
            // Quick Stats
            quickStatsSection
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5), value: isAnimating)
    }
    
    private var summaryHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(darkGreen)
            
            // Geometric pattern
            GeometryReader { geo in
                Path { path in
                    for i in 0..<8 {
                        let x = CGFloat(i) * 20 + geo.size.width * 0.5
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - 60, y: geo.size.height))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Activity")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("\(viewModel.activities.count) workouts")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(limeGreen)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", viewModel.totalDistance))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(limeGreen)
                        Text("km total")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 36)
                    
                    VStack(spacing: 4) {
                        Text(calculateTotalTime())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(limeGreen)
                        Text("active time")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 36)
                    
                    VStack(spacing: 4) {
                        Text("\(viewModel.totalCalories)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(limeGreen)
                        Text("kcal burned")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .frame(height: 160)
        .padding(.horizontal, 20)
    }
    
    private var weeklyDistanceChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Distance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.1f km total", generateWeeklyData().reduce(0) { $0 + $1.distance }))
                    .font(.system(size: 13))
                    .foregroundColor(limeGreen)
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(generateWeeklyData().enumerated()), id: \.offset) { index, data in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 120)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [limeGreen, limeGreen.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(CGFloat(data.distance) / 10.0 * 120, 8))
                        }
                        
                        Text(data.day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
    }
    
    private var streakCard: some View {
        HStack(spacing: 20) {
            // Current Streak
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(limeGreen.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    VStack(spacing: 2) {
                        Text("\(calculateCurrentStreak())")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(limeGreen)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(limeGreen)
                    }
                }
                
                Text("Current\nStreak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 60)
            
            // Best Streak
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    VStack(spacing: 2) {
                        Text("\(calculateLongestStreak())")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                
                Text("Best\nStreak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                if calculateCurrentStreak() > 0 {
                    Text("Keep it up!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("You're on a roll")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("Start today!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Build your streak")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RunQuickStatItem(
                    icon: "speedometer",
                    iconColor: limeGreen,
                    value: calculateAvgPace(),
                    label: "Avg Pace",
                    colorScheme: colorScheme
                )
                
                RunQuickStatItem(
                    icon: "heart.fill",
                    iconColor: .red,
                    value: "\(calculateAvgHeartRate())",
                    label: "Avg HR",
                    colorScheme: colorScheme
                )
                
                RunQuickStatItem(
                    icon: "clock.fill",
                    iconColor: .orange,
                    value: calculateTotalTime(),
                    label: "Total Time",
                    colorScheme: colorScheme
                )
                
                RunQuickStatItem(
                    icon: "map.fill",
                    iconColor: Color(hex: "5AC8FA"),
                    value: String(format: "%.1f km", viewModel.totalDistance / Double(max(viewModel.activities.count, 1))),
                    label: "Avg Distance",
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Performance Content
    
    private var performanceContent: some View {
        VStack(spacing: 24) {
            PerformanceInsightsCard(insights: generateInsights())
                .padding(.horizontal, 20)
            
            PersonalRecordsSection(records: generatePersonalRecords())
                .padding(.horizontal, 20)
            
            PaceDistributionChart(
                paceRanges: generatePaceDistribution(),
                color: limeGreen
            )
            .padding(.horizontal, 20)
            
            TimeOfDayAnalysis(distribution: generateTimeDistribution())
                .padding(.horizontal, 20)
            
            goalsProgressSection
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    private var goalsProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(limeGreen)
                
                Text("Goals Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            GoalProgressRow(
                title: "Steps",
                current: viewModel.activityGoal.currentSteps,
                goal: viewModel.activityGoal.dailyStepsGoal,
                color: limeGreen
            )
            
            GoalProgressRow(
                title: "Distance",
                current: Int(viewModel.activityGoal.currentDistance * 1000),
                goal: Int(viewModel.activityGoal.dailyDistanceGoal * 1000),
                unit: "m",
                color: Color(hex: "5AC8FA")
            )
            
            GoalProgressRow(
                title: "Calories",
                current: viewModel.activityGoal.currentCalories,
                goal: viewModel.activityGoal.dailyCaloriesGoal,
                color: .orange
            )
        }
        .padding(20)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Activities")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.activities.count) total")
                    .font(.system(size: 14))
                    .foregroundColor(limeGreen)
            }
            .padding(.horizontal, 20)
            
            if viewModel.activities.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(limeGreen.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(limeGreen)
                    }
                    
                    Text("No activities yet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Start a workout to track your activities")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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
        
        let activeDays = Set(viewModel.activities.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        insights.append(PerformanceInsight(
            icon: "checkmark.circle.fill",
            title: "Consistency",
            description: "You've been active on \(activeDays) different days",
            color: limeGreen
        ))
        
        if viewModel.percentageChange > 0 {
            insights.append(PerformanceInsight(
                icon: "arrow.up.right.circle.fill",
                title: "Distance Improved",
                description: String(format: "Up %.1f%% compared to last period", viewModel.percentageChange),
                color: Color(hex: "5AC8FA")
            ))
        }
        
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

// MARK: - Run Analytics Stat Card

private struct RunAnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    
                    Text(String(format: "%.1f%%", abs(trend)))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(trend >= 0 ? MovementsColors.limeGreen : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((trend >= 0 ? MovementsColors.limeGreen : Color.red).opacity(0.15))
                )
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Run Quick Stat Item

private struct RunQuickStatItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
