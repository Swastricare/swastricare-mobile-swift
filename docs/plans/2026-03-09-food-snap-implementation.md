# Food Snap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a food photo recognition feature that lets users snap a meal photo, auto-detect food items via the existing AI router, and log them with one tap.

**Architecture:** Reuse existing `ai-router` edge function (already routes images to Gemini vision). Add `imageData` support to `ChatRequest`, a new `analyzeFoodImage()` method to `AIService`, snap-related state to `DietViewModel`, a `FoodSnapScreen` for the review/confirm UI, and an `ImageUtils` helper for compression. Entry points are a FAB on DietScreen and a button on AddFoodScreen.

**Tech Stack:** Kotlin, Jetpack Compose, Supabase Edge Functions (existing), CameraX / ActivityResultContracts for image capture.

---

### Task 1: Add `imageData` to ChatRequest and `SnapFoodResult` model

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/AIModels.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/DietModels.kt`

**Step 1: Add `imageData` field to `ChatRequest`**

In `AIModels.kt`, add the optional field:

```kotlin
@Serializable
data class ChatRequest(
    val message: String,
    val conversationHistory: List<ContextMessage>,
    val imageData: String? = null
)
```

**Step 2: Add `SnapFoodResult` to `DietModels.kt`**

Append at the end of the file:

```kotlin
// ─────────────────────────────────────
// MARK: - Food Snap Result
// ─────────────────────────────────────

data class SnapFoodResult(
    val name: String,
    val calories: Double,
    val proteinG: Double,
    val carbsG: Double,
    val fatG: Double,
    val fiberG: Double = 0.0,
    val servingSize: Double = 1.0,
    val servingUnit: String = "piece",
    val category: String = "other"
) {
    fun toFoodItem(): FoodItem = FoodItem(
        name = name,
        servingSize = servingSize,
        servingUnit = servingUnit,
        calories = calories,
        proteinG = proteinG,
        carbsG = carbsG,
        fatG = fatG,
        fiberG = fiberG,
        category = category
    )
}
```

**Step 3: Build to verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/models/AIModels.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/data/models/DietModels.kt
git commit -m "feat(android): add imageData to ChatRequest and SnapFoodResult model"
```

---

### Task 2: Add `analyzeFoodImage()` to AIService

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AIService.kt`

**Step 1: Add the food analysis method**

Add this method to the `AIService` class:

```kotlin
suspend fun analyzeFoodImage(imageBase64: String): SnapFoodResult {
    val prompt = buildString {
        appendLine("Identify the food in this image. This is likely Indian cuisine.")
        appendLine("Respond ONLY with this exact format:")
        appendLine()
        appendLine("FOOD: <name>")
        appendLine("CALORIES: <number>")
        appendLine("PROTEIN: <grams as number>")
        appendLine("CARBS: <grams as number>")
        appendLine("FAT: <grams as number>")
        appendLine("FIBER: <grams as number>")
        appendLine("SERVING_SIZE: <number>")
        appendLine("SERVING_UNIT: <unit like piece, bowl, plate, cup, g>")
        appendLine("CATEGORY: <fruits|vegetables|grains|protein|dairy|beverages|snacks|sweets|other>")
    }

    val request = ChatRequest(
        message = prompt,
        conversationHistory = emptyList(),
        imageData = imageBase64
    )

    val response = client.functions.invoke(
        function = "ai-router",
        body = request
    )
    val body = response.body<String>()
    val responseText = json.decodeFromString<ChatResponse>(body).response
    return parseFoodSnapResponse(responseText)
}

private fun parseFoodSnapResponse(text: String): SnapFoodResult {
    fun extractValue(key: String): String? {
        val regex = Regex("$key:\\s*(.+)", RegexOption.IGNORE_CASE)
        return regex.find(text)?.groupValues?.get(1)?.trim()
    }

    return SnapFoodResult(
        name = extractValue("FOOD") ?: "Unknown Food",
        calories = extractValue("CALORIES")?.toDoubleOrNull() ?: 0.0,
        proteinG = extractValue("PROTEIN")?.toDoubleOrNull() ?: 0.0,
        carbsG = extractValue("CARBS")?.toDoubleOrNull() ?: 0.0,
        fatG = extractValue("FAT")?.toDoubleOrNull() ?: 0.0,
        fiberG = extractValue("FIBER")?.toDoubleOrNull() ?: 0.0,
        servingSize = extractValue("SERVING_SIZE")?.toDoubleOrNull() ?: 1.0,
        servingUnit = extractValue("SERVING_UNIT") ?: "piece",
        category = extractValue("CATEGORY") ?: "other"
    )
}
```

Add the import at top of file:
```kotlin
import com.swasthicare.mobile.data.models.SnapFoodResult
```

**Step 2: Build to verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AIService.kt
git commit -m "feat(android): add analyzeFoodImage method to AIService"
```

---

### Task 3: Create ImageUtils for compression and base64 encoding

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/ImageUtils.kt`

**Step 1: Create the utility**

```kotlin
package com.swasthicare.mobile.data.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream

object ImageUtils {

    /**
     * Read image from URI, compress to max 800px width, and return base64 string.
     */
    fun compressAndEncode(context: Context, uri: Uri, maxWidth: Int = 800): String? {
        return try {
            val inputStream = context.contentResolver.openInputStream(uri) ?: return null
            val original = BitmapFactory.decodeStream(inputStream)
            inputStream.close()

            val scaled = if (original.width > maxWidth) {
                val ratio = maxWidth.toFloat() / original.width
                val newHeight = (original.height * ratio).toInt()
                Bitmap.createScaledBitmap(original, maxWidth, newHeight, true).also {
                    if (it !== original) original.recycle()
                }
            } else {
                original
            }

            val outputStream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
            val bytes = outputStream.toByteArray()
            scaled.recycle()

            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }
}
```

**Step 2: Build to verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/ImageUtils.kt
git commit -m "feat(android): add ImageUtils for food photo compression and base64 encoding"
```

---

### Task 4: Add snap state and `analyzeFood()` to DietViewModel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietViewModel.kt`

**Step 1: Add snap state fields to `DietUiState`**

Add these fields to the `DietUiState` data class:

```kotlin
val snapState: SnapAnalysisState = SnapAnalysisState.Idle,
val snapImageUri: String? = null
```

Add the sealed class above or below `DietUiState`:

```kotlin
sealed class SnapAnalysisState {
    object Idle : SnapAnalysisState()
    object Analyzing : SnapAnalysisState()
    data class Result(val food: SnapFoodResult) : SnapAnalysisState()
    data class Error(val message: String) : SnapAnalysisState()
}
```

**Step 2: Add `analyzeFood()` method to `DietViewModel`**

Add `AIService` as a parameter (or get from AppContainer):

```kotlin
private val aiService = AIService(com.swasthicare.mobile.di.AppContainer.supabaseClient)
```

Add the method:

```kotlin
fun analyzeFood(context: android.content.Context, imageUri: android.net.Uri) {
    viewModelScope.launch {
        _uiState.value = _uiState.value.copy(
            snapState = SnapAnalysisState.Analyzing,
            snapImageUri = imageUri.toString()
        )
        try {
            val base64 = ImageUtils.compressAndEncode(context, imageUri)
                ?: throw Exception("Failed to process image")
            val result = aiService.analyzeFoodImage(base64)
            _uiState.value = _uiState.value.copy(
                snapState = SnapAnalysisState.Result(result)
            )
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                snapState = SnapAnalysisState.Error(e.message ?: "Analysis failed")
            )
        }
    }
}

fun clearSnapState() {
    _uiState.value = _uiState.value.copy(
        snapState = SnapAnalysisState.Idle,
        snapImageUri = null
    )
}
```

Add imports at top:
```kotlin
import com.swasthicare.mobile.data.models.SnapFoodResult
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.ImageUtils
```

**Step 3: Build to verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietViewModel.kt
git commit -m "feat(android): add food snap analysis state and method to DietViewModel"
```

---

### Task 5: Create FoodSnapScreen UI

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

**Step 1: Create the screen**

This screen shows:
1. The captured food photo at the top
2. Pre-filled editable fields for name, calories, protein, carbs, fat
3. Meal type dropdown (auto-detected from time of day)
4. "Log Meal" button and "Retake Photo" text button
5. Loading state with shimmer
6. Error state with retry/manual fallback

Key implementation notes:
- Use `AppColors` and `DietGreen` from existing diet screens for consistency
- Use `MealType` enum for the dropdown
- Auto-detect meal type: Morning -> BREAKFAST, Afternoon -> LUNCH, Evening -> DINNER
- On "Log Meal", convert `SnapFoodResult` to `FoodItem` via `toFoodItem()`, then call `vm.logFood(item, quantity, mealType)`
- On "Retake", navigate back to let user pick image again
- On "Enter Manually", navigate to `add_food/{mealType}`

The screen receives `imageUri` and `mealType` as parameters. It observes `DietViewModel.uiState.snapState`.

States:
- `Analyzing` -> full-screen loading overlay with "Analyzing your meal..." text
- `Result` -> show form with pre-filled fields
- `Error` -> show error card with "Try Again" and "Enter Manually" buttons

Form fields (all editable via `OutlinedTextField`):
- Food Name (text)
- Calories (number)
- Protein (number, g)
- Carbs (number, g)
- Fat (number, g)
- Serving Size (number)
- Serving Unit (dropdown: piece, bowl, plate, cup, g)
- Meal Type (dropdown: Breakfast, Lunch, etc.)

**Step 2: Build to verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt
git commit -m "feat(android): add FoodSnapScreen for food photo review and logging"
```

---

### Task 6: Add navigation route and entry points

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/MainNavGraph.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/AddFoodScreen.kt`

**Step 1: Add `food_snap` route to MainNavGraph**

After the `food_search` composable block, add:

```kotlin
composable(
    route = "food_snap/{${NavArgs.MEAL_TYPE}}",
    arguments = listOf(
        navArgument(NavArgs.MEAL_TYPE) {
            type = NavType.StringType
            defaultValue = "breakfast"
        }
    )
) { backStackEntry ->
    val mealTypeDb = backStackEntry.arguments?.getString(NavArgs.MEAL_TYPE) ?: "breakfast"
    FoodSnapScreen(
        mealTypeDb = mealTypeDb,
        onDismiss = { navController.popBackStack() },
        onNavigateToAddFood = { mt -> navController.navigate("add_food/$mt") }
    )
}
```

Add import: `import com.swasthicare.mobile.ui.screens.diet.FoodSnapScreen`

**Step 2: Add `onNavigateToFoodSnap` callback to DietScreen**

Update `DietScreen` composable signature to add:
```kotlin
onNavigateToFoodSnap: (String) -> Unit
```

Add a FAB inside the `Box` at the bottom of DietScreen:

```kotlin
FloatingActionButton(
    onClick = {
        // Auto-detect meal type from time of day
        val hour = java.time.LocalTime.now().hour
        val mealType = when {
            hour < 10 -> MealType.BREAKFAST
            hour < 14 -> MealType.LUNCH
            hour < 17 -> MealType.EVENING_SNACK
            else -> MealType.DINNER
        }
        onNavigateToFoodSnap(mealType.dbValue)
    },
    modifier = Modifier
        .align(Alignment.BottomEnd)
        .padding(end = 16.dp, bottom = 16.dp),
    containerColor = AppColors.accentBlue,
    contentColor = Color.White
) {
    Icon(Icons.Default.CameraAlt, "Snap Food")
}
```

**Step 3: Update MainNavGraph DietScreen call to pass the new callback**

In the `composable("diet")` block, add:
```kotlin
onNavigateToFoodSnap = { mealTypeDb ->
    navController.navigate("food_snap/$mealTypeDb")
}
```

**Step 4: Add Snap button to AddFoodScreen**

In `AddFoodScreen`, add an `onNavigateToFoodSnap` callback parameter and add a "Snap Food" button alongside the existing food search button. This should be a prominent button with a camera icon.

**Step 5: Build to verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/MainNavGraph.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/AddFoodScreen.kt
git commit -m "feat(android): add food snap navigation, FAB on DietScreen, and snap button on AddFoodScreen"
```

---

### Task 7: Add camera/gallery image picker to FoodSnapScreen

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

**Step 1: Add image picker logic**

Use `ActivityResultContracts.TakePicture` for camera and `ActivityResultContracts.GetContent` for gallery. Show a bottom sheet on entry with "Take Photo" and "Choose from Gallery" options.

For camera:
- Create a temp file URI using `FileProvider`
- Launch `TakePicture` contract
- On result, call `vm.analyzeFood(context, uri)`

For gallery:
- Launch `GetContent("image/*")` contract
- On result, call `vm.analyzeFood(context, uri)`

Check `android/app/src/main/AndroidManifest.xml` for existing `FileProvider` — if not present, it needs to be added. Check existing camera usage in the codebase (vault document upload, AI image analysis) for patterns to follow.

**Step 2: Build and test manually**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt
git commit -m "feat(android): add camera and gallery image picker to FoodSnapScreen"
```

---

### Task 8: End-to-end verification

**Step 1: Build the app**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 2: Manual test checklist**

- [ ] Diet screen shows camera FAB in bottom-right
- [ ] Tapping FAB opens FoodSnapScreen with image picker sheet
- [ ] Camera capture works and triggers analysis
- [ ] Gallery pick works and triggers analysis
- [ ] Loading state shows "Analyzing your meal..."
- [ ] AI response populates food name, calories, macros
- [ ] All fields are editable
- [ ] Meal type is auto-detected from time of day
- [ ] "Log Meal" creates a DietLogEntry and returns to Diet screen
- [ ] "Retake Photo" restarts the image picker
- [ ] Error state shows "Try Again" and "Enter Manually" buttons
- [ ] AddFoodScreen has a snap button that navigates to FoodSnapScreen

**Step 3: Final commit**

```bash
git commit -m "feat(android): food snap feature complete - photo-based food logging with AI"
```
