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

    // MARK: - Diet brand tokens (mirrors Android)
    private let dietAccent = AppColors.aiTeal
    private let dietAccentSoft = Color(hex: "E6FAF5")
    private let dietHeroSurface = Color(hex: "EEFBF7")
    private let dietOrange = Color(hex: "FF9500")
    private let nutritionProtein = Color(hex: "FF6B6B")
    private let nutritionCarbs = Color(hex: "4ECDC4")
    private let nutritionFat = Color(hex: "FFD93D")

    private var primaryMeals: [MealType] { [.breakfast, .lunch, .eveningSnack, .dinner] }

    var body: some View {
        NavigationStack {
        ZStack(alignment: .bottom) {
            Color.white
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero header (illustration + title + close + menu)
                    heroHeader

                    // Today's Progress card pulled up over the hero
                    todaysProgressCard
                        .padding(.horizontal, 16)
                        .offset(y: -40)
                        .padding(.bottom, -40)

                    Spacer().frame(height: 12)

                    // 4-up macro chip row
                    macroChipRow
                        .padding(.horizontal, 16)

                    Spacer().frame(height: 20)

                    // Today's Meals header
                    HStack {
                        Text("Today's Meals")
                            .font(.poppins(.semiBold, size: 17))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            selectedMealType = .breakfast
                            viewModel.showAddFood = true
                        } label: {
                            Text("View all")
                                .font(.poppins(.medium, size: 13))
                                .foregroundColor(dietAccent)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 10)

                    // Compact meal rows
                    VStack(spacing: 8) {
                        ForEach(primaryMeals, id: \.self) { meal in
                            CompactMealRow(
                                mealType: meal,
                                entries: viewModel.getMealLogs(for: meal),
                                accent: mealAccent(meal),
                                proteinColor: nutritionProtein,
                                carbsColor: nutritionCarbs,
                                fatColor: nutritionFat,
                                orangeAccent: dietOrange,
                                onTap: {
                                    selectedMealType = meal
                                    viewModel.showAddFood = true
                                },
                                onDelete: { entry in
                                    Task { await viewModel.deleteLog(entry) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    // Insights
                    if let insights = viewModel.insights {
                        Spacer().frame(height: 12)
                        insightsCard(insights)
                            .padding(.horizontal, 16)
                    }

                    // Ask AI
                    Spacer().frame(height: 12)
                    askAIButton
                        .padding(.horizontal, 16)

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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { viewModel.showSettings = true } label: {
                        Label("Goals & Settings", systemImage: "gearshape.fill")
                    }
                    if viewModel.insights != nil {
                        Button {
                            viewModel.generateWeeklyReport()
                            viewModel.showWeeklyReport = true
                        } label: {
                            Label("Weekly Report", systemImage: "chart.bar.doc.horizontal")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.75))
                }
            }
        }
        .onAppear {
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
        .trackScreen("Diet")
        } // NavigationStack
    }

    private func mealAccent(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return Color(hex: "FFB020")
        case .morningSnack: return Color(hex: "8B6914")
        case .lunch: return Color(hex: "FFA000")
        case .eveningSnack: return dietAccent
        case .dinner: return Color(hex: "6C7BFF")
        case .lateNight: return Color(hex: "9B59B6")
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .top) {
            // Illustration banner
            Image.androidImage("diet screen hero illustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white, location: 0.12),
                            .init(color: .clear, location: 0.35),
                            .init(color: .clear, location: 0.75),
                            .init(color: .white, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Title + subtitle (left-aligned, overlay)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diet")
                        .font(.poppins(.bold, size: 28))
                        .foregroundStyle(.primary)
                    Text("Eat healthy, stay happy :)")
                        .font(.poppins(.regular, size: 13))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.top, -8)
        }
    }

    // MARK: - Today's Progress Card

    private var todaysProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress")
                .font(.poppins(.semiBold, size: 16))
                .foregroundStyle(.primary)

            HStack(alignment: .center, spacing: 16) {
                CalorieDonut(
                    current: Int(viewModel.nutritionSummary.totalCalories),
                    goal: viewModel.dietGoals.dailyCalories,
                    progress: viewModel.calorieProgress,
                    accent: dietAccent
                )
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 10) {
                    ProgressLine(
                        color: dietAccent,
                        label: "Calories",
                        value: "\(Int(viewModel.nutritionSummary.totalCalories)) / \(viewModel.dietGoals.dailyCalories)",
                        progress: viewModel.calorieProgress
                    )
                    ProgressLine(
                        color: nutritionProtein,
                        label: "Protein",
                        value: "\(Int(viewModel.nutritionSummary.totalProteinG)) / \(viewModel.dietGoals.proteinGrams)",
                        progress: viewModel.proteinProgress
                    )
                    ProgressLine(
                        color: nutritionCarbs,
                        label: "Carbs",
                        value: "\(Int(viewModel.nutritionSummary.totalCarbsG)) / \(viewModel.dietGoals.carbsGrams)",
                        progress: viewModel.carbsProgress
                    )
                    ProgressLine(
                        color: nutritionFat,
                        label: "Fats",
                        value: "\(Int(viewModel.nutritionSummary.totalFatG)) / \(viewModel.dietGoals.fatGrams)",
                        progress: viewModel.fatProgress
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "0F172A").opacity(0.10), radius: 18, x: 0, y: 6)
    }

    // MARK: - Macro Chip Row

    private var macroChipRow: some View {
        HStack(spacing: 10) {
            macroChip(
                label: "Protein",
                value: "\(Int(viewModel.nutritionSummary.totalProteinG))g",
                target: "Target \(viewModel.dietGoals.proteinGrams)g",
                color: nutritionProtein
            )
            macroChip(
                label: "Carbs",
                value: "\(Int(viewModel.nutritionSummary.totalCarbsG))g",
                target: "Target \(viewModel.dietGoals.carbsGrams)g",
                color: nutritionCarbs
            )
            macroChip(
                label: "Fats",
                value: "\(Int(viewModel.nutritionSummary.totalFatG))g",
                target: "Target \(viewModel.dietGoals.fatGrams)g",
                color: nutritionFat
            )
            macroChip(
                label: "Fiber",
                value: "\(Int(viewModel.nutritionSummary.totalFiberG))g",
                target: "Target 30g",
                color: dietAccent
            )
        }
    }

    private func macroChip(label: String, value: String, target: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.poppins(.medium, size: 11))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.poppins(.bold, size: 17))
                .foregroundStyle(.primary)
            Text(target)
                .font(.poppins(.regular, size: 10))
                .foregroundStyle(.primary.opacity(0.45))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color(hex: "0F172A").opacity(0.08), radius: 14, x: 0, y: 4)
    }

    // MARK: - Insights Card

    private func insightsCard(_ insights: DietInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(dietAccent)
                Text("Insights")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundStyle(.primary)
            }

            HStack {
                insightItem(
                    value: "\(insights.currentStreak)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: dietOrange
                )
                Spacer()
                insightItem(
                    value: "\(insights.weeklyAverageCalories)",
                    label: "Avg cal/day",
                    icon: "chart.bar.fill",
                    color: dietAccent
                )
                Spacer()
            }
            .padding(.horizontal, 8)

            if !insights.topFoods.isEmpty {
                Divider().background(Color.primary.opacity(0.08))
                Text("Top Foods")
                    .font(.poppins(.medium, size: 13))
                    .foregroundStyle(.primary.opacity(0.5))
                ForEach(insights.topFoods, id: \.self) { food in
                    HStack(spacing: 8) {
                        Circle().fill(dietAccent).frame(width: 6, height: 6)
                        Text(food)
                            .font(.poppins(.regular, size: 14))
                            .foregroundStyle(.primary)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(dietAccent)
                Text("Macro balance: \(insights.macroBalance)")
                    .font(.poppins(.regular, size: 13))
                    .foregroundStyle(.primary.opacity(0.6))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(hex: "0F172A").opacity(0.10), radius: 16, x: 0, y: 5)
    }

    private func insightItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.poppins(.semiBold, size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.poppins(.bold, size: 18))
                .foregroundStyle(.primary)
            Text(label)
                .font(.poppins(.regular, size: 12))
                .foregroundStyle(.primary.opacity(0.5))
        }
    }

    // MARK: - Ask AI button

    private var askAIButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NotificationCenter.default.post(name: .init("NavigateToAI"), object: nil)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.poppins(.semiBold, size: 14))
                Text("Ask AI about my diet")
                    .font(.poppins(.semiBold, size: 14))
            }
            .foregroundColor(dietAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(dietAccent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
                        .font(.poppins(.semiBold, size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(dietAccent)
                        .clipShape(Circle())
                        .shadow(color: dietAccent.opacity(0.35), radius: 10, x: 0, y: 5)
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
                .font(.poppins(.regular, size: 13))
                .foregroundStyle(.secondary)
            Text("Meal deleted")
                .font(.poppins(.medium, size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.undoDelete()
            } label: {
                Text("Undo")
                    .font(.poppins(.semiBold, size: 15))
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
                        .font(.poppins(.medium, size: 13))
                        .foregroundStyle(.secondary)

                    TextField("My usual \(templateMealType.displayName.lowercased())", text: $templateName)
                        .font(.poppins(.regular, size: 17))
                        .padding(14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                let entries = viewModel.getMealLogs(for: templateMealType)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items (\(entries.count))")
                        .font(.poppins(.medium, size: 13))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                            HStack {
                                Text(entry.foodName)
                                    .font(.poppins(.regular, size: 15))
                                Spacer()
                                Text("\(Int(entry.calories)) cal")
                                    .font(.poppins(.medium, size: 14))
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
                        .font(.poppins(.semiBold, size: 17))
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

// MARK: - Calorie Donut (Android-style ring with center label + % badge)

private struct CalorieDonut: View {
    let current: Int
    let goal: Int
    let progress: Double
    let accent: Color

    @State private var animated: Double = 0

    private var percent: Int {
        guard goal > 0 else { return 0 }
        return Int((Double(current) / Double(goal)) * 100)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.12), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            Circle()
                .trim(from: 0, to: CGFloat(animated))
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.poppins(.bold, size: 24))
                    .foregroundStyle(.primary)
                Text("/ \(goal) kcal")
                    .font(.poppins(.regular, size: 11))
                    .foregroundStyle(.primary.opacity(0.5))
                Spacer().frame(height: 4)
                Text("\(percent)%")
                    .font(.poppins(.semiBold, size: 11))
                    .foregroundColor(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                animated = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                animated = newValue
            }
        }
    }
}

// MARK: - Macro Progress Line

private struct ProgressLine: View {
    let color: Color
    let label: String
    let value: String
    let progress: Double

    @State private var animated: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(label)
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                Spacer()
                Text(value)
                    .font(.poppins(.medium, size: 12))
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(animated))
                }
            }
            .frame(height: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animated = progress }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) { animated = newValue }
        }
    }
}

// MARK: - Compact Meal Row (Android-style)

private struct CompactMealRow: View {
    let mealType: MealType
    let entries: [DietLogEntry]
    let accent: Color
    let proteinColor: Color
    let carbsColor: Color
    let fatColor: Color
    let orangeAccent: Color
    let onTap: () -> Void
    let onDelete: (DietLogEntry) -> Void

    private var totalCal: Int { entries.reduce(0) { $0 + Int($1.calories) } }
    private var totalProtein: Int { entries.reduce(0) { $0 + Int($1.proteinG) } }
    private var totalCarbs: Int { entries.reduce(0) { $0 + Int($1.carbsG) } }
    private var totalFat: Int { entries.reduce(0) { $0 + Int($1.fatG) } }
    private var hasEntries: Bool { !entries.isEmpty }

    private var iconName: String {
        switch mealType {
        case .breakfast: return "sun.max.fill"
        case .morningSnack: return "cup.and.saucer.fill"
        case .lunch: return "sun.and.horizon.fill"
        case .eveningSnack: return "leaf.fill"
        case .dinner: return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        }
    }

    private var shortTime: String {
        switch mealType {
        case .breakfast: return "8:30 AM"
        case .morningSnack: return "10:30 AM"
        case .lunch: return "1:00 PM"
        case .eveningSnack: return "4:30 PM"
        case .dinner: return "7:30 PM"
        case .lateNight: return "10:30 PM"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // Leading icon
                ZStack {
                    Circle().fill(accent.opacity(0.14))
                    Image(systemName: iconName)
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(accent)
                }
                .frame(width: 40, height: 40)

                // Title + secondary line + macro letters
                VStack(alignment: .leading, spacing: 2) {
                    Text(mealType.displayName)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(.primary)
                    Text(hasEntries ? (entries.first?.foodName ?? "") : shortTime)
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(.primary.opacity(0.5))
                        .lineLimit(1)
                    if hasEntries {
                        HStack(spacing: 8) {
                            macroLetter("P", "\(totalProtein)g", color: proteinColor)
                            macroLetter("C", "\(totalCarbs)g", color: carbsColor)
                            macroLetter("F", "\(totalFat)g", color: fatColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Trailing: total kcal or add button
                VStack(alignment: .trailing, spacing: 4) {
                    if hasEntries {
                        Text("\(totalCal) kcal")
                            .font(.poppins(.bold, size: 14))
                            .foregroundColor(orangeAccent)
                        if entries.count > 1 {
                            Text("\(entries.count) items")
                                .font(.poppins(.regular, size: 10))
                                .foregroundStyle(.primary.opacity(0.4))
                        } else if let first = entries.first {
                            Button {
                                onDelete(first)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.poppins(.regular, size: 14))
                                    .foregroundColor(Color(hex: "FF3B30").opacity(0.55))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ZStack {
                            Circle().fill(accent.opacity(0.14))
                            Image(systemName: "plus")
                                .font(.poppins(.semiBold, size: 12))
                                .foregroundColor(accent)
                        }
                        .frame(width: 28, height: 28)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(hex: "0F172A").opacity(0.10), radius: 16, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func macroLetter(_ letter: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Text("\(letter) ")
                .font(.poppins(.bold, size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.poppins(.regular, size: 11))
                .foregroundStyle(.primary.opacity(0.55))
        }
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
                            .font(.poppins(.semiBold, size: 17))
                            .foregroundStyle(mealType.color)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(mealType.displayName)
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundStyle(.primary)
                        Text(mealType.typicalTime)
                            .font(.poppins(.regular, size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !entries.isEmpty {
                        Text("\(totalCalories)")
                            .font(.poppins(.semiBold, size: 15))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text("cal")
                            .font(.poppins(.regular, size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.poppins(.semiBold, size: 11))
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
                                    .font(.poppins(.regular, size: 15))
                                    .foregroundStyle(mealType.color)
                                Text("Add \(mealType.displayName.lowercased())")
                                    .font(.poppins(.regular, size: 15))
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
                                    .font(.poppins(.regular, size: 14))
                                    .foregroundStyle(mealType.color)
                                Text("Add more")
                                    .font(.poppins(.regular, size: 14))
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
                    .font(.poppins(.regular, size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName)
                    .font(.poppins(.medium, size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(entry.displayQuantity)
                    .font(.poppins(.regular, size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories))")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundStyle(.primary)
                Text("cal")
                    .font(.poppins(.regular, size: 11))
                    .foregroundStyle(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.poppins(.regular, size: 20))
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
                        .font(.poppins(.semiBold, size: 17))
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
                .font(.poppins(.medium, size: 13))
                .foregroundStyle(.secondary)
            Text("\(report.totalMealsLogged) meals logged this week")
                .font(.poppins(.regular, size: 12))
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
                    .font(.poppins(.bold, size: 52))
                    .foregroundStyle(adherenceColor)
                Text("goal adherence")
                    .font(.poppins(.regular, size: 13))
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
                        .font(.poppins(.regular, size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(report.streakInfo.current) day streak")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundStyle(.primary)
                        Text("current")
                            .font(.poppins(.regular, size: 12))
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
                        .font(.poppins(.regular, size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(report.streakInfo.best) day streak")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundStyle(.primary)
                        Text("personal best")
                            .font(.poppins(.regular, size: 12))
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
                .font(.poppins(.semiBold, size: 15))
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
                    .font(.poppins(.bold, size: 14))
                    .foregroundStyle(.primary)
            }
            Text("\(current)g")
                .font(.poppins(.semiBold, size: 13))
                .foregroundStyle(.primary)
            Text(label)
                .font(.poppins(.regular, size: 12))
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
                            .font(.poppins(.medium, size: 15))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(gap.averageIntake)) / \(Int(gap.recommendedIntake))\(gap.nutrient == "Calories" ? " cal" : "g")")
                            .font(.poppins(.regular, size: 13))
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
                        .font(.poppins(.regular, size: 13))
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
                            .font(.poppins(.bold, size: 13))
                            .foregroundStyle(i == 0 ? Color.yellow : .secondary)
                    }

                    Text(food.name)
                        .font(.poppins(.regular, size: 15))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Frequency pill
                    Text("\(food.count)×")
                        .font(.poppins(.semiBold, size: 13))
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
                            .font(.poppins(.bold, size: 12))
                            .foregroundStyle(Color.orange)
                    }

                    Text(tip)
                        .font(.poppins(.regular, size: 14))
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
                .font(.poppins(.semiBold, size: 13))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.poppins(.semiBold, size: 13))
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
                    .font(.poppins(.bold, size: 22))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.poppins(.regular, size: 12))
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
