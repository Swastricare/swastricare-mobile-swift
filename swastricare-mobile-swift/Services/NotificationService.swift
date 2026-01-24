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
    func scheduleSmartReminder(progress: Double, remainingMl: Int, effectiveIntake: Int, dailyGoal: Int, streak: Int, context: HydrationReminderContext?) async
    func cancelAllReminders()
    func registerForRemoteNotifications()
    func handleNotificationResponse(response: UNNotificationResponse) async
    func handleMedicationNotificationResponse(response: UNNotificationResponse) async
}

// MARK: - Notification Service Implementation

@MainActor
final class NotificationService: NSObject, NotificationServiceProtocol {
    
    static let shared = NotificationService()
    
    // MARK: - Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "notification_settings"
    private let scheduledIdsKey = "scheduled_notification_ids"
    private let historyManager = NotificationHistoryManager.shared
    
    private(set) var settings: NotificationSettings {
        didSet {
            saveSettings()
        }
    }
    
    /// Track scheduled notification IDs for incremental updates
    private var scheduledNotificationIds: Set<String> = []
    
    /// Last known progress status to avoid unnecessary rescheduling
    private var lastProgressStatus: HydrationProgressStatus?
    private var lastGoalMet: Bool = false
    
    weak var hydrationViewModel: HydrationViewModel?
    weak var medicationViewModel: MedicationViewModel?
    
    // MARK: - Init
    
    override private init() {
        self.settings = NotificationService.loadSettings()
        self.scheduledNotificationIds = NotificationService.loadScheduledIds()
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
    
    /// Schedule a smart reminder based on hydration progress (without context)
    func scheduleSmartReminder(
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int
    ) async {
        await scheduleSmartReminder(
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            streak: streak,
            context: nil
        )
    }
    
    /// Schedule a smart reminder based on hydration progress with context awareness
    /// Uses incremental scheduling to avoid cancelling all reminders unnecessarily
    func scheduleSmartReminder(
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int,
        context: HydrationReminderContext?
    ) async {
        guard settings.enabled else {
            print("🔔 NotificationService: Notifications disabled, skipping schedule")
            await cancelAllRemindersAsync()
            return
        }
        
        let status = await checkPermissionStatus()
        guard status.canSchedule else {
            print("🔔 NotificationService: No permission to schedule")
            return
        }
        
        let isGoalMet = progress >= 1.0
        let timeOfDay = TimeOfDay.current()
        let progressStatus = determineProgressStatus(progress: progress, timeOfDay: timeOfDay)
        
        // Check if we need to reschedule
        let shouldReschedule = shouldRescheduleNotifications(
            newProgressStatus: progressStatus,
            newGoalMet: isGoalMet,
            context: context
        )
        
        // Don't schedule if goal is met
        if isGoalMet {
            if lastGoalMet != isGoalMet {
                // Goal just met - cancel remaining reminders and update badge
                await cancelAllRemindersAsync()
                await updateBadgeCount(pendingCount: 0)
                print("🔔 NotificationService: Goal met, cancelled remaining reminders")
            }
            lastGoalMet = isGoalMet
            lastProgressStatus = progressStatus
            return
        }
        
        // Check pattern learner if user naturally drinks at this time
        if let patternLearner = context?.patternLearner {
            if !patternLearner.shouldSendReminderNow() {
                print("🔔 NotificationService: Pattern learner suggests user drinks naturally at this time, but checking future schedule")
            }
        }
        
        // Only reschedule if progress status changed significantly
        guard shouldReschedule else {
            print("🔔 NotificationService: Progress status unchanged, skipping reschedule")
            return
        }
        
        // Cancel existing reminders only when needed
        await cancelAllRemindersAsync()
        
        // Calculate frequency with context adjustments
        var frequencyHours = settings.smartReminders ? 
            progressStatus.reminderFrequencyHours : 
            settings.reminderFrequencyHours
        
        // Apply context-based frequency adjustments
        if let ctx = context {
            frequencyHours = calculateOptimalFrequency(
                baseFrequency: frequencyHours,
                context: ctx,
                progressStatus: progressStatus
            )
        }
        
        guard frequencyHours > 0 else {
            print("🔔 NotificationService: No reminder needed for current progress")
            return
        }
        
        // Check if we should send an immediate reminder (e.g., after exercise in hot weather)
        if let ctx = context, ctx.shouldSendImmediateReminder() && progress < 0.8 {
            await scheduleImmediateContextReminder(context: ctx, remainingMl: remainingMl)
        }
        
        // Schedule reminders for the rest of the day
        let scheduledCount = await scheduleReminders(
            frequencyHours: frequencyHours,
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            streak: streak,
            context: context
        )
        
        // Update badge count based on pending reminders
        await updateBadgeCount(pendingCount: scheduledCount)
        
        // Update state
        lastProgressStatus = progressStatus
        lastGoalMet = isGoalMet
        settings.lastScheduledTime = Date()
    }
    
    /// Determines if we should reschedule notifications based on progress changes
    private func shouldRescheduleNotifications(
        newProgressStatus: HydrationProgressStatus,
        newGoalMet: Bool,
        context: HydrationReminderContext? = nil
    ) -> Bool {
        // Always reschedule if goal status changed
        if newGoalMet != lastGoalMet {
            return true
        }
        
        // First time scheduling
        guard let lastStatus = lastProgressStatus else {
            return true
        }
        
        // Reschedule if progress status category changed
        if lastStatus != newProgressStatus {
            return true
        }
        
        // Check if we have any scheduled notifications
        if scheduledNotificationIds.isEmpty {
            return true
        }
        
        // Check if any scheduled notifications are in the future
        let now = Date().timeIntervalSince1970
        let hasFutureReminders = scheduledNotificationIds.contains { id in
            // Extract timestamp from identifier (assumed format: prefix_TIMESTAMP)
            let components = id.components(separatedBy: "_")
            if let last = components.last, let timestamp = TimeInterval(last) {
                return timestamp > now
            }
            return false
        }
        
        if !hasFutureReminders {
            print("🔔 NotificationService: No future reminders found, forcing reschedule")
            return true
        }
        
        // Reschedule if context suggests urgency (hot day or recent exercise)
        if let ctx = context {
            if ctx.shouldSendImmediateReminder() {
                return true
            }
        }
        
        return false
    }
    
    /// Calculate optimal frequency based on context
    private func calculateOptimalFrequency(
        baseFrequency: Int,
        context: HydrationReminderContext,
        progressStatus: HydrationProgressStatus
    ) -> Int {
        var frequency = baseFrequency
        
        // Apply context adjustments
        frequency += context.getFrequencyAdjustment()
        
        // Get pattern learner recommendations if available
        if let patternLearner = context.patternLearner {
            let pattern = patternLearner.getPattern()
            
            // If user has slow notification response, reduce frequency slightly
            if let avgResponse = pattern.avgNotificationResponseTime, avgResponse > 1800 {
                // User typically takes > 30 min to respond, don't spam
                frequency = max(frequency, 3)
            }
        }
        
        // Ensure reasonable bounds (1-6 hours)
        return max(1, min(6, frequency))
    }
    
    /// Schedule an immediate context-based reminder (e.g., post-exercise)
    private func scheduleImmediateContextReminder(context: HydrationReminderContext, remainingMl: Int) async {
        let content = UNMutableNotificationContent()
        
        if context.recentlyExercised && context.isHotDay {
            content.title = "🏃‍♂️💧 Post-Workout Hydration"
            content.body = "Great workout! It's \(Int(context.temperature ?? 30))°C outside. Time to rehydrate - \(remainingMl)ml remaining!"
        } else if context.recentlyExercised {
            content.title = "🏃‍♂️ Post-Workout Reminder"
            content.body = "Great workout! Don't forget to rehydrate - \(remainingMl)ml remaining!"
        } else if context.isHotDay {
            content.title = "🌡️ Hot Weather Alert"
            content.body = "It's \(Int(context.temperature ?? 30))°C outside! Stay hydrated - \(remainingMl)ml remaining!"
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.hydrationReminder.identifier
        content.userInfo = [
            "type": "hydration_reminder",
            "context": "immediate",
            "temperature": context.temperature ?? 0,
            "exerciseMinutes": context.exerciseMinutes
        ]
        
        // Schedule 5 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        let identifier = "hydration_context_\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            scheduledNotificationIds.insert(identifier)
            saveScheduledIds()
            print("🔔 NotificationService: Scheduled immediate context reminder")
        } catch {
            print("🔔 NotificationService: Failed to schedule context reminder - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Scheduling Helpers
    
    @discardableResult
    private func scheduleReminders(
        frequencyHours: Int,
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int,
        context: HydrationReminderContext? = nil
    ) async -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        // Clear tracked IDs for fresh scheduling
        scheduledNotificationIds.removeAll()
        
        // Get end of day (10 PM or start of quiet hours)
        let quietHoursStartComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursStart)
        var endOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endOfDayComponents.hour = quietHoursStartComponents.hour ?? 22
        endOfDayComponents.minute = quietHoursStartComponents.minute ?? 0
        
        guard let endOfDay = calendar.date(from: endOfDayComponents) else { return 0 }
        
        // Get start time (now + frequency or after quiet hours)
        var startTime = now.addingTimeInterval(TimeInterval(frequencyHours * 3600))
        
        // If start time falls in quiet hours, reschedule to next available time
        startTime = getNextAvailableTime(after: startTime)
        
        // Get optimal reminder hours from pattern learner if available
        let optimalHours = context?.patternLearner?.getOptimalReminderHours(
            quietHoursStart: quietHoursStartComponents.hour ?? 22,
            quietHoursEnd: calendar.component(.hour, from: settings.quietHoursEnd)
        ) ?? []
        
        var currentTime = startTime
        var count = 0
        let maxReminders = 5 // Limit to 5 reminders per day
        
        while currentTime < endOfDay && count < maxReminders {
            // Get next available time (skipping quiet hours)
            var availableTime = getNextAvailableTime(after: currentTime)
            
            // If pattern learner suggests better hours, try to align
            if !optimalHours.isEmpty {
                let currentHour = calendar.component(.hour, from: availableTime)
                if let betterHour = optimalHours.first(where: { $0 > currentHour && $0 < (quietHoursStartComponents.hour ?? 22) }) {
                    var betterComponents = calendar.dateComponents([.year, .month, .day], from: availableTime)
                    betterComponents.hour = betterHour
                    betterComponents.minute = 0
                    if let betterTime = calendar.date(from: betterComponents), betterTime > now {
                        availableTime = betterTime
                    }
                }
            }
            
            // Check if still within today's schedule window
            if availableTime < endOfDay {
                let identifier = await scheduleNotification(
                    at: availableTime,
                    progress: progress,
                    remainingMl: remainingMl,
                    effectiveIntake: effectiveIntake,
                    dailyGoal: dailyGoal,
                    streak: streak,
                    context: context
                )
                
                if let id = identifier {
                    scheduledNotificationIds.insert(id)
                    count += 1
                }
                
                currentTime = availableTime.addingTimeInterval(TimeInterval(frequencyHours * 3600))
            } else {
                break
            }
        }
        
        // Save scheduled IDs for persistence
        saveScheduledIds()
        
        print("🔔 NotificationService: Scheduled \(count) reminders (frequency: \(frequencyHours)h)")
        return count
    }
    
    /// Get the next available time that's not in quiet hours
    /// Handles overnight quiet hours properly (e.g., 22:00 to 07:00)
    private func getNextAvailableTime(after date: Date) -> Date {
        guard settings.isInQuietHours(date: date) else {
            return date
        }
        
        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursEnd)
        
        guard let endHour = endComponents.hour, let endMinute = endComponents.minute else {
            return date
        }
        
        // Build the quiet hours end time for today
        var nextComponents = calendar.dateComponents([.year, .month, .day], from: date)
        nextComponents.hour = endHour
        nextComponents.minute = endMinute
        
        guard let nextTime = calendar.date(from: nextComponents) else {
            return date
        }
        
        // If the end time has already passed today, it means we're in overnight quiet hours
        // and need to go to tomorrow's end time
        if nextTime <= date {
            return calendar.date(byAdding: .day, value: 1, to: nextTime) ?? date
        }
        
        return nextTime
    }
    
    @discardableResult
    private func scheduleNotification(
        at date: Date,
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        streak: Int,
        context: HydrationReminderContext? = nil
    ) async -> String? {
        let timeOfDay = TimeOfDay.current(date: date)
        
        // Generate message with context awareness
        let message = NotificationMessageGenerator.generateMessage(
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
            streak: streak,
            context: context
        )
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.hydrationReminder.identifier
        // Badge will be managed separately for accuracy
        
        // Add user info for tracking
        var userInfo: [String: Any] = [
            "type": "hydration_reminder",
            "progress": progress,
            "remainingMl": remainingMl,
            "scheduledTime": date.timeIntervalSince1970
        ]
        
        // Add context info if available
        if let ctx = context {
            userInfo["temperature"] = ctx.temperature ?? 0
            userInfo["exerciseMinutes"] = ctx.exerciseMinutes
            userInfo["isHotDay"] = ctx.isHotDay
            userInfo["recentlyExercised"] = ctx.recentlyExercised
        }
        
        content.userInfo = userInfo
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "hydration_\(Int(date.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            
            // Record in history
            let historyContext = NotificationHistoryContext(
                progress: progress,
                remainingMl: remainingMl,
                temperature: context?.temperature,
                exerciseMinutes: context?.exerciseMinutes,
                isHotDay: context?.isHotDay,
                timeOfDay: timeOfDay.displayName
            )
            let _ = historyManager.recordScheduled(
                type: .hydrationReminder,
                scheduledTime: date,
                context: historyContext
            )
            
            print("🔔 NotificationService: Scheduled notification for \(date)")
            return identifier
        } catch {
            print("🔔 NotificationService: Failed to schedule - \(error.localizedDescription)")
            return nil
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
    
    /// Cancel all scheduled hydration reminders (synchronous version for protocol conformance)
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
        
        scheduledNotificationIds.removeAll()
        saveScheduledIds()
    }
    
    /// Cancel all scheduled hydration reminders (async version)
    private func cancelAllRemindersAsync() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let hydrationIds = requests
            .filter { $0.identifier.starts(with: "hydration_") }
            .map { $0.identifier }
        
        if !hydrationIds.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: hydrationIds)
            print("🔔 NotificationService: Cancelled \(hydrationIds.count) reminders (async)")
        }
        
        scheduledNotificationIds.removeAll()
        saveScheduledIds()
    }
    
    /// Cancel specific notification by ID
    private func cancelNotification(withIdentifier identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledNotificationIds.remove(identifier)
        saveScheduledIds()
    }
    
    // MARK: - Badge Management
    
    /// Update app badge count based on pending notifications
    private func updateBadgeCount(pendingCount: Int) async {
        await MainActor.run {
            // Badge shows 1 if goal not met and there are reminders, 0 otherwise
            UIApplication.shared.applicationIconBadgeNumber = pendingCount > 0 ? 1 : 0
        }
    }
    
    /// Get current pending notification count
    func getPendingNotificationCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.filter { $0.identifier.starts(with: "hydration_") }.count
    }
    
    /// Get all pending reminders (hydration and medication)
    func getAllPendingReminders() async -> [PendingReminder] {
        let requests = await notificationCenter.pendingNotificationRequests()
        var reminders: [PendingReminder] = []
        
        for request in requests {
            let userInfo = request.content.userInfo
            let type = userInfo["type"] as? String ?? "unknown"
            
            // Extract scheduled time
            var scheduledTime: Date?
            if let timeInterval = userInfo["scheduledTime"] as? TimeInterval {
                scheduledTime = Date(timeIntervalSince1970: timeInterval)
            } else if let timeInterval = userInfo["scheduled_time"] as? TimeInterval {
                scheduledTime = Date(timeIntervalSince1970: timeInterval)
            }
            
            // Get trigger date if available
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                scheduledTime = trigger.nextTriggerDate()
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                scheduledTime = trigger.nextTriggerDate()
            }
            
            guard let time = scheduledTime, time > Date() else { continue }
            
            if type == "hydration_reminder" {
                let remainingMl = userInfo["remainingMl"] as? Int ?? 0
                reminders.append(PendingReminder(
                    id: request.identifier,
                    type: .hydration,
                    title: request.content.title,
                    body: request.content.body,
                    scheduledTime: time
                ))
            } else if type == "medication_reminder" {
                let medicationName = userInfo["medication_name"] as? String ?? "Medication"
                reminders.append(PendingReminder(
                    id: request.identifier,
                    type: .medication,
                    title: request.content.title,
                    body: request.content.body,
                    scheduledTime: time,
                    medicationName: medicationName
                ))
            }
        }
        
        // Sort by scheduled time
        return reminders.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    // MARK: - Notification Response Handler
    
    /// Handle user interaction with notification
    func handleNotificationResponse(response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        // Check notification type
        if let type = userInfo["type"] as? String {
            if type == "medication_reminder" {
                await handleMedicationNotificationResponse(response: response)
                return
            }
        }
        
        // Get scheduled time for history tracking
        let scheduledTime: Date
        if let scheduledTimeInterval = userInfo["scheduledTime"] as? TimeInterval {
            scheduledTime = Date(timeIntervalSince1970: scheduledTimeInterval)
        } else {
            scheduledTime = response.notification.date
        }
        
        // Handle hydration notifications
        switch actionIdentifier {
        case NotificationAction.log250ml.rawValue:
            await logWaterFromNotification(amount: 250)
            historyManager.recordActionByScheduledTime(scheduledTime, action: "log_250ml")
            
            // Record response time to pattern learner
            let responseTime = Date().timeIntervalSince(response.notification.date)
            DrinkingPatternLearner.shared.recordNotificationResponse(responseTime: responseTime)
            
        case NotificationAction.log500ml.rawValue:
            await logWaterFromNotification(amount: 500)
            historyManager.recordActionByScheduledTime(scheduledTime, action: "log_500ml")
            
            // Record response time to pattern learner
            let responseTime = Date().timeIntervalSince(response.notification.date)
            DrinkingPatternLearner.shared.recordNotificationResponse(responseTime: responseTime)
            
        case NotificationAction.remindLater.rawValue:
            // Use customizable snooze duration from settings
            await scheduleSnoozeReminder(delayMinutes: settings.snoozeMinutes)
            historyManager.recordActionByScheduledTime(scheduledTime, action: "snooze_\(settings.snoozeMinutes)m")
            
        case NotificationAction.dismiss.rawValue:
            // Stop reminders for 3 hours
            await scheduleSnoozeReminder(delayMinutes: 180)
            historyManager.recordActionByScheduledTime(scheduledTime, action: "dismiss")
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            historyManager.recordActionByScheduledTime(scheduledTime, action: "opened_app")
            print("🔔 NotificationService: User opened app from notification")
            
        default:
            break
        }
    }
    
    /// Handle medication notification response
    func handleMedicationNotificationResponse(response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        guard let medicationIdString = userInfo["medication_id"] as? String,
              let medicationId = UUID(uuidString: medicationIdString),
              let scheduledTimeInterval = userInfo["scheduled_time"] as? TimeInterval else {
            print("🔔 NotificationService: Invalid medication notification data")
            return
        }
        
        let scheduledTime = Date(timeIntervalSince1970: scheduledTimeInterval)
        
        switch actionIdentifier {
        case NotificationAction.medicationTaken.rawValue:
            await markMedicationAsTaken(medicationId: medicationId, scheduledTime: scheduledTime)
            
        case NotificationAction.medicationSkip.rawValue:
            await markMedicationAsSkipped(medicationId: medicationId, scheduledTime: scheduledTime)
            
        case NotificationAction.medicationSnooze.rawValue:
            await snoozeMedicationReminder(medicationId: medicationId, scheduledTime: scheduledTime, minutes: 15)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification - open app
            print("🔔 NotificationService: User opened app from medication notification")
            
        default:
            break
        }
        
        // Clear badge
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    private func markMedicationAsTaken(medicationId: UUID, scheduledTime: Date) async {
        guard let viewModel = medicationViewModel else {
            print("🔔 NotificationService: No medication view model available")
            return
        }
        
        do {
            try await viewModel.markAsTaken(medicationId: medicationId, scheduledTime: scheduledTime)
            print("🔔 NotificationService: Marked medication as taken from notification")
        } catch {
            print("🔔 NotificationService: Failed to mark as taken - \(error.localizedDescription)")
        }
    }
    
    private func markMedicationAsSkipped(medicationId: UUID, scheduledTime: Date) async {
        guard let viewModel = medicationViewModel else {
            print("🔔 NotificationService: No medication view model available")
            return
        }
        
        do {
            try await viewModel.markAsSkipped(medicationId: medicationId, scheduledTime: scheduledTime, notes: "Skipped from notification")
            print("🔔 NotificationService: Marked medication as skipped from notification")
        } catch {
            print("🔔 NotificationService: Failed to mark as skipped - \(error.localizedDescription)")
        }
    }
    
    private func snoozeMedicationReminder(medicationId: UUID, scheduledTime: Date, minutes: Int) async {
        // Get medication name from user info would be ideal, but we'll use a generic message
        let content = UNMutableNotificationContent()
        content.title = "💊 Medication Reminder"
        content.body = "Time for your medication"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.medicationReminder.identifier
        content.badge = 1
        
        content.userInfo = [
            "type": "medication_reminder",
            "medication_id": medicationId.uuidString,
            "scheduled_time": scheduledTime.timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let identifier = "medication_snooze_\(medicationId.uuidString)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("🔔 NotificationService: Snoozed medication reminder for \(minutes) minutes")
        } catch {
            print("🔔 NotificationService: Failed to snooze medication reminder - \(error.localizedDescription)")
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
        await scheduleSnoozeReminder(delayMinutes: delayHours * 60)
    }
    
    /// Schedule a snooze reminder with customizable delay in minutes
    private func scheduleSnoozeReminder(delayMinutes: Int) async {
        var triggerDate = Date().addingTimeInterval(TimeInterval(delayMinutes * 60))
        
        // If in quiet hours, reschedule to after quiet hours
        if settings.isInQuietHours(date: triggerDate) {
            triggerDate = getNextAvailableTime(after: triggerDate)
            print("🔔 NotificationService: Snooze was in quiet hours, rescheduled to \(triggerDate)")
        }
        
        let content = UNMutableNotificationContent()
        content.title = "💧 Hydration Reminder"
        
        // Customize body based on snooze duration
        if delayMinutes >= 60 {
            let hours = delayMinutes / 60
            content.body = "You snoozed \(hours) hour\(hours > 1 ? "s" : "") ago. Time to drink some water!"
        } else {
            content.body = "You snoozed \(delayMinutes) minutes ago. Time to drink some water!"
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.hydrationReminder.identifier
        content.userInfo = [
            "type": "hydration_reminder",
            "context": "snooze",
            "snoozeMinutes": delayMinutes,
            "scheduledTime": triggerDate.timeIntervalSince1970
        ]
        
        let timeInterval = triggerDate.timeIntervalSince(Date())
        guard timeInterval > 0 else {
            print("🔔 NotificationService: Invalid trigger time, skipping")
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let identifier = "hydration_snooze_\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            scheduledNotificationIds.insert(identifier)
            saveScheduledIds()
            
            // Record snooze notification in history
            let _ = historyManager.recordScheduled(
                type: .hydrationSnooze,
                scheduledTime: triggerDate,
                context: NotificationHistoryContext()
            )
            
            print("🔔 NotificationService: Scheduled snooze reminder for \(delayMinutes) minutes (\(triggerDate))")
        } catch {
            print("🔔 NotificationService: Failed to schedule snooze reminder - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Analytics
    
    /// Get notification statistics for analytics
    func getNotificationStats() -> NotificationStats {
        return historyManager.getStats()
    }
    
    /// Get today's notification history
    func getTodayNotificationHistory() -> [NotificationHistoryEntry] {
        return historyManager.getTodayHistory()
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: NotificationSettings) {
        let oldSnoozeMinutes = settings.snoozeMinutes
        settings = newSettings
        
        // If notifications are disabled, cancel all
        if !newSettings.enabled {
            cancelAllReminders()
        }
        
        // Refresh notification categories if snooze duration changed
        if oldSnoozeMinutes != newSettings.snoozeMinutes {
            refreshNotificationCategories()
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
    
    // MARK: - Scheduled IDs Persistence
    
    private func saveScheduledIds() {
        let idsArray = Array(scheduledNotificationIds)
        userDefaults.set(idsArray, forKey: scheduledIdsKey)
    }
    
    private static func loadScheduledIds() -> Set<String> {
        guard let idsArray = UserDefaults.standard.stringArray(forKey: "scheduled_notification_ids") else {
            return []
        }
        return Set(idsArray)
    }
    
    /// Reset scheduling state (useful when app launches or user changes settings)
    func resetSchedulingState() {
        lastProgressStatus = nil
        lastGoalMet = false
        scheduledNotificationIds.removeAll()
        saveScheduledIds()
    }
    
    // MARK: - Setup Notification Categories
    
    private func setupNotificationCategories() {
        // Hydration category - actions run in background for better UX
        let log250Action = UNNotificationAction(
            identifier: NotificationAction.log250ml.rawValue,
            title: NotificationAction.log250ml.title,
            options: [] // No .foreground - handles in background
        )
        
        let log500Action = UNNotificationAction(
            identifier: NotificationAction.log500ml.rawValue,
            title: NotificationAction.log500ml.title,
            options: [] // No .foreground - handles in background
        )
        
        // Use customizable snooze duration from settings
        let remindLaterAction = UNNotificationAction(
            identifier: NotificationAction.remindLater.rawValue,
            title: NotificationAction.remindLater.title(snoozeMinutes: settings.snoozeMinutes),
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: NotificationAction.dismiss.title,
            options: [.destructive]
        )
        
        let hydrationCategory = UNNotificationCategory(
            identifier: NotificationCategory.hydrationReminder.identifier,
            actions: [log250Action, log500Action, remindLaterAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay]
        )
        
        // Medication category - actions run in background for better UX
        let medicationTakenAction = UNNotificationAction(
            identifier: NotificationAction.medicationTaken.rawValue,
            title: NotificationAction.medicationTaken.title,
            options: [] // No .foreground - handles in background
        )
        
        let medicationSkipAction = UNNotificationAction(
            identifier: NotificationAction.medicationSkip.rawValue,
            title: NotificationAction.medicationSkip.title,
            options: []
        )
        
        let medicationSnoozeAction = UNNotificationAction(
            identifier: NotificationAction.medicationSnooze.rawValue,
            title: NotificationAction.medicationSnooze.title(snoozeMinutes: settings.snoozeMinutes),
            options: []
        )
        
        let medicationCategory = UNNotificationCategory(
            identifier: NotificationCategory.medicationReminder.identifier,
            actions: [medicationTakenAction, medicationSnoozeAction, medicationSkipAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay]
        )
        
        notificationCenter.setNotificationCategories([hydrationCategory, medicationCategory])
        print("🔔 NotificationService: Notification categories configured (snooze: \(settings.snoozeMinutes)m)")
    }
    
    /// Refresh notification categories when settings change (e.g., snooze duration)
    func refreshNotificationCategories() {
        setupNotificationCategories()
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
