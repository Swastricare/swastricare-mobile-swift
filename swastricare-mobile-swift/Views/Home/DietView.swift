//
//  DietView.swift
//  swastricare-mobile-swift
//
//  Diet Chart - Main view for food logging and nutrition tracking
//

import SwiftUI

struct DietView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel

    @State private var selectedMealType: MealType = .breakfast
    @State private var calendarAppeared = false
    @State private var progressAppeared = false
    @State private var macrosAppeared = false
    @State private var mealsAppeared = false
    @State private var insightsAppeared = false
    @State private var aiButtonAppeared = false
    @State private var trendAppeared = false
    @State private var showCopiedToast = false

    var body: some View {
        NavigationView {
            ZStack {
                // Theme-aware Background
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Calendar Strip
                        calendarStrip
                            .opacity(calendarAppeared ? 1 : 0)
                            .offset(y: calendarAppeared ? 0 : 16)

                        // Progress Section
                        progressSection
                            .opacity(progressAppeared ? 1 : 0)
                            .offset(y: progressAppeared ? 0 : 20)

                        // Macro Breakdown
                        macroBreakdownSection
                            .opacity(macrosAppeared ? 1 : 0)
                            .offset(y: macrosAppeared ? 0 : 20)

                        // Weekly Trend Chart + Goal Adherence
                        if !viewModel.weeklyTrend.isEmpty {
                            weeklyTrendSection
                                .opacity(trendAppeared ? 1 : 0)
                                .offset(y: trendAppeared ? 0 : 20)
                        }

                        // Copy Yesterday's Meals
                        if viewModel.hasYesterdaysMeals && Calendar.current.isDateInToday(viewModel.selectedDate) {
                            copyYesterdayButton
                                .opacity(trendAppeared ? 1 : 0)
                                .offset(y: trendAppeared ? 0 : 20)
                        }

                        // Meal Sections
                        mealSectionsView
                            .opacity(mealsAppeared ? 1 : 0)
                            .offset(y: mealsAppeared ? 0 : 20)

                        // Insights Card
                        if let insights = viewModel.insights {
                            insightsCard(insights)
                                .opacity(insightsAppeared ? 1 : 0)
                                .offset(y: insightsAppeared ? 0 : 20)
                        }

                        // Ask AI about diet
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Ask AI about my diet")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accentBlue, AppColors.accentBlue.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: AppColors.accentBlue.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal, 20)
                        .opacity(aiButtonAppeared ? 1 : 0)
                        .offset(y: aiButtonAppeared ? 0 : 20)
                    }
                    .padding(.bottom, 20)
                }

                // Undo Delete Toast
                if viewModel.showUndoToast {
                    VStack {
                        Spacer()
                        undoDeleteToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 16)
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showUndoToast)
                }
            }
            .navigationTitle("Diet Chart")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showSettings = true }) {
                            Label("Goals & Settings", systemImage: "gearshape.fill")
                        }

                        Button(action: { viewModel.showAddFood = true }) {
                            Label("Add Food", systemImage: "plus.circle.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.accentGreen)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                AppAnalyticsService.shared.logScreen("diet")
                triggerEntranceAnimations()
            }
            .task {
                await viewModel.onAppear()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $viewModel.showAddFood) {
                AddFoodView(viewModel: viewModel, selectedMealType: selectedMealType)
            }
            .sheet(isPresented: $viewModel.showSettings) {
                DietSettingsView(viewModel: viewModel)
            }
        }
    }

    private func triggerEntranceAnimations() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.05)) {
            calendarAppeared = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.15)) {
            progressAppeared = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.25)) {
            macrosAppeared = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.30)) {
            trendAppeared = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.35)) {
            mealsAppeared = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.45)) {
            insightsAppeared = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.55)) {
            aiButtonAppeared = true
        }
    }

    // MARK: - Calendar Strip

    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index - 3, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)

                    VStack(spacing: 6) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isSelected ? AppColors.accentGreen : .secondary)

                        ZStack {
                            // Today ring (subtle)
                            if isToday && !isSelected {
                                Circle()
                                    .strokeBorder(AppColors.accentGreen.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 36, height: 36)
                            }

                            // Selected fill
                            Circle()
                                .fill(isSelected ? AppColors.accentGreen : Color.clear)
                                .frame(width: 36, height: 36)

                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(isSelected ? .white : (isToday ? AppColors.accentGreen : .primary))
                        }
                    }
                    .frame(width: 50)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isToday && !isSelected ? AppColors.accentGreen.opacity(0.07) : Color.clear)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            viewModel.selectedDate = date
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 16) {
            // Goal description
            Text(viewModel.goalDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            // Calorie Progress Ring (centered hero)
            CalorieProgressRing(
                current: viewModel.totalCalories,
                goal: viewModel.dietGoals.dailyCalories,
                progress: viewModel.calorieProgress
            )

            // Stat pills row
            HStack(spacing: 10) {
                dietStatPill(
                    icon: "flame.fill",
                    color: AppColors.accentGreen,
                    value: "\(viewModel.totalCalories)",
                    label: "of \(viewModel.dietGoals.dailyCalories) cal"
                )

                dietStatPill(
                    icon: "arrow.up.circle.fill",
                    color: AppColors.accentOrange,
                    value: "\(viewModel.remainingCalories)",
                    label: "remaining"
                )

                dietStatPill(
                    icon: "fork.knife",
                    color: AppColors.accentBlue,
                    value: "\(viewModel.nutritionSummary.mealCount)",
                    label: "meals"
                )
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.largeCardRadius)
        .padding(.horizontal, 20)
    }

    private func dietStatPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Macro Breakdown Section

    private var macroBreakdownSection: some View {
        MacroBreakdownCard(
            proteinCurrent: Int(viewModel.nutritionSummary.totalProteinG),
            proteinGoal: viewModel.dietGoals.proteinGrams,
            proteinProgress: viewModel.proteinProgress,
            carbsCurrent: Int(viewModel.nutritionSummary.totalCarbsG),
            carbsGoal: viewModel.dietGoals.carbsGrams,
            carbsProgress: viewModel.carbsProgress,
            fatCurrent: Int(viewModel.nutritionSummary.totalFatG),
            fatGoal: viewModel.dietGoals.fatGrams,
            fatProgress: viewModel.fatProgress
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Meal Sections

    private var mealSectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Meals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(MealType.allCases) { mealType in
                    MealSectionCard(
                        mealType: mealType,
                        entries: viewModel.getMealLogs(for: mealType),
                        onDelete: { entry in
                            Task {
                                await viewModel.deleteLog(entry)
                            }
                        },
                        onAddFood: {
                            selectedMealType = mealType
                            viewModel.showAddFood = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Insights Card

    private func insightsCard(_ insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.accentGreen)
                Text("Insights")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                insightItem(
                    value: "\(insights.currentStreak)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: .orange,
                    highlightValue: true
                )

                insightItem(
                    value: "\(insights.weeklyAverageCalories)",
                    label: "Avg cal/day",
                    icon: "chart.bar.fill",
                    color: AppColors.accentGreen,
                    highlightValue: false
                )

                if let best = insights.bestDay {
                    insightItem(
                        value: "\(best.calories)",
                        label: "Best Day",
                        icon: "trophy.fill",
                        color: .yellow,
                        highlightValue: false
                    )
                }
            }

            if !insights.topFoods.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Foods")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(insights.topFoods, id: \.self) { food in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(AppColors.accentGreen)
                            Text(food)
                                .font(.subheadline)
                        }
                    }
                }
            }

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.accentGreen)
                Text("Macro balance: \(insights.macroBalance)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private func insightItem(value: String, label: String, icon: String, color: Color, highlightValue: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(highlightValue ? AppColors.accentGreen : .primary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly Trend Chart

    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(AppColors.accentBlue)
                Text("Weekly Trend")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                // Goal adherence badge
                HStack(spacing: 4) {
                    Image(systemName: viewModel.goalAdherence.rating.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(viewModel.goalAdherence.adherencePercent)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(adherenceColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(adherenceColor.opacity(0.12))
                .clipShape(Capsule())
            }

            // Bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyTrend) { day in
                    VStack(spacing: 6) {
                        // Calorie label on top
                        Text("\(day.calories)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(day.isToday ? AppColors.accentGreen : .secondary)
                            .opacity(day.calories > 0 ? 1 : 0)

                        // Bar
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                day.isToday
                                    ? AppColors.accentGreen
                                    : (day.progress >= 0.9 ? AppColors.accentGreen.opacity(0.5) : AppColors.accentBlue.opacity(0.4))
                            )
                            .frame(height: max(4, CGFloat(day.progress) * 60))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: day.progress)

                        // Day label
                        Text(day.dayLabel)
                            .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                            .foregroundColor(day.isToday ? AppColors.accentGreen : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            // Goal line label
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(height: 1)
                Text("Goal: \(viewModel.dietGoals.dailyCalories) cal")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(height: 1)
            }

            // Adherence summary
            HStack(spacing: 16) {
                adherenceStat(
                    label: "Days Tracked",
                    value: "\(viewModel.goalAdherence.daysTracked)/7",
                    color: AppColors.accentBlue
                )
                adherenceStat(
                    label: "On Target",
                    value: "\(viewModel.goalAdherence.daysOnTarget)",
                    color: AppColors.accentGreen
                )
                adherenceStat(
                    label: "Rating",
                    value: viewModel.goalAdherence.rating.rawValue,
                    color: adherenceColor
                )
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.largeCardRadius)
        .padding(.horizontal, 20)
    }

    private var adherenceColor: Color {
        switch viewModel.goalAdherence.rating {
        case .excellent: return AppColors.accentGreen
        case .good: return AppColors.accentBlue
        case .fair: return .orange
        case .needsWork: return AppColors.accentRed
        }
    }

    private func adherenceStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Copy Yesterday Button

    private var copyYesterdayButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await viewModel.copyYesterdaysMeals()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCopiedToast = true
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation {
                    showCopiedToast = false
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accentBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(showCopiedToast ? "Meals Copied!" : "Copy Yesterday's Meals")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(showCopiedToast ? AppColors.accentGreen : .primary)
                    Text("Quickly repeat your meals from yesterday")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: showCopiedToast ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(showCopiedToast ? AppColors.accentGreen : AppColors.accentBlue.opacity(0.6))
            }
            .padding(16)
            .glass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.accentBlue.opacity(0.15), lineWidth: 0.8)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(showCopiedToast)
        .padding(.horizontal, 20)
    }

    // MARK: - Undo Delete Toast

    private var undoDeleteToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text("Meal deleted")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.undoDelete()
            } label: {
                Text("Undo")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.accentGreen.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray6).opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    DietView(viewModel: DietViewModel())
}
