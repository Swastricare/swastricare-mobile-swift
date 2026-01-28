//
//  RunAnalyticsService.swift
//  swastricare-mobile-swift
//
//  Service for calculating run analytics: splits, pace, heart rate zones
//

import Foundation
import CoreLocation

// MARK: - Run Analytics Service

final class RunAnalyticsService {
    
    static let shared = RunAnalyticsService()
    
    private init() {}
    
    // MARK: - Constants
    
    private let splitDistanceMeters: Double = 1000 // 1 km splits
    private let paceSampleIntervalMeters: Double = 100 // Sample pace every 100m
    private let earthRadiusMeters: Double = 6371000 // Earth's radius in meters
    
    // MARK: - Splits Calculation
    
    /// Calculate kilometer splits from route coordinates
    /// - Parameters:
    ///   - coordinates: Array of route coordinates with timestamps
    ///   - heartRateSamples: Optional heart rate samples for HR per split
    /// - Returns: Array of ActivitySplit for each kilometer
    func calculateSplits(
        from coordinates: [RouteCoordinate],
        heartRateSamples: [RunHeartRateSample] = []
    ) -> [ActivitySplit] {
        guard coordinates.count >= 2 else { return [] }
        
        var splits: [ActivitySplit] = []
        var currentSplitIndex = 1
        var accumulatedDistance: Double = 0
        var splitStartIndex = 0
        var splitStartTime: Date?
        var previousCoord: RouteCoordinate?
        var splitElevationGain: Double = 0
        var splitElevationLoss: Double = 0
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Get start time from first coordinate
        if let firstTs = coordinates.first?.ts {
            splitStartTime = isoFormatter.date(from: firstTs)
        }
        
        for (index, coord) in coordinates.enumerated() {
            if let prev = previousCoord {
                // Calculate distance between points
                let distance = haversineDistance(
                    lat1: prev.lat, lon1: prev.lng,
                    lat2: coord.lat, lon2: coord.lng
                )
                accumulatedDistance += distance
                
                // Calculate elevation change
                if let prevAlt = prev.alt, let currAlt = coord.alt {
                    let elevDiff = currAlt - prevAlt
                    if elevDiff > 0 {
                        splitElevationGain += elevDiff
                    } else {
                        splitElevationLoss += abs(elevDiff)
                    }
                }
                
                // Check if we've completed a split
                if accumulatedDistance >= splitDistanceMeters {
                    guard let startTime = splitStartTime,
                          let endTimeStr = coord.ts,
                          let endTime = isoFormatter.date(from: endTimeStr) else {
                        previousCoord = coord
                        continue
                    }
                    
                    let durationSeconds = Int(endTime.timeIntervalSince(startTime))
                    let paceSecondsPerKm = durationSeconds > 0 ? Int((Double(durationSeconds) / accumulatedDistance) * 1000) : 0
                    
                    // Calculate average HR for this split
                    let splitAvgHR = calculateAverageHeartRate(
                        samples: heartRateSamples,
                        startTime: startTime,
                        endTime: endTime
                    )
                    
                    let split = ActivitySplit(
                        id: currentSplitIndex,
                        distanceMeters: accumulatedDistance,
                        durationSeconds: durationSeconds,
                        paceSecondsPerKm: paceSecondsPerKm,
                        elevationGain: splitElevationGain,
                        elevationLoss: splitElevationLoss,
                        startTime: startTime,
                        endTime: endTime,
                        avgHeartRate: splitAvgHR
                    )
                    
                    splits.append(split)
                    
                    // Reset for next split
                    currentSplitIndex += 1
                    accumulatedDistance = 0
                    splitStartIndex = index
                    splitStartTime = endTime
                    splitElevationGain = 0
                    splitElevationLoss = 0
                }
            }
            
            previousCoord = coord
        }
        
        // Handle partial final split (if > 100m remaining)
        if accumulatedDistance >= 100, let startTime = splitStartTime {
            if let lastCoord = coordinates.last,
               let endTimeStr = lastCoord.ts,
               let endTime = isoFormatter.date(from: endTimeStr) {
                
                let durationSeconds = Int(endTime.timeIntervalSince(startTime))
                let paceSecondsPerKm = durationSeconds > 0 ? Int((Double(durationSeconds) / accumulatedDistance) * 1000) : 0
                
                let splitAvgHR = calculateAverageHeartRate(
                    samples: heartRateSamples,
                    startTime: startTime,
                    endTime: endTime
                )
                
                let split = ActivitySplit(
                    id: currentSplitIndex,
                    distanceMeters: accumulatedDistance,
                    durationSeconds: durationSeconds,
                    paceSecondsPerKm: paceSecondsPerKm,
                    elevationGain: splitElevationGain,
                    elevationLoss: splitElevationLoss,
                    startTime: startTime,
                    endTime: endTime,
                    avgHeartRate: splitAvgHR
                )
                
                splits.append(split)
            }
        }
        
        return splits
    }
    
    // MARK: - Pace Samples Calculation
    
    /// Calculate pace samples for graphing pace over distance
    /// - Parameter coordinates: Array of route coordinates with timestamps
    /// - Returns: Array of PaceSample for charting
    func calculatePaceSamples(from coordinates: [RouteCoordinate]) -> [PaceSample] {
        guard coordinates.count >= 2 else { return [] }
        
        var samples: [PaceSample] = []
        var cumulativeDistance: Double = 0
        var lastSampleDistance: Double = 0
        var previousCoord: RouteCoordinate?
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Add initial sample at 0
        if let firstTs = coordinates.first?.ts,
           let timestamp = isoFormatter.date(from: firstTs) {
            samples.append(PaceSample(
                distanceKm: 0,
                paceSecondsPerKm: 0,
                timestamp: timestamp,
                speedKmh: 0
            ))
        }
        
        var segmentStartCoord: RouteCoordinate?
        var segmentStartTime: Date?
        var segmentDistance: Double = 0
        
        for coord in coordinates {
            if let prev = previousCoord {
                let distance = haversineDistance(
                    lat1: prev.lat, lon1: prev.lng,
                    lat2: coord.lat, lon2: coord.lng
                )
                cumulativeDistance += distance
                segmentDistance += distance
                
                // Sample every 100m
                if cumulativeDistance - lastSampleDistance >= paceSampleIntervalMeters {
                    guard let currentTs = coord.ts,
                          let currentTime = isoFormatter.date(from: currentTs),
                          let startCoord = segmentStartCoord,
                          let startTs = startCoord.ts,
                          let startTime = isoFormatter.date(from: startTs) else {
                        previousCoord = coord
                        continue
                    }
                    
                    let segmentDuration = currentTime.timeIntervalSince(startTime)
                    
                    if segmentDuration > 0 && segmentDistance > 0 {
                        let speedMs = segmentDistance / segmentDuration
                        let speedKmh = speedMs * 3.6
                        let paceSecondsPerKm = speedMs > 0 ? Int(1000 / speedMs) : 0
                        
                        samples.append(PaceSample(
                            distanceKm: cumulativeDistance / 1000,
                            paceSecondsPerKm: paceSecondsPerKm,
                            timestamp: currentTime,
                            speedKmh: speedKmh
                        ))
                    }
                    
                    lastSampleDistance = cumulativeDistance
                    segmentStartCoord = coord
                    segmentStartTime = currentTime
                    segmentDistance = 0
                }
            } else {
                segmentStartCoord = coord
                if let ts = coord.ts {
                    segmentStartTime = isoFormatter.date(from: ts)
                }
            }
            
            previousCoord = coord
        }
        
        // Downsample if too many points (keep ~100 for smooth charting)
        if samples.count > 100 {
            return downsample(samples, to: 100)
        }
        
        return samples
    }
    
    // MARK: - Heart Rate Zone Distribution
    
    /// Calculate time spent in each heart rate zone
    /// - Parameters:
    ///   - samples: Array of heart rate samples
    ///   - maxHeartRate: User's maximum heart rate (typically 220 - age)
    /// - Returns: HeartRateZoneDistribution with time in each zone
    func calculateHeartRateZones(
        samples: [RunHeartRateSample],
        maxHeartRate: Int
    ) -> HeartRateZoneDistribution {
        guard samples.count >= 2, maxHeartRate > 0 else {
            return HeartRateZoneDistribution()
        }
        
        var distribution = HeartRateZoneDistribution()
        
        for i in 0..<(samples.count - 1) {
            let currentSample = samples[i]
            let nextSample = samples[i + 1]
            
            let duration = nextSample.timestamp.timeIntervalSince(currentSample.timestamp)
            let zone = HeartRateZone.zone(for: currentSample.bpm, maxHeartRate: maxHeartRate)
            
            distribution.addTime(duration, to: zone)
        }
        
        return distribution
    }
    
    // MARK: - Full Analytics Calculation
    
    /// Calculate complete activity analytics including splits, pace, and HR data
    /// - Parameters:
    ///   - coordinates: Route coordinates with timestamps
    ///   - heartRateSamples: Heart rate samples during activity
    ///   - maxHeartRate: User's max heart rate for zone calculation
    /// - Returns: ActivityAnalytics with all calculated data
    func calculateActivityAnalytics(
        coordinates: [RouteCoordinate],
        heartRateSamples: [RunHeartRateSample] = [],
        maxHeartRate: Int = 190
    ) -> ActivityAnalytics {
        let splits = calculateSplits(from: coordinates, heartRateSamples: heartRateSamples)
        let paceSamples = calculatePaceSamples(from: coordinates)
        let zoneDistribution = calculateHeartRateZones(samples: heartRateSamples, maxHeartRate: maxHeartRate)
        
        // Calculate pace stats
        let paces = splits.map { $0.paceSecondsPerKm }
        let avgPace = paces.isEmpty ? 0 : paces.reduce(0, +) / paces.count
        let bestPace = paces.min() ?? 0
        let worstPace = paces.max() ?? 0
        let bestSplitIndex = splits.firstIndex { $0.paceSecondsPerKm == bestPace }
        let worstSplitIndex = splits.firstIndex { $0.paceSecondsPerKm == worstPace }
        
        // Calculate HR stats
        let hrValues = heartRateSamples.map { $0.bpm }
        let avgHR = hrValues.isEmpty ? 0 : hrValues.reduce(0, +) / hrValues.count
        let maxHR = hrValues.max() ?? 0
        let minHR = hrValues.min() ?? 0
        
        return ActivityAnalytics(
            splits: splits,
            paceSamples: paceSamples,
            heartRateSamples: heartRateSamples,
            zoneDistribution: zoneDistribution,
            avgPaceSecondsPerKm: avgPace,
            bestPaceSecondsPerKm: bestPace,
            worstPaceSecondsPerKm: worstPace,
            bestSplitIndex: bestSplitIndex,
            worstSplitIndex: worstSplitIndex,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            minHeartRate: minHR
        )
    }
    
    // MARK: - Weekly Progress Calculation
    
    /// Calculate weekly progress data for charts
    /// - Parameters:
    ///   - summaries: Daily activity summaries
    ///   - weekStart: Start date of the week
    ///   - goalDistance: Weekly distance goal in km
    /// - Returns: WeeklyProgressData for charting
    func calculateWeeklyProgress(
        summaries: [DailyActivitySummary],
        weekStart: Date? = nil,
        goalDistance: Double = 50.0 // default 50km weekly goal
    ) -> WeeklyProgressData {
        let calendar = Calendar.current
        let startOfWeek = weekStart ?? calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        var dailyDistances: [WeeklyProgressData.DailyDistance] = []
        var totalDistance: Double = 0
        var totalActivities = 0
        
        // Get data for each day of the week
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            
            let daySummary = summaries.first { summary in
                calendar.isDate(summary.date, inSameDayAs: date)
            }
            
            let distance = daySummary?.distance ?? 0
            let activityCount = daySummary?.activities.count ?? 0
            
            dailyDistances.append(WeeklyProgressData.DailyDistance(
                date: date,
                distance: distance,
                activityCount: activityCount
            ))
            
            totalDistance += distance
            totalActivities += activityCount
        }
        
        let avgDailyDistance = totalDistance / 7.0
        let goalProgress = min(totalDistance / goalDistance, 1.0)
        
        return WeeklyProgressData(
            weekStart: startOfWeek,
            dailyDistances: dailyDistances,
            totalDistance: totalDistance,
            totalActivities: totalActivities,
            avgDailyDistance: avgDailyDistance,
            goalDistance: goalDistance,
            goalProgress: goalProgress
        )
    }
    
    // MARK: - Calendar Run Data
    
    /// Generate calendar data for a given month
    /// - Parameters:
    ///   - activities: All activities to analyze
    ///   - month: The month to generate data for
    /// - Returns: Array of CalendarRunData for each day
    func generateCalendarData(
        activities: [RouteActivity],
        for month: Date
    ) -> [CalendarRunData] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }
        
        var calendarData: [CalendarRunData] = []
        var currentDate = monthInterval.start
        
        while currentDate < monthInterval.end {
            let dayActivities = activities.filter { activity in
                calendar.isDate(activity.startTime, inSameDayAs: currentDate)
            }
            
            let totalDistance = dayActivities.reduce(0) { $0 + $1.distance }
            let totalDuration = dayActivities.reduce(0) { $0 + $1.duration }
            
            calendarData.append(CalendarRunData(
                date: currentDate,
                totalDistance: totalDistance,
                totalDuration: totalDuration,
                activityCount: dayActivities.count,
                activities: dayActivities
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return calendarData
    }
    
    // MARK: - Helper Methods
    
    /// Calculate distance between two coordinates using Haversine formula
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusMeters * c
    }
    
    /// Calculate average heart rate for a time period
    private func calculateAverageHeartRate(
        samples: [RunHeartRateSample],
        startTime: Date,
        endTime: Date
    ) -> Int? {
        let filteredSamples = samples.filter { sample in
            sample.timestamp >= startTime && sample.timestamp <= endTime
        }
        
        guard !filteredSamples.isEmpty else { return nil }
        
        let total = filteredSamples.reduce(0) { $0 + $1.bpm }
        return total / filteredSamples.count
    }
    
    /// Downsample an array to target count using LTTB algorithm
    private func downsample(_ samples: [PaceSample], to targetCount: Int) -> [PaceSample] {
        guard samples.count > targetCount else { return samples }
        
        var result: [PaceSample] = []
        result.append(samples[0]) // Always keep first
        
        let bucketSize = (samples.count - 2) / (targetCount - 2)
        
        for i in 0..<(targetCount - 2) {
            let bucketStart = i * bucketSize + 1
            let bucketEnd = min(bucketStart + bucketSize, samples.count - 1)
            
            // Use average of bucket
            var sumPace = 0
            var sumDistance = 0.0
            var count = 0
            
            for j in bucketStart..<bucketEnd {
                sumPace += samples[j].paceSecondsPerKm
                sumDistance += samples[j].distanceKm
                count += 1
            }
            
            if count > 0 {
                let avgSample = samples[bucketStart + count / 2]
                result.append(avgSample)
            }
        }
        
        result.append(samples[samples.count - 1]) // Always keep last
        
        return result
    }
    
    // MARK: - Estimated Max Heart Rate
    
    /// Calculate estimated max heart rate based on age
    /// - Parameter age: User's age in years
    /// - Returns: Estimated maximum heart rate
    func estimatedMaxHeartRate(age: Int) -> Int {
        // Using the Tanaka formula: 208 - (0.7 × age)
        return max(100, 208 - Int(0.7 * Double(age)))
    }
}

// MARK: - Mock Analytics Data

extension RunAnalyticsService {
    
    /// Generate mock splits for testing
    static func generateMockSplits(count: Int = 5) -> [ActivitySplit] {
        var splits: [ActivitySplit] = []
        let baseTime = Date().addingTimeInterval(-3600) // 1 hour ago
        
        for i in 1...count {
            let basePace = Int.random(in: 300...420) // 5:00 - 7:00 min/km
            let duration = basePace + Int.random(in: -30...30)
            
            splits.append(ActivitySplit(
                id: i,
                distanceMeters: 1000,
                durationSeconds: duration,
                paceSecondsPerKm: duration,
                elevationGain: Double.random(in: 0...20),
                elevationLoss: Double.random(in: 0...15),
                startTime: baseTime.addingTimeInterval(Double((i - 1) * duration)),
                endTime: baseTime.addingTimeInterval(Double(i * duration)),
                avgHeartRate: Int.random(in: 140...170)
            ))
        }
        
        return splits
    }
    
    /// Generate mock pace samples for testing
    static func generateMockPaceSamples(distanceKm: Double = 5.0) -> [PaceSample] {
        var samples: [PaceSample] = []
        let baseTime = Date().addingTimeInterval(-1800)
        let sampleCount = Int(distanceKm * 10) // 10 samples per km
        
        for i in 0...sampleCount {
            let distance = Double(i) / 10.0
            let basePace = 360 // 6:00 min/km base
            let variance = Int.random(in: -60...60)
            let pace = basePace + variance
            let speed = 3600.0 / Double(pace) // Convert pace to speed km/h
            
            samples.append(PaceSample(
                distanceKm: distance,
                paceSecondsPerKm: pace,
                timestamp: baseTime.addingTimeInterval(Double(i) * 36),
                speedKmh: speed
            ))
        }
        
        return samples
    }
    
    /// Generate mock heart rate samples for testing
    static func generateMockRunHeartRateSamples(durationMinutes: Int = 30) -> [RunHeartRateSample] {
        var samples: [RunHeartRateSample] = []
        let baseTime = Date().addingTimeInterval(-Double(durationMinutes * 60))
        let sampleCount = durationMinutes * 4 // Sample every 15 seconds
        
        var currentHR = 100 // Starting HR
        
        for i in 0..<sampleCount {
            // Simulate HR increasing during warmup, plateauing, then decreasing
            let phase = Double(i) / Double(sampleCount)
            
            if phase < 0.2 {
                // Warmup - increase
                currentHR = min(currentHR + Int.random(in: 0...3), 170)
            } else if phase < 0.8 {
                // Main activity - fluctuate around high HR
                currentHR = 150 + Int.random(in: -15...15)
            } else {
                // Cooldown - decrease
                currentHR = max(currentHR - Int.random(in: 0...3), 100)
            }
            
            samples.append(RunHeartRateSample(
                bpm: currentHR,
                timestamp: baseTime.addingTimeInterval(Double(i) * 15),
                distanceKm: Double(i) * 0.05
            ))
        }
        
        return samples
    }
    
    /// Generate mock activity analytics
    static func generateMockAnalytics() -> ActivityAnalytics {
        let splits = generateMockSplits()
        let paceSamples = generateMockPaceSamples()
        let heartRateSamples = generateMockRunHeartRateSamples()
        
        var zoneDistribution = HeartRateZoneDistribution()
        zoneDistribution.recovery = 120
        zoneDistribution.fatBurn = 300
        zoneDistribution.cardio = 600
        zoneDistribution.peak = 480
        zoneDistribution.maximum = 60
        
        return ActivityAnalytics(
            splits: splits,
            paceSamples: paceSamples,
            heartRateSamples: heartRateSamples,
            zoneDistribution: zoneDistribution,
            avgPaceSecondsPerKm: 360,
            bestPaceSecondsPerKm: 310,
            worstPaceSecondsPerKm: 420,
            bestSplitIndex: 2,
            worstSplitIndex: 4,
            avgHeartRate: 152,
            maxHeartRate: 175,
            minHeartRate: 105
        )
    }
}
