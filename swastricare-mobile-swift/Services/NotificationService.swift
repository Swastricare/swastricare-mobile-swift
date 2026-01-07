//
//  NotificationService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Push notification management and smart scheduling
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Service Protocol

protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func checkPermissionStatus() async -> NotificationPermissionStatus
    func scheduleSmartReminder(progress: Double, remainingMl: Int, effectiveIntake: Int, dailyGoal: Int, streak: Int) async
    func cancelAllReminders()
    func registerForRemoteNotifications()
    func handleNotificationResponse(response: UNNotificationResponse) async
}

// MARK: - Notification Service Implementation

@MainActor
final class NotificationService: NSObject, NotificationServiceProtocol {
    
    static let shared = NotificationService()
    
    // MARK: - Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "notification_settings"
    
    private(set) var settings: NotificationSettings {
        didSet {
            saveSettings()
        }
    }
    
    weak var hydrationViewModel: HydrationViewModel?
    
    // MARK: - Init
    
    override private init() {
        self.settings = NotificationService.loadSettings()
        super.init()
        notificationCenter.delegate = self
        setupNotificationCategories()
    }
    
    // MARK: - Permission Management
    
    /// Request notification permission from user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            if granted {
                print("🔔 NotificationService: Permission granted")
                settings.enabled = true
            } else {
                print("🔔 NotificationService: Permission denied")
                settings.enabled = false
            }
            
            return granted
        } catch {
            print("🔔 NotificationService: Permission error - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Check current permission status
    func checkPermissionStatus() async -> NotificationPermissionStatus {
        let settings = await notificationCenter.notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .provisional:
            return .provisional
        case .ephemeral:
            return .provisional
        @unknown default:
            return .notDetermined
        }
    }
    
    // MARK: - Remote Notifications
    
    /// Register for remote push notifications
    func registerForRemoteNotifications() {
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Handle device token registration
    func handleDeviceToken(_ deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🔔 NotificationService: Device token received - \(tokenString)")
        
        // Save to Supabase
        do {
            try await SupabaseManager.shared.registerPushToken(
                deviceToken: tokenString,
                deviceName: UIDevice.current.name,
                deviceModel: UIDevice.current.model,
                osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
            print("🔔 NotificationService: Token registered with Supabase")
        } catch {
            print("🔔 NotificationService: Failed to register token - \(error.localizedDescription)")
        }
    }
    
    /// Handle remote notification failure
    func handleRemoteNotificationError(_ error: Error) {
        print("🔔 NotificationService: Remote notification registration failed - \(error.localizedDescription)")
    }
    
    // MARK: - Smart Scheduling
    
    /// Schedule a smart reminder based on hydration progress
    func scheduleSmartReminder(
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int
    ) async {
        guard settings.enabled else {
            print("🔔 NotificationService: Notifications disabled, skipping schedule")
            return
        }
        
        let status = await checkPermissionStatus()
        guard status.canSchedule else {
            print("🔔 NotificationService: No permission to schedule")
            return
        }
        
        // Cancel existing reminders
        cancelAllReminders()
        
        // Don't schedule if goal is met
        if progress >= 1.0 {
            print("🔔 NotificationService: Goal met, no reminder needed")
            return
        }
        
        // Calculate next reminder time
        let timeOfDay = TimeOfDay.current()
        let progressStatus = determineProgressStatus(progress: progress, timeOfDay: timeOfDay)
        
        let frequencyHours = settings.smartReminders ? 
            progressStatus.reminderFrequencyHours : 
            settings.reminderFrequencyHours
        
        guard frequencyHours > 0 else {
            print("🔔 NotificationService: No reminder needed for current progress")
            return
        }
        
        // Schedule reminders for the rest of the day
        await scheduleReminders(
            frequencyHours: frequencyHours,
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            streak: streak
        )
        
        settings.lastScheduledTime = Date()
    }
    
    // MARK: - Private Scheduling Helpers
    
    private func scheduleReminders(
        frequencyHours: Int,
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int
    ) async {
        let calendar = Calendar.current
        let now = Date()
        
        // Get end of day (10 PM or start of quiet hours)
        let quietHoursStartComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursStart)
        var endOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endOfDayComponents.hour = quietHoursStartComponents.hour ?? 22
        endOfDayComponents.minute = quietHoursStartComponents.minute ?? 0
        
        guard let endOfDay = calendar.date(from: endOfDayComponents) else { return }
        
        // Get start time (now or end of quiet hours)
        var startTime = now.addingTimeInterval(TimeInterval(frequencyHours * 3600))
        
        if settings.isInQuietHours(date: startTime) {
            // Schedule after quiet hours end
            let endComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursEnd)
            var nextComponents = calendar.dateComponents([.year, .month, .day], from: startTime)
            nextComponents.hour = endComponents.hour
            nextComponents.minute = endComponents.minute
            
            if let nextTime = calendar.date(from: nextComponents) {
                startTime = nextTime
                // If that time has passed, add a day
                if nextTime < now {
                    startTime = calendar.date(byAdding: .day, value: 1, to: nextTime) ?? startTime
                }
            }
        }
        
        var currentTime = startTime
        var count = 0
        let maxReminders = 5 // Limit to 5 reminders per day
        
        while currentTime < endOfDay && count < maxReminders {
            // Skip if in quiet hours
            if !settings.isInQuietHours(date: currentTime) {
                await scheduleNotification(
                    at: currentTime,
                    progress: progress,
                    remainingMl: remainingMl,
                    effectiveIntake: effectiveIntake,
                    dailyGoal: dailyGoal,
                    streak: streak
                )
                count += 1
            }
            
            currentTime = currentTime.addingTimeInterval(TimeInterval(frequencyHours * 3600))
        }
        
        print("🔔 NotificationService: Scheduled \(count) reminders")
    }
    
    private func scheduleNotification(
        at date: Date,
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int
    ) async {
        let timeOfDay = TimeOfDay.current(date: date)
        let message = NotificationMessageGenerator.generateMessage(
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
            streak: streak
        )
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.hydrationReminder.identifier
        content.badge = 1
        
        // Add user info for tracking
        content.userInfo = [
            "type": "hydration_reminder",
            "progress": progress,
            "remainingMl": remainingMl,
            "scheduledTime": date.timeIntervalSince1970
        ]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "hydration_\(date.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("🔔 NotificationService: Scheduled notification for \(date)")
        } catch {
            print("🔔 NotificationService: Failed to schedule - \(error.localizedDescription)")
        }
    }
    
    private func determineProgressStatus(progress: Double, timeOfDay: TimeOfDay) -> HydrationProgressStatus {
        if progress >= 1.0 {
            return .goalMet
        }
        
        // Check if behind schedule based on time of day
        if timeOfDay == .afternoon && progress < 0.3 {
            return .behindSchedule
        }
        
        if progress > 0.7 {
            return .ahead
        } else if progress >= 0.3 {
            return .onTrack
        } else {
            return .behindSchedule
        }
    }
    
    // MARK: - Cancel Notifications
    
    /// Cancel all scheduled hydration reminders
    func cancelAllReminders() {
        notificationCenter.getPendingNotificationRequests { requests in
            let hydrationIds = requests
                .filter { $0.identifier.starts(with: "hydration_") }
                .map { $0.identifier }
            
            if !hydrationIds.isEmpty {
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: hydrationIds)
                print("🔔 NotificationService: Cancelled \(hydrationIds.count) reminders")
            }
        }
    }
    
    // MARK: - Notification Response Handler
    
    /// Handle user interaction with notification
    func handleNotificationResponse(response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case NotificationAction.log250ml.rawValue:
            await logWaterFromNotification(amount: 250)
            
        case NotificationAction.log500ml.rawValue:
            await logWaterFromNotification(amount: 500)
            
        case NotificationAction.remindLater.rawValue:
            await scheduleOneTimeReminder(delayHours: 1)
            
        case NotificationAction.dismiss.rawValue:
            // Stop reminders for 3 hours
            await scheduleOneTimeReminder(delayHours: 3)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            print("🔔 NotificationService: User opened app from notification")
            
        default:
            break
        }
    }
    
    private func logWaterFromNotification(amount: Int) async {
        guard let viewModel = hydrationViewModel else {
            print("🔔 NotificationService: No view model available")
            return
        }
        
        await viewModel.addWaterIntake(amount: amount, drinkType: .water, notes: "Added from notification")
        print("🔔 NotificationService: Logged \(amount)ml from notification")
        
        // Clear badge
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    private func scheduleOneTimeReminder(delayHours: Int) async {
        let triggerDate = Date().addingTimeInterval(TimeInterval(delayHours * 3600))
        
        // Skip if in quiet hours
        if settings.isInQuietHours(date: triggerDate) {
            print("🔔 NotificationService: Delay would be in quiet hours, skipping")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "💧 Hydration Reminder"
        content.body = "Time to drink some water!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.hydrationReminder.identifier
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayHours * 3600), repeats: false)
        let request = UNNotificationRequest(identifier: "hydration_delayed", content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("🔔 NotificationService: Scheduled delayed reminder for \(delayHours) hours")
        } catch {
            print("🔔 NotificationService: Failed to schedule delayed reminder - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        
        // If notifications are disabled, cancel all
        if !newSettings.enabled {
            cancelAllReminders()
        }
    }
    
    func getSettings() -> NotificationSettings {
        return settings
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    private static func loadSettings() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: "notification_settings"),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return settings
    }
    
    // MARK: - Setup Notification Categories
    
    private func setupNotificationCategories() {
        let log250Action = UNNotificationAction(
            identifier: NotificationAction.log250ml.rawValue,
            title: NotificationAction.log250ml.title,
            options: [.foreground]
        )
        
        let log500Action = UNNotificationAction(
            identifier: NotificationAction.log500ml.rawValue,
            title: NotificationAction.log500ml.title,
            options: [.foreground]
        )
        
        let remindLaterAction = UNNotificationAction(
            identifier: NotificationAction.remindLater.rawValue,
            title: NotificationAction.remindLater.title,
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: NotificationAction.dismiss.title,
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: NotificationCategory.hydrationReminder.identifier,
            actions: [log250Action, log500Action, remindLaterAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        notificationCenter.setNotificationCategories([category])
        print("🔔 NotificationService: Notification categories configured")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification response
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await handleNotificationResponse(response: response)
            completionHandler()
        }
    }
}
