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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Theme-aware Background
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Calendar Strip
                        calendarStrip
                        
                        // Progress Section
                        progressSection
                        
                        // Macro Breakdown
                        macroBreakdownSection
                        
                        // Meal Sections
                        mealSectionsView
                        
                        // Insights Card
                        if let insights = viewModel.insights {
                            insightsCard(insights)
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
                            .foregroundColor(Color(hex: "2E3192"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "2E3192").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "2E3192").opacity(0.15), lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
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
                            .foregroundStyle(Color.green)
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
    
    // MARK: - Calendar Strip
    
    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index - 3, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                    
                    VStack(spacing: 8) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.green : Color.clear)
                            )
                    }
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(isToday && !isSelected ? Color(UIColor.secondarySystemBackground) : Color.clear)
                    .cornerRadius(12)
                    .onTapGesture {
                        withAnimation {
                            viewModel.selectedDate = date
                        }
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
                    color: .green,
                    value: "\(viewModel.totalCalories)",
                    label: "of \(viewModel.dietGoals.dailyCalories) cal"
                )

                dietStatPill(
                    icon: "arrow.up.circle.fill",
                    color: .orange,
                    value: "\(viewModel.remainingCalories)",
                    label: "remaining"
                )

                dietStatPill(
                    icon: "fork.knife",
                    color: .blue,
                    value: "\(viewModel.nutritionSummary.mealCount)",
                    label: "meals"
                )
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func dietStatPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
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
                    .foregroundColor(.green)
                Text("Insights")
                    .font(.headline)
            }
            
            HStack(spacing: 20) {
                insightItem(
                    value: "\(insights.currentStreak)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: .orange
                )
                
                insightItem(
                    value: "\(insights.weeklyAverageCalories)",
                    label: "Avg cal/day",
                    icon: "chart.bar.fill",
                    color: .green
                )
                
                if let best = insights.bestDay {
                    insightItem(
                        value: "\(best.calories)",
                        label: "Best Day",
                        icon: "trophy.fill",
                        color: .yellow
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
                                .foregroundColor(.green)
                            Text(food)
                                .font(.subheadline)
                        }
                    }
                }
            }
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Macro balance: \(insights.macroBalance)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    private func insightItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DietView(viewModel: DietViewModel())
}
