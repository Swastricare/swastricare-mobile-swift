# Hydration Screen Redesign — Android

**Date:** 2026-03-30

## Goal

Redesign the Android hydration screen to match the reference design pattern: full blue gradient background, greeting header, large circular progress hero, sliding insight card, bottom-card entry list, and FAB-triggered add sheet. All existing ViewModel logic and functionality is preserved.

## Visual Shell

- Full-bleed gradient background: `#0EA5E9` → `#2563EB` (top-to-bottom)
- All text directly on gradient in white — no wrapping surface card for the hero area
- Bottom section is a white rounded-top persistent card (like a bottom sheet pinned to bottom)

## Layout Sections (top → bottom)

### 1. Top Bar
- Back arrow (left)
- Settings + AI icons (right)
- No title — greeting replaces it

### 2. Greeting Header
- `Hello, [Name]` — bold white, large
- Subtitle: dynamic based on progress (`"You're on track!"` / `"Drink more water"` / `"Goal reached! 🎉"`)
- Name sourced from ProfileRepository (same as HomeScreen)

### 3. Hero Pager (swipeable, 2 pages)
**Page 1 — Progress Ring**
- Large circular arc ring, white track, white/cyan-glow arc
- Center: 💧 → ml consumed (large bold) → `of XxxxML` → `X%`
- Ring color: white at <70%, cyan glow at ≥70%, green at 100%

**Page 2 — Insights**
- Streak days, 7-day avg, favourite drink, caffeine count — same data as current HydrationInsightsCard
- White card style on gradient

- Pagination dots between hero and calendar

### 4. Calendar Strip
- Existing `HydrationCalendarStrip` — restyled: translucent white pill bg per day, selected = white filled

### 5. Weather Banner (conditional)
- Shown inline below calendar if `uiState.isWeatherAdjusted`
- Semi-transparent white card, same data as current `WeatherAdjustmentBanner`

### 6. Bottom Card (white rounded-top sheet, scrollable)
**Header row:**
- `Today, DD MMM YYYY` (bold)
- `N drinks · Xml` subtitle
- Calendar icon tapping selects date

**Entry rows:**
- Drink emoji in cyan-tinted circle
- Drink name + `Xml · Xml effective`
- Time right-aligned
- Swipe or delete icon

**Empty state:**
- `💧 No drinks yet` centered, with hint to tap `+`

### 7. FAB
- Cyan `+` FAB, bottom-right
- Opens `AddDrinkBottomSheet`

## Add Drink Bottom Sheet
- Handle + "Add a Drink" title
- Drink type chips (horizontal scrollable) — all existing `DrinkType` values
- Quick-add preset grid (3 columns) — all existing `QuickAddPreset.defaults`
- Custom amount `OutlinedTextField` + "Add" button
- Divider + "Urine Color Guide" text button at bottom (opens existing `UrineColorGuideSheet`)

## ViewModel Changes
- Add `userName: String` field to `HydrationUiState`, loaded from `profileRepository` in `loadData()`
- No other logic changes

## Files to Modify
- `HydrationScreen.kt` — full rewrite of composable layout
- `HydrationComponents.kt` — add new components; keep `WaterGlassView`, `UrineColorGuideSheet`, `DrinkTypePicker`, `QuickAddButton`, `HydrationEntryCard`, `HydrationInsightsCard`; add `HydrationHeroRing`, `AddDrinkBottomSheet`, restyled `HydrationCalendarStrip`
- `HydrationViewModel.kt` / `HydrationUiState` — add `userName` field

## Preserved Features
- Weather adjustment banner
- Urine color guide sheet
- Insights (streak, avg, favourite drink, caffeine)
- All quick-add presets
- Drink type selection
- Custom amount input
- Date selection via calendar strip
- Delete entries
- Error snackbar
- Skeleton loading state
- AI navigation button
- Settings navigation button
