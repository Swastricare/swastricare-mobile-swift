# Activity Screen Redesign (Android)

**Date:** 2026-04-11  
**Scope:** `RunActivityScreen.kt` only — LiveWorkoutScreen unchanged  
**Style reference:** Strava (bold stats, dark density) + Nike Run Club (large typography, strong color per type)

---

## Problem

The current `RunActivityScreen` has:
- A "Start a Workout" hero card that navigates to `LiveWorkoutScreen` (idle phase) as a separate screen
- Four small quick-start buttons duplicating what the idle phase already provides
- A flat weekly stats table with no visual rhythm
- Generic card layout with no strong visual identity

The user wants:
1. Workout-type selection embedded directly in the activity screen
2. A brand-new design from scratch — more visual, more confident
3. No separate idle screen — START is always one tap away

---

## Design

### Layout

```
┌─────────────────────────────┐
│  Activity          📅        │  Header
├─────────────────────────────┤
│  Today                      │
│  8,432   2.1km   312kcal   │  Hero stats card (large bold numbers)
├─────────────────────────────┤
│  This Week                  │
│  M T W T F S S  (bar chart)│  7-day activity bar chart
├─────────────────────────────┤
│  VO2 Max 42.3  · Building ↑ │  Fitness insights chips (if data exists)
├─────────────────────────────┤
│  Recent Workouts   See all →│
│  ▌Run · 5.2km · 28:14      │  Strava-style cards (colored left border)
│  ▌Walk · 3.1km · 42:00     │
│  ▌Cycle · 14km · 55:00     │
│     (scrolls)               │
├═════════════════════════════╡  fixed divider
│  🏃 🚶 🚴 ⛰               │  4 workout type chips (always visible)
│  ┌──────────────────────┐  │
│  │   ▶  START RUN       │  │  Pulsing START button (full-width, green)
│  └──────────────────────┘  │
└─────────────────────────────┘
```

### Sections

#### 1. Header
- "Activity" — `headlineMedium`, `FontWeight.ExtraBold`, left-aligned
- Calendar icon button right — navigates to `RunCalendarScreen`

#### 2. Today's Hero Stats Card
- Dark surface card (`AppColors.surfaceVariant`)
- 3 columns: Steps · Distance (km) · Calories
- Numbers: `headlineLarge`, `FontWeight.Bold`
- Colored icons: Steps=cyan, Distance=green, Calories=orange
- "Today" label top-left in `labelMedium`

#### 3. Weekly Activity Bar Chart
- 7 bars (Mon–Sun), each bar height = proportional to that day's total distance/calories
- Bar color = dominant activity type that day (cyan=run, green=walk, yellow=cycle, purple=hike), gray if no activity
- Day label below each bar
- Today's bar has a dot marker above it
- Section title: "This Week" `titleSmall`

#### 4. Fitness Insights (conditional)
- Shown only when `vo2Max != null || weeklyTrainingLoad > 0`
- Horizontal chip row: VO2 Max chip, Weekly Load chip, Trend chip
- Each chip: rounded pill, colored icon + value + label

#### 5. Recent Workouts
- Section header: "Recent" left, "See all →" right (navigates to RunCalendarScreen)
- Up to 5 workout cards
- **Card style (Strava-inspired):**
  - 4dp left-edge colored stripe (type color)
  - Bold distance headline left
  - Date + pace/time subtitle
  - Calories right-aligned
  - No chevron
- Empty state: centered icon + two lines of text (only in this section)

#### 6. Fixed Bottom Workout Panel (~180dp, not scrollable)
- **Workout type chips row** — 4 chips: Run / Walk / Cycle / Hike
  - Selected: solid color background + white text + type icon
  - Unselected: transparent bg + outline + muted text
  - Colors: Run=RunningCyan, Walk=WalkingGreen, Cycle=CyclingYellow, Hike=HikingPurple
  - Default selected: RUN
- **START button** — full-width, `RoundedCornerShape(16.dp)`, `SecondaryColor` fill
  - Label: "START [TYPE]" — updates dynamically
  - Pulse animation on idle (scale 1.0→1.02 loop)
  - On click: haptic + `onNavigateToLiveWorkout(selectedType)`

---

## Removed
- `StartWorkoutCard` hero banner
- `QuickStartButton` row (4 buttons)
- `WeeklyStatsCard` flat table
- `FitnessCard` column layout → replaced by chip row

## Unchanged
- `RunActivityViewModel` — no logic changes
- `LiveWorkoutScreen` — untouched
- Navigation callbacks — same signatures

---

## Files to Change
- `RunActivityScreen.kt` — full rewrite (single file, ~550 lines)

## Files Unchanged
- `RunActivityViewModel.kt`
- `LiveWorkoutScreen.kt` + all phase components
- Navigation graph
