//
//  HealthAnalyticsView.swift
//  swastricare-mobile-swift
//
//  Created by Swasthicare AI
//

import SwiftUI
import Charts

struct HealthAnalyticsView: View {
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
            case .steps: return .green
            case .activeCalories: return .orange
            case .heartRate: return .red
            case .sleep: return .indigo
            case .exercise: return .blue
            case .distance: return .cyan
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
            PremiumBackground()
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
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health Analytics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(viewModel.isSelectedDateToday ? "Today" : formattedSelectedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showFilterSheet = true
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
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
            HStack(spacing: 12) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    DateButton(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        dayName: viewModel.dayName(for: date)
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
            SummaryCard(
                title: "Steps",
                value: "\(viewModel.stepCount)",
                icon: "figure.walk",
                color: .green,
                progress: Double(viewModel.stepCount) / 10000.0
            )
            
            SummaryCard(
                title: "Calories",
                value: "\(viewModel.activeCalories)",
                icon: "flame.fill",
                color: .orange,
                progress: Double(viewModel.activeCalories) / 500.0
            )
            
            SummaryCard(
                title: "Exercise",
                value: "\(viewModel.exerciseMinutes)",
                icon: "clock.fill",
                color: .blue,
                progress: Double(viewModel.exerciseMinutes) / 30.0
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedMetric.rawValue)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currentMetricValue)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        
                        Text(selectedMetric.unit)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Trend indicator
                trendIndicator
            }
            .padding(.horizontal)
            
            // Chart
            Chart {
                ForEach(viewModel.weeklySteps) { metric in
                    BarMark(
                        x: .value("Day", metric.dayName),
                        y: .value("Value", chartValue(for: metric))
                    )
                    .foregroundStyle(barColor(for: metric))
                    .cornerRadius(6)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(formatAxisValue(intValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(height: 200)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal)
            .id(chartAnimationKey)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chartAnimationKey)
            
            // Average & Total Stats
            HStack(spacing: 16) {
                StatBadge(
                    title: "Weekly Avg",
                    value: weeklyAverage,
                    color: selectedMetric.color
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMetric)
                
                StatBadge(
                    title: "Weekly Total",
                    value: weeklyTotal,
                    color: selectedMetric.color
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMetric)
                
                StatBadge(
                    title: "Best Day",
                    value: bestDayValue,
                    color: selectedMetric.color
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
        return HStack(spacing: 4) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
            Text("\(abs(trend))%")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(trend >= 0 ? .green : .red)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((trend >= 0 ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(8)
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
                Label("AI Insights", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.analysisState.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                if let analysis = viewModel.analysisState.result?.analysis {
                    Text(analysis.assessment)
                        .font(.subheadline)
                        .lineLimit(4)
                        .foregroundColor(.primary)
                    
                    if !analysis.recommendations.isEmpty {
                        Text("Top Recommendation:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text(analysis.recommendations.first ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Tap to generate personalized health insights based on your data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    Task { await viewModel.requestAIAnalysis() }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(viewModel.analysisState.result != nil ? "Refresh Analysis" : "Generate Analysis")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "2E3192"))
                    .cornerRadius(12)
                }
                .disabled(viewModel.analysisState.isAnalyzing)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 40)
        .animation(.spring().delay(0.3), value: isAnimating)
    }
}

// MARK: - Supporting Views

private struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let dayName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 50, height: 60)
            .background(isSelected ? Color(hex: "2E3192") : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text("\(Int(min(progress, 1.0) * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0))
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

private struct MetricCard: View {
    let metric: HealthAnalyticsView.HealthMetricType
    let value: String
    let isSelected: Bool
    let onTap: () -> Void
    var onMeasure: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.title3)
                        .foregroundColor(metric.color)
                        .padding(8)
                        .background(metric.color.opacity(0.1))
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "2E3192"))
                            .font(.caption)
                    }
                    
                    if let onMeasure = onMeasure {
                        Button(action: onMeasure) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(metric.color)
                                .clipShape(Circle())
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(metric.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(metric.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

private struct FilterSheet: View {
    @Binding var selectedMetric: HealthAnalyticsView.HealthMetricType
    @Binding var selectedTimeRange: HealthAnalyticsView.TimeRange
    @Environment(\.dismiss) private var dismiss
    
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
                            HStack {
                                Image(systemName: metric.icon)
                                    .foregroundColor(metric.color)
                                    .frame(width: 30)
                                
                                Text(metric.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedMetric == metric {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "2E3192"))
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
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTimeRange == range {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "2E3192"))
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
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct AnalysisResultSheet: View {
    let state: AnalysisState
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if state.isAnalyzing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Analyzing your health data...")
                                .font(.headline)
                            Text("This may take a moment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let result = state.result {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Assessment", systemImage: "heart.text.square.fill")
                                .font(.headline)
                                .foregroundColor(Color(hex: "2E3192"))
                            
                            Text(result.analysis.assessment)
                                .font(.body)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Insights", systemImage: "lightbulb.fill")
                                .font(.headline)
                                .foregroundColor(Color(hex: "2E3192"))
                            
                            Text(result.analysis.insights)
                                .font(.body)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Recommendations", systemImage: "star.fill")
                                .font(.headline)
                                .foregroundColor(Color(hex: "2E3192"))
                            
                            ForEach(Array(result.analysis.recommendations.enumerated()), id: \.offset) { index, rec in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "2E3192"))
                                    Text(rec)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    } else if case .error(let message) = state {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Analysis Error")
                                .font(.headline)
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    HealthAnalyticsView()
}
