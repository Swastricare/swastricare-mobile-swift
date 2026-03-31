# Hydration Screen Redesign — Android

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Android HydrationScreen to match the reference pattern: full blue gradient, greeting header, circular progress hero with swipeable insight page, white bottom card for entries, and FAB-triggered add sheet — preserving all existing ViewModel logic.

**Architecture:** HydrationScreen gets a new two-zone layout (gradient hero zone + white bottom card). HydrationComponents gains new composables (hero ring, hero pager, add-drink bottom sheet) while keeping all existing ones. HydrationUiState gains a `userName` field loaded from `authRepository`.

**Tech Stack:** Jetpack Compose, Material3, `androidx.compose.foundation.pager.HorizontalPager`, Canvas for arc ring, existing Hilt ViewModel/Repository stack.

---

### Task 1: Add `userName` to HydrationUiState and load it in ViewModel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationViewModel.kt`

**Step 1: Add `userName` field to `HydrationUiState`**

In `HydrationUiState` data class (around line 31), add one field:

```kotlin
data class HydrationUiState(
    val userName: String = "",          // ← add this line
    val entries: List<HydrationEntry> = emptyList(),
    // ... rest unchanged
)
```

**Step 2: Load userName in `loadData()`**

At the top of the `viewModelScope.launch` block in `loadData()` (before `val localEntries = ...`), add:

```kotlin
val currentUser = authRepository.getCurrentUser()
val resolvedName = currentUser?.fullName
    ?: currentUser?.email?.substringBefore("@")
    ?: ""
_uiState.value = _uiState.value.copy(userName = resolvedName)
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationViewModel.kt
git commit -m "feat(hydration): add userName to HydrationUiState"
```

---

### Task 2: Add HydrationHeroRing composable to HydrationComponents.kt

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt`

Add this composable after the existing `HydrationProgressRing` (around line 833). This replaces the water glass as the hero element.

**Step 1: Add the composable**

```kotlin
// ─────────────────────────────────────
// MARK: - HydrationHeroRing
// ─────────────────────────────────────

@Composable
fun HydrationHeroRing(
    intakeMl: Int,
    goalMl: Int,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 900, easing = FastOutSlowInEasing),
        label = "heroRing"
    )
    val ringColor = when {
        progress >= 1f -> Color(0xFF34C759)
        progress >= 0.7f -> Color(0xFF64D2FF)
        else -> Color.White
    }
    val percent = (progress * 100).toInt().coerceIn(0, 100)

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeWidth = 14.dp.toPx()
            val diameter = size.minDimension - strokeWidth * 2
            val topLeft = Offset(
                (size.width - diameter) / 2f,
                (size.height - diameter) / 2f
            )
            val arcSize = Size(diameter, diameter)
            // Track
            drawArc(
                color = Color.White.copy(alpha = 0.2f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
            // Progress arc
            drawArc(
                color = ringColor,
                startAngle = -90f,
                sweepAngle = 360f * animatedProgress,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
        }
        // Center content
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text("💧", fontSize = 28.sp)
            Text(
                text = "${intakeMl}ml",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = "of ${goalMl}ml",
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.75f)
            )
            Spacer(Modifier.height(2.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color.White.copy(alpha = 0.2f))
                    .padding(horizontal = 10.dp, vertical = 3.dp)
            ) {
                Text(
                    text = "$percent%",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt
git commit -m "feat(hydration): add HydrationHeroRing composable"
```

---

### Task 3: Add HydrationHeroPager (ring + insights slide)

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt`

Add the following imports at the top of the file (alongside existing imports):

```kotlin
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.ExperimentalFoundationApi
```

Then add this composable after `HydrationHeroRing`:

**Step 1: Add HydrationHeroPager**

```kotlin
// ─────────────────────────────────────
// MARK: - HydrationHeroPager
// ─────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HydrationHeroPager(
    uiState: HydrationUiState,
    modifier: Modifier = Modifier
) {
    val pageCount = if (uiState.insights != null) 2 else 1
    val pagerState = rememberPagerState(pageCount = { pageCount })

    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
        ) { page ->
            when (page) {
                0 -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        // Motivational subtitle
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            val subtitle = when {
                                uiState.isGoalMet -> "Goal reached! Great job 🎉"
                                uiState.progress >= 0.7f -> "Almost there, keep going!"
                                uiState.todaysEntries.isEmpty() -> "Start hydrating today"
                                else -> "Stay hydrated, keep going"
                            }
                            Text(
                                text = subtitle,
                                fontSize = 14.sp,
                                color = Color.White.copy(alpha = 0.85f),
                                textAlign = TextAlign.Center
                            )
                            HydrationHeroRing(
                                intakeMl = uiState.effectiveIntake,
                                goalMl = uiState.effectiveGoalMl,
                                progress = uiState.progress,
                                modifier = Modifier.size(160.dp)
                            )
                        }
                    }
                }
                1 -> {
                    // Insights slide
                    uiState.insights?.let { insights ->
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    "Your Stats",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    HeroInsightTile(
                                        label = "Streak",
                                        value = "${insights.streakDays}d",
                                        icon = "🔥",
                                        modifier = Modifier.weight(1f)
                                    )
                                    HeroInsightTile(
                                        label = "7-day avg",
                                        value = "${insights.avgDailyIntake}ml",
                                        icon = "📊",
                                        modifier = Modifier.weight(1f)
                                    )
                                }
                                insights.mostCommonDrink?.let { drink ->
                                    HeroInsightTile(
                                        label = "Favourite",
                                        value = drink,
                                        icon = "💙",
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Pagination dots
        if (pageCount > 1) {
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(pageCount) { i ->
                    Box(
                        modifier = Modifier
                            .size(if (pagerState.currentPage == i) 8.dp else 6.dp)
                            .clip(CircleShape)
                            .background(
                                if (pagerState.currentPage == i) Color.White
                                else Color.White.copy(alpha = 0.4f)
                            )
                    )
                }
            }
        }
    }
}

@Composable
private fun HeroInsightTile(
    label: String,
    value: String,
    icon: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.18f))
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(icon, fontSize = 20.sp)
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
        Text(label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.7f))
    }
}
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt
git commit -m "feat(hydration): add HydrationHeroPager with insights slide"
```

---

### Task 4: Add AddDrinkBottomSheet composable

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt`

Add required import at top:
```kotlin
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
```

Add after `HeroInsightTile`:

**Step 1: Add AddDrinkBottomSheet**

```kotlin
// ─────────────────────────────────────
// MARK: - AddDrinkBottomSheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddDrinkBottomSheet(
    onDismiss: () -> Unit,
    onAdd: (DrinkType, Int) -> Unit,
    onOpenUrineGuide: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedType by remember { mutableStateOf(DrinkType.WATER) }
    var customText by remember { mutableStateOf("") }
    val focusManager = LocalFocusManager.current

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Title
            Text(
                "Add a Drink",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            // Drink type chips
            Text("Drink Type", fontSize = 13.sp, color = AppColors.onSurface.copy(alpha = 0.55f))
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(DrinkType.entries.toList()) { type ->
                    val isSelected = type == selectedType
                    val bgColor by animateColorAsState(
                        targetValue = if (isSelected) HydrationCyan else AppColors.surfaceVariant,
                        label = "chipColor"
                    )
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(bgColor)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) { selectedType = type }
                            .padding(horizontal = 14.dp, vertical = 8.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Text(type.icon, fontSize = 16.sp)
                            Text(
                                type.displayName,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (isSelected) Color.White else AppColors.onSurface
                            )
                        }
                    }
                }
            }

            // Quick-add presets
            Text("Quick Add", fontSize = 13.sp, color = AppColors.onSurface.copy(alpha = 0.55f))
            val presets = QuickAddPreset.defaults
            val columns = 3
            val rows = (presets.size + columns - 1) / columns
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(rows) { row ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        repeat(columns) { col ->
                            val idx = row * columns + col
                            if (idx < presets.size) {
                                val preset = presets[idx]
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(HydrationCyan.copy(alpha = 0.12f))
                                        .clickable(
                                            interactionSource = remember { MutableInteractionSource() },
                                            indication = null
                                        ) {
                                            onAdd(selectedType, preset.amountMl)
                                            onDismiss()
                                        }
                                        .padding(vertical = 12.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.spacedBy(2.dp)
                                    ) {
                                        Text(preset.icon, fontSize = 18.sp)
                                        Text(
                                            preset.label,
                                            fontSize = 13.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = HydrationCyan
                                        )
                                    }
                                }
                            } else {
                                Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // Custom amount
            Text("Custom Amount", fontSize = 13.sp, color = AppColors.onSurface.copy(alpha = 0.55f))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedTextField(
                    value = customText,
                    onValueChange = { customText = it.filter { c -> c.isDigit() } },
                    label = { Text("Amount (ml)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Done
                    ),
                    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = HydrationCyan,
                        cursorColor = HydrationCyan
                    )
                )
                Button(
                    onClick = {
                        val amount = customText.toIntOrNull()
                        if (amount != null && amount > 0) {
                            onAdd(selectedType, amount)
                            onDismiss()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = HydrationCyan),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.height(56.dp)
                ) {
                    Icon(Icons.Default.Add, null, tint = Color.White)
                }
            }

            // Urine guide
            HorizontalDivider(color = AppColors.outline.copy(alpha = 0.25f))
            TextButton(
                onClick = {
                    onDismiss()
                    onOpenUrineGuide()
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(
                    Icons.Default.Colorize, null,
                    tint = Color(0xFF00C7BE),
                    modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "Urine Color Guide",
                    color = Color(0xFF00C7BE),
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt
git commit -m "feat(hydration): add AddDrinkBottomSheet composable"
```

---

### Task 5: Add blue-themed HydrationCalendarStrip variant

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt`

Replace the body of `HydrationCalendarDay` (the private composable inside `HydrationCalendarStrip`, lines ~213-268) to use a white/translucent style suitable for the blue gradient background.

**Step 1: Update HydrationCalendarDay**

Replace the entire `HydrationCalendarDay` composable with:

```kotlin
@Composable
private fun HydrationCalendarDay(
    date: LocalDate,
    isToday: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val dayAbbr = date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(3)

    Box(
        modifier = Modifier
            .width(50.dp)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = dayAbbr,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = if (isSelected) Color.White
                else Color.White.copy(alpha = 0.6f)
            )
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        when {
                            isSelected -> Color.White
                            isToday -> Color.White.copy(alpha = 0.25f)
                            else -> Color.Transparent
                        },
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = date.dayOfMonth.toString(),
                    fontSize = 16.sp,
                    fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Normal,
                    color = when {
                        isSelected -> Color(0xFF2563EB)
                        else -> Color.White
                    }
                )
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationComponents.kt
git commit -m "feat(hydration): restyle calendar strip for blue gradient background"
```

---

### Task 6: Rewrite HydrationScreen.kt with new layout

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationScreen.kt`

Replace the entire file content with the redesigned screen below. This keeps all navigation callbacks, all ViewModel calls, all functionality — only the layout changes.

**Step 1: Rewrite HydrationScreen.kt**

```kotlin
package com.swastricare.health.ui.screens.hydration

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.models.DrinkType
import com.swastricare.health.ui.components.TrackScreen
import java.time.format.DateTimeFormatter
import java.util.Locale

// ─────────────────────────────────────
// MARK: - HydrationScreen
// ─────────────────────────────────────

private val HydrationGradient = Brush.verticalGradient(
    colors = listOf(Color(0xFF0EA5E9), Color(0xFF2563EB))
)

@Composable
fun HydrationScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAI: () -> Unit,
    onNavigateToSettings: () -> Unit = {}
) {
    TrackScreen("Hydration")
    val vm: HydrationViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()

    var showAddSheet by remember { mutableStateOf(false) }
    var showUrineGuide by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.error) {
        uiState.error?.let { msg ->
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            vm.clearError()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {

        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(HydrationGradient)
                ) {
                    HydrationSkeletonContent()
                }
            }
            else -> {
                // ── Two-zone layout: gradient hero + white bottom card ──
                Column(modifier = Modifier.fillMaxSize()) {

                    // ── GRADIENT ZONE ──
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(HydrationGradient)
                    ) {
                        Column(modifier = Modifier.fillMaxWidth()) {

                            // Top bar
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .statusBarsPadding()
                                    .padding(horizontal = 4.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                IconButton(onClick = onNavigateBack) {
                                    Icon(
                                        Icons.Default.ArrowBack, "Back",
                                        tint = Color.White
                                    )
                                }
                                Spacer(Modifier.weight(1f))
                                IconButton(onClick = onNavigateToSettings) {
                                    Icon(
                                        Icons.Default.Settings, "Settings",
                                        tint = Color.White.copy(alpha = 0.8f)
                                    )
                                }
                                IconButton(onClick = onNavigateToAI) {
                                    Icon(
                                        Icons.Default.AutoAwesome, "Ask AI",
                                        tint = Color.White
                                    )
                                }
                            }

                            // Greeting
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Text(
                                    text = if (uiState.userName.isNotBlank())
                                        "Hello, ${uiState.userName.substringBefore(" ")}"
                                    else "Hydration",
                                    fontSize = 28.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                                val subtitle = when {
                                    uiState.isGoalMet -> "Goal reached! Great job 🎉"
                                    uiState.progress >= 0.7f -> "Almost there, keep going!"
                                    uiState.todaysEntries.isEmpty() -> "Start hydrating today 💧"
                                    else -> "You're on track!"
                                }
                                Text(
                                    text = subtitle,
                                    fontSize = 14.sp,
                                    color = Color.White.copy(alpha = 0.8f)
                                )
                            }

                            Spacer(Modifier.height(20.dp))

                            // Hero pager
                            HydrationHeroPager(
                                uiState = uiState,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp)
                            )

                            Spacer(Modifier.height(20.dp))

                            // Calendar strip
                            HydrationCalendarStrip(
                                selectedDate = uiState.selectedDate,
                                onDateSelected = { vm.selectDate(it) }
                            )

                            Spacer(Modifier.height(16.dp))

                            // Weather banner (on gradient, translucent)
                            if (uiState.isWeatherAdjusted && uiState.weatherData != null) {
                                WeatherAdjustmentBanner(
                                    temperature = uiState.weatherData!!.temperatureCelsius,
                                    city = uiState.weatherData!!.city,
                                    baseGoal = uiState.baseGoalMl,
                                    adjustedGoal = uiState.effectiveGoalMl,
                                    modifier = Modifier.padding(horizontal = 16.dp)
                                )
                                Spacer(Modifier.height(12.dp))
                            }
                        }
                    }

                    // ── WHITE BOTTOM CARD ──
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                            .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                            .background(MaterialTheme.colorScheme.background)
                    ) {
                        val dateFormatter = DateTimeFormatter.ofPattern("d MMM yyyy", Locale.getDefault())
                        val formattedDate = uiState.selectedDate.format(dateFormatter)
                        val totalMl = uiState.effectiveIntake
                        val drinkCount = uiState.todaysEntries.size

                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(bottom = 100.dp)
                        ) {
                            // Date header
                            item {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 20.dp, vertical = 16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "Today, $formattedDate",
                                            fontSize = 17.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onBackground
                                        )
                                        if (drinkCount > 0) {
                                            Text(
                                                text = "$drinkCount drink${if (drinkCount != 1) "s" else ""} · ${totalMl}ml",
                                                fontSize = 12.sp,
                                                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
                                            )
                                        }
                                    }
                                    Icon(
                                        Icons.Default.CalendarToday,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f),
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                                HorizontalDivider(
                                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.07f)
                                )
                            }

                            // Entry list or empty state
                            if (uiState.todaysEntries.isNotEmpty()) {
                                items(
                                    items = uiState.todaysEntries,
                                    key = { it.id }
                                ) { entry ->
                                    HydrationEntryCard(
                                        entry = entry,
                                        onDelete = { vm.deleteDrink(entry.id) }
                                    )
                                    HorizontalDivider(
                                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.06f),
                                        modifier = Modifier.padding(start = 72.dp)
                                    )
                                }
                            } else {
                                item {
                                    Column(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(vertical = 48.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Text("💧", fontSize = 44.sp)
                                        Text(
                                            "No drinks logged yet",
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.55f)
                                        )
                                        Text(
                                            "Tap + to log your first drink",
                                            fontSize = 13.sp,
                                            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.35f)
                                        )
                                    }
                                }
                            }

                            // Ask AI row
                            item {
                                Spacer(Modifier.height(8.dp))
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable(
                                            interactionSource = remember { MutableInteractionSource() },
                                            indication = null
                                        ) { onNavigateToAI() }
                                        .padding(horizontal = 20.dp, vertical = 14.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Icon(
                                        Icons.Default.AutoAwesome,
                                        null,
                                        tint = HydrationCyan,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Text(
                                        "Ask AI about my hydration",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = HydrationCyan
                                    )
                                    Spacer(Modifier.weight(1f))
                                    Icon(
                                        Icons.Default.ChevronRight, null,
                                        tint = HydrationCyan.copy(alpha = 0.6f),
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                                HorizontalDivider(
                                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.07f)
                                )
                            }
                        }
                    }
                }
            }
        }

        // FAB
        FloatingActionButton(
            onClick = { showAddSheet = true },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 20.dp, bottom = 28.dp),
            containerColor = HydrationCyan,
            contentColor = Color.White
        ) {
            Icon(Icons.Default.Add, "Add drink")
        }

        // Snackbar
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 96.dp)
        )
    }

    // Add drink bottom sheet
    if (showAddSheet) {
        AddDrinkBottomSheet(
            onDismiss = { showAddSheet = false },
            onAdd = { drinkType, amountMl -> vm.addDrink(drinkType, amountMl) },
            onOpenUrineGuide = { showUrineGuide = true }
        )
    }

    // Urine color guide sheet
    if (showUrineGuide) {
        UrineColorGuideSheet(
            onDismiss = { showUrineGuide = false },
            onLogWater = { amount -> vm.addDrink(DrinkType.WATER, amount) }
        )
    }
}
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/hydration/HydrationScreen.kt
git commit -m "feat(hydration): redesign HydrationScreen with gradient hero layout"
```

---

### Task 7: Build and verify

**Step 1: Run debug build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -40
```

Expected: `BUILD SUCCESSFUL`

**Step 2: If build errors — common fixes**

- Missing import for `HorizontalPager`: add `import androidx.compose.foundation.pager.HorizontalPager` and `import androidx.compose.foundation.pager.rememberPagerState` to `HydrationComponents.kt`
- Missing `@OptIn(ExperimentalFoundationApi::class)`: add to file level or composable level
- Missing `items` import in `AddDrinkBottomSheet`: add `import androidx.compose.foundation.lazy.items`
- `HydrationUiState` not visible in `HydrationComponents.kt`: add import `import com.swastricare.health.ui.screens.hydration.HydrationUiState` if in same package it's already visible

**Step 3: Final commit**

```bash
git add -p
git commit -m "fix(hydration): resolve build errors from redesign"
```
