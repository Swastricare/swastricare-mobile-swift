//
//  NudgeService.swift
//  swastricare-mobile-swift
//
//  Fetches and manages server-side proactive health nudges
//

import Foundation
import Supabase

// MARK: - Protocol

protocol NudgeServiceProtocol {
    func fetchActiveNudges() async throws -> [ServerNudge]
    func dismissNudge(id: UUID) async throws
    func markActedOn(id: UUID) async throws
}

// MARK: - Model

struct ServerNudge: Identifiable, Equatable, Codable {
    let id: UUID
    let nudgeType: String
    let title: String
    let message: String
    let priority: String
    let actionDeeplink: String?
    let isDismissed: Bool
    let isActedOn: Bool
    let createdAt: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case nudgeType = "nudge_type"
        case title, message, priority
        case actionDeeplink = "action_deeplink"
        case isDismissed = "is_dismissed"
        case isActedOn = "is_acted_on"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    var icon: String {
        switch nudgeType {
        case "hydration": return "drop.fill"
        case "inactivity": return "figure.walk"
        case "medication_missed": return "pills.fill"
        case "sleep_deficit": return "moon.zzz.fill"
        case "step_goal_close": return "flame.fill"
        case "heart_rate_elevated": return "heart.fill"
        case "streak_at_risk": return "trophy.fill"
        case "weekly_insight": return "chart.bar.fill"
        default: return "bell.fill"
        }
    }

    var nudgeColor: String {
        switch nudgeType {
        case "hydration": return "3B82F6"
        case "inactivity": return "22C55E"
        case "medication_missed": return "EF4444"
        case "heart_rate_elevated": return "EF4444"
        case "streak_at_risk": return "F97316"
        default: return "6366F1"
        }
    }
}

// MARK: - Update DTOs

private struct NudgeDismissUpdate: Encodable {
    let is_dismissed: Bool
    let updated_at: String
}

private struct NudgeActedOnUpdate: Encodable {
    let is_acted_on: Bool
    let updated_at: String
}

// MARK: - Service

final class NudgeService: NudgeServiceProtocol {
    static let shared = NudgeService()
    private let supabase = SupabaseManager.shared
    private init() {}

    func fetchActiveNudges() async throws -> [ServerNudge] {
        let now = ISO8601DateFormatter().string(from: Date())
        let nudges: [ServerNudge] = try await supabase.client
            .from("ai_nudges")
            .select()
            .eq("is_dismissed", value: false)
            .or("expires_at.is.null,expires_at.gte.\(now)")
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value
        return nudges
    }

    func dismissNudge(id: UUID) async throws {
        try await supabase.client
            .from("ai_nudges")
            .update(NudgeDismissUpdate(
                is_dismissed: true,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markActedOn(id: UUID) async throws {
        try await supabase.client
            .from("ai_nudges")
            .update(NudgeActedOnUpdate(
                is_acted_on: true,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }
}
