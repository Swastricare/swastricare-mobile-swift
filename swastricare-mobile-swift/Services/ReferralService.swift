//
//  ReferralService.swift
//  swastricare-mobile-swift
//

import Foundation
import Supabase

// MARK: - Referral Service Protocol

protocol ReferralServiceProtocol {
    func getOrCreateReferralCode() async throws -> String
    func checkAIUnlocked() async throws -> Bool
    func applyReferralCode(_ code: String) async throws -> Bool
}

// MARK: - Referral Service Implementation

final class ReferralService: ReferralServiceProtocol {

    static let shared = ReferralService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    func getOrCreateReferralCode() async throws -> String {
        let session = try await client.auth.session
        let userId = session.user.id

        // First check if user already has a code
        struct UserCode: Decodable {
            let referral_code: String?
        }
        let existing: UserCode = try await client
            .from("users")
            .select("referral_code")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        if let code = existing.referral_code, !code.isEmpty {
            return code
        }

        // No code yet — call RPC to generate one
        try await client
            .rpc("generate_referral_code", params: ["p_user_id": AnyJSON.string(userId.uuidString)])
            .execute()

        // Read back the generated code
        let updated: UserCode = try await client
            .from("users")
            .select("referral_code")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        guard let code = updated.referral_code, !code.isEmpty else {
            throw ReferralError.codeGenerationFailed
        }
        return code
    }

    func checkAIUnlocked() async throws -> Bool {
        let session = try await client.auth.session
        let userId = session.user.id

        struct UserAI: Decodable {
            let ai_unlocked: Bool?
        }

        let user: UserAI = try await client
            .from("users")
            .select("ai_unlocked")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return user.ai_unlocked ?? false
    }

    func applyReferralCode(_ code: String) async throws -> Bool {
        let session = try await client.auth.session
        let userId = session.user.id

        // Call RPC to complete the referral
        try await client
            .rpc("complete_referral", params: [
                "p_referral_code": AnyJSON.string(code.uppercased()),
                "p_referred_user_id": AnyJSON.string(userId.uuidString)
            ])
            .execute()

        // Verify it actually worked by checking the user's ai_unlocked status
        struct UserAI: Decodable {
            let ai_unlocked: Bool?
        }
        let user: UserAI = try await client
            .from("users")
            .select("ai_unlocked")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return user.ai_unlocked ?? false
    }
}

// MARK: - Referral Errors

enum ReferralError: LocalizedError {
    case codeGenerationFailed
    case invalidCode
    case selfReferral
    case networkError

    var errorDescription: String? {
        switch self {
        case .codeGenerationFailed: return "Failed to generate referral code. Please try again."
        case .invalidCode: return "Invalid referral code. Please check and try again."
        case .selfReferral: return "You can't use your own referral code."
        case .networkError: return "Network error. Please check your connection."
        }
    }
}
