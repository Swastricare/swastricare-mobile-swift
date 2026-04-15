# Sleep Manual Entry — Design

**Date:** 2026-04-14  
**Platform:** Android (Kotlin / Jetpack Compose)  
**Scope:** Manual sleep logging when Health Connect has no data for a given day

---

## Problem

The current SleepScreen is read-only — it only displays data synced from Health Connect. Users without a wearable, or users who missed a sync, have no way to log sleep manually.

## Solution

Add a `LogSleepScreen` — a full-screen manual entry UI with a circular arc slider for duration, reachable from both the empty state and a FAB on the main SleepScreen.

---

## Behaviour Rules

- If Health Connect has data for the selected date → that date's chip is disabled ("Synced from wearable"). Manual entry is blocked for that date.
- Manual entry is always available for dates where HC has no data.
- Manual data is saved to Supabase `daily_health_metrics` with `source = "manual"`.

---

## Screen Layout: LogSleepScreen

### 1. Top Bar
- Back arrow + "Log Sleep" title

### 2. Date Chips Row
- Horizontally scrollable chips: Today, Yesterday, 2 days ago … 6 days ago
- Chips with HC data: disabled style, subtitle "Synced"
- Default selection: most recent date without HC data (usually Today)

### 3. Circular Arc Slider (main element)
- Size: 260dp diameter, centered
- Arc sweep: 270° (from ~135° to ~405°), representing 0h to 12h
- Single drag handle with moon icon
- Arc fills with `SleepColor` (indigo) proportional to duration
- Background arc: white at 10% alpha
- Center label: duration in large bold (`7h 30m`), subtitle `Sleep Duration`
- Snap to 15-minute increments

### 4. Time Chips Row
- Two pill chips: `Bedtime  11:00 PM` and `Wake Up  6:30 AM`
- Auto-derived: wake = current time rounded to nearest 30min; bedtime = wake − duration
- Tapping either opens system `TimePickerDialog`
- Changing either time recalculates duration and updates the arc

### 5. Notes Field
- Single-line optional text input
- Placeholder: "How did you feel?"

### 6. Save Button
- Full-width, `SleepColor` gradient background
- Label: "Save Sleep"
- Disabled (greyed) until `durationMinutes > 0`

---

## Data Model

No new model class needed. Reuses `SleepSession`:

```kotlin
SleepSession(
    date = selectedDate,
    startTimeEpochMillis = bedtimeMillis,
    endTimeEpochMillis = wakeTimeMillis,
    totalMinutes = durationMinutes,
    // stages left empty — manual entry has no stage data
)
```

---

## ViewModel: LogSleepViewModel

State:
```kotlin
data class LogSleepUiState(
    val selectedDate: LocalDate = LocalDate.now(),
    val durationMinutes: Int = 0,           // 0 = nothing set yet
    val bedtimeMillis: Long = 0L,
    val wakeTimeMillis: Long = 0L,
    val notes: String = "",
    val disabledDates: Set<LocalDate> = emptySet(), // dates with HC data
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val error: String? = null
)
```

Actions:
- `selectDate(date)` — switches selected date, checks if disabled
- `setDuration(minutes)` — updates duration, recalculates wake/bedtime
- `setBedtime(millis)` — updates bedtime, recalculates duration + wake
- `setWakeTime(millis)` — updates wake, recalculates duration + bedtime
- `setNotes(text)`
- `save()` — calls repository, emits `saveSuccess = true` on completion

---

## Repository Change: SleepRepository

Add one method:

```kotlin
suspend fun saveManualSession(session: SleepSession, profileId: String): ResultWrapper<Unit>
```

Implementation in `SleepRepositoryImpl`:
- Upserts into `daily_health_metrics` with `source = "manual"`
- Conflict key: `(profile_id, date)` — overwrites previous manual entry for same date

---

## Entry Points

### A. Empty state (SleepScreen)
Replace the current "Sleep data will appear here..." text with a "Log Sleep" `Button` below the icon. Navigates to `LogSleepScreen`.

### B. FAB on SleepScreen
- `FloatingActionButton` with `Icons.Default.Bedtime`, bottom-right corner
- Visible only when today has no HC data (`uiState.todaySession == null`)
- Navigates to `LogSleepScreen`

---

## Navigation

New route added to `MainNavGraph.kt`:

```
sleep/log  →  LogSleepScreen(onNavigateBack)
```

`SleepScreen` gets an `onNavigateToLog: () -> Unit` parameter.

---

## What's Excluded

- Sleep stage breakdown (manual entry cannot know stages)
- Editing or deleting previously logged manual sessions (future scope)
- Editing HC-synced sessions
