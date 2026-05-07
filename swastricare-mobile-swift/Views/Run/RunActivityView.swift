//
//  RunActivityView.swift
//  swastricare-mobile-swift
//
//  Steps & Walk/Run Activity Tracking View
//  Designed following iOS-style minimal, clean UI
//

import SwiftUI
import MapKit

// MARK: - Local design tokens (mirrors Android file-level privates)

private let textPrimary   = Color(hex: "0F172A")
private let textSecondary = Color(hex: "6B7280")
private let softBorder    = Color(hex: "E9EEF3")
private let mintTint      = Color(hex: "E6F7F2")
private let tintMint      = Color(hex: "E6F7F2")
private let tintBlue      = Color(hex: "E6F0FF")
private let tintAmber     = Color(hex: "FFF1DC")
private let tintPink      = Color(hex: "FDE6EE")
private let runTint       = Color(hex: "E6F4EA")
private let walkTint      = Color(hex: "FFF1DC")
private let cycleTint     = Color(hex: "E6F0FF")
private let hikeTint      = Color(hex: "EDE9FE")

// MARK: - Main Screen

struct RunActivityView: View {

    // ── ViewModel ────────────────────────────────────────────────────────────
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel

    // ── Sheet / Nav state ────────────────────────────────────────────────────
    @State private var showWorkoutPicker  = false
    @State private var showFullCalendar   = false
    @State private var showLiveTracking   = false
    @State private var selectedWorkoutType: WorkoutActivityType? = nil
    @State private var deepLinkWorkoutType: WorkoutActivityType? = nil

    // ── Date selection ───────────────────────────────────────────────────────
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    activityHeroHeader
                        .ignoresSafeArea(.container, edges: .top)
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
                .padding(.top, 0)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        // Calendar sheet
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
                        Button("Done") { showFullCalendar = false }
                            .font(.poppins(.semiBold, size: 17))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showLiveTracking) {
            NavigationStack {
                LiveActivityTrackingView(
                    initialActivityType: selectedWorkoutType ?? deepLinkWorkoutType
                )
            }
        }
        .trackScreen("RunActivity")
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenLiveTracking)) { notification in
            if let typeString = notification.userInfo?[DeepLinkUserInfoKey.workoutType] as? String {
                deepLinkWorkoutType = mapToWorkoutActivityType(typeString)
            } else {
                deepLinkWorkoutType = nil
            }
            showLiveTracking = true
        }
    }

    // MARK: - Deep-link helper

    private func mapToWorkoutActivityType(_ raw: String) -> WorkoutActivityType {
        switch raw.lowercased() {
        case "walk", "walking": return .walking
        case "commute", "cycle", "cycling": return .cycling
        case "hike", "hiking": return .hiking
        default: return .running
        }
    }

    // MARK: - Computed display values

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private func activities(on date: Date) -> [RouteActivity] {
        let cal = Calendar.current
        return viewModel.activities.filter { cal.isDate($0.startTime, inSameDayAs: date) }
    }

    private func summary(for date: Date) -> DailyActivitySummary? {
        let cal = Calendar.current
        return viewModel.dailySummaries.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var displaySteps: Int {
        let acts = activities(on: selectedDate)
        return max(acts.reduce(0) { $0 + $1.steps }, summary(for: selectedDate)?.steps ?? 0)
    }

    private var displayCalories: Int {
        let acts = activities(on: selectedDate)
        return max(acts.reduce(0) { $0 + $1.calories }, summary(for: selectedDate)?.calories ?? 0)
    }

    private var displayDistanceKm: Double {
        let acts = activities(on: selectedDate)
        return max(acts.reduce(0.0) { $0 + $1.distance }, summary(for: selectedDate)?.distance ?? 0)
    }

    private var displayActiveMinutes: Int {
        Int(activities(on: selectedDate).reduce(0.0) { $0 + $1.duration } / 60)
    }

    private var stepsGoal: Int    { max(viewModel.activityGoal.dailyStepsGoal, 1) }
    private var caloriesGoal: Int { max(viewModel.activityGoal.dailyCaloriesGoal, 1) }
    private var distanceGoalKm: Double { max(viewModel.activityGoal.dailyDistanceGoal, 0.001) }
    private var activeMinutesGoal: Int { 30 }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "Today" }
        if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
        return f.string(from: selectedDate)
    }

    private var highlightsTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "Today's Highlights" }
        if cal.isDateInYesterday(selectedDate) { return "Yesterday's Highlights" }
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
        return "\(f.string(from: selectedDate)) Highlights"
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

    /// Active weekdays (1=Mon..7=Sun) within the current Mon-Sun week.
    private var activeWeekdays: Set<Int> {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        let wd = cal.component(.weekday, from: now) // 1=Sun..7=Sat
        let mondayOffset = (wd + 5) % 7
        guard let weekStart = cal.date(byAdding: .day, value: -mondayOffset, to: now),
              let weekEnd   = cal.date(byAdding: .day, value: 6, to: weekStart) else { return [] }
        var result: Set<Int> = []
        for act in viewModel.activities {
            let day = cal.startOfDay(for: act.startTime)
            guard day >= weekStart, day <= weekEnd else { continue }
            let rawWd = cal.component(.weekday, from: day)
            result.insert(((rawWd + 5) % 7) + 1) // convert to Mon=1..Sun=7
        }
        return result
    }

    // MARK: - Hero Header

    private var activityHeroHeader: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "EEF7F2")

            // Image height (200) < container height (240) — bottom 40pt is empty space
            // so rounded corners (radius 36) curve into that gap, not into image content
            Image.androidImage("activity screen hero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            LinearGradient(
                colors: [.white, .white.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.poppins(.bold, size: 32))
                        .foregroundColor(textPrimary)
                    Text("Track your daily movement\nand progress")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(textSecondary)
                        .lineSpacing(2)
                }
                Spacer()
                Button { showFullCalendar = true } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.aiTeal)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedCorners(radius: 36, corners: [.bottomLeft, .bottomRight]))
    }

    // MARK: - Week Day Strip

    private var weekDayStrip: some View {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let days: [Date] = (0..<7).reversed()
            .compactMap { cal.date(byAdding: .day, value: -$0, to: todayStart) }

        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                let isToday    = cal.isDate(day, inSameDayAs: todayStart)
                let isFuture   = day > todayStart
                let wdStr      = ActivityHelpers.shortWeekday(day)
                let dayNum     = cal.component(.day, from: day)

                Button {
                    guard !isFuture else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    selectedDate = day
                    Task { await viewModel.loadDaySummary(for: day) }
                } label: {
                    VStack(spacing: 2) {
                        Text(wdStr)
                            .font(.poppins(.medium, size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.85) : textSecondary)
                        Text("\(dayNum)")
                            .font(.poppins(.bold, size: 16))
                            .foregroundColor(
                                isSelected ? .white :
                                isFuture   ? textSecondary.opacity(0.4) :
                                             textPrimary
                            )
                        Circle()
                            .fill(isToday && !isSelected ? AppColors.aiTeal : .clear)
                            .frame(width: 4, height: 4)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? AppColors.aiTeal : .white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? .clear :
                                isToday    ? AppColors.aiTeal.opacity(0.6) :
                                             softBorder,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isFuture)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Move Goal Card (swipeable + nudge)

    private var moveGoalCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Move Goal")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(textPrimary)
                Spacer()
                Text(dateLabel)
                    .font(.poppins(.medium, size: 12))
                    .foregroundColor(textSecondary)
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
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        // Horizontal swipe to change date
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { val in
                    let cal = Calendar.current
                    if val.translation.width > 60 {
                        if let prev = cal.date(byAdding: .day, value: -1, to: selectedDate) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedDate = prev
                            Task { await viewModel.loadDaySummary(for: prev) }
                        }
                    } else if val.translation.width < -60 {
                        if let next = cal.date(byAdding: .day, value: 1, to: selectedDate),
                           next <= today {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedDate = next
                            Task { await viewModel.loadDaySummary(for: next) }
                        }
                    }
                }
        )
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let activeDays = activeWeekdays
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
                        .foregroundColor(active ? AppColors.aiTeal : .white)
                        .frame(width: 18, height: 22)
                        .background(Capsule().fill(active ? Color.white : Color.white.opacity(0.22)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(hex: "1FB495"), Color(hex: "14A07F")],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    // MARK: - Highlights Header

    private var highlightsHeader: some View {
        Text(highlightsTitle)
            .font(.poppins(.bold, size: 16))
            .foregroundColor(textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    // MARK: - Highlights Grid

    private var highlightsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HighlightTile(icon: "figure.run",         iconTint: AppColors.aiTeal,     bgTint: tintMint,  value: ActivityHelpers.formatThousands(displaySteps), label: "Steps")
                HighlightTile(icon: "clock",              iconTint: Color(hex: "3B82F6"), bgTint: tintBlue,  value: "\(displayActiveMinutes)", label: "Min Active")
            }
            HStack(spacing: 10) {
                HighlightTile(icon: "flame.fill",         iconTint: Color(hex: "EF8B3C"), bgTint: tintAmber, value: "\(displayCalories)", label: "kcal Burned")
                HighlightTile(icon: "mappin.and.ellipse", iconTint: Color(hex: "E11D74"), bgTint: tintPink,  value: String(format: "%.2f", displayDistanceKm), label: "km")
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Start Workout CTA

    private var startWorkoutCta: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedWorkoutType = nil
            showLiveTracking = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 36, height: 36)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.aiTeal))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Activities Header

    private var recentActivitiesHeader: some View {
        HStack {
            Text("Recent Activities")
                .font(.poppins(.bold, size: 16))
                .foregroundColor(textPrimary)
            Spacer()
            Button { showFullCalendar = true } label: {
                Text("View all")
                    .font(.poppins(.semiBold, size: 12))
                    .foregroundColor(AppColors.aiTeal)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Activities List

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

    // MARK: - Empty State

    private var emptyActivitiesPrompt: some View {
        VStack(spacing: 8) {
            Text("No activities yet")
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(textPrimary)
            Text("Start a workout to see it here.")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(mintTint))
        .padding(.horizontal, 16)
    }
}

// MARK: - Workout Picker Sheet (mirrors Android activity-type cards)

private struct WorkoutPickerSheet: View {
    let onSelect: (WorkoutActivityType) -> Void
    let onDismiss: () -> Void

    struct WorkoutOption {
        let type: WorkoutActivityType
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let bg: Color
        let assetIcon: String?
    }

    private let options: [WorkoutOption] = [
        WorkoutOption(type: .walking, title: "Walk",  subtitle: "Outdoor or treadmill walk",  icon: "figure.walk", tint: Color(hex: "EF8B3C"), bg: Color(hex: "FFF1DC"), assetIcon: "walk illustration"),
        WorkoutOption(type: .running, title: "Run",   subtitle: "Track pace & route",          icon: "figure.run",  tint: Color(hex: "22C55E"), bg: Color(hex: "E6F4EA"), assetIcon: "run activity illustration"),
        WorkoutOption(type: .hiking,  title: "Hike",  subtitle: "Trail & elevation tracking",  icon: "mountain.2.fill", tint: Color(hex: "8B5CF6"), bg: Color(hex: "EDE9FE"), assetIcon: "hike illustration"),
        WorkoutOption(type: .cycling, title: "Cycle", subtitle: "Road, trail, or stationary",  icon: "bicycle",     tint: Color(hex: "3B82F6"), bg: Color(hex: "E6F0FF"), assetIcon: nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "E9EEF3"))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 16)

            Text("Choose Activity")
                .font(.poppins(.bold, size: 20))
                .foregroundColor(textPrimary)
                .padding(.horizontal, 20)

            Text("What would you like to do today?")
                .font(.poppins(.regular, size: 13))
                .foregroundColor(textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 20)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(options, id: \.title) { option in
                    WorkoutOptionCard(option: option) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSelect(option.type)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }
}

private struct WorkoutOptionCard: View {
    let option: WorkoutPickerSheet.WorkoutOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(option.bg)
                        .frame(width: 48, height: 48)
                    if let assetName = option.assetIcon {
                        Image.androidIcon(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: option.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(option.tint)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundColor(textPrimary)
                    Text(option.subtitle)
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
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
                .stroke(Color(hex: "E6F4EA"),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))

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
                    .foregroundColor(textPrimary)
                Text("of \(caloriesGoal) kcal")
                    .font(.poppins(.regular, size: 10))
                    .foregroundColor(textSecondary)
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
                        .font(.system(size: 11))
                        .foregroundColor(iconTint)
                }
                Text(label)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(textSecondary)
                Spacer()
                Text("\(value) \(goal)")
                    .font(.poppins(.semiBold, size: 11))
                    .foregroundColor(textPrimary)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconTint)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.poppins(.bold, size: 16))
                    .foregroundColor(textPrimary)
                Text(label)
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Activity List Row

private struct ActivityListRow: View {
    let activity: RouteActivity

    private var iconBundle: (icon: String, tint: Color, bg: Color, title: String) {
        switch activity.type {
        case .run:
            return ("figure.run",  Color(hex: "22C55E"), runTint,   runTitle)
        case .walk:
            return ("figure.walk", Color(hex: "EF8B3C"), walkTint,  walkTitle)
        case .commute:
            return ("bicycle",     Color(hex: "3B82F6"), cycleTint, "Cycling")
        }
    }

    private var runTitle: String {
        let h = Calendar.current.component(.hour, from: activity.startTime)
        switch h { case 5...11: return "Morning Run"; case 12...16: return "Afternoon Run"; case 17...20: return "Evening Run"; default: return "Night Run" }
    }

    private var walkTitle: String {
        let h = Calendar.current.component(.hour, from: activity.startTime)
        switch h { case 5...11: return "Morning Walk"; case 12...16: return "Afternoon Walk"; case 17...20: return "Evening Walk"; default: return "Night Walk" }
    }

    private var timeText: String {
        let cal = Calendar.current; let f = DateFormatter()
        if cal.isDateInToday(activity.startTime)     { f.dateFormat = "h:mm a"; return f.string(from: activity.startTime) }
        if cal.isDateInYesterday(activity.startTime) { return "Yesterday" }
        f.dateFormat = "MMM d"; return f.string(from: activity.startTime)
    }

    private var subtitle: String {
        let mins = Int(activity.duration / 60)
        let dur  = mins >= 60 ? "\(mins/60)h \(mins%60)m" : "\(mins) min"
        var parts = [String(format: "%.2f km", activity.distance), dur]
        if activity.distance > 0 && activity.type != .commute {
            let pace = (activity.duration / 60) / max(activity.distance, 0.001)
            parts.append(String(format: "%d:%02d/km", Int(pace), Int((pace - Double(Int(pace))) * 60)))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let b = iconBundle
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(b.bg).frame(width: 40, height: 40)
                Image(systemName: b.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(b.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(b.title)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(textPrimary)
                Text(subtitle)
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(textSecondary)
            }

            Spacer()

            Text(timeText)
                .font(.poppins(.regular, size: 11))
                .foregroundColor(textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Helpers

private enum ActivityHelpers {
    static func formatThousands(_ value: Int) -> String {
        if value < 1000 { return "\(value)" }
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        return String(f.string(from: date).prefix(3))
    }

    /// 1=Mon..7=Sun
    static func weekdayShortInitial(_ mondayBased: Int) -> String {
        let labels = ["", "M", "T", "W", "T", "F", "S", "S"]
        guard mondayBased >= 1, mondayBased <= 7 else { return "" }
        return labels[mondayBased]
    }
}

// MARK: - Rounded-corner shape (selective corners)

struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

// MARK: - Retained public structs (used from other files)

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

struct RouteActivityCardContent: View {
    let activity: RouteActivity

    var body: some View {
        HStack(spacing: 12) {
            ActivityRouteThumbnailMapView(routeCoordinates: activity.routeCoordinates, size: CGSize(width: 80, height: 80))
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: activity.type.icon)
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                    Text(activity.formattedTimeRange)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                }
                Text(activity.name)
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.primary)
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

struct WeeklyComparisonBar: View {
    let average: Double
    let dateRange: String
    let maxValue: Double
    let isCurrent: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", average))
                    .font(.poppins(.bold, size: 20))
                    .foregroundColor(.primary)
                Text("Km / day")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 90, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.systemGray5))
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isCurrent ? accentColor : accentColor.opacity(0.4))
                        .frame(width: max(geometry.size.width * (average / max(maxValue, 0.001)), 0))
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
                Text(title).font(.poppins(.medium, size: 15)).foregroundColor(.primary)
                Spacer()
                Text("\(current)\(unit.isEmpty ? "" : " \(unit)") / \(goal)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - RunStatsAnalyticsView (unchanged; retained for other navigation targets)

struct RunStatsAnalyticsView: View {
    @StateObject private var viewModel = DependencyContainer.shared.runActivityViewModel
    @State private var isAnimating = false
    @State private var selectedTab: AnalyticsTab = .overview

    private let accentBlue  = AppColors.accentBlue
    private let accentGreen = AppColors.accentGreen

    enum AnalyticsTab: String, CaseIterable {
        case overview    = "Overview"
        case performance = "Performance"
        case calendar    = "Calendar"
        case activities  = "Activities"

        var icon: String {
            switch self {
            case .overview:    return "chart.bar.fill"
            case .performance: return "bolt.fill"
            case .calendar:    return "calendar"
            case .activities:  return "list.bullet"
            }
        }
    }

    var body: some View {
        ZStack {
            PremiumBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .overview:    overviewContent
                        case .performance: performanceContent
                        case .calendar:    calendarContent
                        case .activities:  activitiesContent
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { isAnimating = true }
        }
        .task { await viewModel.loadData() }
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon).font(.poppins(.semiBold, size: 12))
                            Text(tab.rawValue).font(.poppins(.semiBold, size: 14)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 20).fill(selectedTab == tab ? accentBlue : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(selectedTab == tab ? Color.clear : Color.primary.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 20)
        }
    }

    private var overviewContent: some View {
        VStack(spacing: 24) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                EnhancedStatCard(title: "Total Steps",  value: "\(viewModel.totalSteps)",                         subtitle: "steps",           icon: "figure.walk", color: accentGreen, trend: 12.5)
                EnhancedStatCard(title: "Distance",     value: String(format: "%.1f", viewModel.totalDistance),   subtitle: "kilometers",      icon: "map",         color: accentBlue,  trend: 8.3)
                EnhancedStatCard(title: "Calories",     value: String(format: "%.0f", Double(viewModel.totalCalories)), subtitle: "kcal burned", icon: "flame.fill", color: .orange,    trend: 15.7)
                EnhancedStatCard(title: "Points",       value: "\(viewModel.totalPoints)",                        subtitle: "activity points", icon: "star.fill",   color: .yellow,    trend: -2.1)
            }
            .padding(.horizontal, 20)

            WeeklyDistanceChart(data: generateWeeklyData(), color: accentBlue).padding(.horizontal, 20)
            ActivityStreakCard(currentStreak: calculateCurrentStreak(), longestStreak: calculateLongestStreak(), color: accentGreen).padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Stats").font(.poppins(.bold, size: 17)).foregroundColor(.primary).padding(.horizontal, 20)
                QuickStatsGrid(
                    avgPace: calculateAvgPace(),
                    avgHeartRate: calculateAvgHeartRate(),
                    totalTime: calculateTotalTime(),
                    avgDistance: viewModel.totalDistance / Double(max(viewModel.activities.count, 1))
                ).padding(.horizontal, 20)
            }

            if let wc = viewModel.weeklyComparison {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.poppins(.semiBold, size: 18)).foregroundColor(accentBlue)
                        Text("Weekly Comparison").font(.poppins(.bold, size: 17)).foregroundColor(.primary)
                        Spacer()
                    }
                    Text(wc.insightText).font(.poppins(.regular, size: 15)).foregroundColor(.secondary).lineSpacing(4)
                    VStack(spacing: 12) {
                        WeeklyComparisonBar(average: wc.currentWeekAverage, dateRange: wc.currentWeekDateRange, maxValue: max(wc.currentWeekAverage, wc.previousWeekAverage), isCurrent: true, accentColor: accentBlue)
                        WeeklyComparisonBar(average: wc.previousWeekAverage, dateRange: wc.previousWeekDateRange, maxValue: max(wc.currentWeekAverage, wc.previousWeekAverage), isCurrent: false, accentColor: accentBlue)
                    }
                }
                .padding(20).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20)
            }
        }
        .opacity(isAnimating ? 1 : 0).offset(y: isAnimating ? 0 : 20).animation(.spring(response: 0.5), value: isAnimating)
    }

    private var performanceContent: some View {
        VStack(spacing: 24) {
            PerformanceInsightsCard(insights: generateInsights()).padding(.horizontal, 20)
            PersonalRecordsSection(records: generatePersonalRecords()).padding(.horizontal, 20)
            PaceDistributionChart(paceRanges: generatePaceDistribution(), color: accentBlue).padding(.horizontal, 20)
            TimeOfDayAnalysis(distribution: generateTimeDistribution()).padding(.horizontal, 20)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target").font(.poppins(.semiBold, size: 18)).foregroundColor(accentBlue)
                    Text("Goals Progress").font(.poppins(.bold, size: 17)).foregroundColor(.primary)
                    Spacer()
                }
                GoalProgressRow(title: "Steps",    current: viewModel.activityGoal.currentSteps,                goal: viewModel.activityGoal.dailyStepsGoal,                               color: accentGreen)
                GoalProgressRow(title: "Distance", current: Int(viewModel.activityGoal.currentDistance * 1000), goal: Int(viewModel.activityGoal.dailyDistanceGoal * 1000), unit: "m",        color: accentBlue)
                GoalProgressRow(title: "Calories", current: viewModel.activityGoal.currentCalories,             goal: viewModel.activityGoal.dailyCaloriesGoal,                            color: .orange)
            }
            .padding(20).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20)
        }
        .opacity(isAnimating ? 1 : 0).offset(y: isAnimating ? 0 : 20).animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }

    private var calendarContent: some View {
        VStack(spacing: 24) { RunCalendarView(activities: viewModel.activities) }
            .opacity(isAnimating ? 1 : 0).offset(y: isAnimating ? 0 : 20).animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }

    private var activitiesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Activities").font(.poppins(.bold, size: 20)).foregroundColor(.primary)
                Spacer()
                Text("\(viewModel.activities.count) total").font(.poppins(.regular, size: 12)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            if viewModel.activities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.circle").font(.poppins(.regular, size: 48)).foregroundColor(.secondary.opacity(0.5))
                    Text("No activities yet").font(.poppins(.semiBold, size: 17)).foregroundColor(.secondary)
                    Text("Start a workout to track your activities").font(.poppins(.regular, size: 15)).foregroundColor(.secondary.opacity(0.8)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60).padding(.horizontal, 20)
            } else {
                ForEach(viewModel.activities) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        RouteActivityCardContent(activity: activity)
                    }
                    .buttonStyle(ScaleButtonStyle()).padding(.horizontal, 20)
                }
            }
        }
        .opacity(isAnimating ? 1 : 0).offset(y: isAnimating ? 0 : 20).animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }

    // helpers
    private func generateWeeklyData() -> [(day: String, distance: Double)] {
        let days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        let cal = Calendar.current; let today = Date()
        return days.enumerated().map { i, day in
            guard let date = cal.date(byAdding: .day, value: -(6-i), to: today) else { return (day, 0.0) }
            let dist = viewModel.activities.filter { cal.isDate($0.startTime, inSameDayAs: date) }.reduce(0.0) { $0 + $1.distance }
            return (day, dist)
        }
    }
    private func calculateCurrentStreak() -> Int {
        guard !viewModel.activities.isEmpty else { return 0 }
        let cal = Calendar.current; var streak = 0; var cur = Date()
        while viewModel.activities.contains(where: { cal.isDate($0.startTime, inSameDayAs: cur) }) {
            streak += 1; cur = cal.date(byAdding: .day, value: -1, to: cur) ?? cur
        }
        return streak
    }
    private func calculateLongestStreak() -> Int {
        guard !viewModel.activities.isEmpty else { return 0 }
        let cal = Calendar.current
        let sorted = viewModel.activities.map { $0.startTime }.sorted()
        var longest = 1; var current = 1
        for i in 1..<sorted.count {
            if (cal.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0) == 1 { current += 1; longest = max(longest, current) } else { current = 1 }
        }
        return longest
    }
    private func calculateAvgPace() -> String {
        let acts = viewModel.activities.filter { $0.distance > 0 }
        guard !acts.isEmpty else { return "--:--" }
        let avg = acts.reduce(0.0) { $0 + $1.duration/60/$1.distance } / Double(acts.count)
        return String(format: "%d:%02d", Int(avg), Int((avg - Double(Int(avg))) * 60))
    }
    private func calculateAvgHeartRate() -> Int {
        let acts = viewModel.activities.filter { $0.averageBPM > 0 }
        guard !acts.isEmpty else { return 0 }
        return acts.reduce(0) { $0 + $1.averageBPM } / acts.count
    }
    private func calculateTotalTime() -> String {
        let secs = viewModel.activities.reduce(0.0) { $0 + $1.duration }
        let h = Int(secs)/3600; let m = (Int(secs)%3600)/60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    private func generateInsights() -> [PerformanceInsight] {
        var insights: [PerformanceInsight] = []
        let activeDays = Set(viewModel.activities.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        insights.append(PerformanceInsight(icon: "checkmark.circle.fill", title: "Consistency", description: "You've been active on \(activeDays) different days", color: accentGreen))
        if viewModel.percentageChange > 0 {
            insights.append(PerformanceInsight(icon: "arrow.up.right.circle.fill", title: "Distance Improved", description: String(format: "Up %.1f%% compared to last period", viewModel.percentageChange), color: accentBlue))
        }
        let morningCount = viewModel.activities.filter { Calendar.current.component(.hour, from: $0.startTime) < 12 }.count
        if morningCount > viewModel.activities.count / 2 {
            insights.append(PerformanceInsight(icon: "sunrise.fill", title: "Morning Person", description: "Most of your workouts are in the morning", color: .orange))
        }
        return insights
    }
    private func generatePersonalRecords() -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        if let r = viewModel.activities.max(by: { $0.distance < $1.distance }) { records.append(PersonalRecord(title: "Longest Distance", value: String(format: "%.2f km", r.distance), date: f.string(from: r.startTime), icon: "map.fill")) }
        if let r = viewModel.activities.max(by: { $0.duration < $1.duration }) { let h = Int(r.duration)/3600; let m = (Int(r.duration)%3600)/60; records.append(PersonalRecord(title: "Longest Duration", value: h > 0 ? "\(h)h \(m)m" : "\(m)m", date: f.string(from: r.startTime), icon: "clock.fill")) }
        if let r = viewModel.activities.max(by: { $0.steps < $1.steps }) { records.append(PersonalRecord(title: "Most Steps", value: "\(r.steps)", date: f.string(from: r.startTime), icon: "figure.walk")) }
        return records
    }
    private func generatePaceDistribution() -> [(range: String, count: Int)] {
        let ranges: [(String, Range<Double>)] = [("< 5:00",0..<5),("5:00-6:00",5..<6),("6:00-7:00",6..<7),("7:00-8:00",7..<8),("> 8:00",8..<100)]
        return ranges.map { (label, r) in (label, viewModel.activities.filter { a in guard a.distance > 0 else { return false }; let p = a.duration/60/a.distance; return p >= r.lowerBound && p < r.upperBound }.count) }
    }
    private func generateTimeDistribution() -> [(time: String, count: Int)] {
        let ranges: [(String, Range<Int>)] = [("Morning",5..<12),("Afternoon",12..<17),("Evening",17..<21),("Night",21..<24)]
        return ranges.map { (label, r) in (label, viewModel.activities.filter { r.contains(Calendar.current.component(.hour, from: $0.startTime)) }.count) }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RunActivityView()
    }
}
