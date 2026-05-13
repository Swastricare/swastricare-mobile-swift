//
//  FamilyMemberRemindersRepository.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — Batch 6.
//  Repository for listing & editing a family member's medication reminder
//  schedules. RLS (has_family_access(..., 'edit')) enforces permission.
//

import Foundation
import Supabase

protocol FamilyMemberRemindersRepositoryProtocol: Sendable {
    func listSchedulesForProfile(_ profileId: String) async throws -> [MedicationWithSchedule]
    func updateScheduleTime(scheduleId: String, timeOfDay: String) async throws
    func setReminderEnabled(scheduleId: String, enabled: Bool) async throws
}

final class FamilyMemberRemindersRepository: FamilyMemberRemindersRepositoryProtocol, @unchecked Sendable {
    static let shared = FamilyMemberRemindersRepository()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    // MARK: - Row DTO

    private struct Row: Codable {
        let id: String
        let medicationId: String
        let scheduleType: String
        let timeOfDay: String?
        let frequencyPerDay: Int?
        let reminderEnabled: Bool?
        let isActive: Bool
        let medications: MedRef?

        struct MedRef: Codable {
            let id: String
            let name: String
        }

        enum CodingKeys: String, CodingKey {
            case id
            case medicationId = "medication_id"
            case scheduleType = "schedule_type"
            case timeOfDay = "time_of_day"
            case frequencyPerDay = "frequency_per_day"
            case reminderEnabled = "reminder_enabled"
            case isActive = "is_active"
            case medications
        }
    }

    // MARK: - List

    func listSchedulesForProfile(_ profileId: String) async throws -> [MedicationWithSchedule] {
        let rows: [Row] = try await client
            .from("medication_schedules")
            .select("id, medication_id, schedule_type, time_of_day, frequency_per_day, reminder_enabled, is_active, medications(id, name)")
            .eq("health_profile_id", value: profileId)
            .eq("is_active", value: true)
            .execute()
            .value

        return rows.map { r in
            MedicationWithSchedule(
                medicationId: r.medicationId,
                medicationName: r.medications?.name ?? "Untitled",
                scheduleId: r.id,
                scheduleType: r.scheduleType,
                timeOfDay: r.timeOfDay ?? "08:00:00",
                frequencyPerDay: r.frequencyPerDay ?? 1,
                reminderEnabled: r.reminderEnabled ?? true,
                isActive: r.isActive
            )
        }
    }

    // MARK: - Update time

    func updateScheduleTime(scheduleId: String, timeOfDay: String) async throws {
        struct Update: Encodable { let time_of_day: String }
        try await client
            .from("medication_schedules")
            .update(Update(time_of_day: timeOfDay))
            .eq("id", value: scheduleId)
            .execute()
    }

    // MARK: - Toggle reminder

    func setReminderEnabled(scheduleId: String, enabled: Bool) async throws {
        struct Update: Encodable { let reminder_enabled: Bool }
        try await client
            .from("medication_schedules")
            .update(Update(reminder_enabled: enabled))
            .eq("id", value: scheduleId)
            .execute()
    }
}
