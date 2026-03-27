//
//  RemindersSettingsViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModels Layer
//  Manages unified reminder settings across all health categories
//

import Foundation
import SwiftUI
import Combine
import Supabase
import Auth

@MainActor
final class RemindersSettingsViewModel: ObservableObject {

    private let notificationService = NotificationService.shared
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "reminder_settings"

    @Published var settings: ReminderSettings {
        didSet { saveSettings() }
    }
    @Published var permissionStatus: NotificationPermissionStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var userPhone: String? = nil

    init() {
        self.settings = Self.loadOrMigrate()
    }

    // MARK: - Permission

    func checkPermission() async {
        permissionStatus = await notificationService.checkPermissionStatus()
    }

    func requestPermission() async {
        let granted = await notificationService.requestPermission()
        await checkPermission()
        if granted {
            settings.globalEnabled = true
        }
    }

    // MARK: - Global Toggle

    func setGlobalEnabled(_ enabled: Bool) {
        settings.globalEnabled = enabled
        syncHydrationToLegacy()
        if enabled {
            rescheduleAll()
        } else {
            notificationService.cancelAllReminders()
        }
    }

    // MARK: - Category Toggles

    func setHydrationEnabled(_ enabled: Bool) {
        settings.hydration.enabled = enabled
        syncHydrationToLegacy()
        if enabled {
            Task {
                notificationService.resetSchedulingState()
            }
        } else {
            notificationService.cancelAllReminders()
        }
    }

    func setMedicationEnabled(_ enabled: Bool) {
        settings.medication.enabled = enabled
    }

    func setDietEnabled(_ enabled: Bool) {
        settings.diet.enabled = enabled
        Task { await notificationService.scheduleDietReminders() }
    }

    func setMenstrualEnabled(_ enabled: Bool) {
        settings.menstrual.enabled = enabled
        Task { await notificationService.scheduleMenstrualCycleNotifications() }
    }

    func setAINudgesEnabled(_ enabled: Bool) {
        settings.aiNudges.enabled = enabled
    }

    // MARK: - Hydration Settings Updates

    func updateHydrationSettings() {
        syncHydrationToLegacy()
    }

    // MARK: - Reschedule

    func rescheduleAll() {
        syncHydrationToLegacy()
        Task {
            notificationService.resetSchedulingState()
            await notificationService.scheduleDietReminders()
            await notificationService.scheduleMenstrualCycleNotifications()
        }
    }

    /// Keep the existing NotificationSettings in sync for backward compatibility
    /// with hydration scheduling code
    private func syncHydrationToLegacy() {
        let h = settings.hydration
        var legacy = notificationService.getSettings()
        legacy.enabled = settings.globalEnabled && h.enabled
        legacy.smartReminders = h.smartReminders
        legacy.quietHoursStart = h.quietHoursStart
        legacy.quietHoursEnd = h.quietHoursEnd
        legacy.reminderFrequencyHours = h.reminderFrequencyHours
        legacy.showProgress = h.showProgress
        legacy.showMotivational = h.showMotivational
        legacy.snoozeMinutes = h.snoozeMinutes
        legacy.useAdaptiveLearning = h.useAdaptiveLearning
        notificationService.updateSettings(legacy)
    }

    // MARK: - WhatsApp

    func loadWhatsAppSettings() async {
        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }

        struct PhoneRow: Decodable { let phone: String? }
        if let row: PhoneRow = try? await SupabaseManager.shared.client
            .from("users")
            .select("phone")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value {
            userPhone = row.phone
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }

    private static func loadOrMigrate() -> ReminderSettings {
        let defaults = UserDefaults.standard

        // Try loading new format first
        if let data = defaults.data(forKey: "reminder_settings"),
           let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) {
            return settings
        }

        // Migrate from legacy
        if let data = defaults.data(forKey: "notification_settings"),
           let legacy = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            let migrated = ReminderSettings.migrateFromLegacy(legacy)
            if let encoded = try? JSONEncoder().encode(migrated) {
                defaults.set(encoded, forKey: "reminder_settings")
            }
            return migrated
        }

        return ReminderSettings()
    }
}
