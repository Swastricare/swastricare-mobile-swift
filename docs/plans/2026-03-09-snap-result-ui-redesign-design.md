# Snap Result UI Redesign

## Overview

Replace the current form-dump `ReviewForm` in `FoodSnapScreen.kt` with a visually crafted snap result screen: hero photo at top, floating data sheet below, macro pills, inline editing, and a stepper-based serving control.

## Layout

```
┌────────────────────────────────────┐
│ [←]                      [↩ Retake]│  transparent bar over photo
│                                    │
│         FOOD PHOTO                 │  full-bleed, ~45% screen height
│         (edge to edge, no clip)    │
│                                    │
│  "Masala Dosa"         [✨ AI]     │  gradient overlay; name tap-to-edit
├────────────────────────────────────┤  sheet, rounded top 28dp
│                                    │
│         486  kcal                  │  48sp bold, centered
│  ▓▓▓▓▓▓▓░░░░░░░░░░░░░░  38%       │  6dp thin progress bar, daily budget
│                                    │
│  ┌──────┐  ┌──────┐  ┌──────┐    │
│  │■■■■■ │  │■■■■■ │  │■■■■■ │    │  3dp colored top-accent line
│  │  12g │  │  68g │  │  18g │    │
│  │Protein│  │ Carbs│  │  Fat │    │  tap each → inline number edit
│  └──────┘  └──────┘  └──────┘    │
│                                    │
│  Serving  [−]  [ 1 ]  [+]  [g ▾] │  stepper + unit chip
│                                    │
│  [☀️ Breakfast] [Lunch] [Dinner] [Snack]  │  FilterChip row
│                                    │
│  [         Log Meal         ]      │  full-width, 56dp, SnapGreen
└────────────────────────────────────┘
```

## Components

### HeroPhotoHeader
- `Box` fills `fillMaxWidth` + `fillMaxHeight(0.45f)`
- `AsyncImage` with `ContentScale.Crop`, no clip/border
- `Box` gradient overlay: `Brush.verticalGradient(transparent → Color.Black.copy(0.75f))`
- Food name as `BasicTextField` (24sp bold, white) aligned to bottom-start over gradient
- `✨ AI` pill: small rounded surface with sparkle icon + "AI" text, 12sp
- Back `IconButton` top-start, Retake `IconButton` top-end — both white icons on transparent bg

### CalorieSummarySection
- Calorie number: 48sp `FontWeight.Bold`, centered
- `kcal` label: 14sp muted alongside the number
- `LinearProgressIndicator` styled to 6dp height, rounded, `SnapGreen` color
- Progress = (calories / dailyCalorieGoal).coerceIn(0f, 1f)
- Daily goal falls back to 2000 if not set

### MacroPillsRow
- `Row` with 3 equal-weight `Card`s, `horizontalArrangement = Arrangement.spacedBy(10.dp)`
- Each card:
  - 3dp tall `Box` at top with macro color (protein=#4CAF50, carbs=#FF9800, fat=#FFD600)
  - `16sp FontWeight.Bold` gram value
  - `12sp` label in muted color
  - Entire card is clickable → opens `MacroEditDialog`
- `MacroEditDialog`: `AlertDialog` with a single `OutlinedTextField` (number keyboard), confirm/cancel

### ServingRow
- Label "Serving" 13sp muted
- Stepper: `IconButton(−)` | `Text(value)` | `IconButton(+)` with `+0.5` increments, min 0.5
- Unit chip: `AssistChip` showing current unit, click → `DropdownMenu` with `ServingUnit.values()`

### MealTypeChips
- `LazyRow` of `FilterChip` for each `MealType`
- Selected chip: `containerColor = SnapGreen`, `labelColor = White`
- Each chip has `leadingIcon` from `mealType.iconVector()`

### LogMealButton
- `Button`, `fillMaxWidth`, 56dp height, `SnapGreen`, 16dp rounded
- Shows `CircularProgressIndicator` when `isLogging`

## Inline Food Name Editing
- `BasicTextField` styled with `TextStyle(fontSize=24.sp, fontWeight=Bold, color=White)`
- `decorationBox` renders just the text with a blinking cursor — no border, no background
- Cursor color set to white via `cursorBrush = SolidColor(Color.White)`

## State
All existing state in `ReviewForm` is kept (foodName, calories, proteinG, carbsG, fatG, servingSize, selectedUnit, selectedMealType). No new ViewModel state is needed — all local to the composable.

## Files Changed
- `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`
  - Replace `ReviewForm` composable entirely
  - Add: `HeroPhotoHeader`, `CalorieSummarySection`, `MacroPillsRow`, `MacroEditDialog`, `ServingRow`, `MealTypeChips` private composables

## No changes needed
- `DietViewModel` — no new state
- `DietModels` — no new models
- `AppNavigation` — no new routes
