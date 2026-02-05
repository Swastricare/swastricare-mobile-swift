//
//  FoodTrackingView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Premium food and nutrition tracking interface
//

import SwiftUI

// MARK: - Food Tracking View

struct FoodTrackingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = DependencyContainer.shared.foodTrackingViewModel

    @State private var selectedDateIndex = 6 // Today
    @State private var animateProgress = false

    private let accentColor = Color(hex: "FF6B35") // Warm orange for food

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Strip
                    dateStrip

                    // Calorie Ring & Macros
                    calorieOverview

                    // Macro Breakdown Bars
                    macroBreakdown

                    // Quick Add Section
                    quickAddSection

                    // Meal Sections
                    mealSections

                    Spacer(minLength: 100)
                }
                .padding(.bottom, 20)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.prepareAddEntry()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [accentColor, Color(hex: "FF8F00")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: accentColor.opacity(0.4), radius: 12, y: 6)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Food Tracker")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { viewModel.showGoalSheet = true }) {
                        Label("Set Goals", systemImage: "target")
                    }
                    Button(action: { viewModel.goToToday() }) {
                        Label("Go to Today", systemImage: "calendar")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddEntrySheet) {
            AddFoodEntrySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showGoalSheet) {
            GoalSettingsSheet(viewModel: viewModel)
        }
        .alert("Food Tracker", isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .task {
            await viewModel.loadData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateProgress = true
            }
        }
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset - 6, to: Date())!
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectDate(date)
                                selectedDateIndex = offset
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(dayOfWeek(date))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isSelected ? .white : .secondary)
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(width: 44, height: 62)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? accentColor : Color(UIColor.tertiarySystemBackground))
                            )
                        }
                        .id(offset)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                proxy.scrollTo(6, anchor: .trailing)
            }
        }
    }

    // MARK: - Calorie Overview

    private var calorieOverview: some View {
        VStack(spacing: 16) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: animateProgress ? viewModel.calorieProgress : 0)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor, Color(hex: "FF8F00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(viewModel.totalCalories)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("of \(viewModel.dailyGoal.calorieTarget)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("kcal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor)
                }
            }

            // Stats Row
            HStack(spacing: 0) {
                statBadge(label: "Eaten", value: "\(viewModel.totalCalories)", color: accentColor)
                Divider().frame(height: 30)
                statBadge(label: "Remaining", value: "\(viewModel.caloriesRemaining)", color: .green)
                Divider().frame(height: 30)
                statBadge(label: "Meals", value: "\(viewModel.entries.count)", color: .blue)
            }
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Macro Breakdown

    private var macroBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macros")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                macroBar(
                    name: "Protein",
                    current: viewModel.summary.totalProtein,
                    target: Double(viewModel.dailyGoal.proteinTargetGrams),
                    unit: "g",
                    color: Color(hex: "E53935"),
                    progress: viewModel.summary.proteinProgress
                )
                macroBar(
                    name: "Carbs",
                    current: viewModel.summary.totalCarbs,
                    target: Double(viewModel.dailyGoal.carbsTargetGrams),
                    unit: "g",
                    color: Color(hex: "FF9800"),
                    progress: viewModel.summary.carbsProgress
                )
                macroBar(
                    name: "Fat",
                    current: viewModel.summary.totalFat,
                    target: Double(viewModel.dailyGoal.fatTargetGrams),
                    unit: "g",
                    color: Color(hex: "FFC107"),
                    progress: viewModel.summary.fatProgress
                )
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Quick Add

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(QuickAddFoodPreset.defaults) { preset in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            Task { await viewModel.quickAdd(preset: preset) }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(accentColor)
                                    .frame(width: 42, height: 42)
                                    .background(accentColor.opacity(0.12))
                                    .clipShape(Circle())

                                Text(preset.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text("\(Int(preset.nutrition.calories)) cal")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 80)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Meal Sections

    private var mealSections: some View {
        VStack(spacing: 16) {
            ForEach(MealType.allCases) { meal in
                let mealEntries = viewModel.summary.entriesByMeal[meal] ?? []
                let mealCalories = viewModel.summary.calories(for: meal)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: meal.icon)
                            .foregroundColor(meal.color)
                            .font(.system(size: 16))
                        Text(meal.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        if mealCalories > 0 {
                            Text("\(Int(mealCalories)) cal")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Button(action: {
                            viewModel.formMealType = meal
                            viewModel.prepareAddEntry()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(accentColor.opacity(0.7))
                                .font(.system(size: 20))
                        }
                    }

                    if mealEntries.isEmpty {
                        Text("No entries yet")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(mealEntries) { entry in
                            FoodEntryRow(entry: entry, accentColor: accentColor) {
                                Task { await viewModel.deleteEntry(entry) }
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Components

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroBar(name: String, current: Double, target: Double, unit: String, color: Color, progress: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(current))/\(Int(target))\(unit)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * (animateProgress ? min(progress, 1.0) : 0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Food Entry Row

private struct FoodEntryRow: View {
    let entry: FoodEntry
    let accentColor: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.icon)
                .font(.system(size: 14))
                .foregroundColor(accentColor)
                .frame(width: 32, height: 32)
                .background(accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium))
                Text(entry.servingDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.totalNutrition.calories)) cal")
                    .font(.system(size: 13, weight: .semibold))
                Text(entry.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Add Food Entry Sheet

private struct AddFoodEntrySheet: View {
    @ObservedObject var viewModel: FoodTrackingViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Food Details") {
                    TextField("Food name", text: $viewModel.formName)

                    Picker("Meal", selection: $viewModel.formMealType) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.displayName, systemImage: meal.icon).tag(meal)
                        }
                    }

                    Picker("Category", selection: $viewModel.formCategory) {
                        ForEach(FoodCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Nutrition (per serving)") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $viewModel.formCalories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kcal")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $viewModel.formProtein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $viewModel.formCarbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $viewModel.formFat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Servings") {
                    HStack {
                        Text("Number of servings")
                        Spacer()
                        TextField("1", text: $viewModel.formServings)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Notes (optional)") {
                    TextField("Add a note...", text: $viewModel.formNotes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.addEntry() }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.formName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Goal Settings Sheet

private struct GoalSettingsSheet: View {
    @ObservedObject var viewModel: FoodTrackingViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Daily Calorie Target") {
                    Stepper(
                        "\(viewModel.dailyGoal.calorieTarget) kcal",
                        value: $viewModel.dailyGoal.calorieTarget,
                        in: 1000...5000,
                        step: 50
                    )
                }

                Section("Macro Targets") {
                    Stepper(
                        "Protein: \(viewModel.dailyGoal.proteinTargetGrams)g",
                        value: $viewModel.dailyGoal.proteinTargetGrams,
                        in: 10...300,
                        step: 5
                    )
                    Stepper(
                        "Carbs: \(viewModel.dailyGoal.carbsTargetGrams)g",
                        value: $viewModel.dailyGoal.carbsTargetGrams,
                        in: 50...500,
                        step: 10
                    )
                    Stepper(
                        "Fat: \(viewModel.dailyGoal.fatTargetGrams)g",
                        value: $viewModel.dailyGoal.fatTargetGrams,
                        in: 10...200,
                        step: 5
                    )
                }
            }
            .navigationTitle("Nutrition Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.saveGoal() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FoodTrackingView()
    }
}
