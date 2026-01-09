//
//  HealthProfileService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//

import Foundation
import Supabase

// MARK: - Health Profile Service Protocol

protocol HealthProfileServiceProtocol {
    func saveHealthProfile(_ profile: HealthProfile) async throws
    func fetchHealthProfile() async throws -> HealthProfile?
    func hasHealthProfile() async throws -> Bool
}

// MARK: - Health Profile Service Implementation

final class HealthProfileService: HealthProfileServiceProtocol {
    
    static let shared = HealthProfileService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseManager.shared.client
    }
    
    // MARK: - Save Health Profile
    
    func saveHealthProfile(_ profile: HealthProfile) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw HealthProfileError.notAuthenticated
        }
        
        // Ensure profile has correct user ID
        let profileToSave = HealthProfile(
            id: profile.id,
            userId: userId,
            fullName: profile.fullName,
            gender: profile.gender,
            dateOfBirth: profile.dateOfBirth,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            bloodType: profile.bloodType,
            createdAt: profile.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        // Check if profile exists
        let existing: [HealthProfile] = try await client
            .from("health_profiles")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        if existing.isEmpty {
            // Insert new profile
            let _: HealthProfile = try await client
                .from("health_profiles")
                .insert(profileToSave)
                .select()
                .single()
                .execute()
                .value
        } else {
            // Update existing profile - use the existing ID
            let existingProfile = existing.first!
            let updatedProfile = HealthProfile(
                id: existingProfile.id,
                userId: userId,
                fullName: profileToSave.fullName,
                gender: profileToSave.gender,
                dateOfBirth: profileToSave.dateOfBirth,
                heightCm: profileToSave.heightCm,
                weightKg: profileToSave.weightKg,
                bloodType: profileToSave.bloodType,
                createdAt: existingProfile.createdAt,
                updatedAt: Date()
            )
            
            let _: HealthProfile = try await client
                .from("health_profiles")
                .update(updatedProfile)
                .eq("user_id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
        
        // CRITICAL: Also update the users table with full_name and mark onboarding complete
        struct UserUpdate: Encodable {
            let full_name: String
            let onboarding_completed: Bool
            let updated_at: Date
        }
        
        let userUpdate = UserUpdate(
            full_name: profile.fullName,
            onboarding_completed: true,
            updated_at: Date()
        )
        
        // Update users table
        try await client
            .from("users")
            .update(userUpdate)
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ HealthProfileService: Updated users table with name '\(profile.fullName)' and onboarding_completed=true")
    }
    
    // MARK: - Fetch Health Profile
    
    func fetchHealthProfile() async throws -> HealthProfile? {
        // Get the current session
        let session = try await client.auth.session
        let userId = session.user.id
        
        print("📋 HealthProfileService: Fetching profile for user \(userId)")
        
        let profiles: [HealthProfile] = try await client
            .from("health_profiles")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        if let profile = profiles.first {
            print("📋 HealthProfileService: Loaded profile for \(profile.fullName)")
        } else {
            print("📋 HealthProfileService: No profile found")
        }
        
        return profiles.first
    }
    
    // MARK: - Check if Health Profile Exists
    
    func hasHealthProfile() async throws -> Bool {
        // Get the current session
        let session = try await client.auth.session
        let userId = session.user.id
        
        print("📋 HealthProfileService: Checking profile for user \(userId)")
        
        // IMPORTANT: We only select `id` here, so decode into a lightweight type.
        struct HealthProfileIdRow: Codable {
            let id: UUID
        }
        
        let profiles: [HealthProfileIdRow] = try await client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        print("📋 HealthProfileService: Found \(profiles.count) profile(s)")
        return !profiles.isEmpty
    }
}

// MARK: - Health Profile Errors

enum HealthProfileError: LocalizedError {
    case notAuthenticated
    case invalidData
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid health profile data"
        case .saveFailed(let message):
            return "Failed to save health profile: \(message)"
        }
    }
}
