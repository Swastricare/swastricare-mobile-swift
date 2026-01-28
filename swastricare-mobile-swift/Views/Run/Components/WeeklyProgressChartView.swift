//
//  WeeklyProgressChartView.swift
//  swastricare-mobile-swift
//
//  Displays weekly running progress with bar chart
//

import SwiftUI
import Charts

struct WeeklyProgressChartView: View {
    
    let progressData: WeeklyProgressData
    @State private var selectedDay: WeeklyProgressData.DailyDistance?
    @State private var isAnimating = false
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            // Chart
            chartSection
            
            // Stats Row
            statsRow
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(weekDateRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress indicator
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f km", progressData.totalDistance))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(accentBlue)
                
                Text("of \(Int(progressData.goalDistance)) km goal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
    
    // MARK: - Chart
    
    private var chartSection: some View {
        VStack(spacing: 8) {
            Chart {
                // Goal line
                RuleMark(
                    y: .value("Goal", progressData.goalDistance / 7)
                )
                .foregroundStyle(accentGreen.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("Goal")
                        .font(.caption2)
                        .foregroundColor(accentGreen)
                }
                
                // Daily bars
                ForEach(progressData.dailyDistances) { day in
                    BarMark(
                        x: .value("Day", day.dayAbbreviation),
                        y: .value("Distance", day.distance)
                    )
                    .foregroundStyle(
                        day.id == selectedDay?.id ? accentBlue : accentBlue.opacity(0.7)
                    )
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if day.id == selectedDay?.id {
                            Text(String(format: "%.1f", day.distance))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(accentBlue)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(String(format: "%.0f", distance))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let day = value.as(String.self) {
                            Text(day)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                    if let day: String = proxy.value(atX: x) {
                                        selectedDay = progressData.dailyDistances.first { $0.dayAbbreviation == day }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedDay = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 160)
            
            // X-axis label
            Text("Distance (km)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            WeeklyStatItem(
                title: "Total",
                value: String(format: "%.1f km", progressData.totalDistance),
                color: accentBlue
            )
            
            Divider()
                .frame(height: 40)
            
            WeeklyStatItem(
                title: "Daily Avg",
                value: String(format: "%.1f km", progressData.avgDailyDistance),
                color: .orange
            )
            
            Divider()
                .frame(height: 40)
            
            WeeklyStatItem(
                title: "Activities",
                value: "\(progressData.totalActivities)",
                color: accentGreen
            )
            
            Divider()
                .frame(height: 40)
            
            WeeklyStatItem(
                title: "Progress",
                value: String(format: "%.0f%%", progressData.goalProgress * 100),
                color: progressData.goalProgress >= 1.0 ? accentGreen : .purple
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.15), value: isAnimating)
    }
    
    // MARK: - Helpers
    
    private var weekDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: progressData.weekStart)
        
        if let endDate = Calendar.current.date(byAdding: .day, value: 6, to: progressData.weekStart) {
            formatter.dateFormat = "d, yyyy"
            let endStr = formatter.string(from: endDate)
            return "\(startStr) - \(endStr)"
        }
        return startStr
    }
}

// MARK: - Weekly Stat Item

struct WeeklyStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Weekly Progress View (for RunActivityView)

struct CompactWeeklyProgressView: View {
    
    let dailySummaries: [DailyActivitySummary]
    let goalDistanceKm: Double
    
    @State private var isAnimating = false
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("This Week")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.1f km", totalDistance))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(accentBlue)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [accentBlue, accentGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(progressPercentage, 1.0))
                        .animation(.spring(response: 0.6), value: isAnimating)
                }
            }
            .frame(height: 12)
            
            // Daily bars
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.date) { day in
                    DayProgressBar(
                        dayName: day.shortName,
                        distance: day.distance,
                        maxDistance: maxDayDistance,
                        isToday: day.isToday
                    )
                }
            }
            .frame(height: 80)
            
            // Footer
            HStack {
                Text("\(Int(progressPercentage * 100))% of \(Int(goalDistanceKm)) km goal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(activeDays) active days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalDistance: Double {
        weekDays.reduce(0) { $0 + $1.distance }
    }
    
    private var progressPercentage: Double {
        guard goalDistanceKm > 0 else { return 0 }
        return totalDistance / goalDistanceKm
    }
    
    private var maxDayDistance: Double {
        weekDays.map { $0.distance }.max() ?? 1.0
    }
    
    private var activeDays: Int {
        weekDays.filter { $0.distance > 0 }.count
    }
    
    private var weekDays: [(date: Date, shortName: String, distance: Double, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            
            let summary = dailySummaries.first { summary in
                calendar.isDate(summary.date, inSameDayAs: date)
            }
            
            return (
                date: date,
                shortName: String(formatter.string(from: date).prefix(1)),
                distance: summary?.distance ?? 0,
                isToday: calendar.isDateInToday(date)
            )
        }
    }
}

// MARK: - Day Progress Bar

struct DayProgressBar: View {
    let dayName: String
    let distance: Double
    let maxDistance: Double
    let isToday: Bool
    
    private let accentBlue = Color(hex: "4F46E5")
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? accentBlue : accentBlue.opacity(0.6))
                        .frame(height: max(4, geometry.size.height * barHeight))
                }
            }
            
            Text(dayName)
                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? accentBlue : .secondary)
        }
    }
    
    private var barHeight: Double {
        guard maxDistance > 0, distance > 0 else { return 0.05 }
        return distance / maxDistance
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        WeeklyProgressChartView(
            progressData: WeeklyProgressData(
                weekStart: Date(),
                dailyDistances: [
                    .init(date: Date().addingTimeInterval(-6 * 86400), distance: 3.2, activityCount: 1),
                    .init(date: Date().addingTimeInterval(-5 * 86400), distance: 5.1, activityCount: 2),
                    .init(date: Date().addingTimeInterval(-4 * 86400), distance: 0, activityCount: 0),
                    .init(date: Date().addingTimeInterval(-3 * 86400), distance: 4.8, activityCount: 1),
                    .init(date: Date().addingTimeInterval(-2 * 86400), distance: 6.2, activityCount: 2),
                    .init(date: Date().addingTimeInterval(-1 * 86400), distance: 2.5, activityCount: 1),
                    .init(date: Date(), distance: 4.0, activityCount: 1)
                ],
                totalDistance: 25.8,
                totalActivities: 8,
                avgDailyDistance: 3.7,
                goalDistance: 50,
                goalProgress: 0.52
            )
        )
        .padding(.horizontal, 20)
        
        CompactWeeklyProgressView(
            dailySummaries: MockRunActivityData.generateDailySummaries(for: .oneWeek),
            goalDistanceKm: 50
        )
        .padding(.horizontal, 20)
    }
    .background(Color(UIColor.systemBackground))
}
