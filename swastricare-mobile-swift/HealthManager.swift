//
//  HealthManager.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthManager: ObservableObject {
    static let shared = HealthManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var stepCount: Int = 0
    @Published var heartRate: Int = 0
    @Published var sleepHours: String = "0h 0m"
    @Published var isAuthorized: Bool = false
    @Published var authorizationError: String?
    @Published var hasRequestedAuthorization: Bool = false
    
    // Additional metrics
    @Published var activeCalories: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var standHours: Int = 0
    @Published var distance: Double = 0.0 // in kilometers
    @Published var bloodPressure: String = "--/--"
    @Published var weight: String = "--"
    
    // Historical data
    @Published var weeklySteps: [DailyMetric] = []
    @Published var selectedDate: Date = Date()
    
    private init() {
        // Load persisted authorization request status
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: "hasRequestedHealthAuthorization")
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "Health data is not available on this device"
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            
            // Mark that we've requested authorization
            hasRequestedAuthorization = true
            UserDefaults.standard.set(true, forKey: "hasRequestedHealthAuthorization")
            
            isAuthorized = true
            authorizationError = nil
            
            // Fetch initial data after authorization
            await fetchAllHealthData()
        } catch {
            authorizationError = "Failed to authorize HealthKit: \(error.localizedDescription)"
            isAuthorized = false
            
            // Still mark as requested even if there was an error
            hasRequestedAuthorization = true
            UserDefaults.standard.set(true, forKey: "hasRequestedHealthAuthorization")
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        
        // Check if we have authorization for step count (as a proxy for all types)
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let status = healthStore.authorizationStatus(for: stepType)
        isAuthorized = (status == .sharingAuthorized)
    }
    
    // MARK: - Fetch Health Data
    
    func fetchAllHealthData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchStepCount() }
            group.addTask { await self.fetchHeartRate() }
            group.addTask { await self.fetchSleepData() }
            group.addTask { await self.fetchActiveCalories() }
            group.addTask { await self.fetchExerciseMinutes() }
            group.addTask { await self.fetchStandHours() }
            group.addTask { await self.fetchStandHours() }
            group.addTask { await self.fetchDistance() }
            group.addTask { await self.fetchBloodPressure() }
            group.addTask { await self.fetchWeight() }
        }
    }
    
    func fetchAllHealthDataForDate(_ date: Date) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchStepCount(for: date) }
            group.addTask { await self.fetchHeartRate(for: date) }
            group.addTask { await self.fetchSleepData(for: date) }
            group.addTask { await self.fetchActiveCalories(for: date) }
            group.addTask { await self.fetchExerciseMinutes(for: date) }
            group.addTask { await self.fetchStandHours(for: date) }
            group.addTask { await self.fetchStandHours(for: date) }
            group.addTask { await self.fetchDistance(for: date) }
            // BP and Weight are usually sparse, so we fetch latest generally, or could be specific
            // keeping simple for now by just refreshing latest
            group.addTask { await self.fetchBloodPressure() }
            group.addTask { await self.fetchWeight() }
        }
    }
    
    func fetchWeeklySteps() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var metrics: [DailyMetric] = []
        
        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let steps = await fetchStepCountForDate(date)
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                metrics.append(DailyMetric(date: date, dayName: dayName, steps: steps))
            }
        }
        
        await MainActor.run {
            self.weeklySteps = metrics
        }
    }
    
    // MARK: - Step Count
    
    func fetchStepCount() async {
        await fetchStepCount(for: Date())
    }
    
    func fetchStepCount(for date: Date) async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                Task { @MainActor in
                    self.stepCount = 0
                }
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            Task { @MainActor in
                self.stepCount = steps
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchStepCountForDate(_ date: Date) async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Heart Rate
    
    func fetchHeartRate() async {
        await fetchHeartRate(for: Date())
    }
    
    func fetchHeartRate(for date: Date) async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                Task { @MainActor in
                    self.heartRate = 0
                }
                return
            }
            
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            Task { @MainActor in
                self.heartRate = bpm
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Sleep Data
    
    func fetchSleepData() async {
        await fetchSleepData(for: Date())
    }
    
    func fetchSleepData(for date: Date) async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }
        
        let calendar = Calendar.current
        
        // Get sleep data from the night before the selected date
        let startDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        let endDate = calendar.startOfDay(for: date)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                Task { @MainActor in
                    self.sleepHours = "0h 0m"
                }
                return
            }
            
            // Calculate total sleep duration
            var totalSleepSeconds: TimeInterval = 0
            
            for sample in samples {
                // Only count "asleep" samples (not awake or in bed)
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }
            
            let hours = Int(totalSleepSeconds / 3600)
            let minutes = Int((totalSleepSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
            
            Task { @MainActor in
                self.sleepHours = "\(hours)h \(minutes)m"
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Active Calories
    
    func fetchActiveCalories() async {
        await fetchActiveCalories(for: Date())
    }
    
    func fetchActiveCalories(for date: Date) async {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: calorieType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                Task { @MainActor in
                    self.activeCalories = 0
                }
                return
            }
            
            let calories = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
            Task { @MainActor in
                self.activeCalories = calories
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Exercise Minutes
    
    func fetchExerciseMinutes() async {
        await fetchExerciseMinutes(for: Date())
    }
    
    func fetchExerciseMinutes(for date: Date) async {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: exerciseType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                Task { @MainActor in
                    self.exerciseMinutes = 0
                }
                return
            }
            
            let minutes = Int(sum.doubleValue(for: HKUnit.minute()))
            Task { @MainActor in
                self.exerciseMinutes = minutes
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Stand Hours
    
    func fetchStandHours() async {
        await fetchStandHours(for: Date())
    }
    
    func fetchStandHours(for date: Date) async {
        guard let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: standType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                Task { @MainActor in
                    self.standHours = 0
                }
                return
            }
            
            let hours = Int(sum.doubleValue(for: HKUnit.hour()))
            Task { @MainActor in
                self.standHours = hours
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Distance
    
    func fetchDistance() async {
        await fetchDistance(for: Date())
    }
    
    func fetchDistance(for date: Date) async {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: distanceType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                Task { @MainActor in
                    self.distance = 0.0
                }
                return
            }
            
            let km = sum.doubleValue(for: HKUnit.meterUnit(with: .kilo))
            Task { @MainActor in
                self.distance = km
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Blood Pressure
    
    func fetchBloodPressure() async {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        
        // We need both, so let's try to get them correlatively or just latest of each
        // For simplicity in this demo, fetching latest single samples
        
        async let systolic = fetchLatestSample(for: systolicType)
        async let diastolic = fetchLatestSample(for: diastolicType)
        
        let (sys, dia) = await (systolic, diastolic)
        
        Task { @MainActor in
            if let sysVal = sys, let diaVal = dia {
                let s = Int(sysVal.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                let d = Int(diaVal.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                self.bloodPressure = "\(s)/\(d)"
            } else {
                self.bloodPressure = "--/--"
            }
        }
    }
    
    // MARK: - Weight
    
    func fetchWeight() async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        if let sample = await fetchLatestSample(for: weightType) {
            let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            Task { @MainActor in
                self.weight = String(format: "%.1f", kg)
            }
        }
    }
    
    private func fetchLatestSample(for sampleType: HKSampleType) async -> HKQuantitySample? {
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Helper Methods
    
    func getHealthMetrics() -> HealthMetrics {
        return HealthMetrics(
            steps: stepCount,
            heartRate: heartRate,
            sleep: sleepHours,
            timestamp: Date()
        )
    }
}

// MARK: - Data Models

struct HealthMetrics: Codable {
    let steps: Int
    let heartRate: Int
    let sleep: String
    let timestamp: Date
}

struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let dayName: String
    let steps: Int
}
