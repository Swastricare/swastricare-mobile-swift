//
//  HydrationView.swift
//  swastricare-mobile-swift
//
//  Smart Hydration Tracking with Movements+ Design
//

import SwiftUI

struct HydrationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: HydrationViewModel
    
    @State private var selectedDrinkType: DrinkType = .water
    @State private var showDrinkTypePicker = false
    @State private var customAmount: String = ""
    @State private var showCustomAmountField = false
    @State private var hasAppeared = false
    @State private var waveOffset: Double = 0
    
    // MARK: - Theme Colors
    
    private var hydrationBlue: Color { Color(hex: "5AC8FA") }
    private var hydrationTeal: Color { Color(hex: "4ECDC4") }
    
    // MARK: - Computed Properties
    
    private var hasMissingData: Bool {
        missingDataItems.count > 0
    }
    
    private var missingDataItems: [MissingDataItem] {
        var items: [MissingDataItem] = []
        
        if viewModel.preferences.weightKg == nil {
            items.append(MissingDataItem(
                icon: "scalemass.fill",
                title: "Weight",
                description: "Add your weight for accurate goal calculation",
                action: "Set Weight"
            ))
        }
        
        if viewModel.preferences.activityLevel == .moderate && viewModel.preferences.updatedAt == nil {
            items.append(MissingDataItem(
                icon: "figure.walk",
                title: "Activity Level",
                description: "Tell us about your daily activity",
                action: "Set Activity"
            ))
        }
        
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
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if hasMissingData {
                            missingDataTooltip
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                        }
                        
                        calendarStrip
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
                        
                        heroProgressSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
                        
                        quickAddSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
                        
                        statsCardsSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
                        
                        if let insights = viewModel.insights {
                            insightsCard(insights)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
                        }
                        
                        if let temp = viewModel.currentTemperature, temp > 30 {
                            weatherAlert(temp)
                        }
                        
                        if let warning = viewModel.insights?.caffeineWarning {
                            caffeineWarning(warning)
                        }
                        
                        entriesSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: hasAppeared)
                        
                        aiAssistantButton
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: hasAppeared)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Hydration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showSettings = true }) {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        
                        Button(action: { viewModel.showUrineColorGuide = true }) {
                            Label("Hydration Check", systemImage: "drop.fill")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(hydrationBlue.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(hydrationBlue)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .onAppear {
                AppAnalyticsService.shared.logScreen("hydration")
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    hasAppeared = true
                }
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    waveOffset = .pi * 2
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
        Button(action: { viewModel.showSettings = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete Your Profile")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("For personalized hydration goals")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    ForEach(Array(missingDataItems.prefix(3)), id: \.title) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
    }
    
    // MARK: - Calendar Strip
    
    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    let date = Calendar.current.date(byAdding: .day, value: index - 3, to: Date()) ?? Date()
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedDate = date
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSelected ? .white : .secondary)
                            
                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .frame(width: 48, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSelected ? hydrationBlue : (isToday ? hydrationBlue.opacity(0.1) : Color.clear))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Hero Progress Section
    
    private var heroProgressSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [hydrationBlue, hydrationTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            HydrationWaveShape(progress: viewModel.progress, waveOffset: waveOffset)
                .fill(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 28))
            
            HydrationWaveShape(progress: viewModel.progress, waveOffset: waveOffset + 1.5)
                .fill(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 28))
            
            VStack(spacing: 16) {
                Text(viewModel.goalDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(alignment: .center, spacing: 32) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 10)
                            .frame(width: 130, height: 130)
                        
                        Circle()
                            .trim(from: 0, to: viewModel.progress)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.progress)
                        
                        VStack(spacing: 4) {
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            if viewModel.isGoalMet {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HydrationStatRow(
                            icon: "drop.fill",
                            value: "\(viewModel.totalIntake)",
                            label: "of \(viewModel.dailyGoal) ml"
                        )
                        
                        HydrationStatRow(
                            icon: "arrow.up.circle.fill",
                            value: "\(viewModel.remainingMl)",
                            label: "remaining"
                        )
                        
                        HydrationStatRow(
                            icon: "cup.and.saucer.fill",
                            value: "\(viewModel.caffeineInfo.count)",
                            label: "caffeine"
                        )
                    }
                }
            }
            .padding(24)
        }
        .frame(height: 220)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Quick Add Section
    
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Add")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showDrinkTypePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: selectedDrinkType.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedDrinkType.color)
                        
                        Text(selectedDrinkType.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(MovementsColors.card(for: colorScheme))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            HStack(spacing: 12) {
                ForEach(QuickAddPreset.defaults) { preset in
                    QuickAddButton(
                        preset: preset,
                        drinkType: selectedDrinkType,
                        colorScheme: colorScheme
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        AppAnalyticsService.shared.logHydrationButtonTap(amountMl: preset.amountMl, button: preset.label)
                        Task {
                            await viewModel.addWaterIntake(
                                amount: preset.amountMl,
                                drinkType: selectedDrinkType
                            )
                        }
                    }
                }
            }
            
            if showCustomAmountField {
                HStack(spacing: 12) {
                    HStack {
                        TextField("Amount", text: $customAmount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("ml")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(MovementsColors.card(for: colorScheme))
                    )
                    
                    Button(action: {
                        if let amount = Int(customAmount), amount > 0 {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            AppAnalyticsService.shared.logHydrationButtonTap(amountMl: amount, button: "custom")
                            Task {
                                await viewModel.addWaterIntake(
                                    amount: amount,
                                    drinkType: selectedDrinkType
                                )
                            }
                            customAmount = ""
                            showCustomAmountField = false
                        }
                    }) {
                        Text("Add")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(hydrationBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: { showCustomAmountField = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Button(action: { showCustomAmountField = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        
                        Text("Custom Amount")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(hydrationBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(hydrationBlue.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Stats Cards Section
    
    private var statsCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                HydrationMiniStatCard(
                    title: "Today",
                    value: "\(viewModel.totalIntake)",
                    unit: "ml",
                    icon: "drop.fill",
                    color: hydrationBlue,
                    colorScheme: colorScheme
                )
                
                HydrationMiniStatCard(
                    title: "Goal",
                    value: "\(viewModel.dailyGoal)",
                    unit: "ml",
                    icon: "target",
                    color: hydrationTeal,
                    colorScheme: colorScheme
                )
                
                HydrationMiniStatCard(
                    title: "Remaining",
                    value: "\(viewModel.remainingMl)",
                    unit: "ml",
                    icon: "arrow.up.circle.fill",
                    color: MovementsColors.limeGreen,
                    colorScheme: colorScheme
                )
                
                HydrationMiniStatCard(
                    title: "Caffeine",
                    value: "\(viewModel.caffeineInfo.count)",
                    unit: "drinks",
                    icon: "cup.and.saucer.fill",
                    color: Color.brown,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Insights Card
    
    private func insightsCard(_ insights: HydrationInsights) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(hydrationBlue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(hydrationBlue)
                }
                
                Text("Insights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                InsightStatView(
                    value: "\(insights.currentStreak)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: .orange,
                    colorScheme: colorScheme
                )
                
                InsightStatView(
                    value: "\(insights.averageDailyIntake)",
                    label: "Avg ml/day",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    colorScheme: colorScheme
                )
                
                if let best = insights.bestDayThisWeek {
                    InsightStatView(
                        value: "\(best.amount)",
                        label: "Best Day",
                        icon: "trophy.fill",
                        color: .yellow,
                        colorScheme: colorScheme
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Weather Alert
    
    private func weatherAlert(_ temp: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hot Weather Alert")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("It's \(Int(temp))°C today - your goal increased by 20%")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Caffeine Warning
    
    private func caffeineWarning(_ warning: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brown.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.brown)
            }
            
            Text(warning)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Entries Section
    
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Log")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.todaysEntries.count) entries")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            if viewModel.todaysEntries.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.todaysEntries) { entry in
                        HydrationEntryCardNew(entry: entry, colorScheme: colorScheme) {
                            Task {
                                await viewModel.deleteEntry(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(hydrationBlue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "drop")
                    .font(.system(size: 36))
                    .foregroundColor(hydrationBlue)
            }
            
            VStack(spacing: 6) {
                Text("No entries yet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Tap the quick add buttons to log your water intake")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - AI Assistant Button
    
    private var aiAssistantButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToAITab"), object: nil)
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    MovementsColors.limeGreen,
                                    hydrationTeal,
                                    hydrationBlue,
                                    MovementsColors.limeGreen
                                ],
                                center: .center
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Ask AI about my hydration")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(hydrationBlue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [MovementsColors.limeGreen.opacity(0.5), hydrationBlue.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
    }
    
    // MARK: - Drink Type Picker Sheet
    
    private var drinkTypePickerSheet: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(DrinkType.allCases) { type in
                            Button(action: {
                                selectedDrinkType = type
                                showDrinkTypePicker = false
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(type.color.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: type.icon)
                                            .font(.system(size: 18))
                                            .foregroundColor(type.color)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(type.displayName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        if type.containsCaffeine {
                                            Text("Contains caffeine")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedDrinkType == type {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(hydrationBlue)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(MovementsColors.card(for: colorScheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedDrinkType == type ? hydrationBlue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Select Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showDrinkTypePicker = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hydrationBlue)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Supporting Views

struct HydrationStatRow: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct QuickAddButton: View {
    let preset: QuickAddPreset
    let drinkType: DrinkType
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(drinkType.color)
                
                Text(preset.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(drinkType.color.opacity(0.12))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct HydrationMiniStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 110)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

struct InsightStatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HydrationEntryCardNew: View {
    let entry: HydrationEntry
    let colorScheme: ColorScheme
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.drinkType.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: entry.drinkType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(entry.drinkType.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(entry.amountMl) ml")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if entry.drinkType != .water {
                        Text("(\(entry.effectiveHydration) ml effective)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(entry.drinkType.displayName) • \(entry.formattedTime)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

// MARK: - Hydration Wave Shape

struct HydrationWaveShape: Shape {
    var progress: Double
    var waveOffset: Double
    
    var animatableData: Double {
        get { waveOffset }
        set { waveOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let height = rect.height * (1 - progress)
        let amplitude: CGFloat = 10
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, to: rect.width, by: 2) {
            let relativeX = x / rect.width
            let angle = relativeX * .pi * 3 + waveOffset
            let y = height + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Missing Data Item Model

struct MissingDataItem {
    let icon: String
    let title: String
    let description: String
    let action: String
}

#Preview {
    HydrationView(viewModel: HydrationViewModel())
}
