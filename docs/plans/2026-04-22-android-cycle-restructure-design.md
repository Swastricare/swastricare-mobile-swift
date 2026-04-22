# Android Cycle Tracker Restructure — Design

**Date:** 2026-04-22
**Scope:** Android menstrual-cycle feature + Supabase schema cleanup + iOS coherence fixes.
**Approach:** B — restructure DB + consolidate code (chosen over surgical fixes or full rewrite).

## Problem

The Android cycle feature compiles and the wiring (DI, nav, workers, notifications) is in place, but the module is fragile. Investigation surfaced seven concrete issues and one large one that changes scope:

1. **Duplicate data layer.** Two parallel DTO packages exist: `data/models/MenstrualCycleModels.kt` (legacy) and `data/remote/dto/menstrualcycle/MenstrualCycleDto.kt` (current). Same class names, different packages. The repo uses the new one; the legacy file is dead weight. Same for `CyclePhase` (two enums).
2. **Errors are silently swallowed.** `getCycles()`, `getSettings()`, `getDailyLogs()` catch `Exception` and return `Success(localData)`. Supabase failures never surface.
3. **Schema over-engineered and inconsistent.** `menstrual_cycles` has 50+ columns (fertile_window, BBT, cervical_mucus, intimacy_logged, etc.); Android uses only 7. `flow_intensity` on `menstrual_cycles` uses `spotting/light/medium/heavy/very_heavy`; `menstrual_daily_logs.flow_level` uses `none/light/medium/heavy/very_heavy`. Two columns for the same concept with different vocabularies.
4. **No default on `MenstrualCycleDto.id`** (new DTO) — JSON migration from legacy cache can deserialize-fail and wipe data via the catch-all fallback.
5. **Calendar logic drift.** Repo has `getCalendarData()` but the ViewModel recomputes inline — repo and UI can disagree on predictions/phases.
6. **`logDailyData` does `insert`, not `upsert`.** Re-logging the same date risks duplicates or PK collisions.
7. **Settings DTO is missing UI-toggled fields** (`reminder_days_before`, `fertile_reminder_enabled`, `pms_reminder_enabled`). UI toggles reset on reload.

**Scope-expanding finding: iOS writes to phantom columns.** `MenstrualCycleRecord` (`SupabaseManager.swift:2175`) encodes `user_id`, `start_date`, `end_date`, `is_predicted`. The actual DB has `health_profile_id`, `period_start`, `period_end`, and no `is_predicted`. Every iOS cycle sync has been silently 400-ing. Same for `MenstrualDailyLogRecord` (encodes `user_id`, `log_date`, plus `energy_level`/`sleep_quality`/`temperature`/`weight`/`cervical_mucus`/`sexual_activity`/`protected_sex` — none of which exist in `menstrual_daily_logs`). Android is the only platform aligned with the DB.

Cleaning up just Android won't give working cross-platform sync. The restructure has to bring iOS, Android, and DB into agreement.

## Design

### 1. DB restructure

New migration `supabase/migrations/20260422000001_cycle_schema_cleanup.sql` that does the following inside a single transaction.

**`menstrual_cycles` — slim down.** Keep only columns actually tracked per-cycle. Daily-varying data (flow, pain, mood, symptoms) lives in `menstrual_daily_logs`.

Keep:
- `id`, `health_profile_id`, `period_start`, `period_end`, `cycle_length`, `period_length`, `notes`, `is_predicted BOOLEAN DEFAULT false`, `created_at`, `updated_at`.

Drop: `flow_intensity`, `daily_flow`, `symptoms`, `symptom_severity`, `pain_level`, `pain_location`, `pain_relief_used`, `mood`, `mood_notes`, `energy_level`, `sleep_quality`, `ovulation_date`, `ovulation_confirmed`, `ovulation_symptoms`, `fertile_window_start`, `fertile_window_end`, `basal_body_temp`, `cervical_mucus`, `intimacy_logged`, `protection_used`, `protection_type`, `predicted_period_start`, `predicted_ovulation`.

Safety: before each `DROP COLUMN`, a `DO $$` block counts non-null rows and `RAISE NOTICE` so the migration log shows any data loss. `DROP IF EXISTS` on every column.

**`menstrual_daily_logs` — extend.**
- Add: `energy_level INT CHECK (energy_level BETWEEN 0 AND 10)`, `sleep_quality VARCHAR(20)`, `temperature DECIMAL(4,2)`, `weight DECIMAL(5,2)`, `cervical_mucus VARCHAR(20)`, `sexual_activity BOOLEAN`, `protected_sex BOOLEAN`.
- Add `UNIQUE(health_profile_id, date)` so same-day logging upserts cleanly.

**`menstrual_settings` — extend with reminder controls.**
- `reminder_days_before INT DEFAULT 2 CHECK (reminder_days_before BETWEEN 1 AND 7)`
- `fertile_reminder_enabled BOOLEAN DEFAULT false`
- `pms_reminder_enabled BOOLEAN DEFAULT false`
- `ovulation_reminder_enabled BOOLEAN DEFAULT false`
- `luteal_phase_length INT DEFAULT 14 CHECK (luteal_phase_length BETWEEN 10 AND 16)`

**Rollback plan.** A commented `-- ROLLBACK` block at the bottom re-adds the dropped columns as nullable. Will not restore data.

### 2. Android data layer consolidation

- **Delete** `android/app/src/main/kotlin/com/swastricare/health/data/models/MenstrualCycleModels.kt` in full. Rewire remaining imports to `domain/model/menstrualcycle/*` (entities) and `data/remote/dto/menstrualcycle/MenstrualCycleDto.kt` (DTOs).
- **Extend DTOs** to match the new schema:
  - `MenstrualCycleDto`: add `isPredicted: Boolean = false` (@SerialName `is_predicted`) and `updatedAt`.
  - `MenstrualDailyLogDto`: add `energyLevel`, `sleepQuality`, `temperature`, `weight`, `cervicalMucus`, `sexualActivity`, `protectedSex`, `updatedAt`.
  - `MenstrualSettingsDto`: add `reminderDaysBefore`, `fertileReminderEnabled`, `pmsReminderEnabled`, `ovulationReminderEnabled`, `lutealPhaseLength`, `updatedAt`.
- **Extend domain models** (`domain/model/menstrualcycle/*`) and the mappers in `data/mapper/MenstrualCycleMapper.kt` to carry the new fields end-to-end.
- **Repository fixes** (`MenstrualCycleRepositoryImpl.kt`):
  1. Stop blanket-catching `Exception` in `getCycles`/`getSettings`/`getDailyLogs`. Return `ResultWrapper.Error(...)` on remote failure and surface it. Local-cache fallback is allowed only for `IOException`/network failures, not schema/RLS/400 errors.
  2. `logDailyData` and `updateDailyLog`: `insert(dto)` → `upsert(dto) { onConflict = "id" }`. Same for cycle writes.
  3. Leverage the new unique constraint: daily-log upserts should also work keyed on `(health_profile_id, date)` — we use `onConflict = "id"` for primary-key idempotence; the DB unique constraint enforces per-day uniqueness so a duplicate `(health_profile_id, date)` with a different `id` will error loudly.
  4. `getProfileId()` — if lookup returns empty, surface `AppException.NotFound` instead of returning `""` which masquerades as "logged out" and trips the `isNotSetUp` UI.

### 3. ViewModel & UI wiring

- **`MenstrualCycleViewModel`** exposes three new StateFlows:
  - `prediction: StateFlow<CyclePrediction?>` — from `repository.getPrediction()`.
  - `statistics: StateFlow<CycleStatistics?>` — from `repository.getStatistics()`.
  - `calendarData: StateFlow<List<CalendarDayData>>` — from `repository.getCalendarData(month)`, refreshed on `changeMonth()`.
- Remove inline helpers `generatePredictedPeriodDates`/`generateFertileWindowDates`/`buildStatisticsFromCycles` — delegate to the repository so predictions match notifications and the calendar.
- Keep VM-local `CycleRecordUi`/`PhaseTip`/`CycleRegularity` as UI adapter types.
- `updateCycleSettings` and `updateNotificationSettings` persist **all** new fields via `repository.updateSettings()`.
- `CycleSettingsSheet` (`CycleSheets.kt`) gains:
  - Reminder-days-before stepper (1-7).
  - Fertile-window reminder toggle (wired to `fertileReminderEnabled`).
  - PMS reminder toggle (wired to `pmsReminderEnabled`).
  - Ovulation reminder toggle (wired to `ovulationReminderEnabled`).

### 4. iOS coherence fixes

Minimum edits needed for iOS syncs to succeed against the new DB. No Swift model or View changes — only the wire format.

- `SupabaseManager.swift:2175` — `MenstrualCycleRecord` CodingKeys:
  - `userId` → `"health_profile_id"`
  - `startDate` → `"period_start"`
  - `endDate` → `"period_end"`
  - `is_predicted` stays (column now exists).
- `SupabaseManager.swift:1784` — `.eq("user_id", …)` → `.eq("health_profile_id", …)`, and the `userId` passed in must be resolved to the user's `health_profiles.id` (mirror Android's profile lookup). Add a helper `fetchHealthProfileId() async throws -> UUID`.
- `SupabaseManager.swift:1785` — `.order("start_date", …)` → `.order("period_start", …)`.
- `MenstrualDailyLogRecord` (`SupabaseManager.swift:2247`):
  - `userId` → `"health_profile_id"`
  - `logDate` → `"date"`
  - `energy_level`/`sleep_quality`/`temperature`/`weight`/`cervical_mucus`/`sexual_activity`/`protected_sex` now exist in the DB so they can stay.
- `deleteMenstrualCycle` and `deleteMenstrualDailyLog` — filter on `health_profile_id` instead of `user_id`.

### 5. What this does **not** change (YAGNI)

- No new repositories, use-cases, or abstractions.
- No cycle tests (project has no test infrastructure).
- No new notification categories beyond wiring existing ones to the new toggles.
- No changes to `CycleAINudgeWorker`. The edge function `supabase/functions/cycle-ai-nudges/index.ts` already uses `period_start`/`period_end`/`health_profile_id` — already matches the new schema.
- No pruning of `pregnancy_tracking`/`pregnancy_logs` (separate feature, out of scope).

## Verification

1. **Pre-migration count.** Migration logs non-null row counts per to-be-dropped column via `RAISE NOTICE` so we can audit data loss.
2. **Builds green.**
   - `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
   - `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug`
3. **Smoke tests** (manual — OnePlus 8T serial `KB2001` + iOS simulator):
   1. Android: start period → row appears in `menstrual_cycles`. Log daily entry → row in `menstrual_daily_logs`. Re-log same date → upsert, no duplicate.
   2. Android: change settings (cycle length, reminder days, toggles) → row in `menstrual_settings` updated with all fields.
   3. iOS: repeat 1–2. Open Android — sees the same data. Reverse.
   4. Calendar on both platforms shows logged days, predicted days, fertile window — with identical shading.
   5. Notifications: flip reminder toggles, verify `CycleNotificationScheduler` picks up the new fields.

## Files affected

**New:**
- `supabase/migrations/20260422000001_cycle_schema_cleanup.sql`

**Modified:**
- `android/app/src/main/kotlin/com/swastricare/health/data/remote/dto/menstrualcycle/MenstrualCycleDto.kt`
- `android/app/src/main/kotlin/com/swastricare/health/data/mapper/MenstrualCycleMapper.kt`
- `android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt`
- `android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/CycleSettings.kt`
- `android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/DailyLog.kt`
- `android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/CycleRecord.kt`
- `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/MenstrualCycleViewModel.kt`
- `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/CycleSheets.kt`
- `android/app/src/main/kotlin/com/swastricare/health/data/services/CycleNotificationScheduler.kt` (honour `reminderDaysBefore` instead of hardcoded `2`)
- `swastricare-mobile-swift/SupabaseManager.swift` (4 sites around lines 1740–1808, 2175–2330)

**Deleted:**
- `android/app/src/main/kotlin/com/swastricare/health/data/models/MenstrualCycleModels.kt`

## Risk & mitigation

| Risk | Mitigation |
|---|---|
| Destructive `DROP COLUMN` on `menstrual_cycles` deletes data a user cared about | Pre-drop `RAISE NOTICE` count; transactional migration; rollback block at bottom of file. Current usage of dropped columns is zero on Android and broken on iOS, so real-world data loss is near-zero. |
| iOS update ships before DB migration lands | Do DB migration first, ship iOS+Android together. Both platforms' clients still work against the old schema during the gap (iOS is already broken; Android just won't use new fields). |
| Android removal of `data/models/MenstrualCycleModels.kt` breaks a forgotten import | `./gradlew assembleDebug` will catch it. Sweep with `grep` before deleting. |
| `CycleSyncWorker` runs mid-migration | Worker uses upserts; will either succeed against old schema or error loudly. Not a data-loss risk. |
