package com.swastricare.health.ui.screens.runactivity

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.swastricare.health.data.models.ActivityType
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.data.models.TimeRangeFilter
import com.swastricare.health.data.services.FitnessAnalyticsService
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.*

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
    val haptic = LocalHapticFeedback.current

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

    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 100.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            // ── Hero ──────────────────────────────────────────────────────
            item {
                HeroSection(
                    steps = uiState.todaySteps,
                    isLoading = uiState.isLoading,
                    onStartWorkout = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        onNavigateToLiveWorkout(null)
                    }
                )
            }

            // ── Time Range Selector ───────────────────────────────────────
            item {
                TimeRangeSelector(
                    selected = uiState.timeRangeFilter,
                    onSelect = { viewModel.setTimeRange(it) }
                )
            }

            // ── Metrics Row ───────────────────────────────────────────────
            item {
                MetricsRow(
                    distanceKm = uiState.statistics.totalDistanceKm,
                    calories = uiState.statistics.totalCalories,
                    workouts = uiState.statistics.totalActivities
                )
            }

            // ── Fitness Insights (compact chips) ─────────────────────────
            if (uiState.vo2Max != null || uiState.weeklyTrainingLoad > 0) {
                item {
                    FitnessChips(
                        vo2Max = uiState.vo2Max,
                        weeklyLoad = uiState.weeklyTrainingLoad,
                        loadTrend = uiState.loadTrend
                    )
                }
            }

            // ── Recent Activities ────────────────────────────────────────
            item {
                RecentActivitiesHeader(
                    count = uiState.activities.size,
                    onSeeAll = onNavigateToCalendar
                )
            }

            if (uiState.activities.isEmpty()) {
                item { EmptyActivitiesState() }
            } else {
                items(uiState.activities.take(5), key = { it.id }) { activity ->
                    ActivityCard(
                        activity = activity,
                        onClick = { onNavigateToActivityDetail(activity.id) }
                    )
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 96.dp)
        )
    }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

@Composable
private fun HeroSection(
    steps: Int,
    isLoading: Boolean,
    onStartWorkout: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.background)
            .padding(horizontal = 20.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Step count
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = "Walk & Run Activity",
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.onSurfaceVariant,
                fontWeight = FontWeight.Medium
            )
            if (isLoading) {
                Box(
                    modifier = Modifier
                        .width(160.dp)
                        .height(56.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(AppColors.surfaceVariant)
                )
            } else {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = if (steps > 0) "%,d".format(steps) else "0",
                        style = MaterialTheme.typography.displayLarge,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onBackground,
                        fontSize = 52.sp
                    )
                    Text(
                        text = "Steps",
                        style = MaterialTheme.typography.titleMedium,
                        color = AppColors.onSurfaceVariant,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.padding(bottom = 10.dp)
                    )
                }
            }
        }

        // Start Workout button — iOS style: green circle play + text + chevron
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(8.dp, RoundedCornerShape(16.dp), clip = false)
                .clip(RoundedCornerShape(16.dp))
                .clickable { onStartWorkout() },
            color = SecondaryColor.copy(alpha = 0.10f),
            shape = RoundedCornerShape(16.dp)
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(SecondaryColor.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.PlayArrow,
                        contentDescription = null,
                        tint = SecondaryColor,
                        modifier = Modifier.size(22.dp)
                    )
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Start Workout",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onBackground
                    )
                    Text(
                        text = "Track GPS, distance, and route",
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = SecondaryColor,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// ─── Time Range Selector ──────────────────────────────────────────────────────

private fun TimeRangeFilter.shortLabel(): String = when (this) {
    TimeRangeFilter.TWO_WEEKS -> "2W"
    TimeRangeFilter.ONE_MONTH -> "1M"
    TimeRangeFilter.THREE_MONTHS -> "3M"
}

@Composable
private fun TimeRangeSelector(
    selected: TimeRangeFilter,
    onSelect: (TimeRangeFilter) -> Unit
) {
    val haptic = LocalHapticFeedback.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp)
            .clip(CircleShape)
            .background(AppColors.surfaceVariant)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        TimeRangeFilter.values().forEach { filter ->
            val isSelected = filter == selected
            val bgColor by animateColorAsState(
                targetValue = if (isSelected) AppColors.onBackground else Color.Transparent,
                animationSpec = tween(200),
                label = "tabBg"
            )
            val textColor by animateColorAsState(
                targetValue = if (isSelected) AppColors.background else AppColors.onSurfaceVariant,
                animationSpec = tween(200),
                label = "tabText"
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(CircleShape)
                    .background(bgColor)
                    .clickable {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onSelect(filter)
                    }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = filter.shortLabel(),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    color = textColor
                )
            }
        }
    }
}

// ─── Metrics Row ──────────────────────────────────────────────────────────────

@Composable
private fun MetricsRow(
    distanceKm: Double,
    calories: Int,
    workouts: Int
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp)
            .shadow(4.dp, RoundedCornerShape(16.dp), clip = false)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .padding(vertical = 20.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        MetricItem(
            value = "%.2f".format(distanceKm),
            unit = "km",
            label = "Distance"
        )
        Box(
            modifier = Modifier
                .width(1.dp)
                .height(44.dp)
                .background(AppColors.outlineVariant)
        )
        MetricItem(
            value = "$calories",
            unit = "kcal",
            label = "Calories"
        )
        Box(
            modifier = Modifier
                .width(1.dp)
                .height(44.dp)
                .background(AppColors.outlineVariant)
        )
        MetricItem(
            value = "$workouts",
            unit = "",
            label = "Workouts"
        )
    }
}

@Composable
private fun MetricItem(value: String, unit: String, label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                fontSize = 26.sp
            )
            if (unit.isNotEmpty()) {
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }
    }
}

// ─── Fitness Chips ────────────────────────────────────────────────────────────

@Composable
private fun FitnessChips(
    vo2Max: Double?,
    weeklyLoad: Int,
    loadTrend: FitnessAnalyticsService.LoadTrend
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (vo2Max != null) {
            FitnessChip(icon = Icons.Default.Favorite, value = "%.1f VO₂".format(vo2Max))
        }
        if (weeklyLoad > 0) {
            FitnessChip(icon = Icons.Default.Bolt, value = "$weeklyLoad Load")
        }
        val trendLabel = when (loadTrend) {
            FitnessAnalyticsService.LoadTrend.INCREASING -> "Building ↑"
            FitnessAnalyticsService.LoadTrend.DECREASING -> "Tapering ↓"
            FitnessAnalyticsService.LoadTrend.MAINTAINING -> "Steady →"
        }
        FitnessChip(icon = Icons.Default.TrendingUp, value = trendLabel)
    }
}

@Composable
private fun FitnessChip(icon: ImageVector, value: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(AppColors.surfaceVariant)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurface
        )
    }
}

// ─── Recent Activities ────────────────────────────────────────────────────────

@Composable
private fun RecentActivitiesHeader(count: Int, onSeeAll: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 20.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "Recent Activities",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
        if (count > 5) {
            TextButton(onClick = onSeeAll, contentPadding = PaddingValues(0.dp)) {
                Text("See All", style = MaterialTheme.typography.labelMedium, color = PrimaryColor)
                Icon(
                    Icons.Default.ArrowForward,
                    contentDescription = null,
                    tint = PrimaryColor,
                    modifier = Modifier.size(14.dp)
                )
            }
        } else if (count > 0) {
            Text(
                "$count activities",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ActivityCard(activity: RunActivity, onClick: () -> Unit) {
    val typeIcon: ImageVector = when (activity.activityType) {
        ActivityType.RUNNING -> Icons.Default.DirectionsRun
        ActivityType.WALKING -> Icons.Default.DirectionsWalk
        ActivityType.CYCLING -> Icons.Default.DirectionsBike
        ActivityType.HIKING -> Icons.Default.Terrain
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 5.dp)
            .shadow(3.dp, RoundedCornerShape(16.dp), clip = false)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Icon box (map thumbnail placeholder)
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(AppColors.surfaceVariant),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = typeIcon,
                contentDescription = null,
                tint = AppColors.onSurfaceVariant,
                modifier = Modifier.size(32.dp)
            )
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(typeIcon, null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(11.dp))
                Text(
                    text = activity.formattedDate,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
            Text(
                text = activity.activityType.displayName,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (activity.caloriesBurned > 0) {
                    Text(
                        text = "${activity.caloriesBurned} kcal",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                    Text(
                        "·",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Text(
                    text = activity.formattedDistance + " km",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun EmptyActivitiesState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = Icons.Default.DirectionsWalk,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.3f),
            modifier = Modifier.size(48.dp)
        )
        Text(
            text = "No activities yet",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurfaceVariant
        )
        Text(
            text = "Start a workout to track your activities",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant.copy(alpha = 0.6f),
            textAlign = TextAlign.Center
        )
    }
}
