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
    
    // MARK: - Edge Functions
    
    /// Invokes a Supabase Edge Function
    func invokeFunction(name: String, payload: [String: Any]) async throws -> [String: Any] {
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        // Call the edge function - returns Void, response comes via different method
        // For now, we'll use a simpler approach with URLSession
        guard let functionURL = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/\(name)") else {
            throw SupabaseError.invalidData
        }
        
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SupabaseError.networkError("Function call failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseError.invalidData
        }
        
        return json
    }
    
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
    
    // MARK: - Vault/Document Management
    
    /// Fetches user's medical documents
    func fetchUserDocuments() async throws -> [MedicalDocument] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let documents: [MedicalDocument] = try await client
            .from("medical_documents")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("uploaded_at", ascending: false)
            .execute()
            .value
        
        return documents
    }
    
    /// Uploads a medical document
    func uploadDocument(fileData: Data, fileName: String, category: String, notes: String?) async throws -> MedicalDocument {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        // Generate unique file path
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
        let storagePath = "\(userId.uuidString)/\(uniqueFileName)"
        
        // Upload to storage
        try await client.storage
            .from("medical-vault")
            .upload(
                path: storagePath,
                file: fileData,
                options: FileOptions(contentType: mimeType(for: fileExtension))
            )
        
        // Create document record
        let document = MedicalDocument(
            userId: userId,
            title: fileName,
            category: category,
            fileType: fileExtension.uppercased(),
            fileUrl: storagePath,
            fileSize: Int64(fileData.count),
            uploadedAt: Date(),
            notes: notes,
            createdAt: Date()
        )
        
        let inserted: MedicalDocument = try await client
            .from("medical_documents")
            .insert(document)
            .select()
            .single()
            .execute()
            .value
        
        return inserted
    }
    
    /// Deletes a medical document
    func deleteDocument(document: MedicalDocument) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        guard let docId = document.id else {
            throw SupabaseError.invalidData
        }
        
        // Delete from storage
        try await client.storage
            .from("medical-vault")
            .remove(paths: [document.fileUrl])
        
        // Delete from database
        try await client
            .from("medical_documents")
            .delete()
            .eq("id", value: docId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
    
    /// Downloads a medical document
    func downloadDocument(storagePath: String) async throws -> Data {
        let data = try await client.storage
            .from("medical-vault")
            .download(path: storagePath)
        
        return data
    }
    
    /// Searches medical documents
    func searchDocuments(query: String) async throws -> [MedicalDocument] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let documents: [MedicalDocument] = try await client
            .from("medical_documents")
            .select()
            .eq("user_id", value: userId.uuidString)
            .or("title.ilike.%\(query)%,notes.ilike.%\(query)%")
            .order("uploaded_at", ascending: false)
            .execute()
            .value
        
        return documents
    }
    
    /// Helper to get MIME type from extension
    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt":
            return "text/plain"
        case "rtf":
            return "application/rtf"
        case "csv":
            return "text/csv"
        default:
            return "application/octet-stream"
        }
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

struct MedicalDocument: Codable, Identifiable, Equatable {
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

