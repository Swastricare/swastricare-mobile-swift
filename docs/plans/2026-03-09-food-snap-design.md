# Food Snap Feature Design

## Overview

A food photo recognition feature (similar to HealthifyMe's Snap) that lets users photograph their meal, auto-detect food items with nutritional info via the existing AI router, and log them with one tap.

## Decisions

- **Entry points**: Camera FAB on Diet screen + button inside AddFoodScreen
- **Image source**: Camera + gallery picker
- **UX flow**: Auto-fill and confirm (AI pre-fills name/calories/macros, user reviews and taps Log)
- **Backend**: Reuse existing `ai-router` edge function with `imageData` field (routes to Gemini vision)
- **Platform**: Android only (for now)

## User Flow

```
User taps Snap FAB (Diet screen) or Snap button (AddFoodScreen)
  -> Bottom sheet: "Take Photo" / "Choose from Gallery"
  -> Image captured/selected
  -> Image compressed to ~800px width, converted to base64
  -> Sent to ai-router with food-analysis prompt
  -> Loading overlay: "Analyzing your meal..."
  -> AI returns structured text with food name + macros
  -> SnapResultScreen: pre-filled food name, calories, protein, carbs, fat
  -> User can edit any field, pick meal type, adjust serving
  -> User taps "Log Meal"
  -> DietLogEntry created via existing DietViewModel.logFood()
  -> Return to Diet screen with updated log
```

## Architecture

### Existing Infrastructure Used

| Component | Location | How It's Used |
|-----------|----------|---------------|
| `AIService` | `data/services/AIService.kt` | New `analyzeFoodImage(base64)` method |
| `ChatRequest` | `data/models/AIModels.kt` | Add optional `imageData` field |
| `ai-router` edge function | `supabase/functions/ai-router/index.ts` | Already routes `imageData` to vision model |
| `DietViewModel` | `ui/screens/diet/DietViewModel.kt` | New snap state + `analyzeFood()` method |
| `DietLogEntry` / `FoodItem` | `data/models/DietModels.kt` | Reused as-is for logging |

### New Components

| Component | Location | Role |
|-----------|----------|------|
| `SnapFoodResult` | `data/models/DietModels.kt` | Parsed AI response (name, calories, macros) |
| `FoodSnapScreen` | `ui/screens/diet/FoodSnapScreen.kt` | Camera/gallery picker + result review + confirm |
| Image compression util | `data/services/ImageUtils.kt` | Compress + base64 encode food photo |

### AI Prompt Strategy

Send to `ai-router` with `imageData` (triggers vision model routing) and a structured prompt:

```
Identify the food items in this image. This is likely Indian cuisine.
Respond ONLY with this exact format for each food item detected:

FOOD: <name>
CALORIES: <number>
PROTEIN: <grams>
CARBS: <grams>
FAT: <grams>
FIBER: <grams>
SERVING_SIZE: <number>
SERVING_UNIT: <unit>
CATEGORY: <fruits|vegetables|grains|protein|dairy|beverages|snacks|sweets|other>
```

The response is parsed on the Android side into a `SnapFoodResult` model. If parsing fails, the raw response is shown with a fallback to manual entry.

### Data Flow

```
FoodSnapScreen (camera/gallery)
  -> ImageUtils.compressAndEncode(uri) -> base64 string
  -> DietViewModel.analyzeFood(base64)
    -> AIService.analyzeFoodImage(base64, prompt)
      -> ai-router (imageData present -> routes to vision model)
      -> returns text response
    -> parse into SnapFoodResult
    -> update UI state with result
  -> User reviews/edits fields
  -> User taps Log
  -> DietViewModel.logFood(entry) (existing method)
```

### ChatRequest Change

```kotlin
// Current
data class ChatRequest(
    val message: String,
    val conversationHistory: List<ContextMessage>
)

// Updated - add optional imageData
data class ChatRequest(
    val message: String,
    val conversationHistory: List<ContextMessage>,
    val imageData: String? = null  // base64 encoded image
)
```

### SnapFoodResult Model

```kotlin
data class SnapFoodResult(
    val name: String,
    val calories: Double,
    val proteinG: Double,
    val carbsG: Double,
    val fatG: Double,
    val fiberG: Double,
    val servingSize: Double,
    val servingUnit: String,
    val category: String
)
```

## UI Design

### Diet Screen FAB
- Camera icon, bottom-right, above bottom nav
- Material3 FloatingActionButton with AppColors.accentBlue

### FoodSnapScreen
- Top: captured food photo thumbnail
- Middle: pre-filled editable fields (name, calories, protein, carbs, fat, serving size, serving unit)
- Meal type dropdown (auto-detected from time of day)
- Bottom: "Log Meal" primary button + "Retake Photo" text button
- Error state: "Try Again" or "Enter Manually" options
- Loading state: shimmer/skeleton over the fields

## Error Handling

- AI fails to respond: show error with "Try Again" / "Enter Manually" buttons
- AI response can't be parsed: show raw AI text + "Enter Manually" fallback
- No camera permission: prompt for permission
- Image too large: compress before sending (800px max width)

## Navigation

New route in diet navigation:
- `diet/snap` -> FoodSnapScreen (with meal type param)
