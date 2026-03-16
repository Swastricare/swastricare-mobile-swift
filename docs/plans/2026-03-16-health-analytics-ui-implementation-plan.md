# Health Analytics UI Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fully redesign the Android HealthAnalyticsScreen with a hero health-score ring, bezier charts with drag scrubber, tappable metric grid cards, and a new per-metric detail screen.

**Architecture:** Single `LazyColumn` layout with 6 zones (TopBar → Hero → TimeRange → Chart → Grid → AI Insights). New `HealthMetricDetailScreen` added as a nav destination in `MainNavGraph`. `HealthAnalyticsViewModel` gains a health score computation and `MetricStats` data class.

**Tech Stack:** Kotlin, Jetpack Compose, Canvas API, Compose Navigation (string routes), Hilt, `pointerInput(detectDragGestures)` for chart scrubber, `infiniteTransition` for pulse animation.

**No test framework** is configured in this project — skip test steps, go straight to build + visual verification.

---

## Context: Existing Files

| File | What it does today |
|------|-------------------|
| `ui/screens/analytics/HealthAnalyticsScreen.kt` | Full screen + all composables — will be fully replaced |
| `ui/screens/analytics/HealthAnalyticsViewModel.kt` | ViewModel + all data models — will be extended |
| `ui/navigation/MainNavGraph.kt` | Wires `"health_analytics"` route — needs 1 new route |
| `ui/navigation/NavConfig.kt` | `NavArgs` object — needs 1 new constant |

---

## Task 1: Extend ViewModel with Health Score + MetricStats

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthAnalyticsViewModel.kt`

**Step 1: Add `MetricStats` data class and updated `LegacyHealthAnalyticsState`**

Add these right after the existing `LegacyMetricSummary` data class (around line 68):

```kotlin
data class MetricStats(
    val current: Float,
    val average: Float,
    val best: Float,
    val goal: Float?
)
```

Add `healthScore: Int = 0` to `LegacyHealthAnalyticsState`:

```kotlin
data class LegacyHealthAnalyticsState(
    val isLoading: Boolean = true,
    val selectedTimeRange: LegacyTimeRange = LegacyTimeRange.Week,
    val selectedMetric: LegacyMetricType = LegacyMetricType.Steps,
    val summaries: List<LegacyMetricSummary> = emptyList(),
    val chartData: List<LegacyChartDataPoint> = emptyList(),
    val aiInsight: String = "",
    val healthScore: Int = 0
)
```

**Step 2: Add `computeHealthScore()` and `getMetricStats()` to the ViewModel**

Add these private/public functions inside `HealthAnalyticsViewModel`, before the `companion object`:

```kotlin
private fun computeHealthScore(): Int {
    val stepsScore = if (LegacyMetricType.Steps.goal != null)
        (todaySteps.toFloat() / LegacyMetricType.Steps.goal!! * 100f).coerceIn(0f, 100f)
    else 0f
    val sleepScore = (todaySleepHours / 8f * 100f).coerceIn(0f, 100f)
    val hydrationScore = if (LegacyMetricType.Hydration.goal != null)
        (todayHydrationMl.toFloat() / LegacyMetricType.Hydration.goal!! * 100f).coerceIn(0f, 100f)
    else 0f
    val heartScore = if (todayHeartRate in 60..100) 100f
    else if (todayHeartRate == 0) 50f
    else (1f - kotlin.math.abs(todayHeartRate - 80f) / 80f).coerceIn(0f, 1f) * 100f

    return (stepsScore * 0.30f + sleepScore * 0.25f + hydrationScore * 0.25f + heartScore * 0.20f)
        .toInt().coerceIn(0, 100)
}

fun getMetricStats(metric: LegacyMetricType): MetricStats {
    val allValues: List<Float> = when (metric) {
        LegacyMetricType.Steps -> weeklyStepCounts.map { it.second.toFloat() }
            .ifEmpty { listOf(todaySteps.toFloat()) }
        LegacyMetricType.Hydration -> hydrationByDay.values.map { it.toFloat() }
            .ifEmpty { listOf(todayHydrationMl.toFloat()) }
        LegacyMetricType.Distance -> runActivitiesByDay.values.map { it.toFloat() }
            .ifEmpty { listOf(todayDistanceKm) }
        else -> listOf(getDailyValueForMetric(metric, java.time.LocalDate.now()))
    }
    val current = getDailyValueForMetric(metric, java.time.LocalDate.now())
    val avg = if (allValues.isNotEmpty()) allValues.average().toFloat() else current
    val best = allValues.maxOrNull() ?: current
    return MetricStats(current = current, average = avg, best = best, goal = metric.goal)
}
```

**Step 3: Call `computeHealthScore()` inside `buildSummaries()` result and update state**

In `loadData()`, after `buildSummaries()` is called, add `healthScore`:

```kotlin
_uiState.value = _uiState.value.copy(
    isLoading = false,
    summaries = summaries,
    aiInsight = generateInsight(summaries),
    healthScore = computeHealthScore()
)
```

**Step 4: Build + verify no compile errors**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthAnalyticsViewModel.kt
git commit -m "feat(analytics): add MetricStats, healthScore to ViewModel"
```

---

## Task 2: Add Nav Route for Metric Detail

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/NavConfig.kt`

**Step 1: Add `METRIC_TYPE` to `NavArgs`**

Inside the `NavArgs` object, add:

```kotlin
const val METRIC_TYPE = "metricType"
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/navigation/NavConfig.kt
git commit -m "feat(nav): add METRIC_TYPE nav arg constant"
```

---

## Task 3: Create HealthMetricDetailScreen

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthMetricDetailScreen.kt`

**Step 1: Write the full file**

```kotlin
package com.swastricare.health.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.TextStyle as DateTextStyle
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun HealthMetricDetailScreen(
    metricTypeName: String,
    viewModel: HealthAnalyticsViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val metric = remember(metricTypeName) {
        LegacyMetricType.entries.firstOrNull { it.name == metricTypeName }
            ?: LegacyMetricType.Steps
    }
    val uiState by viewModel.uiState.collectAsState()
    val stats = remember(uiState.summaries) { viewModel.getMetricStats(metric) }

    // Generate last-7-days chart data
    val chartData = remember(uiState.summaries) {
        viewModel.generatePublicChartData(metric, LegacyTimeRange.Week)
    }

    // Recent history (last 7 days)
    val today = remember { LocalDate.now() }
    val historyDays = remember { (6 downTo 0).map { today.minusDays(it.toLong()) } }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            // ── Top Bar ─────────────────────────────────────────────
            DetailTopBar(metric = metric, onBack = onNavigateBack)

            Spacer(modifier = Modifier.height(12.dp))

            // ── Large Chart ──────────────────────────────────────────
            DetailChartCard(metric = metric, chartData = chartData)

            Spacer(modifier = Modifier.height(16.dp))

            // ── Stats Row ────────────────────────────────────────────
            DetailStatsRow(stats = stats, metric = metric)

            Spacer(modifier = Modifier.height(16.dp))

            // ── Goal Progress Ring ───────────────────────────────────
            if (metric.goal != null) {
                DetailGoalCard(stats = stats, metric = metric)
                Spacer(modifier = Modifier.height(16.dp))
            }

            // ── 7-Day History ────────────────────────────────────────
            DetailHistoryCard(
                metric = metric,
                days = historyDays,
                chartData = chartData
            )

            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}

// ── Top Bar ──────────────────────────────────────────────────────────────────

@Composable
private fun DetailTopBar(metric: LegacyMetricType, onBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .glass(cornerRadius = 20.dp),
            contentAlignment = Alignment.Center
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    tint = AppColors.onSurface,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
        Spacer(modifier = Modifier.width(12.dp))
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(metric.color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = iconForLegacyMetric(metric),
                contentDescription = null,
                tint = metric.color,
                modifier = Modifier.size(18.dp)
            )
        }
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = metric.label,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
    }
}

// ── Detail Chart Card ─────────────────────────────────────────────────────────

@Composable
private fun DetailChartCard(
    metric: LegacyMetricType,
    chartData: List<LegacyChartDataPoint>
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "7-Day Trend",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        DetailBezierChart(
            data = chartData,
            color = metric.color,
            goalValue = metric.goal
        )
    }
}

@Composable
private fun DetailBezierChart(
    data: List<LegacyChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animProgress = 0f
        animate(0f, 1f, animationSpec = tween(1000, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    val textMeasurer = rememberTextMeasurer()
    val maxVal = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxVal, it) * 1.15f } ?: (maxVal * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(modifier = modifier.fillMaxWidth().height(320.dp)) {
        val lp = 44.dp.toPx()
        val bp = 28.dp.toPx()
        val cw = size.width - lp - 8.dp.toPx()
        val ch = size.height - bp - 8.dp.toPx()
        val top = 8.dp.toPx()
        val spacing = cw / (data.size - 1).coerceAtLeast(1)

        // 4 Y-axis gridlines
        for (i in 0..3) {
            val yVal = yMax * i / 3f
            val yPos = ch - (yVal / yMax * ch) + top
            val lbl = formatAxisValue(yVal)
            val m = textMeasurer.measure(lbl, style = TextStyle(fontSize = 9.sp, color = labelColor))
            drawText(m, topLeft = Offset(0f, yPos - m.size.height / 2f))
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(lp, yPos), end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        // Points
        val pts = data.mapIndexed { i, pt ->
            Offset(lp + i * spacing, ch - (pt.value / yMax * ch) + top)
        }

        val visibleIdx = (pts.size * animProgress).toInt().coerceAtLeast(1)
        val visPts = pts.take(visibleIdx)

        // Gradient fill with bezier
        if (visPts.size >= 2) {
            val fillPath = Path().apply {
                moveTo(visPts.first().x, ch + top)
                moveTo(visPts.first().x, visPts.first().y)
                for (i in 1 until visPts.size) {
                    val cp1x = (visPts[i - 1].x + visPts[i].x) / 2f
                    cubicTo(cp1x, visPts[i - 1].y, cp1x, visPts[i].y, visPts[i].x, visPts[i].y)
                }
                lineTo(visPts.last().x, ch + top)
                lineTo(visPts.first().x, ch + top)
                close()
            }
            drawPath(fillPath, brush = Brush.verticalGradient(
                colors = listOf(color.copy(alpha = 0.35f), Color.Transparent),
                startY = top, endY = ch + top
            ))

            val linePath = Path().apply {
                moveTo(visPts.first().x, visPts.first().y)
                for (i in 1 until visPts.size) {
                    val cp1x = (visPts[i - 1].x + visPts[i].x) / 2f
                    cubicTo(cp1x, visPts[i - 1].y, cp1x, visPts[i].y, visPts[i].x, visPts[i].y)
                }
            }
            drawPath(linePath, color = color, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
        }

        // Dots + X labels
        visPts.forEachIndexed { i, pt ->
            drawCircle(color = color, radius = 5.dp.toPx(), center = pt)
            drawCircle(color = Color.White, radius = 2.5f.dp.toPx(), center = pt)
            if (data[i].label.isNotEmpty()) {
                val m = textMeasurer.measure(data[i].label, style = TextStyle(fontSize = 9.sp, color = labelColor))
                drawText(m, topLeft = Offset(pt.x - m.size.width / 2f, ch + 12.dp.toPx()))
            }
        }

        // Goal line
        if (goalValue != null && goalValue <= yMax) {
            val goalY = ch - (goalValue / yMax * ch) + top
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(lp, goalY), end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }
    }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

@Composable
private fun DetailStatsRow(stats: MetricStats, metric: LegacyMetricType) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        listOf(
            "Current" to formatLegacyValue(stats.current, metric),
            "Average" to formatLegacyValue(stats.average, metric),
            "Best" to formatLegacyValue(stats.best, metric),
            "Goal" to (stats.goal?.let { formatLegacyValue(it, metric) } ?: "—")
        ).forEach { (label, value) ->
            Column(
                modifier = Modifier
                    .weight(1f)
                    .glass(cornerRadius = 14.dp)
                    .padding(vertical = 12.dp, horizontal = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleMedium,
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
    }
}

// ── Goal Progress Card ────────────────────────────────────────────────────────

@Composable
private fun DetailGoalCard(stats: MetricStats, metric: LegacyMetricType) {
    val goal = stats.goal ?: return
    val progress = (stats.current / goal).coerceIn(0f, 1f)

    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(Unit) {
        animate(0f, progress, animationSpec = tween(1200, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Goal Progress",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(160.dp)) {
            Canvas(modifier = Modifier.size(160.dp)) {
                val stroke = 14.dp.toPx()
                val inset = stroke / 2f
                // Track
                drawArc(
                    color = metric.color.copy(alpha = 0.15f),
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - stroke, size.height - stroke),
                    style = Stroke(stroke, cap = StrokeCap.Round)
                )
                // Fill
                drawArc(
                    color = metric.color,
                    startAngle = -90f,
                    sweepAngle = 360f * animProgress,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - stroke, size.height - stroke),
                    style = Stroke(stroke, cap = StrokeCap.Round)
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "${(progress * 100).roundToInt()}%",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = metric.color
                )
                Text(
                    text = "of goal",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        val remaining = (goal - stats.current).coerceAtLeast(0f)
        val remainText = if (remaining == 0f) "Goal achieved!" else
            "${formatLegacyValue(remaining, metric)} ${metric.unit} remaining"
        Text(
            text = remainText,
            style = MaterialTheme.typography.bodyMedium,
            color = if (remaining == 0f) metric.color else AppColors.onSurfaceVariant
        )
    }
}

// ── 7-Day History Card ────────────────────────────────────────────────────────

@Composable
private fun DetailHistoryCard(
    metric: LegacyMetricType,
    days: List<LocalDate>,
    chartData: List<LegacyChartDataPoint>
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        Text(
            text = "Recent History",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface,
            modifier = Modifier.padding(bottom = 12.dp)
        )

        val maxVal = chartData.maxOfOrNull { it.value }?.coerceAtLeast(1f) ?: 1f

        days.forEachIndexed { i, date ->
            val value = chartData.getOrNull(i)?.value ?: 0f
            val barFraction = (value / maxVal).coerceIn(0f, 1f)
            val dayLabel = date.dayOfWeek.getDisplayName(DateTextStyle.SHORT, Locale.getDefault())
            val dateLabel = "${date.dayOfMonth} ${date.month.getDisplayName(DateTextStyle.SHORT, Locale.getDefault())}"

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = dayLabel,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface,
                    modifier = Modifier.width(36.dp)
                )
                Text(
                    text = dateLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    modifier = Modifier.width(52.dp)
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(metric.color.copy(alpha = 0.12f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(barFraction)
                            .clip(RoundedCornerShape(4.dp))
                            .background(metric.color)
                    )
                }
                Text(
                    text = if (value == 0f) "—" else formatLegacyValue(value, metric),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (value == 0f) AppColors.onSurfaceVariant else AppColors.onSurface,
                    modifier = Modifier.width(52.dp)
                )
            }

            if (i < days.lastIndex) {
                HorizontalDivider(
                    color = AppColors.onSurfaceVariant.copy(alpha = 0.08f),
                    thickness = 0.5.dp
                )
            }
        }
    }
}
```

**Step 2: Expose `generatePublicChartData` on the ViewModel**

In `HealthAnalyticsViewModel.kt`, add a public wrapper so the detail screen can call it:

```kotlin
fun generatePublicChartData(metric: LegacyMetricType, range: LegacyTimeRange): List<LegacyChartDataPoint> {
    return generateChartData(metric, range)
}
```

**Step 3: Build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthMetricDetailScreen.kt \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthAnalyticsViewModel.kt
git commit -m "feat(analytics): add HealthMetricDetailScreen with bezier chart + goal ring"
```

---

## Task 4: Wire Detail Screen into MainNavGraph

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/MainNavGraph.kt`

**Step 1: Add import for HealthMetricDetailScreen**

At the top of the imports block:

```kotlin
import com.swastricare.health.ui.screens.analytics.HealthMetricDetailScreen
```

**Step 2: Update `"health_analytics"` composable to add `onNavigateToMetricDetail` callback**

Replace the existing `"health_analytics"` composable entry:

```kotlin
// ─── Health Analytics ───
composable("health_analytics") {
    HealthAnalyticsScreen(
        onNavigateBack = { navController.popBackStack() },
        onNavigateToAI = { navigateToTab(navController, BottomNavTab.AI.route) },
        onNavigateToMetricDetail = { metric ->
            navController.navigate("metric_detail/${metric.name}")
        }
    )
}

// ─── Metric Detail ───
composable(
    route = "metric_detail/{${NavArgs.METRIC_TYPE}}",
    arguments = listOf(
        navArgument(NavArgs.METRIC_TYPE) { type = NavType.StringType }
    )
) { backStackEntry ->
    val metricName = backStackEntry.arguments?.getString(NavArgs.METRIC_TYPE) ?: "Steps"
    HealthMetricDetailScreen(
        metricTypeName = metricName,
        onNavigateBack = { navController.popBackStack() }
    )
}
```

**Step 3: Build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -30
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/navigation/MainNavGraph.kt \
        android/app/src/main/kotlin/com/swastricare/health/ui/navigation/NavConfig.kt
git commit -m "feat(nav): wire metric_detail route into MainNavGraph"
```

---

## Task 5: Rewrite HealthAnalyticsScreen

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthAnalyticsScreen.kt`

This is the main visual redesign. Replace the entire file content with the following:

```kotlin
package com.swastricare.health.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.*
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.roundToInt

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main Screen
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun HealthAnalyticsScreen(
    viewModel: HealthAnalyticsViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {},
    onNavigateToAI: () -> Unit = {},
    onNavigateToMetricDetail: (LegacyMetricType) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        if (uiState.isLoading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.primary)
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 120.dp)
            ) {
                // Top Bar
                item {
                    AnalyticsTopBar(onNavigateBack = onNavigateBack)
                    Spacer(Modifier.height(8.dp))
                }

                // Hero Card
                item {
                    HeroCard(
                        summaries = uiState.summaries,
                        healthScore = uiState.healthScore
                    )
                    Spacer(Modifier.height(16.dp))
                }

                // Time Range Chips
                item {
                    TimeRangeChips(
                        selected = uiState.selectedTimeRange,
                        onSelect = { viewModel.selectTimeRange(it) }
                    )
                    Spacer(Modifier.height(16.dp))
                }

                // Chart Card
                item {
                    ChartCard(
                        selectedMetric = uiState.selectedMetric,
                        selectedRange = uiState.selectedTimeRange,
                        chartData = uiState.chartData,
                        onMetricSelected = { viewModel.selectMetric(it) }
                    )
                    Spacer(Modifier.height(16.dp))
                }

                // Metrics Grid Header
                item {
                    Text(
                        text = "All Metrics",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onBackground,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                    Spacer(Modifier.height(12.dp))
                }

                // Metrics Grid rows (2 per row)
                val rows = uiState.summaries.chunked(2)
                items(rows.size) { rowIdx ->
                    val row = rows[rowIdx]
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        row.forEachIndexed { colIdx, summary ->
                            MetricCard(
                                summary = summary,
                                animationDelay = (rowIdx * 2 + colIdx) * 80,
                                modifier = Modifier.weight(1f),
                                onClick = { onNavigateToMetricDetail(summary.type) }
                            )
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(12.dp))
                }

                // AI Insights
                item {
                    Spacer(Modifier.height(8.dp))
                    AIInsightsCard(
                        insight = uiState.aiInsight,
                        onAskAI = onNavigateToAI
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - TopBar
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AnalyticsTopBar(onNavigateBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .glass(cornerRadius = 20.dp)
                .clickable { onNavigateBack() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = AppColors.onSurface,
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(Modifier.width(12.dp))
        Text(
            text = "Health Analytics",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground,
            modifier = Modifier.weight(1f)
        )
        // Date badge
        val today = remember {
            LocalDate.now().format(DateTimeFormatter.ofPattern("MMM d"))
        }
        Box(
            modifier = Modifier
                .glass(cornerRadius = 12.dp)
                .padding(horizontal = 10.dp, vertical = 4.dp)
        ) {
            Text(
                text = "Today, $today",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Hero Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun HeroCard(
    summaries: List<LegacyMetricSummary>,
    healthScore: Int
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(100)
        isVisible = true
    }
    val animAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "heroAlpha"
    )
    val animOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 24f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "heroOffset"
    )

    val scoreColor = when {
        healthScore >= 90 -> PrimaryColor
        healthScore >= 70 -> SecondaryColor
        healthScore >= 40 -> WarningOrange
        else -> DangerRed
    }
    val scoreLabel = when {
        healthScore >= 90 -> "Excellent"
        healthScore >= 70 -> "Good"
        healthScore >= 40 -> "Fair"
        else -> "Needs Attention"
    }

    val keyMetrics = summaries.filter {
        it.type in listOf(
            LegacyMetricType.Steps,
            LegacyMetricType.HeartRate,
            LegacyMetricType.Sleep,
            LegacyMetricType.Hydration
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .graphicsLayer {
                alpha = animAlpha
                translationY = animOffset
            }
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Health score ring
            HealthScoreRing(score = healthScore, scoreColor = scoreColor, scoreLabel = scoreLabel)

            // Key metric pills
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                keyMetrics.forEach { summary ->
                    HeroMetricPill(summary = summary)
                }
            }
        }
    }
}

@Composable
private fun HealthScoreRing(score: Int, scoreColor: Color, scoreLabel: String) {
    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(score) {
        animProgress = 0f
        animate(0f, score / 100f, animationSpec = tween(1200, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(110.dp)) {
        Canvas(modifier = Modifier.size(110.dp)) {
            val stroke = 10.dp.toPx()
            val inset = stroke / 2f
            // Track ring
            drawArc(
                color = scoreColor.copy(alpha = 0.15f),
                startAngle = -90f, sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(size.width - stroke, size.height - stroke),
                style = Stroke(stroke, cap = StrokeCap.Round)
            )
            // Score arc
            drawArc(
                color = scoreColor,
                startAngle = -90f, sweepAngle = 360f * animProgress,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(size.width - stroke, size.height - stroke),
                style = Stroke(stroke, cap = StrokeCap.Round)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "$score",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = scoreColor,
                fontSize = 28.sp
            )
            Text(
                text = scoreLabel,
                style = MaterialTheme.typography.labelSmall,
                color = scoreColor,
                fontSize = 10.sp
            )
        }
    }
}

@Composable
private fun HeroMetricPill(summary: LegacyMetricSummary) {
    val goal = summary.type.goal
    val progress = if (goal != null && goal > 0f)
        (summary.currentValue / goal).coerceIn(0f, 1f) else 0f

    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(summary.type.color, CircleShape)
            )
            Text(
                text = summary.type.label,
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant,
                fontSize = 11.sp
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "${formatLegacyValue(summary.currentValue, summary.type)} ${summary.type.unit}",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface,
                fontSize = 12.sp
            )
        }
        if (goal != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(summary.type.color.copy(alpha = 0.15f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(progress)
                        .clip(RoundedCornerShape(2.dp))
                        .background(summary.type.color)
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Time Range Chips
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TimeRangeChips(
    selected: LegacyTimeRange,
    onSelect: (LegacyTimeRange) -> Unit
) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(LegacyTimeRange.entries) { range ->
            val isSelected = range == selected
            FilterChip(
                selected = isSelected,
                onClick = { onSelect(range) },
                label = {
                    Text(
                        text = range.label,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = AppColors.primary,
                    selectedLabelColor = AppColors.onPrimary,
                    containerColor = Color.Transparent,
                    labelColor = AppColors.onSurfaceVariant
                ),
                border = if (isSelected) null else FilterChipDefaults.filterChipBorder(
                    borderColor = AppColors.onSurfaceVariant.copy(alpha = 0.3f),
                    enabled = true,
                    selected = false
                )
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Chart Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ChartCard(
    selectedMetric: LegacyMetricType,
    selectedRange: LegacyTimeRange,
    chartData: List<LegacyChartDataPoint>,
    onMetricSelected: (LegacyMetricType) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(
            text = "${selectedMetric.label} Overview",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        // Metric tab picker with labels
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(LegacyMetricType.entries) { metric ->
                val isSelected = metric == selectedMetric
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.clickable { onMetricSelected(metric) }
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(
                                if (isSelected) metric.color
                                else metric.color.copy(alpha = 0.1f)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = iconForLegacyMetric(metric),
                            contentDescription = metric.label,
                            tint = if (isSelected) Color.White else metric.color,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Text(
                        text = metric.label.split(" ").first(), // e.g. "Heart" from "Heart Rate"
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) metric.color else AppColors.onSurfaceVariant,
                        fontSize = 9.sp
                    )
                }
            }
        }

        // Chart
        when (selectedRange) {
            LegacyTimeRange.Month -> BezierLineChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
            else -> GradientBarChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Gradient Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun GradientBarChart(
    data: List<LegacyChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animProgress = 0f
        animate(0f, 1f, animationSpec = tween(800, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    // Drag scrubber state
    var dragX by remember { mutableStateOf<Float?>(null) }
    var tooltipIndex by remember { mutableStateOf<Int?>(null) }

    val textMeasurer = rememberTextMeasurer()
    val maxVal = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxVal, it) * 1.15f } ?: (maxVal * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(280.dp)
            .pointerInput(data) {
                detectDragGestures(
                    onDragStart = { offset -> dragX = offset.x },
                    onDrag = { _, drag -> dragX = (dragX ?: 0f) + drag.x },
                    onDragEnd = { kotlinx.coroutines.GlobalScope.launch { kotlinx.coroutines.delay(1500); dragX = null } },
                    onDragCancel = { dragX = null }
                )
            }
    ) {
        val lp = 44.dp.toPx()
        val bp = 28.dp.toPx()
        val cw = size.width - lp - 8.dp.toPx()
        val ch = size.height - bp - 8.dp.toPx()
        val count = data.size
        val gapRatio = 0.3f
        val bw = cw / count * (1f - gapRatio)
        val gap = cw / count * gapRatio

        // 4 Y-axis ticks
        for (i in 0..3) {
            val yVal = yMax * i / 3f
            val yPos = ch - (yVal / yMax * ch) + 8.dp.toPx()
            val m = textMeasurer.measure(formatAxisValue(yVal), style = TextStyle(fontSize = 9.sp, color = labelColor))
            drawText(m, topLeft = Offset(0f, yPos - m.size.height / 2f))
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(lp, yPos), end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        // Bars
        data.forEachIndexed { idx, point ->
            val x = lp + idx * (bw + gap) + gap / 2f
            val barH = (point.value / yMax * ch) * animProgress
            val top = ch - barH + 8.dp.toPx()

            // Determine if this bar is highlighted by drag
            val isHovered = dragX != null &&
                    dragX!! >= x && dragX!! <= x + bw

            if (isHovered) tooltipIndex = idx

            drawRoundRect(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        if (isHovered) color else color.copy(alpha = 0.85f),
                        color.copy(alpha = 0.5f)
                    ),
                    startY = top, endY = top + barH
                ),
                topLeft = Offset(x, top),
                size = Size(bw, barH),
                cornerRadius = CornerRadius(6.dp.toPx(), 6.dp.toPx())
            )

            if (point.label.isNotEmpty()) {
                val m = textMeasurer.measure(point.label, style = TextStyle(fontSize = 9.sp, color = labelColor))
                drawText(m, topLeft = Offset(x + bw / 2f - m.size.width / 2f, ch + 12.dp.toPx()))
            }
        }

        // Goal line + badge
        if (goalValue != null && goalValue <= yMax) {
            val goalY = ch - (goalValue / yMax * ch) + 8.dp.toPx()
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(lp, goalY), end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }

        // Tooltip for hovered bar
        val ti = tooltipIndex
        if (ti != null && dragX != null) {
            val point = data.getOrNull(ti)
            if (point != null) {
                val x = lp + ti * (bw + gap) + gap / 2f
                val tooltipText = "${point.label}: ${formatAxisValue(point.value)}"
                val tm = textMeasurer.measure(tooltipText, style = TextStyle(fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.SemiBold))
                val tPad = 6.dp.toPx()
                val tW = tm.size.width + tPad * 2
                val tH = tm.size.height + tPad * 2
                val tX = (x + bw / 2f - tW / 2f).coerceIn(lp, size.width - tW - 4.dp.toPx())
                val barTop = ch - (point.value / yMax * ch) * animProgress + 8.dp.toPx()
                val tY = (barTop - tH - 8.dp.toPx()).coerceAtLeast(4.dp.toPx())
                drawRoundRect(
                    color = color,
                    topLeft = Offset(tX, tY),
                    size = Size(tW, tH),
                    cornerRadius = CornerRadius(6.dp.toPx())
                )
                drawText(tm, topLeft = Offset(tX + tPad, tY + tPad))
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Bezier Line Chart
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun BezierLineChart(
    data: List<LegacyChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animProgress = 0f
        animate(0f, 1f, animationSpec = tween(1000, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    var dragX by remember { mutableStateOf<Float?>(null) }

    val textMeasurer = rememberTextMeasurer()
    val maxVal = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxVal, it) * 1.15f } ?: (maxVal * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(280.dp)
            .pointerInput(data) {
                detectDragGestures(
                    onDragStart = { offset -> dragX = offset.x },
                    onDrag = { _, drag -> dragX = (dragX ?: 0f) + drag.x },
                    onDragEnd = { kotlinx.coroutines.GlobalScope.launch { kotlinx.coroutines.delay(1500); dragX = null } },
                    onDragCancel = { dragX = null }
                )
            }
    ) {
        val lp = 44.dp.toPx()
        val bp = 28.dp.toPx()
        val cw = size.width - lp - 8.dp.toPx()
        val ch = size.height - bp - 8.dp.toPx()
        val top = 8.dp.toPx()
        val spacing = cw / (data.size - 1).coerceAtLeast(1)

        // 4 gridlines
        for (i in 0..3) {
            val yVal = yMax * i / 3f
            val yPos = ch - (yVal / yMax * ch) + top
            val m = textMeasurer.measure(formatAxisValue(yVal), style = TextStyle(fontSize = 9.sp, color = labelColor))
            drawText(m, topLeft = Offset(0f, yPos - m.size.height / 2f))
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(lp, yPos), end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        val allPts = data.mapIndexed { i, pt ->
            Offset(lp + i * spacing, ch - (pt.value / yMax * ch) + top)
        }
        val visibleCount = (allPts.size * animProgress).toInt().coerceAtLeast(1)
        val pts = allPts.take(visibleCount)

        if (pts.size >= 2) {
            // Gradient fill
            val fillPath = Path().apply {
                moveTo(pts.first().x, ch + top)
                lineTo(pts.first().x, pts.first().y)
                for (i in 1 until pts.size) {
                    val cpX = (pts[i - 1].x + pts[i].x) / 2f
                    cubicTo(cpX, pts[i - 1].y, cpX, pts[i].y, pts[i].x, pts[i].y)
                }
                lineTo(pts.last().x, ch + top)
                close()
            }
            drawPath(fillPath, brush = Brush.verticalGradient(
                colors = listOf(color.copy(alpha = 0.4f), Color.Transparent),
                startY = top, endY = ch + top
            ))

            // Bezier line
            val linePath = Path().apply {
                moveTo(pts.first().x, pts.first().y)
                for (i in 1 until pts.size) {
                    val cpX = (pts[i - 1].x + pts[i].x) / 2f
                    cubicTo(cpX, pts[i - 1].y, cpX, pts[i].y, pts[i].x, pts[i].y)
                }
            }
            drawPath(linePath, color = color, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
        }

        // Dots + X labels
        pts.forEachIndexed { i, pt ->
            drawCircle(color = color, radius = 4.dp.toPx(), center = pt)
            drawCircle(color = Color.White, radius = 2.dp.toPx(), center = pt)
            if (data[i].label.isNotEmpty()) {
                val m = textMeasurer.measure(data[i].label, style = TextStyle(fontSize = 9.sp, color = labelColor))
                drawText(m, topLeft = Offset(pt.x - m.size.width / 2f, ch + 12.dp.toPx()))
            }
        }

        // Goal line
        if (goalValue != null && goalValue <= yMax) {
            val goalY = ch - (goalValue / yMax * ch) + top
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(lp, goalY), end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }

        // Drag indicator
        val dx = dragX
        if (dx != null && dx >= lp) {
            // Find closest point
            val closestIdx = pts.indices.minByOrNull { abs(allPts[it].x - dx) } ?: return@Canvas
            val pt = pts.getOrNull(closestIdx) ?: return@Canvas
            // Vertical line
            drawLine(
                color = color.copy(alpha = 0.6f),
                start = Offset(pt.x, top),
                end = Offset(pt.x, ch + top),
                strokeWidth = 1.5f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
            )
            // Tooltip
            val tooltipText = "${data[closestIdx].label}: ${formatAxisValue(data[closestIdx].value)}"
            val tm = textMeasurer.measure(tooltipText, style = TextStyle(fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.SemiBold))
            val tPad = 6.dp.toPx()
            val tW = tm.size.width + tPad * 2
            val tH = tm.size.height + tPad * 2
            val tX = (pt.x - tW / 2f).coerceIn(lp, size.width - tW - 4.dp.toPx())
            val tY = (pt.y - tH - 10.dp.toPx()).coerceAtLeast(top)
            drawRoundRect(
                color = color,
                topLeft = Offset(tX, tY),
                size = Size(tW, tH),
                cornerRadius = CornerRadius(6.dp.toPx())
            )
            drawText(tm, topLeft = Offset(tX + tPad, tY + tPad))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Metric Card (tappable, with goal ring)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun MetricCard(
    summary: LegacyMetricSummary,
    animationDelay: Int = 0,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {}
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animationDelay.toLong())
        isVisible = true
    }
    val animAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "alpha"
    )
    val animOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "offset"
    )

    val goal = summary.type.goal
    val progress = if (goal != null && goal > 0f)
        (summary.currentValue / goal).coerceIn(0f, 1f) else 0f

    var ringProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(isVisible, progress) {
        if (isVisible) {
            animate(0f, progress, animationSpec = tween(900, easing = FastOutSlowInEasing)) { v, _ ->
                ringProgress = v
            }
        }
    }

    Column(
        modifier = modifier
            .graphicsLayer { alpha = animAlpha; translationY = animOffset }
            .glass(cornerRadius = 20.dp)
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .background(summary.type.color.copy(alpha = 0.15f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = iconForLegacyMetric(summary.type),
                        contentDescription = null,
                        tint = summary.type.color,
                        modifier = Modifier.size(16.dp)
                    )
                }
                Text(
                    text = summary.type.label,
                    style = MaterialTheme.typography.labelMedium,
                    color = AppColors.onSurfaceVariant
                )
            }

            // Mini goal ring
            if (goal != null) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(48.dp)) {
                    Canvas(modifier = Modifier.size(48.dp)) {
                        val stroke = 4.dp.toPx()
                        val inset = stroke / 2f
                        drawArc(
                            color = summary.type.color.copy(alpha = 0.15f),
                            startAngle = -90f, sweepAngle = 360f, useCenter = false,
                            topLeft = Offset(inset, inset),
                            size = Size(size.width - stroke, size.height - stroke),
                            style = Stroke(stroke, cap = StrokeCap.Round)
                        )
                        drawArc(
                            color = summary.type.color,
                            startAngle = -90f, sweepAngle = 360f * ringProgress, useCenter = false,
                            topLeft = Offset(inset, inset),
                            size = Size(size.width - stroke, size.height - stroke),
                            style = Stroke(stroke, cap = StrokeCap.Round)
                        )
                    }
                    Text(
                        text = "${(progress * 100).roundToInt()}%",
                        style = MaterialTheme.typography.labelSmall,
                        fontSize = 8.sp,
                        color = summary.type.color,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = formatLegacyValue(summary.currentValue, summary.type),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                text = summary.type.unit,
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 3.dp)
            )
        }

        // Change badge
        val pct = abs(summary.changePercent).roundToInt()
        val (badgeColor, badgeText) = when (summary.trend) {
            LegacyTrendDirection.Up -> Color(0xFF4CAF50) to "+$pct%"
            LegacyTrendDirection.Down -> Color(0xFFF44336) to "-$pct%"
            LegacyTrendDirection.Flat -> Color.Gray to "—"
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(badgeColor.copy(alpha = 0.15f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(
                    text = badgeText,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = badgeColor
                )
            }
            Text(
                text = "vs prev",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant.copy(alpha = 0.6f)
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AI Insights Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AIInsightsCard(insight: String, onAskAI: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition(label = "aiPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .graphicsLayer { scaleX = pulseScale; scaleY = pulseScale }
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(PremiumColor.DeepPurpleStart, PremiumColor.DeepPurpleEnd)
                        ),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
            Text(
                text = "AI Health Insights",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }

        Text(
            text = insight,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant,
            lineHeight = 22.sp
        )

        Button(
            onClick = onAskAI,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            contentPadding = PaddingValues(0.dp),
            shape = RoundedCornerShape(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(PremiumColor.DeepPurpleStart, PremiumColor.DeepPurpleEnd)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "Ask AI for more insights",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

private fun iconForLegacyMetric(type: LegacyMetricType): ImageVector = when (type) {
    LegacyMetricType.Steps -> Icons.Default.DirectionsWalk
    LegacyMetricType.Calories -> Icons.Default.LocalFireDepartment
    LegacyMetricType.HeartRate -> Icons.Default.Favorite
    LegacyMetricType.Sleep -> Icons.Default.Bedtime
    LegacyMetricType.Exercise -> Icons.Default.FitnessCenter
    LegacyMetricType.Distance -> Icons.Default.NearMe
    LegacyMetricType.Hydration -> Icons.Default.LocalDrink
    LegacyMetricType.MedAdherence -> Icons.Default.Medication
}

private fun formatLegacyValue(value: Float, type: LegacyMetricType): String = when (type) {
    LegacyMetricType.Steps -> "${value.roundToInt()}"
    LegacyMetricType.Calories -> "${value.roundToInt()}"
    LegacyMetricType.HeartRate -> "${value.roundToInt()}"
    LegacyMetricType.Sleep -> String.format("%.1f", value)
    LegacyMetricType.Exercise -> "${value.roundToInt()}"
    LegacyMetricType.Distance -> String.format("%.1f", value)
    LegacyMetricType.Hydration -> "${value.roundToInt()}"
    LegacyMetricType.MedAdherence -> "${value.roundToInt()}"
}

private fun formatAxisValue(value: Float): String =
    if (value >= 1000f) {
        val k = value / 1000f
        if (k == k.toLong().toFloat()) "${k.toLong()}k" else String.format("%.1fk", k)
    } else if (value == value.toLong().toFloat()) "${value.toLong()}"
    else String.format("%.1f", value)
```

**Step 2: Build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -40
```

Expected: `BUILD SUCCESSFUL`

If there are unused import errors or missing symbols, fix them individually — the most likely issues:
- `kotlinx.coroutines.GlobalScope.launch` in `pointerInput`: replace with a `rememberCoroutineScope()` passed in — see note below
- `FontWeight` import missing: add `import androidx.compose.ui.text.font.FontWeight`
- `PathEffect` import: add `import androidx.compose.ui.graphics.PathEffect`

**Note on GlobalScope in drag handlers:** The `GlobalScope.launch` inside `pointerInput` is a simplification for the tooltip dismiss timer. A cleaner approach is to hoist a `CoroutineScope` via `rememberCoroutineScope()` and cancel/restart a `Job` on each drag end. If the linter flags `GlobalScope`, replace with:

```kotlin
// At the start of GradientBarChart / BezierLineChart composable:
val scope = rememberCoroutineScope()
var dismissJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }

// In onDragEnd:
onDragEnd = {
    dismissJob?.cancel()
    dismissJob = scope.launch {
        kotlinx.coroutines.delay(1500)
        dragX = null
    }
}
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/analytics/HealthAnalyticsScreen.kt
git commit -m "feat(analytics): full UI redesign — hero ring, bezier charts, drag scrubber, tappable grid"
```

---

## Task 6: Final Build Verification

**Step 1: Clean build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew clean assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 2: Verify nav wiring by reading MainNavGraph.kt**

Confirm `"metric_detail/{metricType}"` composable is present and imports `HealthMetricDetailScreen`.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(analytics): complete health analytics UI redesign with detail screen"
```

---

## Summary of All Changes

| File | Change |
|------|--------|
| `HealthAnalyticsViewModel.kt` | +`MetricStats`, +`healthScore` in state, +`computeHealthScore()`, +`getMetricStats()`, +`generatePublicChartData()` |
| `HealthAnalyticsScreen.kt` | Full rewrite: LazyColumn, HeroCard with ring, TimeRangeChips LazyRow, ChartCard with metric tabs + labels, GradientBarChart + BezierLineChart with drag scrubber + tooltip, MetricCard with goal ring + tap, AIInsightsCard with pulse + gradient CTA |
| `HealthMetricDetailScreen.kt` | New: DetailTopBar, DetailBezierChart (320dp), DetailStatsRow (4 chips), DetailGoalCard (160dp ring), DetailHistoryCard (7-day bars) |
| `NavConfig.kt` | +`NavArgs.METRIC_TYPE` |
| `MainNavGraph.kt` | Updated `"health_analytics"` composable callback, +`"metric_detail/{metricType}"` composable |
