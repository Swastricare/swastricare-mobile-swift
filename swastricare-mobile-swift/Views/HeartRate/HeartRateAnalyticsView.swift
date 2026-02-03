//
//  HeartRateAnalyticsView.swift
//  swastricare-mobile-swift
//
//  Analytics + history for heart rate measurements.
//

import SwiftUI
import Charts

struct HeartRateAnalyticsView: View {
    
    @StateObject private var viewModel = HeartRateHistoryViewModel()
    @State private var range: HeartRateHistoryViewModel.TimeRange = .week
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                controls
                
                summaryCards
                
                chartSection
                
                detailsFooter
                
                historySection
                
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        viewModel.clearLocalHistory()
                    } label: {
                        Label("Clear on-device history", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(HeartRateHistoryViewModel.TimeRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("Source", selection: $viewModel.sourceFilter) {
                ForEach(HeartRateHistoryViewModel.SourceFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    private var summaryCards: some View {
        let s = viewModel.summary(range: range, filter: viewModel.sourceFilter)
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                HeartRateStatCard(title: "Average", value: s.avg.map(String.init) ?? "--", unit: "BPM", color: .red, icon: "waveform.path.ecg")
                HeartRateStatCard(title: "Latest", value: s.latest.map(String.init) ?? "--", unit: "BPM", color: .orange, icon: "clock.fill")
            }
            HStack(spacing: 12) {
                HeartRateStatCard(title: "Min", value: s.min.map(String.init) ?? "--", unit: "BPM", color: .blue, icon: "arrow.down")
                HeartRateStatCard(title: "Max", value: s.max.map(String.init) ?? "--", unit: "BPM", color: .pink, icon: "arrow.up")
            }
        }
    }
    
    private var chartSection: some View {
        let series = viewModel.dailySeries(range: range, filter: viewModel.sourceFilter)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily average", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                Text("\(series.count) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if series.isEmpty {
                ContentUnavailableView(
                    "Not enough data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Take measurements over time to see trends.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Chart(series) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("BPM", point.bpm)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Day", point.day),
                        y: .value("BPM", point.bpm)
                    )
                    .foregroundStyle(.red.opacity(0.7))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    private var detailsFooter: some View {
        let s = viewModel.summary(range: range, filter: viewModel.sourceFilter)
        return HStack {
            Label("\(s.count) readings", systemImage: "list.bullet")
            Spacer()
            if let msg = viewModel.errorMessage, viewModel.sourceFilter != .local {
                Label("Cloud unavailable", systemImage: "icloud.slash")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .help(msg)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
    }
    
    // MARK: - History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("History", systemImage: "clock")
                .font(.headline)
            
            if let msg = viewModel.errorMessage, viewModel.sourceFilter != .local {
                Label(msg, systemImage: "icloud.slash")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.filteredItems.isEmpty {
                ContentUnavailableView(
                    "No heart rate history",
                    systemImage: "clock",
                    description: Text("Take a measurement to see it here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(groupedDays, id: \.key) { day, items in
                    historyDayBlock(day: day, items: items)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    private var groupedDays: [(key: Date, value: [HeartRateHistoryViewModel.HeartRateMeasurementItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.filteredItems) { item in
            calendar.startOfDay(for: item.measuredAt)
        }
        return grouped
            .map { ($0.key, $0.value.sorted(by: { $0.measuredAt > $1.measuredAt })) }
            .sorted(by: { $0.0 > $1.0 })
    }
    
    private func historyDayBlock(day: Date, items: [HeartRateHistoryViewModel.HeartRateMeasurementItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(historyDayHeader(day))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            
            ForEach(items) { item in
                HeartRateAnalyticsHistoryRow(item: item)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)
                    .contextMenu {
                        if item.source == .local {
                            Button(role: .destructive) {
                                viewModel.deleteLocalItem(id: item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
    }
    
    private func historyDayHeader(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct HeartRateStatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(14)
    }
}

private struct HeartRateAnalyticsHistoryRow: View {
    let item: HeartRateHistoryViewModel.HeartRateMeasurementItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.source == .cloud ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "heart.fill")
                    .foregroundStyle(item.source == .cloud ? .blue : .red)
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(item.bpm)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                Text(item.measuredAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(item.source == .cloud ? "Cloud" : "Device")
                .font(.caption2.weight(.semibold))
                .foregroundColor(item.source == .cloud ? .blue : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((item.source == .cloud ? Color.blue : Color.red).opacity(0.12))
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.bpm) beats per minute at \(item.measuredAt.formatted(date: .omitted, time: .shortened))")
    }
}

#Preview {
    NavigationStack {
        HeartRateAnalyticsView()
    }
}

