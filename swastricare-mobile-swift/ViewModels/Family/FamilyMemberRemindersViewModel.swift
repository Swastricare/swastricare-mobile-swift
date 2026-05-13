//
//  FamilyMemberRemindersViewModel.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — Batch 6.
//  ViewModel for FamilyMemberRemindersView. Loads a member's active
//  medication schedules and applies remote edits via the repository.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class FamilyMemberRemindersViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var schedules: [MedicationWithSchedule] = []
    @Published var savingScheduleId: String?
    @Published var message: String?

    private var targetProfileId: String = ""

    func load(targetHealthProfileId: String) async {
        targetProfileId = targetHealthProfileId
        isLoading = true
        error = nil
        do {
            schedules = try await FamilyMemberRemindersRepository.shared.listSchedulesForProfile(targetHealthProfileId)
            isLoading = false
        } catch {
            let lower = error.localizedDescription.lowercased()
            self.error = (lower.contains("permission") || lower.contains("policy"))
                ? "You don't have edit permission for this member"
                : error.localizedDescription
            isLoading = false
        }
    }

    func updateTime(scheduleId: String, newTime: String) {
        savingScheduleId = scheduleId
        Task {
            do {
                try await FamilyMemberRemindersRepository.shared.updateScheduleTime(
                    scheduleId: scheduleId,
                    timeOfDay: newTime
                )
                message = "Time updated"
                savingScheduleId = nil
                await load(targetHealthProfileId: targetProfileId)
            } catch {
                let lower = error.localizedDescription.lowercased()
                message = (lower.contains("permission") || lower.contains("policy"))
                    ? "You don't have edit permission"
                    : "Update failed: \(error.localizedDescription)"
                savingScheduleId = nil
            }
        }
    }

    func setReminderEnabled(scheduleId: String, enabled: Bool) {
        Task {
            do {
                try await FamilyMemberRemindersRepository.shared.setReminderEnabled(
                    scheduleId: scheduleId,
                    enabled: enabled
                )
                await load(targetHealthProfileId: targetProfileId)
            } catch {
                let lower = error.localizedDescription.lowercased()
                message = (lower.contains("permission") || lower.contains("policy"))
                    ? "You don't have edit permission"
                    : "Toggle failed: \(error.localizedDescription)"
            }
        }
    }

    func clearMessage() { message = nil }
}
