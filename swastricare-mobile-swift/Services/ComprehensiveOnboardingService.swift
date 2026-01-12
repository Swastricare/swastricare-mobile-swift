//
//  ComprehensiveOnboardingService.swift
//  swastricare-mobile-swift
//
//  Comprehensive Onboarding Service
//

import Foundation
import Supabase

// MARK: - Protocol

protocol ComprehensiveOnboardingServiceProtocol {
    func saveOnboardingData(_ data: [String: Any]) async throws
    func fetchOnboardingData() async throws -> [String: Any]?
}

// MARK: - Implementation

final class ComprehensiveOnboardingService: ComprehensiveOnboardingServiceProtocol {
    
    static let shared = ComprehensiveOnboardingService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseManager.shared.client
    }
    
    // MARK: - Save Onboarding Data
    
    func saveOnboardingData(_ data: [String: Any]) async throws {
        // #region agent log
        let logEntry1: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "A", "location": "ComprehensiveOnboardingService.swift:32", "message": "saveOnboardingData entry", "data": ["timestamp": Date().timeIntervalSince1970], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry1), let logString = String(data: logData, encoding: .utf8) {
            try? logString.write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        guard let session = try? await client.auth.session else {
            throw ComprehensiveOnboardingError.notAuthenticated
        }
        
        let userId = session.user.id
        let userEmail = session.user.email
        
        // #region agent log
        let logEntry2: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "E", "location": "ComprehensiveOnboardingService.swift:38", "message": "userId extracted", "data": ["userId": userId.uuidString, "userEmail": userEmail ?? "nil"], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry2), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        // Ensure user exists in users table (required for foreign key constraint)
        do {
            try await ensureUserExists(userId: userId, email: userEmail, fullName: data["full_name"] as? String)
            
            // #region agent log
            let logEntry3: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "A", "location": "ComprehensiveOnboardingService.swift:45", "message": "ensureUserExists completed successfully", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
            if let logData = try? JSONSerialization.data(withJSONObject: logEntry3), let logString = String(data: logData, encoding: .utf8) {
                try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
            }
            // #endregion
        } catch {
            // #region agent log
            let logEntry4: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "A", "location": "ComprehensiveOnboardingService.swift:52", "message": "ensureUserExists failed", "data": ["userId": userId.uuidString, "error": error.localizedDescription], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
            if let logData = try? JSONSerialization.data(withJSONObject: logEntry4), let logString = String(data: logData, encoding: .utf8) {
                try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
            }
            // #endregion
            throw error
        }
        
        // Prepare update data for health_profiles table
        // Use a dictionary approach for flexibility with JSONB
        var updateData: [String: Any] = [
            "updated_at": Date()
        ]
        
        // Add all fields if they exist
        if let value = data["location_type"] { updateData["location_type"] = value }
        if let value = data["city"] { updateData["city"] = value }
        if let value = data["latitude"] { updateData["latitude"] = value }
        if let value = data["longitude"] { updateData["longitude"] = value }
        if let value = data["body_goal"] { updateData["body_goal"] = value }
        if let value = data["primary_goal"] { updateData["primary_goal"] = value }
        if let value = data["tracking_preferences"] { updateData["tracking_preferences"] = value }
        if let value = data["activity_level"] { updateData["activity_level"] = value }
        if let value = data["sleep_duration"] { updateData["sleep_duration"] = value }
        if let value = data["diet_type"] { updateData["diet_type"] = value }
        if let value = data["water_intake"] { updateData["water_intake"] = value }
        if let value = data["existing_conditions"] { updateData["existing_conditions"] = value }
        if let value = data["allergies"] { updateData["allergies"] = value }
        if let value = data["family_history"] { updateData["family_history"] = value }
        if let value = data["smoking"] { updateData["smoking"] = value }
        if let value = data["alcohol"] { updateData["alcohol"] = value }
        if let value = data["medical_alerts"] { updateData["medical_alerts"] = value }
        if let value = data["has_regular_medication"] { updateData["has_regular_medication"] = value }
        if let value = data["medications"] { updateData["medications"] = value }
        
        // Check if health profile exists
        struct ExistingProfile: Decodable {
            let id: UUID
        }
        
        // #region agent log
        let logEntry5: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "B", "location": "ComprehensiveOnboardingService.swift:75", "message": "Before checking existing health profile", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry5), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        let existing: [ExistingProfile]? = try? await client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        // #region agent log
        let logEntry6: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "B", "location": "ComprehensiveOnboardingService.swift:85", "message": "After checking existing health profile", "data": ["userId": userId.uuidString, "existingCount": existing?.count ?? -1], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry6), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        // Define MedicationItem struct once at function scope
        struct MedicationItem: Codable {
            let name: String
            let dosage: String
            let schedule: String
        }
        
        // Convert medications array to Encodable format
        var medicationsArray: [MedicationItem]? = nil
        if let meds = data["medications"] as? [[String: Any]] {
            medicationsArray = meds.compactMap { med in
                guard let name = med["name"] as? String,
                      let dosage = med["dosage"] as? String,
                      let schedule = med["schedule"] as? String else {
                    return nil
                }
                return MedicationItem(name: name, dosage: dosage, schedule: schedule)
            }
        }
        
        if let existing = existing, !existing.isEmpty {
            // Update existing health profile
            struct UpdateRow: Encodable {
                let location_type: String?
                let city: String?
                let latitude: Double?
                let longitude: Double?
                let body_goal: String?
                let primary_goal: String?
                let tracking_preferences: [String]?
                let activity_level: String?
                let sleep_duration: String?
                let diet_type: String?
                let water_intake: String?
                let existing_conditions: [String]?
                let allergies: [String]?
                let family_history: [String]?
                let smoking: String?
                let alcohol: String?
                let medical_alerts: [String]?
                let has_regular_medication: Bool?
                let medications: [MedicationItem]? // JSONB array
                let updated_at: Date
            }
            
            let updateRow = UpdateRow(
                location_type: data["location_type"] as? String,
                city: data["city"] as? String,
                latitude: data["latitude"] as? Double,
                longitude: data["longitude"] as? Double,
                body_goal: data["body_goal"] as? String,
                primary_goal: data["primary_goal"] as? String,
                tracking_preferences: data["tracking_preferences"] as? [String],
                activity_level: data["activity_level"] as? String,
                sleep_duration: data["sleep_duration"] as? String,
                diet_type: data["diet_type"] as? String,
                water_intake: data["water_intake"] as? String,
                existing_conditions: data["existing_conditions"] as? [String],
                allergies: data["allergies"] as? [String],
                family_history: data["family_history"] as? [String],
                smoking: data["smoking"] as? String,
                alcohol: data["alcohol"] as? String,
                medical_alerts: data["medical_alerts"] as? [String],
                has_regular_medication: data["has_regular_medication"] as? Bool,
                medications: medicationsArray,
                updated_at: Date()
            )
            
            // #region agent log
            let logEntry7: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "D", "location": "ComprehensiveOnboardingService.swift:155", "message": "Before updating health profile", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
            if let logData = try? JSONSerialization.data(withJSONObject: logEntry7), let logString = String(data: logData, encoding: .utf8) {
                try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
            }
            // #endregion
            
            try await client
                .from("health_profiles")
                .update(updateRow)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } else {
            // #region agent log
            let logEntry8: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "D", "location": "ComprehensiveOnboardingService.swift:163", "message": "Before inserting new health profile", "data": ["userId": userId.uuidString, "fullName": data["full_name"] as? String ?? "nil"], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
            if let logData = try? JSONSerialization.data(withJSONObject: logEntry8), let logString = String(data: logData, encoding: .utf8) {
                try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
            }
            // #endregion
            // Create new health profile with onboarding data
            // Note: Basic fields (full_name, gender, etc.) should be set via HealthProfileService first
            struct NewProfile: Encodable {
                let user_id: UUID
                let full_name: String
                let location_type: String?
                let city: String?
                let latitude: Double?
                let longitude: Double?
                let body_goal: String?
                let primary_goal: String?
                let tracking_preferences: [String]?
                let activity_level: String?
                let sleep_duration: String?
                let diet_type: String?
                let water_intake: String?
                let existing_conditions: [String]?
                let allergies: [String]?
                let family_history: [String]?
                let smoking: String?
                let alcohol: String?
                let medical_alerts: [String]?
                let has_regular_medication: Bool?
                let medications: [MedicationItem]? // JSONB array
                let created_at: Date
                let updated_at: Date
            }
            
            let newProfile = NewProfile(
                user_id: userId,
                full_name: data["full_name"] as? String ?? "",
                location_type: data["location_type"] as? String,
                city: data["city"] as? String,
                latitude: data["latitude"] as? Double,
                longitude: data["longitude"] as? Double,
                body_goal: data["body_goal"] as? String,
                primary_goal: data["primary_goal"] as? String,
                tracking_preferences: data["tracking_preferences"] as? [String],
                activity_level: data["activity_level"] as? String,
                sleep_duration: data["sleep_duration"] as? String,
                diet_type: data["diet_type"] as? String,
                water_intake: data["water_intake"] as? String,
                existing_conditions: data["existing_conditions"] as? [String],
                allergies: data["allergies"] as? [String],
                family_history: data["family_history"] as? [String],
                smoking: data["smoking"] as? String,
                alcohol: data["alcohol"] as? String,
                medical_alerts: data["medical_alerts"] as? [String],
                has_regular_medication: data["has_regular_medication"] as? Bool,
                medications: medicationsArray,
                created_at: Date(),
                updated_at: Date()
            )
            
            do {
                try await client
                    .from("health_profiles")
                    .insert(newProfile)
                    .execute()
                
                // #region agent log
                let logEntry9: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "D", "location": "ComprehensiveOnboardingService.swift:218", "message": "Health profile insert succeeded", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
                if let logData = try? JSONSerialization.data(withJSONObject: logEntry9), let logString = String(data: logData, encoding: .utf8) {
                    try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
                }
                // #endregion
            } catch {
                // #region agent log
                let logEntry10: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "D", "location": "ComprehensiveOnboardingService.swift:225", "message": "Health profile insert failed", "data": ["userId": userId.uuidString, "error": error.localizedDescription, "errorType": String(describing: type(of: error))], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
                if let logData = try? JSONSerialization.data(withJSONObject: logEntry10), let logString = String(data: logData, encoding: .utf8) {
                    try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
                }
                // #endregion
                throw error
            }
        }
        
        print("✅ ComprehensiveOnboardingService: Saved onboarding data to health_profiles for user \(userId)")
    }
    
    // MARK: - Fetch Onboarding Data
    
    func fetchOnboardingData() async throws -> [String: Any]? {
        guard let userId = try? await client.auth.session.user.id else {
            throw ComprehensiveOnboardingError.notAuthenticated
        }
        
        // Fetch onboarding data from health_profiles
        struct MedicationItemRow: Decodable {
            let name: String
            let dosage: String
            let schedule: String
        }
        
        struct OnboardingDataRow: Decodable {
            let location_type: String?
            let city: String?
            let latitude: Double?
            let longitude: Double?
            let body_goal: String?
            let primary_goal: String?
            let tracking_preferences: [String]?
            let activity_level: String?
            let sleep_duration: String?
            let diet_type: String?
            let water_intake: String?
            let existing_conditions: [String]?
            let allergies: [String]?
            let family_history: [String]?
            let smoking: String?
            let alcohol: String?
            let medical_alerts: [String]?
            let has_regular_medication: Bool?
            let medications: [MedicationItemRow]? // JSONB array
        }
        
        let rows: [OnboardingDataRow] = try await client
            .from("health_profiles")
            .select("location_type, city, latitude, longitude, body_goal, primary_goal, tracking_preferences, activity_level, sleep_duration, diet_type, water_intake, existing_conditions, allergies, family_history, smoking, alcohol, medical_alerts, has_regular_medication, medications")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        guard let row = rows.first else {
            return nil
        }
        
        // Convert to dictionary
        var result: [String: Any] = [:]
        if let value = row.location_type { result["location_type"] = value }
        if let value = row.city { result["city"] = value }
        if let value = row.latitude { result["latitude"] = value }
        if let value = row.longitude { result["longitude"] = value }
        if let value = row.body_goal { result["body_goal"] = value }
        if let value = row.primary_goal { result["primary_goal"] = value }
        if let value = row.tracking_preferences { result["tracking_preferences"] = value }
        if let value = row.activity_level { result["activity_level"] = value }
        if let value = row.sleep_duration { result["sleep_duration"] = value }
        if let value = row.diet_type { result["diet_type"] = value }
        if let value = row.water_intake { result["water_intake"] = value }
        if let value = row.existing_conditions { result["existing_conditions"] = value }
        if let value = row.allergies { result["allergies"] = value }
        if let value = row.family_history { result["family_history"] = value }
        if let value = row.smoking { result["smoking"] = value }
        if let value = row.alcohol { result["alcohol"] = value }
        if let value = row.medical_alerts { result["medical_alerts"] = value }
        if let value = row.has_regular_medication { result["has_regular_medication"] = value }
        // Convert medications array back to dictionary format
        if let meds = row.medications {
            result["medications"] = meds.map { [
                "name": $0.name,
                "dosage": $0.dosage,
                "schedule": $0.schedule
            ]}
        }
        
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Helper: Ensure User Exists
    
    private func ensureUserExists(userId: UUID, email: String?, fullName: String?) async throws {
        // #region agent log
        let logEntry11: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "A", "location": "ComprehensiveOnboardingService.swift:302", "message": "ensureUserExists entry", "data": ["userId": userId.uuidString, "email": email ?? "nil"], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry11), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        struct UserRow: Decodable {
            let id: UUID
        }
        
        // Check if user exists
        // #region agent log
        let logEntry12: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "B", "location": "ComprehensiveOnboardingService.swift:312", "message": "Before user existence check", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry12), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        let existing: [UserRow] = try await client
            .from("users")
            .select("id")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        // #region agent log
        let logEntry13: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "B", "location": "ComprehensiveOnboardingService.swift:320", "message": "After user existence check", "data": ["userId": userId.uuidString, "existingCount": existing.count, "userExists": !existing.isEmpty], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
        if let logData = try? JSONSerialization.data(withJSONObject: logEntry13), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
        }
        // #endregion
        
        if existing.isEmpty {
            // #region agent log
            let logEntry14: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "ComprehensiveOnboardingService.swift:326", "message": "User does not exist, attempting insert", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
            if let logData = try? JSONSerialization.data(withJSONObject: logEntry14), let logString = String(data: logData, encoding: .utf8) {
                try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
            }
            // #endregion
            // Create user record if it doesn't exist
            struct NewUser: Encodable {
                let id: UUID
                let email: String?
                let full_name: String?
                let created_at: Date
                let updated_at: Date
            }
            
            let newUser = NewUser(
                id: userId,
                email: email,
                full_name: fullName,
                created_at: Date(),
                updated_at: Date()
            )
            
            // Try insert - if it fails due to race condition, verify user exists
            do {
                // #region agent log
                let logEntry15: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "ComprehensiveOnboardingService.swift:340", "message": "Before user insert", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
                if let logData = try? JSONSerialization.data(withJSONObject: logEntry15), let logString = String(data: logData, encoding: .utf8) {
                    try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
                }
                // #endregion
                
                try await client
                    .from("users")
                    .insert(newUser)
                    .execute()
                
                // #region agent log
                let logEntry16: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "ComprehensiveOnboardingService.swift:348", "message": "User insert succeeded", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
                if let logData = try? JSONSerialization.data(withJSONObject: logEntry16), let logString = String(data: logData, encoding: .utf8) {
                    try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
                }
                // #endregion
                
                print("✅ ComprehensiveOnboardingService: Created user record for \(userId)")
            } catch {
                // #region agent log
                let logEntry17: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "ComprehensiveOnboardingService.swift:356", "message": "User insert failed", "data": ["userId": userId.uuidString, "error": error.localizedDescription, "errorType": String(describing: type(of: error))], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
                if let logData = try? JSONSerialization.data(withJSONObject: logEntry17), let logString = String(data: logData, encoding: .utf8) {
                    try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
                }
                // #endregion
                
                // If insert fails (e.g., user was created by another process), verify
                print("⚠️ ComprehensiveOnboardingService: User insert failed, verifying: \(error)")
                
                // Verify user exists now (might have been created by another process)
                let verify: [UserRow] = try await client
                    .from("users")
                    .select("id")
                    .eq("id", value: userId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                
                // #region agent log
                let logEntry18: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "D", "location": "ComprehensiveOnboardingService.swift:370", "message": "After verify check", "data": ["userId": userId.uuidString, "verifyCount": verify.count], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
                if let logData = try? JSONSerialization.data(withJSONObject: logEntry18), let logString = String(data: logData, encoding: .utf8) {
                    try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
                }
                // #endregion
                
                if verify.isEmpty {
                    // User still doesn't exist, this is a real error
                    print("❌ ComprehensiveOnboardingService: User creation failed and user still doesn't exist")
                    throw ComprehensiveOnboardingError.userCreationFailed
                } else {
                    print("✅ ComprehensiveOnboardingService: User exists (created by another process)")
                }
            }
        } else {
            // #region agent log
            let logEntry19: [String: Any] = ["sessionId": "debug-session", "runId": "run1", "hypothesisId": "A", "location": "ComprehensiveOnboardingService.swift:384", "message": "User already exists", "data": ["userId": userId.uuidString], "timestamp": Int64(Date().timeIntervalSince1970 * 1000)]
            if let logData = try? JSONSerialization.data(withJSONObject: logEntry19), let logString = String(data: logData, encoding: .utf8) {
                try? (logString + "\n").write(toFile: "/Users/syamsundar/Onwords/swastricare-mobile-swift/.cursor/debug.log", atomically: false, encoding: .utf8)
            }
            // #endregion
            print("✅ ComprehensiveOnboardingService: User \(userId) already exists")
        }
    }
}
