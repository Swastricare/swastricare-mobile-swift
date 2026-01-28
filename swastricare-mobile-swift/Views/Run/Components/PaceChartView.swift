//
//  PaceChartView.swift
//  swastricare-mobile-swift
//
//  Displays pace over distance/time chart for run activities
//

import SwiftUI
import Charts

struct PaceChartView: View {
    
    let paceSamples: [PaceSample]
    let avgPaceSecondsPerKm: Int
    let bestPaceSecondsPerKm: Int
    let worstPaceSecondsPerKm: Int
    
    @State private var selectedSample: PaceSample?
    @State private var isAnimating = false
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    private let accentOrange = Color(hex: "F59E0B")
    
    init(
        paceSamples: [PaceSample],
        avgPaceSecondsPerKm: Int = 0,
        bestPaceSecondsPerKm: Int = 0,
        worstPaceSecondsPerKm: Int = 0
    ) {
        self.paceSamples = paceSamples
        self.avgPaceSecondsPerKm = avgPaceSecondsPerKm
        self.bestPaceSecondsPerKm = bestPaceSecondsPerKm
        self.worstPaceSecondsPerKm = worstPaceSecondsPerKm
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            if paceSamples.isEmpty {
                emptyStateView
            } else {
                // Chart
                chartSection
                
                // Stats Row
                statsRow
            }
        }
        .padding(.horizontal, 20)
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
                Text("Pace Analysis")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Speed variation over distance")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Current pace display if selected
            if let sample = selectedSample {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(sample.formattedPace)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(accentBlue)
                    
                    Text(String(format: "%.2f km", sample.distanceKm))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
    
    // MARK: - Chart
    
    private var chartSection: some View {
        VStack(spacing: 0) {
            Chart {
                // Area fill under the line
                ForEach(paceSamples) { sample in
                    AreaMark(
                        x: .value("Distance", sample.distanceKm),
                        y: .value("Pace", sample.paceMinutesPerKm)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentBlue.opacity(0.3), accentBlue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // Main pace line
                ForEach(paceSamples) { sample in
                    LineMark(
                        x: .value("Distance", sample.distanceKm),
                        y: .value("Pace", sample.paceMinutesPerKm)
                    )
                    .foregroundStyle(accentBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                }
                
                // Average pace reference line
                if avgPaceSecondsPerKm > 0 {
                    RuleMark(
                        y: .value("Avg Pace", Double(avgPaceSecondsPerKm) / 60.0)
                    )
                    .foregroundStyle(accentOrange.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Avg")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(accentOrange)
                            .padding(.horizontal, 4)
                    }
                }
                
                // Selection indicator
                if let sample = selectedSample {
                    PointMark(
                        x: .value("Distance", sample.distanceKm),
                        y: .value("Pace", sample.paceMinutesPerKm)
                    )
                    .foregroundStyle(accentBlue)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(String(format: "%.1f", distance))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            Text(formatPaceMinutes(pace))
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
                                    if let distance: Double = proxy.value(atX: x) {
                                        selectedSample = findClosestSample(to: distance)
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedSample = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 200)
            .padding(16)
            
            // X-axis label
            Text("Distance (km)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            PaceStatCard(
                title: "Average",
                pace: avgPaceSecondsPerKm,
                icon: "speedometer",
                color: accentOrange
            )
            
            PaceStatCard(
                title: "Fastest",
                pace: bestPaceSecondsPerKm,
                icon: "hare.fill",
                color: accentGreen
            )
            
            PaceStatCard(
                title: "Slowest",
                pace: worstPaceSecondsPerKm,
                icon: "tortoise.fill",
                color: Color(hex: "EF4444")
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No pace data available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Pace data requires GPS tracking during the activity")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helpers
    
    private var yAxisDomain: ClosedRange<Double> {
        let paces = paceSamples.map { $0.paceMinutesPerKm }
        let minPace = (paces.min() ?? 4) - 0.5
        let maxPace = (paces.max() ?? 10) + 0.5
        return max(0, minPace)...maxPace
    }
    
    private func findClosestSample(to distance: Double) -> PaceSample? {
        paceSamples.min(by: { abs($0.distanceKm - distance) < abs($1.distanceKm - distance) })
    }
    
    private func formatPaceMinutes(_ minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Pace Stat Card

struct PaceStatCard: View {
    let title: String
    let pace: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            
            Text(formattedPace)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var formattedPace: String {
        guard pace > 0 else { return "--:--" }
        let minutes = pace / 60
        let seconds = pace % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        PaceChartView(
            paceSamples: RunAnalyticsService.generateMockPaceSamples(),
            avgPaceSecondsPerKm: 360,
            bestPaceSecondsPerKm: 310,
            worstPaceSecondsPerKm: 420
        )
    }
    .background(Color(UIColor.systemBackground))
}
