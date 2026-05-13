//
//  FamilyNudgeRepository.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — sends nudges (preset or custom) to a family member via
//  the `send-family-nudge` edge function, and provides reads against the
//  `ai_nudges` table (mark acted-on, dismiss, fetch by id).
//
//  Mirrors the Android FamilyNudgeRepository.
//

import Foundation
import Supabase

// MARK: - Preset

enum NudgePreset: String, Codable, CaseIterable, Sendable {
    case medication
    case hydration
    case vitals
    case appointment
    case checkin

    /// The preset_key value the edge function expects (uppercase).
    var key: String {
        switch self {
        case .medication: return "MEDICATION"
        case .hydration:  return "HYDRATION"
        case .vitals:     return "VITALS"
        case .appointment:return "APPOINTMENT"
        case .checkin:    return "CHECKIN"
        }
    }

    /// The `category` value (matches `nudge_type` semantics on the nudges table).
    var category: String { key }
}

// MARK: - Request / Response DTOs

struct NudgeRequest: Codable, Sendable {
    let recipientUserId: String
    let targetHealthProfileId: String?
    let presetKey: String?
    let customMessage: String?
    let category: String
    let isCritical: Bool

    enum CodingKeys: String, CodingKey {
        case recipientUserId = "recipient_user_id"
        case targetHealthProfileId = "target_health_profile_id"
        case presetKey = "preset_key"
        case customMessage = "custom_message"
        case category
        case isCritical = "is_critical"
    }
}

struct NudgeResponse: Codable, Sendable {
    var delivered: Bool
    var nudgeId: String?
    var reason: String?

    init(delivered: Bool = false, nudgeId: String? = nil, reason: String? = nil) {
        self.delivered = delivered
        self.nudgeId = nudgeId
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case delivered
        case nudgeId = "nudge_id"
        case reason
    }
}

struct NudgeDetail: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let message: String
    let nudgeType: String
    let priority: String?
    let presetKey: String?
    let isCritical: Bool
    let isDismissed: Bool
    let isActedOn: Bool
    let senderUserId: String?
    let actionDeeplink: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case nudgeType = "nudge_type"
        case priority
        case presetKey = "preset_key"
        case isCritical = "is_critical"
        case isDismissed = "is_dismissed"
        case isActedOn = "is_acted_on"
        case senderUserId = "sender_user_id"
        case actionDeeplink = "action_deeplink"
        case createdAt = "created_at"
    }
}

// MARK: - Protocol

protocol FamilyNudgeRepositoryProtocol: Sendable {
    func sendPreset(
        recipientUserId: String,
        targetProfileId: String?,
        preset: NudgePreset,
        isCritical: Bool
    ) async throws -> NudgeResponse

    func sendCustom(
        recipientUserId: String,
        targetProfileId: String?,
        message: String,
        category: String,
        isCritical: Bool
    ) async throws -> NudgeResponse

    func fetchById(id: String) async throws -> NudgeDetail?
    func markActedOn(id: String) async throws
    func dismiss(id: String) async throws
}

// MARK: - Implementation

final class FamilyNudgeRepository: FamilyNudgeRepositoryProtocol, @unchecked Sendable {
    static let shared = FamilyNudgeRepository()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    // MARK: Send

    func sendPreset(
        recipientUserId: String,
        targetProfileId: String?,
        preset: NudgePreset,
        isCritical: Bool = false
    ) async throws -> NudgeResponse {
        let request = NudgeRequest(
            recipientUserId: recipientUserId,
            targetHealthProfileId: targetProfileId,
            presetKey: preset.key,
            customMessage: nil,
            category: preset.category,
            isCritical: isCritical
        )
        return try await invokeSendFamilyNudge(request)
    }

    func sendCustom(
        recipientUserId: String,
        targetProfileId: String?,
        message: String,
        category: String = "CHECKIN",
        isCritical: Bool = false
    ) async throws -> NudgeResponse {
        let request = NudgeRequest(
            recipientUserId: recipientUserId,
            targetHealthProfileId: targetProfileId,
            presetKey: nil,
            customMessage: message,
            category: category,
            isCritical: isCritical
        )
        return try await invokeSendFamilyNudge(request)
    }

    private func invokeSendFamilyNudge(_ request: NudgeRequest) async throws -> NudgeResponse {
        let decoder = JSONDecoder()
        do {
            let response: NudgeResponse = try await client.functions.invoke(
                "send-family-nudge",
                options: FunctionInvokeOptions(body: request),
                decoder: decoder
            )
            return response
        } catch {
            // Surface a structured failure rather than throwing — mirrors Android behavior
            // where the caller checks `delivered` first.
            return NudgeResponse(
                delivered: false,
                nudgeId: nil,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: Reads / mutations on ai_nudges

    func fetchById(id: String) async throws -> NudgeDetail? {
        let rows: [NudgeDetail] = try await client
            .from("ai_nudges")
            .select("id, title, message, nudge_type, priority, preset_key, is_critical, is_dismissed, is_acted_on, sender_user_id, action_deeplink, created_at")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func markActedOn(id: String) async throws {
        struct Update: Encodable { let is_acted_on: Bool }
        try await client
            .from("ai_nudges")
            .update(Update(is_acted_on: true))
            .eq("id", value: id)
            .execute()
    }

    func dismiss(id: String) async throws {
        struct Update: Encodable { let is_dismissed: Bool }
        try await client
            .from("ai_nudges")
            .update(Update(is_dismissed: true))
            .eq("id", value: id)
            .execute()
    }
}
