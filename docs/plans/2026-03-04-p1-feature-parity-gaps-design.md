# P1 Feature Parity Gaps — Design Document

> **Date**: 2026-03-04 | **Branch**: android-nikhil | **Scope**: 7 confirmed gaps between iOS and Android

---

## Context

Audit of the Android codebase against the iOS reference revealed that most P1 features are already implemented. The following 7 gaps represent genuinely missing or broken functionality — not "verify" tasks.

## Gap 1: SupabaseVaultRepository (Critical)

**Problem**: `AppContainer` wires `VaultRepository` to `MockVaultRepository` which stores documents in-memory only. No Supabase Storage upload, no Postgrest persistence.

**Design**:
- Create `SupabaseVaultRepository.kt` in `data/repository/`
- Mirror iOS `SupabaseManager.swift` vault operations:
  - `getDocuments()` → SELECT from `medical_documents` table, ordered by `uploaded_at DESC`
  - `uploadDocument()` → Upload binary to `medical-vault` bucket, INSERT row into `medical_documents`, rollback storage on DB failure
  - `deleteDocument()` → Remove from Storage bucket, DELETE from `medical_documents`
  - `getSignedUrl()` → `createSignedURL` from `medical-vault` bucket
  - `updateDocument()` → UPDATE `medical_documents` row
- All operations scoped to current user via `supabaseClient.auth.currentUserOrNull()?.id`
- Swap `MockVaultRepository()` → `SupabaseVaultRepository(supabaseClient)` in `AppContainer`
- Storage path convention: `{userId}/{UUID}_{fileName}`

## Gap 2: Wire HeartRateViewModel to Real PPG Services (Critical)

**Problem**: `HeartRateViewModel.startMeasurement()` runs a fake simulation loop generating random BPM values. Meanwhile, `PPGSignalProcessor.kt` (226 lines) and `HeartRateDetector.kt` (275 lines) exist as service files but are never called.

**Design**:
- Wire `HeartRateViewModel` to use `HeartRateDetector` and `PPGSignalProcessor`
- Add `CameraX` integration in `HeartRateScreen` for finger-on-lens PPG capture
- Flow: Camera preview → frame analysis → PPGSignalProcessor → HeartRateDetector → BPM result
- Add `SignalValidator` class to assess signal quality (finger coverage, motion artifacts)
- Replace the simulated delay loop with a real 30-second measurement cycle
- Keep the existing UI (waveform chart, timer, result display) but feed real data

## Gap 3: Heart Rate Supabase Sync (High)

**Problem**: Heart rate readings stored only in SharedPreferences (last 500 readings). No cloud persistence.

**Design**:
- After measurement completes, INSERT reading into `health_metrics` table (columns: `heart_rate`, `heart_rate_variability`, `resting_heart_rate`)
- On analytics screen load, fetch history from Supabase, merge with local cache
- SharedPreferences remains as offline cache / fast access layer
- Sync on app launch if connected

## Gap 4: ActivityDetailScreen Supabase Fetch (High)

**Problem**: Screen loads from `loadLocalActivities()` and falls back to hardcoded sample data (fake Bengaluru route) if no local match.

**Design**:
- Add Supabase fetch as fallback: local miss → query `run_activities` table by ID → display
- Remove `generateSampleWorkout()` entirely — if no data found locally or remotely, show empty state
- The existing `EmptyTabPlaceholder` composables already handle missing data per tab

## Gap 5: Urine Color Guide Enhancement (Medium)

**Problem**: Android has a read-only bottom sheet. iOS has interactive tappable color swatches with "Log 250ml Now" action.

**Design**:
- Add `selectedLevel` state to `UrineColorGuideSheet`
- Make each color swatch tappable → reveals detail panel with hydration status + recommendation
- Add "Log 250ml Water" button that calls `HydrationViewModel.addIntake(250, "water")`
- Dismiss sheet after logging

## Gap 6: Drinking Pattern Learner (Medium)

**Problem**: iOS has `DrinkingPatternLearner.swift` for ML-based smart reminder timing. Android has no equivalent.

**Design**:
- Create `DrinkingPatternService.kt` in `data/services/`
- Heuristic approach (not full ML): Track timestamps of all hydration entries over last 14 days
- Detect clusters of drinking times → compute median time for each cluster
- Use these median times to schedule smart reminders vs. fixed-interval reminders
- Store pattern data in SharedPreferences
- Integrate with `NotificationService` to adjust reminder schedules

## Gap 7: Live Workout Foreground Notification (Medium)

**Problem**: iOS uses Live Activity widgets for real-time workout display on lock screen. Android has no equivalent.

**Design**:
- Create a foreground `Service` with an ongoing notification showing live workout stats
- Notification content: elapsed time, distance, current pace, calories
- Update every 5 seconds using the existing `LiveWorkoutViewModel` data
- Notification actions: Pause/Resume, Stop
- Tie into existing `LocationTrackingService` lifecycle

---

## Out of Scope

- **Health Streaks**: iOS version is a non-functional mock with hardcoded data. Neither platform has real streak logic. Skip.
- **Water Wave Animation**: Already implemented in Android's `WaterGlassView` composable.
- **All "verify X matches iOS" tasks**: These are audit items, not code changes.

## Implementation Order

1. SupabaseVaultRepository (isolated, no dependencies)
2. HeartRate PPG wiring (complex, needs camera integration)
3. Heart Rate Supabase sync (depends on #2)
4. ActivityDetailScreen Supabase fetch (isolated)
5. Urine Color Guide enhancement (small UI change)
6. Drinking Pattern Learner (new service)
7. Live Workout Foreground Notification (new service)
