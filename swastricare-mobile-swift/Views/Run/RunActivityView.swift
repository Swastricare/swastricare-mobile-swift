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
    @State private var deepLinkWorkoutType: WorkoutActivityType? = nil
    
    @Namespace private var namespace
    
    // MARK: - Constants
    
    private let accentBlue = AppColors.accentBlue
    private let accentGreen = AppColors.accentGreen
    private let backgroundGray = Color(hex: "F8F9FA")
    
    // MARK: - Selected Date

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    activityHeroHeader
                    weekDayStrip
                    moveGoalCard
                    streakCard
                    highlightsHeader
                    highlightsGrid
                    startWorkoutCta
                    recentActivitiesHeader
                    if viewModel.activities.isEmpty {
                        emptyActivitiesPrompt
                    } else {
                        recentActivitiesList
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showLiveTracking) {
            // LiveActivityTrackingView struct is currently absent — placeholder until restored.
            NavigationStack {
                Color.clear
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
                        .font(.poppins(.semiBold, size: 17))
                    }
                }
            }
        }
        .trackScreen("RunActivity")
        .onAppear {
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
    
    // MARK: - Helpers

    private var todaySummary: DailyActivitySummary? {
        let cal = Calendar.current
        return viewModel.dailySummaries.first { cal.isDateInToday($0.date) }
    }

    private func summary(for date: Date) -> DailyActivitySummary? {
        let cal = Calendar.current
        return viewModel.dailySummaries.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func activities(on date: Date) -> [RouteActivity] {
        let cal = Calendar.current
        return viewModel.activities.filter { cal.isDate($0.startTime, inSameDayAs: date) }
    }

    private var displaySteps: Int {
        let dayActivities = activities(on: selectedDate)
        let activitySteps = dayActivities.reduce(0) { $0 + $1.steps }
        let summarySteps = summary(for: selectedDate)?.steps ?? 0
        return max(activitySteps, summarySteps)
    }

    private var displayCalories: Int {
        let dayActivities = activities(on: selectedDate)
        let activityCals = dayActivities.reduce(0) { $0 + $1.calories }
        let summaryCals = summary(for: selectedDate)?.calories ?? 0
        return max(activityCals, summaryCals)
    }

    private var displayDistanceKm: Double {
        let dayActivities = activities(on: selectedDate)
        let activityDist = dayActivities.reduce(0.0) { $0 + $1.distance }
        let summaryDist = summary(for: selectedDate)?.distance ?? 0
        return max(activityDist, summaryDist)
    }

    private var displayActiveMinutes: Int {
        let dayActivities = activities(on: selectedDate)
        return Int(dayActivities.reduce(0.0) { $0 + $1.duration } / 60)
    }

    private var stepsGoal: Int {
        max(viewModel.activityGoal.dailyStepsGoal, 1)
    }

    private var caloriesGoal: Int {
        max(viewModel.activityGoal.dailyCaloriesGoal, 1)
    }

    private var distanceGoalKm: Double {
        max(viewModel.activityGoal.dailyDistanceGoal, 0.001)
    }

    private var activeMinutesGoal: Int { 30 }

    private var highlightsTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "Today's Highlights" }
        if cal.isDateInYesterday(selectedDate) { return "Yesterday's Highlights" }
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return "\(f.string(from: selectedDate)) Highlights"
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "Today" }
        if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: selectedDate)
    }

    private var streakDays: Int {
        let cal = Calendar.current
        let activityDays = Set(viewModel.activities.map { cal.startOfDay(for: $0.startTime) })
        if activityDays.isEmpty { return 0 }
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        while activityDays.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        if streak == 0 {
            cursor = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) ?? Date()
            while activityDays.contains(cursor) {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            }
        }
        return streak
    }

    private var activeWeekdays: Set<Int> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1=Sun..7=Sat
        // Monday-start week: monday offset = (weekday + 5) % 7
        let mondayOffset = (weekday + 5) % 7
        guard let weekStart = cal.date(byAdding: .day, value: -mondayOffset, to: today) else { return [] }
        guard let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else { return [] }
        var result: Set<Int> = []
        for activity in viewModel.activities {
            let day = cal.startOfDay(for: activity.startTime)
            if day >= weekStart && day <= weekEnd {
                let wd = cal.component(.weekday, from: day) // 1=Sun..7=Sat
                // Map to Mon=1..Sun=7
                let mondayBased = ((wd + 5) % 7) + 1
                result.insert(mondayBased)
            }
        }
        return result
    }

    // MARK: - Hero Header

    private var activityHeroHeader: some View {
        ZStack(alignment: .topLeading) {
            // Hero illustration aligned right
            HStack {
                Spacer()
                Image.androidImage("activity screen hero")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipped()
            }
            .frame(height: 200)

            // Top fade
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.white, .white.opacity(0.85), .white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)
                Spacer()
            }
            .frame(height: 200)

            // Title + calendar button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.poppins(.bold, size: 32))
                        .foregroundColor(Color(hex: "0F172A"))
                    Text("Track your daily movement\nand progress")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(Color(hex: "6B7280"))
                        .lineSpacing(2)
                }

                Spacer()

                Button {
                    showFullCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(AppColors.aiTeal)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .frame(height: 200)
        .clipShape(RoundedCorners(radius: 36, corners: [.bottomLeft, .bottomRight]))
    }

    // MARK: - Week Day Strip

    private var weekDayStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days: [Date] = (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today) ?? today }
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                let isToday = cal.isDate(day, inSameDayAs: today)
                let isFuture = day > today
                let weekdayChar = ActivityHelpers.shortWeekday(day)
                let dayNum = cal.component(.day, from: day)

                Button {
                    if !isFuture {
                        let gen = UISelectionFeedbackGenerator()
                        gen.selectionChanged()
                        selectedDate = day
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(weekdayChar)
                            .font(.poppins(.medium, size: 10))
                            .foregroundColor(isSelected ? Color.white.opacity(0.85) : Color(hex: "6B7280"))
                        Text("\(dayNum)")
                            .font(.poppins(.bold, size: 16))
                            .foregroundColor(isSelected ? .white : (isFuture ? Color(hex: "6B7280").opacity(0.4) : Color(hex: "0F172A")))
                        Circle()
                            .fill(isToday && !isSelected ? AppColors.aiTeal : Color.clear)
                            .frame(width: 4, height: 4)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? AppColors.aiTeal : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? Color.clear : (isToday ? AppColors.aiTeal.opacity(0.6) : Color(hex: "E9EEF3")),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isFuture)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Move Goal Card

    private var moveGoalCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Move Goal")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(Color(hex: "0F172A"))
                Spacer()
                Text(dateLabel)
                    .font(.poppins(.medium, size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
            }

            HStack(alignment: .center, spacing: 14) {
                MoveRingView(
                    progress: min(Double(displayCalories) / Double(caloriesGoal), 1.0),
                    calories: displayCalories,
                    caloriesGoal: caloriesGoal
                )
                .frame(width: 130, height: 130)

                VStack(spacing: 12) {
                    MoveMetricRow(
                        icon: "figure.run",
                        iconTint: AppColors.aiTeal,
                        label: "Steps",
                        value: ActivityHelpers.formatThousands(displaySteps),
                        goal: "/\(ActivityHelpers.formatThousands(stepsGoal))",
                        progress: min(Double(displaySteps) / Double(stepsGoal), 1.0),
                        barColor: AppColors.aiTeal
                    )
                    MoveMetricRow(
                        icon: "clock",
                        iconTint: Color(hex: "EF8B3C"),
                        label: "Active Time",
                        value: "\(displayActiveMinutes)",
                        goal: "/\(activeMinutesGoal) min",
                        progress: min(Double(displayActiveMinutes) / Double(activeMinutesGoal), 1.0),
                        barColor: Color(hex: "EF8B3C")
                    )
                    MoveMetricRow(
                        icon: "mappin.and.ellipse",
                        iconTint: Color(hex: "EAB308"),
                        label: "Distance",
                        value: String(format: "%.2f", displayDistanceKm),
                        goal: "/\(Int(distanceGoalKm)) km",
                        progress: min(displayDistanceKm / distanceGoalKm, 1.0),
                        barColor: Color(hex: "EAB308")
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let cal = Calendar.current
                    if value.translation.width > 60 {
                        if let prev = cal.date(byAdding: .day, value: -1, to: selectedDate) {
                            selectedDate = prev
                        }
                    } else if value.translation.width < -60 {
                        if let next = cal.date(byAdding: .day, value: 1, to: selectedDate),
                           next <= cal.startOfDay(for: Date()) {
                            selectedDate = next
                        }
                    }
                }
        )
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let activeDays = activeWeekdays
        let streakColor = AppColors.aiTeal
        return HStack(spacing: 12) {
            Image.androidIcon("activity streak icon")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakDays) Day Streak!")
                    .font(.poppins(.bold, size: 14))
                    .foregroundColor(.white)
                Text("Keep up the great work")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    let active = activeDays.contains(day)
                    Text(ActivityHelpers.weekdayShortInitial(day))
                        .font(.poppins(.bold, size: 9))
                        .foregroundColor(active ? streakColor : .white)
                        .frame(width: 18, height: 22)
                        .background(
                            Capsule()
                                .fill(active ? Color.white : Color.white.opacity(0.22))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(hex: "1FB495"), Color(hex: "14A07F")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    // MARK: - Highlights

    private var highlightsHeader: some View {
        Text(highlightsTitle)
            .font(.poppins(.bold, size: 16))
            .foregroundColor(Color(hex: "0F172A"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    private var highlightsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HighlightTile(
                    icon: "figure.run",
                    iconTint: AppColors.aiTeal,
                    bgTint: Color(hex: "E6F7F2"),
                    value: ActivityHelpers.formatThousands(displaySteps),
                    label: "Steps"
                )
                HighlightTile(
                    icon: "clock",
                    iconTint: Color(hex: "3B82F6"),
                    bgTint: Color(hex: "E6F0FF"),
                    value: "\(displayActiveMinutes)",
                    label: "Min Active"
                )
            }
            HStack(spacing: 10) {
                HighlightTile(
                    icon: "flame.fill",
                    iconTint: Color(hex: "EF8B3C"),
                    bgTint: Color(hex: "FFF1DC"),
                    value: "\(displayCalories)",
                    label: "kcal Burned"
                )
                HighlightTile(
                    icon: "mappin.and.ellipse",
                    iconTint: Color(hex: "E11D74"),
                    bgTint: Color(hex: "FDE6EE"),
                    value: String(format: "%.2f", displayDistanceKm),
                    label: "km"
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Start Workout CTA

    private var startWorkoutCta: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            showLiveTracking = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 36, height: 36)
                    Image(systemName: "play.fill")
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a Workout")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(.white)
                    Text("Run, walk, cycle, or pick another activity")
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppColors.aiTeal)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Activities

    private var recentActivitiesHeader: some View {
        HStack {
            Text("Recent Activities")
                .font(.poppins(.bold, size: 16))
                .foregroundColor(Color(hex: "0F172A"))
            Spacer()
            Button {
                showFullCalendar = true
            } label: {
                Text("View all")
                    .font(.poppins(.semiBold, size: 12))
                    .foregroundColor(AppColors.aiTeal)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var recentActivitiesList: some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.activities.prefix(4))) { activity in
                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                    ActivityListRow(activity: activity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyActivitiesPrompt: some View {
        VStack(spacing: 8) {
            Text("No activities yet")
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(Color(hex: "0F172A"))
            Text("Start a workout to see it here.")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color(hex: "6B7280"))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "E6F7F2"))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Move Ring

private struct MoveRingView: View {
    let progress: Double
    let calories: Int
    let caloriesGoal: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "E6F4EA"), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color(hex: "22C5A6"), Color(hex: "22C55E"), Color(hex: "22C5A6")]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)

            VStack(spacing: 0) {
                Text("\(calories)")
                    .font(.poppins(.bold, size: 28))
                    .foregroundColor(Color(hex: "0F172A"))
                Text("of \(caloriesGoal) kcal")
                    .font(.poppins(.regular, size: 10))
                    .foregroundColor(Color(hex: "6B7280"))
                Text("\(Int(progress * 100))%")
                    .font(.poppins(.semiBold, size: 12))
                    .foregroundColor(AppColors.aiTeal)
                    .padding(.top, 4)
            }
        }
        .padding(7)
    }
}

// MARK: - Move Metric Row

private struct MoveMetricRow: View {
    let icon: String
    let iconTint: Color
    let label: String
    let value: String
    let goal: String
    let progress: Double
    let barColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.14))
                        .frame(width: 22, height: 22)
                    Image(systemName: icon)
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(iconTint)
                }
                Text(label)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                Spacer()
                Text("\(value) \(goal)")
                    .font(.poppins(.semiBold, size: 11))
                    .foregroundColor(Color(hex: "0F172A"))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "EFF3F7"))
                        .frame(height: 5)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Highlight Tile

private struct HighlightTile: View {
    let icon: String
    let iconTint: Color
    let bgTint: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(bgTint)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(iconTint)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.poppins(.bold, size: 16))
                    .foregroundColor(Color(hex: "0F172A"))
                Text(label)
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(Color(hex: "6B7280"))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Activity List Row

private struct ActivityListRow: View {
    let activity: RouteActivity

    private var iconBundle: (icon: String, tint: Color, bg: Color, title: String) {
        switch activity.type {
        case .run:
            return ("figure.run", Color(hex: "22C55E"), Color(hex: "E6F4EA"), runTitle)
        case .walk:
            return ("figure.walk", Color(hex: "EF8B3C"), Color(hex: "FFF1DC"), walkTitle)
        case .commute:
            return ("bicycle", Color(hex: "3B82F6"), Color(hex: "E6F0FF"), "Cycling")
        }
    }

    private var runTitle: String {
        let hour = Calendar.current.component(.hour, from: activity.startTime)
        switch hour {
        case 5...11: return "Morning Run"
        case 12...16: return "Afternoon Run"
        case 17...20: return "Evening Run"
        default: return "Night Run"
        }
    }

    private var walkTitle: String {
        let hour = Calendar.current.component(.hour, from: activity.startTime)
        switch hour {
        case 5...11: return "Morning Walk"
        case 12...16: return "Afternoon Walk"
        case 17...20: return "Evening Walk"
        default: return "Night Walk"
        }
    }

    private var timeText: String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDateInToday(activity.startTime) {
            f.dateFormat = "h:mm a"
            return f.string(from: activity.startTime)
        } else if cal.isDateInYesterday(activity.startTime) {
            return "Yesterday"
        } else {
            f.dateFormat = "MMM d"
            return f.string(from: activity.startTime)
        }
    }

    private var subtitle: String {
        let mins = Int(activity.duration / 60)
        let dur: String
        if mins >= 60 {
            dur = "\(mins / 60)h \(mins % 60)m"
        } else {
            dur = "\(mins) min"
        }
        var parts = [String(format: "%.2f km", activity.distance), dur]
        if activity.distance > 0 && activity.type != .commute {
            let paceMinPerKm = (activity.duration / 60) / max(activity.distance, 0.001)
            let paceMins = Int(paceMinPerKm)
            let paceSecs = Int((paceMinPerKm - Double(paceMins)) * 60)
            parts.append(String(format: "%d:%02d/km", paceMins, paceSecs))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let bundle = iconBundle
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bundle.bg)
                    .frame(width: 40, height: 40)
                Image(systemName: bundle.icon)
                    .font(.poppins(.semiBold, size: 18))
                    .foregroundColor(bundle.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bundle.title)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(Color(hex: "0F172A"))
                Text(subtitle)
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(Color(hex: "6B7280"))
            }

            Spacer()

            Text(timeText)
                .font(.poppins(.regular, size: 11))
                .foregroundColor(Color(hex: "6B7280"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Helpers

private enum ActivityHelpers {
    static func formatThousands(_ value: Int) -> String {
        if value < 1000 { return "\(value)" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(3))
    }

    /// 1=Mon..7=Sun
    static func weekdayShortInitial(_ mondayBased: Int) -> String {
        switch mondayBased {
        case 1: return "M"
        case 2: return "T"
        case 3: return "W"
        case 4: return "T"
        case 5: return "F"
        case 6: return "S"
        case 7: return "S"
        default: return ""
        }
    }
}

// MARK: - Rounded Corners Shape

private struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
                .font(.poppins(.regular, size: 12))
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.poppins(.bold, size: isLarge ? 28 : 22))
                    .foregroundColor(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.poppins(.medium, size: 12))
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Map Preview – same MKMapView + polyline as detail screen so route layout matches
            ActivityRouteThumbnailMapView(routeCoordinates: activity.routeCoordinates, size: CGSize(width: 80, height: 80))
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                // Time Range with icon
                HStack(spacing: 4) {
                    Image(systemName: activity.type.icon)
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(activity.formattedTimeRange)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Activity Name
                Text(activity.name)
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.primary)
                
                // BPM and Distance
                HStack(spacing: 8) {
                    Text("AVG \(activity.averageBPM) BPM")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("-")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(activity.formattedDistance)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .font(.poppins(.bold, size: 20))
                    .foregroundColor(.primary)
                
                Text("Km / day")
                    .font(.poppins(.regular, size: 11))
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
                        .font(.poppins(.medium, size: 12))
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
                                .font(.poppins(.semiBold, size: 12))
                            
                            Text(tab.rawValue)
                                .font(.poppins(.semiBold, size: 14))
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
                    .font(.poppins(.bold, size: 17))
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
                            .font(.poppins(.semiBold, size: 18))
                            .foregroundColor(accentBlue)
                        
                        Text("Weekly Comparison")
                            .font(.poppins(.bold, size: 17))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text(weeklyComparison.insightText)
                        .font(.poppins(.regular, size: 15))
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
                        .font(.poppins(.semiBold, size: 18))
                        .foregroundColor(accentBlue)
                    
                    Text("Goals Progress")
                        .font(.poppins(.bold, size: 17))
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
                    .font(.poppins(.bold, size: 20))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.activities.count) total")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            if viewModel.activities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.circle")
                        .font(.poppins(.regular, size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No activities yet")
                        .font(.poppins(.semiBold, size: 17))
                        .foregroundColor(.secondary)
                    
                    Text("Start a workout to track your activities")
                        .font(.poppins(.regular, size: 15))
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
                .font(.poppins(.medium, size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.poppins(.bold, size: 24))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.poppins(.regular, size: 12))
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
                    .font(.poppins(.medium, size: 15))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(current)\(unit.isEmpty ? "" : " \(unit)") / \(goal)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.poppins(.regular, size: 12))
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
