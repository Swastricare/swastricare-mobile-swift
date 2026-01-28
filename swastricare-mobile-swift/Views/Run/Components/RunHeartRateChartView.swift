//
//  RunHeartRateChartView.swift
//  swastricare-mobile-swift
//
//  Displays heart rate chart with zone distribution for run activities
//

import SwiftUI
import Charts

struct RunHeartRateChartView: View {
    
    let heartRateSamples: [RunHeartRateSample]
    let zoneDistribution: HeartRateZoneDistribution
    let avgHeartRate: Int
    let maxHeartRate: Int
    let minHeartRate: Int
    let userMaxHR: Int // User's max HR for zone calculation
    
    @State private var selectedSample: RunHeartRateSample?
    @State private var isAnimating = false
    
    private let accentRed = Color(hex: "EF4444")
    
    init(
        heartRateSamples: [RunHeartRateSample],
        zoneDistribution: HeartRateZoneDistribution = HeartRateZoneDistribution(),
        avgHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        minHeartRate: Int = 0,
        userMaxHR: Int = 190
    ) {
        self.heartRateSamples = heartRateSamples
        self.zoneDistribution = zoneDistribution
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.userMaxHR = userMaxHR
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            if heartRateSamples.isEmpty {
                emptyStateView
            } else {
                // Heart Rate Chart
                chartSection
                
                // Zone Distribution Bar
                zoneDistributionSection
                
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
                Text("Heart Rate")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("BPM over time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Current HR display if selected
            if let sample = selectedSample {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accentRed)
                        
                        Text("\(sample.bpm)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(accentRed)
                    }
                    
                    Text(formatTime(sample.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accentRed)
                        
                        Text("\(avgHeartRate)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Text("Average BPM")
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
                // Zone background bands
                ForEach(HeartRateZone.allCases, id: \.self) { zone in
                    RectangleMark(
                        xStart: nil,
                        xEnd: nil,
                        yStart: .value("Min", zoneMinHR(zone)),
                        yEnd: .value("Max", zoneMaxHR(zone))
                    )
                    .foregroundStyle(zone.color.opacity(0.1))
                }
                
                // Heart rate line with zone coloring
                ForEach(heartRateSamples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("HR", sample.bpm)
                    )
                    .foregroundStyle(colorForHeartRate(sample.bpm))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                
                // Area fill
                ForEach(heartRateSamples) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("HR", sample.bpm)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentRed.opacity(0.3), accentRed.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // Average HR reference line
                if avgHeartRate > 0 {
                    RuleMark(
                        y: .value("Avg", avgHeartRate)
                    )
                    .foregroundStyle(Color.orange.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
                
                // Selection point
                if let sample = selectedSample {
                    PointMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("HR", sample.bpm)
                    )
                    .foregroundStyle(accentRed)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatAxisTime(date))
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
                        if let hr = value.as(Int.self) {
                            Text("\(hr)")
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
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedSample = findClosestSample(to: date)
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
            .frame(height: 180)
            .padding(16)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.1), value: isAnimating)
    }
    
    // MARK: - Zone Distribution
    
    private var zoneDistributionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Zone Distribution")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatDuration(zoneDistribution.totalTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Zone bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(HeartRateZone.allCases, id: \.self) { zone in
                        let percentage = zoneDistribution.percentage(for: zone)
                        if percentage > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(zone.color)
                                .frame(width: max(4, geometry.size.width * CGFloat(percentage / 100)))
                        }
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // Zone legend
            HStack(spacing: 16) {
                ForEach(HeartRateZone.allCases, id: \.self) { zone in
                    let percentage = zoneDistribution.percentage(for: zone)
                    if percentage > 0 {
                        ZoneLegendItem(
                            zone: zone,
                            percentage: percentage,
                            time: zoneDistribution.time(for: zone)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.spring(response: 0.5).delay(0.15), value: isAnimating)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            RunHeartRateStatCard(
                title: "Average",
                value: avgHeartRate,
                icon: "heart.fill",
                color: .orange
            )
            
            RunHeartRateStatCard(
                title: "Maximum",
                value: maxHeartRate,
                icon: "arrow.up.heart.fill",
                color: accentRed
            )
            
            RunHeartRateStatCard(
                title: "Minimum",
                value: minHeartRate,
                icon: "arrow.down.heart.fill",
                color: .green
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
        .animation(.spring(response: 0.5).delay(0.2), value: isAnimating)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No heart rate data")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Heart rate data requires an Apple Watch or compatible heart rate monitor")
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
    
    private var yAxisDomain: ClosedRange<Int> {
        let hrValues = heartRateSamples.map { $0.bpm }
        let minHR = max(60, (hrValues.min() ?? 80) - 10)
        let maxHR = min(220, (hrValues.max() ?? 180) + 10)
        return minHR...maxHR
    }
    
    private func findClosestSample(to date: Date) -> RunHeartRateSample? {
        heartRateSamples.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }
    
    private func colorForHeartRate(_ hr: Int) -> Color {
        let zone = HeartRateZone.zone(for: hr, maxHeartRate: userMaxHR)
        return zone.color
    }
    
    private func zoneMinHR(_ zone: HeartRateZone) -> Int {
        Int(Double(userMaxHR) * zone.minPercentage)
    }
    
    private func zoneMaxHR(_ zone: HeartRateZone) -> Int {
        Int(Double(userMaxHR) * zone.maxPercentage)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
    
    private func formatAxisTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

// MARK: - Zone Legend Item

struct ZoneLegendItem: View {
    let zone: HeartRateZone
    let percentage: Double
    let time: TimeInterval
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(zone.color)
                    .frame(width: 8, height: 8)
                
                Text(zone.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(String(format: "%.0f%%", percentage))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Heart Rate Stat Card

struct RunHeartRateStatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            
            Text(value > 0 ? "\(value)" : "--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
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
}

// MARK: - Preview

#Preview {
    ScrollView(.vertical, showsIndicators: true) {
        RunHeartRateChartView(
            heartRateSamples: RunAnalyticsService.generateMockRunHeartRateSamples(),
            zoneDistribution: {
                var dist = HeartRateZoneDistribution()
                dist.recovery = 120
                dist.fatBurn = 300
                dist.cardio = 600
                dist.peak = 480
                dist.maximum = 60
                return dist
            }(),
            avgHeartRate: 152,
            maxHeartRate: 175,
            minHeartRate: 105,
            userMaxHR: 190
        )
    }
    .background(Color(UIColor.systemBackground))
}
