# Android Medications Feature — Design Document
**Date:** 2026-03-02
**Platform:** Android (Kotlin / Jetpack Compose)
**Status:** Implemented (iOS Carbon Copy UI — 2026-03-02 rev)

---

## Overview

Full iOS-parity implementation of the Medications feature on Android. Tracks medication adherence with a timeline UI, pill bottle progress animation, and Supabase backend sync.

---

## Files Created

| File | Purpose |
|------|---------|
| `data/models/MedicationModels.kt` | Kotlin data classes + enums mirroring iOS models and Supabase schema |
| `data/repository/MedicationRepository.kt` | Interface + `SupabaseMedicationRepository` with SharedPrefs caching |
| `ui/screens/medications/MedicationsViewModel.kt` | `StateFlow` ViewModel with optimistic updates |
| `ui/screens/medications/MedicationComponents.kt` | Shared composables: `PillBottleProgress`, `DateStrip`, `MedicationCard`, `StatusBadge`, `TimelineGroup`, `AdherenceBarChart` |
| `ui/screens/medications/MedicationsScreen.kt` | Main timeline screen |
| `ui/screens/medications/AddMedicationScreen.kt` | 3-step wizard for adding medications |
| `ui/screens/medications/MedicationDetailScreen.kt` | Detail view with adherence chart and log history |

## Files Modified

| File | Change |
|------|--------|
| `di/AppContainer.kt` | Added `sharedPreferences`, `medicationRepository`, `medicationsViewModel` lazy properties |
| `ui/screens/main/MainScreen.kt` | Added `medications`, `add_medication`, `medication_detail/{id}` routes |
| `ui/screens/home/HomeScreen.kt` | Added `onNavigateToMedications` callback; wired medication card tap |

---

## Architecture

### Data Flow
```
Supabase (medications + medication_schedules + medication_logs tables)
    ↕  SupabaseMedicationRepository
    ↕  SharedPreferences cache (List<MedicationDto> JSON)
    ↕  MedicationsViewModel (StateFlow<MedicationsUiState>)
    ↕  MedicationsScreen / MedicationDetailScreen
```

### Key Design Decisions

1. **Pending status is client-side only**
   The `medication_logs` DB table only supports `taken/skipped/missed/late/early`. "Pending" doses are computed by cross-referencing `medication_schedules` with today's logs — no DB write for pending state.

2. **Optimistic updates**
   When the user taps "Take", the UI updates immediately (status → TAKEN). If the Supabase call fails, the update reverts.

3. **Local cache for instant display**
   `SupabaseMedicationRepository.getCachedMedications()` loads from SharedPreferences on app start, so the list shows instantly while Supabase data loads in background.

4. **Soft delete**
   `deleteMedication()` sets `status = 'discontinued'` rather than hard-deleting, preserving log history.

5. **Navigation within Vitals tab**
   Medication routes (`medications`, `add_medication`, `medication_detail/{id}`) are added to the inner NavHost in `MainScreen.kt`, keeping them within the Vitals tab stack.

---

## UI Components

### PillBottleProgress
Canvas-drawn animated pill bottle. Fill height is animated with `animateFloatAsState`. Color transitions green→orange→red based on adherence rate (≥80% / ≥50% / <50%).

### Timeline Layout
Doses grouped by time period: Morning (5–12), Afternoon (12–17), Evening (17–21), Night (21+). Each group uses `TimelineGroup` composable. Empty groups are hidden.

### MedicationCard
Glassmorphic card with: type emoji, scheduled time, name/dosage, status badge, and Take/Skip action buttons (shown only for PENDING status).

### 3-Step Add Wizard
Step 1: Name + type grid + dosage
Step 2: Schedule frequency chips + time pickers (system `TimePickerDialog`)
Step 3: Duration (ongoing toggle + date) + notes
LinearProgressIndicator tracks progress.

---

## Supabase Tables Used

| Table | Operations |
|-------|-----------|
| `medications` | SELECT (active), UPSERT (new medication), UPDATE (soft-delete status) |
| `medication_schedules` | SELECT (active schedules), UPSERT (new schedules) |
| `medication_logs` | SELECT (today/week range), UPSERT (taken/skipped) |

All queries filter by `health_profile_id`.

---

## Testing Checklist

- [ ] `./gradlew assembleDebug` — 0 errors
- [ ] Home screen medication card taps → navigates to MedicationsScreen
- [ ] "+" button → AddMedicationScreen opens, 3-step wizard completes
- [ ] Tap "Take" → status changes optimistically, Supabase log created
- [ ] Tap "Skip" → skip reason dialog, then skipped status
- [ ] Tap a medication card → MedicationDetailScreen opens
- [ ] Kill/relaunch → cached medications shown instantly
- [ ] Empty state shown for fresh account with no medications
- [ ] Supabase dashboard shows `medications` + `medication_logs` rows with correct `health_profile_id`
