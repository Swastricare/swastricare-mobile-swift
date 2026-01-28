//
//  HealthKitService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles all HealthKit interactions
//

import Foundation
import HealthKit
internal import _LocationEssentials

// MARK: - HealthKit Service Protocol

protocol HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws
    func fetchHealthMetrics(for date: Date) async -> HealthMetrics
    func fetchHealthMetricsHistory(days: Int) async -> [HealthMetrics]
    func fetchWeeklySteps() async -> [DailyMetric]
    func fetchStepCount(for date: Date) async -> Int
    
    // Hydration-related methods
    func fetchUserWeight() async -> Double?
    func fetchDailyWaterIntake(for date: Date) async -> Double
    func writeWaterIntake(amountMl: Double, date: Date) async throws
    func fetchExerciseMinutesValue(for date: Date) async -> Int
    
    // Heart rate methods
    func saveHeartRate(bpm: Int, date: Date) async throws
    func requestHeartRateWriteAuthorization() async throws
    
    // Workout/Activity methods
    func fetchWalkingRunningWorkouts(startDate: Date, endDate: Date) async -> [HealthKitWorkout]
    func fetchWorkoutRoute(workout: HKWorkout) async -> [WorkoutRoutePoint]
    func fetchDailyActivitySummary(for date: Date) async -> DailyActivityData
    func fetchWorkoutHeartRate(workout: HKWorkout) async -> (avg: Int?, max: Int?, min: Int?)
    
    // Workout saving methods
    func requestWorkoutAuthorization() async throws
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        distance: Double,
        calories: Double,
        routeLocations: [CLLocation]
    ) async throws -> HKWorkout
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
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute()
    ]
    
    private let typesToShare: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.workoutType(),
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSeriesType.workoutRoute()
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
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
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
            timestamp: date
        )
    }
    
    func fetchHealthMetricsHistory(days: Int) async -> [HealthMetrics] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var history: [HealthMetrics] = []
        
        // Fetch last N days including today
        for dayOffset in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let metrics = await fetchHealthMetrics(for: date)
                history.append(metrics)
            }
        }
        
        return history
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
        // Get sleep data for the sleep session ending on the selected date (Noon Yesterday to Noon Today)
        let startOfDay = calendar.startOfDay(for: date)
        let startDate = calendar.date(byAdding: .hour, value: -12, to: startOfDay)! // Yesterday 12:00 PM
        let endDate = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!   // Today 12:00 PM
        
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
    
    // MARK: - Hydration Methods
    
    /// Fetches the user's latest weight in kg from HealthKit
    func fetchUserWeight() async -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        
        if let sample = await fetchLatestSample(for: weightType) {
            return sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
        }
        return nil
    }
    
    /// Fetches total water intake for a specific date in ml
    func fetchDailyWaterIntake(for date: Date) async -> Double {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return 0
        }
        
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                // HealthKit stores water in liters, convert to ml
                let liters = result?.sumQuantity()?.doubleValue(for: .liter()) ?? 0
                continuation.resume(returning: liters * 1000)
            }
            healthStore.execute(query)
        }
    }
    
    /// Writes water intake to HealthKit
    func writeWaterIntake(amountMl: Double, date: Date) async throws {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitError.fetchFailed
        }
        
        // Convert ml to liters for HealthKit
        let liters = amountMl / 1000.0
        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        
        try await healthStore.save(sample)
    }
    
    /// Fetches exercise minutes for a specific date (public method for hydration adjustments)
    func fetchExerciseMinutesValue(for date: Date) async -> Int {
        return await fetchExerciseMinutes(for: date)
    }
    
    // MARK: - Heart Rate Methods
    
    /// Saves a heart rate measurement to HealthKit
    func saveHeartRate(bpm: Int, date: Date) async throws {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.writeFailed
        }
        
        // Create quantity (beats per minute)
        let quantity = HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: Double(bpm))
        
        // Create sample
        let sample = HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: date,
            end: date
        )
        
        // Save to HealthKit
        try await healthStore.save(sample)
    }
    
    /// Requests authorization specifically for writing heart rate data
    func requestHeartRateWriteAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.writeFailed
        }
        
        try await healthStore.requestAuthorization(toShare: [heartRateType], read: [heartRateType])
    }
    
    // MARK: - Workout/Activity Methods
    
    /// Fetches walking and running workouts within a date range
    func fetchWalkingRunningWorkouts(startDate: Date, endDate: Date) async -> [HealthKitWorkout] {
        let walkingType = HKQuery.predicateForWorkouts(with: .walking)
        let runningType = HKQuery.predicateForWorkouts(with: .running)
        let hikingType = HKQuery.predicateForWorkouts(with: .hiking)
        
        let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [walkingType, runningType, hikingType])
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [typePredicate, datePredicate])
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: combinedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                let healthKitWorkouts = workouts.map { workout -> HealthKitWorkout in
                    let activityType: String
                    switch workout.workoutActivityType {
                    case .walking: activityType = "walk"
                    case .running: activityType = "run"
                    case .hiking: activityType = "hike"
                    default: activityType = "walk"
                    }
                    
                    return HealthKitWorkout(
                        id: workout.uuid,
                        workout: workout,
                        activityType: activityType,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                        totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                        averageHeartRate: nil,
                        route: []
                    )
                }
                
                continuation.resume(returning: healthKitWorkouts)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches route data for a specific workout
    func fetchWorkoutRoute(workout: HKWorkout) async -> [WorkoutRoutePoint] {
        return await withCheckedContinuation { continuation in
            let routeType = HKSeriesType.workoutRoute()
            let predicate = HKQuery.predicateForObjects(from: workout)
            
            let routeQuery = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, error in
                guard let routes = samples as? [HKWorkoutRoute], let firstRoute = routes.first else {
                    continuation.resume(returning: [])
                    return
                }
                
                self?.fetchRoutePoints(from: firstRoute) { points in
                    continuation.resume(returning: points)
                }
            }
            healthStore.execute(routeQuery)
        }
    }
    
    private func fetchRoutePoints(from route: HKWorkoutRoute, completion: @escaping ([WorkoutRoutePoint]) -> Void) {
        var allPoints: [WorkoutRoutePoint] = []
        
        let routeDataQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
            guard let locations = locations, error == nil else {
                if done {
                    completion(allPoints)
                }
                return
            }
            
            let points = locations.map { location -> WorkoutRoutePoint in
                WorkoutRoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    timestamp: location.timestamp,
                    speed: location.speed >= 0 ? location.speed : nil,
                    horizontalAccuracy: location.horizontalAccuracy
                )
            }
            
            allPoints.append(contentsOf: points)
            
            if done {
                completion(allPoints)
            }
        }
        
        healthStore.execute(routeDataQuery)
    }
    
    /// Fetches daily activity summary including steps, distance, and calories
    func fetchDailyActivitySummary(for date: Date) async -> DailyActivityData {
        async let steps = fetchStepCount(for: date)
        async let distance = fetchDistance(for: date)
        async let calories = fetchActiveCalories(for: date)
        async let heartRate = fetchHeartRate(for: date)
        
        return await DailyActivityData(
            date: date,
            steps: steps,
            distanceMeters: distance * 1000, // Convert km to meters
            calories: calories,
            averageHeartRate: heartRate > 0 ? heartRate : nil,
            activityCount: 0
        )
    }
    
    /// Fetches heart rate samples during a workout
    func fetchWorkoutHeartRate(workout: HKWorkout) async -> (avg: Int?, max: Int?, min: Int?) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }
                
                let heartRates = samples.map { 
                    $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
                
                let avg = Int(heartRates.reduce(0, +) / Double(heartRates.count))
                let max = Int(heartRates.max() ?? 0)
                let min = Int(heartRates.min() ?? 0)
                
                continuation.resume(returning: (avg, max, min))
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches detailed heart rate samples during a workout for graphing
    /// Returns individual HR samples with timestamps for analytics visualization
    func fetchWorkoutHeartRateSamples(workout: HKWorkout) async -> [RunHeartRateSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    if let error = error {
                        print("⚠️ Error fetching HR samples: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: [])
                    return
                }
                
                let heartRateSamples = samples.map { sample -> RunHeartRateSample in
                    let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                    return RunHeartRateSample(
                        bpm: bpm,
                        timestamp: sample.startDate,
                        distanceKm: nil // Distance will be correlated separately if needed
                    )
                }
                
                // Downsample if too many samples (keep reasonable amount for charting)
                let downsampledSamples: [RunHeartRateSample]
                if heartRateSamples.count > 200 {
                    downsampledSamples = self.downsampleRunHeartRateSamples(heartRateSamples, to: 200)
                } else {
                    downsampledSamples = heartRateSamples
                }
                
                continuation.resume(returning: downsampledSamples)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches heart rate samples for a specific time range (not tied to a workout)
    func fetchRunHeartRateSamples(startDate: Date, endDate: Date) async -> [RunHeartRateSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }
                
                let heartRateSamples = samples.map { sample -> RunHeartRateSample in
                    let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                    return RunHeartRateSample(
                        bpm: bpm,
                        timestamp: sample.startDate,
                        distanceKm: nil
                    )
                }
                
                continuation.resume(returning: heartRateSamples)
            }
            healthStore.execute(query)
        }
    }
    
    /// Downsamples heart rate samples to a target count for efficient charting
    private func downsampleRunHeartRateSamples(_ samples: [RunHeartRateSample], to targetCount: Int) -> [RunHeartRateSample] {
        guard samples.count > targetCount else { return samples }
        
        var result: [RunHeartRateSample] = []
        result.append(samples[0]) // Always keep first
        
        let bucketSize = (samples.count - 2) / (targetCount - 2)
        
        for i in 0..<(targetCount - 2) {
            let bucketStart = i * bucketSize + 1
            let bucketEnd = min(bucketStart + bucketSize, samples.count - 1)
            
            // Use representative sample from middle of bucket
            let midIndex = bucketStart + (bucketEnd - bucketStart) / 2
            if midIndex < samples.count {
                result.append(samples[midIndex])
            }
        }
        
        result.append(samples[samples.count - 1]) // Always keep last
        
        return result
    }
    
    // MARK: - Workout Saving Methods
    
    /// Requests authorization for saving workouts and routes
    func requestWorkoutAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKSeriesType.workoutRoute()
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKSeriesType.workoutRoute()
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    /// Saves a workout with route data to HealthKit
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        distance: Double,
        calories: Double,
        routeLocations: [CLLocation]
    ) async throws -> HKWorkout {
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        // Create workout builder
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        // Begin collection
        try await builder.beginCollection(at: startDate)
        
        // Add distance sample
        if distance > 0 {
            let distanceType: HKQuantityType
            switch activityType {
            case .cycling:
                distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
            default:
                distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            }
            
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: startDate,
                end: endDate
            )
            try await addSamplesToBuilder(builder, samples: [distanceSample])
        }
        
        // Add calories sample
        if calories > 0 {
            let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let calorieSample = HKQuantitySample(
                type: calorieType,
                quantity: calorieQuantity,
                start: startDate,
                end: endDate
            )
            try await addSamplesToBuilder(builder, samples: [calorieSample])
        }
        
        // End collection and finish workout
        try await builder.endCollection(at: endDate)
        
        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitError.writeFailed
        }
        
        // Save route if we have locations
        if !routeLocations.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            try await routeBuilder.insertRouteData(routeLocations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
        
        print("✅ Workout saved to HealthKit: \(workout.uuid)")
        return workout
    }
    
    // MARK: - Helpers
    
    /// Helper to add samples to workout builder with async/await
    private func addSamplesToBuilder(_ builder: HKWorkoutBuilder, samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.writeFailed)
                }
            }
        }
    }
    
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
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Health data is not available on this device"
        case .authorizationFailed: return "Failed to authorize HealthKit access"
        case .fetchFailed: return "Failed to fetch health data"
        case .writeFailed: return "Failed to write health data"
        }
    }
}

// MARK: - HealthKit Workout Model

struct HealthKitWorkout: Identifiable, Equatable {
    let id: UUID
    let workout: HKWorkout
    let activityType: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalDistance: Double // in meters
    let totalEnergyBurned: Double // in kcal
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var minHeartRate: Int?
    var route: [WorkoutRoutePoint]
    
    var durationSeconds: Int {
        Int(duration)
    }
    
    var distanceKm: Double {
        totalDistance / 1000.0
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    static func == (lhs: HealthKitWorkout, rhs: HealthKitWorkout) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Workout Route Point

struct WorkoutRoutePoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double?
    let horizontalAccuracy: Double
    
    var coordinate: (lat: Double, lng: Double) {
        (latitude, longitude)
    }
}

// MARK: - Daily Activity Data

struct DailyActivityData: Equatable {
    let date: Date
    let steps: Int
    let distanceMeters: Double
    let calories: Int
    let averageHeartRate: Int?
    let activityCount: Int
    
    var distanceKm: Double {
        distanceMeters / 1000.0
    }
}

