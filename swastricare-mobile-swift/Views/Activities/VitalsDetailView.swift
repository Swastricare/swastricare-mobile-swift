//
//  VitalsDetailView.swift
//  swastricare-mobile-swift
//
//  Complete Vitals Dashboard with animated cards and detailed health metrics
//

import SwiftUI

struct VitalsDetailView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    
    @State private var hasAppeared = false
    @State private var selectedVital: VitalType? = nil
    @State private var showHeartRateDetail = false
    
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                    
                    heroVitalsCard
                        .padding(.top, 24)
                    
                    summarySection
                        .padding(.top, 20)
                    
                    mainVitalsGrid
                        .padding(.top, 24)
                    
                    secondaryVitalsSection
                        .padding(.top, 20)
                    
                    weeklyTrendSection
                        .padding(.top, 24)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showHeartRateDetail) {
            NavigationStack {
                TargetHeartRateView()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
        .task {
            await homeViewModel.loadTodaysData()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        MovementsColors.darkGreen.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                RadialGradient(
                    colors: [
                        MovementsColors.limeGreen.opacity(0.08),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 50,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Hero Vitals Card
    
    private var heroVitalsCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(MovementsColors.limeGreen)
            
            VitalsGeometricPattern()
                .clipShape(RoundedRectangle(cornerRadius: 28))
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Health Score")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        
                        Text("\(Int(healthScore * 100))%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: healthScore)
                            .stroke(
                                Color.black,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                }
                
                HStack(spacing: 20) {
                    VitalsHeroStat(icon: "figure.walk", value: formatNumber(homeViewModel.stepCount), label: "Steps")
                    VitalsHeroStat(icon: "flame.fill", value: "\(homeViewModel.activeCalories)", label: "Cal")
                    VitalsHeroStat(icon: "moon.fill", value: parseSleepValue(homeViewModel.sleepHours), label: "Sleep")
                }
            }
            .padding(24)
        }
        .frame(height: 200)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(MovementsColors.card(for: colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Health Vitals")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(MovementsColors.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                Task { await homeViewModel.refresh() }
            }) {
                ZStack {
                    Circle()
                        .fill(MovementsColors.card(for: colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MovementsColors.limeGreen)
                        .rotationEffect(.degrees(homeViewModel.isLoading ? 360 : 0))
                        .animation(homeViewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: homeViewModel.isLoading)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Overview")
                        .font(.system(size: 14))
                        .foregroundColor(MovementsColors.textSecondary)
                    
                    Text(healthScoreText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(MovementsColors.limeGreen)
                    
                    Text("\(Int(healthScore * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MovementsColors.limeGreen)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(MovementsColors.limeGreen.opacity(0.15))
                )
            }
            
            Text(healthSummaryMessage)
                .font(.system(size: 14))
                .foregroundColor(MovementsColors.textSecondary)
                .lineLimit(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Main Vitals Grid
    
    private var mainVitalsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            VitalCard(
                type: .steps,
                value: "\(formatNumber(homeViewModel.stepCount))",
                unit: "steps",
                progress: homeViewModel.stepProgress,
                goal: "10,000",
                isSelected: selectedVital == .steps
            ) {
                withAnimation(.spring(response: 0.4)) {
                    selectedVital = selectedVital == .steps ? nil : .steps
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
            
            VitalCard(
                type: .heartRate,
                value: "\(homeViewModel.heartRate > 0 ? homeViewModel.heartRate : 72)",
                unit: "bpm",
                progress: min(Double(homeViewModel.heartRate > 0 ? homeViewModel.heartRate : 72) / 200.0, 1.0),
                goal: "60-100",
                isSelected: selectedVital == .heartRate
            ) {
                showHeartRateDetail = true
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
            
            VitalCard(
                type: .calories,
                value: "\(homeViewModel.activeCalories)",
                unit: "kcal",
                progress: homeViewModel.calorieProgress,
                goal: "500",
                isSelected: selectedVital == .calories
            ) {
                withAnimation(.spring(response: 0.4)) {
                    selectedVital = selectedVital == .calories ? nil : .calories
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
            
            VitalCard(
                type: .sleep,
                value: parseSleepValue(homeViewModel.sleepHours),
                unit: "hrs",
                progress: min(parseSleepHours(homeViewModel.sleepHours) / 8.0, 1.0),
                goal: "8",
                isSelected: selectedVital == .sleep
            ) {
                withAnimation(.spring(response: 0.4)) {
                    selectedVital = selectedVital == .sleep ? nil : .sleep
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
        }
    }
    
    // MARK: - Secondary Vitals Section
    
    private var secondaryVitalsSection: some View {
        VStack(spacing: 12) {
            SecondaryVitalRow(
                icon: "figure.run",
                title: "Exercise",
                value: "\(homeViewModel.exerciseMinutes)",
                unit: "min",
                progress: homeViewModel.exerciseProgress,
                color: MovementsColors.limeGreen
            )
            
            SecondaryVitalRow(
                icon: "figure.stand",
                title: "Stand Hours",
                value: "\(homeViewModel.standHours)",
                unit: "hrs",
                progress: min(Double(homeViewModel.standHours) / 12.0, 1.0),
                color: Color(hex: "5AC8FA")
            )
            
            SecondaryVitalRow(
                icon: "ruler",
                title: "Distance",
                value: String(format: "%.1f", homeViewModel.distance),
                unit: "km",
                progress: min(homeViewModel.distance / 8.0, 1.0),
                color: Color(hex: "AF52DE")
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: hasAppeared)
    }
    
    // MARK: - Weekly Trend Section
    
    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(MovementsColors.limeGreen)
                    
                    Text("Weekly Steps")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Last 7 days")
                    .font(.system(size: 12))
                    .foregroundColor(MovementsColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                    )
            }
            
            WeeklyStepsChart(data: homeViewModel.weeklySteps, maxSteps: homeViewModel.maxWeeklySteps)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: hasAppeared)
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    private var healthScore: Double {
        let stepScore = homeViewModel.stepProgress
        let calorieScore = homeViewModel.calorieProgress
        let exerciseScore = homeViewModel.exerciseProgress
        let sleepScore = min(parseSleepHours(homeViewModel.sleepHours) / 8.0, 1.0)
        
        return (stepScore + calorieScore + exerciseScore + sleepScore) / 4.0
    }
    
    private var healthScoreText: String {
        let score = Int(healthScore * 100)
        if score >= 80 { return "Excellent Day!" }
        if score >= 60 { return "Good Progress" }
        if score >= 40 { return "Keep Moving" }
        return "Let's Get Active"
    }
    
    private var healthSummaryMessage: String {
        let steps = homeViewModel.stepCount
        let calories = homeViewModel.activeCalories
        
        if steps >= 10000 && calories >= 500 {
            return "You've hit all your goals today! Amazing work keeping active."
        } else if steps >= 7000 {
            return "Great progress! You're \(10000 - steps) steps away from your daily goal."
        } else {
            return "Keep moving! Every step counts towards a healthier you."
        }
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func parseSleepValue(_ sleepString: String) -> String {
        let hours = parseSleepHours(sleepString)
        if hours == 0 { return "0" }
        return String(format: "%.1f", hours)
    }
    
    private func parseSleepHours(_ sleepString: String) -> Double {
        let components = sleepString.lowercased().components(separatedBy: CharacterSet.letters.union(.whitespaces))
        let numbers = components.compactMap { Double($0) }
        if numbers.count >= 2 {
            return numbers[0] + numbers[1] / 60.0
        } else if numbers.count == 1 {
            return numbers[0]
        }
        return 0
    }
}

// MARK: - Vital Type Enum

enum VitalType: String, CaseIterable {
    case steps = "Steps"
    case heartRate = "Heart Rate"
    case calories = "Calories"
    case sleep = "Sleep"
    case exercise = "Exercise"
    
    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .heartRate: return "heart.fill"
        case .calories: return "flame.fill"
        case .sleep: return "moon.fill"
        case .exercise: return "figure.run"
        }
    }
    
    var color: Color {
        switch self {
        case .steps: return MovementsColors.limeGreen
        case .heartRate: return Color(hex: "FF6B6B")
        case .calories: return Color(hex: "FF9F43")
        case .sleep: return Color(hex: "5856D6")
        case .exercise: return Color(hex: "4ECDC4")
        }
    }
    
    var gradient: [Color] {
        switch self {
        case .steps: return [MovementsColors.limeGreen, Color(hex: "4ECDC4")]
        case .heartRate: return [Color(hex: "FF6B6B"), Color(hex: "FF8E8E")]
        case .calories: return [Color(hex: "FF9F43"), Color(hex: "FFB976")]
        case .sleep: return [Color(hex: "5856D6"), Color(hex: "7B79E8")]
        case .exercise: return [Color(hex: "4ECDC4"), Color(hex: "7EDCD6")]
        }
    }
}

// MARK: - Vitals Geometric Pattern

struct VitalsGeometricPattern: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let spacing: CGFloat = 14
                    let startX = geometry.size.width * 0.4
                    
                    for i in 0..<10 {
                        let x = startX + CGFloat(i) * spacing
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - geometry.size.height * 0.6, y: geometry.size.height))
                    }
                }
                .stroke(Color.black.opacity(0.06), lineWidth: 2)
                
                Circle()
                    .fill(Color.black.opacity(0.03))
                    .frame(width: 150, height: 150)
                    .offset(x: geometry.size.width * 0.3, y: -30)
            }
        }
    }
}

// MARK: - Vitals Hero Stat

struct VitalsHeroStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.7))
                
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.08))
        )
    }
}

// MARK: - Vital Card Component

struct VitalCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let type: VitalType
    let value: String
    let unit: String
    let progress: Double
    let goal: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var animatedProgress: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(MovementsColors.card(for: colorScheme))
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: type.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [type.color.opacity(0.2), type.color.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .scaleEffect(pulseScale)
                            
                            Image(systemName: type.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(type.color)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Goal")
                                .font(.system(size: 10))
                                .foregroundColor(MovementsColors.textSecondary)
                            Text(goal)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(type.color)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(type.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(MovementsColors.textSecondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(value)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            
                            Text(unit)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MovementsColors.textSecondary)
                        }
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(colorScheme == .dark ? MovementsColors.progressBackground : type.color.opacity(0.15))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: type.gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * animatedProgress, height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.top, 12)
                }
                .padding(18)
            }
            .frame(height: 170)
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedProgress = progress
            }
            
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
            }
        }
    }
}

// MARK: - Secondary Vital Row

struct SecondaryVitalRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let color: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(MovementsColors.textSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MovementsColors.textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? MovementsColors.progressBackground : color.opacity(0.15))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * animatedProgress, height: 6)
                    }
                }
                .frame(width: 80, height: 6)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Weekly Steps Chart

struct WeeklyStepsChart: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let data: [DailyMetric]
    let maxSteps: Int
    
    @State private var animatedHeights: [CGFloat] = Array(repeating: 0, count: 7)
    
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var todayIndex: Int {
        Calendar.current.component(.weekday, from: Date()) - 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<7, id: \.self) { index in
                let isToday = index == todayIndex
                
                VStack(spacing: 8) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? MovementsColors.progressBackground : Color.primary.opacity(0.08))
                            .frame(width: 36, height: 110)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isToday
                                    ? LinearGradient(
                                        colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: colorScheme == .dark 
                                            ? [Color.white.opacity(0.4), Color.white.opacity(0.2)]
                                            : [Color.primary.opacity(0.35), Color.primary.opacity(0.2)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                            .frame(width: 36, height: animatedHeights[index])
                        
                        if isToday {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .offset(y: -animatedHeights[index] + 4)
                        }
                    }
                    
                    VStack(spacing: 2) {
                        Text(dayLabels[index])
                            .font(.system(size: 12, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? MovementsColors.limeGreen : MovementsColors.textSecondary)
                        
                        if isToday {
                            Circle()
                                .fill(MovementsColors.limeGreen)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            for index in 0..<7 {
                let steps = index < data.count ? data[index].steps : Int.random(in: 3000...8000)
                let height = maxSteps > 0 ? CGFloat(steps) / CGFloat(maxSteps) * 110 : 0
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.08)) {
                    animatedHeights[index] = max(height, 10)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VitalsDetailView()
    }
}
