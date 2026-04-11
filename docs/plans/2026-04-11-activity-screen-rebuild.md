# Activity Screen Rebuild Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fully rewrite `RunActivityScreen.kt` with a Strava + Nike Run Club aesthetic — bold stats, Strava-style workout cards, 7-day bar chart, and a persistent bottom panel for workout type selection + START.

**Architecture:** Single-file rewrite of `RunActivityScreen.kt`. Screen uses `Box` with a `LazyColumn` content area above a fixed bottom `WorkoutPanel`. No ViewModel changes, no navigation changes — only the UI layer changes.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, `androidx.compose.animation`, existing `AppColors` / `PremiumColor` / activity-specific colors from `Color.kt`.

---

## Reference Files (read before starting)

- `RunActivityScreen.kt` — file being replaced: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt`
- `RunActivityViewModel.kt` — UiState shape (don't change): same package
- `LiveWorkoutViewModel.kt` — `WorkoutType` enum lives here (same package, import it): same package
- `Color.kt` — `RunningCyan`, `WalkingGreen`, `CyclingYellow`, `HikingPurple`, `AppColors`, `SecondaryColor`: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt`
- `WorkoutTypeCard.kt` — existing component for type selection (reference, do NOT reuse directly): `components/WorkoutTypeCard.kt`

---

## Task 1: Scaffold — Box layout with scrollable body + fixed bottom panel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt` (full rewrite)

**Step 1: Replace entire file with the scaffold**

Delete all existing content. Write this skeleton:

```kotlin
package com.swastricare.health.ui.screens.runactivity

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AppColors

@Composable
fun RunActivityScreen(
    onNavigateToLiveWorkout: (WorkoutType?) -> Unit = {},
    onNavigateToActivityDetail: (String) -> Unit = {},
    onNavigateToCalendar: () -> Unit = {},
    onNavigateBack: (() -> Unit)? = null
) {
    TrackScreen("RunActivity")
    val viewModel: RunActivityViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val lifecycleOwner = LocalLifecycleOwner.current

    // Reload on resume (after returning from live workout)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadData()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let { msg ->
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            viewModel.clearError()
        }
    }

    // Selected workout type lives here (UI-only state, not in ViewModel)
    var selectedType by remember { mutableStateOf(WorkoutType.RUN) }

    Box(modifier = Modifier
        .fillMaxSize()
        .background(AppColors.background)
    ) {
        // Scrollable content — padded at bottom so it doesn't hide behind the panel
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 20.dp, end = 20.dp,
                top = 16.dp, bottom = 200.dp   // 200dp clears fixed bottom panel
            ),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item { ActivityHeader(onNavigateToCalendar = onNavigateToCalendar) }
            item {
                HeroStatsCard(
                    steps = uiState.todaySteps,
                    distanceKm = uiState.todayDistance,
                    calories = uiState.todayCalories,
                    isLoading = uiState.isLoading
                )
            }
            item { WeeklyBarChart(activities = uiState.activities) }
            if (uiState.vo2Max != null || uiState.weeklyTrainingLoad > 0) {
                item {
                    FitnessInsightChips(
                        vo2Max = uiState.vo2Max,
                        weeklyLoad = uiState.weeklyTrainingLoad,
                        loadTrend = uiState.loadTrend
                    )
                }
            }
            item { RecentWorkoutsHeader(onSeeAll = onNavigateToCalendar) }
            if (uiState.activities.isEmpty()) {
                item { EmptyWorkoutsState() }
            } else {
                items(uiState.activities.take(5), key = { it.id }) { activity ->
                    StravaWorkoutCard(
                        activity = activity,
                        onClick = { onNavigateToActivityDetail(activity.id) }
                    )
                }
            }
        }

        // Fixed bottom workout panel
        WorkoutPanel(
            selectedType = selectedType,
            onTypeSelected = { selectedType = it },
            onStart = { onNavigateToLiveWorkout(selectedType) },
            modifier = Modifier.align(Alignment.BottomCenter)
        )

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 196.dp)
        )
    }
}
```

**Step 2: Verify it compiles with stub composables**

Add these stubs at the bottom of the same file (they'll be replaced in later tasks):

```kotlin
@Composable private fun ActivityHeader(onNavigateToCalendar: () -> Unit) {}
@Composable private fun HeroStatsCard(steps: Int, distanceKm: Double, calories: Int, isLoading: Boolean) {}
@Composable private fun WeeklyBarChart(activities: List<com.swastricare.health.data.models.RunActivity>) {}
@Composable private fun FitnessInsightChips(vo2Max: Double?, weeklyLoad: Int, loadTrend: com.swastricare.health.data.services.FitnessAnalyticsService.LoadTrend) {}
@Composable private fun RecentWorkoutsHeader(onSeeAll: () -> Unit) {}
@Composable private fun EmptyWorkoutsState() {}
@Composable private fun StravaWorkoutCard(activity: com.swastricare.health.data.models.RunActivity, onClick: () -> Unit) {}
@Composable private fun WorkoutPanel(selectedType: WorkoutType, onTypeSelected: (WorkoutType) -> Unit, onStart: () -> Unit, modifier: Modifier = Modifier) {}
```

**Step 3: Build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:compileDebugKotlin 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL` (stubs compile, no logic yet)

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): scaffold new RunActivityScreen - Box + LazyColumn + stub composables"
```

---

## Task 2: Header + HeroStatsCard

**Files:**
- Modify: `RunActivityScreen.kt` — replace `ActivityHeader` and `HeroStatsCard` stubs

**Step 1: Replace `ActivityHeader` stub**

```kotlin
@Composable
private fun ActivityHeader(onNavigateToCalendar: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "Activity",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.ExtraBold,
            color = AppColors.onBackground
        )
        IconButton(onClick = onNavigateToCalendar) {
            Icon(
                imageVector = Icons.Default.CalendarMonth,
                contentDescription = "Calendar",
                tint = AppColors.onSurfaceVariant
            )
        }
    }
}
```

**Step 2: Replace `HeroStatsCard` stub**

```kotlin
@Composable
private fun HeroStatsCard(
    steps: Int,
    distanceKm: Double,
    calories: Int,
    isLoading: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(AppColors.surfaceVariant)
            .padding(20.dp)
    ) {
        Text(
            text = "Today",
            style = MaterialTheme.typography.labelMedium,
            color = AppColors.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.sp
        )
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceAround
        ) {
            HeroStatItem(
                value = if (steps > 0) "%,d".format(steps) else "—",
                label = "Steps",
                icon = Icons.Default.DirectionsWalk,
                color = RunningCyan,
                isLoading = isLoading
            )
            // Subtle vertical divider
            Box(
                modifier = Modifier
                    .height(48.dp)
                    .width(1.dp)
                    .background(AppColors.outlineVariant)
                    .align(Alignment.CenterVertically)
            )
            HeroStatItem(
                value = if (distanceKm > 0) "%.1f".format(distanceKm) else "—",
                label = "km",
                icon = Icons.Default.Route,
                color = WalkingGreen,
                isLoading = isLoading
            )
            Box(
                modifier = Modifier
                    .height(48.dp)
                    .width(1.dp)
                    .background(AppColors.outlineVariant)
                    .align(Alignment.CenterVertically)
            )
            HeroStatItem(
                value = if (calories > 0) "$calories" else "—",
                label = "kcal",
                icon = Icons.Default.LocalFireDepartment,
                color = Color(0xFFFF9F0A),
                isLoading = isLoading
            )
        }
    }
}

@Composable
private fun HeroStatItem(
    value: String,
    label: String,
    icon: ImageVector,
    color: Color,
    isLoading: Boolean
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = color,
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.height(6.dp))
        if (isLoading) {
            Box(
                modifier = Modifier
                    .width(48.dp)
                    .height(28.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(AppColors.outlineVariant)
            )
        } else {
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
        }
        Spacer(Modifier.height(2.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}
```

**Step 3: Add required imports at top of file**

Add to the imports block:
```kotlin
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.*
```

**Step 4: Build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:compileDebugKotlin 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): add ActivityHeader and HeroStatsCard to new activity screen"
```

---

## Task 3: WeeklyBarChart

**Files:**
- Modify: `RunActivityScreen.kt` — replace `WeeklyBarChart` stub

**Step 1: Replace stub with bar chart implementation**

```kotlin
@Composable
private fun WeeklyBarChart(activities: List<com.swastricare.health.data.models.RunActivity>) {
    // Build a map of day-of-week (0=Mon..6=Sun) → (maxDistanceKm, dominantType)
    val today = java.time.LocalDate.now()
    val weekStart = today.minusDays(today.dayOfWeek.value.toLong() - 1) // Monday

    data class DayData(val distanceKm: Double, val type: com.swastricare.health.data.models.ActivityType?)

    val dayMap = (0..6).associate { offset ->
        val date = weekStart.plusDays(offset.toLong())
        val dayActivities = activities.filter {
            it.startTime?.toLocalDate() == date
        }
        val totalDist = dayActivities.sumOf { it.distanceKm }
        val dominant = dayActivities.maxByOrNull { it.distanceKm }?.activityType
        offset to DayData(totalDist, dominant)
    }

    val maxDist = dayMap.values.maxOfOrNull { it.distanceKm }?.coerceAtLeast(1.0) ?: 1.0
    val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
    val todayOffset = today.dayOfWeek.value - 1 // 0=Mon..6=Sun

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(AppColors.surfaceVariant)
            .padding(16.dp)
    ) {
        Text(
            text = "This Week",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Spacer(Modifier.height(14.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(80.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.Bottom
        ) {
            dayMap.entries.forEach { (offset, data) ->
                val barColor = when (data.type) {
                    com.swastricare.health.data.models.ActivityType.RUNNING -> RunningCyan
                    com.swastricare.health.data.models.ActivityType.WALKING -> WalkingGreen
                    com.swastricare.health.data.models.ActivityType.CYCLING -> CyclingYellow
                    com.swastricare.health.data.models.ActivityType.HIKING -> HikingPurple
                    null -> AppColors.outlineVariant
                }
                val heightFraction = (data.distanceKm / maxDist).toFloat().coerceIn(0.05f, 1f)
                val isToday = offset == todayOffset

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom,
                    modifier = Modifier.weight(1f)
                ) {
                    // Dot above today's bar
                    if (isToday) {
                        Box(
                            modifier = Modifier
                                .size(5.dp)
                                .clip(androidx.compose.foundation.shape.CircleShape)
                                .background(SecondaryColor)
                        )
                        Spacer(Modifier.height(3.dp))
                    } else {
                        Spacer(Modifier.height(8.dp))
                    }
                    Box(
                        modifier = Modifier
                            .width(18.dp)
                            .fillMaxHeight(heightFraction)
                            .clip(RoundedCornerShape(topStart = 5.dp, topEnd = 5.dp))
                            .background(
                                if (isToday) barColor else barColor.copy(alpha = 0.5f)
                            )
                    )
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceAround
        ) {
            dayLabels.forEachIndexed { idx, label ->
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (idx == todayOffset) AppColors.onSurface
                            else AppColors.onSurfaceVariant.copy(alpha = 0.5f),
                    fontWeight = if (idx == todayOffset) FontWeight.Bold else FontWeight.Normal
                )
            }
        }
    }
}
```

**Step 2: Add import**

```kotlin
import java.time.LocalDate
```

**Step 3: Build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:compileDebugKotlin 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): add WeeklyBarChart section to activity screen"
```

---

## Task 4: FitnessInsightChips + RecentWorkoutsHeader

**Files:**
- Modify: `RunActivityScreen.kt` — replace `FitnessInsightChips` and `RecentWorkoutsHeader` stubs

**Step 1: Replace `FitnessInsightChips` stub**

```kotlin
@Composable
private fun FitnessInsightChips(
    vo2Max: Double?,
    weeklyLoad: Int,
    loadTrend: com.swastricare.health.data.services.FitnessAnalyticsService.LoadTrend
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (vo2Max != null) {
            InsightChip(
                icon = Icons.Default.MonitorHeart,
                value = "%.1f".format(vo2Max),
                label = "VO₂ Max",
                color = RunningCyan
            )
        }
        if (weeklyLoad > 0) {
            InsightChip(
                icon = Icons.Default.Bolt,
                value = "$weeklyLoad",
                label = "Load",
                color = CyclingYellow
            )
        }
        val (trendIcon, trendColor, trendLabel) = when (loadTrend) {
            com.swastricare.health.data.services.FitnessAnalyticsService.LoadTrend.INCREASING ->
                Triple(Icons.Default.TrendingUp, WalkingGreen, "Building")
            com.swastricare.health.data.services.FitnessAnalyticsService.LoadTrend.DECREASING ->
                Triple(Icons.Default.TrendingDown, Color(0xFFFF9F0A), "Tapering")
            com.swastricare.health.data.services.FitnessAnalyticsService.LoadTrend.MAINTAINING ->
                Triple(Icons.Default.TrendingFlat, RunningCyan, "Steady")
        }
        InsightChip(
            icon = trendIcon,
            value = trendLabel,
            label = "Trend",
            color = trendColor
        )
    }
}

@Composable
private fun InsightChip(
    icon: ImageVector,
    value: String,
    label: String,
    color: Color
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}
```

**Step 2: Replace `RecentWorkoutsHeader` stub**

```kotlin
@Composable
private fun RecentWorkoutsHeader(onSeeAll: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "Recent",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
        TextButton(onClick = onSeeAll, contentPadding = PaddingValues(0.dp)) {
            Text(
                text = "See all",
                style = MaterialTheme.typography.labelMedium,
                color = SecondaryColor
            )
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = SecondaryColor,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}
```

**Step 3: Build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:compileDebugKotlin 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): add FitnessInsightChips and RecentWorkoutsHeader"
```

---

## Task 5: StravaWorkoutCard + EmptyWorkoutsState

**Files:**
- Modify: `RunActivityScreen.kt` — replace `StravaWorkoutCard` and `EmptyWorkoutsState` stubs

**Step 1: Replace `StravaWorkoutCard` stub**

```kotlin
@Composable
private fun StravaWorkoutCard(
    activity: com.swastricare.health.data.models.RunActivity,
    onClick: () -> Unit
) {
    val typeColor = when (activity.activityType) {
        com.swastricare.health.data.models.ActivityType.RUNNING -> RunningCyan
        com.swastricare.health.data.models.ActivityType.WALKING -> WalkingGreen
        com.swastricare.health.data.models.ActivityType.CYCLING -> CyclingYellow
        com.swastricare.health.data.models.ActivityType.HIKING -> HikingPurple
    }
    val typeIcon = when (activity.activityType) {
        com.swastricare.health.data.models.ActivityType.RUNNING -> Icons.Default.DirectionsRun
        com.swastricare.health.data.models.ActivityType.WALKING -> Icons.Default.DirectionsWalk
        com.swastricare.health.data.models.ActivityType.CYCLING -> Icons.Default.DirectionsBike
        com.swastricare.health.data.models.ActivityType.HIKING -> Icons.Default.Terrain
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surfaceVariant)
            .clickable { onClick() }
    ) {
        // Strava-style colored left stripe
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(80.dp)
                .background(typeColor)
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon badge
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(androidx.compose.foundation.shape.CircleShape)
                    .background(typeColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = typeIcon,
                    contentDescription = null,
                    tint = typeColor,
                    modifier = Modifier.size(20.dp)
                )
            }
            Spacer(Modifier.width(12.dp))
            // Main content
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${activity.formattedDistance} km",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Text(
                    text = "${activity.formattedDate}  ·  ${activity.formattedDuration}  ·  ${activity.formattedPace}/km",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
            // Calories right-aligned
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "${activity.caloriesBurned}",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFFFF9F0A)
                )
                Text(
                    text = "kcal",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}
```

**Step 2: Replace `EmptyWorkoutsState` stub**

```kotlin
@Composable
private fun EmptyWorkoutsState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(AppColors.surfaceVariant)
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = Icons.Default.DirectionsRun,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.3f),
            modifier = Modifier.size(52.dp)
        )
        Text(
            text = "No workouts yet",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurfaceVariant
        )
        Text(
            text = "Pick a workout below and hit Start",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant.copy(alpha = 0.55f),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}
```

**Step 3: Add missing import**

```kotlin
import androidx.compose.foundation.clickable
```

**Step 4: Build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:compileDebugKotlin 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): add StravaWorkoutCard with left stripe and EmptyWorkoutsState"
```

---

## Task 6: WorkoutPanel — fixed bottom with type chips + pulsing START button

**Files:**
- Modify: `RunActivityScreen.kt` — replace `WorkoutPanel` stub

**Step 1: Replace `WorkoutPanel` stub**

```kotlin
@Composable
private fun WorkoutPanel(
    selectedType: WorkoutType,
    onTypeSelected: (WorkoutType) -> Unit,
    onStart: () -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current

    // Pulse animation for START button
    val infiniteTransition = rememberInfiniteTransition(label = "startPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.025f,
        animationSpec = infiniteRepeatable(
            animation = androidx.compose.animation.core.tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Surface(
        modifier = modifier.fillMaxWidth(),
        color = AppColors.surface,
        shadowElevation = 12.dp,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Workout type chip row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                WorkoutType.entries.forEach { type ->
                    WorkoutChip(
                        type = type,
                        isSelected = type == selectedType,
                        onClick = {
                            haptic.performHapticFeedback(
                                androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove
                            )
                            onTypeSelected(type)
                        },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // START button
            Button(
                onClick = {
                    haptic.performHapticFeedback(
                        androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress
                    )
                    onStart()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .scale(pulseScale),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = SecondaryColor
                )
            ) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "START ${selectedType.displayName.uppercase()}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    letterSpacing = 1.sp
                )
            }
        }
    }
}

@Composable
private fun WorkoutChip(
    type: WorkoutType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val accentColor = when (type) {
        WorkoutType.RUN -> RunningCyan
        WorkoutType.WALK -> WalkingGreen
        WorkoutType.CYCLE -> CyclingYellow
        WorkoutType.HIKE -> HikingPurple
    }
    val icon: ImageVector = when (type) {
        WorkoutType.RUN -> Icons.Default.DirectionsRun
        WorkoutType.WALK -> Icons.Default.DirectionsWalk
        WorkoutType.CYCLE -> Icons.Default.DirectionsBike
        WorkoutType.HIKE -> Icons.Default.Terrain
    }
    val bgColor by animateColorAsState(
        targetValue = if (isSelected) accentColor else AppColors.surfaceVariant,
        animationSpec = tween(200),
        label = "chipBg"
    )
    val contentColor = if (isSelected) Color.Black else AppColors.onSurfaceVariant

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(bgColor)
            .clickable { onClick() }
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = type.displayName,
            tint = contentColor,
            modifier = Modifier.size(22.dp)
        )
        Text(
            text = type.displayName,
            style = MaterialTheme.typography.labelSmall,
            color = contentColor,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
        )
    }
}
```

**Step 2: Add required imports**

```kotlin
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.ui.draw.scale
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
```

**Step 3: Build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:compileDebugKotlin 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): add fixed WorkoutPanel with type chips and pulsing START button"
```

---

## Task 7: Full assembleDebug build + cleanup

**Step 1: Run full debug build**

```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift/android && \
  JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew assembleDebug 2>&1 | tail -40
```

Expected: `BUILD SUCCESSFUL` with APK at `app/build/outputs/apk/debug/app-debug.apk`

**Step 2: Fix any remaining issues**

If build fails, read the full error output and fix. Common issues:
- Missing imports — add the specific import
- `unresolved reference` for `animateColorAsState` — ensure `import androidx.compose.animation.animateColorAsState`
- `unresolved reference` for `scale` — ensure `import androidx.compose.ui.draw.scale`
- `unresolved reference` for `tween` — ensure `import androidx.compose.animation.core.*`

**Step 3: Verify unused stubs are removed**

Check that none of the original `StartWorkoutCard`, `QuickStartButton`, `FitnessCard`, `WeeklyStatsCard`, `TodayStatsRow`, `WorkoutHistoryCard` are still referenced or defined in the file.

```bash
grep -n "StartWorkoutCard\|QuickStartButton\|WeeklyStatsCard\|TodayStatsRow\|WorkoutHistoryCard" \
  android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
```

Expected: no matches (all removed)

**Step 4: Final commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/RunActivityScreen.kt
git commit -m "feat(android): complete RunActivityScreen redesign - Strava+Nike style with embedded workout panel"
```

---

## Notes

- `WorkoutType` enum is defined in `LiveWorkoutViewModel.kt` in the same package — no new import path needed, it's already visible.
- `formattedDate`, `formattedDistance`, `formattedDuration`, `formattedPace`, `caloriesBurned` are all computed properties on `RunActivity` — safe to use.
- Navigation callbacks (`onNavigateToLiveWorkout`, `onNavigateToActivityDetail`, `onNavigateToCalendar`) are **unchanged** — the new screen uses the same signatures.
- Do NOT modify `RunActivityViewModel`, `LiveWorkoutViewModel`, or any navigation file.
