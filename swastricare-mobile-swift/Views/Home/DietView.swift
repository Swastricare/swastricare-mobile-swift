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
    // Fast Logging: template & quick-log state
    @State private var showSaveTemplateSheet = false
    @State private var templateMealType: MealType = .breakfast
    @State private var templateName = ""
    @State private var showQuickLogPopover = false
    @State private var mealCopiedType: MealType?

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

                // Quick Log FAB (from Fast Logging branch)
                quickLogFAB

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
            .sheet(isPresented: $showSaveTemplateSheet) {
                saveTemplateSheet
            }
            .sheet(isPresented: $viewModel.showWeeklyReport) {
                if let report = viewModel.weeklyReport {
                    WeeklyReportSheet(report: report)
                }
            }
        }
    }

    // MARK: - Save Template Sheet (from Fast Logging branch)

    private var saveTemplateSheet: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("My usual \(templateMealType.displayName.lowercased())", text: $templateName)
                            .font(.system(size: 17))
                            .padding(14)
                            .glass(cornerRadius: 12)
                    }

                    // Preview items
                    let entries = viewModel.getMealLogs(for: templateMealType)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items (\(entries.count))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        ForEach(entries) { entry in
                            HStack {
                                Text(entry.foodName)
                                    .font(.system(size: 15))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(entry.calories)) cal")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.accentGreen)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(16)
                    .glass(cornerRadius: 14)

                    Spacer()

                    Button {
                        let name = templateName.isEmpty ? "\(templateMealType.displayName) template" : templateName
                        viewModel.saveMealAsTemplate(mealType: templateMealType, name: name)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showSaveTemplateSheet = false
                        templateName = ""
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Save Template")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.greenGradient)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Save as Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showSaveTemplateSheet = false
                        templateName = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Quick Log FAB (from Fast Logging branch)

    private var quickLogFAB: some View {
        let currentMeal = MealSuggestionEngine.currentMealType()
        let topSuggestions = Array(viewModel.suggestedFoods.prefix(3))

        return Group {
            if !topSuggestions.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()

                        Menu {
                            ForEach(topSuggestions) { food in
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task {
                                        await viewModel.quickLogFood(food, mealType: currentMeal)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }
                                } label: {
                                    Label("\(food.name) (\(Int(food.calories)) cal)", systemImage: "plus.circle")
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppColors.greenGradient)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: AppColors.accentGreen.opacity(0.4), radius: 8, x: 0, y: 4)

                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
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

    // MARK: - Meal Sections (with per-meal context menu from Fast Logging branch)

    private var mealSectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Meals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(MealType.allCases) { mealType in
                    VStack(spacing: 0) {
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
                        .contextMenu {
                            // Save as Template (only if meal has entries)
                            if !viewModel.getMealLogs(for: mealType).isEmpty {
                                Button {
                                    templateMealType = mealType
                                    templateName = "\(mealType.displayName) template"
                                    showSaveTemplateSheet = true
                                } label: {
                                    Label("Save as Template", systemImage: "doc.badge.plus")
                                }
                            }

                            // Copy this meal from yesterday
                            if viewModel.hasYesterdaysMeal(for: mealType) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task {
                                        await viewModel.copySingleMeal(mealType)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            mealCopiedType = mealType
                                        }
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        withAnimation {
                                            mealCopiedType = nil
                                        }
                                    }
                                } label: {
                                    Label("Copy from Yesterday", systemImage: "doc.on.doc")
                                }
                            }
                        }

                        // Per-meal copied toast
                        if mealCopiedType == mealType {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.accentGreen)
                                Text("\(mealType.displayName) copied!")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.accentGreen)
                            }
                            .padding(.top, 6)
                            .transition(.opacity)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Insights Card (merged: Intelligence streak/coaching/gaps/timing + original)

    private func insightsCard(_ insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.accentGreen)
                Text("Insights")
                    .font(.headline)
            }

            // Enhanced streak display (from Intelligence branch)
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(insights.streakEmoji)
                        .font(.system(size: 24))

                    Text("\(insights.currentStreak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.accentGreen)

                    Text("Day Streak")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if let next = insights.nextMilestone {
                        Text("\(next - insights.currentStreak) to next")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
                .frame(maxWidth: .infinity)

                insightItem(
                    value: "\(insights.weeklyAverageCalories)",
                    label: "Avg cal/day",
                    icon: "chart.bar.fill",
                    color: AppColors.accentGreen,
                    highlightValue: false
                )

                if insights.bestStreak > 0 {
                    insightItem(
                        value: "\(insights.bestStreak)",
                        label: "Best Streak",
                        icon: "trophy.fill",
                        color: .yellow,
                        highlightValue: false
                    )
                } else if let best = insights.bestDay {
                    insightItem(
                        value: "\(best.calories)",
                        label: "Best Day",
                        icon: "trophy.fill",
                        color: .yellow,
                        highlightValue: false
                    )
                }
            }

            // Coaching Tips (from Intelligence branch)
            if !insights.coachingTips.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                        Text("Coaching Tips")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    ForEach(insights.coachingTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.accentGreen)
                                .padding(.top, 3)
                            Text(tip)
                                .font(.system(size: 13))
                                .foregroundColor(.primary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // Nutrient Gaps (from Intelligence branch)
            if !insights.nutrientGaps.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.accentRed)
                        Text("Nutrient Gaps")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    ForEach(insights.nutrientGaps) { gap in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(gap.nutrient)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(Int(gap.averageIntake))/\(Int(gap.recommendedIntake))\(gap.nutrient == "Calories" ? " cal" : "g")")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(nutrientGapColor(deficit: gap.deficitPercent))
                                        .frame(width: max(0, geo.size.width * min(1, gap.averageIntake / max(1, gap.recommendedIntake))), height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text(gap.suggestion)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Meal Timing Insights (from Intelligence branch)
            if !insights.mealTimingInsights.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.accentBlue)
                        Text("Meal Timing")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    ForEach(insights.mealTimingInsights) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: mealTimingIcon(for: insight.severity))
                                .font(.system(size: 10))
                                .foregroundColor(mealTimingColor(for: insight.severity))
                                .padding(.top, 3)
                            Text(insight.message)
                                .font(.system(size: 13))
                                .foregroundColor(.primary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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

            // View Weekly Report button (from Intelligence branch)
            Divider()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.generateWeeklyReport()
                viewModel.showWeeklyReport = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text("View Weekly Report")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppColors.accentBlue)
                .padding(.vertical, 4)
            }
            .buttonStyle(ScaleButtonStyle())
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

    // MARK: - Insight Helpers (from Intelligence branch)

    private func nutrientGapColor(deficit: Double) -> Color {
        if deficit > 40 {
            return AppColors.accentRed
        } else if deficit > 20 {
            return .orange
        } else {
            return AppColors.accentGreen
        }
    }

    private func mealTimingIcon(for severity: InsightSeverity) -> String {
        switch severity {
        case .info: return "checkmark.circle.fill"
        case .suggestion: return "lightbulb.fill"
        case .warning: return "exclamationmark.circle.fill"
        }
    }

    private func mealTimingColor(for severity: InsightSeverity) -> Color {
        switch severity {
        case .info: return AppColors.accentGreen
        case .suggestion: return .orange
        case .warning: return AppColors.accentRed
        }
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

// MARK: - Weekly Report Sheet (from Intelligence branch)

struct WeeklyReportSheet: View {
    @Environment(\.dismiss) var dismiss
    let report: WeeklyDietReport

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        reportHeader

                        // Calorie Summary
                        calorieSummaryCard

                        // Macro Averages
                        macroAveragesCard

                        // Streak Info
                        streakCard

                        // Nutrient Gaps
                        if !report.nutrientGaps.isEmpty {
                            nutrientGapsCard
                        }

                        // Meal Timing Insights
                        if !report.mealTimingInsights.isEmpty {
                            mealTimingCard
                        }

                        // Top Foods
                        if !report.topFoods.isEmpty {
                            topFoodsCard
                        }

                        // Improvement Tips
                        if !report.improvementTips.isEmpty {
                            improvementTipsCard
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accentGreen)
                }
            }
        }
    }

    // MARK: - Report Sections

    private var reportHeader: some View {
        VStack(spacing: 6) {
            let formatter = DateFormatter()
            let _ = formatter.dateFormat = "MMM d"
            Text("\(formatter.string(from: report.startDate)) - \(formatter.string(from: report.endDate))")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text("\(report.totalMealsLogged) meals logged")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.top, 8)
    }

    private var calorieSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Calorie Summary")
                    .font(.system(size: 16, weight: .semibold))
            }

            HStack(spacing: 16) {
                reportStat(
                    value: "\(report.averageDailyCalories)",
                    label: "Avg/Day",
                    color: AppColors.accentGreen
                )
                reportStat(
                    value: "\(report.calorieGoal)",
                    label: "Goal",
                    color: AppColors.accentBlue
                )
                reportStat(
                    value: "\(Int(report.adherencePercent))%",
                    label: "Adherence",
                    color: report.adherencePercent >= 70 ? AppColors.accentGreen : .orange
                )
            }

            if let best = report.bestDay {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                    Text("Best day: \(best.calories) cal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private var macroAveragesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(AppColors.accentBlue)
                Text("Average Macros")
                    .font(.system(size: 16, weight: .semibold))
            }

            HStack(spacing: 16) {
                reportStat(
                    value: "\(Int(report.macroAverages.proteinG))g",
                    label: "Protein",
                    color: AppColors.accentBlue
                )
                reportStat(
                    value: "\(Int(report.macroAverages.carbsG))g",
                    label: "Carbs",
                    color: AppColors.accentGreen
                )
                reportStat(
                    value: "\(Int(report.macroAverages.fatG))g",
                    label: "Fat",
                    color: .orange
                )
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private var streakCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(report.streakInfo.current > 0 ? "\u{1F525}" : "\u{2744}\u{FE0F}")
                    .font(.system(size: 28))
                Text("\(report.streakInfo.current)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
                Text("Current")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("\u{1F3C6}")
                    .font(.system(size: 28))
                Text("\(report.streakInfo.best)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                Text("Best")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private var nutrientGapsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.accentRed)
                Text("Nutrient Gaps")
                    .font(.system(size: 16, weight: .semibold))
            }

            ForEach(report.nutrientGaps) { gap in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(gap.nutrient)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text("\(Int(gap.averageIntake))/\(Int(gap.recommendedIntake))")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text(gap.suggestion)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private var mealTimingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(AppColors.accentBlue)
                Text("Meal Timing")
                    .font(.system(size: 16, weight: .semibold))
            }

            ForEach(report.mealTimingInsights) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(insightSeverityColor(insight.severity))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    Text(insight.message)
                        .font(.system(size: 13))
                        .foregroundColor(.primary.opacity(0.85))
                }
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private var topFoodsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(AppColors.accentGreen)
                Text("Top Foods This Week")
                    .font(.system(size: 16, weight: .semibold))
            }

            ForEach(Array(report.topFoods.enumerated()), id: \.offset) { index, food in
                HStack {
                    Text("\(index + 1).")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.accentGreen)
                        .frame(width: 24)
                    Text(food.name)
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(food.count)x")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    private var improvementTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Improvement Tips")
                    .font(.system(size: 16, weight: .semibold))
            }

            ForEach(report.improvementTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.accentGreen)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.system(size: 13))
                        .foregroundColor(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .glass(cornerRadius: AppDimensions.cardRadius)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func reportStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightSeverityColor(_ severity: InsightSeverity) -> Color {
        switch severity {
        case .info: return AppColors.accentGreen
        case .suggestion: return .orange
        case .warning: return AppColors.accentRed
        }
    }
}

#Preview {
    DietView(viewModel: DietViewModel())
}
