//
//  DietView.swift
//  swastricare-mobile-swift
//
//  Diet screen — Apple Health-style clean layout
//

import SwiftUI

struct DietView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel

    @State private var selectedMealType: MealType = .breakfast
    @State private var showCopiedToast = false
    @State private var showSaveTemplateSheet = false
    @State private var templateMealType: MealType = .breakfast
    @State private var templateName = ""
    @State private var mealCopiedType: MealType?
    @State private var showFoodSnap = false
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Date picker strip
                    dateStrip
                        .padding(.top, 8)

                    // Hero calorie card
                    calorieHeroCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Macro row
                    macroRow
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Copy yesterday banner (contextual)
                    if viewModel.hasYesterdaysMeals && Calendar.current.isDateInToday(viewModel.selectedDate) {
                        copyYesterdayBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    // Meals header
                    HStack {
                        Text(Calendar.current.isDateInToday(viewModel.selectedDate) ? "Today's Meals" : "Meals")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 8)

                    // Meal sections
                    mealList

                    // Weekly chart
                    if !viewModel.weeklyTrend.isEmpty {
                        weeklySection
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    }

                    // Insights
                    if let insights = viewModel.insights {
                        insightsSection(insights)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }

                    Spacer().frame(height: 100)
                }
            }

            // Undo toast
            if viewModel.showUndoToast {
                undoToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showUndoToast)
            }

            // Camera FAB
            cameraFAB
        }
        .navigationTitle("Diet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { viewModel.showAddFood = true }) {
                        Label("Add Food", systemImage: "plus.circle.fill")
                    }
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showFoodSnap = true
                    }) {
                        Label("Snap Food Photo", systemImage: "camera.fill")
                    }
                    Divider()
                    Button(action: { viewModel.showSettings = true }) {
                        Label("Goals & Settings", systemImage: "gearshape.fill")
                    }
                    if viewModel.insights != nil {
                        Button(action: {
                            viewModel.generateWeeklyReport()
                            viewModel.showWeeklyReport = true
                        }) {
                            Label("Weekly Report", systemImage: "chart.bar.doc.horizontal")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("diet")
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
        .task { await viewModel.onAppear() }
        .refreshable { await viewModel.refresh() }
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
        .fullScreenCover(isPresented: $showFoodSnap) {
            FoodSnapView(viewModel: viewModel, suggestedMealType: MealType.autoDetect())
        }
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<7) { i in
                    let date = Calendar.current.date(byAdding: .day, value: i - 3, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.selectedDate = date
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 5) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 34, height: 34)
                                } else if isToday {
                                    Circle()
                                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                                        .frame(width: 34, height: 34)
                                }

                                Text(date.formatted(.dateTime.day()))
                                    .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                            }
                        }
                        .frame(width: 44, height: 60)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Calorie Hero Card

    private var calorieHeroCard: some View {
        HStack(alignment: .center, spacing: 0) {
            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemFill), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: appeared ? min(viewModel.calorieProgress, 1.0) : 0)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: viewModel.calorieProgress)

                VStack(spacing: 1) {
                    Text("\(viewModel.totalCalories)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("of \(viewModel.dietGoals.dailyCalories)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Stats column
            VStack(alignment: .leading, spacing: 0) {
                statRow(
                    label: "Remaining",
                    value: "\(viewModel.remainingCalories)",
                    unit: "cal",
                    color: remainingColor
                )

                Divider()
                    .padding(.vertical, 10)

                statRow(
                    label: "Consumed",
                    value: "\(viewModel.totalCalories)",
                    unit: "cal",
                    color: .primary
                )

                Divider()
                    .padding(.vertical, 10)

                statRow(
                    label: "Meals",
                    value: "\(viewModel.nutritionSummary.mealCount)",
                    unit: "logged",
                    color: .secondary
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 24)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(label: String, value: String, unit: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var ringColor: Color {
        if viewModel.calorieProgress >= 1.0 { return .orange }
        if viewModel.calorieProgress >= 0.75 { return AppColors.accentGreen }
        return AppColors.accentBlue
    }

    private var remainingColor: Color {
        viewModel.remainingCalories < 0 ? .orange : AppColors.accentGreen
    }

    // MARK: - Macro Row

    private var macroRow: some View {
        HStack(spacing: 10) {
            macroPill(
                label: "Protein",
                current: Int(viewModel.nutritionSummary.totalProteinG),
                goal: viewModel.dietGoals.proteinGrams,
                progress: viewModel.proteinProgress,
                color: AppColors.accentBlue
            )
            macroPill(
                label: "Carbs",
                current: Int(viewModel.nutritionSummary.totalCarbsG),
                goal: viewModel.dietGoals.carbsGrams,
                progress: viewModel.carbsProgress,
                color: AppColors.accentGreen
            )
            macroPill(
                label: "Fat",
                current: Int(viewModel.nutritionSummary.totalFatG),
                goal: viewModel.dietGoals.fatGrams,
                progress: viewModel.fatProgress,
                color: .orange
            )
        }
    }

    private func macroPill(label: String, current: Int, goal: Int, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(current)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text("/ \(goal)g")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 5)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Copy Yesterday Banner

    private var copyYesterdayBanner: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await viewModel.copyYesterdaysMeals()
                withAnimation { showCopiedToast = true }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation { showCopiedToast = false }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: showCopiedToast ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(showCopiedToast ? AppColors.accentGreen : Color.accentColor)
                    .frame(width: 20)

                Text(showCopiedToast ? "Meals copied from yesterday" : "Copy yesterday's meals")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(showCopiedToast ? AppColors.accentGreen : .primary)

                Spacer()

                if !showCopiedToast {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(showCopiedToast)
    }

    // MARK: - Meal List

    private var mealList: some View {
        VStack(spacing: 0) {
            ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, mealType in
                VStack(spacing: 0) {
                    MealSectionRow(
                        mealType: mealType,
                        entries: viewModel.getMealLogs(for: mealType),
                        onDelete: { entry in
                            Task { await viewModel.deleteLog(entry) }
                        },
                        onAddFood: {
                            selectedMealType = mealType
                            viewModel.showAddFood = true
                        }
                    )
                    .contextMenu {
                        if !viewModel.getMealLogs(for: mealType).isEmpty {
                            Button {
                                templateMealType = mealType
                                templateName = "\(mealType.displayName) template"
                                showSaveTemplateSheet = true
                            } label: {
                                Label("Save as Template", systemImage: "doc.badge.plus")
                            }
                        }
                        if viewModel.hasYesterdaysMeal(for: mealType) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task {
                                    await viewModel.copySingleMeal(mealType)
                                    withAnimation { mealCopiedType = mealType }
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    withAnimation { mealCopiedType = nil }
                                }
                            } label: {
                                Label("Copy from Yesterday", systemImage: "doc.on.doc")
                            }
                        }
                    }

                    if index < MealType.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Weekly Chart Section

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("This Week")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                HStack(spacing: 4) {
                    Text("\(viewModel.goalAdherence.adherencePercent)%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(adherenceColor)
                    Text("on target")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(viewModel.weeklyTrend) { day in
                    VStack(spacing: 5) {
                        if day.calories > 0 {
                            Text("\(day.calories)")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(day.isToday ? AppColors.accentGreen : .secondary)
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                day.isToday ? AppColors.accentGreen
                                : day.progress >= 0.9 ? AppColors.accentGreen.opacity(0.45)
                                : Color(UIColor.systemFill)
                            )
                            .frame(height: max(6, CGFloat(day.progress) * 72))
                            .animation(.spring(response: 0.55, dampingFraction: 0.75), value: day.progress)

                        Text(day.dayLabel)
                            .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                            .foregroundStyle(day.isToday ? AppColors.accentGreen : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            HStack(spacing: 20) {
                weekStat(label: "Days tracked", value: "\(viewModel.goalAdherence.daysTracked)/7")
                weekStat(label: "On target", value: "\(viewModel.goalAdherence.daysOnTarget)")
                weekStat(label: "Goal", value: "\(viewModel.dietGoals.dailyCalories) cal")
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func weekStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var adherenceColor: Color {
        switch viewModel.goalAdherence.rating {
        case .excellent: return AppColors.accentGreen
        case .good: return AppColors.accentBlue
        case .fair: return .orange
        case .needsWork: return AppColors.accentRed
        }
    }

    // MARK: - Insights Section

    private func insightsSection(_ insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Streak + avg row
            HStack(spacing: 0) {
                insightCell(
                    topLine: "\(insights.currentStreak)",
                    bottomLine: "day streak",
                    icon: insights.streakEmoji,
                    isEmoji: true
                )

                insightDivider

                insightCell(
                    topLine: "\(insights.weeklyAverageCalories)",
                    bottomLine: "avg cal/day",
                    icon: "chart.bar.fill",
                    isEmoji: false
                )

                if insights.bestStreak > 0 {
                    insightDivider
                    insightCell(
                        topLine: "\(insights.bestStreak)",
                        bottomLine: "best streak",
                        icon: "🏆",
                        isEmoji: true
                    )
                }
            }
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Coaching tips
            if !insights.coachingTips.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(insights.coachingTips.prefix(3).enumerated()), id: \.offset) { i, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                                .frame(width: 20)
                                .padding(.top, 1)
                            Text(tip)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if i < min(insights.coachingTips.count, 3) - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 12)
            }
        }
    }

    private var insightDivider: some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.5))
            .frame(width: 0.5)
            .padding(.vertical, 12)
    }

    private func insightCell(topLine: String, bottomLine: String, icon: String, isEmoji: Bool) -> some View {
        VStack(spacing: 4) {
            if isEmoji {
                Text(icon)
                    .font(.system(size: 20))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.accentGreen)
            }
            Text(topLine)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(bottomLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Camera FAB

    private var cameraFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showFoodSnap = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.accentGreen)
                        .clipShape(Circle())
                        .shadow(color: AppColors.accentGreen.opacity(0.35), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Undo Toast

    private var undoToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Meal deleted")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.undoDelete()
            } label: {
                Text("Undo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.accentGreen)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Save Template Sheet

    private var saveTemplateSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("My usual \(templateMealType.displayName.lowercased())", text: $templateName)
                        .font(.system(size: 17))
                        .padding(14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                let entries = viewModel.getMealLogs(for: templateMealType)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items (\(entries.count))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                            HStack {
                                Text(entry.foodName)
                                    .font(.system(size: 15))
                                Spacer()
                                Text("\(Int(entry.calories)) cal")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppColors.accentGreen)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            if i < entries.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button {
                    let name = templateName.isEmpty ? "\(templateMealType.displayName) template" : templateName
                    viewModel.saveMealAsTemplate(mealType: templateMealType, name: name)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showSaveTemplateSheet = false
                    templateName = ""
                } label: {
                    Text("Save Template")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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
}

// MARK: - Meal Section Row (Apple Health list style)

struct MealSectionRow: View {
    let mealType: MealType
    let entries: [DietLogEntry]
    let onDelete: (DietLogEntry) -> Void
    let onAddFood: () -> Void

    @State private var isExpanded = true

    private var totalCalories: Int {
        Int(entries.reduce(0.0) { $0 + $1.calories })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — tap to collapse
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(mealType.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: mealType.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(mealType.color)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(mealType.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(mealType.typicalTime)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !entries.isEmpty {
                        Text("\(totalCalories)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text("cal")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 70)

                    if entries.isEmpty {
                        // Empty tap target
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onAddFood()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 15))
                                    .foregroundStyle(mealType.color)
                                Text("Add \(mealType.displayName.lowercased())")
                                    .font(.system(size: 15))
                                    .foregroundStyle(mealType.color)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                            FoodEntryRowClean(entry: entry, mealColor: mealType.color) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onDelete(entry)
                            }

                            if i < entries.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }

                        // Add more
                        Divider().padding(.leading, 70)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onAddFood()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(mealType.color)
                                Text("Add more")
                                    .font(.system(size: 14))
                                    .foregroundStyle(mealType.color)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Food Entry Row (clean list style)

struct FoodEntryRowClean: View {
    let entry: DietLogEntry
    let mealColor: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Food icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: 40, height: 40)
                Text("🍽️")
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(entry.displayQuantity)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("cal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(UIColor.systemRed).opacity(0.8))
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Weekly Report Sheet

struct WeeklyReportSheet: View {
    @Environment(\.dismiss) var dismiss
    let report: WeeklyDietReport

    @State private var barsAppeared = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var adherenceColor: Color {
        if report.adherencePercent >= 80 { return AppColors.accentGreen }
        if report.adherencePercent >= 55 { return .orange }
        return AppColors.accentRed
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Hero header ──────────────────────────────────────────
                    heroHeader

                    // ── Calorie + streak quick stats ─────────────────────────
                    calorieStatsCard

                    // ── Macro averages ───────────────────────────────────────
                    macrosCard

                    // ── Nutrient gaps ────────────────────────────────────────
                    if !report.nutrientGaps.isEmpty {
                        nutrientGapsCard
                    }

                    // ── Top foods ────────────────────────────────────────────
                    if !report.topFoods.isEmpty {
                        topFoodsCard
                    }

                    // ── Tips ─────────────────────────────────────────────────
                    if !report.improvementTips.isEmpty {
                        tipsCard
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                    barsAppeared = true
                }
            }
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        VStack(spacing: 4) {
            Text("\(Self.dateFormatter.string(from: report.startDate)) – \(Self.dateFormatter.string(from: report.endDate))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(report.totalMealsLogged) meals logged this week")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Calorie + streak card

    private var calorieStatsCard: some View {
        VStack(spacing: 0) {
            // Big adherence number at top
            VStack(spacing: 4) {
                Text("\(Int(report.adherencePercent))%")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(adherenceColor)
                Text("goal adherence")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)

            Divider()

            // Three stats in a row
            HStack(spacing: 0) {
                reportStatCell(
                    value: "\(report.averageDailyCalories)",
                    unit: "cal",
                    label: "avg / day"
                )
                reportDivider
                reportStatCell(
                    value: "\(report.calorieGoal)",
                    unit: "cal",
                    label: "daily goal"
                )
                reportDivider
                if let best = report.bestDay {
                    reportStatCell(
                        value: "\(best.calories)",
                        unit: "cal",
                        label: "best day"
                    )
                } else {
                    reportStatCell(
                        value: "\(report.streakInfo.current)",
                        unit: "days",
                        label: "streak"
                    )
                }
            }
            .padding(.vertical, 16)

            Divider()

            // Streak row
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(report.streakInfo.current > 0 ? "🔥" : "❄️")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(report.streakInfo.current) day streak")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("current")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(UIColor.separator).opacity(0.5))
                    .frame(width: 0.5)
                    .padding(.vertical, 8)

                HStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(report.streakInfo.best) day streak")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("personal best")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Macros card

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Average Macros")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            HStack(spacing: 0) {
                macroRingCell(
                    label: "Protein",
                    current: Int(report.macroAverages.proteinG),
                    color: AppColors.accentBlue
                )
                reportDivider
                macroRingCell(
                    label: "Carbs",
                    current: Int(report.macroAverages.carbsG),
                    color: AppColors.accentGreen
                )
                reportDivider
                macroRingCell(
                    label: "Fat",
                    current: Int(report.macroAverages.fatG),
                    color: .orange
                )
            }
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func macroRingCell(label: String, current: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 7)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: barsAppeared ? 0.72 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: barsAppeared)
                Text("\(current)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text("\(current)g")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Nutrient gaps card

    private var nutrientGapsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            reportSectionHeader("Nutrient Gaps", icon: "exclamationmark.triangle.fill", iconColor: .orange)

            ForEach(Array(report.nutrientGaps.enumerated()), id: \.element.id) { i, gap in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(gap.nutrient)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(gap.averageIntake)) / \(Int(gap.recommendedIntake))\(gap.nutrient == "Calories" ? " cal" : "g")")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(UIColor.systemFill))
                                .frame(height: 6)
                            Capsule()
                                .fill(gapColor(for: gap.deficitPercent))
                                .frame(width: barsAppeared ? geo.size.width * min(1, gap.averageIntake / max(1, gap.recommendedIntake)) : 0, height: 6)
                                .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(Double(i) * 0.05), value: barsAppeared)
                        }
                    }
                    .frame(height: 6)

                    Text(gap.suggestion)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if i < report.nutrientGaps.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }

            Spacer().frame(height: 4)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func gapColor(for deficit: Double) -> Color {
        if deficit > 40 { return AppColors.accentRed }
        if deficit > 20 { return .orange }
        return AppColors.accentGreen
    }

    // MARK: - Top foods card

    private var topFoodsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            reportSectionHeader("Top Foods", icon: "fork.knife", iconColor: AppColors.accentGreen)

            ForEach(Array(report.topFoods.enumerated()), id: \.offset) { i, food in
                HStack(spacing: 12) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(i == 0 ? Color.yellow.opacity(0.15) : Color(UIColor.systemFill))
                            .frame(width: 32, height: 32)
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(i == 0 ? Color.yellow : .secondary)
                    }

                    Text(food.name)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Frequency pill
                    Text("\(food.count)×")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accentGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.accentGreen.opacity(0.10))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                if i < report.topFoods.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }

            Spacer().frame(height: 4)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tips card

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            reportSectionHeader("Tips for Next Week", icon: "lightbulb.fill", iconColor: .yellow)

            ForEach(Array(report.improvementTips.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }

                    Text(tip)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if i < report.improvementTips.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }

            Spacer().frame(height: 4)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Shared helpers

    private func reportSectionHeader(_ title: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func reportStatCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var reportDivider: some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.5))
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        DietView(viewModel: DietViewModel())
    }
}
