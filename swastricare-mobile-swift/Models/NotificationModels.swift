//
//  NotificationModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Notification settings and state management
//

import Foundation
import SwiftUI

// MARK: - Notification Settings

struct NotificationSettings: Codable, Equatable {
    var enabled: Bool
    var smartReminders: Bool
    var quietHoursStart: Date
    var quietHoursEnd: Date
    var reminderFrequencyHours: Int
    var showProgress: Bool
    var showMotivational: Bool
    var lastScheduledTime: Date?
    var snoozeMinutes: Int
    var useAdaptiveLearning: Bool
    
    /// Available snooze duration options
    static let snoozeDurationOptions: [Int] = [5, 10, 15, 30, 60]
    
    init(
        enabled: Bool = false,
        smartReminders: Bool = true,
        quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(),
        quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
        reminderFrequencyHours: Int = 3,
        showProgress: Bool = true,
        showMotivational: Bool = true,
        lastScheduledTime: Date? = nil,
        snoozeMinutes: Int = 15,
        useAdaptiveLearning: Bool = true
    ) {
        self.enabled = enabled
        self.smartReminders = smartReminders
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.reminderFrequencyHours = reminderFrequencyHours
        self.showProgress = showProgress
        self.showMotivational = showMotivational
        self.lastScheduledTime = lastScheduledTime
        self.snoozeMinutes = snoozeMinutes
        self.useAdaptiveLearning = useAdaptiveLearning
    }
    
    /// Get human-readable snooze duration description
    var snoozeDurationDescription: String {
        if snoozeMinutes >= 60 {
            return "\(snoozeMinutes / 60) hour"
        }
        return "\(snoozeMinutes) minutes"
    }
    
    /// Check if current time is within quiet hours
    func isInQuietHours(date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        guard let startHour = startComponents.hour, let startMinute = startComponents.minute,
              let endHour = endComponents.hour, let endMinute = endComponents.minute else {
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        // Handle overnight quiet hours (e.g., 22:00 to 07:00)
        if startMinutes > endMinutes {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        }
    }
    
    var quietHoursDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: quietHoursStart)) - \(formatter.string(from: quietHoursEnd))"
    }
}

// MARK: - Notification Permission Status

enum NotificationPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case provisional
    
    var displayName: String {
        switch self {
        case .notDetermined: return "Not Requested"
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .provisional: return "Provisional"
        }
    }
    
    var canSchedule: Bool {
        switch self {
        case .authorized, .provisional: return true
        default: return false
        }
    }
}

// MARK: - Hydration Progress Status

enum HydrationProgressStatus {
    case behindSchedule    // < 30% by noon
    case onTrack           // 30-70%
    case ahead             // > 70%
    case goalMet           // 100%+
    
    var reminderFrequencyHours: Int {
        switch self {
        case .behindSchedule: return 2
        case .onTrack: return 3
        case .ahead: return 4
        case .goalMet: return 0 // No more reminders
        }
    }
    
    var displayName: String {
        switch self {
        case .behindSchedule: return "Behind Schedule"
        case .onTrack: return "On Track"
        case .ahead: return "Ahead of Schedule"
        case .goalMet: return "Goal Met"
        }
    }
}

// MARK: - Time of Day

enum TimeOfDay {
    case morning    // 7 AM - 12 PM
    case afternoon  // 12 PM - 5 PM
    case evening    // 5 PM - 10 PM
    case night      // 10 PM - 7 AM
    
    static func current(date: Date = Date()) -> TimeOfDay {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        switch hour {
        case 7..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
    
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}

// MARK: - Notification Message Generator

struct NotificationMessageGenerator {
    
    /// Generate a motivational notification message based on context (backward compatible)
    static func generateMessage(
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        streak: Int
    ) -> (title: String, body: String) {
        return generateMessage(
            progress: progress,
            remainingMl: remainingMl,
            effectiveIntake: effectiveIntake,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
            streak: streak,
            context: nil
        )
    }
    
    /// Generate a motivational notification message with context awareness
    static func generateMessage(
        progress: Double,
        remainingMl: Int,
        effectiveIntake: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        streak: Int,
        context: HydrationReminderContext?
    ) -> (title: String, body: String) {
        
        // Check for context-specific messages first
        if let ctx = context {
            if let contextMessage = generateContextMessage(context: ctx, remainingMl: remainingMl, progress: progress) {
                return contextMessage
            }
        }
        
        let progressStatus = getProgressStatus(progress: progress, timeOfDay: timeOfDay)
        
        switch progressStatus {
        case .goalMet:
            return generateGoalMetMessage(effectiveIntake: effectiveIntake, streak: streak)
            
        case .ahead:
            return generateAheadMessage(progress: progress, remainingMl: remainingMl, timeOfDay: timeOfDay)
            
        case .onTrack:
            return generateOnTrackMessage(progress: progress, remainingMl: remainingMl, timeOfDay: timeOfDay, context: context)
            
        case .behindSchedule:
            return generateBehindMessage(progress: progress, remainingMl: remainingMl, timeOfDay: timeOfDay, context: context)
        }
    }
    
    // MARK: - Context-Aware Messages
    
    private static func generateContextMessage(
        context: HydrationReminderContext,
        remainingMl: Int,
        progress: Double
    ) -> (String, String)? {
        
        // Hot weather + recent exercise - highest priority
        if context.isHotDay && context.recentlyExercised {
            let temp = Int(context.temperature ?? 30)
            return (
                "🏃‍♂️🌡️ Stay Hydrated!",
                "After your workout in \(temp)°C weather, you need extra water! \(remainingMl)ml remaining."
            )
        }
        
        // Hot weather messages
        if context.isHotDay {
            let temp = Int(context.temperature ?? 30)
            let messages = [
                ("🌡️ Hot Day Alert", "It's \(temp)°C outside! Your body needs more water. \(remainingMl)ml to go."),
                ("☀️ Beat the Heat", "Stay cool and hydrated! It's \(temp)°C. Drink some water now."),
                ("🥵 Hydration Boost", "Hot weather means you need extra fluids. \(remainingMl)ml remaining.")
            ]
            return messages.randomElement()
        }
        
        // Post-exercise messages
        if context.recentlyExercised {
            let exerciseMins = context.exerciseMinutes
            let messages = [
                ("🏃‍♂️ Post-Workout", "Great \(exerciseMins) min workout! Time to rehydrate. \(remainingMl)ml remaining."),
                ("💪 Recovery Time", "After your exercise, replenish your fluids! \(remainingMl)ml to go."),
                ("🎯 Fuel Your Body", "Exercise depletes water. Drink up! \(remainingMl)ml remaining.")
            ]
            return messages.randomElement()
        }
        
        // Pattern-based messages (if we had pattern info in context)
        // This would require passing pattern learner data through context
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private static func getProgressStatus(progress: Double, timeOfDay: TimeOfDay) -> HydrationProgressStatus {
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
    
    private static func generateGoalMetMessage(effectiveIntake: Int, streak: Int) -> (String, String) {
        let titles = [
            "🎉 Goal Achieved!",
            "⭐ Amazing Work!",
            "🏆 Well Done!",
            "💪 You Did It!"
        ]
        
        var bodies = [
            "You've reached your daily goal of \(effectiveIntake)ml! Keep up the great work!",
            "Fantastic! You've hit your hydration target. Your body thanks you!",
            "Goal complete! You're staying healthy and hydrated."
        ]
        
        // Add streak-specific messages
        if streak >= 7 {
            bodies.append("🔥 \(streak) day streak! You're a hydration champion!")
        } else if streak >= 3 {
            bodies.append("That's \(streak) days in a row! Keep the streak going!")
        } else if streak > 1 {
            bodies.append("That's \(streak) days in a row! You're on fire!")
        }
        
        return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
    }
    
    private static func generateAheadMessage(progress: Double, remainingMl: Int, timeOfDay: TimeOfDay) -> (String, String) {
        let percent = Int(progress * 100)
        
        switch timeOfDay {
        case .morning:
            return ("☀️ Great Start!", "You're \(percent)% toward your goal! Keep it up!")
        case .afternoon:
            return ("🌟 Excellent Progress!", "You're ahead of schedule at \(percent)%. Just \(remainingMl)ml to go!")
        case .evening:
            return ("🎯 Almost There!", "Only \(remainingMl)ml left! You've got this!")
        case .night:
            return ("💧 Final Push", "You're so close! \(remainingMl)ml more to reach your goal.")
        }
    }
    
    private static func generateOnTrackMessage(
        progress: Double,
        remainingMl: Int,
        timeOfDay: TimeOfDay,
        context: HydrationReminderContext? = nil
    ) -> (String, String) {
        let percent = Int(progress * 100)
        
        switch timeOfDay {
        case .morning:
            let messages = [
                ("☕ Morning Hydration", "Good morning! Start your day with a glass of water 💧"),
                ("🌅 Rise & Hydrate", "Your body loses water overnight. Time to rehydrate!"),
                ("💪 Morning Boost", "Kickstart your metabolism with some water!")
            ]
            return messages.randomElement() ?? messages[0]
            
        case .afternoon:
            let messages = [
                ("📊 Hydration Check", "You're \(percent)% toward your goal! Keep going 💪"),
                ("☕ Afternoon Reminder", "Afternoon slump? A glass of water can help!"),
                ("💧 Stay Hydrated", "\(remainingMl)ml remaining. You're doing great!")
            ]
            return messages.randomElement() ?? messages[0]
            
        case .evening:
            let messages = [
                ("🌆 Evening Hydration", "Don't forget your evening water! \(remainingMl)ml to go."),
                ("⭐ Keep It Up", "You're at \(percent)%. Finish strong!"),
                ("💧 Almost Done", "Just \(remainingMl)ml more to hit your goal!")
            ]
            return messages.randomElement() ?? messages[0]
            
        case .night:
            return ("🌙 Last Call", "Time for a final glass before bed. \(remainingMl)ml left!")
        }
    }
    
    private static func generateBehindMessage(
        progress: Double,
        remainingMl: Int,
        timeOfDay: TimeOfDay,
        context: HydrationReminderContext? = nil
    ) -> (String, String) {
        let percent = Int(progress * 100)
        
        // Add extra urgency for hot days
        let hotDaySuffix = context?.isHotDay == true ? " Stay cool!" : ""
        
        switch timeOfDay {
        case .morning:
            return ("⚠️ Let's Get Started", "Don't forget to hydrate! Start your day with water.\(hotDaySuffix)")
            
        case .afternoon:
            return ("🚨 Hydration Alert", "You're at \(percent)%. Time to catch up! Drink some water now.\(hotDaySuffix)")
            
        case .evening:
            return ("⏰ Urgent Reminder", "You still need \(remainingMl)ml. Let's reach that goal!\(hotDaySuffix)")
            
        case .night:
            return ("💧 Final Reminder", "You're behind today. Try to drink \(remainingMl)ml before bed.")
        }
    }
}

// MARK: - Notification Action Identifiers

enum NotificationAction: String {
    case log250ml = "LOG_250ML"
    case log500ml = "LOG_500ML"
    case remindLater = "REMIND_LATER"
    case dismiss = "DISMISS"
    
    // Medication actions
    case medicationTaken = "MEDICATION_TAKEN"
    case medicationSkip = "MEDICATION_SKIP"
    case medicationSnooze = "MEDICATION_SNOOZE"
    
    var title: String {
        switch self {
        case .log250ml: return "Log 250ml"
        case .log500ml: return "Log 500ml"
        case .remindLater: return "Remind Later"
        case .dismiss: return "Dismiss"
        case .medicationTaken: return "✓ Taken"
        case .medicationSkip: return "Skip"
        case .medicationSnooze: return "Snooze 15m"
        }
    }
    
    var icon: String {
        switch self {
        case .log250ml: return "drop"
        case .log500ml: return "drop.fill"
        case .remindLater: return "clock"
        case .dismiss: return "xmark"
        case .medicationTaken: return "checkmark.circle.fill"
        case .medicationSkip: return "xmark.circle"
        case .medicationSnooze: return "clock.fill"
        }
    }
}

// MARK: - Notification Category Identifiers

enum NotificationCategory: String {
    case hydrationReminder = "HYDRATION_REMINDER"
    case medicationReminder = "MEDICATION_REMINDER"
    
    var identifier: String { rawValue }
}

// MARK: - Push Token Record

struct PushTokenRecord: Codable {
    let userId: UUID
    let deviceToken: String
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceToken = "device_token"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
