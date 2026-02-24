//
//  RunningActivityView.swift
//  swastricare-mobile-swift
//
//  Running Activity detail screen with steps, distance, pace, and analytics
//

import SwiftUI

struct RunningActivityView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var hasAppeared = false
    @State private var selectedTimeRange = "Today"
    @State private var animatedSteps: Int = 0
    
    private let timeRanges = ["Today", "Week", "Month"]
    
    // Sample data
    private let currentSteps = 6842
    private let goalSteps = 10000
    private let distance = 4.2
    private let calories = 320
    private let activeMinutes = 52
    private let avgPace = "6'24\""
    
    private var progress: Double {
        Double(currentSteps) / Double(goalSteps)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)
                    
                    mainProgressSection
                        .padding(.top, 32)
                    
                    timeRangeSelector
                        .padding(.top, 24)
                    
                    statsGridSection
                        .padding(.top, 24)
                    
                    hourlyChartSection
                        .padding(.top, 24)
                    
                    weeklyTrendSection
                        .padding(.top, 24)
                    
                    achievementsSection
                        .padding(.top, 24)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                animatedSteps = currentSteps
            }
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemBackground)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            Text("Running")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Main Progress Section
    
    private var mainProgressSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(MovementsColors.limeGreen.opacity(0.2), lineWidth: 16)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        MovementsColors.limeGreen,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: progress)
                
                VStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 28))
                        .foregroundColor(MovementsColors.limeGreen)
                    
                    Text("\(animatedSteps)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    Text("of \(goalSteps) steps")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 8) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MovementsColors.limeGreen)
                
                Text("of daily goal")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.9)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(timeRanges, id: \.self) { range in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeRange = range
                    }
                }) {
                    Text(range)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTimeRange == range ? .black : .primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? MovementsColors.limeGreen : Color.primary.opacity(0.1))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Stats Grid Section
    
    private var statsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            RunningStatCard(
                icon: "location.fill",
                title: "Distance",
                value: String(format: "%.1f", distance),
                unit: "km",
                color: Color(hex: "4ECDC4")
            )
            
            RunningStatCard(
                icon: "flame.fill",
                title: "Calories",
                value: "\(calories)",
                unit: "kcal",
                color: Color(hex: "FF6B6B")
            )
            
            RunningStatCard(
                icon: "clock.fill",
                title: "Active Time",
                value: "\(activeMinutes)",
                unit: "min",
                color: Color(hex: "45B7D1")
            )
            
            RunningStatCard(
                icon: "speedometer",
                title: "Avg Pace",
                value: avgPace,
                unit: "/km",
                color: Color(hex: "5856D6")
            )
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
    }
    
    // MARK: - Hourly Chart Section
    
    private var hourlyChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Activity")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            HourlyActivityChart()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }
    
    // MARK: - Weekly Trend Section
    
    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Trend")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("+12%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MovementsColors.limeGreen)
            }
            
            WeeklyTrendChart()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
    }
    
    // MARK: - Achievements Section
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Achievements")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    AchievementBadge(
                        icon: "flame.fill",
                        title: "5 Day Streak",
                        isUnlocked: true
                    )
                    
                    AchievementBadge(
                        icon: "star.fill",
                        title: "10K Steps",
                        isUnlocked: true
                    )
                    
                    AchievementBadge(
                        icon: "trophy.fill",
                        title: "Marathon",
                        isUnlocked: false
                    )
                    
                    AchievementBadge(
                        icon: "bolt.fill",
                        title: "Speed Demon",
                        isUnlocked: false
                    )
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: hasAppeared)
    }
}

// MARK: - Running Stat Card

struct RunningStatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MovementsColors.card(for: colorScheme))
        )
    }
}

// MARK: - Hourly Activity Chart

struct HourlyActivityChart: View {
    private let hourlyData: [(String, Double)] = [
        ("6am", 0.15),
        ("8am", 0.45),
        ("10am", 0.7),
        ("12pm", 0.5),
        ("2pm", 0.3),
        ("4pm", 0.6),
        ("6pm", 0.85),
        ("8pm", 0.4),
        ("10pm", 0.1)
    ]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(hourlyData, id: \.0) { item in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            item.1 > 0.6
                                ? MovementsColors.limeGreen
                                : MovementsColors.limeGreen.opacity(0.4)
                        )
                        .frame(width: 28, height: 100 * item.1)
                    
                    Text(item.0)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
    }
}

// MARK: - Weekly Trend Chart

struct WeeklyTrendChart: View {
    private let weeklyData: [(String, Double)] = [
        ("Mon", 0.65),
        ("Tue", 0.8),
        ("Wed", 0.55),
        ("Thu", 0.9),
        ("Fri", 0.7),
        ("Sat", 0.95),
        ("Sun", 0.68)
    ]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(weeklyData, id: \.0) { item in
                VStack(spacing: 8) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 36, height: 100)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [MovementsColors.limeGreen, MovementsColors.limeGreen.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 36, height: 100 * item.1)
                    }
                    
                    Text(item.0)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let icon: String
    let title: String
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                            ? MovementsColors.limeGreen
                            : Color.primary.opacity(0.1)
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isUnlocked ? .black : .secondary)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
        .opacity(isUnlocked ? 1 : 0.5)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RunningActivityView()
    }
}
