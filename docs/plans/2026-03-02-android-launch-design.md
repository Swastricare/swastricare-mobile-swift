# Android Launch Design — SwasthiCare
**Date:** 2026-03-02
**Scope:** Core 4-tab parity with iOS (Vitals, AI, Vault, Profile)
**Approach:** Phase-by-phase
**Excluded from v1:** Steps/Run tab, Heart Rate camera, Menstrual tracker, AR body scan, Widgets, Family sharing

---

## Current State (as of audit)

| Screen | Completion | Blocker |
|---|---|---|
| Auth (Login / SignUp / Reset) | 100% | Google OAuth needs Web Client ID |
| Navigation / Routing | 100% | — |
| Design System (Theme, Colors) | 100% | — |
| DI Container (AppContainer) | 100% | — |
| Diet | 85% | Settings/goals TODO |
| Medications | 85% | Demo profile ID used |
| Vault | 75% | MockVaultRepository, no Supabase Storage |
| Profile | 60% | MockProfileRepository, no Supabase health_profile |
| Home/Vitals | 50% | All data hardcoded, no Health Connect |
| AI Chat | 50% | AIService returns hardcoded demo responses |

---

## Phase 1 — Backend Connections

Connect all screens that have real UI but mock/demo data to Supabase.

### 1.1 Profile → Supabase health_profile
- Implement `SupabaseProfileRepository` replacing `MockProfileRepository`
- Fetch `health_profiles` table via `profileId` from auth session
- Persist settings (notifications, biometric, health sync) to `DataStore<Preferences>`
- Wire sign out to clear session + navigate to LoginScreen
- Wire delete account to Supabase `auth.admin.deleteUser()`

### 1.2 Home/Vitals → Health Connect API
- Add `androidx.health.connect:connect-client` dependency
- Request permissions: `Steps`, `HeartRate`, `ActiveCaloriesBurned`, `TotalCaloriesBurned`
- Replace `HomeViewModel` hardcoded values with real `HealthConnectClient` reads
- Sync daily summary to Supabase `daily_health_metrics` table
- Handle Health Connect unavailable (API level < 28) gracefully

### 1.3 Vault → Supabase Storage
- Implement `SupabaseVaultRepository` replacing `MockVaultRepository`
- Upload files to Supabase Storage bucket `vault-documents/{userId}/{filename}`
- List documents from `vault_documents` table
- Delete: remove from Storage + table row
- Add upload progress tracking via Ktor's `onUpload` callback

### 1.4 AI Chat → ai-router Edge Function
- Replace `AIService` stub with real HTTP call to Supabase `ai-router` edge function
- Pass user message + health context (latest medications, diet summary) in request body
- Support streaming responses via `HttpStatement.execute { response -> ... }`
- Implement Android `SpeechRecognizer` for voice input (mic button)
- Handle medical disclaimer display (first use)

---

## Phase 2 — Missing Screens & Flows

### 2.1 Onboarding Screens
- Create `OnboardingScreen.kt` with 3-4 feature highlight slides (matching iOS OnboardingView)
- Track `has_completed_onboarding` in `DataStore<Preferences>` — skip on subsequent launches
- Add page indicator dots + Next/Get Started buttons

### 2.2 Consent Screen
- Create `ConsentScreen.kt` with privacy policy + terms of service text
- Require explicit "I Agree" tap before proceeding (India DPDPA compliance)
- Track `has_accepted_consent` in `DataStore<Preferences>`

### 2.3 Health Profile Questionnaire
- Create `HealthProfileScreen.kt` — multi-step form: name, DOB, gender, height, weight, blood type, activity level
- Write result to Supabase `health_profiles` table on completion
- Show after consent, before ContentView (matching iOS navigation state machine)
- Skip if profile already exists in Supabase

### 2.4 Force Update Screen
- Create `ForceUpdateScreen.kt` displayed when remote config `min_android_version > currentVersionCode`
- Fetch min version from Supabase `app_config` table or Firebase Remote Config
- Show update button linking to Play Store

### 2.5 Google OAuth Fix
- Register Android app in Google Cloud Console
- Add SHA-1 fingerprints (debug + release)
- Replace `YOUR_GOOGLE_WEB_CLIENT_ID` placeholder in `AppContainer.kt`

### 2.6 Medication Reminders
- Implement `MedicationReminderService.kt` using `AlarmManager` + `BroadcastReceiver`
- Schedule alarms for each dose time when medications are added/updated
- Show `NotificationCompat` notification with "Take Now" + "Skip" actions
- Handle Android 12+ exact alarm permission (`SCHEDULE_EXACT_ALARM`)
- Cancel alarms on medication deletion

### 2.7 Diet Goals Settings Screen
- Create `DietSettingsSheet.kt` (bottom sheet) for daily calorie + macro targets
- Persist to `DataStore<Preferences>` + sync to Supabase `diet_goals` table
- Show from DietScreen toolbar menu (fix the TODO at DietScreen.kt:85)

---

## Phase 3 — UI Polish (Visual iOS Parity)

### 3.1 Home Screen Premium Background
- Implement animated gradient `PremiumBackground` composable matching iOS (`LinearGradient` with `infiniteTransition`)
- Add staggered card entry animations using `AnimatedVisibility` + `animateFloatAsState` with delay offsets

### 3.2 Typography Audit
- Cross-reference all text styles in `Type.kt` against iOS `DesignSystem.swift`
- Ensure headline = 28sp bold, body = 16sp regular, caption = 12sp medium
- Use `fontFamily = FontFamily.Default` (Roboto) consistently

### 3.3 Semantic Color Verification
- Verify `Color.kt` hex values match iOS `AppColors` for: heartRate, hydration, medication, diet, steps, sleep, exercise, distance, pace, cadence
- Add any missing semantic colors

### 3.4 Tab Animations
- Add `CrossfadeTransition` between tab switches
- Match iOS tab selection animation (scale + opacity)

### 3.5 Dark Mode Audit
- Test all 6 screens in dark mode
- Fix surface colors that don't respect `darkColorScheme`
- Ensure glass modifier works correctly in both modes

### 3.6 Empty States
- Vault: "No documents yet" with upload icon
- Diet: "No meals logged today" with add icon
- AI: Welcome message with quick-start suggestions
- Medications: "No medications added" with add icon

### 3.7 Medication & Add Flows Polish
- Verify `AddMedicationScreen` matches iOS step-by-step schedule builder
- Ensure time picker matches iOS style (wheel picker)

---

## Phase 4 — Pre-Launch

### 4.1 Production Configuration
- Swap Supabase dev keys → production keys in `SupabaseConfig.kt`
- Configure production Google OAuth credentials
- Set `BuildConfig.DEBUG = false` verification in release config

### 4.2 Firebase Crashlytics
- Add `com.google.firebase:firebase-crashlytics-ktx` dependency
- Initialize in `SwasthiCareApplication.kt`
- Add `google-services.json` for Android app (already in iOS via `GoogleService-Info.plist`)

### 4.3 ProGuard / R8 Rules
- Add keep rules for:
  - Supabase model data classes (`@Serializable`)
  - Kotlin coroutines
  - Coil image loading
  - Health Connect classes

### 4.4 App Signing
- Generate release keystore: `keytool -genkey -v -keystore swasthicare-release.jks`
- Configure `signingConfigs.release` in `build.gradle.kts`
- Store keystore securely (not in git)

### 4.5 Play Store Assets
- 8 screenshots: Phone (min 2) + 7-inch tablet (min 1)
- Feature graphic: 1024×500px
- App icon: 512×512px (hi-res)
- Short description (80 chars): "AI-powered personal health tracker for you and your family"
- Full description (~4000 chars)
- Content rating questionnaire

### 4.6 Privacy & Legal
- Add Privacy Policy URL to Play Store + in-app "About" section
- Add Terms of Service URL
- DPDPA compliance statement (data residency for Indian users)

### 4.7 Internal Beta
- Build signed release APK/AAB
- Upload to Play Console → Internal testing track
- Test on 3 physical devices (min Android 9, 11, 14)
- Verify all Supabase calls work with production keys

---

## Navigation State Machine (post-implementation)

```
Splash → ForceUpdate? → Onboarding → Consent → Login → HealthProfileQuestionnaire → ContentView (4 tabs)
                                                  ↑
                                            (if no profile)
```

## Out of Scope (v2+)
- Steps/Run tab
- Heart Rate via camera
- Menstrual cycle tracker
- AR body scan
- Home screen widgets
- Family sharing & groups
