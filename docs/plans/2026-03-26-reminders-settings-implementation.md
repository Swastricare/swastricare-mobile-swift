# Reminders & Notifications Settings — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unified reminders settings screen on both iOS and Android where users can see and toggle all notification categories with per-category detailed settings.

**Architecture:** iOS gets a new `RemindersSettingsView` + `RemindersSettingsViewModel` with a `ReminderSettings` data model stored in UserDefaults. Android already has `NotificationSettingsScreen` — it gets enhanced with missing detailed settings (medication snooze, menstrual sub-toggles, AI nudge frequency). Both follow existing MVVM + DI patterns.

**Tech Stack:** SwiftUI, Jetpack Compose, UserDefaults, SharedPreferences

---

## Task 1: iOS — Add `ReminderSettings` Data Model

**Files:**
- Modify: `swastricare-mobile-swift/Models/NotificationModels.swift`

**Step 1: Add new settings structs after the existing `NotificationSettings` struct (~line 92)**

Add these structs:

```swift
// MARK: - Unified Reminder Settings

struct ReminderSettings: Codable, Equatable {
    var globalEnabled: Bool
    var hydration: HydrationReminderSettings
    var medication: MedicationReminderSettings
    var diet: DietReminderSettings
    var menstrual: MenstrualReminderSettings
    var aiNudges: AIReminderSettings

    init(
        globalEnabled: Bool = true,
        hydration: HydrationReminderSettings = HydrationReminderSettings(),
        medication: MedicationReminderSettings = MedicationReminderSettings(),
        diet: DietReminderSettings = DietReminderSettings(),
        menstrual: MenstrualReminderSettings = MenstrualReminderSettings(),
        aiNudges: AIReminderSettings = AIReminderSettings()
    ) {
        self.globalEnabled = globalEnabled
        self.hydration = hydration
        self.medication = medication
        self.diet = diet
        self.menstrual = menstrual
        self.aiNudges = aiNudges
    }

    /// Migrate from legacy NotificationSettings
    static func migrateFromLegacy(_ legacy: NotificationSettings) -> ReminderSettings {
        ReminderSettings(
            globalEnabled: legacy.enabled,
            hydration: HydrationReminderSettings(
                enabled: legacy.enabled,
                smartReminders: legacy.smartReminders,
                quietHoursStart: legacy.quietHoursStart,
                quietHoursEnd: legacy.quietHoursEnd,
                reminderFrequencyHours: legacy.reminderFrequencyHours,
                showProgress: legacy.showProgress,
                showMotivational: legacy.showMotivational,
                snoozeMinutes: legacy.snoozeMinutes,
                useAdaptiveLearning: legacy.useAdaptiveLearning
            )
        )
    }
}

struct HydrationReminderSettings: Codable, Equatable {
    var enabled: Bool = true
    var smartReminders: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var reminderFrequencyHours: Int = 3
    var showProgress: Bool = true
    var showMotivational: Bool = true
    var snoozeMinutes: Int = 15
    var useAdaptiveLearning: Bool = true
}

struct MedicationReminderSettings: Codable, Equatable {
    var enabled: Bool = true
    var reminderBeforeDoseMinutes: Int = 15  // 15, 30, 60
    var missedDoseFollowUp: Bool = true
    var snoozeMinutes: Int = 15  // 5, 10, 15, 30
}

struct DietReminderSettings: Codable, Equatable {
    var enabled: Bool = true
    var breakfastEnabled: Bool = true
    var breakfastTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var lunchEnabled: Bool = true
    var lunchTime: Date = Calendar.current.date(from: DateComponents(hour: 12, minute: 30)) ?? Date()
    var dinnerEnabled: Bool = true
    var dinnerTime: Date = Calendar.current.date(from: DateComponents(hour: 19, minute: 30)) ?? Date()
    var snacksEnabled: Bool = false
    var snacksTime: Date = Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date()
    var logNudgeEnabled: Bool = true
}

struct MenstrualReminderSettings: Codable, Equatable {
    var enabled: Bool = false
    var periodPredictionEnabled: Bool = true
    var periodPredictionDaysBefore: Int = 2  // 1, 2, 3
    var dailySymptomCheckIn: Bool = true
    var symptomCheckInTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var ovulationAlertEnabled: Bool = true
    var cycleSummaryEnabled: Bool = true
}

struct AIReminderSettings: Codable, Equatable {
    var enabled: Bool = true
    var frequencyPerDay: Int = 2  // 1, 2, 3
    var useGlobalQuietHours: Bool = true
    var whatsAppNudgesEnabled: Bool = false
}
```

**Step 2: Verify the build compiles**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Models/NotificationModels.swift
git commit -m "feat(ios): add ReminderSettings data model with per-category sub-structs"
```

---

## Task 2: iOS — Add `RemindersSettingsViewModel`

**Files:**
- Create: `swastricare-mobile-swift/ViewModels/RemindersSettingsViewModel.swift`
- Modify: `swastricare-mobile-swift/Core/DependencyContainer.swift`

**Step 1: Create the ViewModel**

Create `swastricare-mobile-swift/ViewModels/RemindersSettingsViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
final class RemindersSettingsViewModel: ObservableObject {

    private let notificationService = NotificationService.shared
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "reminder_settings"
    private let legacySettingsKey = "notification_settings"

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
            Task { await rescheduleHydration() }
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

    // MARK: - Reschedule

    func rescheduleAll() {
        syncHydrationToLegacy()
        Task {
            await rescheduleHydration()
            await notificationService.scheduleDietReminders()
            await notificationService.scheduleMenstrualCycleNotifications()
        }
    }

    private func rescheduleHydration() async {
        // Sync hydration settings to the legacy NotificationSettings
        // so existing scheduling code picks them up
        notificationService.resetSchedulingState()
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
            // Save in new format
            if let encoded = try? JSONEncoder().encode(migrated) {
                defaults.set(encoded, forKey: "reminder_settings")
            }
            return migrated
        }

        return ReminderSettings()
    }
}
```

**Step 2: Add to DependencyContainer**

In `DependencyContainer.swift`, add after the `familyViewModel` lazy var (~line 107):

```swift
lazy var remindersSettingsViewModel: RemindersSettingsViewModel = {
    RemindersSettingsViewModel()
}()
```

**Step 3: Build verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/RemindersSettingsViewModel.swift swastricare-mobile-swift/Core/DependencyContainer.swift
git commit -m "feat(ios): add RemindersSettingsViewModel with migration from legacy settings"
```

---

## Task 3: iOS — Create `RemindersSettingsView`

**Files:**
- Create: `swastricare-mobile-swift/Views/Settings/RemindersSettingsView.swift`

**Step 1: Create the view**

Create `swastricare-mobile-swift/Views/Settings/RemindersSettingsView.swift` with these sections:

1. Permission status banner (reuse pattern from existing `NotificationSettingsView.permissionSection`)
2. Master toggle card
3. Hydration expandable card — absorb all hydration settings from `NotificationSettingsView`
4. Medication expandable card — before-dose picker, missed dose toggle, snooze picker
5. Diet expandable card — per-meal toggles + time pickers, log nudge toggle
6. Menstrual expandable card — period prediction, symptom check-in, ovulation, cycle summary
7. AI Nudges expandable card — frequency picker, WhatsApp toggle

Use `PremiumBackground()`, `.glass()` modifier for cards, `ScaleButtonStyle()` for buttons. Each card has a header with icon + name + toggle, and expands/collapses with animation using `@State private var expandedCategory: String?`.

The view should use `@StateObject private var viewModel = DependencyContainer.shared.remindersSettingsViewModel`.

Key pattern for expandable cards:

```swift
// Expandable card pattern
@State private var expandedCategory: String? = nil

private func categoryCard(
    id: String,
    icon: String,
    iconColor: Color,
    title: String,
    isEnabled: Binding<Bool>,
    @ViewBuilder content: () -> some View
) -> some View {
    VStack(spacing: 0) {
        // Header: icon + title + toggle
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 28)
            Text(title)
                .font(.headline)
            Spacer()
            Toggle("", isOn: isEnabled)
                .labelsHidden()
                .tint(iconColor)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                expandedCategory = expandedCategory == id ? nil : id
            }
        }

        // Expanded content
        if expandedCategory == id && isEnabled.wrappedValue {
            Divider().padding(.vertical, 8)
            content()
        }
    }
    .padding(16)
    .glass(cornerRadius: 16)
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
}
```

Include a test notification button in each expanded card (reuse existing pattern).

**Step 2: Build verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Settings/RemindersSettingsView.swift
git commit -m "feat(ios): add RemindersSettingsView with expandable per-category cards"
```

---

## Task 4: iOS — Wire Up Navigation

**Files:**
- Modify: `swastricare-mobile-swift/Views/Profile/ProfileView.swift`

**Step 1: Add "Reminders & Notifications" row to ProfileView**

In `ProfileView.swift`, in the `settingsSection` computed property (around line 454), add a NavigationLink row for "Reminders & Notifications" **before** the existing Notifications toggle. Replace the existing simple toggle with the NavigationLink:

Replace:
```swift
Toggle(isOn: $viewModel.notificationsEnabled) {
    Label("Notifications", systemImage: "bell.fill")
}
```

With:
```swift
NavigationLink(destination: RemindersSettingsView()) {
    HStack {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders & Notifications")
                    .foregroundColor(.primary)
                Text("Hydration, medication, diet, cycle, AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } icon: {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
```

**Step 2: Do the same in SettingsView.swift**

In `SettingsView.swift`, in the `settingsSection` (around line 480), replace the Notifications toggle with the same NavigationLink pattern.

**Step 3: Build verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/Profile/ProfileView.swift swastricare-mobile-swift/Views/Settings/SettingsView.swift
git commit -m "feat(ios): wire RemindersSettingsView into Profile and Settings navigation"
```

---

## Task 5: Android — Enhance `NotificationSettingsScreen` with Detailed Settings

The Android `NotificationSettingsScreen` already has per-category toggles. Add the missing detailed settings to match the design.

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/notifications/NotificationSettingsScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/notifications/NotificationSettingsViewModel.kt`

**Step 1: Add missing state fields to `NotificationSettingsState`**

In `NotificationSettingsViewModel.kt`, add to `NotificationSettingsState`:
```kotlin
// Medication detailed settings
val medicationReminderBeforeMinutes: Int = 15,  // 15, 30, 60
val missedDoseFollowUp: Boolean = true,
val medicationSnoozeMinutes: Int = 15,

// Menstrual detailed settings
val periodPredictionEnabled: Boolean = true,
val periodPredictionDaysBefore: Int = 2,
val dailySymptomCheckIn: Boolean = true,
val ovulationAlertEnabled: Boolean = true,
val cycleSummaryEnabled: Boolean = true,

// AI Nudge detailed settings
val aiNudgeFrequencyPerDay: Int = 2,
```

**Step 2: Add setter functions in ViewModel**

Add setter functions for each new field following the existing pattern (update notifService property + update state flow).

**Step 3: Add corresponding properties to `NotificationService.kt`**

Add SharedPreferences-backed properties for the new settings in the Android `NotificationService`.

**Step 4: Update `NotificationSettingsScreen` UI**

In the Medication section, add after the toggle:
- `FrequencySelector` for "Reminder before dose" (15min, 30min, 1hr)
- `NotifToggleRow` for "Missed dose follow-up"
- `FrequencySelector` for "Snooze duration" (5, 10, 15, 30 min)

In the Cycle section, add after the toggle:
- `NotifToggleRow` for "Period prediction alerts"
- `FrequencySelector` for "Days before period" (1, 2, 3 days)
- `NotifToggleRow` for "Daily symptom check-in"
- `NotifToggleRow` for "Ovulation alerts"
- `NotifToggleRow` for "Cycle summary"

In the AI Health Coach section, add after the toggle:
- `FrequencySelector` for "Daily frequency" (1x, 2x, 3x)

**Step 5: Build verify**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

**Step 6: Commit**

```bash
git add android/
git commit -m "feat(android): enhance NotificationSettingsScreen with detailed per-category settings"
```

---

## Task 6: Android — Add "Reminders & Notifications" Entry Point

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/settings/SettingsScreen.kt`

**Step 1: Update the Settings screen**

The Android SettingsScreen likely already has a navigation callback `onNavigateToNotificationSettings`. Verify this exists and ensure there's a prominent "Reminders & Notifications" row in the settings section (similar to the iOS pattern with bell icon and subtitle text).

If the row already exists as a simple "Notifications" entry, update the label and subtitle:
- Title: "Reminders & Notifications"
- Subtitle: "Hydration, medication, diet, cycle, AI"
- Icon: bell icon with gradient

**Step 2: Build verify**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/
git commit -m "feat(android): update settings entry point for Reminders & Notifications"
```

---

## Task 7: iOS — Integration Test

**Step 1: Full build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 2: Verify navigation flow works**

Manually check:
- Profile tab > Settings section > "Reminders & Notifications" row is visible
- Tapping it opens RemindersSettingsView
- All 5 category cards are visible
- Each card expands on tap
- Toggles work

**Step 3: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix(ios): integration fixes for reminders settings"
```

---

## Task 8: Android — Integration Test

**Step 1: Full build**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL

**Step 2: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix(android): integration fixes for reminders settings"
```
