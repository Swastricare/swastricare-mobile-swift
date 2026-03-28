# Analytics Full-Depth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add complete end-to-end analytics (screen dwell times, feature events, session duration) to both iOS and Android, stored in the existing Supabase `app_events` table.

**Architecture:** DB gets a `platform` column; both services add `logScreen`/`trackScreen` with duration; a new `ViewModifier` (iOS) and `@Composable` (Android) use `onDisappear`/`DisposableEffect` to emit a single `screen_view` event on exit; session end is emitted when app backgrounds.

**Tech Stack:** Swift/SwiftUI + AppAnalyticsService.swift (iOS), Kotlin/Compose + AppAnalyticsService.kt (Android), Supabase `app_events` table, `xcodebuild` for iOS verification, `gradlew assembleDebug` for Android.

**No unit tests exist.** Build verification is the only check: iOS = `xcodebuild`, Android = `gradlew assembleDebug`.

---

## Task 1: DB Migration — add `platform` column

**Files:**
- Create: `supabase/migrations/20260328000001_add_platform_to_app_events.sql`

**Step 1: Create the migration file**

```sql
-- Add platform column to app_events for reliable iOS/Android split.
-- Android service already sends platform:"android"; iOS will send platform:"ios".
ALTER TABLE public.app_events
    ADD COLUMN IF NOT EXISTS platform VARCHAR(20);

CREATE INDEX IF NOT EXISTS idx_app_events_platform ON public.app_events(platform)
    WHERE platform IS NOT NULL;
```

**Step 2: Apply migration locally**

```bash
supabase db push
```
Expected: migration applies with no errors.

**Step 3: Commit**

```bash
git add supabase/migrations/20260328000001_add_platform_to_app_events.sql
git commit -m "feat(db): add platform column to app_events"
```

---

## Task 2: iOS Service — add screen/session methods + platform field

**Files:**
- Modify: `swastricare-mobile-swift/Services/AppAnalyticsService.swift`

**Step 1: Add `platform: "ios"` to `deviceInfo` in `enqueue()`**

In the `enqueue()` method (~line 246), change the `deviceInfo` dict:

```swift
let deviceInfo: [String: String] = [
    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
    "os": "iOS",
    "device_model": DeviceModelHelper.deviceModelName(),
    "platform": "ios"
]
```

**Step 2: Replace the existing `logScreen` method (line 62–66) with a duration-aware version**

Remove the old `logScreen` and add:

```swift
/// Log a screen view with dwell time. Called from ScreenTrackingModifier on disappear.
func logScreen(_ name: String, durationSeconds: Int) {
    log(
        eventName: "screen_view",
        eventType: "screen",
        properties: ["screen": name, "duration_seconds": durationSeconds]
    )
}
```

**Step 3: Add session tracking properties and `logSessionEnd()` method**

Add a `sessionStartTime` property near the other private properties (after line 35):

```swift
private var sessionStartTime: Date = Date()
```

Add the session end method in the `// MARK: - Auth events` section:

```swift
// MARK: - Session

func logSessionEnd() {
    let duration = Int(Date().timeIntervalSince(sessionStartTime))
    log(eventName: "session_end", eventType: "action", properties: ["duration_seconds": duration])
    sessionStartTime = Date() // Reset for next session
}
```

**Step 4: Add feature event methods for Diet**

Add after the `// MARK: - Vault` section:

```swift
// MARK: - Diet

func logFoodSearched(queryLength: Int, resultsCount: Int) {
    log(eventName: "food_searched", eventType: "feature_usage",
        properties: ["query_length": queryLength, "results_count": resultsCount])
}

func logFoodAdded(mealType: String, calories: Int, isCustom: Bool) {
    log(eventName: "food_added", eventType: "feature_usage",
        properties: ["meal_type": mealType, "calories": calories, "is_custom": isCustom])
}

func logFoodDeleted(mealType: String) {
    log(eventName: "food_deleted", eventType: "feature_usage", properties: ["meal_type": mealType])
}

func logMealCopied() {
    log(eventName: "meal_copied", eventType: "feature_usage", properties: [:])
}

func logCalorieGoalReached(goalKcal: Int, actualKcal: Int) {
    log(eventName: "calorie_goal_reached", eventType: "feature_usage",
        properties: ["goal_kcal": goalKcal, "actual_kcal": actualKcal])
}
```

**Step 5: Add feature event methods for Cycle, Family, Settings, AR, Notifications**

```swift
// MARK: - Menstrual Cycle

func logCycleLogged(entryType: String) {
    log(eventName: "cycle_logged", eventType: "feature_usage", properties: ["entry_type": entryType])
}

func logSymptomLogged(symptomType: String) {
    log(eventName: "symptom_logged", eventType: "feature_usage", properties: ["symptom_type": symptomType])
}

func logCyclePredictionViewed() {
    log(eventName: "cycle_prediction_viewed", eventType: "feature_usage", properties: [:])
}

// MARK: - Family

func logFamilyCreated() {
    log(eventName: "family_created", eventType: "feature_usage", properties: [:])
}

func logFamilyJoined() {
    log(eventName: "family_joined", eventType: "feature_usage", properties: [:])
}

func logFamilyMemberViewed() {
    log(eventName: "family_member_viewed", eventType: "feature_usage", properties: [:])
}

func logFamilyInviteSent() {
    log(eventName: "family_invite_sent", eventType: "feature_usage", properties: [:])
}

// MARK: - Settings

func logNotificationToggled(type: String, enabled: Bool) {
    log(eventName: "notification_toggled", eventType: "feature_usage",
        properties: ["type": type, "enabled": enabled])
}

func logProfileUpdated(fieldsChanged: [String]) {
    log(eventName: "profile_updated", eventType: "feature_usage",
        properties: ["fields_changed": fieldsChanged.joined(separator: ",")])
}

func logHealthKitToggled(enabled: Bool) {
    log(eventName: "healthkit_toggled", eventType: "feature_usage", properties: ["enabled": enabled])
}

// MARK: - AR

func logARLaunched() {
    log(eventName: "ar_launched", eventType: "feature_usage", properties: [:])
}

func logARScanCompleted(durationSeconds: Int) {
    log(eventName: "ar_scan_completed", eventType: "feature_usage",
        properties: ["duration_seconds": durationSeconds])
}

// MARK: - Notifications

func logNotificationTapped(notificationType: String) {
    log(eventName: "notification_tapped", eventType: "feature_usage",
        properties: ["notification_type": notificationType])
}
```

**Step 6: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 7: Commit**

```bash
git add swastricare-mobile-swift/Services/AppAnalyticsService.swift
git commit -m "feat(ios): add screen/session/feature analytics methods to AppAnalyticsService"
```

---

## Task 3: Android Service — add screen/session/feature methods

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/services/AppAnalyticsService.kt`

**Step 1: Add `trackScreen()` and `trackSessionEnd()` in the convenience methods section (after `trackError`, before flush logic)**

```kotlin
fun trackScreen(screenName: String, durationSeconds: Int) {
    track("screen_view", mapOf("screen" to screenName, "duration_seconds" to durationSeconds.toString()))
}

fun trackSessionEnd(durationSeconds: Long) {
    track("session_end", mapOf("duration_seconds" to durationSeconds.toString()))
    sessionStartTime = System.currentTimeMillis()
}
```

**Step 2: Emit `session_end` in `onStop`**

Replace the existing `onStop` (line 159–163):

```kotlin
override fun onStop(owner: LifecycleOwner) {
    val durationSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
    trackSessionEnd(durationSeconds)
    track("app_background")
    scope.launch { flush() }
}
```

**Step 3: Add Diet feature event methods**

```kotlin
// Diet
fun trackFoodSearched(queryLength: Int, resultsCount: Int) {
    track("food_searched", mapOf("query_length" to queryLength.toString(), "results_count" to resultsCount.toString()))
}

fun trackFoodAdded(mealType: String, calories: Int, isCustom: Boolean) {
    track("food_added", mapOf("meal_type" to mealType, "calories" to calories.toString(), "is_custom" to isCustom.toString()))
}

fun trackFoodDeleted(mealType: String) {
    track("food_deleted", mapOf("meal_type" to mealType))
}

fun trackMealCopied() {
    track("meal_copied")
}

fun trackCalorieGoalReached(goalKcal: Int, actualKcal: Int) {
    track("calorie_goal_reached", mapOf("goal_kcal" to goalKcal.toString(), "actual_kcal" to actualKcal.toString()))
}
```

**Step 4: Add Cycle, Family, Settings, Notifications methods**

```kotlin
// Menstrual Cycle
fun trackCycleLogged(entryType: String) {
    track("cycle_logged", mapOf("entry_type" to entryType))
}

fun trackSymptomLogged(symptomType: String) {
    track("symptom_logged", mapOf("symptom_type" to symptomType))
}

fun trackCyclePredictionViewed() {
    track("cycle_prediction_viewed")
}

// Family
fun trackFamilyCreated() { track("family_created") }
fun trackFamilyJoined() { track("family_joined") }
fun trackFamilyMemberViewed() { track("family_member_viewed") }
fun trackFamilyInviteSent() { track("family_invite_sent") }

// Settings
fun trackNotificationToggled(type: String, enabled: Boolean) {
    track("notification_toggled", mapOf("type" to type, "enabled" to enabled.toString()))
}

fun trackProfileUpdated(fieldsChanged: List<String>) {
    track("profile_updated", mapOf("fields_changed" to fieldsChanged.joinToString(",")))
}

fun trackHealthConnectToggled(enabled: Boolean) {
    track("health_connect_toggled", mapOf("enabled" to enabled.toString()))
}

// Notifications
fun trackNotificationTapped(notificationType: String) {
    track("notification_tapped", mapOf("notification_type" to notificationType))
}

// AR
fun trackARLaunched() { track("ar_launched") }
fun trackARScanCompleted(durationSeconds: Int) {
    track("ar_scan_completed", mapOf("duration_seconds" to durationSeconds.toString()))
}
```

**Step 5: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: `BUILD SUCCESSFUL`

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/services/AppAnalyticsService.kt
git commit -m "feat(android): add screen/session/feature analytics methods to AppAnalyticsService"
```

---

## Task 4: iOS — create View+ScreenTracking.swift

**Files:**
- Create: `swastricare-mobile-swift/Services/View+ScreenTracking.swift`

**Step 1: Create the file**

```swift
//
//  View+ScreenTracking.swift
//  swastricare-mobile-swift
//
//  Attaches a screen_view analytics event (with dwell time) to any SwiftUI View.
//  Usage: add .trackScreen("ScreenName") to the outermost view of each full screen.
//

import SwiftUI

private struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    @State private var enteredAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear { enteredAt = Date() }
            .onDisappear {
                let duration = enteredAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
                AppAnalyticsService.shared.logScreen(screenName, durationSeconds: duration)
                enteredAt = nil
            }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(screenName: name))
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add "swastricare-mobile-swift/Services/View+ScreenTracking.swift"
git commit -m "feat(ios): add ScreenTrackingModifier for dwell-time screen_view events"
```

---

## Task 5: iOS — session end on app background

**Files:**
- Modify: `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift`

**Step 1: Add session flush to `handleScenePhaseChange` in the `.background` case (~line 362)**

Find the `.background:` case and add two lines at the end of it:

```swift
case .background:
    // Lock the app when going to background
    if authViewModel.isAuthenticated && UserDefaults.standard.bool(forKey: "biometricEnabled") {
        lockViewModel.lock()
    }
    // Emit session_end and flush analytics
    AppAnalyticsService.shared.logSessionEnd()
    Task { await AppAnalyticsService.shared.flushNow() }
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add "swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift"
git commit -m "feat(ios): emit session_end + flush analytics on app background"
```

---

## Task 6: iOS — add `.trackScreen()` to Auth, Onboarding, Lock screens

**Files to modify** (add `.trackScreen("Name")` to the outermost view's body return):
- `Views/Auth/AuthView.swift` → `"Auth"`
- `Views/Auth/ConsentView.swift` → `"Consent"`
- `Views/Auth/ReferralCodeEntryView.swift` → `"ReferralCodeEntry"`
- `Views/App/ForceUpdateView.swift` → `"ForceUpdate"`
- `Views/Splash/SplashView.swift` → `"Splash"`
- `Views/Onboarding/OnboardingView.swift` → `"Onboarding"`
- `Views/Onboarding/HealthProfileQuestionnaireView.swift` → `"HealthProfileQuestionnaire"`
- `Views/Lock/LockScreenView.swift` → `"LockScreen"`

**Pattern for each file:** Find the outermost `var body: some View { ... }` return value (usually a `NavigationStack`, `ZStack`, or `VStack`) and chain `.trackScreen("Name")` at the end.

Example — in `AuthView.swift`, if body returns:
```swift
var body: some View {
    NavigationStack { ... }
}
```
Change to:
```swift
var body: some View {
    NavigationStack { ... }
        .trackScreen("Auth")
}
```

**Step 1: Add `.trackScreen()` to all 8 files above following the pattern.**

**Step 2: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Auth/ swastricare-mobile-swift/Views/App/ \
        swastricare-mobile-swift/Views/Splash/ swastricare-mobile-swift/Views/Onboarding/ \
        swastricare-mobile-swift/Views/Lock/
git commit -m "feat(ios): track screen views for Auth/Onboarding/Lock screens"
```

---

## Task 7: iOS — add `.trackScreen()` to Home, Hydration, Medication, Diet screens

**Files:**
- `Views/Home/HomeView.swift` → `"Home"` (check if HomeViewV2.swift is the active one — if so, track both as "Home")
- `Views/Home/HydrationView.swift` → `"Hydration"`
- `Views/Home/HydrationSettingsView.swift` → `"HydrationSettings"`
- `Views/Home/MedicationsView.swift` → `"Medications"`
- `Views/Home/MedicationDetailView.swift` → `"MedicationDetail"`
- `Views/Home/AddMedicationView.swift` → `"AddMedication"`
- `Views/Home/DietView.swift` → `"Diet"`
- `Views/Home/FoodSearchView.swift` → `"FoodSearch"`
- `Views/Home/AddFoodView.swift` → `"AddFood"`
- `Views/Home/FoodSnapView.swift` → `"FoodSnap"`
- `Views/Home/BarcodeScannerView.swift` → `"BarcodeScanner"`
- `Views/Home/DietSettingsView.swift` → `"DietSettings"`
- `Views/Home/NotificationSettingsView.swift` → `"NotificationSettings"`
- `Views/Home/RemindersView.swift` → `"Reminders"`

Same pattern as Task 6: chain `.trackScreen("Name")` on the outermost view in `var body`.

**Step 1: Add `.trackScreen()` to all 14 files above.**

**Step 2: Build + commit**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
git add swastricare-mobile-swift/Views/Home/
git commit -m "feat(ios): track screen views for Home/Hydration/Medication/Diet screens"
```

---

## Task 8: iOS — add `.trackScreen()` to HeartRate, Run, Tracker screens

**Files:**
- `Views/HeartRate/HeartRateView.swift` → `"HeartRate"`
- `Views/HeartRate/HeartRateAnalyticsView.swift` → `"HeartRateAnalytics"`
- `Views/HeartRate/HeartRateDisclaimerView.swift` → `"HeartRateDisclaimer"`
- `Views/HeartRate/HeartRateResultView.swift` → `"HeartRateResult"`
- `Views/Run/RunActivityView.swift` → `"RunActivity"`
- `Views/Run/RunCalendarView.swift` → `"RunCalendar"`
- `Views/Run/ActivityDetailView.swift` → `"ActivityDetail"`
- `Views/Run/LiveActivityTrackingView.swift` → `"LiveActivityTracking"`
- `Views/Run/RouteMapView.swift` → `"RouteMap"`
- `Views/Run/WorkoutRecoveryView.swift` → `"WorkoutRecovery"`
- `Views/Tracker/TrackerView.swift` → `"Tracker"`
- `Views/Tracker/HealthAnalyticsView.swift` → `"HealthAnalytics"`
- `Views/Tracker/HealthStreaksView.swift` → `"HealthStreaks"`

**Step 1: Add `.trackScreen()` to all 13 files above.**

**Step 2: Build + commit**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
git add swastricare-mobile-swift/Views/HeartRate/ swastricare-mobile-swift/Views/Run/ \
        swastricare-mobile-swift/Views/Tracker/
git commit -m "feat(ios): track screen views for HeartRate/Run/Tracker screens"
```

---

## Task 9: iOS — add `.trackScreen()` to Profile, Settings, AI, Vault screens

**Files:**
- `Views/Profile/ProfileView.swift` → `"Profile"`
- `Views/Profile/AccountView.swift` → `"Account"`
- `Views/Profile/FamilyView.swift` → `"Family"`
- `Views/Profile/HealthDataSettingsView.swift` → `"HealthDataSettings"`
- `Views/Profile/ThemeSettingsView.swift` → `"ThemeSettings"`
- `Views/Settings/SettingsView.swift` → `"Settings"`
- `Views/Settings/GoalsSettingsView.swift` → `"GoalsSettings"`
- `Views/Settings/RemindersSettingsView.swift` → `"RemindersSettings"`
- `Views/AI/AIView.swift` → `"AI"`
- `Views/AI/AIReferralGateView.swift` → `"AIReferralGate"`
- `Views/AI/MedicalDisclaimerView.swift` → `"MedicalDisclaimer"`
- `Views/Vault/VaultView.swift` → `"Vault"`

**Step 1: Add `.trackScreen()` to all 12 files above.**

**Step 2: Build + commit**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
git add swastricare-mobile-swift/Views/Profile/ swastricare-mobile-swift/Views/Settings/ \
        swastricare-mobile-swift/Views/AI/ swastricare-mobile-swift/Views/Vault/
git commit -m "feat(ios): track screen views for Profile/Settings/AI/Vault screens"
```

---

## Task 10: iOS — add `.trackScreen()` to MenstrualCycle and AR screens

**Files:**
- `Views/MenstrualCycle/MenstrualCycleView.swift` → `"MenstrualCycle"`
- `Views/AR/ARBodyScanView.swift` → `"ARBodyScan"`

**Step 1: Add `.trackScreen()` to both files.**

**Step 2: Build + commit**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
git add swastricare-mobile-swift/Views/MenstrualCycle/ swastricare-mobile-swift/Views/AR/
git commit -m "feat(ios): track screen views for MenstrualCycle and AR screens"
```

---

## Task 11: Android — create ScreenTracking.kt

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/components/ScreenTracking.kt`

**Step 1: Create the file**

```kotlin
package com.swastricare.health.ui.components

import androidx.compose.runtime.*
import com.swastricare.health.data.services.AppAnalyticsService

/**
 * Emits a screen_view event with dwell time when the composable leaves composition.
 * Place at the top of each full-screen composable.
 *
 * Usage: TrackScreen("Hydration", analyticsService)
 */
@Composable
fun TrackScreen(name: String, analyticsService: AppAnalyticsService) {
    val enteredAt = remember { System.currentTimeMillis() }
    DisposableEffect(name) {
        onDispose {
            val durationSeconds = ((System.currentTimeMillis() - enteredAt) / 1000).toInt()
            analyticsService.trackScreen(name, durationSeconds)
        }
    }
}
```

**Step 2: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/components/ScreenTracking.kt
git commit -m "feat(android): add TrackScreen composable for dwell-time screen_view events"
```

---

## Task 12: Android — add `TrackScreen()` to Auth and Onboarding screens

**Files:**
Each screen composable function receives `analyticsService: AppAnalyticsService` via the navigation graph. If a screen doesn't already receive it, thread it through from `AppNavigation.kt`.

Screens:
- `ui/screens/auth/LoginScreen.kt` → `TrackScreen("Login", analyticsService)`
- `ui/screens/auth/SignUpScreen.kt` → `TrackScreen("SignUp", analyticsService)`
- `ui/screens/auth/EmailVerificationScreen.kt` → `TrackScreen("EmailVerification", analyticsService)`
- `ui/screens/auth/ResetPasswordScreen.kt` → `TrackScreen("ResetPassword", analyticsService)`
- `ui/screens/onboarding/OnboardingScreen.kt` → `TrackScreen("Onboarding", analyticsService)`
- `ui/screens/onboarding/ConsentScreen.kt` → `TrackScreen("Consent", analyticsService)`
- `ui/screens/onboarding/HealthProfileScreen.kt` → `TrackScreen("HealthProfile", analyticsService)`
- `ui/screens/splash/SplashScreen.kt` → skip (too brief, system-level)
- `ui/screens/update/ForceUpdateScreen.kt` → `TrackScreen("ForceUpdate", analyticsService)`

**Pattern for each file:** Add `TrackScreen("ScreenName", analyticsService)` as the first statement inside the top-level composable function body. If `analyticsService` is not a parameter, add it.

Example — in `LoginScreen.kt`:
```kotlin
@Composable
fun LoginScreen(
    onNavigateToSignUp: () -> Unit,
    onLoginSuccess: () -> Unit,
    analyticsService: AppAnalyticsService    // add if missing
) {
    TrackScreen("Login", analyticsService)   // add as first line
    // ... rest of screen
}
```

For screens that use Hilt `hiltViewModel()` and don't receive `analyticsService` directly, retrieve it from the ViewModel or from `AppContainer` via local composition.

**Step 1: Add `TrackScreen()` to all 8 files above.**

**Step 2: Update `AppNavigation.kt`** to pass `analyticsService` to any screens that now require it.

**Step 3: Build + commit**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/auth/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/splash/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/update/ \
        android/app/src/main/kotlin/com/swastricare/health/navigation/
git commit -m "feat(android): track screen views for Auth/Onboarding screens"
```

---

## Task 13: Android — add `TrackScreen()` to Home, Hydration, Medication, Diet screens

**Files:**
- `ui/screens/home/HomeScreen.kt` → `"Home"`
- `ui/screens/hydration/HydrationScreen.kt` → `"Hydration"`
- `ui/screens/hydration/HydrationSettingsScreen.kt` → `"HydrationSettings"`
- `ui/screens/medications/MedicationsScreen.kt` → `"Medications"`
- `ui/screens/medications/MedicationDetailScreen.kt` → `"MedicationDetail"`
- `ui/screens/medications/AddMedicationScreen.kt` → `"AddMedication"`
- `ui/screens/diet/DietScreen.kt` → `"Diet"`
- `ui/screens/diet/FoodSearchScreen.kt` → `"FoodSearch"`
- `ui/screens/diet/AddFoodScreen.kt` → `"AddFood"`
- `ui/screens/diet/FoodSnapScreen.kt` → `"FoodSnap"`

Same pattern as Task 12.

**Step 1: Add `TrackScreen()` to all 10 files.**

**Step 2: Build + commit**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/home/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/medications/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/diet/
git commit -m "feat(android): track screen views for Home/Hydration/Medication/Diet screens"
```

---

## Task 14: Android — add `TrackScreen()` to HeartRate, Run, Analytics screens

**Files:**
- `ui/screens/heartrate/HeartRateScreen.kt` → `"HeartRate"`
- `ui/screens/heartrate/HeartRateAnalyticsScreen.kt` → `"HeartRateAnalytics"`
- `ui/screens/runactivity/RunActivityScreen.kt` → `"RunActivity"`
- `ui/screens/runactivity/RunCalendarScreen.kt` → `"RunCalendar"`
- `ui/screens/runactivity/ActivityDetailScreen.kt` → `"ActivityDetail"`
- `ui/screens/runactivity/LiveWorkoutScreen.kt` → `"LiveWorkout"`
- `ui/screens/runactivity/WorkoutSummaryScreen.kt` → `"WorkoutSummary"`
- `ui/screens/analytics/HealthAnalyticsScreen.kt` → `"HealthAnalytics"`
- `ui/screens/analytics/HealthMetricDetailScreen.kt` → `"HealthMetricDetail"`

**Step 1: Add `TrackScreen()` to all 9 files.**

**Step 2: Build + commit**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/heartrate/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/
git commit -m "feat(android): track screen views for HeartRate/Run/Analytics screens"
```

---

## Task 15: Android — add `TrackScreen()` to Profile, Settings, AI, Vault screens

**Files:**
- `ui/screens/profile/ProfileScreen.kt` → `"Profile"`
- `ui/screens/profile/EditProfileScreen.kt` → `"EditProfile"`
- `ui/screens/settings/SettingsScreen.kt` → `"Settings"`
- `ui/screens/settings/ThemeSettingsScreen.kt` → `"ThemeSettings"`
- `ui/screens/settings/HealthConnectSettingsScreen.kt` → `"HealthConnectSettings"`
- `ui/screens/settings/HealthDataSyncScreen.kt` → `"HealthDataSync"`
- `ui/screens/settings/GarminConnectSettingsScreen.kt` → `"GarminConnectSettings"`
- `ui/screens/settings/GoogleHealthSettingsScreen.kt` → `"GoogleHealthSettings"`
- `ui/screens/settings/SamsungHealthSettingsScreen.kt` → `"SamsungHealthSettings"`
- `ui/screens/ai/AIScreen.kt` → `"AI"`
- `ui/screens/vault/VaultScreen.kt` → `"Vault"`
- `ui/screens/vault/DocumentViewerScreen.kt` → `"DocumentViewer"`

**Step 1: Add `TrackScreen()` to all 12 files.**

**Step 2: Build + commit**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/profile/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/settings/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/ai/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/vault/
git commit -m "feat(android): track screen views for Profile/Settings/AI/Vault screens"
```

---

## Task 16: Android — add `TrackScreen()` to MenstrualCycle, Family, Notifications, AR screens

**Files:**
- `ui/screens/menstrualcycle/MenstrualCycleScreen.kt` → `"MenstrualCycle"`
- `ui/screens/family/FamilyScreen.kt` → `"Family"`
- `ui/screens/notifications/NotificationSettingsScreen.kt` → `"NotificationSettings"`
- `ui/screens/notifications/NotificationHistoryScreen.kt` → `"NotificationHistory"`
- `ui/screens/ar/ARBodyScanScreen.kt` → `"ARBodyScan"`

**Step 1: Add `TrackScreen()` to all 5 files.**

**Step 2: Build + commit**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/notifications/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/ar/
git commit -m "feat(android): track screen views for MenstrualCycle/Family/Notifications/AR"
```

---

## Task 17: iOS — add Diet feature event calls

**Files to modify:**
- `Views/Home/DietView.swift` — `meal_copied`, `calorie_goal_reached`
- `Views/Home/FoodSearchView.swift` — `food_searched`
- `ViewModels/DietViewModel.swift` — `food_added`, `food_deleted`

**Step 1: In `DietViewModel.swift` — find `addFoodEntry` (or equivalent method that saves a food item) and add call after successful save:**

```swift
AppAnalyticsService.shared.logFoodAdded(
    mealType: mealType.rawValue,
    calories: Int(item.calories),
    isCustom: item.isCustom ?? false
)
```

**Step 2: Find `deleteFood` (or equivalent) and add after delete:**

```swift
AppAnalyticsService.shared.logFoodDeleted(mealType: mealType.rawValue)
```

**Step 3: In `DietView.swift` — find the "copy yesterday" button action and add:**

```swift
AppAnalyticsService.shared.logMealCopied()
```

Find where daily calorie goal is checked/updated and add (only when newly reached):

```swift
AppAnalyticsService.shared.logCalorieGoalReached(goalKcal: Int(goal), actualKcal: Int(actual))
```

**Step 4: In `FoodSearchView.swift` — find where search is triggered (e.g., `.onChange(of: searchText)` or a search button tap) and add:**

```swift
AppAnalyticsService.shared.logFoodSearched(
    queryLength: searchText.count,
    resultsCount: searchResults.count
)
```

**Step 5: Build + commit**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
git add swastricare-mobile-swift/ViewModels/DietViewModel.swift \
        "swastricare-mobile-swift/Views/Home/DietView.swift" \
        "swastricare-mobile-swift/Views/Home/FoodSearchView.swift"
git commit -m "feat(ios): add diet feature analytics events"
```

---

## Task 18: iOS — add Cycle, Family, Settings, AR, Notification feature event calls

**Step 1: Menstrual Cycle — `Views/MenstrualCycle/MenstrualCycleView.swift`**

Find where a cycle entry is saved and add:
```swift
AppAnalyticsService.shared.logCycleLogged(entryType: "start") // or "end"
```

Find where a symptom is added:
```swift
AppAnalyticsService.shared.logSymptomLogged(symptomType: symptom.rawValue)
```

Find the prediction card tap:
```swift
AppAnalyticsService.shared.logCyclePredictionViewed()
```

**Step 2: Family — `Views/Profile/FamilyView.swift`**

Find create group action:
```swift
AppAnalyticsService.shared.logFamilyCreated()
```

Find join via code action:
```swift
AppAnalyticsService.shared.logFamilyJoined()
```

Find member detail tap:
```swift
AppAnalyticsService.shared.logFamilyMemberViewed()
```

Find send invite action:
```swift
AppAnalyticsService.shared.logFamilyInviteSent()
```

**Step 3: Settings — `Views/Home/NotificationSettingsView.swift`**

Find each toggle `.onChange` and add:
```swift
AppAnalyticsService.shared.logNotificationToggled(type: "hydration", enabled: newValue)
```
(Repeat for medication, diet, cycle toggles with appropriate `type` string.)

**Step 4: Profile save — find ViewModel or View where profile is saved:**
```swift
AppAnalyticsService.shared.logProfileUpdated(fieldsChanged: changedFields)
```

**Step 5: HealthKit toggle — `Views/Profile/HealthDataSettingsView.swift`**
Find the HealthKit toggle action:
```swift
AppAnalyticsService.shared.logHealthKitToggled(enabled: newValue)
```

**Step 6: AR — `Views/AR/ARBodyScanView.swift`**
Add on appear / launch:
```swift
AppAnalyticsService.shared.logARLaunched()
```
Add on scan completion:
```swift
AppAnalyticsService.shared.logARScanCompleted(durationSeconds: Int(scanDuration))
```

**Step 7: Notifications — `Services/NotificationService.swift` or `App/swastricare_mobile_swiftApp.swift`**
Find `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` (or `onOpenURL`) and add:
```swift
AppAnalyticsService.shared.logNotificationTapped(notificationType: notificationType)
```

**Step 8: Build + commit**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
git add swastricare-mobile-swift/Views/MenstrualCycle/ swastricare-mobile-swift/Views/Profile/ \
        "swastricare-mobile-swift/Views/Home/NotificationSettingsView.swift" \
        swastricare-mobile-swift/Views/AR/ swastricare-mobile-swift/Services/
git commit -m "feat(ios): add cycle/family/settings/AR/notification feature analytics events"
```

---

## Task 19: Android — add feature event calls (Diet, Cycle, Family, Settings, Notifications, AR)

**Step 1: Diet — `ui/screens/diet/DietViewModel.kt`**

Find add food function, add after success:
```kotlin
analyticsService.trackFoodAdded(mealType, calories, isCustom)
```

Find delete food function, add after success:
```kotlin
analyticsService.trackFoodDeleted(mealType)
```

**Step 2: Diet — `ui/screens/diet/FoodSearchScreen.kt`**

Find search trigger (LaunchedEffect on query or search button), add:
```kotlin
analyticsService.trackFoodSearched(query.length, results.size)
```

**Step 3: Diet — `ui/screens/diet/DietScreen.kt`**

Find copy-yesterday action:
```kotlin
analyticsService.trackMealCopied()
```

Find calorie goal reached check:
```kotlin
analyticsService.trackCalorieGoalReached(goalKcal, actualKcal)
```

**Step 4: Menstrual Cycle — `ui/screens/menstrualcycle/MenstrualCycleViewModel.kt`**

Find save entry:
```kotlin
analyticsService.trackCycleLogged(entryType)
```
Find add symptom:
```kotlin
analyticsService.trackSymptomLogged(symptomType)
```
Find prediction viewed (in screen or viewmodel):
```kotlin
analyticsService.trackCyclePredictionViewed()
```

**Step 5: Family — `ui/screens/family/FamilyViewModel.kt`**

```kotlin
analyticsService.trackFamilyCreated()
analyticsService.trackFamilyJoined()
analyticsService.trackFamilyMemberViewed()
analyticsService.trackFamilyInviteSent()
```

**Step 6: Settings — `ui/screens/notifications/NotificationSettingsViewModel.kt`**

Find each toggle change:
```kotlin
analyticsService.trackNotificationToggled(type, enabled)
```

**Step 7: Settings — `ui/screens/settings/HealthConnectSettingsScreen.kt`**

Find permission toggle:
```kotlin
analyticsService.trackHealthConnectToggled(enabled)
```

**Step 8: Profile — `ui/screens/profile/ProfileViewModel.kt`**

Find save profile:
```kotlin
analyticsService.trackProfileUpdated(fieldsChanged)
```

**Step 9: AR — `ui/screens/ar/ARBodyScanScreen.kt`**

On screen launch:
```kotlin
analyticsService.trackARLaunched()
```
On scan complete:
```kotlin
analyticsService.trackARScanCompleted(durationSeconds)
```

**Step 10: Notifications — find the notification tap handler in `MainActivity.kt` or a `NotificationReceiver`:**

```kotlin
analyticsService.trackNotificationTapped(notificationType)
```

**Step 11: Build + commit**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/diet/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/notifications/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/settings/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/profile/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/ar/ \
        android/app/src/main/kotlin/com/swastricare/health/
git commit -m "feat(android): add diet/cycle/family/settings/AR/notification feature analytics events"
```

---

## Done

All 19 tasks complete. The dashboard work (parsing `duration_seconds` on `screen_view` events, showing screen dwell time from DB, etc.) is deferred — the data will start flowing once the app ships.
