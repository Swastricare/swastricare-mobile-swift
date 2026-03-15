# Home Screen Visual Refresh

**Date:** 2026-03-14
**Status:** Approved
**Platform:** iOS (Swift/SwiftUI)

## Summary

Visual refresh of the HomeView to match the premium design language established in the onboarding and login redesign. Introduces a semantic color tint system, zoned spacing rhythm, redesigned header, color-tinted vitals/quick action cards with progress bars, and a compact activity bar replacing the 320pt 3D model section.

## Problems Solved

1. **No visual hierarchy** — every section uses identical `.glass(cornerRadius: 16)`, no variation or rhythm
2. **Not premium** — doesn't match the new onboarding/login aesthetic (bold type, gradients, glass depth)
3. **Colors/spacing off** — uniform gray cards, uniform 16pt gaps, 3D model takes too much space

## Design

### A. Semantic Color Tint System

Replace uniform gray glass backgrounds with feature-specific color tints. Each card gets:
- Background: `featureColor.opacity(0.07)` (dark mode: `0.05`)
- Border: `featureColor.opacity(0.10)` (dark mode: `0.08`), 1px stroke
- Corner radius: 16pt (using `AppDimensions.cardRadius`)
- Values and labels use the feature's semantic color

**Color map:**

| Feature | Color | Hex |
|---------|-------|-----|
| Heart Rate | Red | `AppColors.accentRed` (#EF4444) |
| Sleep | Indigo | `Color.indigo` / `AppColors.sleep` |
| Distance/Steps | Green | `AppColors.accentGreen` (#22C55E) |
| Hydration | Sky Blue | `AppColors.onboardingSkyBlue` (#0EA5E9) |
| Medication | Purple | `AppColors.medication` (#5856D6) |
| Diet | Orange | `Color.orange` |
| Menstrual Cycle | Pink | `Color(hex: "EC4899")` |
| Active Calories | Orange | `Color.orange` |
| Exercise | Blue | `AppColors.accentBlue` |
| Stand Hours | Purple | `Color.purple` |

### B. Section Spacing & Rhythm

**Zone structure (top to bottom):**
1. Header zone
2. Nudge zone (conditional)
3. Activity bar zone (replaces 3D model)
4. Vitals zone
5. AR Body Scan card
6. Quick actions zone

**Spacing rules:**
- Between major zones: 28pt
- Within a zone (between cards): 12pt
- Section labels: Optional uppercase labels in 11pt `.semibold`, `.secondary` color, 0.8pt tracking (e.g., "YOUR VITALS", "QUICK ACTIONS"). Placed 8pt above each zone.
- Horizontal padding: 20pt (matching onboarding/login)

### C. Greeting Header Redesign

**Layout (single HStack):**
- **Left side:**
  - Greeting text: 13pt `.medium`, `.secondary` color ("Good Morning")
  - User name: 24pt `.bold`, `.primary` color (no heart emoji)
  - Status line: 8pt green dot + "All vitals normal" in 12pt `.semibold`, `AppColors.accentGreen`
- **Right side:**
  - Bell icon: 34×34pt rounded square (cornerRadius 10), `Color.primary.opacity(0.06)` background, 0.5pt border
  - User avatar/initial: 34×34pt rounded square (cornerRadius 12), 2pt border using brand gradient (`#11998e → #38ef7d`), initial letter in white on gradient background

**Status logic (existing):**
- Green dot + "All vitals normal" — when health metrics are in range
- Orange dot + "Needs attention" — when any metric is flagged
- Blue dot + "Syncing..." — when data is loading

### D. Compact Activity Bar (replaces 3D model section)

Replace the 320pt `humanBodyImageWithDetails` section with a compact horizontal bar (~80pt height):

**Layout:** HStack with 3 evenly-spaced activity pills:
- **Active Calories:** orange-tinted pill, flame icon, value + "kcal" unit
- **Exercise Minutes:** blue-tinted pill, clock icon, value + "min" unit
- **Stand Hours:** purple-tinted pill, figure icon, value + "hrs" unit

**Each pill:**
- Background: `featureColor.opacity(0.07)`, border: `featureColor.opacity(0.10)`
- Corner radius: 14pt
- Icon: 20×20pt rounded square with `featureColor.opacity(0.15)` background
- Value: 18pt `.bold` in feature color
- Unit: 10pt `.secondary`

**Note:** The 3D model (`ModelViewer(modelName: "anatomy")`) is NOT deleted — it remains available for the AR Body Scan card. We only remove it from the main home scroll.

### E. Vitals Cards Redesign

Replace the current flat 3-column `LazyVGrid` with color-tinted cards:

**Each vital card:**
- Background: semantic color tint (per color map above)
- Border: 1px semantic color stroke at 0.10 opacity
- Corner radius: 16pt
- **Top row:** 22×22pt icon badge (rounded square, `color.opacity(0.15)`) + label in 10pt `.semibold`
- **Value:** 24pt `.bold`, `-1` letter spacing, in semantic color
- **Bottom:** unit + status label in 9pt (e.g., "bpm · Normal")
- Tappable: Heart Rate opens HeartRateView (existing behavior preserved)

**Grid:** 3-column `LazyVGrid` with 10pt spacing (same as current)

### F. Quick Actions Redesign

Replace the current uniform 2×2 grid with color-tinted cards with progress bars:

**Each quick action card:**
- Background: semantic color tint (per color map above)
- Border: 1px semantic color stroke
- Corner radius: 16pt
- **Top row:** 28×28pt icon badge (rounded square, `color.opacity(0.12)`) + label in 11pt `.bold`
- **Value:** 20pt `.bold` in semantic color, with unit in 13pt `.semibold` at 0.6 opacity
- **Progress bar:** 4pt height, `color.opacity(0.10)` track, solid color fill, 2pt corner radius
  - Medication: `takenCount / totalCount`
  - Hydration: `currentML / dailyGoalML`
  - Diet: `currentCalories / dailyGoalCalories`
  - Cycle: no progress bar — shows "Day X" + phase name instead

**Grid:** 2-column `LazyVGrid` with 10pt spacing
- All 4 items are equal size (no spanning)
- Menstrual Cycle card: same size as others (remove the 2-column span)

### G. Staggered Entrance Animations

Replace the current simultaneous opacity fade with a cascading reveal:

**Timing:**
- 0.00s: Header slides in (spring, response 0.6, damping 0.8)
- 0.10s: Activity bar slides up
- 0.20s: Vitals zone slides up
- 0.30s: Quick actions zone slides up

Each element: offset Y from 20pt → 0pt, opacity 0 → 1, using `.spring(response: 0.6, dampingFraction: 0.8)`

Respect `@Environment(\.accessibilityReduceMotion)` — show instantly if enabled.

Keep the existing `hasAppeared` flag pattern to prevent re-animating on tab switches.

## Technical Changes

### Files to Modify
- `swastricare-mobile-swift/Views/Home/HomeView.swift` — all visual changes

### Scope Boundaries
- **Functional behavior unchanged** — all taps, sheets, deep links, data loading, pull-to-refresh work exactly as before
- **No ViewModel changes** — this is purely a view-layer refresh
- **No new files** — all changes within HomeView.swift
- **3D model code stays** — just removed from the main scroll layout. `ModelViewer` import and the AR Body Scan card remain.

### What NOT to Change
- `HomeViewModel.swift` — no data layer changes
- `HomeViewV2.swift` — leave untouched
- Other Views/Home/ files (HydrationView, MedicationsView, etc.) — not in scope
- Tab structure in ContentView — unchanged
- Navigation logic — unchanged
