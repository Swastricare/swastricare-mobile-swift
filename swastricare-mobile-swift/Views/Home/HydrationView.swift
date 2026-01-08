//
//  HydrationView.swift
//  swastricare-mobile-swift
//
//  Smart Hydration Tracking with personalized goals
//

import SwiftUI

struct HydrationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = HydrationViewModel()
    
    @State private var selectedDrinkType: DrinkType = .water
    @State private var showDrinkTypePicker = false
    @State private var customAmount: String = ""
    @State private var showCustomAmountField = false
    
    // MARK: - Computed Properties
    
    private var hasMissingData: Bool {
        missingDataItems.count > 0
    }
    
    private var missingDataItems: [MissingDataItem] {
        var items: [MissingDataItem] = []
        
        // Check for weight
        if viewModel.preferences.weightKg == nil {
            items.append(MissingDataItem(
                icon: "scalemass.fill",
                title: "Weight",
                description: "Add your weight for accurate goal calculation",
                action: "Set Weight"
            ))
        }
        
        // Check for activity level (if still default and never set)
        if viewModel.preferences.activityLevel == .moderate && viewModel.preferences.updatedAt == nil {
            items.append(MissingDataItem(
                icon: "figure.walk",
                title: "Activity Level",
                description: "Tell us about your daily activity",
                action: "Set Activity"
            ))
        }
        
        // Check if HealthKit authorization might help
        if viewModel.preferences.useHealthKitWeight && viewModel.preferences.weightKg == nil {
            items.append(MissingDataItem(
                icon: "heart.text.square.fill",
                title: "HealthKit Access",
                description: "Enable HealthKit to auto-sync your weight",
                action: "Enable"
            ))
        }
        
        return items
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Theme-aware Background
                // PremiumBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Missing Data Tooltip
                        if hasMissingData {
                            missingDataTooltip
                        }
                        
                        // Calendar Strip
                        calendarStrip
                        
                        // Progress Section
                        progressSection
                        
                        // Quick Add Section
                        quickAddSection
                        
                        // Insights Card
                        if let insights = viewModel.insights {
                            insightsCard(insights)
                        }
                        
                        // Weather Alert
                        if let temp = viewModel.currentTemperature, temp > 30 {
                            weatherAlert(temp)
                        }
                        
                        // Caffeine Warning
                        if let warning = viewModel.insights?.caffeineWarning {
                            caffeineWarning(warning)
                        }
                        
                        // Today's Entries
                        entriesSection
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showSettings = true }) {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        
                        Button(action: { viewModel.showUrineColorGuide = true }) {
                            Label("Hydration Check", systemImage: "drop.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.cyan)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .task {
                await viewModel.onAppear()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $viewModel.showSettings) {
                HydrationSettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showUrineColorGuide) {
                UrineColorGuideView(viewModel: viewModel)
            }
            .sheet(isPresented: $showDrinkTypePicker) {
                drinkTypePickerSheet
            }
        }
    }
    
    // MARK: - Missing Data Tooltip
    
    private var missingDataTooltip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Complete Your Profile")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { viewModel.showSettings = true }) {
                    Text("Settings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(missingDataItems.prefix(3)), id: \.title) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundColor(.orange.opacity(0.8))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(item.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if missingDataItems.count > 0 {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.yellow.opacity(0.8))
                    
                    Text("Complete your profile for personalized hydration goals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .onTapGesture {
            viewModel.showSettings = true
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
                                    .fill(isSelected ? Color(hex: "2E3192") : Color.clear)
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
            
            HStack(alignment: .center, spacing: 24) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            Color(hex: "2E3192"),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: viewModel.progress)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if viewModel.isGoalMet {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    statRow(
                        icon: "drop.fill",
                        color: .cyan,
                        value: "\(viewModel.totalIntake)",
                        label: "of \(viewModel.dailyGoal) ml"
                    )
                    
                    statRow(
                        icon: "arrow.up.circle.fill",
                        color: .green,
                        value: "\(viewModel.remainingMl)",
                        label: "remaining"
                    )
                    
                    statRow(
                        icon: "cup.and.saucer.fill",
                        color: .brown,
                        value: "\(viewModel.caffeineInfo.count)",
                        label: "caffeine drinks"
                    )
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    private func statRow(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Quick Add Section
    
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Add")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Drink type selector
                Button(action: { showDrinkTypePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: selectedDrinkType.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedDrinkType.color)
                        Text(selectedDrinkType.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                }
            }
            
            // Preset buttons
            HStack(spacing: 12) {
                ForEach(QuickAddPreset.defaults) { preset in
                    quickAddButton(preset)
                }
            }
            
            // Custom amount
            if showCustomAmountField {
                HStack {
                    TextField("Amount", text: $customAmount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    
                    Text("ml")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add") {
                        if let amount = Int(customAmount), amount > 0 {
                            Task {
                                await viewModel.addWaterIntake(
                                    amount: amount,
                                    drinkType: selectedDrinkType
                                )
                            }
                            customAmount = ""
                            showCustomAmountField = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "2E3192"))
                    
                    Button(action: { showCustomAmountField = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Button(action: { showCustomAmountField = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Custom Amount")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "2E3192"))
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    private func quickAddButton(_ preset: QuickAddPreset) -> some View {
        Button(action: {
            Task {
                await viewModel.addWaterIntake(
                    amount: preset.amountMl,
                    drinkType: selectedDrinkType
                )
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(selectedDrinkType.color)
                
                Text(preset.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedDrinkType.color.opacity(0.15))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Insights Card
    
    private func insightsCard(_ insights: HydrationInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
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
                    value: "\(insights.averageDailyIntake)",
                    label: "Avg ml/day",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
                
                if let best = insights.bestDayThisWeek {
                    insightItem(
                        value: "\(best.amount)",
                        label: "Best Day",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                }
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
    
    // MARK: - Weather Alert
    
    private func weatherAlert(_ temp: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Hot Weather Alert")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("It's \(Int(temp))°C today - your goal increased by 20%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Caffeine Warning
    
    private func caffeineWarning(_ warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.title2)
                .foregroundColor(.brown)
            
            Text(warning)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(16)
        .background(Color.brown.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Entries Section
    
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Log")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            if viewModel.todaysEntries.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.todaysEntries) { entry in
                    HydrationEntryCard(entry: entry) {
                        Task {
                            await viewModel.deleteEntry(entry)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No entries yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the quick add buttons above to log your water intake")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Drink Type Picker Sheet
    
    private var drinkTypePickerSheet: some View {
        NavigationView {
            List {
                ForEach(DrinkType.allCases) { type in
                    Button(action: {
                        selectedDrinkType = type
                        showDrinkTypePicker = false
                    }) {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                if type.containsCaffeine {
                                    Text("Contains caffeine")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedDrinkType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showDrinkTypePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Missing Data Item Model

struct MissingDataItem {
    let icon: String
    let title: String
    let description: String
    let action: String
}

// MARK: - Hydration Entry Card

struct HydrationEntryCard: View {
    let entry: HydrationEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(entry.drinkType.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: entry.drinkType.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(entry.drinkType.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(entry.amountMl) ml")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if entry.drinkType != .water {
                        Text("(\(entry.effectiveHydration) ml effective)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(entry.drinkType.displayName) • \(entry.formattedTime)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    HydrationView()
}
