//
//  MedicationWithSchedule.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — Batch 6.
//  Flattened view-model for a medication + one of its active schedules,
//  used by FamilyMemberRemindersView for remote editing by caregivers.
//

import Foundation

struct MedicationWithSchedule: Identifiable, Codable, Equatable {
    var id: String { scheduleId }
    let medicationId: String
    let medicationName: String
    let scheduleId: String
    let scheduleType: String       // 'daily' / 'weekly' / 'monthly' / 'as_needed' / 'custom'
    let timeOfDay: String          // "HH:mm:ss"
    let frequencyPerDay: Int
    let reminderEnabled: Bool
    let isActive: Bool
}
