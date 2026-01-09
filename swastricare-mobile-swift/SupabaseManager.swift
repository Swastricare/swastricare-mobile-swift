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
        
        do {
        let documents: [MedicalDocument] = try await client
            .from("medical_documents")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("uploaded_at", ascending: false)
            .execute()
            .value
        
            print("✅ Fetched \(documents.count) documents for user")
        return documents
        } catch {
            print("❌ Failed to fetch documents: \(error)")
            throw SupabaseError.databaseError("Failed to fetch documents: \(error.localizedDescription)")
        }
    }
    
    /// Uploads a medical document
    func uploadDocument(
        fileData: Data,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ) async throws -> MedicalDocument {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        // Generate unique file path with sanitized filename
        var fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        // Handle files without extension
        if fileExtension.isEmpty {
            // Try to detect from content or use default
            fileExtension = "dat"
        }
        
        let baseName = sanitizeFileName((fileName as NSString).deletingPathExtension)
        let uniqueFileName = "\(baseName)_\(UUID().uuidString.lowercased()).\(fileExtension)"
        let storagePath = "\(userId.uuidString.lowercased())/\(uniqueFileName)"
        
        print("📦 Uploading file:")
        print("   Original name: \(fileName)")
        print("   Extension: \(fileExtension)")
        print("   Storage path: \(storagePath)")
        print("   File size: \(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file))")
        
        // Upload to storage
        let options = FileOptions(
            cacheControl: "3600",
            contentType: mimeType(for: fileExtension),
            upsert: true
        )
        
        do {
        try await client.storage
            .from("medical-vault")
            .upload(
                    storagePath,
                    data: fileData,
                    options: options
                )
        } catch {
            print("📦 Storage upload failed for path: \(storagePath), error: \(error)")
            throw SupabaseError.storageError("Unable to upload to bucket medical-vault: \(error.localizedDescription)")
        }
        
        // Ensure title is never empty - use folderName, metadata.name, or fileName
        let documentTitle: String = {
            if let folderName = metadata.folderName, !folderName.isEmpty {
                return folderName
            } else if !metadata.name.isEmpty {
                return metadata.name
            } else {
                // Use fileName without extension as fallback
                return (fileName as NSString).deletingPathExtension
            }
        }()
        
        // Create document record with metadata
        let document = MedicalDocument(
            userId: userId,
            title: documentTitle,
            category: category,
            fileType: fileExtension.uppercased(),
            fileUrl: storagePath,
            fileSize: Int64(fileData.count),
            uploadedAt: Date(),
            notes: metadata.description,
            createdAt: Date(),
            description: metadata.description,
            folderName: metadata.folderName,
            documentDate: metadata.documentDate,
            reminderDate: metadata.reminderDate,
            appointmentDate: metadata.appointmentDate,
            doctorName: metadata.doctorName,
            location: metadata.location,
            tags: metadata.tags.isEmpty ? nil : metadata.tags,
            updatedAt: Date()
        )
        
        print("📄 Creating document record:")
        print("   Title: \(documentTitle)")
        print("   Category: \(category)")
        print("   File Type: \(fileExtension.uppercased())")
        print("   Folder Name: \(metadata.folderName ?? "nil")")
        print("   Description: \(metadata.description ?? "nil")")
        print("   Doctor: \(metadata.doctorName ?? "nil")")
        print("   Location: \(metadata.location ?? "nil")")
        print("   Document Date: \(metadata.documentDate?.description ?? "nil")")
        print("   Tags: \(metadata.tags)")
        
        do {
        let inserted: MedicalDocument = try await client
            .from("medical_documents")
            .insert(document)
            .select()
            .single()
            .execute()
            .value
        
            print("✅ Document uploaded successfully: \(inserted.id?.uuidString ?? "unknown")")
        return inserted
        } catch {
            print("❌ Database insert failed for document: \(error)")
            // Try to clean up the uploaded file if database insert fails
            try? await client.storage
                .from("medical-vault")
                .remove(paths: [storagePath])
            
            throw SupabaseError.databaseError("Failed to create document record: \(error.localizedDescription)")
        }
    }
    
    /// Updates a medical document's metadata
    func updateDocument(_ document: MedicalDocument, metadata: DocumentMetadata) async throws -> MedicalDocument {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        guard let docId = document.id else {
            throw SupabaseError.invalidData
        }
        
        // Create update struct with only changed fields
        // Note: documentDate uses String for PostgreSQL date type (YYYY-MM-DD format)
        struct DocumentUpdate: Codable {
            var title: String?
            var description: String?
            var folderName: String?
            var documentDate: String?  // Date-only format for PostgreSQL date type
            var reminderDate: Date?
            var appointmentDate: Date?
            var doctorName: String?
            var location: String?
            var tags: [String]?
            
            enum CodingKeys: String, CodingKey {
                case title
                case description
                case folderName = "folder_name"
                case documentDate = "document_date"
                case reminderDate = "reminder_date"
                case appointmentDate = "appointment_date"
                case doctorName = "doctor_name"
                case location
                case tags
            }
        }
        
        // Format document_date as date-only string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        var update = DocumentUpdate()
        if !metadata.name.isEmpty {
            update.title = metadata.name
        }
        update.description = metadata.description
        update.folderName = metadata.folderName
        update.documentDate = metadata.documentDate.map { dateFormatter.string(from: $0) }
        update.reminderDate = metadata.reminderDate
        update.appointmentDate = metadata.appointmentDate
        update.doctorName = metadata.doctorName
        update.location = metadata.location
        update.tags = metadata.tags.isEmpty ? nil : metadata.tags
        
        // Update document
        let updated: MedicalDocument = try await client
            .from("medical_documents")
            .update(update)
            .eq("id", value: docId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return updated
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
        do {
        let data = try await client.storage
            .from("medical-vault")
            .download(path: storagePath)
        
            guard !data.isEmpty else {
                throw SupabaseError.storageError("Downloaded file is empty")
            }
            
        return data
        } catch {
            // Provide more specific error messages
            if let supabaseError = error as? StorageError {
                throw SupabaseError.storageError("Failed to download: \(supabaseError.message ?? supabaseError.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Gets a signed URL for a document (valid for specified seconds)
    func getSignedURL(storagePath: String, expiresIn: Int = 3600) async throws -> URL {
        let signedURL = try await client.storage
            .from("medical-vault")
            .createSignedURL(path: storagePath, expiresIn: expiresIn)
        
        return signedURL
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
    
    /// Sanitizes filename for storage - removes invalid characters
    private func sanitizeFileName(_ fileName: String) -> String {
        // Remove or replace invalid characters for storage keys
        var sanitized = fileName
        
        // Replace spaces with underscores
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        
        // Remove or replace invalid characters: : / \ ? * | " < >
        let invalidChars = [":", "/", "\\", "?", "*", "|", "\"", "<", ">"]
        for char in invalidChars {
            sanitized = sanitized.replacingOccurrences(of: char, with: "_")
        }
        
        // Remove any remaining non-alphanumeric characters except dots, dashes, and underscores
        sanitized = sanitized.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).inverted)
            .joined(separator: "_")
        
        // Remove consecutive underscores
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        
        // Remove leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        // Ensure it's not empty
        if sanitized.isEmpty {
            sanitized = "file"
        }
        
        // Limit length to 200 characters (storage key limit)
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }
        
        return sanitized
    }
    
    /// Helper to get MIME type from extension
    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        // Documents
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt":
            return "text/plain"
        case "rtf":
            return "application/rtf"
        case "csv":
            return "text/csv"
        case "xml":
            return "application/xml"
        case "json":
            return "application/json"
        case "html", "htm":
            return "text/html"
        // Images
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        case "webp":
            return "image/webp"
        case "bmp":
            return "image/bmp"
        case "tiff", "tif":
            return "image/tiff"
        case "svg":
            return "image/svg+xml"
        // Archives
        case "zip":
            return "application/zip"
        case "rar":
            return "application/x-rar-compressed"
        case "7z":
            return "application/x-7z-compressed"
        case "tar":
            return "application/x-tar"
        case "gz":
            return "application/gzip"
        // Medical/Health specific
        case "dcm", "dicom":
            return "application/dicom"
        case "hl7":
            return "application/hl7"
        // Default
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
    
    // MARK: - Hydration Sync
    
    /// Syncs a hydration entry to Supabase
    func syncHydrationEntry(_ entry: HydrationEntry) async throws -> HydrationEntryRecord {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let record = HydrationEntryRecord(from: entry, userId: userId)
        
        let inserted: HydrationEntryRecord = try await client
            .from("hydration_entries")
            .upsert(record, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
        
        return inserted
    }
    
    /// Syncs multiple hydration entries to Supabase
    func syncHydrationEntries(_ entries: [HydrationEntry]) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let records = entries.map { HydrationEntryRecord(from: $0, userId: userId) }
        
        try await client
            .from("hydration_entries")
            .upsert(records, onConflict: "id")
            .execute()
    }
    
    /// Fetches hydration entries for a date range
    func fetchHydrationEntries(from startDate: Date, to endDate: Date) async throws -> [HydrationEntry] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: startDate)
        let toString = dateFormatter.string(from: endDate)
        
        let records: [HydrationEntryRecord] = try await client
            .from("hydration_entries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: fromString)
            .lte("logged_at", value: toString)
            .order("logged_at", ascending: false)
            .execute()
            .value
        
        return records.map { $0.toHydrationEntry() }
    }
    
    /// Fetches today's hydration entries
    func fetchTodayHydrationEntries() async throws -> [HydrationEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        return try await fetchHydrationEntries(from: startOfDay, to: endOfDay)
    }
    
    /// Deletes a hydration entry
    func deleteHydrationEntry(id: UUID) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        try await client
            .from("hydration_entries")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
    
    /// Saves hydration preferences to Supabase
    func saveHydrationPreferences(_ preferences: HydrationPreferences) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        var prefsToSave = preferences
        prefsToSave.userId = userId
        prefsToSave.updatedAt = Date()
        
        try await client
            .from("hydration_preferences")
            .upsert(prefsToSave, onConflict: "user_id")
            .execute()
    }
    
    /// Fetches hydration preferences from Supabase
    func fetchHydrationPreferences() async throws -> HydrationPreferences? {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let records: [HydrationPreferences] = try await client
            .from("hydration_preferences")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        return records.first
    }
    
    /// Gets daily hydration stats for a date range (for charts)
    func getHydrationStats(days: Int = 7) async throws -> [(date: Date, totalMl: Int)] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: startDate)
        
        let records: [HydrationEntryRecord] = try await client
            .from("hydration_entries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: fromString)
            .order("logged_at", ascending: true)
            .execute()
            .value
        
        // Group by date
        var dailyTotals: [Date: Int] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.loggedAt)
            dailyTotals[day, default: 0] += record.amountMl
        }
        
        // Fill in missing days with 0
        var result: [(date: Date, totalMl: Int)] = []
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let day = calendar.startOfDay(for: date)
                result.append((day, dailyTotals[day] ?? 0))
            }
        }
        
        return result
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
    
    // New metadata fields
    let description: String?
    let folderName: String?
    let documentDate: Date?
    let reminderDate: Date?
    let appointmentDate: Date?
    let doctorName: String?
    let location: String?
    let tags: [String]?
    let updatedAt: Date?
    
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
        case description
        case folderName = "folder_name"
        case documentDate = "document_date"
        case reminderDate = "reminder_date"
        case appointmentDate = "appointment_date"
        case doctorName = "doctor_name"
        case location
        case tags
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID? = nil,
        userId: UUID,
        title: String,
        category: String,
        fileType: String,
        fileUrl: String,
        fileSize: Int64,
        uploadedAt: Date? = Date(),
        notes: String? = nil,
        createdAt: Date? = Date(),
        description: String? = nil,
        folderName: String? = nil,
        documentDate: Date? = nil,
        reminderDate: Date? = nil,
        appointmentDate: Date? = nil,
        doctorName: String? = nil,
        location: String? = nil,
        tags: [String]? = nil,
        updatedAt: Date? = nil
    ) {
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
        self.description = description
        self.folderName = folderName
        self.documentDate = documentDate
        self.reminderDate = reminderDate
        self.appointmentDate = appointmentDate
        self.doctorName = doctorName
        self.location = location
        self.tags = tags
        self.updatedAt = updatedAt
    }
    
    // Custom decoder to handle both date-only and datetime formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(String.self, forKey: .category)
        fileType = try container.decode(String.self, forKey: .fileType)
        fileUrl = try container.decode(String.self, forKey: .fileUrl)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        folderName = try container.decodeIfPresent(String.self, forKey: .folderName)
        doctorName = try container.decodeIfPresent(String.self, forKey: .doctorName)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        
        // Decode dates with flexible format handling
        uploadedAt = Self.decodeFlexibleDate(from: container, forKey: .uploadedAt)
        createdAt = Self.decodeFlexibleDate(from: container, forKey: .createdAt)
        documentDate = Self.decodeFlexibleDate(from: container, forKey: .documentDate)
        reminderDate = Self.decodeFlexibleDate(from: container, forKey: .reminderDate)
        appointmentDate = Self.decodeFlexibleDate(from: container, forKey: .appointmentDate)
        updatedAt = Self.decodeFlexibleDate(from: container, forKey: .updatedAt)
    }
    
    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // Try decoding as Date first (ISO8601 full format)
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        
        // Try decoding as string and parse manually
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else {
            return nil
        }
        
        // Try ISO8601 with fractional seconds
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try date-only format (YYYY-MM-DD)
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    // Custom encoder to handle date-only fields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(fileType, forKey: .fileType)
        try container.encode(fileUrl, forKey: .fileUrl)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(folderName, forKey: .folderName)
        try container.encodeIfPresent(doctorName, forKey: .doctorName)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(tags, forKey: .tags)
        
        // Encode timestamps normally
        try container.encodeIfPresent(uploadedAt, forKey: .uploadedAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(reminderDate, forKey: .reminderDate)
        try container.encodeIfPresent(appointmentDate, forKey: .appointmentDate)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        
        // Encode document_date as date-only string (PostgreSQL date type)
        if let docDate = documentDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            try container.encode(formatter.string(from: docDate), forKey: .documentDate)
        } else {
            try container.encodeNil(forKey: .documentDate)
        }
    }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    case storageError(String)
    case uploadFailed(String)
    case databaseError(String)
    
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
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - Push Notification Token Management

extension SupabaseManager {
    
    /// Register device push token with Supabase
    func registerPushToken(
        deviceToken: String,
        deviceName: String,
        deviceModel: String,
        osVersion: String,
        appVersion: String
    ) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let record = PushTokenRecord(
            userId: userId,
            deviceToken: deviceToken,
            deviceName: deviceName,
            deviceModel: deviceModel,
            osVersion: osVersion,
            appVersion: appVersion,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Upsert: update if exists, insert if new
        let _: PushTokenRecord = try await client
            .from("push_tokens")
            .upsert(record)
            .execute()
            .value
        
        print("📲 SupabaseManager: Push token registered successfully")
    }
    
    /// Remove device push token
    func removePushToken(deviceToken: String) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        try await client
            .from("push_tokens")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("device_token", value: deviceToken)
            .execute()
        
        print("📲 SupabaseManager: Push token removed")
    }
}

// MARK: - Medication Sync

extension SupabaseManager {
    
    /// Sync a medication to Supabase
    func syncMedication(_ medication: Medication) async throws -> MedicationRecord {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        var medicationToSync = medication
        medicationToSync.userId = userId
        medicationToSync.updatedAt = Date()
        
        let record = MedicationRecord(from: medicationToSync)
        
        let inserted: MedicationRecord = try await client
            .from("medications")
            .upsert(record, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
        
        print("💊 SupabaseManager: Synced medication '\(medication.name)'")
        return inserted
    }
    
    /// Sync multiple medications
    func syncMedications(_ medications: [Medication]) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let records = medications.map { medication -> MedicationRecord in
            var med = medication
            med.userId = userId
            med.updatedAt = Date()
            return MedicationRecord(from: med)
        }
        
        try await client
            .from("medications")
            .upsert(records, onConflict: "id")
            .execute()
        
        print("💊 SupabaseManager: Synced \(medications.count) medications")
    }
    
    /// Fetch user's medications from Supabase
    func fetchUserMedications() async throws -> [Medication] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let records: [MedicationRecord] = try await client
            .from("medications")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("💊 SupabaseManager: Fetched \(records.count) medications")
        return records.map { $0.toMedication() }
    }
    
    /// Delete a medication from Supabase
    func deleteMedicationRecord(id: UUID) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        try await client
            .from("medications")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("💊 SupabaseManager: Deleted medication record")
    }
    
    /// Sync medication adherence record
    func syncMedicationAdherence(_ adherence: MedicationAdherence) async throws -> MedicationAdherenceRecord {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let record = MedicationAdherenceRecord(from: adherence, userId: userId)
        
        let inserted: MedicationAdherenceRecord = try await client
            .from("medication_adherence")
            .upsert(record, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
        
        print("💊 SupabaseManager: Synced adherence record")
        return inserted
    }
    
    /// Sync multiple adherence records
    func syncMedicationAdherences(_ adherences: [MedicationAdherence]) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let records = adherences.map { MedicationAdherenceRecord(from: $0, userId: userId) }
        
        try await client
            .from("medication_adherence")
            .upsert(records, onConflict: "id")
            .execute()
        
        print("💊 SupabaseManager: Synced \(adherences.count) adherence records")
    }
    
    /// Fetch adherence records for a date range
    func fetchMedicationAdherence(from startDate: Date, to endDate: Date) async throws -> [MedicationAdherence] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: startDate)
        let toString = dateFormatter.string(from: endDate)
        
        let records: [MedicationAdherenceRecord] = try await client
            .from("medication_adherence")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("scheduled_time", value: fromString)
            .lte("scheduled_time", value: toString)
            .order("scheduled_time", ascending: false)
            .execute()
            .value
        
        print("💊 SupabaseManager: Fetched \(records.count) adherence records")
        return records.map { $0.toMedicationAdherence() }
    }
    
    /// Fetch today's adherence records
    func fetchTodayMedicationAdherence() async throws -> [MedicationAdherence] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        return try await fetchMedicationAdherence(from: startOfDay, to: endOfDay)
    }
    
    /// Get medication adherence statistics for a period
    func getMedicationAdherenceStats(days: Int = 7) async throws -> [(date: Date, adherenceRate: Double)] {
        guard let userId = try? await client.auth.session.user.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: startDate)
        
        let records: [MedicationAdherenceRecord] = try await client
            .from("medication_adherence")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("scheduled_time", value: fromString)
            .order("scheduled_time", ascending: true)
            .execute()
            .value
        
        // Group by date and calculate adherence
        var dailyStats: [Date: (taken: Int, total: Int)] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.scheduledTime)
            let stats = dailyStats[day] ?? (taken: 0, total: 0)
            dailyStats[day] = (
                taken: stats.taken + (record.status == "Taken" ? 1 : 0),
                total: stats.total + 1
            )
        }
        
        // Fill in missing days with 0
        var result: [(date: Date, adherenceRate: Double)] = []
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let day = calendar.startOfDay(for: date)
                if let stats = dailyStats[day], stats.total > 0 {
                    let rate = Double(stats.taken) / Double(stats.total)
                    result.append((day, rate))
                } else {
                    result.append((day, 0.0))
                }
            }
        }
        
        return result
    }
}


