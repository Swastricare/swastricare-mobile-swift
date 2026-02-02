//
//  RunStatsComponents.swift
//  swastricare-mobile-swift
//
//  Enhanced components for run stats & analytics
//

import SwiftUI
import Charts

// MARK: - Enhanced Stat Card with Trend

struct EnhancedStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let trend: Double? // Percentage change
    let progress: Double? // 0-1 for progress ring
    
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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                if let trend = trend {
                    TrendBadge(trend: trend)
                }
            }
            
            // Value with progress ring
            ZStack(alignment: .leading) {
                if let progress = progress {
                    HStack(spacing: 0) {
                        Spacer()
                        ProgressRing(progress: progress, color: color, lineWidth: 6)
                            .frame(width: 60, height: 60)
                            .padding(.trailing, 8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let trend: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            
            Text(String(format: "%.1f%%", abs(trend)))
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(trend >= 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((trend >= 0 ? Color.green : Color.red).opacity(0.15))
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
            // Background circle
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
            
            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Weekly Distance Chart

struct WeeklyDistanceChart: View {
    let data: [(day: String, distance: Double)]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Distance")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.1f km total", data.reduce(0) { $0 + $1.distance }))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Distance", item.distance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.2))
                }
            }
        }
        .padding(20)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Activity Streak Card

struct ActivityStreakCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            // Current streak
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    VStack(spacing: 2) {
                        Text("\(currentStreak)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(color)
                    }
                }
                
                VStack(spacing: 2) {
                    Text("Current")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Streak")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .frame(height: 60)
            
            // Longest streak
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    VStack(spacing: 2) {
                        Text("\(longestStreak)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                
                VStack(spacing: 2) {
                    Text("Best")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Streak")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Motivation text
            VStack(alignment: .leading, spacing: 4) {
                if currentStreak > 0 {
                    Text("🔥 Keep it up!")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("You're on a roll")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Start a streak")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Exercise today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Performance Insights Card

struct PerformanceInsightsCard: View {
    let insights: [PerformanceInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
                
                Text("Performance Insights")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(insights) { insight in
                    InsightRow(insight: insight)
                    
                    if insight.id != insights.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.05),
                    Color.purple.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(insight.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: insight.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(insight.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Pace Distribution Chart

struct PaceDistributionChart: View {
    let paceRanges: [(range: String, count: Int)]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pace Distribution")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(paceRanges.reduce(0) { $0 + $1.count }) activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Chart {
                ForEach(Array(paceRanges.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Pace", item.range)
                    )
                    .foregroundStyle(color.gradient)
                    .cornerRadius(6)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Time of Day Analysis

struct TimeOfDayAnalysis: View {
    let distribution: [(time: String, count: Int)]
    
    private let accentBlue = AppColors.accentBlue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentBlue)
                
                Text("Preferred Workout Time")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(Array(distribution.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Text(item.time)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .leading)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.15))
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [accentBlue, accentBlue.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * percentage(for: item.count))
                            }
                        }
                        .frame(height: 32)
                        
                        Text("\(item.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func percentage(for count: Int) -> Double {
        let maxCount = distribution.map { $0.count }.max() ?? 1
        return Double(count) / Double(maxCount)
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    let avgPace: String
    let avgHeartRate: Int
    let totalTime: String
    let avgDistance: Double
    
    private let accentBlue = AppColors.accentBlue
    private let accentRed = Color.red
    private let accentGreen = AppColors.accentGreen
    private let accentOrange = Color.orange
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            QuickStatItem(
                icon: "speedometer",
                iconColor: accentBlue,
                value: avgPace,
                label: "Avg Pace"
            )
            
            QuickStatItem(
                icon: "heart.fill",
                iconColor: accentRed,
                value: "\(avgHeartRate)",
                label: "Avg HR"
            )
            
            QuickStatItem(
                icon: "clock.fill",
                iconColor: accentOrange,
                value: totalTime,
                label: "Total Time"
            )
            
            QuickStatItem(
                icon: "map.fill",
                iconColor: accentGreen,
                value: String(format: "%.1f km", avgDistance),
                label: "Avg Distance"
            )
        }
    }
}

struct QuickStatItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Personal Records Section

struct PersonalRecordsSection: View {
    let records: [PersonalRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yellow)
                
                Text("Personal Records")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(records) { record in
                    PersonalRecordRow(record: record)
                    
                    if record.id != records.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.yellow.opacity(0.08),
                    Color.yellow.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
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
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(record.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}
