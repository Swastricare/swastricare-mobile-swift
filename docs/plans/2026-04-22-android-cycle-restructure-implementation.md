# Android Cycle Tracker Restructure — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring Android, iOS, and Supabase into agreement on the menstrual-cycle feature: slim the bloated `menstrual_cycles` schema, extend `menstrual_daily_logs` and `menstrual_settings`, consolidate Android's duplicate data layer, surface sync errors instead of swallowing them, and fix iOS's phantom column names.

**Architecture:** Single destructive SQL migration drops unused `menstrual_cycles` columns, adds missing `menstrual_daily_logs`/`menstrual_settings` columns, and adds a unique constraint on `(health_profile_id, date)`. Android repo switches `insert → upsert` and stops blanket-catching Supabase errors. ViewModel delegates calendar/prediction/statistics computation to the repo (currently it re-implements inline). iOS gets 4 coding-key renames so its requests match the real schema.

**Tech Stack:** Supabase (Postgres + PostgREST, RLS), Kotlin + Jetpack Compose + Hilt (Android), Swift + SwiftUI (iOS).

**Design reference:** `docs/plans/2026-04-22-android-cycle-restructure-design.md`

**Testing note:** Neither iOS nor Android has unit tests configured. Each task's verification step is `build green + manual smoke test on the OnePlus 8T (adb serial KB2001) or iOS simulator + row-level inspection in Supabase dashboard`. TDD steps are replaced with compile-check + behavioural smoke tests.

**Commit cadence:** One commit per task unless explicitly noted.

---

## Phase 1 — Database migration

### Task 1: Write the cycle-schema-cleanup migration

**Files:**
- Create: `supabase/migrations/20260422000001_cycle_schema_cleanup.sql`

**Step 1: Write the migration**

Create the file with this content:

```sql
-- ============================================================================
-- CYCLE SCHEMA CLEANUP
-- ============================================================================
-- Slims menstrual_cycles to per-cycle data only (daily-varying data belongs
-- in menstrual_daily_logs). Extends menstrual_daily_logs with fields iOS
-- already writes. Extends menstrual_settings with reminder toggles the
-- Android UI already exposes.
--
-- Safety:
--   * Wrapped in a transaction.
--   * Before each DROP COLUMN, RAISE NOTICE reports non-null row counts so
--     the migration log contains a paper trail of data loss.
--   * All drops use IF EXISTS so re-running is safe.
--   * Rollback block at the bottom re-adds nullable columns (will NOT
--     restore data).

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Log non-null counts for columns about to be dropped.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    col text;
    cnt bigint;
    cols text[] := ARRAY[
        'flow_intensity','daily_flow','symptoms','symptom_severity',
        'pain_level','pain_location','pain_relief_used',
        'mood','mood_notes','energy_level','sleep_quality',
        'ovulation_date','ovulation_confirmed','ovulation_symptoms',
        'fertile_window_start','fertile_window_end','basal_body_temp',
        'cervical_mucus','intimacy_logged','protection_used','protection_type',
        'predicted_period_start','predicted_ovulation'
    ];
BEGIN
    FOREACH col IN ARRAY cols LOOP
        EXECUTE format(
            'SELECT count(*) FROM public.menstrual_cycles WHERE %I IS NOT NULL',
            col
        ) INTO cnt;
        RAISE NOTICE 'menstrual_cycles.% non-null rows: %', col, cnt;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Add is_predicted (iOS sends this; column was missing).
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_cycles
    ADD COLUMN IF NOT EXISTS is_predicted BOOLEAN NOT NULL DEFAULT false;

-- ----------------------------------------------------------------------------
-- 3. Drop unused columns on menstrual_cycles.
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_cycles
    DROP COLUMN IF EXISTS flow_intensity,
    DROP COLUMN IF EXISTS daily_flow,
    DROP COLUMN IF EXISTS symptoms,
    DROP COLUMN IF EXISTS symptom_severity,
    DROP COLUMN IF EXISTS pain_level,
    DROP COLUMN IF EXISTS pain_location,
    DROP COLUMN IF EXISTS pain_relief_used,
    DROP COLUMN IF EXISTS mood,
    DROP COLUMN IF EXISTS mood_notes,
    DROP COLUMN IF EXISTS energy_level,
    DROP COLUMN IF EXISTS sleep_quality,
    DROP COLUMN IF EXISTS ovulation_date,
    DROP COLUMN IF EXISTS ovulation_confirmed,
    DROP COLUMN IF EXISTS ovulation_symptoms,
    DROP COLUMN IF EXISTS fertile_window_start,
    DROP COLUMN IF EXISTS fertile_window_end,
    DROP COLUMN IF EXISTS basal_body_temp,
    DROP COLUMN IF EXISTS cervical_mucus,
    DROP COLUMN IF EXISTS intimacy_logged,
    DROP COLUMN IF EXISTS protection_used,
    DROP COLUMN IF EXISTS protection_type,
    DROP COLUMN IF EXISTS predicted_period_start,
    DROP COLUMN IF EXISTS predicted_ovulation;

-- The ovulation-date index no longer has a column to index.
DROP INDEX IF EXISTS public.idx_menstrual_cycles_ovulation;

-- ----------------------------------------------------------------------------
-- 4. Extend menstrual_daily_logs with fields iOS already sends.
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_daily_logs
    ADD COLUMN IF NOT EXISTS energy_level INT CHECK (energy_level BETWEEN 0 AND 10),
    ADD COLUMN IF NOT EXISTS sleep_quality VARCHAR(20),
    ADD COLUMN IF NOT EXISTS temperature DECIMAL(4,2),
    ADD COLUMN IF NOT EXISTS weight DECIMAL(5,2),
    ADD COLUMN IF NOT EXISTS cervical_mucus VARCHAR(20),
    ADD COLUMN IF NOT EXISTS sexual_activity BOOLEAN,
    ADD COLUMN IF NOT EXISTS protected_sex BOOLEAN;

-- One log row per (profile, date) so re-logging the same day upserts cleanly.
-- Safe against existing duplicates: the migration will fail loudly if any
-- exist, signalling we need a manual de-dupe first.
ALTER TABLE public.menstrual_daily_logs
    ADD CONSTRAINT menstrual_daily_logs_profile_date_key
    UNIQUE (health_profile_id, date);

-- ----------------------------------------------------------------------------
-- 5. Extend menstrual_settings with reminder controls.
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_settings
    ADD COLUMN IF NOT EXISTS reminder_days_before INT NOT NULL DEFAULT 2
        CHECK (reminder_days_before BETWEEN 1 AND 7),
    ADD COLUMN IF NOT EXISTS fertile_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS pms_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS ovulation_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS luteal_phase_length INT NOT NULL DEFAULT 14
        CHECK (luteal_phase_length BETWEEN 10 AND 16);

COMMIT;

-- ============================================================================
-- ROLLBACK (manual — re-adds columns as nullable; WILL NOT RESTORE DATA)
-- ============================================================================
-- BEGIN;
-- ALTER TABLE public.menstrual_cycles
--     ADD COLUMN IF NOT EXISTS flow_intensity VARCHAR(20) CHECK (flow_intensity IN (
--         'spotting','light','medium','heavy','very_heavy')),
--     ADD COLUMN IF NOT EXISTS daily_flow JSONB,
--     ADD COLUMN IF NOT EXISTS symptoms TEXT[],
--     ADD COLUMN IF NOT EXISTS symptom_severity JSONB,
--     ADD COLUMN IF NOT EXISTS pain_level INT CHECK (pain_level BETWEEN 0 AND 10),
--     ADD COLUMN IF NOT EXISTS pain_location TEXT[],
--     ADD COLUMN IF NOT EXISTS pain_relief_used TEXT[],
--     ADD COLUMN IF NOT EXISTS mood TEXT[],
--     ADD COLUMN IF NOT EXISTS mood_notes TEXT,
--     ADD COLUMN IF NOT EXISTS energy_level INT CHECK (energy_level BETWEEN 1 AND 5),
--     ADD COLUMN IF NOT EXISTS sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 5),
--     ADD COLUMN IF NOT EXISTS ovulation_date DATE,
--     ADD COLUMN IF NOT EXISTS ovulation_confirmed BOOLEAN DEFAULT false,
--     ADD COLUMN IF NOT EXISTS ovulation_symptoms TEXT[],
--     ADD COLUMN IF NOT EXISTS fertile_window_start DATE,
--     ADD COLUMN IF NOT EXISTS fertile_window_end DATE,
--     ADD COLUMN IF NOT EXISTS basal_body_temp DECIMAL(4,2),
--     ADD COLUMN IF NOT EXISTS cervical_mucus VARCHAR(30),
--     ADD COLUMN IF NOT EXISTS intimacy_logged BOOLEAN DEFAULT false,
--     ADD COLUMN IF NOT EXISTS protection_used BOOLEAN,
--     ADD COLUMN IF NOT EXISTS protection_type VARCHAR(30),
--     ADD COLUMN IF NOT EXISTS predicted_period_start DATE,
--     ADD COLUMN IF NOT EXISTS predicted_ovulation DATE,
--     DROP COLUMN IF EXISTS is_predicted;
-- ALTER TABLE public.menstrual_daily_logs
--     DROP CONSTRAINT IF EXISTS menstrual_daily_logs_profile_date_key,
--     DROP COLUMN IF EXISTS energy_level,
--     DROP COLUMN IF EXISTS sleep_quality,
--     DROP COLUMN IF EXISTS temperature,
--     DROP COLUMN IF EXISTS weight,
--     DROP COLUMN IF EXISTS cervical_mucus,
--     DROP COLUMN IF EXISTS sexual_activity,
--     DROP COLUMN IF EXISTS protected_sex;
-- ALTER TABLE public.menstrual_settings
--     DROP COLUMN IF EXISTS reminder_days_before,
--     DROP COLUMN IF EXISTS fertile_reminder_enabled,
--     DROP COLUMN IF EXISTS pms_reminder_enabled,
--     DROP COLUMN IF EXISTS ovulation_reminder_enabled,
--     DROP COLUMN IF EXISTS luteal_phase_length;
-- COMMIT;
```

**Step 2: Apply migration locally**

Run: `supabase db push`
Expected: migration applies cleanly, NOTICE lines appear in output with per-column non-null counts.

**Step 3: Verify new schema in `psql`**

Run (adjust connection string as the project normally does, e.g. `supabase db shell` or `psql` via the Supabase CLI):

```
\d public.menstrual_cycles
\d public.menstrual_daily_logs
\d public.menstrual_settings
```

Expected:
- `menstrual_cycles` no longer shows dropped columns; shows `is_predicted`.
- `menstrual_daily_logs` shows new 7 columns and a unique constraint on `(health_profile_id, date)`.
- `menstrual_settings` shows the 5 new columns.

**Step 4: Commit**

```bash
git add supabase/migrations/20260422000001_cycle_schema_cleanup.sql
git commit -m "db(cycle): slim menstrual_cycles, extend daily_logs and settings"
```

---

## Phase 2 — Android DTO & domain & mapper updates

### Task 2: Extend `MenstrualCycleDto` with `isPredicted` + `updatedAt`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/remote/dto/menstrualcycle/MenstrualCycleDto.kt`

**Step 1: Edit the DTO**

Locate `MenstrualCycleDto` (lines 10-28). Add `isPredicted` (before `notes`) and ensure `updatedAt` is present:

```kotlin
@Serializable
data class MenstrualCycleDto(
    val id: String,
    @SerialName("health_profile_id")
    val healthProfileId: String,
    @SerialName("period_start")
    val startDate: String,
    @SerialName("period_end")
    val endDate: String? = null,
    @SerialName("cycle_length")
    val cycleLength: Int? = null,
    @SerialName("period_length")
    val periodLength: Int? = null,
    @SerialName("is_predicted")
    val isPredicted: Boolean = false,
    val notes: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)
```

(The file already has `updatedAt` — verify and leave as-is.)

**Step 2: Compile check only**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin`
Expected: FAIL — mappers and callers that construct `MenstrualCycleDto` will be missing the new arg; we fix those in later tasks.

(Do not commit yet; we'll commit after the DTO set is consistent in Task 5.)

---

### Task 3: Extend `MenstrualDailyLogDto` with iOS-parity fields

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/remote/dto/menstrualcycle/MenstrualCycleDto.kt`

**Step 1: Edit**

Locate `MenstrualDailyLogDto` in the same file. Add the 7 new fields:

```kotlin
@Serializable
data class MenstrualDailyLogDto(
    val id: String,
    @SerialName("cycle_id")
    val cycleId: String,
    @SerialName("health_profile_id")
    val healthProfileId: String,
    val date: String,
    @SerialName("flow_level")
    val flowLevel: String,
    val symptoms: String,
    val mood: String? = null,
    val notes: String? = null,
    @SerialName("pain_level")
    val painLevel: Int = 0,
    @SerialName("energy_level")
    val energyLevel: Int? = null,
    @SerialName("sleep_quality")
    val sleepQuality: String? = null,
    val temperature: Double? = null,
    val weight: Double? = null,
    @SerialName("cervical_mucus")
    val cervicalMucus: String? = null,
    @SerialName("sexual_activity")
    val sexualActivity: Boolean? = null,
    @SerialName("protected_sex")
    val protectedSex: Boolean? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)
```

**Step 2: No commit yet** — continue to next task.

---

### Task 4: Extend `MenstrualSettingsDto` with reminder controls

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/remote/dto/menstrualcycle/MenstrualCycleDto.kt`

**Step 1: Edit**

Locate `MenstrualSettingsDto`. Add the 5 new fields:

```kotlin
@Serializable
data class MenstrualSettingsDto(
    val id: String,
    @SerialName("health_profile_id")
    val healthProfileId: String,
    @SerialName("average_cycle_length")
    val averageCycleLength: Int = 28,
    @SerialName("average_period_length")
    val averagePeriodLength: Int = 5,
    @SerialName("reminder_enabled")
    val reminderEnabled: Boolean = true,
    @SerialName("reminder_time")
    val reminderTime: String = "09:00:00",
    @SerialName("reminder_days_before")
    val reminderDaysBefore: Int = 2,
    @SerialName("fertile_reminder_enabled")
    val fertileReminderEnabled: Boolean = false,
    @SerialName("pms_reminder_enabled")
    val pmsReminderEnabled: Boolean = false,
    @SerialName("ovulation_reminder_enabled")
    val ovulationReminderEnabled: Boolean = false,
    @SerialName("luteal_phase_length")
    val lutealPhaseLength: Int = 14,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)
```

**Step 2: No commit yet.**

---

### Task 5: Extend domain models

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/CycleRecord.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/DailyLog.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/CycleSettings.kt`

**Step 1: `CycleRecord.kt`** — add `isPredicted`:

```kotlin
data class CycleRecord(
    val id: String,
    val userId: String,
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val cycleLength: Int? = null,
    val periodLength: Int? = null,
    val notes: String? = null,
    val isPredicted: Boolean = false
) {
    // existing computed props unchanged
}
```

**Step 2: `DailyLog.kt`** — add iOS-parity fields:

```kotlin
data class DailyLog(
    val id: String,
    val cycleId: String,
    val date: LocalDate,
    val flowLevel: FlowLevel,
    val symptoms: List<Symptom>,
    val mood: Mood?,
    val notes: String?,
    val painLevel: Int,
    val energyLevel: Int? = null,
    val sleepQuality: String? = null,
    val temperature: Double? = null,
    val weight: Double? = null,
    val cervicalMucus: String? = null,
    val sexualActivity: Boolean? = null,
    val protectedSex: Boolean? = null
) {
    // existing helpers unchanged
}
```

**Step 3: `CycleSettings.kt`** — add reminder fields:

```kotlin
data class CycleSettings(
    val averageCycleLength: Int = 28,
    val averagePeriodLength: Int = 5,
    val reminderEnabled: Boolean = true,
    val reminderTime: String = "09:00",
    val reminderDaysBefore: Int = 2,
    val fertileReminderEnabled: Boolean = false,
    val pmsReminderEnabled: Boolean = false,
    val ovulationReminderEnabled: Boolean = false,
    val lutealPhaseLength: Int = 14
) {
    // existing validators unchanged
}
```

**Step 4: No commit yet.**

---

### Task 6: Update the mappers to round-trip the new fields

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/mapper/MenstrualCycleMapper.kt`

**Step 1: Rewrite the three mapper pairs**

Replace the six existing functions (`MenstrualCycleDto.toDomain`, `CycleRecord.toDto`, `MenstrualDailyLogDto.toDomain`, `DailyLog.toDto`, `MenstrualSettingsDto.toDomain`, `CycleSettings.toDto`) with field-complete versions:

```kotlin
fun MenstrualCycleDto.toDomain(): CycleRecord = CycleRecord(
    id = id,
    userId = healthProfileId,
    startDate = LocalDate.parse(startDate),
    endDate = endDate?.let { LocalDate.parse(it) },
    cycleLength = cycleLength,
    periodLength = periodLength,
    notes = notes,
    isPredicted = isPredicted
)

fun CycleRecord.toDto(healthProfileId: String): MenstrualCycleDto = MenstrualCycleDto(
    id = id,
    healthProfileId = healthProfileId,
    startDate = startDate.toString(),
    endDate = endDate?.toString(),
    cycleLength = cycleLength,
    periodLength = effectivePeriodLength,
    isPredicted = isPredicted,
    notes = notes
)

fun MenstrualDailyLogDto.toDomain(): DailyLog = DailyLog(
    id = id,
    cycleId = cycleId,
    date = LocalDate.parse(date),
    flowLevel = flowLevel.toFlowLevel(),
    symptoms = symptoms.toSymptomList(),
    mood = mood?.toMood(),
    notes = notes,
    painLevel = painLevel,
    energyLevel = energyLevel,
    sleepQuality = sleepQuality,
    temperature = temperature,
    weight = weight,
    cervicalMucus = cervicalMucus,
    sexualActivity = sexualActivity,
    protectedSex = protectedSex
)

fun DailyLog.toDto(healthProfileId: String): MenstrualDailyLogDto = MenstrualDailyLogDto(
    id = id,
    cycleId = cycleId,
    healthProfileId = healthProfileId,
    date = date.toString(),
    flowLevel = flowLevel.toDbValue(),
    symptoms = symptoms.toDbValue(),
    mood = mood?.toDbValue(),
    notes = notes,
    painLevel = painLevel,
    energyLevel = energyLevel,
    sleepQuality = sleepQuality,
    temperature = temperature,
    weight = weight,
    cervicalMucus = cervicalMucus,
    sexualActivity = sexualActivity,
    protectedSex = protectedSex
)

fun MenstrualSettingsDto.toDomain(): CycleSettings = CycleSettings(
    averageCycleLength = averageCycleLength,
    averagePeriodLength = averagePeriodLength,
    reminderEnabled = reminderEnabled,
    reminderTime = reminderTime.take(5),
    reminderDaysBefore = reminderDaysBefore,
    fertileReminderEnabled = fertileReminderEnabled,
    pmsReminderEnabled = pmsReminderEnabled,
    ovulationReminderEnabled = ovulationReminderEnabled,
    lutealPhaseLength = lutealPhaseLength
)

fun CycleSettings.toDto(healthProfileId: String): MenstrualSettingsDto = MenstrualSettingsDto(
    id = UUID.randomUUID().toString(),
    healthProfileId = healthProfileId,
    averageCycleLength = averageCycleLength,
    averagePeriodLength = averagePeriodLength,
    reminderEnabled = reminderEnabled,
    reminderTime = if (reminderTime.length == 5) "$reminderTime:00" else reminderTime,
    reminderDaysBefore = reminderDaysBefore,
    fertileReminderEnabled = fertileReminderEnabled,
    pmsReminderEnabled = pmsReminderEnabled,
    ovulationReminderEnabled = ovulationReminderEnabled,
    lutealPhaseLength = lutealPhaseLength
)
```

**Step 2: Compile check**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin`
Expected: still failing because the legacy `data/models/MenstrualCycleModels.kt` also defines `toDto`/`toDomain`; task 8 deletes that file.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/remote/dto/menstrualcycle/ \
        android/app/src/main/kotlin/com/swastricare/health/domain/model/menstrualcycle/ \
        android/app/src/main/kotlin/com/swastricare/health/data/mapper/MenstrualCycleMapper.kt
git commit -m "feat(cycle,android): extend cycle/log/settings DTOs + domain + mappers"
```

---

## Phase 3 — Android legacy cleanup

### Task 7: Find all callers of the legacy `data/models/MenstrualCycleModels.kt`

**Step 1: Grep for usages**

Run:
```
grep -rn "com.swastricare.health.data.models.MenstrualCycle" android/app/src/main
grep -rn "com.swastricare.health.data.models.MenstrualDailyLog" android/app/src/main
grep -rn "com.swastricare.health.data.models.MenstrualSettings" android/app/src/main
grep -rn "com.swastricare.health.data.models.MenstrualSymptom" android/app/src/main
grep -rn "com.swastricare.health.data.models.MenstrualMood" android/app/src/main
grep -rn "com.swastricare.health.data.models.FlowLevel" android/app/src/main
grep -rn "com.swastricare.health.data.models.CyclePhase" android/app/src/main
grep -rn "com.swastricare.health.data.models.CalendarDayData" android/app/src/main
grep -rn "com.swastricare.health.data.models.CyclePrediction" android/app/src/main
grep -rn "com.swastricare.health.data.models.CycleStatistics" android/app/src/main
```

Expected: only the file itself is the definition site; if any imports from other files appear, they must be rewired in Task 8 before the delete.

**Step 2: No commit.**

---

### Task 8: Rewire imports, then delete the legacy file

**Files:**
- Rewire (depends on Task 7 findings): any file that imports from `data.models.Menstrual*`, change import to either:
  - `data.remote.dto.menstrualcycle.MenstrualCycleDto` etc. for DTOs, or
  - `domain.model.menstrualcycle.CycleRecord` / `DailyLog` / `CycleSettings` / `CyclePhase` / `CalendarDayData` / `CyclePrediction` / `CycleStatistics` / `FlowLevel` / `Symptom` / `Mood` for domain types.
- Delete: `android/app/src/main/kotlin/com/swastricare/health/data/models/MenstrualCycleModels.kt`

**Step 1: Edit every importing file** (list produced by Task 7).

**Step 2: Delete the legacy file**

Run: `rm android/app/src/main/kotlin/com/swastricare/health/data/models/MenstrualCycleModels.kt`

**Step 3: Verify build**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin`
Expected: PASS.

**Step 4: Commit**

```bash
git add -A android/app/src/main/kotlin/com/swastricare/health/
git commit -m "refactor(cycle,android): delete duplicate data/models layer"
```

---

## Phase 4 — Android repository hardening

### Task 9: Stop swallowing Supabase errors in `getCycles`/`getSettings`/`getDailyLogs`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt:76-97,200-229,348-368`

**Step 1: Narrow the catch**

Replace each `catch (e: Exception) { /* fallback to local */ ResultWrapper.Success(local…) }` with:

```kotlin
} catch (e: java.io.IOException) {
    // Network / connectivity — fall back to local cache, still "Success" from the UI's POV.
    ResultWrapper.Success(loadLocalCycles())
} catch (e: Exception) {
    android.util.Log.e("CycleRepo", "Supabase fetch failed", e)
    ResultWrapper.Error(AppException.UnknownException(cause = e))
}
```

Apply the same pattern to `getSettings()` (returning `loadLocalSettings()` in the IOException branch) and `getDailyLogs()` (returning locally-filtered logs).

**Step 2: Compile check**

Run: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin`
Expected: PASS.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt
git commit -m "fix(cycle,android): surface Supabase errors, only fall back on IOException"
```

---

### Task 10: Switch cycle/log writes to `upsert`

**Files:**
- Modify: `MenstrualCycleRepositoryImpl.kt` — `startCycle`, `endCycle`, `logDailyData`, `updateDailyLog`.

**Step 1: Replace inserts with upserts**

- `startCycle`: `supabaseClient.from("menstrual_cycles").insert(dto)` → `supabaseClient.from("menstrual_cycles").upsert(dto) { onConflict = "id" }`.
- `logDailyData`: both the auto-create-cycle insert and the log insert become upserts with `onConflict = "id"`.
- `updateDailyLog`: already an update; leave alone but wrap the same narrowed catch as Task 9.

**Step 2: Compile + manual smoke**

Run: `cd android && ./gradlew :app:assembleDebug` then install on device (`adb -s KB2001 install -r ...`) and:

1. Open app → Cycle → Start Period today → verify row in `menstrual_cycles`.
2. Swipe back, Start Period today again → expect *no* duplicate row, same `id` upserted.
3. Log daily entry → row in `menstrual_daily_logs`.
4. Log same date again (Daily Log sheet) → expect the row to upsert (single row per `id`).

Expected: all four pass.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt
git commit -m "fix(cycle,android): upsert cycles and daily logs for idempotence"
```

---

### Task 11: Surface missing-profile as an error

**Files:**
- Modify: `MenstrualCycleRepositoryImpl.kt:55-70`

**Step 1: Replace silent empty-string fallback**

```kotlin
private suspend fun getProfileId(): String {
    cachedProfileId?.let { return it }
    return profileIdMutex.withLock {
        cachedProfileId?.let { return@withLock it }
        val userId = supabaseClient.auth.currentUserOrNull()?.id
            ?: throw AppException.ValidationException.Custom("Not authenticated")
        val id = supabaseClient.from("health_profiles")
            .select { filter { eq("user_id", userId) } }
            .decodeSingleOrNull<HealthProfileIdRow>()?.id
            ?: throw AppException.ValidationException.Custom("No health profile found for user")
        cachedProfileId = id
        id
    }
}
```

**Step 2: Adapt call sites**

Every caller of `getProfileId()` inside this class needs a try/catch → return `ResultWrapper.Error(...)` so the VM can surface an error message.

Pattern:
```kotlin
val profileId = try { getProfileId() } catch (e: AppException) {
    return@withContext ResultWrapper.Error(e)
}
```

Apply to: `getCycles`, `startCycle`, `endCycle`, `deleteCycle`, `getDailyLogs`, `logDailyData`, `updateDailyLog`, `deleteDailyLog`, `getSettings`, `updateSettings`, `syncData`, `loadLocalCycles`, `saveLocalCycles`, `loadLocalLogs`, `saveLocalLogs`, `loadLocalSettings`, `saveLocalSettings`.

For the local-storage helpers, catching silently is fine (they just return empty / no-op) — the change is only at the API boundary. Keep their existing catch.

**Step 3: Compile check**

Run: `./gradlew :app:compileDebugKotlin`
Expected: PASS.

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt
git commit -m "fix(cycle,android): surface missing health profile as error, not empty string"
```

---

## Phase 5 — Android ViewModel & UI

### Task 12: Expose prediction/statistics/calendarData StateFlows and delegate to repo

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/MenstrualCycleViewModel.kt`

**Step 1: Add StateFlows**

Inside the class, after the existing `_uiState`:

```kotlin
private val _prediction = MutableStateFlow<CyclePrediction?>(null)
val prediction: StateFlow<CyclePrediction?> = _prediction.asStateFlow()

private val _statistics = MutableStateFlow<CycleStatistics?>(null)
val statistics: StateFlow<CycleStatistics?> = _statistics.asStateFlow()

private val _calendarData = MutableStateFlow<List<CalendarDayData>>(emptyList())
val calendarData: StateFlow<List<CalendarDayData>> = _calendarData.asStateFlow()
```

Use the **domain** types here (`com.swastricare.health.domain.model.menstrualcycle.CyclePrediction` etc.), not the VM-local UI types.

**Step 2: Populate them from the repo**

Add a private helper:

```kotlin
private suspend fun refreshDerived(month: LocalDate = _uiState.value.selectedMonth) {
    (cycleRepository.getPrediction() as? ResultWrapper.Success)?.let { _prediction.value = it.data }
    (cycleRepository.getStatistics() as? ResultWrapper.Success)?.let { _statistics.value = it.data }
    (cycleRepository.getCalendarData(month) as? ResultWrapper.Success)?.let { _calendarData.value = it.data }
}
```

Call it at the end of `loadData()` and at the end of `changeMonth()`.

**Step 3: Remove inline duplicates**

Delete the following private helpers from the ViewModel (the repo owns them now):
- `generatePredictedPeriodDates`
- `generateFertileWindowDates`
- `buildStatisticsFromCycles`

Delete the UI duplicates `CycleStatistics` (VM-local) and `SymptomFrequency`. The UI should consume the domain `CycleStatistics` + `CyclePrediction`. Keep `CycleRecordUi`, `PhaseTip`, `CycleRegularity` — those are UI adapter types.

**Step 4: Fix the screens**

Screens that currently read `uiState.value.statistics` / compute prediction locally now read from the new StateFlows via `collectAsState()`. Compile errors will point you at every site.

**Step 5: Compile + run**

Run: `./gradlew :app:assembleDebug` and manually verify:
- Open cycle screen with existing data → phase badge, countdown, calendar shading match repo output.
- Swipe calendar month → new month's data renders.

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/
git commit -m "refactor(cycle,android): delegate prediction/stats/calendar to repository"
```

---

### Task 13: Wire new settings toggles in `CycleSheets.kt`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/CycleSheets.kt`
- Modify: `MenstrualCycleViewModel.kt` — extend `updateNotificationSettings` signature.

**Step 1: Extend VM method**

```kotlin
fun updateNotificationSettings(
    periodReminder: Boolean? = null,
    fertileReminder: Boolean? = null,
    pmsReminder: Boolean? = null,
    ovulationReminder: Boolean? = null,
    reminderDaysBefore: Int? = null
) {
    viewModelScope.launch {
        val current = _uiState.value.settings
        val updated = current.copy(
            periodReminderEnabled = periodReminder ?: current.periodReminderEnabled,
            fertileWindowReminderEnabled = fertileReminder ?: current.fertileWindowReminderEnabled,
            pmsReminderEnabled = pmsReminder ?: current.pmsReminderEnabled
        )
        _uiState.value = _uiState.value.copy(settings = updated)
        val domainSettings = DomainCycleSettings(
            averageCycleLength = updated.averageCycleLength,
            averagePeriodLength = updated.averagePeriodLength,
            reminderEnabled = updated.periodReminderEnabled,
            reminderTime = "09:00",
            reminderDaysBefore = reminderDaysBefore ?: _prediction.value?.let { 2 } ?: 2, // simplification
            fertileReminderEnabled = updated.fertileWindowReminderEnabled,
            pmsReminderEnabled = updated.pmsReminderEnabled,
            ovulationReminderEnabled = ovulationReminder ?: false,
            lutealPhaseLength = 14
        )
        cycleRepository.updateSettings(domainSettings)
    }
}
```

(Adjust defaults as needed — goal: every new DB column receives a real value.)

**Step 2: Add UI rows in `CycleSettingsSheet`**

Open `CycleSheets.kt`, locate the settings sheet composable, add after the existing period-reminder toggle:

- `SettingsToggleRow("Fertile window reminder", checked = settings.fertileWindowReminderEnabled, onToggle = { vm.updateNotificationSettings(fertileReminder = it) })`
- `SettingsToggleRow("PMS reminder", …)`
- `SettingsToggleRow("Ovulation reminder", …)`
- `SettingsStepperRow("Remind me this many days before", value = settings.reminderDaysBefore, range = 1..7, onChange = { vm.updateNotificationSettings(reminderDaysBefore = it) })`

Use whatever row composable the sheet already defines; the names above are illustrative.

**Step 3: Extend `CycleSettings` UI data class** in `MenstrualCycleViewModel.kt` to carry `reminderDaysBefore` (it currently lacks it).

**Step 4: Compile + run**

Run: `./gradlew :app:assembleDebug`, smoke-test:
- Open settings → toggle each of the four new controls → close → reopen → state persists (in-memory).
- Check `menstrual_settings` row in Supabase dashboard reflects the toggles.

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/
git commit -m "feat(cycle,android): settings UI + VM for fertile/PMS/ovulation reminders + days-before"
```

---

### Task 14: Honour `reminderDaysBefore` in the notification scheduler

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/services/CycleNotificationScheduler.kt`

**Step 1: Accept the new settings**

```kotlin
fun scheduleFromPredictions(
    predictedPeriodStart: LocalDate?,
    predictedOvulation: LocalDate?,
    reminderDaysBefore: Int = 2,
    fertileReminderEnabled: Boolean = false,
    pmsReminderEnabled: Boolean = false,
    ovulationReminderEnabled: Boolean = false
) {
    if (!notificationService.cycleEnabled) return

    predictedPeriodStart?.let { date ->
        val reminderDate = date.minusDays(reminderDaysBefore.toLong())
        if (!reminderDate.isBefore(LocalDate.now())) {
            scheduleCycleAlarm("period", reminderDate, 9,
                "Period Coming Soon",
                "Your period is expected in $reminderDaysBefore days. Be prepared!")
        }
    }

    if (ovulationReminderEnabled) {
        predictedOvulation?.let { date ->
            if (!date.isBefore(LocalDate.now())) {
                scheduleCycleAlarm("ovulation", date, 9,
                    "Ovulation Day", "Today is your predicted ovulation day.")
            }
        }
    }
    // fertileReminderEnabled / pmsReminderEnabled: hook into existing NotificationService
    // categories; if not yet supported, log a TODO and move on — out of scope for this task.

    CycleAINudgeWorker.enqueue(context)
}
```

**Step 2: Update callers**

Grep for `scheduleFromPredictions(` — currently called only by `CycleAINudgeWorker` or similar. Pass the new args from the VM's settings.

**Step 3: Compile + run**

Run: `./gradlew :app:assembleDebug`. Manual test out of scope (notification timing).

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/services/CycleNotificationScheduler.kt \
        android/app/src/main/kotlin/com/swastricare/health/data/workers/ \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/
git commit -m "feat(cycle,android): scheduler honours reminderDaysBefore + new toggles"
```

---

## Phase 6 — iOS coherence

### Task 15: Rename `MenstrualCycleRecord` coding keys

**Files:**
- Modify: `swastricare-mobile-swift/SupabaseManager.swift:2189-2202`

**Step 1: Edit**

```swift
enum CodingKeys: String, CodingKey {
    case id
    case userId = "health_profile_id"
    case startDate = "period_start"
    case endDate = "period_end"
    case cycleLength = "cycle_length"
    case periodLength = "period_length"
    case flowIntensity = "flow_intensity"  // will be removed — see step 2
    case isPredicted = "is_predicted"
    case notes
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case syncedAt = "synced_at"
}
```

**Step 2: Remove `flowIntensity` reference**

`flow_intensity` is dropped from `menstrual_cycles`. Remove the `let flowIntensity: String?` field, its CodingKey, and the encode/decode lines that reference it. Remove the corresponding field from the `MenstrualCycle` struct **only if** no UI reads it — otherwise keep the struct field as transient (derived from daily logs).

Grep: `grep -rn "flowIntensity" swastricare-mobile-swift/`. For each UI site, either switch to `MenstrualDailyLog.flowLevel` or leave the UI field populated from daily logs.

**Step 3: Build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: PASS.

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/SupabaseManager.swift swastricare-mobile-swift/Models/MenstrualCycleModels.swift
git commit -m "fix(cycle,ios): align MenstrualCycleRecord keys with DB (health_profile_id/period_start/period_end)"
```

---

### Task 16: Fix the cycle fetch/query/order clauses

**Files:**
- Modify: `swastricare-mobile-swift/SupabaseManager.swift:1740-1808`

**Step 1: Add a profile-id helper**

Above `syncMenstrualCycle`:

```swift
private func currentHealthProfileId() async throws -> UUID {
    guard let userId = try? await client.auth.session.user.id else {
        throw SupabaseError.notAuthenticated
    }
    struct ProfileRow: Decodable { let id: UUID }
    let row: ProfileRow = try await client
        .from("health_profiles")
        .select("id")
        .eq("user_id", value: userId.uuidString)
        .single()
        .execute()
        .value
    return row.id
}
```

**Step 2: Replace `user_id` filters with `health_profile_id`**

In `syncMenstrualCycle`/`syncMenstrualCycles`: swap `userId` passed into `MenstrualCycleRecord.init(...)` with the result of `currentHealthProfileId()`.

In `fetchMenstrualCycles`:

```swift
let profileId = try await currentHealthProfileId()
let records: [MenstrualCycleRecord] = try await client
    .from("menstrual_cycles")
    .select()
    .eq("health_profile_id", value: profileId.uuidString)
    .order("period_start", ascending: false)
    .limit(limit)
    .execute()
    .value
```

In `deleteMenstrualCycle`: filter `health_profile_id` instead of `user_id`.

**Step 3: Build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: PASS.

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/SupabaseManager.swift
git commit -m "fix(cycle,ios): fetch/delete cycles by health_profile_id, order by period_start"
```

---

### Task 17: Rename `MenstrualDailyLogRecord` coding keys + its callers

**Files:**
- Modify: `swastricare-mobile-swift/SupabaseManager.swift:2266-2330` and its sync/fetch/delete methods (around 1810-1920).

**Step 1: Rename keys**

```swift
enum CodingKeys: String, CodingKey {
    case id
    case userId = "health_profile_id"
    case logDate = "date"
    case cycleId = "cycle_id"
    case flowLevel = "flow_level"
    case painLevel = "pain_level"
    case mood
    case energyLevel = "energy_level"
    case sleepQuality = "sleep_quality"
    case temperature
    case weight
    case cervicalMucus = "cervical_mucus"
    case sexualActivity = "sexual_activity"
    case protectedSex = "protected_sex"
    case notes
    case createdAt = "created_at"
    case updatedAt = "updated_at"
}
```

**Step 2: Rewire sync/fetch/delete to use profile id**

Same pattern as Task 16: `currentHealthProfileId()` for all `userId` uses against `menstrual_daily_logs`; orders by `date`, not `log_date`.

**Step 3: Build**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: PASS.

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/SupabaseManager.swift
git commit -m "fix(cycle,ios): align MenstrualDailyLogRecord with real DB columns"
```

---

## Phase 7 — Verification & smoke tests

### Task 18: Full Android build + install

**Step 1:** `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew clean assembleDebug`
Expected: BUILD SUCCESSFUL.

**Step 2:** `adb -s KB2001 install -r android/app/build/outputs/apk/debug/app-debug.apk`

**Step 3:** Launch app, navigate to Cycle. No crash, no "not set up" state if data exists.

**Step 4:** Smoke checklist:
- Start Period today → row in `menstrual_cycles` (Supabase dashboard).
- Log Daily (flow=medium, cramps, mood=tired, pain=6) → row in `menstrual_daily_logs` with all fields populated.
- Re-log same date (different flow) → row updated in place (unique constraint enforced).
- Open Settings → toggle fertile/PMS/ovulation/days-before → close/reopen → values persist.
- Month navigation on calendar → predictions & fertile shading appear.

Expected: all pass.

**Step 5: No commit** (smoke-test only).

---

### Task 19: Full iOS build + install

**Step 1:** `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: BUILD SUCCEEDED.

**Step 2:** Launch in simulator, log in as the same user as the Android test.

**Step 3:** Navigate to Cycle. Expect to see the cycle and daily log from Android's smoke test.

**Step 4:** iOS-side smoke:
- Log a cycle on iOS → it appears in Supabase with `health_profile_id`, `period_start`, `is_predicted=false`.
- Log a daily entry on iOS → `menstrual_daily_logs` row includes `temperature`, `weight`, `cervical_mucus`, etc. (if UI captures them).

Expected: all pass.

**Step 5: No commit.**

---

### Task 20: Cross-platform sync smoke test

**Step 1:** On iOS, add a cycle starting 45 days ago.

**Step 2:** On Android, pull-to-refresh / reopen cycle screen.

**Step 3:** Verify the iOS-created cycle appears on Android.

**Step 4:** Reverse: create a daily log on Android; verify it appears on iOS.

**Step 5: If all pass, write a short summary comment in the design doc and commit:**

```bash
git add docs/plans/2026-04-22-android-cycle-restructure-design.md
git commit -m "docs(cycle): cross-platform sync verified"
```

---

## Deferred / explicitly out of scope

- **Tests.** Project has no test infrastructure for either platform; adding it is a separate initiative.
- **Pregnancy tables.** `pregnancy_tracking` / `pregnancy_logs` untouched.
- **Fertile/PMS notification content.** Wiring the toggles through `NotificationService` for the fertile/PMS categories may require new notification channels; if they don't exist, log a TODO — the schema support is in place either way.
- **Migration of existing bad rows.** If pre-migration iOS writes produced rows with `NULL` required fields, they simply remain NULL. Not our problem to repair.

## Rollback triggers

Revert the DB migration (using the `-- ROLLBACK` block in the migration file) if:
- PostgREST logs show `column does not exist` after deploy (means a client wasn't updated).
- Data-loss `RAISE NOTICE` counts came back much higher than expected.

Revert Android commits if `assembleDebug` fails in CI or a smoke test regresses. Each phase's commits are independent — cherry-pick reverts are fine.
