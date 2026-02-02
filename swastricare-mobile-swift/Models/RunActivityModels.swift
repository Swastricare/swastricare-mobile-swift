//
//  RunActivityModels.swift
//  swastricare-mobile-swift
//
//  Steps & Walk/Run Activity Tracking Models
//

import Foundation
import SwiftUI
import MapKit

// MARK: - Time Range Filter

enum ActivityTimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1 Week"
    case twoWeeks = "2 Week"
    case threeWeeks = "3 Week"
    case oneMonth = "1 Month"
    
    var id: String { rawValue }
    
    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
        case .oneMonth: return 30
        }
    }
}

// MARK: - Activity Type

enum RunActivityType: String, Codable, CaseIterable {
    case walk = "Walk"
    case run = "Run"
    case commute = "Commute"
    
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .run: return "figure.run"
        case .commute: return "figure.walk.motion"
        }
    }
    
    var color: Color {
        switch self {
        case .walk: return Color(hex: "4F46E5")
        case .run: return Color(hex: "22C55E")
        case .commute: return Color(hex: "3B82F6")
        }
    }
}

// MARK: - Route Activity

struct RouteActivity: Identifiable, Codable, Equatable {
    let id: UUID
    /// Backend row id (Supabase `run_activities.id`) when this activity came from the API.
    /// For local-only HealthKit activities, this is `nil`.
    var apiId: UUID?
    
    /// External id used for de-duplication across sources (e.g. HealthKit workout UUID string).
    var externalId: String?
    
    /// Source of the activity (e.g. "app", "apple_health").
    var source: String?
    var name: String
    var type: RunActivityType
    var startTime: Date
    var endTime: Date
    var distance: Double // in km
    var averageBPM: Int
    var steps: Int
    var calories: Int
    var routeCoordinates: [CoordinatePoint]
    
    init(
        id: UUID = UUID(),
        apiId: UUID? = nil,
        externalId: String? = nil,
        source: String? = nil,
        name: String,
        type: RunActivityType,
        startTime: Date,
        endTime: Date,
        distance: Double,
        averageBPM: Int,
        steps: Int = 0,
        calories: Int = 0,
        routeCoordinates: [CoordinatePoint] = []
    ) {
        self.id = id
        self.apiId = apiId
        self.externalId = externalId
        self.source = source
        self.name = name
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.averageBPM = averageBPM
        self.steps = steps
        self.calories = calories
        self.routeCoordinates = routeCoordinates
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var formattedDistance: String {
        String(format: "%.1f Km", distance)
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
    
    static func == (lhs: RouteActivity, rhs: RouteActivity) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Coordinate Point

struct CoordinatePoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date?
    let altitude: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, timestamp: Date? = nil, altitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
    }
    
    init(coordinate: CLLocationCoordinate2D, timestamp: Date? = nil, altitude: Double? = nil) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
        self.altitude = altitude
    }
}

// MARK: - Daily Activity Summary

struct DailyActivitySummary: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    var steps: Int
    var distance: Double // in km
    var calories: Int
    var points: Int
    var activities: [RouteActivity]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    static func == (lhs: DailyActivitySummary, rhs: DailyActivitySummary) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Activity Statistics

struct ActivityStatistics: Equatable {
    var totalSteps: Int
    var totalDistance: Double // in km
    var totalCalories: Int
    var totalPoints: Int
    var averageStepsPerDay: Int
    var averageDistancePerDay: Double
    var percentageChange: Double // compared to previous period
    var yesterdayDistance: Double
    
    init(
        totalSteps: Int = 0,
        totalDistance: Double = 0,
        totalCalories: Int = 0,
        totalPoints: Int = 0,
        averageStepsPerDay: Int = 0,
        averageDistancePerDay: Double = 0,
        percentageChange: Double = 0,
        yesterdayDistance: Double = 0
    ) {
        self.totalSteps = totalSteps
        self.totalDistance = totalDistance
        self.totalCalories = totalCalories
        self.totalPoints = totalPoints
        self.averageStepsPerDay = averageStepsPerDay
        self.averageDistancePerDay = averageDistancePerDay
        self.percentageChange = percentageChange
        self.yesterdayDistance = yesterdayDistance
    }
    
    var formattedDistance: String {
        String(format: "%.3f", totalDistance)
    }
    
    var formattedCalories: String {
        String(format: "%.3f", Double(totalCalories) / 1000.0)
    }
    
    var formattedPoints: String {
        String(format: "%.3f", Double(totalPoints) / 1000.0)
    }
    
    var isIncreased: Bool {
        percentageChange >= 0
    }
    
    var formattedPercentageChange: String {
        let prefix = isIncreased ? "Increase" : "Decrease"
        return "Distance \(prefix) \(Int(abs(percentageChange)))%"
    }
}

// MARK: - Weekly Comparison

struct WeeklyComparison: Identifiable, Equatable {
    let id = UUID()
    var currentWeekAverage: Double // km/day
    var previousWeekAverage: Double // km/day
    var currentWeekDateRange: String
    var previousWeekDateRange: String
    
    var improvement: Double {
        guard previousWeekAverage > 0 else { return 0 }
        return ((currentWeekAverage - previousWeekAverage) / previousWeekAverage) * 100
    }
    
    var insightText: String {
        if currentWeekAverage > previousWeekAverage {
            return "On average, your walking and running distance last week was more than the week before"
        } else if currentWeekAverage < previousWeekAverage {
            return "On average, your walking and running distance last week was less than the week before"
        } else {
            return "Your walking and running distance remained consistent compared to last week"
        }
    }
}

// MARK: - Activity Goal

struct ActivityGoal: Equatable {
    var dailyStepsGoal: Int
    var dailyDistanceGoal: Double // in km
    var dailyCaloriesGoal: Int
    
    var currentSteps: Int
    var currentDistance: Double
    var currentCalories: Int
    
    var stepsProgress: Double {
        guard dailyStepsGoal > 0 else { return 0 }
        return min(Double(currentSteps) / Double(dailyStepsGoal), 1.0)
    }
    
    var distanceProgress: Double {
        guard dailyDistanceGoal > 0 else { return 0 }
        return min(currentDistance / dailyDistanceGoal, 1.0)
    }
    
    var caloriesProgress: Double {
        guard dailyCaloriesGoal > 0 else { return 0 }
        return min(Double(currentCalories) / Double(dailyCaloriesGoal), 1.0)
    }
    
    init(
        dailyStepsGoal: Int = 10000,
        dailyDistanceGoal: Double = 8.0,
        dailyCaloriesGoal: Int = 500,
        currentSteps: Int = 0,
        currentDistance: Double = 0,
        currentCalories: Int = 0
    ) {
        self.dailyStepsGoal = dailyStepsGoal
        self.dailyDistanceGoal = dailyDistanceGoal
        self.dailyCaloriesGoal = dailyCaloriesGoal
        self.currentSteps = currentSteps
        self.currentDistance = currentDistance
        self.currentCalories = currentCalories
    }
}

// MARK: - Activity Split (per kilometer data)

struct ActivitySplit: Identifiable, Codable, Equatable {
    let id: Int // kilometer number (1, 2, 3...)
    let distanceMeters: Double // distance covered in this split (~1000m)
    let durationSeconds: Int // time taken for this split
    let paceSecondsPerKm: Int // pace in seconds per km
    let elevationGain: Double // elevation gained in meters
    let elevationLoss: Double // elevation lost in meters
    let startTime: Date
    let endTime: Date
    let avgHeartRate: Int? // average heart rate during this split
    
    var formattedPace: String {
        let minutes = paceSecondsPerKm / 60
        let seconds = paceSecondsPerKm % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var paceMinutesPerKm: Double {
        Double(paceSecondsPerKm) / 60.0
    }
}

// MARK: - Pace Sample (for graphing pace over distance/time)

struct PaceSample: Identifiable, Codable, Equatable {
    let id: UUID
    let distanceKm: Double // cumulative distance at this point
    let paceSecondsPerKm: Int // instantaneous pace
    let timestamp: Date
    let speedKmh: Double // speed in km/h
    
    init(id: UUID = UUID(), distanceKm: Double, paceSecondsPerKm: Int, timestamp: Date, speedKmh: Double) {
        self.id = id
        self.distanceKm = distanceKm
        self.paceSecondsPerKm = paceSecondsPerKm
        self.timestamp = timestamp
        self.speedKmh = speedKmh
    }
    
    var formattedPace: String {
        let minutes = paceSecondsPerKm / 60
        let seconds = paceSecondsPerKm % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var paceMinutesPerKm: Double {
        Double(paceSecondsPerKm) / 60.0
    }
}

// MARK: - Run Heart Rate Sample (for graphing HR over time during runs)

struct RunHeartRateSample: Identifiable, Codable, Equatable {
    let id: UUID
    let bpm: Int
    let timestamp: Date
    let distanceKm: Double? // optional distance at this HR sample
    
    init(id: UUID = UUID(), bpm: Int, timestamp: Date, distanceKm: Double? = nil) {
        self.id = id
        self.bpm = bpm
        self.timestamp = timestamp
        self.distanceKm = distanceKm
    }
}

// MARK: - Heart Rate Zone

enum HeartRateZone: String, CaseIterable, Codable {
    case recovery = "Recovery"    // 50-60% max HR
    case fatBurn = "Fat Burn"     // 60-70%
    case cardio = "Cardio"        // 70-80%
    case peak = "Peak"            // 80-90%
    case maximum = "Maximum"      // 90-100%
    
    var color: Color {
        switch self {
        case .recovery: return Color.gray
        case .fatBurn: return Color.blue
        case .cardio: return Color.green
        case .peak: return Color.orange
        case .maximum: return Color.red
        }
    }
    
    var minPercentage: Double {
        switch self {
        case .recovery: return 0.50
        case .fatBurn: return 0.60
        case .cardio: return 0.70
        case .peak: return 0.80
        case .maximum: return 0.90
        }
    }
    
    var maxPercentage: Double {
        switch self {
        case .recovery: return 0.60
        case .fatBurn: return 0.70
        case .cardio: return 0.80
        case .peak: return 0.90
        case .maximum: return 1.00
        }
    }
    
    /// Get zone for a given heart rate and max heart rate
    static func zone(for heartRate: Int, maxHeartRate: Int) -> HeartRateZone {
        let percentage = Double(heartRate) / Double(maxHeartRate)
        
        switch percentage {
        case ..<0.60: return .recovery
        case 0.60..<0.70: return .fatBurn
        case 0.70..<0.80: return .cardio
        case 0.80..<0.90: return .peak
        default: return .maximum
        }
    }
}

// MARK: - Heart Rate Zone Distribution

struct HeartRateZoneDistribution: Equatable {
    var recovery: TimeInterval = 0
    var fatBurn: TimeInterval = 0
    var cardio: TimeInterval = 0
    var peak: TimeInterval = 0
    var maximum: TimeInterval = 0
    
    var totalTime: TimeInterval {
        recovery + fatBurn + cardio + peak + maximum
    }
    
    func percentage(for zone: HeartRateZone) -> Double {
        guard totalTime > 0 else { return 0 }
        let zoneTime: TimeInterval
        switch zone {
        case .recovery: zoneTime = recovery
        case .fatBurn: zoneTime = fatBurn
        case .cardio: zoneTime = cardio
        case .peak: zoneTime = peak
        case .maximum: zoneTime = maximum
        }
        return (zoneTime / totalTime) * 100
    }
    
    func time(for zone: HeartRateZone) -> TimeInterval {
        switch zone {
        case .recovery: return recovery
        case .fatBurn: return fatBurn
        case .cardio: return cardio
        case .peak: return peak
        case .maximum: return maximum
        }
    }
    
    mutating func addTime(_ time: TimeInterval, to zone: HeartRateZone) {
        switch zone {
        case .recovery: recovery += time
        case .fatBurn: fatBurn += time
        case .cardio: cardio += time
        case .peak: peak += time
        case .maximum: maximum += time
        }
    }
}

// MARK: - Activity Analytics Data

struct ActivityAnalytics: Equatable {
    var splits: [ActivitySplit]
    var paceSamples: [PaceSample]
    var heartRateSamples: [RunHeartRateSample]
    var zoneDistribution: HeartRateZoneDistribution
    
    // Pace stats
    var avgPaceSecondsPerKm: Int
    var bestPaceSecondsPerKm: Int
    var worstPaceSecondsPerKm: Int
    var bestSplitIndex: Int?
    var worstSplitIndex: Int?
    
    // Heart rate stats
    var avgHeartRate: Int
    var maxHeartRate: Int
    var minHeartRate: Int
    
    init(
        splits: [ActivitySplit] = [],
        paceSamples: [PaceSample] = [],
        heartRateSamples: [RunHeartRateSample] = [],
        zoneDistribution: HeartRateZoneDistribution = HeartRateZoneDistribution(),
        avgPaceSecondsPerKm: Int = 0,
        bestPaceSecondsPerKm: Int = 0,
        worstPaceSecondsPerKm: Int = 0,
        bestSplitIndex: Int? = nil,
        worstSplitIndex: Int? = nil,
        avgHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        minHeartRate: Int = 0
    ) {
        self.splits = splits
        self.paceSamples = paceSamples
        self.heartRateSamples = heartRateSamples
        self.zoneDistribution = zoneDistribution
        self.avgPaceSecondsPerKm = avgPaceSecondsPerKm
        self.bestPaceSecondsPerKm = bestPaceSecondsPerKm
        self.worstPaceSecondsPerKm = worstPaceSecondsPerKm
        self.bestSplitIndex = bestSplitIndex
        self.worstSplitIndex = worstSplitIndex
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
    }
    
    var formattedAvgPace: String {
        let minutes = avgPaceSecondsPerKm / 60
        let seconds = avgPaceSecondsPerKm % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    var formattedBestPace: String {
        let minutes = bestPaceSecondsPerKm / 60
        let seconds = bestPaceSecondsPerKm % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    var formattedWorstPace: String {
        let minutes = worstPaceSecondsPerKm / 60
        let seconds = worstPaceSecondsPerKm % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - Weekly Progress Data

struct WeeklyProgressData: Equatable {
    let weekStart: Date
    let dailyDistances: [DailyDistance]
    let totalDistance: Double
    let totalActivities: Int
    let avgDailyDistance: Double
    let goalDistance: Double
    let goalProgress: Double // 0-1
    
    struct DailyDistance: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let distance: Double
        let activityCount: Int
        
        var dayAbbreviation: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
        
        var dayNumber: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Calendar Run Data

struct CalendarRunData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let totalDistance: Double
    let totalDuration: TimeInterval
    let activityCount: Int
    let activities: [RouteActivity]
    
    var hasActivity: Bool {
        activityCount > 0
    }
    
    var intensityLevel: Int {
        // Returns 1-5 based on distance for color intensity
        switch totalDistance {
        case 0: return 0
        case ..<2: return 1
        case 2..<5: return 2
        case 5..<8: return 3
        case 8..<12: return 4
        default: return 5
        }
    }
}

// MARK: - Extended Coordinate Point with Timestamp

struct TimestampedCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date
    let speed: Double? // m/s
    let accuracy: Double? // meters
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date, speed: Double? = nil, accuracy: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.accuracy = accuracy
    }
}

// MARK: - Model Conversions

extension RouteActivity {
    /// Creates a RouteActivity from a RunActivityRecord (API response)
    init(from record: RunActivityRecord) {
        let resolvedId = record.id ?? UUID()
        self.id = resolvedId
        self.apiId = record.id
        self.externalId = record.externalId
        self.source = record.source
        self.name = record.activityName ?? Self.generateActivityName(type: record.activityType, startTime: record.startedAt)
        self.type = RunActivityType(rawValue: record.activityType.capitalized) ?? .walk
        self.startTime = record.startedAt
        self.endTime = record.endedAt
        self.distance = record.distanceMeters / 1000.0
        self.averageBPM = record.avgHeartRate ?? 0
        self.steps = record.steps
        self.calories = record.caloriesBurned
        
        // Parse route coordinates with timestamps if available
        let isoFormatter = ISO8601DateFormatter()
        self.routeCoordinates = record.routeCoordinates?.map { coord in
            let timestamp: Date? = {
                guard let ts = coord.ts else { return nil }
                return isoFormatter.date(from: ts)
            }()
            return CoordinatePoint(
                latitude: coord.lat, 
                longitude: coord.lng,
                timestamp: timestamp,
                altitude: coord.alt
            ) 
        } ?? []
    }
    
    /// Creates a RouteActivity from a HealthKitWorkout
    init(from workout: HealthKitWorkout) {
        self.id = workout.id
        self.apiId = nil
        self.externalId = workout.id.uuidString
        self.source = "apple_health"
        self.name = Self.generateActivityName(type: workout.activityType, startTime: workout.startDate)
        self.type = RunActivityType(rawValue: workout.activityType.capitalized) ?? .walk
        self.startTime = workout.startDate
        self.endTime = workout.endDate
        self.distance = workout.distanceKm
        self.averageBPM = workout.averageHeartRate ?? 0
        self.steps = 0 // HealthKit workouts don't directly include steps
        self.calories = Int(workout.totalEnergyBurned)
        self.routeCoordinates = workout.route.map { 
            CoordinatePoint(
                latitude: $0.latitude, 
                longitude: $0.longitude,
                timestamp: $0.timestamp,
                altitude: $0.altitude
            ) 
        }
    }
    
    /// Converts to RunActivityRecord for API submission
    func toRecord(healthProfileId: UUID? = nil) -> RunActivityRecord {
        let isoFormatter = ISO8601DateFormatter()
        return RunActivityRecord(
            id: id,
            healthProfileId: healthProfileId,
            externalId: id.uuidString,
            source: "app",
            activityType: type.rawValue.lowercased(),
            activityName: name,
            startedAt: startTime,
            endedAt: endTime,
            durationSeconds: Int(duration),
            distanceMeters: distance * 1000,
            steps: steps,
            caloriesBurned: calories,
            avgHeartRate: averageBPM > 0 ? averageBPM : nil,
            routeCoordinates: routeCoordinates.map { coord in
                RouteCoordinate(
                    lat: coord.latitude, 
                    lng: coord.longitude, 
                    alt: coord.altitude, 
                    ts: coord.timestamp.map { isoFormatter.string(from: $0) }
                ) 
            },
            startLatitude: routeCoordinates.first?.latitude,
            startLongitude: routeCoordinates.first?.longitude,
            endLatitude: routeCoordinates.last?.latitude,
            endLongitude: routeCoordinates.last?.longitude
        )
    }
    
    private static func generateActivityName(type: String, startTime: Date) -> String {
        let hour = Calendar.current.component(.hour, from: startTime)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "Morning"
        case 12..<17: timeOfDay = "Afternoon"
        case 17..<21: timeOfDay = "Evening"
        default: timeOfDay = "Night"
        }
        
        return "\(timeOfDay) \(type.capitalized)"
    }
}

extension ActivityStatistics {
    /// Creates ActivityStatistics from API response
    init(from stats: ActivityStatsResponse, goals: ActivityGoalsRecord? = nil) {
        self.totalSteps = stats.period.total_steps
        self.totalDistance = stats.period.total_distance_km
        self.totalCalories = stats.period.total_calories
        self.totalPoints = stats.period.total_points
        self.averageStepsPerDay = stats.period.total_steps / max(stats.period.days, 1)
        self.averageDistancePerDay = stats.period.total_distance_km / Double(max(stats.period.days, 1))
        self.percentageChange = Double(stats.period.percentage_change)
        self.yesterdayDistance = stats.yesterday.distance_km
    }
    
    /// Creates ActivityStatistics from daily summary totals
    init(from totals: PeriodTotals, percentageChange: Double, yesterdayDistance: Double) {
        self.totalSteps = totals.total_steps
        self.totalDistance = totals.totalDistanceKm
        self.totalCalories = totals.total_calories
        self.totalPoints = totals.total_points
        self.averageStepsPerDay = totals.avg_daily_steps
        self.averageDistancePerDay = totals.avgDailyDistanceKm
        self.percentageChange = percentageChange
        self.yesterdayDistance = yesterdayDistance
    }
}

extension WeeklyComparison {
    /// Creates WeeklyComparison from API response
    init?(from comparison: WeeklyComparisonData?) {
        guard let comparison = comparison else { return nil }
        
        self.currentWeekAverage = comparison.current_week.avg_daily_distance_km
        self.previousWeekAverage = comparison.previous_week.avg_daily_distance_km
        self.currentWeekDateRange = Self.formatWeekRange(from: comparison.current_week.week_start)
        self.previousWeekDateRange = Self.formatWeekRange(from: comparison.previous_week.week_start)
    }
    
    private static func formatWeekRange(from dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        
        guard let startDate = isoFormatter.date(from: dateString) else {
            return dateString
        }
        
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: startDate)
        
        formatter.dateFormat = "d MMMM"
        let endDayMonth = formatter.string(from: endDate)
        
        return "\(startDay) - \(endDayMonth)"
    }
}

extension ActivityGoal {
    /// Creates ActivityGoal from API response
    init(from record: ActivityGoalsRecord, currentStats: ActivityStatsResponse?) {
        // Defensive: if backend returns 0/invalid goals, fall back to sensible defaults
        // so UI (e.g. progress rings) doesn't show misleading "0%".
        let sanitizedDailyStepsGoal =
            record.dailyStepsGoal > 0 ? record.dailyStepsGoal : ActivityGoalsRecord.default.dailyStepsGoal
        let sanitizedDailyDistanceMeters =
            record.dailyDistanceMeters > 0 ? record.dailyDistanceMeters : ActivityGoalsRecord.default.dailyDistanceMeters
        let sanitizedDailyCaloriesGoal =
            record.dailyCaloriesGoal > 0 ? record.dailyCaloriesGoal : ActivityGoalsRecord.default.dailyCaloriesGoal
        
        self.dailyStepsGoal = sanitizedDailyStepsGoal
        self.dailyDistanceGoal = Double(sanitizedDailyDistanceMeters) / 1000.0
        self.dailyCaloriesGoal = sanitizedDailyCaloriesGoal
        self.currentSteps = currentStats?.today.steps ?? 0
        self.currentDistance = currentStats?.today.distance_km ?? 0
        self.currentCalories = currentStats?.today.calories ?? 0
    }
}

// MARK: - HealthKit Conversion Extensions

extension HealthKitWorkout {
    /// Converts to RunActivityRecord for API sync
    func toRecord(healthProfileId: UUID? = nil, route: [WorkoutRoutePoint] = []) -> RunActivityRecord {
        RunActivityRecord(
            id: nil,
            healthProfileId: healthProfileId,
            externalId: id.uuidString,
            source: "apple_health",
            activityType: activityType,
            activityName: nil,
            startedAt: startDate,
            endedAt: endDate,
            durationSeconds: durationSeconds,
            distanceMeters: totalDistance,
            steps: 0,
            caloriesBurned: Int(totalEnergyBurned),
            avgHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            minHeartRate: minHeartRate,
            routeCoordinates: route.map { 
                RouteCoordinate(lat: $0.latitude, lng: $0.longitude, alt: $0.altitude, ts: ISO8601DateFormatter().string(from: $0.timestamp))
            },
            startLatitude: route.first?.latitude,
            startLongitude: route.first?.longitude,
            endLatitude: route.last?.latitude,
            endLongitude: route.last?.longitude
        )
    }
}

// MARK: - Mock Data Provider

struct MockRunActivityData {
    
    static func generateMockActivities() -> [RouteActivity] {
        let calendar = Calendar.current
        let now = Date()
        
        // Morning commute coordinates (sample route with timestamps)
        let commuteStartTime = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let commuteCoordinates = [
            CoordinatePoint(latitude: 12.9716, longitude: 77.5946, timestamp: commuteStartTime),
            CoordinatePoint(latitude: 12.9726, longitude: 77.5956, timestamp: commuteStartTime.addingTimeInterval(120)),
            CoordinatePoint(latitude: 12.9736, longitude: 77.5966, timestamp: commuteStartTime.addingTimeInterval(240)),
            CoordinatePoint(latitude: 12.9746, longitude: 77.5976, timestamp: commuteStartTime.addingTimeInterval(360)),
            CoordinatePoint(latitude: 12.9756, longitude: 77.5986, timestamp: commuteStartTime.addingTimeInterval(480))
        ]
        
        // Park walk coordinates with timestamps
        let parkStartTime = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let parkCoordinates = [
            CoordinatePoint(latitude: 12.9816, longitude: 77.6046, timestamp: parkStartTime),
            CoordinatePoint(latitude: 12.9826, longitude: 77.6056, timestamp: parkStartTime.addingTimeInterval(180)),
            CoordinatePoint(latitude: 12.9836, longitude: 77.6066, timestamp: parkStartTime.addingTimeInterval(360)),
            CoordinatePoint(latitude: 12.9846, longitude: 77.6076, timestamp: parkStartTime.addingTimeInterval(540))
        ]
        
        return [
            RouteActivity(
                name: "Commute To Office",
                type: .commute,
                startTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: now)!,
                endTime: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now)!,
                distance: 1.6,
                averageBPM: 93,
                steps: 2100,
                calories: 120,
                routeCoordinates: commuteCoordinates
            ),
            RouteActivity(
                name: "Around's Park",
                type: .walk,
                startTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: now)!,
                endTime: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now)!,
                distance: 1.6,
                averageBPM: 93,
                steps: 1800,
                calories: 95,
                routeCoordinates: parkCoordinates
            ),
            RouteActivity(
                name: "Evening Run",
                type: .run,
                startTime: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)!,
                endTime: calendar.date(bySettingHour: 18, minute: 45, second: 0, of: now)!,
                distance: 4.2,
                averageBPM: 135,
                steps: 4500,
                calories: 380,
                routeCoordinates: commuteCoordinates
            )
        ]
    }
    
    static func generateMockStatistics() -> ActivityStatistics {
        ActivityStatistics(
            totalSteps: 8792,
            totalDistance: 7.356,
            totalCalories: 2100,
            totalPoints: 1234,
            averageStepsPerDay: 8500,
            averageDistancePerDay: 3.2,
            percentageChange: 37,
            yesterdayDistance: 2.8
        )
    }
    
    static func generateMockWeeklyComparison() -> WeeklyComparison {
        WeeklyComparison(
            currentWeekAverage: 3.2,
            previousWeekAverage: 2.8,
            currentWeekDateRange: "11 - 17 September",
            previousWeekDateRange: "5 - 10 September"
        )
    }
    
    static func generateDailySummaries(for timeRange: ActivityTimeRange) -> [DailyActivitySummary] {
        let calendar = Calendar.current
        var summaries: [DailyActivitySummary] = []
        
        for i in 0..<timeRange.days {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let steps = Int.random(in: 5000...12000)
            let distance = Double.random(in: 2.0...8.0)
            
            summaries.append(DailyActivitySummary(
                date: date,
                steps: steps,
                distance: distance,
                calories: Int(distance * 80),
                points: Int(Double(steps) * 0.1),
                activities: []
            ))
        }
        
        return summaries
    }
}
