//
//  RunActivityService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles run activity operations with Supabase
//

import Foundation
import Auth
import Supabase

// MARK: - Run Activity Service Protocol

protocol RunActivityServiceProtocol {
    // Activities
    func fetchActivities(startDate: Date?, endDate: Date?, activityType: String?, limit: Int) async throws -> [RunActivityRecord]
    func fetchActivity(id: UUID) async throws -> RunActivityRecord
    func createActivity(_ activity: RunActivityRecord) async throws -> RunActivityRecord
    func updateActivity(_ activity: RunActivityRecord) async throws -> RunActivityRecord
    func deleteActivity(id: UUID) async throws
    /// Deletes run activities from the backend where external_id is in the given set (e.g. HealthKit workout UUIDs).
    func deleteActivitiesByExternalIds(_ externalIds: Set<String>) async throws
    func syncActivities(_ activities: [RunActivityRecord]) async throws -> SyncResult
    
    // Summaries
    func fetchDailySummaries(startDate: Date, endDate: Date) async throws -> DailySummaryResponse
    func fetchWeeklyComparison() async throws -> WeeklyComparisonResponse
    
    // Statistics
    func fetchStats(days: Int) async throws -> ActivityStatsResponse
    
    // Goals
    func fetchGoals() async throws -> ActivityGoalsRecord
    func updateGoals(_ goals: ActivityGoalsRecord) async throws -> ActivityGoalsRecord
}

// MARK: - Run Activity Service Implementation

final class RunActivityService: RunActivityServiceProtocol {
    
    static let shared = RunActivityService()
    
    private let supabase = SupabaseManager.shared
    private let functionName = "run-activities"
    
    private init() {}
    
    // MARK: - Activities
    
    func fetchActivities(
        startDate: Date? = nil,
        endDate: Date? = nil,
        activityType: String? = nil,
        limit: Int = 50
    ) async throws -> [RunActivityRecord] {
        var params: [String: String] = ["limit": "\(limit)"]
        
        if let startDate = startDate {
            params["start_date"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let endDate = endDate {
            params["end_date"] = ISO8601DateFormatter().string(from: endDate)
        }
        if let activityType = activityType {
            params["type"] = activityType
        }
        
        let response: ActivitiesResponse = try await invokeFunction(
            action: "activities",
            method: "GET",
            queryParams: params
        )
        
        return response.activities
    }
    
    func fetchActivity(id: UUID) async throws -> RunActivityRecord {
        let response: ActivityResponse = try await invokeFunction(
            action: id.uuidString,
            method: "GET"
        )
        
        return response.activity
    }
    
    func createActivity(_ activity: RunActivityRecord) async throws -> RunActivityRecord {
        let response: ActivityResponse = try await invokeFunction(
            action: "",
            method: "POST",
            body: activity
        )
        
        return response.activity
    }
    
    func updateActivity(_ activity: RunActivityRecord) async throws -> RunActivityRecord {
        guard let id = activity.id else {
            throw RunActivityError.invalidData
        }
        
        let response: ActivityResponse = try await invokeFunction(
            action: "",
            method: "PUT",
            queryParams: ["id": id.uuidString],
            body: activity
        )
        
        return response.activity
    }
    
    func deleteActivity(id: UUID) async throws {
        // #region agent log
        let logData: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "B",
            "location": "RunActivityService.swift:110",
            "message": "deleteActivity service called",
            "data": ["id": id.uuidString],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
        
        let urlString = "\(SupabaseConfig.projectURL)/functions/v1/\(functionName)?id=\(id.uuidString)"
        
        // #region agent log
        let logData2: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "B",
            "location": "RunActivityService.swift:125",
            "message": "DELETE URL constructed",
            "data": ["url": urlString],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData2),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
        
        let result: SuccessResponse = try await invokeFunction(
            action: "",
            method: "DELETE",
            queryParams: ["id": id.uuidString]
        )
        
        // #region agent log
        let logData3: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "D",
            "location": "RunActivityService.swift:145",
            "message": "Delete response received",
            "data": ["success": result.success],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData3),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
    }
    
    /// Deletes run activities from the backend where external_id is in the given set (e.g. after deleting from Apple Health).
    func deleteActivitiesByExternalIds(_ externalIds: Set<String>) async throws {
        guard !externalIds.isEmpty else { return }
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate
        let records = try await fetchActivities(startDate: startDate, endDate: endDate, activityType: nil, limit: 200)
        let toDelete = records.filter { record in
            guard let eid = record.externalId, record.id != nil else { return false }
            return externalIds.contains(eid)
        }
        for record in toDelete {
            guard let id = record.id else { continue }
            try await deleteActivity(id: id)
        }
    }
    
    func syncActivities(_ activities: [RunActivityRecord]) async throws -> SyncResult {
        let response: SyncResponse = try await invokeFunction(
            action: "sync",
            method: "POST",
            body: SyncRequest(activities: activities)
        )
        
        return response.results
    }
    
    // MARK: - Summaries
    
    func fetchDailySummaries(startDate: Date, endDate: Date) async throws -> DailySummaryResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let response: DailySummaryResponse = try await invokeFunction(
            action: "summary",
            method: "GET",
            queryParams: [
                "start_date": formatter.string(from: startDate),
                "end_date": formatter.string(from: endDate)
            ]
        )
        
        return response
    }
    
    func fetchWeeklyComparison() async throws -> WeeklyComparisonResponse {
        let response: WeeklyComparisonResponse = try await invokeFunction(
            action: "weekly-comparison",
            method: "GET"
        )
        
        return response
    }
    
    // MARK: - Statistics
    
    func fetchStats(days: Int = 14) async throws -> ActivityStatsResponse {
        let response: ActivityStatsResponse = try await invokeFunction(
            action: "stats",
            method: "GET",
            queryParams: ["days": "\(days)"]
        )
        
        return response
    }
    
    // MARK: - Goals
    
    func fetchGoals() async throws -> ActivityGoalsRecord {
        let response: GoalsResponse = try await invokeFunction(
            action: "goals",
            method: "GET"
        )
        
        return response.goals
    }
    
    func updateGoals(_ goals: ActivityGoalsRecord) async throws -> ActivityGoalsRecord {
        let response: GoalsResponse = try await invokeFunction(
            action: "goals",
            method: "POST",
            body: goals
        )
        
        return response.goals
    }
    
    // MARK: - Private Helpers
    
    private func invokeFunction<T: Decodable>(
        action: String,
        method: String,
        queryParams: [String: String]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        // Build URL
        var urlString = "\(SupabaseConfig.projectURL)/functions/v1/\(functionName)"
        if !action.isEmpty {
            urlString += "/\(action)"
        }
        
        // Add query parameters
        if let params = queryParams, !params.isEmpty {
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        
        // #region agent log
        let logData: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "B",
            "location": "RunActivityService.swift:208",
            "message": "invokeFunction - before request",
            "data": [
                "method": method,
                "url": urlString,
                "hasAuth": (try? await supabase.client.auth.session) != nil
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
        
        guard let url = URL(string: urlString) else {
            throw RunActivityError.invalidURL
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add apikey header (required by Supabase edge functions)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        // Add auth token - check if session is valid and not expired
        do {
            let session = try await supabase.client.auth.session
            guard !session.isExpired else {
                throw RunActivityError.notAuthenticated
            }
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } catch {
            throw RunActivityError.notAuthenticated
        }
        
        // Add body for POST/PUT
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RunActivityError.networkError
        }
        
        // #region agent log
        let logData2: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "pre-fix",
            "hypothesisId": "E",
            "location": "RunActivityService.swift:260",
            "message": "HTTP response received",
            "data": [
                "statusCode": httpResponse.statusCode,
                "method": method,
                "dataLength": data.count
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
           let jsonData = try? JSONSerialization.data(withJSONObject: logData2),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? logFile.seekToEnd()
            try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            try? logFile.close()
        }
        // #endregion
        
        if httpResponse.statusCode >= 400 {
            // Try to parse error message
            let errorMessage: String
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                errorMessage = errorResponse.error
            } else {
                errorMessage = "HTTP \(httpResponse.statusCode)"
            }
            
            // #region agent log
            let logData3: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "pre-fix",
                "hypothesisId": "E",
                "location": "RunActivityService.swift:285",
                "message": "HTTP error response",
                "data": [
                    "statusCode": httpResponse.statusCode,
                    "error": errorMessage,
                    "responseBody": String(data: data, encoding: .utf8) ?? "nil"
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
               let jsonData = try? JSONSerialization.data(withJSONObject: logData3),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                try? logFile.close()
            }
            // #endregion
            
            throw RunActivityError.serverError(errorMessage)
        }
        
        // Decode response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // #region agent log
            let logData4: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "pre-fix",
                "hypothesisId": "E",
                "location": "RunActivityService.swift:310",
                "message": "Decoding error",
                "data": [
                    "error": error.localizedDescription,
                    "responseBody": String(data: data, encoding: .utf8) ?? "nil"
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let logFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log")),
               let jsonData = try? JSONSerialization.data(withJSONObject: logData4),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                try? logFile.close()
            }
            // #endregion
            
            print("Decoding error: \(error)")
            throw RunActivityError.decodingError
        }
    }
}

// MARK: - API Response Types

struct ActivitiesResponse: Decodable {
    let activities: [RunActivityRecord]
}

struct ActivityResponse: Decodable {
    let activity: RunActivityRecord
}

struct SuccessResponse: Decodable {
    let success: Bool
}

struct SyncRequest: Encodable {
    let activities: [RunActivityRecord]
}

struct SyncResponse: Decodable {
    let results: SyncResult
}

struct SyncResult: Decodable {
    let synced: Int
    let duplicates: Int
    let errors: [String]
}

struct DailySummaryResponse: Decodable {
    let summaries: [DailySummaryRecord]
    let totals: PeriodTotals
}

struct PeriodTotals: Decodable, Equatable {
    let total_steps: Int
    let total_distance_meters: Double
    let total_calories: Int
    let total_points: Int
    let active_days: Int
    let avg_daily_steps: Int
    let avg_daily_distance: Double
    
    var totalDistanceKm: Double {
        total_distance_meters / 1000.0
    }
    
    var avgDailyDistanceKm: Double {
        avg_daily_distance / 1000.0
    }
}

struct WeeklyComparisonResponse: Decodable {
    let weeks: [WeekRecord]?
    let comparison: WeeklyComparisonData?
}

struct WeekRecord: Decodable {
    let week_start: String
    let total_steps: String?
    let total_distance: String?
    let total_calories: String?
    let total_points: String?
    let avg_daily_steps: String?
    let avg_daily_distance: String?
    let active_days: String?
}

struct WeeklyComparisonData: Decodable, Equatable {
    let current_week: WeekSummary
    let previous_week: WeekSummary
    let percentage_change: Double
    let trend: String
    
    struct WeekSummary: Decodable, Equatable {
        let week_start: String
        let avg_daily_distance_km: Double
        let total_steps: Int
        let active_days: Int
    }
}

struct ActivityStatsResponse: Decodable, Equatable {
    let today: TodayStats
    let yesterday: YesterdayStats
    let period: PeriodStats
    
    struct TodayStats: Decodable, Equatable {
        let steps: Int
        let distance_km: Double
        let calories: Int
        let points: Int
    }
    
    struct YesterdayStats: Decodable, Equatable {
        let distance_km: Double
    }
    
    struct PeriodStats: Decodable, Equatable {
        let days: Int
        let total_steps: Int
        let total_distance_km: Double
        let total_calories: Int
        let total_points: Int
        let percentage_change: Int
    }
}

struct GoalsResponse: Decodable {
    let goals: ActivityGoalsRecord
}

struct ErrorResponse: Decodable {
    let error: String
}

// MARK: - Database Records

struct RunActivityRecord: Codable, Identifiable, Equatable {
    var id: UUID?
    var healthProfileId: UUID?
    var externalId: String?
    var source: String
    var activityType: String
    var activityName: String?
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var distanceMeters: Double
    var steps: Int
    var caloriesBurned: Int
    var pointsEarned: Int?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var minHeartRate: Int?
    var avgPaceSecondsPerKm: Int?
    var routeCoordinates: [RouteCoordinate]?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var notes: String?
    var tags: [String]?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case externalId = "external_id"
        case source
        case activityType = "activity_type"
        case activityName = "activity_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case steps
        case caloriesBurned = "calories_burned"
        case pointsEarned = "points_earned"
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case minHeartRate = "min_heart_rate"
        case avgPaceSecondsPerKm = "avg_pace_seconds_per_km"
        case routeCoordinates = "route_coordinates"
        case startLatitude = "start_latitude"
        case startLongitude = "start_longitude"
        case endLatitude = "end_latitude"
        case endLongitude = "end_longitude"
        case notes
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties for convenience
    var distanceKm: Double {
        distanceMeters / 1000.0
    }
    
    var durationMinutes: Int {
        durationSeconds / 60
    }
    
    var formattedDistance: String {
        String(format: "%.1f Km", distanceKm)
    }
    
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startedAt)) - \(formatter.string(from: endedAt))"
    }
    
    static func == (lhs: RunActivityRecord, rhs: RunActivityRecord) -> Bool {
        lhs.id == rhs.id
    }
}

struct RouteCoordinate: Codable, Equatable, Hashable {
    let lat: Double
    let lng: Double
    let alt: Double?
    let ts: String?
}

struct DailySummaryRecord: Codable, Identifiable, Equatable {
    let id: UUID?
    let healthProfileId: UUID?
    let summaryDate: String
    let totalSteps: Int
    let totalDistanceMeters: Double
    let totalCalories: Int
    let totalPoints: Int
    let totalDurationSeconds: Int
    let walkCount: Int?
    let runCount: Int?
    let commuteCount: Int?
    let avgHeartRate: Int?
    let avgPaceSecondsPerKm: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case summaryDate = "summary_date"
        case totalSteps = "total_steps"
        case totalDistanceMeters = "total_distance_meters"
        case totalCalories = "total_calories"
        case totalPoints = "total_points"
        case totalDurationSeconds = "total_duration_seconds"
        case walkCount = "walk_count"
        case runCount = "run_count"
        case commuteCount = "commute_count"
        case avgHeartRate = "avg_heart_rate"
        case avgPaceSecondsPerKm = "avg_pace_seconds_per_km"
    }
    
    var totalDistanceKm: Double {
        totalDistanceMeters / 1000.0
    }
}

struct ActivityGoalsRecord: Codable, Equatable {
    var dailyStepsGoal: Int
    var dailyDistanceMeters: Int
    var dailyCaloriesGoal: Int
    var dailyActiveMinutes: Int?
    var weeklyStepsGoal: Int?
    var weeklyDistanceMeters: Int?
    var currentStepsStreak: Int?
    var longestStepsStreak: Int?
    var level: Int?
    var totalXp: Int?
    
    enum CodingKeys: String, CodingKey {
        case dailyStepsGoal = "daily_steps_goal"
        case dailyDistanceMeters = "daily_distance_meters"
        case dailyCaloriesGoal = "daily_calories_goal"
        case dailyActiveMinutes = "daily_active_minutes"
        case weeklyStepsGoal = "weekly_steps_goal"
        case weeklyDistanceMeters = "weekly_distance_meters"
        case currentStepsStreak = "current_steps_streak"
        case longestStepsStreak = "longest_steps_streak"
        case level
        case totalXp = "total_xp"
    }
    
    static var `default`: ActivityGoalsRecord {
        ActivityGoalsRecord(
            dailyStepsGoal: 10000,
            dailyDistanceMeters: 8000,
            dailyCaloriesGoal: 500,
            dailyActiveMinutes: 30,
            weeklyStepsGoal: 70000,
            weeklyDistanceMeters: 50000,
            currentStepsStreak: 0,
            longestStepsStreak: 0,
            level: 1,
            totalXp: 0
        )
    }
}

// MARK: - Errors

enum RunActivityError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case networkError
    case serverError(String)
    case decodingError
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .notAuthenticated:
            return "Please sign in to continue"
        case .networkError:
            return "Network connection error"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError:
            return "Failed to process server response"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}
