//
//  MenstrualCycleService.swift
//  swastricare-mobile-swift
//
//  Service layer for menstrual cycle tracking with local storage and prediction logic.
//

import Foundation
import UserNotifications

// MARK: - Protocol

protocol MenstrualCycleServiceProtocol {
    // Cycles
    func loadCycles() -> [MenstrualCycle]
    func saveCycle(_ cycle: MenstrualCycle) async throws
    func updateCycle(_ cycle: MenstrualCycle) async throws
    func deleteCycle(id: UUID) async throws
    func getActiveCycle() -> MenstrualCycle?
    
    // Daily Logs
    func loadDailyLogs(for month: Date) -> [MenstrualDailyLog]
    func loadDailyLog(for date: Date) -> MenstrualDailyLog?
    func saveDailyLog(_ log: MenstrualDailyLog) async throws
    func deleteDailyLog(id: UUID) async throws
    
    // Settings
    func loadSettings() -> MenstrualSettings
    func saveSettings(_ settings: MenstrualSettings) async throws
    
    // Predictions
    func calculatePrediction(from cycles: [MenstrualCycle], settings: MenstrualSettings) -> CyclePrediction?
    func calculateStatistics(from cycles: [MenstrualCycle], logs: [MenstrualDailyLog]) -> CycleStatistics?
    func getCurrentPhase(from cycles: [MenstrualCycle], settings: MenstrualSettings) -> (phase: CyclePhase, dayOfCycle: Int)
    
    // Calendar
    func getCalendarData(for month: Date, cycles: [MenstrualCycle], logs: [MenstrualDailyLog], prediction: CyclePrediction?) -> [CalendarDayData]
    
    // Sync
    func getUnsyncedCycles() -> [MenstrualCycle]
    func markCyclesAsSynced(ids: [UUID])
    
    // Notifications
    func schedulePeriodReminder(for prediction: CyclePrediction, daysBefore: Int) async
    func scheduleOvulationReminder(for prediction: CyclePrediction) async
}

// MARK: - Implementation

@MainActor
final class MenstrualCycleService: MenstrualCycleServiceProtocol {
    
    static let shared = MenstrualCycleService()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let cyclesKey = "menstrual_cycles_v1"
    private let dailyLogsKey = "menstrual_daily_logs_v1"
    private let settingsKey = "menstrual_settings_v1"
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Cycles
    
    func loadCycles() -> [MenstrualCycle] {
        guard let data = userDefaults.data(forKey: cyclesKey) else {
            return []
        }
        
        do {
            let cycles = try JSONDecoder().decode([MenstrualCycle].self, from: data)
            return cycles.sorted { $0.startDate > $1.startDate }
        } catch {
            print("🩸 MenstrualService: Failed to decode cycles - \(error.localizedDescription)")
            return []
        }
    }
    
    func saveCycle(_ cycle: MenstrualCycle) async throws {
        var cycles = loadCycles()
        
        // Check for duplicates
        if let index = cycles.firstIndex(where: { $0.id == cycle.id }) {
            cycles[index] = cycle
        } else {
            cycles.append(cycle)
        }
        
        // Calculate cycle length from previous cycle
        if cycles.count > 1 {
            cycles.sort { $0.startDate > $1.startDate }
            for i in 0..<(cycles.count - 1) {
                let nextCycle = cycles[i + 1]
                let currentCycle = cycles[i]
                let daysBetween = Calendar.current.dateComponents([.day], from: nextCycle.startDate, to: currentCycle.startDate).day
                cycles[i + 1].cycleLength = daysBetween
            }
        }
        
        try saveCyclesToStorage(cycles)
        print("🩸 MenstrualService: Saved cycle starting \(cycle.startDate)")
    }
    
    func updateCycle(_ cycle: MenstrualCycle) async throws {
        var cycles = loadCycles()
        
        guard let index = cycles.firstIndex(where: { $0.id == cycle.id }) else {
            throw MenstrualCycleError.invalidData("Cycle not found")
        }
        
        var updatedCycle = cycle
        updatedCycle.updatedAt = Date()
        cycles[index] = updatedCycle
        
        try saveCyclesToStorage(cycles)
        print("🩸 MenstrualService: Updated cycle")
    }
    
    func deleteCycle(id: UUID) async throws {
        var cycles = loadCycles()
        cycles.removeAll { $0.id == id }
        try saveCyclesToStorage(cycles)
        print("🩸 MenstrualService: Deleted cycle")
    }
    
    func getActiveCycle() -> MenstrualCycle? {
        let cycles = loadCycles()
        return cycles.first { $0.isOngoing }
    }
    
    // MARK: - Daily Logs
    
    func loadDailyLogs(for month: Date) -> [MenstrualDailyLog] {
        let allLogs = loadAllDailyLogs()
        let calendar = Calendar.current
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }
        
        return allLogs.filter { log in
            log.logDate >= monthStart && log.logDate < monthEnd
        }
    }
    
    func loadDailyLog(for date: Date) -> MenstrualDailyLog? {
        let allLogs = loadAllDailyLogs()
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return allLogs.first { log in
            calendar.startOfDay(for: log.logDate) == targetDay
        }
    }
    
    func saveDailyLog(_ log: MenstrualDailyLog) async throws {
        var logs = loadAllDailyLogs()
        let calendar = Calendar.current
        let logDay = calendar.startOfDay(for: log.logDate)
        
        // Replace existing log for the same day or add new
        if let index = logs.firstIndex(where: { calendar.startOfDay(for: $0.logDate) == logDay }) {
            var updatedLog = log
            updatedLog.updatedAt = Date()
            logs[index] = updatedLog
        } else {
            logs.append(log)
        }
        
        try saveDailyLogsToStorage(logs)
        
        // Auto-create or update cycle if flow is logged
        if let flowLevel = log.flowLevel, flowLevel.isPeriod {
            await autoUpdateCycleFromLog(log)
        }
        
        print("🩸 MenstrualService: Saved daily log for \(log.logDate)")
    }
    
    func deleteDailyLog(id: UUID) async throws {
        var logs = loadAllDailyLogs()
        logs.removeAll { $0.id == id }
        try saveDailyLogsToStorage(logs)
        print("🩸 MenstrualService: Deleted daily log")
    }
    
    private func loadAllDailyLogs() -> [MenstrualDailyLog] {
        guard let data = userDefaults.data(forKey: dailyLogsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([MenstrualDailyLog].self, from: data)
        } catch {
            print("🩸 MenstrualService: Failed to decode daily logs - \(error.localizedDescription)")
            return []
        }
    }
    
    private func autoUpdateCycleFromLog(_ log: MenstrualDailyLog) async {
        guard let flowLevel = log.flowLevel, flowLevel.isPeriod else { return }
        
        var cycles = loadCycles()
        let calendar = Calendar.current
        let logDay = calendar.startOfDay(for: log.logDate)
        
        // Check if this date belongs to an existing cycle
        for (index, cycle) in cycles.enumerated() {
            let cycleStart = calendar.startOfDay(for: cycle.startDate)
            let cycleEnd = cycle.endDate.map { calendar.startOfDay(for: $0) }
            
            // If within existing cycle range (within 10 days from start)
            let daysSinceStart = calendar.dateComponents([.day], from: cycleStart, to: logDay).day ?? 0
            if daysSinceStart >= 0 && daysSinceStart <= 10 {
                // Update end date if this log is after current end
                if cycleEnd == nil || logDay > cycleEnd! {
                    cycles[index].endDate = log.logDate
                    cycles[index].periodLength = daysSinceStart + 1
                    try? saveCyclesToStorage(cycles)
                }
                return
            }
        }
        
        // If no matching cycle, and this is a new period start
        // Check if there's no recent period (within last 20 days)
        let recentCycle = cycles.first { cycle in
            let daysSince = calendar.dateComponents([.day], from: cycle.startDate, to: logDay).day ?? 0
            return daysSince >= 0 && daysSince <= 20
        }
        
        if recentCycle == nil {
            // Create new cycle
            let newCycle = MenstrualCycle(
                startDate: log.logDate,
                isPredicted: false
            )
            cycles.append(newCycle)
            try? saveCyclesToStorage(cycles)
            print("🩸 MenstrualService: Auto-created new cycle from log")
        }
    }
    
    // MARK: - Settings
    
    func loadSettings() -> MenstrualSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return MenstrualSettings()
        }
        
        do {
            return try JSONDecoder().decode(MenstrualSettings.self, from: data)
        } catch {
            print("🩸 MenstrualService: Failed to decode settings - \(error.localizedDescription)")
            return MenstrualSettings()
        }
    }
    
    func saveSettings(_ settings: MenstrualSettings) async throws {
        var updatedSettings = settings
        updatedSettings.lastUpdated = Date()
        
        let data = try JSONEncoder().encode(updatedSettings)
        userDefaults.set(data, forKey: settingsKey)
        print("🩸 MenstrualService: Saved settings")
    }
    
    // MARK: - Predictions
    
    func calculatePrediction(from cycles: [MenstrualCycle], settings: MenstrualSettings) -> CyclePrediction? {
        // Need at least 1 cycle for predictions
        guard let lastCycle = cycles.first(where: { !$0.isPredicted }) else {
            return nil
        }
        
        let calendar = Calendar.current
        
        // Calculate average cycle length from history or use settings
        let validCycles = cycles.filter { !$0.isPredicted && $0.cycleLength != nil }
        let avgCycleLength: Int
        
        if validCycles.count >= 3 {
            let total = validCycles.prefix(6).compactMap { $0.cycleLength }.reduce(0, +)
            avgCycleLength = total / min(validCycles.count, 6)
        } else {
            avgCycleLength = settings.averageCycleLength
        }
        
        // Calculate average period length
        let avgPeriodLength: Int
        let periodsWithLength = cycles.filter { !$0.isPredicted && $0.periodLength != nil }
        if periodsWithLength.count >= 2 {
            let total = periodsWithLength.prefix(6).compactMap { $0.periodLength }.reduce(0, +)
            avgPeriodLength = total / min(periodsWithLength.count, 6)
        } else {
            avgPeriodLength = settings.averagePeriodLength
        }
        
        // Calculate next period start
        guard let nextPeriodStart = calendar.date(byAdding: .day, value: avgCycleLength, to: lastCycle.startDate) else {
            return nil
        }
        
        guard let nextPeriodEnd = calendar.date(byAdding: .day, value: avgPeriodLength - 1, to: nextPeriodStart) else {
            return nil
        }
        
        // Calculate ovulation (typically 14 days before next period)
        let lutealLength = settings.lutealPhaseLength
        guard let ovulationDate = calendar.date(byAdding: .day, value: -lutealLength, to: nextPeriodStart) else {
            return nil
        }
        
        // Fertile window: 5 days before ovulation to 1 day after
        guard let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulationDate),
              let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulationDate) else {
            return nil
        }
        
        // PMS: typically 7 days before period
        guard let pmsStart = calendar.date(byAdding: .day, value: -7, to: nextPeriodStart) else {
            return nil
        }
        
        // Calculate confidence based on cycle regularity
        let confidence: Double
        if validCycles.count >= 6 {
            let lengths = validCycles.prefix(6).compactMap { $0.cycleLength }
            let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
            let variance = lengths.map { pow(Double($0) - avg, 2) }.reduce(0, +) / Double(lengths.count)
            let stdDev = sqrt(variance)
            
            // Higher standard deviation = lower confidence
            confidence = max(0.4, min(0.95, 1.0 - (stdDev / 10.0)))
        } else if validCycles.count >= 3 {
            confidence = 0.7
        } else {
            confidence = 0.5
        }
        
        return CyclePrediction(
            nextPeriodStart: nextPeriodStart,
            nextPeriodEnd: nextPeriodEnd,
            ovulationDate: ovulationDate,
            fertileWindowStart: fertileStart,
            fertileWindowEnd: fertileEnd,
            pmsStart: pmsStart,
            confidence: confidence
        )
    }
    
    func calculateStatistics(from cycles: [MenstrualCycle], logs: [MenstrualDailyLog]) -> CycleStatistics? {
        let validCycles = cycles.filter { !$0.isPredicted && $0.cycleLength != nil }
        
        guard validCycles.count >= 2 else { return nil }
        
        let cycleLengths = validCycles.compactMap { $0.cycleLength }
        let periodLengths = validCycles.compactMap { $0.periodLength }
        
        let avgCycleLength = Double(cycleLengths.reduce(0, +)) / Double(cycleLengths.count)
        let avgPeriodLength = periodLengths.isEmpty ? 5.0 : Double(periodLengths.reduce(0, +)) / Double(periodLengths.count)
        
        let shortestCycle = cycleLengths.min() ?? 21
        let longestCycle = cycleLengths.max() ?? 35
        
        // Calculate standard deviation
        let variance = cycleLengths.map { pow(Double($0) - avgCycleLength, 2) }.reduce(0, +) / Double(cycleLengths.count)
        let cycleVariation = sqrt(variance)
        
        // Find most common symptoms
        var symptomCounts: [SymptomType: Int] = [:]
        for log in logs {
            for symptom in log.symptoms {
                symptomCounts[symptom.symptomType, default: 0] += 1
            }
        }
        let sortedSymptoms = symptomCounts.sorted { $0.value > $1.value }
        let topSymptoms = Array(sortedSymptoms.prefix(5).map { $0.key })
        
        // Calculate average pain level
        let painLevels = logs.compactMap { $0.painLevel }
        let avgPainLevel = painLevels.isEmpty ? nil : Double(painLevels.reduce(0, +)) / Double(painLevels.count)
        
        return CycleStatistics(
            averageCycleLength: avgCycleLength,
            averagePeriodLength: avgPeriodLength,
            shortestCycle: shortestCycle,
            longestCycle: longestCycle,
            cycleVariation: cycleVariation,
            totalCyclesTracked: validCycles.count,
            mostCommonSymptoms: topSymptoms,
            averagePainLevel: avgPainLevel
        )
    }
    
    func getCurrentPhase(from cycles: [MenstrualCycle], settings: MenstrualSettings) -> (phase: CyclePhase, dayOfCycle: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Find the most recent non-predicted cycle
        guard let lastCycle = cycles.first(where: { !$0.isPredicted }) else {
            return (.unknown, 0)
        }
        
        let cycleStart = calendar.startOfDay(for: lastCycle.startDate)
        let dayOfCycle = (calendar.dateComponents([.day], from: cycleStart, to: today).day ?? 0) + 1
        
        // If we're past the expected cycle length, might be in next cycle
        let avgCycleLength = settings.averageCycleLength
        if dayOfCycle > avgCycleLength + 7 {
            return (.unknown, dayOfCycle)
        }
        
        // Determine phase
        let periodLength = lastCycle.periodLength ?? settings.averagePeriodLength
        let lutealLength = settings.lutealPhaseLength
        let ovulationDay = avgCycleLength - lutealLength
        
        if dayOfCycle <= periodLength {
            return (.menstrual, dayOfCycle)
        } else if dayOfCycle < ovulationDay - 2 {
            return (.follicular, dayOfCycle)
        } else if dayOfCycle >= ovulationDay - 2 && dayOfCycle <= ovulationDay + 1 {
            return (.ovulation, dayOfCycle)
        } else if dayOfCycle > avgCycleLength - 7 {
            return (.pms, dayOfCycle)
        } else {
            return (.luteal, dayOfCycle)
        }
    }
    
    // MARK: - Calendar
    
    func getCalendarData(for month: Date, cycles: [MenstrualCycle], logs: [MenstrualDailyLog], prediction: CyclePrediction?) -> [CalendarDayData] {
        let calendar = Calendar.current
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }
        
        var calendarData: [CalendarDayData] = []
        var currentDate = monthStart
        
        while currentDate < monthEnd {
            let dayData = createDayData(
                for: currentDate,
                cycles: cycles,
                logs: logs,
                prediction: prediction
            )
            calendarData.append(dayData)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? monthEnd
        }
        
        return calendarData
    }
    
    private func createDayData(for date: Date, cycles: [MenstrualCycle], logs: [MenstrualDailyLog], prediction: CyclePrediction?) -> CalendarDayData {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        var isPeriodDay = false
        var isPredictedPeriod = false
        var flowLevel: FlowLevel?
        
        // Check actual cycles
        for cycle in cycles where !cycle.isPredicted {
            let cycleStart = calendar.startOfDay(for: cycle.startDate)
            let cycleEnd = cycle.endDate.map { calendar.startOfDay(for: $0) }
            
            if targetDay >= cycleStart {
                if let end = cycleEnd {
                    if targetDay <= end {
                        isPeriodDay = true
                        break
                    }
                } else {
                    // Ongoing cycle - check if within reasonable period length (max 10 days)
                    let daysSince = calendar.dateComponents([.day], from: cycleStart, to: targetDay).day ?? 0
                    if daysSince <= 10 {
                        isPeriodDay = true
                        break
                    }
                }
            }
        }
        
        // Check predicted period
        if let prediction = prediction {
            let predStart = calendar.startOfDay(for: prediction.nextPeriodStart)
            let predEnd = calendar.startOfDay(for: prediction.nextPeriodEnd)
            if targetDay >= predStart && targetDay <= predEnd {
                isPredictedPeriod = true
            }
        }
        
        // Check for daily log
        let dayLog = logs.first { calendar.startOfDay(for: $0.logDate) == targetDay }
        if let log = dayLog {
            flowLevel = log.flowLevel
            if flowLevel?.isPeriod == true {
                isPeriodDay = true
            }
        }
        
        // Check ovulation and fertile window
        var isOvulationDay = false
        var isFertileDay = false
        var isPmsDay = false
        
        if let prediction = prediction {
            let ovDay = calendar.startOfDay(for: prediction.ovulationDate)
            let fertileStart = calendar.startOfDay(for: prediction.fertileWindowStart)
            let fertileEnd = calendar.startOfDay(for: prediction.fertileWindowEnd)
            let pmsStart = calendar.startOfDay(for: prediction.pmsStart)
            let periodStart = calendar.startOfDay(for: prediction.nextPeriodStart)
            
            isOvulationDay = targetDay == ovDay
            isFertileDay = targetDay >= fertileStart && targetDay <= fertileEnd
            isPmsDay = targetDay >= pmsStart && targetDay < periodStart
        }
        
        return CalendarDayData(
            date: date,
            isPeriodDay: isPeriodDay,
            isPredictedPeriod: isPredictedPeriod && !isPeriodDay,
            isOvulationDay: isOvulationDay,
            isFertileDay: isFertileDay && !isPeriodDay && !isPredictedPeriod,
            isPmsDay: isPmsDay && !isPeriodDay && !isPredictedPeriod && !isFertileDay,
            flowLevel: flowLevel,
            hasLog: dayLog != nil,
            log: dayLog
        )
    }
    
    // MARK: - Storage Helpers
    
    private func saveCyclesToStorage(_ cycles: [MenstrualCycle]) throws {
        let data = try JSONEncoder().encode(cycles)
        userDefaults.set(data, forKey: cyclesKey)
    }
    
    private func saveDailyLogsToStorage(_ logs: [MenstrualDailyLog]) throws {
        let data = try JSONEncoder().encode(logs)
        userDefaults.set(data, forKey: dailyLogsKey)
    }
    
    // MARK: - Notifications
    
    func schedulePeriodReminder(for prediction: CyclePrediction, daysBefore: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Period Reminder"
        content.body = "Your period is expected in \(daysBefore) days. Be prepared!"
        content.sound = .default
        content.categoryIdentifier = "MENSTRUAL_REMINDER"
        
        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: prediction.nextPeriodStart) else {
            return
        }
        
        // Don't schedule if reminder date is in the past
        if reminderDate < Date() { return }
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "period_reminder_\(prediction.nextPeriodStart.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🩸 MenstrualService: Scheduled period reminder")
        } catch {
            print("🩸 MenstrualService: Failed to schedule reminder - \(error.localizedDescription)")
        }
    }
    
    func scheduleOvulationReminder(for prediction: CyclePrediction) async {
        let content = UNMutableNotificationContent()
        content.title = "Ovulation Day"
        content.body = "Today is your predicted ovulation day. Peak fertility!"
        content.sound = .default
        content.categoryIdentifier = "MENSTRUAL_REMINDER"
        
        let calendar = Calendar.current
        
        // Don't schedule if ovulation date is in the past
        if prediction.ovulationDate < Date() { return }
        
        var components = calendar.dateComponents([.year, .month, .day], from: prediction.ovulationDate)
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "ovulation_reminder_\(prediction.ovulationDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🩸 MenstrualService: Scheduled ovulation reminder")
        } catch {
            print("🩸 MenstrualService: Failed to schedule ovulation reminder - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Unsynced Data
    
    func getUnsyncedCycles() -> [MenstrualCycle] {
        loadCycles().filter { $0.syncedAt == nil }
    }
    
    func markCyclesAsSynced(ids: [UUID]) {
        var cycles = loadCycles()
        let now = Date()
        
        for i in cycles.indices {
            if ids.contains(cycles[i].id) {
                cycles[i].syncedAt = now
            }
        }
        
        try? saveCyclesToStorage(cycles)
    }
}

// MARK: - Cycle Calculator

struct CycleCalculator {
    
    /// Calculate cycle length between two period start dates
    static func cycleLengthBetween(start1: Date, start2: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: start1, to: start2).day ?? 0
    }
    
    /// Calculate period length from start to end date
    static func periodLength(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }
    
    /// Check if a date falls within a fertile window
    static func isFertile(date: Date, ovulationDate: Date) -> Bool {
        let calendar = Calendar.current
        guard let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulationDate),
              let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulationDate) else {
            return false
        }
        
        let targetDay = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: fertileStart)
        let end = calendar.startOfDay(for: fertileEnd)
        
        return targetDay >= start && targetDay <= end
    }
    
    /// Estimate ovulation date based on cycle length and luteal phase
    static func estimateOvulationDate(lastPeriodStart: Date, cycleLength: Int, lutealPhaseLength: Int = 14) -> Date {
        let calendar = Calendar.current
        let ovulationDay = cycleLength - lutealPhaseLength
        return calendar.date(byAdding: .day, value: ovulationDay, to: lastPeriodStart) ?? lastPeriodStart
    }
}
