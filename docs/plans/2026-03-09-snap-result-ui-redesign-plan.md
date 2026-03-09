# Snap Result UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the plain-form `ReviewForm` composable in `FoodSnapScreen.kt` with a visually crafted hero-photo + floating-sheet layout with macro pills, inline editing, a serving stepper, and meal type chips.

**Architecture:** Single-file change. All new composables are private functions inside `FoodSnapScreen.kt`. No new ViewModel state, no new models, no navigation changes — only the presentation layer changes.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, Coil (`AsyncImage`), existing `AppColors` / `SnapGreen` / `MealType` / `ServingUnit` models.

---

## Task 1: Add required imports and update ReviewForm signature

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

**Step 1: Add missing imports at top of file**

The new composables need these additions to the existing import block:

```kotlin
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
```

**Step 2: Add a `dailyCalorieGoal` parameter to `ReviewForm`**

The calorie progress bar needs the daily goal. Change the function signature from:

```kotlin
private fun ReviewForm(
    food: FoodItem,
    imageUri: String?,
    autoMealType: MealType,
    onRetake: () -> Unit,
    onLogMeal: (FoodItem, Double, MealType) -> Unit,
    onDismiss: () -> Unit
)
```

to:

```kotlin
private fun ReviewForm(
    food: FoodItem,
    imageUri: String?,
    autoMealType: MealType,
    dailyCalorieGoal: Int,
    onRetake: () -> Unit,
    onLogMeal: (FoodItem, Double, MealType) -> Unit,
    onDismiss: () -> Unit
)
```

**Step 3: Update the call site in `FoodSnapScreen` to pass `dailyCalorieGoal`**

In the `SnapAnalysisState.Result` branch (around line 168), change:

```kotlin
ReviewForm(
    food = snapState.food.toFoodItem(),
    imageUri = uiState.snapImageUri,
    autoMealType = autoMealType,
    onRetake = { ... },
    onLogMeal = { ... },
    onDismiss = onDismiss
)
```

to:

```kotlin
ReviewForm(
    food = snapState.food.toFoodItem(),
    imageUri = uiState.snapImageUri,
    autoMealType = autoMealType,
    dailyCalorieGoal = uiState.dietGoals.dailyCalories.takeIf { it > 0 } ?: 2000,
    onRetake = { ... },
    onLogMeal = { ... },
    onDismiss = onDismiss
)
```

**Step 4: Build to confirm no compile errors**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: BUILD SUCCESSFUL

---

## Task 2: Replace ReviewForm body with new layout scaffold

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

Delete everything inside the `ReviewForm` function body (from the `val isDark = ...` line to the closing `}`). Replace it with this scaffold:

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReviewForm(
    food: FoodItem,
    imageUri: String?,
    autoMealType: MealType,
    dailyCalorieGoal: Int,
    onRetake: () -> Unit,
    onLogMeal: (FoodItem, Double, MealType) -> Unit,
    onDismiss: () -> Unit
) {
    // Editable state — pre-filled from AI result
    var foodName by remember { mutableStateOf(food.name) }
    var calories by remember { mutableStateOf(food.calories.toInt().toString()) }
    var proteinG by remember { mutableStateOf(food.proteinG.toInt().toString()) }
    var carbsG by remember { mutableStateOf(food.carbsG.toInt().toString()) }
    var fatG by remember { mutableStateOf(food.fatG.toInt().toString()) }
    var servingSize by remember { mutableStateOf(food.servingSize) }
    var selectedUnit by remember { mutableStateOf(food.servingUnitEnum) }
    var selectedMealType by remember { mutableStateOf(autoMealType) }
    var isLogging by remember { mutableStateOf(false) }

    // Which macro is being edited (null = none)
    var editingMacro by remember { mutableStateOf<String?>(null) }

    val isValid = foodName.isNotBlank() && calories.toDoubleOrNull() != null

    val calorieProgress = remember(calories, dailyCalorieGoal) {
        (calories.toFloatOrNull() ?: 0f) / dailyCalorieGoal.coerceAtLeast(1)
    }.coerceIn(0f, 1f)

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Hero photo section (45% of screen height)
            HeroPhotoHeader(
                imageUri = imageUri,
                foodName = foodName,
                onFoodNameChange = { foodName = it },
                onBack = onDismiss,
                onRetake = onRetake,
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.45f)
            )

            // Data sheet
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        color = MaterialTheme.colorScheme.surface,
                        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
                    )
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 24.dp, bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                CalorieSummarySection(
                    calories = calories.toIntOrNull() ?: 0,
                    progress = calorieProgress,
                    dailyGoal = dailyCalorieGoal
                )

                MacroPillsRow(
                    proteinG = proteinG,
                    carbsG = carbsG,
                    fatG = fatG,
                    onEditProtein = { editingMacro = "protein" },
                    onEditCarbs   = { editingMacro = "carbs" },
                    onEditFat     = { editingMacro = "fat" }
                )

                ServingRow(
                    servingSize = servingSize,
                    selectedUnit = selectedUnit,
                    onServingChange = { servingSize = it },
                    onUnitChange = { selectedUnit = it }
                )

                MealTypeChips(
                    selected = selectedMealType,
                    onSelect = { selectedMealType = it }
                )

                // Log Meal button
                Button(
                    onClick = {
                        if (!isValid || isLogging) return@Button
                        isLogging = true
                        val logged = FoodItem(
                            name = foodName.trim(),
                            servingSize = servingSize,
                            servingUnit = selectedUnit.dbValue,
                            calories = calories.toDoubleOrNull() ?: food.calories,
                            proteinG = proteinG.toDoubleOrNull() ?: food.proteinG,
                            carbsG = carbsG.toDoubleOrNull() ?: food.carbsG,
                            fatG = fatG.toDoubleOrNull() ?: food.fatG,
                            fiberG = food.fiberG,
                            category = food.category
                        )
                        onLogMeal(logged, servingSize, selectedMealType)
                    },
                    enabled = isValid && !isLogging,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SnapGreen),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    if (isLogging) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(22.dp),
                            strokeWidth = 2.5.dp
                        )
                    } else {
                        Text(
                            "Log Meal",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }

        // Macro edit dialog (rendered on top)
        if (editingMacro != null) {
            val currentValue = when (editingMacro) {
                "protein" -> proteinG
                "carbs"   -> carbsG
                else      -> fatG
            }
            val label = when (editingMacro) {
                "protein" -> "Protein (g)"
                "carbs"   -> "Carbs (g)"
                else      -> "Fat (g)"
            }
            MacroEditDialog(
                label = label,
                currentValue = currentValue,
                onConfirm = { newVal ->
                    when (editingMacro) {
                        "protein" -> proteinG = newVal
                        "carbs"   -> carbsG = newVal
                        else      -> fatG = newVal
                    }
                    editingMacro = null
                },
                onDismiss = { editingMacro = null }
            )
        }
    }
}
```

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: errors for missing private composables — that is expected, proceed to next tasks.

---

## Task 3: Implement HeroPhotoHeader

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

Add this private composable after the `PickerSheetContent` function:

```kotlin
@Composable
private fun HeroPhotoHeader(
    imageUri: String?,
    foodName: String,
    onFoodNameChange: (String) -> Unit,
    onBack: () -> Unit,
    onRetake: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        // Full-bleed photo
        if (imageUri != null) {
            AsyncImage(
                model = imageUri,
                contentDescription = "Food photo",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF1C1C1E))
            )
        }

        // Bottom gradient overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.25f),
                            Color.Black.copy(alpha = 0.75f)
                        ),
                        startY = 0f
                    )
                )
        )

        // Top bar (back + retake)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    tint = Color.White
                )
            }
            IconButton(onClick = onRetake) {
                Icon(
                    Icons.Default.CameraAlt,
                    contentDescription = "Retake",
                    tint = Color.White
                )
            }
        }

        // Food name + AI badge at bottom of hero
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // AI detected badge
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = Color.White.copy(alpha = 0.18f),
                tonalElevation = 0.dp
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(13.dp)
                    )
                    Text(
                        "AI detected",
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // Editable food name
            BasicTextField(
                value = foodName,
                onValueChange = onFoodNameChange,
                textStyle = TextStyle(
                    color = Color.White,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold
                ),
                cursorBrush = SolidColor(Color.White),
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
```

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: errors reduced — `CalorieSummarySection`, `MacroPillsRow`, `ServingRow`, `MealTypeChips`, `MacroEditDialog` still missing.

---

## Task 4: Implement CalorieSummarySection

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

Add after `HeroPhotoHeader`:

```kotlin
@Composable
private fun CalorieSummarySection(
    calories: Int,
    progress: Float,
    dailyGoal: Int
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = calories.toString(),
                fontSize = 52.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                lineHeight = 52.sp
            )
            Text(
                text = "kcal",
                fontSize = 16.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = SnapGreen,
                trackColor = AppColors.onSurface.copy(alpha = 0.1f)
            )
            Text(
                text = "${(progress * 100).toInt()}% of daily goal ($dailyGoal kcal)",
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.45f),
                modifier = Modifier.align(Alignment.End)
            )
        }
    }
}
```

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

---

## Task 5: Implement MacroPillsRow and MacroEditDialog

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

Add after `CalorieSummarySection`:

```kotlin
private val MacroProteinColor = Color(0xFF4CAF50)
private val MacroCarbsColor   = Color(0xFFFF9800)
private val MacroFatColor     = Color(0xFFFFD600)

@Composable
private fun MacroPillsRow(
    proteinG: String,
    carbsG: String,
    fatG: String,
    onEditProtein: () -> Unit,
    onEditCarbs: () -> Unit,
    onEditFat: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        MacroPill(
            label = "Protein",
            value = proteinG,
            accentColor = MacroProteinColor,
            cardBg = cardBg,
            onClick = onEditProtein,
            modifier = Modifier.weight(1f)
        )
        MacroPill(
            label = "Carbs",
            value = carbsG,
            accentColor = MacroCarbsColor,
            cardBg = cardBg,
            onClick = onEditCarbs,
            modifier = Modifier.weight(1f)
        )
        MacroPill(
            label = "Fat",
            value = fatG,
            accentColor = MacroFatColor,
            cardBg = cardBg,
            onClick = onEditFat,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun MacroPill(
    label: String,
    value: String,
    accentColor: Color,
    cardBg: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = cardBg),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column {
            // Colored top accent
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .background(
                        accentColor,
                        shape = RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp)
                    )
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = "${value}g",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Text(
                    text = label,
                    fontSize = 12.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
            }
        }
    }
}

@Composable
private fun MacroEditDialog(
    label: String,
    currentValue: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var text by remember { mutableStateOf(currentValue) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(label, fontWeight = FontWeight.SemiBold) },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                singleLine = true,
                suffix = { Text("g") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SnapGreen,
                    focusedLabelColor = SnapGreen
                )
            )
        },
        confirmButton = {
            TextButton(onClick = { if (text.toDoubleOrNull() != null) onConfirm(text) }) {
                Text("Done", color = SnapGreen, fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = AppColors.onSurface.copy(alpha = 0.5f))
            }
        }
    )
}
```

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

---

## Task 6: Implement ServingRow

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

Add after `MacroEditDialog`:

```kotlin
@Composable
private fun ServingRow(
    servingSize: Double,
    selectedUnit: ServingUnit,
    onServingChange: (Double) -> Unit,
    onUnitChange: (ServingUnit) -> Unit
) {
    var showUnitDropdown by remember { mutableStateOf(false) }
    val isDark = isSystemInDarkTheme()
    val chipBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            "Serving",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onSurface
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            // Stepper
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier
                    .background(chipBg, RoundedCornerShape(12.dp))
                    .padding(horizontal = 4.dp, vertical = 2.dp)
            ) {
                IconButton(
                    onClick = { onServingChange((servingSize - 0.5).coerceAtLeast(0.5)) },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Remove,
                        contentDescription = "Decrease",
                        tint = AppColors.onSurface,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    text = if (servingSize % 1.0 == 0.0) servingSize.toInt().toString()
                           else servingSize.toString(),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface,
                    modifier = Modifier.widthIn(min = 32.dp),
                    textAlign = TextAlign.Center
                )
                IconButton(
                    onClick = { onServingChange(servingSize + 0.5) },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = "Increase",
                        tint = AppColors.onSurface,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            Spacer(Modifier.width(8.dp))

            // Unit chip
            Box {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = chipBg,
                    modifier = Modifier.clickableNoRipple { showUnitDropdown = true }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            selectedUnit.displayName,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = AppColors.onSurface
                        )
                        Icon(
                            Icons.Default.ArrowDropDown,
                            contentDescription = null,
                            tint = AppColors.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
                DropdownMenu(
                    expanded = showUnitDropdown,
                    onDismissRequest = { showUnitDropdown = false }
                ) {
                    ServingUnit.values().forEach { unit ->
                        DropdownMenuItem(
                            text = { Text(unit.displayName) },
                            onClick = {
                                onUnitChange(unit)
                                showUnitDropdown = false
                            }
                        )
                    }
                }
            }
        }
    }
}
```

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

---

## Task 7: Implement MealTypeChips

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt`

Add after `ServingRow`:

```kotlin
@Composable
private fun MealTypeChips(
    selected: MealType,
    onSelect: (MealType) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "Meal",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(MealType.values()) { mealType ->
                val isSelected = mealType == selected
                FilterChip(
                    selected = isSelected,
                    onClick = { onSelect(mealType) },
                    label = {
                        Text(
                            mealType.displayName,
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                        )
                    },
                    leadingIcon = {
                        Icon(
                            mealType.iconVector(),
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                    },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = SnapGreen,
                        selectedLabelColor = Color.White,
                        selectedLeadingIconColor = Color.White,
                        iconColor = mealType.accentColor()
                    ),
                    border = FilterChipDefaults.filterChipBorder(
                        enabled = true,
                        selected = isSelected,
                        borderColor = AppColors.onSurface.copy(alpha = 0.15f),
                        selectedBorderColor = Color.Transparent
                    )
                )
            }
        }
    }
}
```

**Step 2: Final build — all composables should now be resolved**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -30
```
Expected: BUILD SUCCESSFUL with no errors.

**Step 3: Commit**

```bash
cd android && git add app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/FoodSnapScreen.kt
git commit -m "feat(android/diet): redesign snap result UI with hero photo + macro pills"
```

---

## Notes

- `MealType.values()` — if this produces a deprecation warning in newer Kotlin, replace with `MealType.entries.toTypedArray()`.
- `LinearProgressIndicator` with lambda `progress = { progress }` requires Material3 1.2+; if compile fails use `progress = progress` (without lambda).
- `Icons.Default.AutoAwesome` requires `material-icons-extended` dependency. If unavailable, replace with `Icons.Default.Star`.
- `statusBarsPadding()` requires `androidx.compose.foundation.layout.WindowInsets` — already available in Compose 1.2+.
- The `clickableNoRipple` extension already exists at the bottom of `FoodSnapScreen.kt` — do not add a duplicate.
