//
//  FamilyAlertPreferencesRepository.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — per-(caregiver, target_health_profile_id) alert preferences.
//  Mirrors the Android FamilyAlertPreferencesRepository.
//

import Foundation
import Supabase

// MARK: - Model

struct FamilyAlertPreferences: Codable, Sendable, Equatable {
    let caregiverUserId: String
    let targetHealthProfileId: String
    var missedMedicationAlerts: Bool
    var lowHydrationAlerts: Bool
    var missedVitalsAlerts: Bool
    var customNudgeAlerts: Bool
    var quietHoursStart: String?       // "HH:mm:ss"
    var quietHoursEnd: String?         // "HH:mm:ss"
    var missedMedGraceMinutes: Int

    init(
        caregiverUserId: String,
        targetHealthProfileId: String,
        missedMedicationAlerts: Bool = true,
        lowHydrationAlerts: Bool = true,
        missedVitalsAlerts: Bool = false,
        customNudgeAlerts: Bool = true,
        quietHoursStart: String? = nil,
        quietHoursEnd: String? = nil,
        missedMedGraceMinutes: Int = 30
    ) {
        self.caregiverUserId = caregiverUserId
        self.targetHealthProfileId = targetHealthProfileId
        self.missedMedicationAlerts = missedMedicationAlerts
        self.lowHydrationAlerts = lowHydrationAlerts
        self.missedVitalsAlerts = missedVitalsAlerts
        self.customNudgeAlerts = customNudgeAlerts
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.missedMedGraceMinutes = missedMedGraceMinutes
    }

    enum CodingKeys: String, CodingKey {
        case caregiverUserId = "caregiver_user_id"
        case targetHealthProfileId = "target_health_profile_id"
        case missedMedicationAlerts = "missed_medication_alerts"
        case lowHydrationAlerts = "low_hydration_alerts"
        case missedVitalsAlerts = "missed_vitals_alerts"
        case customNudgeAlerts = "custom_nudge_alerts"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case missedMedGraceMinutes = "missed_med_grace_minutes"
    }
}

// MARK: - Protocol

protocol FamilyAlertPreferencesRepositoryProtocol: Sendable {
    func get(caregiverUserId: String, targetProfileId: String) async throws -> FamilyAlertPreferences?
    func upsert(_ prefs: FamilyAlertPreferences) async throws
}

// MARK: - Implementation

final class FamilyAlertPreferencesRepository: FamilyAlertPreferencesRepositoryProtocol, @unchecked Sendable {
    static let shared = FamilyAlertPreferencesRepository()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    func get(caregiverUserId: String, targetProfileId: String) async throws -> FamilyAlertPreferences? {
        let rows: [FamilyAlertPreferences] = try await client
            .from("family_alert_preferences")
            .select()
            .eq("caregiver_user_id", value: caregiverUserId)
            .eq("target_health_profile_id", value: targetProfileId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsert(_ prefs: FamilyAlertPreferences) async throws {
        try await client
            .from("family_alert_preferences")
            .upsert(prefs, onConflict: "caregiver_user_id,target_health_profile_id")
            .execute()
    }
}
