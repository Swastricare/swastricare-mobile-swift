//
//  DeviceTokenRepository.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — stores FCM device tokens in `device_tokens` so the
//  edge function `send-family-nudge` can fan-out push to the right user.
//  Mirrors the Android DeviceTokenRepository.
//

import Foundation
import Supabase

// MARK: - Row

struct DeviceTokenRow: Codable, Sendable {
    let userId: String
    let fcmToken: String
    let platform: String
    let appVersion: String?
    let deviceModel: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fcmToken = "fcm_token"
        case platform
        case appVersion = "app_version"
        case deviceModel = "device_model"
    }
}

// MARK: - Protocol

protocol DeviceTokenRepositoryProtocol: Sendable {
    func upsertToken(
        userId: String,
        token: String,
        appVersion: String?,
        deviceModel: String?
    ) async throws

    func deleteToken(userId: String, token: String) async throws
}

// MARK: - Implementation

final class DeviceTokenRepository: DeviceTokenRepositoryProtocol, @unchecked Sendable {
    static let shared = DeviceTokenRepository()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    func upsertToken(
        userId: String,
        token: String,
        appVersion: String?,
        deviceModel: String?
    ) async throws {
        let row = DeviceTokenRow(
            userId: userId,
            fcmToken: token,
            platform: "ios",
            appVersion: appVersion,
            deviceModel: deviceModel
        )
        try await client
            .from("device_tokens")
            .upsert(row, onConflict: "user_id,fcm_token")
            .execute()
    }

    func deleteToken(userId: String, token: String) async throws {
        try await client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("fcm_token", value: token)
            .execute()
    }
}
