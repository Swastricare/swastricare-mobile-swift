//
//  HeartRateHistoryViewModel.swift
//  swastricare-mobile-swift
//
//  History + analytics for heart-rate measurements.
//

import Foundation
import Combine

@MainActor
final class HeartRateHistoryViewModel: ObservableObject {

    enum SourceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case local = "On device"
        case cloud = "Cloud"
        
        var id: String { rawValue }
    }
    
    struct HeartRateMeasurementItem: Identifiable, Equatable {
        enum Source: String {
            case local
            case cloud
        }
        
        let id: UUID
        let bpm: Int
        let measuredAt: Date
        let source: Source
        let confidence: Double?
        let deviceUsed: String?
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sourceFilter: SourceFilter = .all
    @Published private(set) var items: [HeartRateMeasurementItem] = []
    
    private let vitalSignsService: VitalSignsServiceProtocol
    private let localStorage: HeartRateLocalStorage
    
    init(
        vitalSignsService: VitalSignsServiceProtocol = VitalSignsService.shared,
        localStorage: HeartRateLocalStorage = .shared
    ) {
        self.vitalSignsService = vitalSignsService
        self.localStorage = localStorage
        self.items = localStorage.loadHistory(limit: 200).map {
            HeartRateMeasurementItem(
                id: $0.id,
                bpm: $0.bpm,
                measuredAt: $0.measuredAt,
                source: .local,
                confidence: $0.confidence,
                deviceUsed: $0.deviceUsed
            )
        }
    }
    
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        // Local always available
        let local = localItems()
        
        do {
            // Cloud may fail (logged out / network). That's fine: we still show local.
            let cloudReadings = try await vitalSignsService.fetchRecentHeartRateReadings(limit: 100)
            let cloud = cloudItems(from: cloudReadings)
            items = merge(local: local, cloud: cloud)
        } catch {
            items = local
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refreshLocalOnly() {
        items = localItems()
    }
    
    func deleteLocalItem(id: UUID) {
        localStorage.deleteMeasurement(id: id)
        refreshLocalOnly()
    }
    
    func clearLocalHistory() {
        localStorage.clearHistory()
        refreshLocalOnly()
    }
    
    var filteredItems: [HeartRateMeasurementItem] {
        switch sourceFilter {
        case .all:
            return items
        case .local:
            return items.filter { $0.source == .local }
        case .cloud:
            return items.filter { $0.source == .cloud }
        }
    }
    
    // MARK: - Analytics
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }
    }
    
    struct Summary: Equatable {
        let avg: Int?
        let min: Int?
        let max: Int?
        let latest: Int?
        let count: Int
    }
    
    func summary(range: TimeRange, filter: SourceFilter) -> Summary {
        let data = itemsFor(range: range, filter: filter)
        let bpms = data.map(\.bpm)
        let avg = bpms.isEmpty ? nil : Int(Double(bpms.reduce(0, +)) / Double(bpms.count))
        return Summary(
            avg: avg,
            min: bpms.min(),
            max: bpms.max(),
            latest: data.sorted(by: { $0.measuredAt > $1.measuredAt }).first?.bpm,
            count: bpms.count
        )
    }
    
    struct DailyPoint: Identifiable, Equatable {
        let id: Date
        let day: Date
        let bpm: Int
    }
    
    func dailySeries(range: TimeRange, filter: SourceFilter) -> [DailyPoint] {
        let calendar = Calendar.current
        let data = itemsFor(range: range, filter: filter)
        
        let grouped = Dictionary(grouping: data) { item in
            calendar.startOfDay(for: item.measuredAt)
        }
        
        let points: [DailyPoint] = grouped.map { (day, items) in
            let avg = Int(Double(items.map(\.bpm).reduce(0, +)) / Double(max(items.count, 1)))
            return DailyPoint(id: day, day: day, bpm: avg)
        }
        
        return points.sorted(by: { $0.day < $1.day })
    }
    
    // MARK: - Private
    
    private func itemsFor(range: TimeRange, filter: SourceFilter) -> [HeartRateMeasurementItem] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -range.days + 1, to: now) ?? now
        let filteredBySource: [HeartRateMeasurementItem]
        switch filter {
        case .all: filteredBySource = items
        case .local: filteredBySource = items.filter { $0.source == .local }
        case .cloud: filteredBySource = items.filter { $0.source == .cloud }
        }
        return filteredBySource.filter { $0.measuredAt >= start && $0.measuredAt <= now }
    }
    
    private func localItems() -> [HeartRateMeasurementItem] {
        localStorage.loadHistory(limit: 200).map {
            HeartRateMeasurementItem(
                id: $0.id,
                bpm: $0.bpm,
                measuredAt: $0.measuredAt,
                source: .local,
                confidence: $0.confidence,
                deviceUsed: $0.deviceUsed
            )
        }
    }
    
    private func cloudItems(from readings: [SavedVitalSign]) -> [HeartRateMeasurementItem] {
        readings.compactMap { r in
            guard let hr = r.heartRate else { return nil }
            return HeartRateMeasurementItem(
                id: r.id,
                bpm: hr,
                measuredAt: r.measuredAt,
                source: .cloud,
                confidence: nil,
                deviceUsed: r.deviceUsed
            )
        }
    }
    
    /// Merge local + cloud, de-duplicating items that look identical (same BPM and within 2s).
    private func merge(local: [HeartRateMeasurementItem], cloud: [HeartRateMeasurementItem]) -> [HeartRateMeasurementItem] {
        var result: [HeartRateMeasurementItem] = []
        result.reserveCapacity(local.count + cloud.count)
        
        func isDuplicate(_ item: HeartRateMeasurementItem, in existing: [HeartRateMeasurementItem]) -> Bool {
            existing.contains { e in
                e.bpm == item.bpm && abs(e.measuredAt.timeIntervalSince(item.measuredAt)) <= 2
            }
        }
        
        for c in cloud {
            result.append(c)
        }
        for l in local {
            if !isDuplicate(l, in: result) {
                result.append(l)
            }
        }
        
        return result.sorted(by: { $0.measuredAt > $1.measuredAt })
    }
}

