//
//  SplitsListView.swift
//  swastricare-mobile-swift
//
//  Displays kilometer-by-kilometer split breakdown for run activities
//

import SwiftUI

struct SplitsListView: View {
    
    let splits: [ActivitySplit]
    let bestSplitIndex: Int?
    let worstSplitIndex: Int?
    
    @State private var isAnimating = false
    
    private let accentBlue = Color(hex: "4F46E5")
    private let accentGreen = Color(hex: "22C55E")
    private let accentRed = Color(hex: "EF4444")
    
    init(splits: [ActivitySplit], bestSplitIndex: Int? = nil, worstSplitIndex: Int? = nil) {
        self.splits = splits
        self.bestSplitIndex = bestSplitIndex
        self.worstSplitIndex = worstSplitIndex
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            // Splits List
            if splits.isEmpty {
                emptyStateView
            } else {
                splitsListSection
                
                // Summary
                summarySection
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
                Text("Splits")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(splits.count) kilometer\(splits.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Legend
            HStack(spacing: 12) {
                LegendItem(color: accentGreen, label: "Best")
                LegendItem(color: accentRed, label: "Slowest")
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
    
    // MARK: - Splits List
    
    private var splitsListSection: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack {
                Text("KM")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                Spacer()
                
                Text("Time")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .center)
                
                Text("Pace")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .center)
                
                Text("Elev")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                
                if splits.first?.avgHeartRate != nil {
                    Text("HR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
            
            // Split rows
            ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                SplitRow(
                    split: split,
                    isBest: bestSplitIndex == index,
                    isWorst: worstSplitIndex == index,
                    showHeartRate: splits.first?.avgHeartRate != nil
                )
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.spring(response: 0.5).delay(Double(index) * 0.05), value: isAnimating)
                
                if index < splits.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Summary
    
    private var summarySection: some View {
        HStack(spacing: 16) {
            SplitSummaryCard(
                title: "Avg Pace",
                value: averagePace,
                icon: "speedometer",
                color: accentBlue
            )
            
            SplitSummaryCard(
                title: "Best",
                value: bestPace,
                icon: "arrow.up.circle.fill",
                color: accentGreen
            )
            
            SplitSummaryCard(
                title: "Slowest",
                value: worstPace,
                icon: "arrow.down.circle.fill",
                color: accentRed
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.spring(response: 0.5).delay(0.3), value: isAnimating)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No splits available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Splits are calculated for runs over 1 km")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Computed Properties
    
    private var averagePace: String {
        guard !splits.isEmpty else { return "--:--" }
        let total = splits.reduce(0) { $0 + $1.paceSecondsPerKm }
        let avg = total / splits.count
        return formatPace(avg)
    }
    
    private var bestPace: String {
        guard let best = splits.min(by: { $0.paceSecondsPerKm < $1.paceSecondsPerKm }) else { return "--:--" }
        return formatPace(best.paceSecondsPerKm)
    }
    
    private var worstPace: String {
        guard let worst = splits.max(by: { $0.paceSecondsPerKm < $1.paceSecondsPerKm }) else { return "--:--" }
        return formatPace(worst.paceSecondsPerKm)
    }
    
    private func formatPace(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Split Row

struct SplitRow: View {
    let split: ActivitySplit
    let isBest: Bool
    let isWorst: Bool
    let showHeartRate: Bool
    
    private let accentGreen = Color(hex: "22C55E")
    private let accentRed = Color(hex: "EF4444")
    
    var body: some View {
        HStack {
            // Kilometer number with indicator
            HStack(spacing: 6) {
                if isBest {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(accentGreen)
                } else if isWorst {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: 10))
                        .foregroundColor(accentRed)
                }
                
                Text("\(split.id)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(rowColor)
            }
            .frame(width: 40, alignment: .leading)
            
            Spacer()
            
            // Time
            Text(split.formattedDuration)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .center)
            
            // Pace
            Text(split.formattedPace)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(rowColor)
                .frame(width: 70, alignment: .center)
            
            // Elevation
            HStack(spacing: 2) {
                if split.elevationGain > 0 {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
                Text(String(format: "%.0fm", split.elevationGain - split.elevationLoss))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .trailing)
            
            // Heart Rate
            if showHeartRate {
                if let hr = split.avgHeartRate {
                    Text("\(hr)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                } else {
                    Text("--")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground)
    }
    
    private var rowColor: Color {
        if isBest { return accentGreen }
        if isWorst { return accentRed }
        return .primary
    }
    
    private var rowBackground: Color {
        if isBest { return accentGreen.opacity(0.08) }
        if isWorst { return accentRed.opacity(0.08) }
        return .clear
    }
}

// MARK: - Split Summary Card

struct SplitSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SplitsListView(
            splits: RunAnalyticsService.generateMockSplits(),
            bestSplitIndex: 2,
            worstSplitIndex: 4
        )
    }
    .background(Color(UIColor.systemBackground))
}
