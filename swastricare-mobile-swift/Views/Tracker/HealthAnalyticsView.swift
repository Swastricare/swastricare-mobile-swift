//
//  HealthAnalyticsView.swift
//  swastricare-mobile-swift
//
//  Created by Swasthicare AI
//

import SwiftUI
import Charts

struct HealthAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DependencyContainer.shared.trackerViewModel
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: HealthMetricType = .steps
    @State private var isAnimating = false
    @State private var showFilterSheet = false
    @State private var showHeartRateMeasurement = false
    
    enum TimeRange: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }
    
    enum HealthMetricType: String, CaseIterable {
        case steps = "Steps"
        case activeCalories = "Calories"
        case heartRate = "Heart Rate"
        case sleep = "Sleep"
        case exercise = "Exercise"
        case distance = "Distance"
        
        var icon: String {
            switch self {
            case .steps: return "figure.walk"
            case .activeCalories: return "flame.fill"
            case .heartRate: return "heart.fill"
            case .sleep: return "moon.fill"
            case .exercise: return "clock.fill"
            case .distance: return "arrow.left.and.right"
            }
        }
        
        var color: Color {
            switch self {
            case .steps: return MovementsColors.limeGreen
            case .activeCalories: return Color(hex: "FF9F43")
            case .heartRate: return Color(hex: "FF6B6B")
            case .sleep: return Color(hex: "5856D6")
            case .exercise: return Color(hex: "4ECDC4")
            case .distance: return Color(hex: "45B7D1")
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .steps: return [MovementsColors.limeGreen, Color(hex: "4ECDC4")]
            case .activeCalories: return [Color(hex: "FF9F43"), Color(hex: "FFB976")]
            case .heartRate: return [Color(hex: "FF6B6B"), Color(hex: "FF8E8E")]
            case .sleep: return [Color(hex: "5856D6"), Color(hex: "7B79E8")]
            case .exercise: return [Color(hex: "4ECDC4"), Color(hex: "7EDCD6")]
            case .distance: return [Color(hex: "45B7D1"), Color(hex: "6DCDE3")]
            }
        }
        
        var unit: String {
            switch self {
            case .steps: return "steps"
            case .activeCalories: return "kcal"
            case .heartRate: return "BPM"
            case .sleep: return "hrs"
            case .exercise: return "min"
            case .distance: return "km"
            }
        }
    }
    
    var body: some View {
        ZStack {
            analyticsBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    dateSelector
                    summaryCards
                    mainChartSection
                    metricsGrid
                    aiInsightsSection
                }
                .padding(.top)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(
                selectedMetric: $selectedMetric,
                selectedTimeRange: $selectedTimeRange
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showHeartRateMeasurement) {
            NavigationStack {
                HeartRateView()
            }
        }
        .sheet(isPresented: $viewModel.showAnalysisSheet) {
            AnalysisResultSheet(
                state: viewModel.analysisState,
                onDismiss: { viewModel.dismissAnalysis() }
            )
        }
    }
    
    // MARK: - Background
    
    private var analyticsBackground: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
            
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        MovementsColors.darkGreen.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RadialGradient(
                    colors: [
                        selectedMetric.color.opacity(0.1),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 50,
                    endRadius: 350
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health Analytics")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(MovementsColors.limeGreen)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.isSelectedDateToday ? "Today" : formattedSelectedDate)
                        .font(.system(size: 14))
                        .foregroundColor(MovementsColors.textSecondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                showFilterSheet = true
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }) {
                ZStack {
                    Circle()
                        .fill(MovementsColors.card(for: colorScheme))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MovementsColors.limeGreen)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : -10)
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: viewModel.selectedDate)
    }
    
    // MARK: - Date Selector
    
    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    AnalyticsDateButton(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        dayName: viewModel.dayName(for: date),
                        colorScheme: colorScheme
                    ) {
                        var transaction = Transaction(animation: .spring(response: 0.3, dampingFraction: 0.7))
                        transaction.disablesAnimations = false
                        withTransaction(transaction) {
                            Task {
                                await viewModel.selectDate(date)
                            }
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    }
                }
            }
            .padding(.horizontal)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            AnalyticsSummaryCard(
                title: "Steps",
                value: "\(viewModel.stepCount)",
                icon: "figure.walk",
                color: MovementsColors.limeGreen,
                progress: Double(viewModel.stepCount) / 10000.0,
                colorScheme: colorScheme
            )
            
            AnalyticsSummaryCard(
                title: "Calories",
                value: "\(viewModel.activeCalories)",
                icon: "flame.fill",
                color: Color(hex: "FF9F43"),
                progress: Double(viewModel.activeCalories) / 500.0,
                colorScheme: colorScheme
            )
            
            AnalyticsSummaryCard(
                title: "Exercise",
                value: "\(viewModel.exerciseMinutes)",
                icon: "clock.fill",
                color: Color(hex: "4ECDC4"),
                progress: Double(viewModel.exerciseMinutes) / 30.0,
                colorScheme: colorScheme
            )
        }
        .padding(.horizontal)
        .opacity(isAnimating ? 1 : 0)
        .scaleEffect(isAnimating ? 1 : 0.95)
    }
    
    // MARK: - Main Chart
    
    private var mainChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedMetric.color)
                        
                        Text(selectedMetric.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MovementsColors.textSecondary)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currentMetricValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        
                        Text(selectedMetric.unit)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MovementsColors.textSecondary)
                    }
                }
                
                Spacer()
                
                trendIndicator
            }
            .padding(.horizontal)
            
            Chart {
                ForEach(viewModel.weeklySteps) { metric in
                    BarMark(
                        x: .value("Day", metric.dayName),
                        y: .value("Value", chartValue(for: metric))
                    )
                    .foregroundStyle(barColor(for: metric))
                    .cornerRadius(8)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(formatAxisValue(intValue))
                                .font(.system(size: 10))
                                .foregroundColor(MovementsColors.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisValueLabel()
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MovementsColors.textSecondary)
                }
            }
            .frame(height: 200)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .padding(.horizontal)
            .id(chartAnimationKey)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chartAnimationKey)
            
            HStack(spacing: 12) {
                AnalyticsStatBadge(
                    title: "Weekly Avg",
                    value: weeklyAverage,
                    color: selectedMetric.color,
                    colorScheme: colorScheme
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMetric)
                
                AnalyticsStatBadge(
                    title: "Weekly Total",
                    value: weeklyTotal,
                    color: selectedMetric.color,
                    colorScheme: colorScheme
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMetric)
                
                AnalyticsStatBadge(
                    title: "Best Day",
                    value: bestDayValue,
                    color: selectedMetric.color,
                    colorScheme: colorScheme
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMetric)
            }
            .padding(.horizontal)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring().delay(0.1), value: isAnimating)
    }
    
    // Helper function to compute bar color with proper state management
    private func barColor(for metric: DailyMetric) -> Color {
        let isSelected = Calendar.current.isDate(metric.date, inSameDayAs: viewModel.selectedDate)
        return isSelected ? selectedMetric.color : selectedMetric.color.opacity(0.4)
    }
    
    // Combined identifier for chart animation tracking
    private var chartAnimationKey: String {
        "\(selectedMetric.rawValue)-\(viewModel.selectedDate.timeIntervalSince1970)"
    }
    
    private var trendIndicator: some View {
        let trend = calculateTrend()
        let isPositive = trend >= 0
        let trendColor = isPositive ? MovementsColors.limeGreen : Color(hex: "FF6B6B")
        
        return HStack(spacing: 6) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
            Text("\(abs(trend))%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(isPositive ? .black : .white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(trendColor)
        )
    }
    
    private func calculateTrend() -> Int {
        guard viewModel.weeklySteps.count >= 2 else { return 0 }
        let recent = viewModel.weeklySteps.suffix(3).reduce(0) { $0 + $1.steps }
        let previous = viewModel.weeklySteps.prefix(3).reduce(0) { $0 + $1.steps }
        guard previous > 0 else { return 0 }
        return Int(((Double(recent) - Double(previous)) / Double(previous)) * 100)
    }
    
    private func chartValue(for metric: DailyMetric) -> Int {
        switch selectedMetric {
        case .steps:
            return metric.steps
        case .activeCalories:
            return metric.steps / 20 // Approximation
        case .exercise:
            return metric.steps / 100 // Approximation
        case .distance:
            return metric.steps / 1500 // ~1500 steps per km
        default:
            return metric.steps
        }
    }
    
    private func formatAxisValue(_ value: Int) -> String {
        if value >= 1000 {
            return "\(value / 1000)k"
        }
        return "\(value)"
    }
    
    private var currentMetricValue: String {
        switch selectedMetric {
        case .steps: return "\(viewModel.stepCount)"
        case .activeCalories: return "\(viewModel.activeCalories)"
        case .heartRate: return "\(viewModel.heartRate)"
        case .sleep: return viewModel.sleepHours
        case .exercise: return "\(viewModel.exerciseMinutes)"
        case .distance: return String(format: "%.1f", viewModel.distance)
        }
    }
    
    private var weeklyAverage: String {
        let total = viewModel.weeklySteps.reduce(0) { $0 + $1.steps }
        let avg = viewModel.weeklySteps.isEmpty ? 0 : total / viewModel.weeklySteps.count
        switch selectedMetric {
        case .steps: return formatNumber(avg)
        case .activeCalories: return formatNumber(avg / 20)
        case .exercise: return "\(avg / 100)"
        default: return formatNumber(avg)
        }
    }
    
    private var weeklyTotal: String {
        let total = viewModel.weeklySteps.reduce(0) { $0 + $1.steps }
        switch selectedMetric {
        case .steps: return formatNumber(total)
        case .activeCalories: return formatNumber(total / 20)
        case .exercise: return "\(total / 100)"
        default: return formatNumber(total)
        }
    }
    
    private var bestDayValue: String {
        let best = viewModel.weeklySteps.max(by: { $0.steps < $1.steps })?.steps ?? 0
        switch selectedMetric {
        case .steps: return formatNumber(best)
        case .activeCalories: return formatNumber(best / 20)
        case .exercise: return "\(best / 100)"
        default: return formatNumber(best)
        }
    }
    
    private func formatNumber(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(HealthMetricType.allCases, id: \.self) { metric in
                MetricCard(
                    metric: metric,
                    value: metricValue(for: metric),
                    isSelected: selectedMetric == metric,
                    onTap: {
                        guard selectedMetric != metric else { return }
                        var transaction = Transaction(animation: .spring(response: 0.3, dampingFraction: 0.7))
                        transaction.disablesAnimations = false
                        withTransaction(transaction) {
                            selectedMetric = metric
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    },
                    onMeasure: metric == .heartRate ? {
                        showHeartRateMeasurement = true
                    } : nil
                )
            }
        }
        .padding(.horizontal)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
        .animation(.spring().delay(0.2), value: isAnimating)
    }
    
    private func metricValue(for metric: HealthMetricType) -> String {
        switch metric {
        case .steps: return "\(viewModel.stepCount)"
        case .activeCalories: return "\(viewModel.activeCalories)"
        case .heartRate: return "\(viewModel.heartRate)"
        case .sleep: return viewModel.sleepHours
        case .exercise: return "\(viewModel.exerciseMinutes)"
        case .distance: return String(format: "%.1f", viewModel.distance)
        }
    }
    
    // MARK: - AI Insights
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4"), Color(hex: "45B7D1"), MovementsColors.limeGreen],
                                    center: .center
                                )
                            )
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("AI Insights")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if viewModel.analysisState.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(MovementsColors.limeGreen)
                }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 14) {
                if let analysis = viewModel.analysisState.result?.analysis {
                    Text(analysis.assessment)
                        .font(.system(size: 14))
                        .lineLimit(4)
                        .foregroundColor(.primary)
                    
                    if !analysis.recommendations.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(MovementsColors.limeGreen)
                            
                            Text("Top Recommendation")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(MovementsColors.limeGreen)
                        }
                        
                        Text(analysis.recommendations.first ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(MovementsColors.textSecondary)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24))
                            .foregroundColor(MovementsColors.limeGreen.opacity(0.6))
                        
                        Text("Tap to generate personalized health insights based on your data.")
                            .font(.system(size: 14))
                            .foregroundColor(MovementsColors.textSecondary)
                    }
                }
                
                Button(action: {
                    Task { await viewModel.requestAIAnalysis() }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.analysisState.result != nil ? "Refresh Analysis" : "Generate Analysis")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(MovementsColors.limeGreen)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(viewModel.analysisState.isAnalyzing)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .padding(.horizontal)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 40)
        .animation(.spring().delay(0.3), value: isAnimating)
    }
}

// MARK: - Supporting Views

private struct AnalyticsDateButton: View {
    let date: Date
    let isSelected: Bool
    let dayName: String
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(dayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .black : MovementsColors.textSecondary)
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .black : .primary)
                
                if isSelected {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 52, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? MovementsColors.limeGreen : MovementsColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct AnalyticsSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let progress: Double
    let colorScheme: ColorScheme
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                Text("\(Int(min(progress, 1.0) * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(MovementsColors.textSecondary)
            
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
            .frame(height: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animatedProgress = min(progress, 1.0)
            }
        }
    }
}

private struct MetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let metric: HealthAnalyticsView.HealthMetricType
    let value: String
    let isSelected: Bool
    let onTap: () -> Void
    var onMeasure: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [metric.color.opacity(0.2), metric.color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: metric.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(metric.color)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MovementsColors.limeGreen)
                            .font(.system(size: 16))
                    }
                    
                    if let onMeasure = onMeasure {
                        Button(action: onMeasure) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(metric.color)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(value)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(metric.unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MovementsColors.textSecondary)
                    }
                    
                    Text(metric.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(MovementsColors.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected 
                            ? LinearGradient(colors: metric.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct AnalyticsStatBadge: View {
    let title: String
    let value: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(MovementsColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

private struct FilterSheet: View {
    @Binding var selectedMetric: HealthAnalyticsView.HealthMetricType
    @Binding var selectedTimeRange: HealthAnalyticsView.TimeRange
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                Section("Metric") {
                    ForEach(HealthAnalyticsView.HealthMetricType.allCases, id: \.self) { metric in
                        Button(action: {
                            selectedMetric = metric
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(metric.color.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: metric.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(metric.color)
                                }
                                
                                Text(metric.rawValue)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedMetric == metric {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(MovementsColors.limeGreen)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                    }
                }
                
                Section("Time Range") {
                    ForEach(HealthAnalyticsView.TimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedTimeRange = range
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }) {
                            HStack {
                                Text(range.rawValue)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTimeRange == range {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(MovementsColors.limeGreen)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MovementsColors.limeGreen)
                }
            }
        }
    }
}

private struct AnalysisResultSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let state: AnalysisState
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if state.isAnalyzing {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(MovementsColors.limeGreen.opacity(0.2), lineWidth: 4)
                                    .frame(width: 60, height: 60)
                                
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(MovementsColors.limeGreen)
                            }
                            
                            Text("Analyzing your health data...")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("This may take a moment")
                                .font(.system(size: 14))
                                .foregroundColor(MovementsColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let result = state.result {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(MovementsColors.limeGreen.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "heart.text.square.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(MovementsColors.limeGreen)
                                }
                                
                                Text("Assessment")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(result.analysis.assessment)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(MovementsColors.card(for: colorScheme))
                        )
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: "4ECDC4").opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "4ECDC4"))
                                }
                                
                                Text("Insights")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(result.analysis.insights)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(MovementsColors.card(for: colorScheme))
                        )
                        
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: "FF9F43").opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "FF9F43"))
                                }
                                
                                Text("Recommendations")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            ForEach(Array(result.analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(MovementsColors.limeGreen)
                                        )
                                    
                                    Text(rec)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(MovementsColors.card(for: colorScheme))
                        )
                    } else if case .error(let message) = state {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "FF9F43").opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "FF9F43"))
                            }
                            
                            Text("Analysis Error")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundColor(MovementsColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Health Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MovementsColors.limeGreen)
                }
            }
        }
    }
}

#Preview {
    HealthAnalyticsView()
}
