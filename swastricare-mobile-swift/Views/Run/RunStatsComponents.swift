//
//  RunStatsComponents.swift
//  swastricare-mobile-swift
//
//  Enhanced components for run stats & analytics
//  Updated with Movements+ UI design - lime green accent, dark theme, geometric patterns
//

import SwiftUI
import Charts

// MARK: - Enhanced Stat Card with Trend

struct EnhancedStatCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let trend: Double?
    let progress: Double?
    
    private let limeGreen = MovementsColors.limeGreen
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color,
        trend: Double? = nil,
        progress: Double? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
        self.progress = progress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                if let trend = trend {
                    TrendBadge(trend: trend)
                }
            }
            
            ZStack(alignment: .leading) {
                if let progress = progress {
                    HStack(spacing: 0) {
                        Spacer()
                        ProgressRing(progress: progress, color: color, lineWidth: 7)
                            .frame(width: 64, height: 64)
                            .padding(.trailing, 10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(22)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let trend: Double
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
            
            Text(String(format: "%.1f%%", abs(trend)))
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(trend >= 0 ? limeGreen : .red)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((trend >= 0 ? limeGreen : Color.red).opacity(0.15))
        )
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Weekly Distance Chart

struct WeeklyDistanceChart: View {
    @Environment(\.colorScheme) var colorScheme
    
    let data: [(day: String, distance: Double)]
    let color: Color
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(limeGreen)
                    
                    Text("Weekly Distance")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(String(format: "%.1f km", data.reduce(0) { $0 + $1.distance }))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(limeGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(limeGreen.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Distance", item.distance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [limeGreen, limeGreen.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.15))
                }
            }
        }
        .padding(22)
        .padding(.bottom, 8)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Activity Streak Card

struct ActivityStreakCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    let currentStreak: Int
    let longestStreak: Int
    let color: Color
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(limeGreen.opacity(0.15))
                        .frame(width: 68, height: 68)
                    
                    VStack(spacing: 3) {
                        Text("\(currentStreak)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(limeGreen)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(limeGreen)
                    }
                }
                
                VStack(spacing: 3) {
                    Text("Current")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Streak")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 70)
            
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 68, height: 68)
                    
                    VStack(spacing: 3) {
                        Text("\(longestStreak)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                }
                
                VStack(spacing: 3) {
                    Text("Best")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Streak")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 6) {
                if currentStreak > 0 {
                    Text("Keep it up!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(limeGreen)
                    
                    Text("You're on a roll")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("Start a streak")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Exercise today")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(22)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Performance Insights Card

struct PerformanceInsightsCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    let insights: [PerformanceInsight]
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(limeGreen)
                
                Text("Performance Insights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 14) {
                ForEach(insights) { insight in
                    InsightRow(insight: insight)
                    
                    if insight.id != insights.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .padding(22)
        .background(
            ZStack {
                MovementsColors.card(for: colorScheme)
                
                LinearGradient(
                    colors: [
                        limeGreen.opacity(0.08),
                        limeGreen.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct PerformanceInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct InsightRow: View {
    let insight: PerformanceInsight
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(insight.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: insight.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(insight.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pace Distribution Chart

struct PaceDistributionChart: View {
    @Environment(\.colorScheme) var colorScheme
    
    let paceRanges: [(range: String, count: Int)]
    let color: Color
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(limeGreen)
                    
                    Text("Pace Distribution")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("\(paceRanges.reduce(0) { $0 + $1.count }) activities")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Chart {
                ForEach(Array(paceRanges.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Pace", item.range)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [limeGreen, limeGreen.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisValueLabel()
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(22)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Time of Day Analysis

struct TimeOfDayAnalysis: View {
    @Environment(\.colorScheme) var colorScheme
    
    let distribution: [(time: String, count: Int)]
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Preferred Workout Time")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 14) {
                ForEach(Array(distribution.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 14) {
                        Text(item.time)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 85, alignment: .leading)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.15))
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [limeGreen, limeGreen.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * percentage(for: item.count))
                            }
                        }
                        .frame(height: 36)
                        
                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(limeGreen)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
        .padding(22)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
    
    private func percentage(for count: Int) -> Double {
        let maxCount = distribution.map { $0.count }.max() ?? 1
        return Double(count) / Double(maxCount)
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    @Environment(\.colorScheme) var colorScheme
    
    let avgPace: String
    let avgHeartRate: Int
    let totalTime: String
    let avgDistance: Double
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 14) {
            QuickStatItem(
                icon: "speedometer",
                iconColor: limeGreen,
                value: avgPace,
                label: "Avg Pace",
                colorScheme: colorScheme
            )
            
            QuickStatItem(
                icon: "heart.fill",
                iconColor: .red,
                value: "\(avgHeartRate)",
                label: "Avg HR",
                colorScheme: colorScheme
            )
            
            QuickStatItem(
                icon: "clock.fill",
                iconColor: .orange,
                value: totalTime,
                label: "Total Time",
                colorScheme: colorScheme
            )
            
            QuickStatItem(
                icon: "map.fill",
                iconColor: Color(hex: "5AC8FA"),
                value: String(format: "%.1f km", avgDistance),
                label: "Avg Distance",
                colorScheme: colorScheme
            )
        }
    }
}

struct QuickStatItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(MovementsColors.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Personal Records Section

struct PersonalRecordsSection: View {
    @Environment(\.colorScheme) var colorScheme
    
    let records: [PersonalRecord]
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.yellow)
                
                Text("Personal Records")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 14) {
                ForEach(records) { record in
                    PersonalRecordRow(record: record)
                    
                    if record.id != records.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .padding(22)
        .background(
            ZStack {
                MovementsColors.card(for: colorScheme)
                
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.1),
                        Color.yellow.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let date: String
    let icon: String
}

struct PersonalRecordRow: View {
    let record: PersonalRecord
    
    private let limeGreen = MovementsColors.limeGreen
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 38, height: 38)
                
                Image(systemName: record.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(record.date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(limeGreen)
        }
        .padding(.vertical, 4)
    }
}
