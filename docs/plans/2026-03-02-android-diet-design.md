# Android Diet Feature — Design Document
**Date:** 2026-03-02
**Platform:** Android (Kotlin / Jetpack Compose)
**Status:** Implemented (iOS Carbon Copy UI — 2026-03-02)

---

## Overview

Full iOS-parity implementation of the Diet / Calorie Tracker feature on Android. Tracks daily food intake across 6 meal types with macro breakdowns, a calorie progress ring, food discovery (categories, recents, favorites), food search, and Supabase backend sync.

---

## Files Created

| File | Purpose |
|------|---------|
| `data/models/DietModels.kt` | Kotlin data classes + enums mirroring iOS `DietModels.swift` and Supabase schema |
| `data/repository/DietRepository.kt` | Interface + `SupabaseDietRepository` with SharedPrefs caching and Supabase sync |
| `ui/screens/diet/DietViewModel.kt` | `StateFlow` ViewModel with local-first loading and background cloud sync |
| `ui/screens/diet/DietComponents.kt` | Shared composables: `DietCalendarStrip`, `CalorieProgressRing`, `DietStatPill`, `MacroBreakdownCard`, `MealSectionCard`, `FoodEntryRow`, `FoodItemRow` |
| `ui/screens/diet/DietScreen.kt` | Main diet chart screen with progress ring, macro breakdown, and meal sections |
| `ui/screens/diet/AddFoodScreen.kt` | Food discovery hub with search, recents, favorites, category grid, custom food entry, and `FoodQuantitySheet` |
| `ui/screens/diet/FoodSearchScreen.kt` | Category-filtered food search with instant results |

## Files Modified

| File | Change |
|------|--------|
| `di/AppContainer.kt` | Added `dietRepository` and `dietViewModel` lazy properties |
| `ui/screens/main/MainScreen.kt` | Added `diet`, `add_food/{mealTypeDb}`, `food_search/{mealTypeDb}` routes + new imports |
| `ui/screens/home/HomeScreen.kt` | Added `onNavigateToDiet` callback + "Diet Chart" entry card |

---

## Architecture

### Data Flow
```
Supabase (food_items [public] + diet_logs [auth])
    ↕  SupabaseDietRepository
    ↕  SharedPreferences cache (food_items JSON + diet_logs JSON)
    ↕  DietViewModel (StateFlow<DietUiState>)
    ↕  DietScreen / AddFoodScreen / FoodSearchScreen
```

### Key Design Decisions

1. **Local-first storage**
   All diet logs are written to SharedPreferences first, then synced to Supabase in background. This means the user sees their data instantly even offline. Sync uses `upsert` so duplicate writes are idempotent.

2. **`food_items` is a public table**
   No `health_profile_id` filter needed when fetching food items — the table has a public SELECT RLS policy. Food items are cached locally after first fetch so subsequent app launches don't require a network call.

3. **Multiplier-based log entries**
   `DietLogEntry.multiplier = quantity / foodItem.servingSize`. All nutrition values are computed on-the-fly as `baseValue * multiplier`, so we never store pre-multiplied values — same pattern as iOS.

4. **`DietGoals` macro percentages**
   Macro targets are stored as percentages (proteinPct, carbsPct, fatPct) rather than absolute grams. Gram values are computed as `(totalCalories * pct / 100) / caloriesPerGram`. This allows easy goal editing without recalculating when calorie target changes.

5. **Navigation within Vitals tab**
   All diet routes (`diet`, `add_food/{mealTypeDb}`, `food_search/{mealTypeDb}`) are added as sub-routes in the inner NavHost in `MainScreen.kt`, keeping them within the Vitals tab stack (no dedicated Diet tab).

6. **`food_items` limit**
   The Supabase Kotlin SDK in this project does not expose a `limit()` function in the select filter DSL. Food items are fetched up to Supabase's server-side default limit (~1000). The local cache is keyed as `"diet_food_cache"` in SharedPreferences.

---

## UI Components

### DietCalendarStrip
7-day strip centered on today (`-3..+3` days). Green filled circle for the selected day. Scrolls to show the current week context. Different from the Medications DateStrip which starts from today and scrolls forward.

### CalorieProgressRing
Custom Canvas-drawn circular arc with `drawArc`. Progress fill animates with `animateFloatAsState`. Color: `DietGreen` (`#34C759`) — matching iOS system green for diet. Displays consumed / goal calories at center.

### MacroBreakdownCard
Three `LinearProgressIndicator` rows (Protein / Carbs / Fat) with animated progress via `animateFloatAsState`. Shows consumed vs. goal in grams with colored progress bars (blue / orange / red).

### MealSectionCard
Collapsible card per `MealType`. Shows meal icon (Material icon), meal name + typical time, calorie subtotal. Expanded state shows `FoodEntryRow` per logged item plus an "Add Food" row. The expand/collapse animation uses `AnimatedVisibility`.

### FoodQuantitySheet
`ModalBottomSheet` (`skipPartiallyExpanded = true`) showing: food emoji icon in colored box, food name/brand, +/- quantity stepper (0.25 increments), real-time nutrition preview (Cal / Protein / Carbs / Fat pills), green "Log Food" button.

### AddFoodScreen Discovery Hub
Four discovery sections when search is empty:
1. **Recent Foods** — horizontal chip row from last 10 unique logged foods
2. **Favorite Foods** — horizontal chip row of starred foods (pink/red icon)
3. **Category Grid** — 3-column `LazyVerticalGrid` of 9 `FoodCategory` icons (Grains, Proteins, Dairy, Fruits, Vegetables, Snacks, Beverages, Sweets, Other)
4. **Custom Food Entry** — `AlertDialog` with Name/Calories/Protein/Carbs/Fat fields

---

## Data Models

### Key Enums

| Enum | Values |
|------|--------|
| `MealType` | `BREAKFAST`, `MORNING_SNACK`, `LUNCH`, `EVENING_SNACK`, `DINNER`, `LATE_NIGHT` |
| `FoodCategory` | `GRAINS`, `PROTEINS`, `DAIRY`, `FRUITS`, `VEGETABLES`, `SNACKS`, `BEVERAGES`, `SWEETS`, `OTHER` |
| `ServingUnit` | `G`, `ML`, `OZ`, `CUP`, `TBSP`, `TSP`, `PIECE`, `SLICE`, `SERVING` |

### SharedPreferences Keys

| Key | Value |
|-----|-------|
| `diet_food_cache` | JSON `List<FoodItem>` |
| `diet_logs` | JSON `List<DietLogEntry>` |
| `diet_goals` | JSON `DietGoals` |
| `diet_favorite_ids` | `StringSet` of food item IDs |

---

## Supabase Tables Used

| Table | Operations |
|-------|-----------|
| `food_items` | SELECT (public, no filter) — cached locally after first fetch |
| `diet_logs` | UPSERT (sync local logs), DELETE (remove log) |

Logs filter by `health_profile_id` on upsert. `food_items` has no auth requirement.

---

## Accent Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `DietGreen` | `#34C759` | Progress ring, calendar selection, Add button, category icons |
| `DietOrange` | `#FF9500` | Carbs progress bar, warning states |
| `DietBlue` | `#007AFF` | Protein progress bar |
| `DietBrandBlue` | `#2E3192` | Brand accent (same as Medications) |

---

## Testing Checklist

- [ ] `./gradlew assembleDebug` — 0 errors
- [ ] Home screen "Diet Chart" card taps → navigates to `DietScreen`
- [ ] `DietCalendarStrip` shows today centered with 3 days on each side
- [ ] Calorie progress ring fills proportionally and animates
- [ ] Macro breakdown bars show correct protein/carbs/fat values
- [ ] Meal sections collapse/expand with `AnimatedVisibility`
- [ ] "Add Food" in a meal section → opens `AddFoodScreen` for that meal type
- [ ] `AddFoodScreen` shows recent foods, favorites, category grid when search is empty
- [ ] Typing in search field filters food items from cache
- [ ] Tapping a food item → `FoodQuantitySheet` opens
- [ ] Stepper increments/decrements quantity, nutrition pills update in real-time
- [ ] "Log Food" → food added to meal section, calorie ring updates
- [ ] `FoodSearchScreen` category filter chips filter results
- [ ] Favorite toggle stars/unstars food items, persists across restarts
- [ ] Custom food dialog creates a new `FoodItem` and logs it immediately
- [ ] Kill/relaunch → cached food items and diet logs load instantly
- [ ] Background sync sends unsynced logs to Supabase `diet_logs` table
- [ ] Supabase dashboard shows `diet_logs` rows with correct `health_profile_id` and `meal_type`
