# Unified Reminders & Notifications Settings

**Date:** 2026-03-26
**Platforms:** iOS (Swift/SwiftUI) + Android (Kotlin/Jetpack Compose)
**Storage:** Local only (UserDefaults / SharedPreferences)

## Overview

A unified RemindersSettingsView accessible from Profile/Settings where users can see and control all notification categories. Replaces the current hydration-only notification settings buried under Hydration Settings.

## Navigation

Profile/Settings screen gets a new "Reminders & Notifications" row (bell icon + chevron). This replaces the old path: Profile > Hydration Settings > Notification Settings.

Top of the view shows:
- System permission status banner (authorized/denied/not determined)
- Master toggle for all notifications

## Category Cards

5 expandable glass cards below the master toggle. Each has an icon, name, and per-category toggle in the collapsed header. Expanding reveals category-specific settings.

### Hydration (absorbs existing NotificationSettingsView)
- Smart Reminders toggle (adaptive frequency based on progress)
- Frequency picker (2-5 hours, disabled when smart is on)
- Quiet Hours start/end time pickers
- Snooze duration (5, 10, 15, 30, 60 min)
- Progress in notifications toggle
- Motivational messages toggle
- Adaptive learning toggle

### Medication
- Reminder timing before dose (15min, 30min, 1hr)
- Missed dose follow-up toggle (re-reminds if not marked taken)
- Snooze duration (5, 10, 15, 30 min)

### Diet
- Per-meal toggles + time pickers: Breakfast (8:00), Lunch (12:30), Dinner (19:30), Snacks (16:00)
- Log nudge toggle (reminds 30min after meal time if no entry)

### Menstrual Cycle
- Period prediction alert toggle (days before: 1, 2, 3)
- Daily symptom check-in toggle + time picker
- Ovulation window alert toggle
- Cycle summary toggle (end-of-cycle notification)

### AI Nudges
- Frequency picker (1x, 2x, 3x per day)
- Quiet hours (reuse global or separate)
- WhatsApp nudges toggle + phone number (migrated from existing)

## Data Model

```
ReminderSettings (Codable / Kotlinx Serializable, JSON in UserDefaults / SharedPreferences)
  globalEnabled: Bool
  hydration: HydrationReminderSettings   -- migrated from existing NotificationSettings
  medication: MedicationReminderSettings
  diet: DietReminderSettings
  menstrual: MenstrualReminderSettings
  aiNudges: AINotificationSettings
```

Each sub-struct has sensible defaults. On first launch after update, existing `notification_settings` key is migrated into `reminder_settings.hydration`, old key deleted.

## Service Layer

### iOS (NotificationService.swift)
- New per-category schedulers: scheduleMedicationReminders(), scheduleDietReminders(), scheduleMenstrualReminders(), scheduleAINudgeReminders()
- Existing hydration scheduling unchanged
- Each scheduler respects globalEnabled + category toggle
- rescheduleAllNotifications() rebuilds all pending notifications on setting change
- New notification categories/actions in NotificationModels.swift for diet, menstrual

### Android
- Mirror per-category scheduling
- WorkManager for periodic reminders (medication, diet meal times)
- Notification channels per category (Android requirement)

### Both
- Category toggle change cancels that category's pending notifications and reschedules
- Master toggle cancels/reschedules everything

## View Layer

### iOS
- New RemindersSettingsView.swift using PremiumBackground, .glass() cards, ScaleButtonStyle
- New RemindersSettingsViewModel (@MainActor, added to DependencyContainer as lazy var)
- Expandable cards via DisclosureGroup or custom animation
- Existing NotificationSettingsView deprecated

### Android
- New RemindersSettingsScreen.kt with expandable Compose cards
- New RemindersSettingsViewModel in AppContainer
- Navigation entry in AppNavigation.kt

### Entry Points
- iOS: "Reminders & Notifications" row in SettingsView/ProfileView, old hydration notification path removed
- Android: Same in Android settings/profile screen
