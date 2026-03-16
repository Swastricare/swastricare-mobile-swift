# Health Analytics UI Redesign
**Date:** 2026-03-16
**Platform:** Android (Kotlin / Jetpack Compose)
**Files:** `ui/screens/analytics/HealthAnalyticsScreen.kt`, `ui/screens/analytics/HealthAnalyticsViewModel.kt`
**Approach:** Dashboard Hero + Tappable Grid + Metric Detail Screen (Approach A)

---

## Goals

1. **Visual polish** — elevate every component to match the premium design language used across FamilyScreen, HomeScreen (glass cards, PremiumBackground, gradient accents)
2. **Information architecture** — replace the horizontal-scroll summary card row with a hero health-score ring; make all metric cards tappable
3. **Chart quality** — taller charts (280dp), bezier curves, drag scrubber with tooltip, goal line badge
4. **Drill-down** — new `HealthMetricDetailScreen` for per-metric deep view

---

## Screen Layout

Single `LazyColumn` replacing `verticalScroll(Column)`:

```
TopBar → Hero Card → Time Range Chips → Chart Card → Metrics Grid → AI Insights Card
```

---

## Component Designs

### 1. TopBar
- Back button (glass circle, 40dp)
- Title "Health Analytics"
- Right: date badge — pill-shaped glass chip showing "Today, Mar 16"

### 2. Hero Card
Full-width glass card with gradient border (DeepPurple: `0xFF654EA3 → 0xFFEAAFC8`).

**Left — Health Score Ring (110dp, Canvas):**
- Animated arc from 0 → score on entry (`tween 1200ms, FastOutSlowInEasing`)
- Gradient stroke: metric-dominant-color → white
- Center text: score number (bold, 28sp) + label ("Good", 11sp, colored)
- Score formula (weighted avg, 0–100):
  - Steps: 30% (value / goal * 100, capped at 100)
  - Sleep: 25% (value / 8h * 100, capped at 100)
  - Hydration: 25% (value / 2500ml * 100, capped at 100)
  - HeartRate: 20% (within 60–100 BPM = 100, else scaled down)
- Buckets: 0–39 = "Needs Attention" (AccentRed), 40–69 = "Fair" (WarningOrange), 70–89 = "Good" (SecondaryGreen), 90–100 = "Excellent" (PrimaryIndigo)

**Right — 4 Metric Pills (stacked Column):**
- Steps, HeartRate, Sleep, Hydration
- Each pill: colored dot (8dp) + metric label (11sp) + value (13sp bold)
- Below value: thin horizontal bar (full width of pill, 4dp height, rounded) showing % of daily goal, filled with metric color

**Card entry animation:** fade + translateY(-24dp → 0) on composition, `tween(600ms, delay=100ms)`.

**Greeting:** "Good morning / afternoon / evening, [firstName]" derived from auth display name. Date badge top-right.

---

### 3. Time Range Chips
`LazyRow` (not `Row`) with `horizontalArrangement = spacedBy(10dp)`, `contentPadding = PaddingValues(horizontal=16dp)`.
Chips: Day / Week / Month — selected chip uses `AppColors.primary` fill, unselected uses transparent + border.

---

### 4. Chart Card
Full-width glass card, `padding(16dp)`.

**Metric Type Tabs (LazyRow):**
- Each tab: Column(icon circle 36dp + label text 10sp), selected = filled metric color, unselected = metric color at 10% alpha
- 8 metrics, horizontal scroll, `spacedBy(12dp)`

**Chart (280dp Canvas):**
- Day/Week → Bar chart with rounded top corners (6dp), gradient fill per bar (metric color → 60% alpha), entry animation `tween(800ms)`
- Month → Bezier line chart (cubic bezier control points), gradient fill below line, animated path draw `tween(1000ms)`
- Y-axis: 4 ticks, labels at 9sp
- Goal line: dashed white 50% + right-anchored pill badge "Goal: X"
- Drag scrubber: `pointerInput(detectDragGestures)` → vertical indicator line + floating tooltip showing date + value; tooltip fades with `animateFloatAsState`

---

### 5. Metrics Grid
**MetricGridCard (updated):**
- Tappable → navigates to `HealthMetricDetailScreen(metricType)`
- Circular mini goal-progress ring (48dp Canvas) in top-right, fills from 0 → (value/goal) on entry
- Ripple effect on tap
- Staggered entry: fade + translateY per card, 80ms delay between cards

---

### 6. AI Insights Card
- Pulsing animation on AutoAwesome icon (scale 1.0 → 1.15 → 1.0, infiniteTransition, `tween(1500ms)`)
- Gradient border matching DeepPurple
- CTA button: full-width, `PremiumColor.DeepPurple` gradient background, white text

---

## New Screen: HealthMetricDetailScreen

**Route:** `analytics/detail/{metricType}`

**Layout:**
```
TopBar (back + metric name)
↓
Large Chart Card (320dp, always bezier line chart)
↓
Stats Row: Current | Average | Best | Goal (4 glass chips)
↓
Goal Progress Card: Large ring (160dp) + percentage + "X remaining" text
↓
Recent History List: Last 7 days as date rows with value + mini bar
```

---

## Navigation Changes

- `NavConfig.kt`: Add `HEALTH_METRIC_DETAIL = "analytics/detail/{metricType}"`
- `AppNavigation.kt`: Add composable destination for detail screen
- `HealthAnalyticsScreen`: Add `onNavigateToMetricDetail: (LegacyMetricType) -> Unit` callback

---

## ViewModel Additions

- `healthScore: Int` added to `LegacyHealthAnalyticsState`
- `scoreLabel: String`, `scoreColor: Color` computed in `buildSummaries()`
- `MetricStats(current, average, best, goal)` data class
- `getMetricStats(metric): MetricStats` function on ViewModel

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `ui/screens/analytics/HealthAnalyticsScreen.kt` | Full rewrite |
| `ui/screens/analytics/HealthAnalyticsViewModel.kt` | Add healthScore, MetricStats |
| `ui/screens/analytics/HealthMetricDetailScreen.kt` | New file |
| `ui/navigation/NavConfig.kt` | Add HEALTH_METRIC_DETAIL route |
| `ui/navigation/AppNavigation.kt` | Add detail screen composable |

---

## Design Tokens Used

- `AppColors.primary` — selected states, score "Excellent"
- `AppColors.secondary` — score "Good"
- `WarningOrange` — score "Fair"
- `DangerRed` — score "Needs Attention"
- `PremiumColor.DeepPurple` — hero card border, AI card border, CTA
- `StepsColor`, `HeartRateColor`, `SleepColor`, `HydrationColor` — per-metric
- `.glass(cornerRadius = 20.dp)` — all cards
- `PremiumBackground()` — screen background
