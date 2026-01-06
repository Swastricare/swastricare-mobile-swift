//
//  SupabaseManager.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // Using configuration from Config.swift
        guard let supabaseURL = URL(string: SupabaseConfig.projectURL) else {
            fatalError("Invalid Supabase URL. Please update Config.swift with your project credentials.")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
    
    // MARK: - Database Methods
    // Add your database query methods here as needed
    
    // MARK: - Health Data Sync
    
    /// Syncs comprehensive health metrics to Supabase
    func syncHealthData(
        steps: Int,
        heartRate: Int,
        sleepDuration: String,
        activeCalories: Int = 0,
        exerciseMinutes: Int = 0,
        standHours: Int = 0,
        distance: Double = 0.0,
        date: Date = Date()
    ) async throws -> HealthMetricRecord {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        // Format date as YYYY-MM-DD for the database
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: targetDate)
        
        // Check if a record exists for this date
        let existingRecords: [HealthMetricRecord] = try await client
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("metric_date", value: dateString)
            .execute()
            .value
        
        let metric = HealthMetricRecord(
            id: existingRecords.first?.id,
            userId: userId,
            steps: steps,
            heartRate: heartRate,
            sleepDuration: sleepDuration,
            activeCalories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            distance: distance,
            metricDate: dateString,
            syncedAt: Date()
        )
        
        if let existingRecord = existingRecords.first {
            // Update existing record
            let updated: HealthMetricRecord = try await client
                .from("health_metrics")
                .update(metric)
                .eq("id", value: existingRecord.id?.uuidString ?? "")
                .select()
                .single()
                .execute()
                .value
            
            // Log sync to history
            try await logSyncHistory(userId: userId, syncType: "health_update", recordsCount: 1)
            
            return updated
        } else {
            // Insert new record
            let inserted: HealthMetricRecord = try await client
                .from("health_metrics")
                .insert(metric)
                .select()
                .single()
                .execute()
                .value
            
            // Log sync to history
            try await logSyncHistory(userId: userId, syncType: "health_insert", recordsCount: 1)
            
            return inserted
        }
    }
    
    /// Syncs manual activity to Supabase
    func syncManualActivity(_ activity: ManualActivityRecord) async throws -> ManualActivityRecord {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        var activityToSync = activity
        activityToSync.userId = userId
        
        let inserted: ManualActivityRecord = try await client
            .from("manual_activities")
            .insert(activityToSync)
            .select()
            .single()
            .execute()
            .value
        
        try await logSyncHistory(userId: userId, syncType: "activity_insert", recordsCount: 1)
        
        return inserted
    }
    
    /// Fetches weekly stats from Supabase
    func getWeeklyStats() async throws -> [HealthMetricRecord] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = dateFormatter.string(from: weekAgo)
        
        let records: [HealthMetricRecord] = try await client
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("metric_date", value: fromDate)
            .order("metric_date", ascending: true)
            .execute()
            .value
        
        return records
    }
    
    /// Fetches monthly stats from Supabase
    func getMonthlyStats() async throws -> [HealthMetricRecord] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = dateFormatter.string(from: monthAgo)
        
        let records: [HealthMetricRecord] = try await client
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("metric_date", value: fromDate)
            .order("metric_date", ascending: true)
            .execute()
            .value
        
        return records
    }
    
    /// Fetches manual activities for a date range
    func fetchManualActivities(from: Date, to: Date) async throws -> [ManualActivityRecord] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: from)
        let toString = dateFormatter.string(from: to)
        
        let records: [ManualActivityRecord] = try await client
            .from("manual_activities")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: fromString)
            .lte("logged_at", value: toString)
            .order("logged_at", ascending: false)
            .execute()
            .value
        
        return records
    }
    
    // MARK: - Vault/Document Management (Stubs for VaultManager)
    
    /// Fetches user's medical documents
    func fetchUserDocuments() async throws -> [MedicalDocument] {
        // TODO: Implement when vault database schema is ready
        return []
    }
    
    /// Uploads a medical document
    func uploadDocument(fileData: Data, fileName: String, category: String, notes: String?) async throws -> MedicalDocument {
        // TODO: Implement when vault storage is configured
        throw SupabaseError.invalidData
    }
    
    /// Deletes a medical document
    func deleteDocument(document: MedicalDocument) async throws {
        // TODO: Implement when vault database schema is ready
    }
    
    /// Downloads a medical document
    func downloadDocument(storagePath: String) async throws -> Data {
        // TODO: Implement when vault storage is configured
        throw SupabaseError.invalidData
    }
    
    /// Searches medical documents
    func searchDocuments(query: String) async throws -> [MedicalDocument] {
        // TODO: Implement when vault database schema is ready
        return []
    }
    
    /// Fetches health history for the current user
    func fetchHealthHistory(limit: Int = 30) async throws -> [HealthMetricRecord] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let records: [HealthMetricRecord] = try await client
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("metric_date", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return records
    }
    
    /// Fetches today's health metrics
    func fetchTodayMetrics() async throws -> HealthMetricRecord? {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: today)
        
        let records: [HealthMetricRecord] = try await client
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("metric_date", value: dateString)
            .limit(1)
            .execute()
            .value
        
        return records.first
    }
    
    // MARK: - Private Helpers
    
    private func logSyncHistory(userId: UUID, syncType: String, recordsCount: Int) async throws {
        let history = SyncHistory(
            userId: userId,
            syncType: syncType,
            recordsSynced: recordsCount
        )
        
        let _: SyncHistory = try await client
            .from("sync_history")
            .insert(history)
            .select()
            .single()
            .execute()
            .value
    }
}

// MARK: - Data Models

struct HealthMetricRecord: Codable {
    let id: UUID?
    let userId: UUID
    let steps: Int
    let heartRate: Int
    let sleepDuration: String?
    let activeCalories: Int?
    let exerciseMinutes: Int?
    let standHours: Int?
    let distance: Double?
    let metricDate: String
    let syncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case steps
        case heartRate = "heart_rate"
        case sleepDuration = "sleep_duration"
        case activeCalories = "active_calories"
        case exerciseMinutes = "exercise_minutes"
        case standHours = "stand_hours"
        case distance
        case metricDate = "metric_date"
        case syncedAt = "synced_at"
    }
}

struct SyncHistory: Codable {
    let id: UUID?
    let userId: UUID
    let syncType: String
    let recordsSynced: Int
    let syncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case syncType = "sync_type"
        case recordsSynced = "records_synced"
        case syncedAt = "synced_at"
    }
    
    init(id: UUID? = nil, userId: UUID, syncType: String, recordsSynced: Int, syncedAt: Date? = Date()) {
        self.id = id
        self.userId = userId
        self.syncType = syncType
        self.recordsSynced = recordsSynced
        self.syncedAt = syncedAt
    }
}

struct ManualActivityRecord: Codable {
    let id: UUID?
    var userId: UUID
    let activityType: String
    let value: Double
    let unit: String
    let notes: String?
    let loggedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case value
        case unit
        case notes
        case loggedAt = "logged_at"
    }
    
    init(id: UUID? = nil, userId: UUID, activityType: String, value: Double, unit: String, notes: String?, loggedAt: Date) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.value = value
        self.unit = unit
        self.notes = notes
        self.loggedAt = loggedAt
    }
}

// MARK: - Medical Documents

enum DocumentCategory: String, Codable, CaseIterable {
    case labReports = "Lab Reports"
    case prescriptions = "Prescriptions"
    case insurance = "Insurance"
    case imaging = "Imaging"
}

struct MedicalDocument: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let title: String
    let category: String
    let fileType: String
    let fileUrl: String
    let fileSize: Int64
    let uploadedAt: Date?
    let notes: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case category
        case fileType = "file_type"
        case fileUrl = "file_url"
        case fileSize = "file_size"
        case uploadedAt = "uploaded_at"
        case notes
        case createdAt = "created_at"
    }
    
    init(id: UUID? = nil, userId: UUID, title: String, category: String, fileType: String, fileUrl: String, fileSize: Int64, uploadedAt: Date? = Date(), notes: String? = nil, createdAt: Date? = Date()) {
        self.id = id
        self.userId = userId
        self.title = title
        self.category = category
        self.fileType = fileType
        self.fileUrl = fileUrl
        self.fileSize = fileSize
        self.uploadedAt = uploadedAt
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    case storageError(String)
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidData:
            return "Invalid data format"
        case .networkError(let message):
            return "Network error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}

