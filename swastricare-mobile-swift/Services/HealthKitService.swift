//
//  HealthKitService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles all HealthKit interactions
//

import Foundation
import HealthKit

// MARK: - HealthKit Service Protocol

protocol HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws
    func fetchHealthMetrics(for date: Date) async -> HealthMetrics
    func fetchWeeklySteps() async -> [DailyMetric]
    func fetchStepCount(for date: Date) async -> Int
}

// MARK: - HealthKit Service Implementation

final class HealthKitService: HealthKitServiceProtocol {
    
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!
    ]
    
    private init() {}
    
    // MARK: - Public Properties
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    // MARK: - Fetch All Metrics
    
    func fetchHealthMetrics(for date: Date) async -> HealthMetrics {
        async let steps = fetchStepCount(for: date)
        async let heartRate = fetchHeartRate(for: date)
        async let sleep = fetchSleepData(for: date)
        async let calories = fetchActiveCalories(for: date)
        async let exercise = fetchExerciseMinutes(for: date)
        async let stand = fetchStandHours(for: date)
        async let distance = fetchDistance(for: date)
        async let bp = fetchBloodPressure()
        async let weight = fetchWeight()
        
        return await HealthMetrics(
            steps: steps,
            heartRate: heartRate,
            sleep: sleep,
            activeCalories: calories,
            exerciseMinutes: exercise,
            standHours: stand,
            distance: distance,
            bloodPressure: bp,
            weight: weight,
            timestamp: Date()
        )
    }
    
    // MARK: - Weekly Steps
    
    func fetchWeeklySteps() async -> [DailyMetric] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var metrics: [DailyMetric] = []
        
        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let steps = await fetchStepCount(for: date)
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                metrics.append(DailyMetric(date: date, dayName: dayName, steps: steps))
            }
        }
        
        return metrics
    }
    
    // MARK: - Individual Metrics
    
    func fetchStepCount(for date: Date) async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRate(for date: Date) async -> Int {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                continuation.resume(returning: Int(bpm))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepData(for date: Date) async -> String {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return "0h 0m"
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        let endDate = calendar.startOfDay(for: date)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                var totalSeconds: TimeInterval = 0
                
                if let samples = samples as? [HKCategorySample] {
                    for sample in samples {
                        let sleepValues: [Int] = [
                            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                            HKCategoryValueSleepAnalysis.asleepREM.rawValue
                        ]
                        if sleepValues.contains(sample.value) {
                            totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                }
                
                let hours = Int(totalSeconds / 3600)
                let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
                continuation.resume(returning: "\(hours)h \(minutes)m")
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveCalories(for date: Date) async -> Int {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(calories))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchExerciseMinutes(for date: Date) async -> Int {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let minutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                continuation.resume(returning: Int(minutes))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchStandHours(for date: Date) async -> Int {
        guard let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: standType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let hours = result?.sumQuantity()?.doubleValue(for: .hour()) ?? 0
                continuation.resume(returning: Int(hours))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchDistance(for date: Date) async -> Double {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let km = result?.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo)) ?? 0
                continuation.resume(returning: km)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchBloodPressure() async -> String {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return "--/--"
        }
        
        async let systolic = fetchLatestSample(for: systolicType)
        async let diastolic = fetchLatestSample(for: diastolicType)
        
        let (sys, dia) = await (systolic, diastolic)
        
        if let sysVal = sys, let diaVal = dia {
            let s = Int(sysVal.quantity.doubleValue(for: .millimeterOfMercury()))
            let d = Int(diaVal.quantity.doubleValue(for: .millimeterOfMercury()))
            return "\(s)/\(d)"
        }
        return "--/--"
    }
    
    private func fetchWeight() async -> String {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return "--"
        }
        
        if let sample = await fetchLatestSample(for: weightType) {
            let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            return String(format: "%.1f", kg)
        }
        return "--"
    }
    
    // MARK: - Helpers
    
    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return (start, end)
    }
    
    private func fetchLatestSample(for sampleType: HKSampleType) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Health data is not available on this device"
        case .authorizationFailed: return "Failed to authorize HealthKit access"
        case .fetchFailed: return "Failed to fetch health data"
        }
    }
}

