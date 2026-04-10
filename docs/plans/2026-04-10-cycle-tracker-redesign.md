# Cycle Tracker Redesign — Android

**Date:** 2026-04-10
**Platform:** Android (Jetpack Compose)

---

## Problem

1. **UI quality** — The current cycle screen lacks polish. The onboarding empty state uses a plain emoji instead of the available hero illustration. Cards lack visual hierarchy.
2. **No period logging UX** — Tapping "Log Your Period" only picks a date. No flow level, symptoms, mood, pain level, or notes are collected.
3. **State management bugs** — After logging, the calendar does not update. Profile ID is never resolved correctly (reads from a SharedPreferences key that is never written), so all local saves and Supabase calls silently no-op. Navigating away and back loses state.

---

## Design

### 1. Hero Illustration Usage

Asset: `assets/illustrations/cycle illustration.png`

- **Empty/Onboarding state:** Full-width illustration (220dp height) above the "Track Your Cycle" headline, replacing the plain emoji box.
- **Log Period sheet header:** Small illustration strip (120dp height) at the top of the bottom sheet, giving it warmth and context.

### 2. Log Period Flow — Multi-Page Bottom Sheet

A tall `ModalBottomSheet` with `skipPartiallyExpanded = true`. Steps are animated with `AnimatedContent` sliding left→right. Step indicator dots shown below the illustration header.

**6 Steps:**

| # | Title | UI Component |
|---|-------|-------------|
| 1 | When did it start? | `DatePicker` with today pre-selected |
| 2 | How heavy is the flow? | 5 horizontal chips: None / Light / Medium / Heavy / Very Heavy (with droplet icons) |
| 3 | Any symptoms? | Multi-select wrapped chip grid (14 symptoms): Cramps, Bloating, Fatigue, Mood Swings, Headache, Backache, Nausea, Acne, Insomnia, Cravings, Breast Tenderness, Spotting, Anxiety, Irritability |
| 4 | How's your mood? | 8 emoji-style selectable cards: 😊 Happy / 😌 Calm / ⚡ Energetic / 😰 Anxious / 😢 Sad / 😤 Irritable / 😴 Tired / 😐 Neutral |
| 5 | Pain level? | `Slider` 0–10 with emoji feedback at key values (0=😊, 3=😐, 6=😟, 10=😣) |
| 6 | Anything else? | `OutlinedTextField` for notes + summary card of all selected values → pink "Log Period" confirm button |

Navigation: Back arrow (top-left) and "Next →" button (bottom-right). Step 6 shows "Log Period" instead of Next.

### 3. State Management Fixes

**Profile ID resolution:**
- `getProfileId()` is now `suspend` and queries `health_profiles` table using the authenticated user's ID — same pattern as `DietRepositoryImpl`.
- Cache the resolved profile ID in a `@Volatile private var cachedProfileId: String? = null` field. On first call, fetch from Supabase and cache. Subsequent calls return cached value immediately.

**Post-action refresh:**
- After `startCycle` or `logDailyData` returns `ResultWrapper.Success`, immediately set `isNotSetUp = false` (optimistic) then call `loadData()`.
- `loadData()` sets `isLoading = true` → fetches → sets full state. No intermediate stale state.

**Navigation stability:**
- ViewModel is Hilt-scoped (`@HiltViewModel`) — it survives configuration changes already. The issue was `loadData()` not being called on re-entry because state appeared valid. Fix: call `loadData()` in `init {}` unconditionally (already done) — no change needed here once profile ID is fixed.

### 4. Main Screen UI Improvements

- Replace plain emoji box in onboarding with the hero illustration
- Add a floating "+" FAB (pink) on the main cycle screen (when set up) to re-open the log sheet for additional logging
- Cycle status card: add subtle gradient border matching the current phase color
- Calendar header: show month + year in a more prominent `titleLarge` style

---

## Files to Modify

| File | Change |
|------|--------|
| `MenstrualCycleRepositoryImpl.kt` | Cache profile ID, fix all local helper suspend signatures (done) |
| `MenstrualCycleScreen.kt` | Hero illustration in onboarding, FAB, UI polish |
| `CycleSheets.kt` | Replace `CycleSettingsSheet` onboarding button handler; add new `LogPeriodSheet` multi-step flow |
| `MenstrualCycleViewModel.kt` | Post-log optimistic state update before `loadData()` |

---

## Success Criteria

- Tapping "Log Your Period" opens the 6-step sheet
- After completing all steps, the calendar updates immediately showing the logged dates
- Navigating away and back preserves the logged data
- The illustration appears on the empty state and inside the log sheet header
- Profile ID is correctly resolved so data saves to both local storage and Supabase
