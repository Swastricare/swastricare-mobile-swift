//
//  MenstruationViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  State management for menstrual cycle tracking module
//

import Foundation
import SwiftUI

// MARK: - Menstruation ViewModel

@MainActor
final class MenstruationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var dataState: MenstruationDataState = .idle
    @Published var cycles: [MenstrualCycle] = []
    @Published var currentCycle: MenstrualCycle?
    @Published var prediction: CyclePrediction?
    @Published var insights: CycleInsights?

    // Sheet state
    @Published var showLogSheet = false
    @Published var showHistorySheet = false
    @Published var showInsightsSheet = false

    // Daily log form
    @Published var logFlow: FlowIntensity? = nil
    @Published var logSymptoms: Set<PeriodSymptom> = []
    @Published var logMood: MoodType? = nil
    @Published var logPainLevel: Int = 0
    @Published var logEnergyLevel: Int = 3
    @Published var logNotes = ""
    @Published var logCervicalMucus: CervicalMucusType? = nil

    // Alert
    @Published var alertMessage: String?
    @Published var showAlert = false

    // MARK: - Dependencies

    private let service: MenstruationServiceProtocol

    // MARK: - Init

    init(service: MenstruationServiceProtocol = MenstruationService.shared) {
        self.service = service
    }

    // MARK: - Computed Properties

    var isPeriodActive: Bool { currentCycle?.isActive ?? false }

    var currentPhase: CyclePhase {
        guard let cycle = currentCycle else {
            // If no active cycle, try to estimate from last completed cycle
            if let pred = prediction {
                let daysUntil = pred.daysUntilNextPeriod
                if daysUntil <= 3 { return .luteal }
                if let ovDays = pred.daysUntilOvulation, ovDays <= 2 { return .ovulation }
                return .follicular
            }
            return .follicular
        }

        if cycle.isActive { return .menstrual }

        // Completed cycle - estimate phase from dates
        let daysSincePeriod = Calendar.current.dateComponents([.day], from: cycle.periodStart, to: Date()).day ?? 0
        let cycleLength = prediction?.averageCycleLength ?? 28

        if daysSincePeriod <= (cycle.periodLength ?? 5) { return .menstrual }
        if daysSincePeriod <= cycleLength / 2 - 2 { return .follicular }
        if daysSincePeriod <= cycleLength / 2 + 2 { return .ovulation }
        return .luteal
    }

    var dayOfCycle: Int {
        guard let recent = cycles.first else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: recent.periodStart, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    var periodDayCount: Int {
        guard let cycle = currentCycle, cycle.isActive else { return 0 }
        return (Calendar.current.dateComponents([.day], from: cycle.periodStart, to: Date()).day ?? 0) + 1
    }

    var statusText: String {
        if isPeriodActive {
            return "Day \(periodDayCount) of your period"
        }
        if let pred = prediction {
            let days = pred.daysUntilNextPeriod
            if days <= 0 { return "Period may start soon" }
            if days == 1 { return "Period expected tomorrow" }
            return "Period in \(days) days"
        }
        return "Track your cycle"
    }

    // MARK: - Load Data

    func loadData() async {
        dataState = .loading

        do {
            async let cyclesResult = service.fetchCycles(limit: 12)
            async let currentResult = service.fetchCurrentCycle()

            let fetchedCycles = try await cyclesResult
            let fetchedCurrent = try await currentResult

            self.cycles = fetchedCycles
            self.currentCycle = fetchedCurrent
            self.prediction = service.calculatePrediction(from: fetchedCycles)
            self.insights = service.calculateInsights(from: fetchedCycles)

            dataState = fetchedCycles.isEmpty ? .empty : .loaded
        } catch {
            print("🩸 Failed to load cycle data: \(error.localizedDescription)")
            dataState = .error(error.localizedDescription)
        }
    }

    // MARK: - Period Actions

    func startPeriod() async {
        guard !isPeriodActive else {
            showError("A period is already being tracked.")
            return
        }

        do {
            let cycle = try await service.startPeriod(date: Date(), flow: logFlow)
            currentCycle = cycle
            cycles.insert(cycle, at: 0)
            dataState = .loaded
            print("🩸 Period started")
        } catch {
            showError("Failed to start period: \(error.localizedDescription)")
        }
    }

    func endPeriod() async {
        guard let cycle = currentCycle, cycle.isActive else {
            showError("No active period to end.")
            return
        }

        do {
            let updated = try await service.endPeriod(cycleId: cycle.id, endDate: Date())
            currentCycle = nil
            if let idx = cycles.firstIndex(where: { $0.id == updated.id }) {
                cycles[idx] = updated
            }
            // Recalculate predictions
            prediction = service.calculatePrediction(from: cycles)
            insights = service.calculateInsights(from: cycles)
            print("🩸 Period ended")
        } catch {
            showError("Failed to end period: \(error.localizedDescription)")
        }
    }

    // MARK: - Daily Logging

    func saveDailyLog() async {
        guard let cycle = currentCycle else {
            showError("No active cycle to log.")
            return
        }

        do {
            try await service.logDailySymptoms(
                cycleId: cycle.id,
                symptoms: logSymptoms.map { $0.rawValue },
                painLevel: logPainLevel,
                mood: logMood?.rawValue,
                energyLevel: logEnergyLevel,
                flow: logFlow
            )

            // Update local state
            var updated = cycle
            updated.symptoms = logSymptoms.map { $0.rawValue }
            updated.painLevel = logPainLevel
            updated.mood = logMood?.rawValue
            updated.energyLevel = logEnergyLevel
            updated.flowIntensity = logFlow
            currentCycle = updated

            if let idx = cycles.firstIndex(where: { $0.id == cycle.id }) {
                cycles[idx] = updated
            }

            showLogSheet = false
            resetLogForm()
            print("🩸 Daily log saved")
        } catch {
            showError("Failed to save log: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Cycle

    func deleteCycle(_ cycle: MenstrualCycle) async {
        do {
            try await service.deleteCycle(id: cycle.id)
            cycles.removeAll { $0.id == cycle.id }
            if currentCycle?.id == cycle.id {
                currentCycle = nil
            }
            prediction = service.calculatePrediction(from: cycles)
            insights = service.calculateInsights(from: cycles)
            if cycles.isEmpty { dataState = .empty }
        } catch {
            showError("Failed to delete cycle: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    func prepareLogSheet() {
        if let cycle = currentCycle {
            // Pre-fill from current cycle data
            logFlow = cycle.flowIntensity
            logSymptoms = Set(cycle.symptoms.compactMap { PeriodSymptom(rawValue: $0) })
            logMood = cycle.mood.flatMap { MoodType(rawValue: $0) }
            logPainLevel = cycle.painLevel ?? 0
            logEnergyLevel = cycle.energyLevel ?? 3
        } else {
            resetLogForm()
        }
        showLogSheet = true
    }

    private func resetLogForm() {
        logFlow = nil
        logSymptoms = []
        logMood = nil
        logPainLevel = 0
        logEnergyLevel = 3
        logNotes = ""
        logCervicalMucus = nil
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
