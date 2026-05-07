//
//  VaultNotificationService.swift
//  swastricare-mobile-swift
//
//  Schedules / cancels local notifications for vault documents — reminder
//  and appointment alerts. Mirrors the pattern used by `MedicationService`.
//

import Foundation
import UserNotifications

@MainActor
final class VaultNotificationService {

    static let shared = VaultNotificationService()
    private init() {}

    // MARK: - Identifier helpers

    private static func reminderIdentifier(for documentId: UUID) -> String {
        "vault_reminder_\(documentId.uuidString)"
    }

    private static func appointmentIdentifier(for documentId: UUID) -> String {
        "vault_appointment_\(documentId.uuidString)"
    }

    // MARK: - Public API

    /// Apply the reminder / appointment dates from a saved document, replacing
    /// any previously-scheduled notifications for the same document. If the
    /// dates are nil, just clears them.
    func sync(document: MedicalDocument) async {
        guard let id = document.id else { return }
        await cancel(for: id)

        if let date = document.reminderDate, date > Date() {
            await scheduleReminder(documentId: id, title: document.title, fireDate: date)
        }
        if let date = document.appointmentDate, date > Date() {
            await scheduleAppointment(
                documentId: id,
                title: document.title,
                fireDate: date,
                location: document.location
            )
        }
    }

    /// Remove both reminder and appointment notifications for a document.
    func cancel(for documentId: UUID) async {
        let identifiers = [
            Self.reminderIdentifier(for: documentId),
            Self.appointmentIdentifier(for: documentId)
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Private scheduling

    private func scheduleReminder(documentId: UUID, title: String, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "📄 Reminder: \(title)"
        content.body = "Tap to open this document in your Vault."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.vaultReminder.identifier
        content.userInfo = [
            "type": "vault_reminder",
            "document_id": documentId.uuidString
        ]

        let trigger = makeTrigger(for: fireDate)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(for: documentId),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📄 VaultNotificationService: scheduled reminder for \(title) at \(fireDate)")
        } catch {
            print("📄 VaultNotificationService: failed to schedule reminder — \(error.localizedDescription)")
        }
    }

    private func scheduleAppointment(documentId: UUID, title: String, fireDate: Date, location: String?) async {
        let content = UNMutableNotificationContent()
        content.title = "🗓️ Appointment: \(title)"
        if let location, !location.isEmpty {
            content.body = "At \(location). Tap to view details."
        } else {
            content.body = "Your appointment is scheduled. Tap to view details."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.vaultAppointment.identifier
        content.userInfo = [
            "type": "vault_appointment",
            "document_id": documentId.uuidString
        ]

        let trigger = makeTrigger(for: fireDate)
        let request = UNNotificationRequest(
            identifier: Self.appointmentIdentifier(for: documentId),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📄 VaultNotificationService: scheduled appointment for \(title) at \(fireDate)")
        } catch {
            print("📄 VaultNotificationService: failed to schedule appointment — \(error.localizedDescription)")
        }
    }

    private func makeTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
