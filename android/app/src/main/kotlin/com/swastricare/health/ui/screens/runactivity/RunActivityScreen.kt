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
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
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

    // Selected workout type — UI-only state, not in ViewModel
    var selectedType by remember { mutableStateOf(WorkoutType.RUN) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.background)
    ) {
        // Scrollable content — bottom padding clears the fixed workout panel
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 20.dp, end = 20.dp,
                top = 16.dp, bottom = 200.dp
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
            item {
                FitnessInsightChips(
                    vo2Max = uiState.vo2Max,
                    weeklyLoad = uiState.weeklyTrainingLoad,
                    loadTrend = uiState.loadTrend
                )
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

        // Fixed bottom workout panel — always visible, not part of scroll
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

// ─── Stub composables (filled in subsequent tasks) ───────────────────────────

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
                imageVector = Icons.Default.DateRange,
                contentDescription = "Calendar",
                tint = AppColors.onSurfaceVariant
            )
        }
    }
}

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
            text = "TODAY",
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.5.sp
        )
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            HeroStatItem(
                value = if (steps > 0) "%,d".format(steps) else "—",
                label = "Steps",
                icon = Icons.Default.DirectionsWalk,
                color = RunningCyan,
                isLoading = isLoading
            )
            Box(
                modifier = Modifier
                    .height(48.dp)
                    .width(1.dp)
                    .background(AppColors.outlineVariant)
            )
            HeroStatItem(
                value = if (distanceKm > 0) "%.1f".format(distanceKm) else "—",
                label = "km",
                icon = Icons.Default.Straighten,
                color = WalkingGreen,
                isLoading = isLoading
            )
            Box(
                modifier = Modifier
                    .height(48.dp)
                    .width(1.dp)
                    .background(AppColors.outlineVariant)
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
                    .width(52.dp)
                    .height(30.dp)
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

@Composable
private fun WeeklyBarChart(activities: List<RunActivity>) {
    // Build per-day data for Mon–Sun of current week
    val today = java.time.LocalDate.now()
    val weekStart = today.minusDays((today.dayOfWeek.value - 1).toLong()) // Monday

    data class DayData(val distanceKm: Double, val type: ActivityType?)

    val dayMap: Map<Int, DayData> = (0..6).associateWith { offset ->
        val date = weekStart.plusDays(offset.toLong())
        val dayActivities = activities.filter {
            it.startTime?.toLocalDate() == date
        }
        val totalDist = dayActivities.sumOf { it.distanceKm }
        val dominant = dayActivities.maxByOrNull { it.distanceKm }?.activityType
        DayData(totalDist, dominant)
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
            text = "THIS WEEK",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurfaceVariant,
            letterSpacing = 1.5.sp
        )
        Spacer(Modifier.height(14.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.Bottom
        ) {
            dayMap.entries.sortedBy { it.key }.forEach { (offset, data) ->
                val barColor = when (data.type) {
                    ActivityType.RUNNING -> RunningCyan
                    ActivityType.WALKING -> WalkingGreen
                    ActivityType.CYCLING -> CyclingYellow
                    ActivityType.HIKING -> HikingPurple
                    null -> AppColors.outlineVariant
                }
                val heightFraction = (data.distanceKm / maxDist).toFloat().coerceIn(0.06f, 1f)
                val isToday = offset == todayOffset

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom,
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                ) {
                    // Dot above today's bar
                    if (isToday) {
                        Box(
                            modifier = Modifier
                                .size(5.dp)
                                .clip(CircleShape)
                                .background(SecondaryColor)
                        )
                        Spacer(Modifier.height(3.dp))
                    }
                    Box(
                        modifier = Modifier
                            .width(14.dp)
                            .fillMaxHeight(heightFraction)
                            .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                            .background(
                                if (isToday) barColor else barColor.copy(alpha = 0.45f)
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

@Composable
private fun FitnessInsightChips(
    vo2Max: Double?,
    weeklyLoad: Int,
    loadTrend: FitnessAnalyticsService.LoadTrend
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (vo2Max != null) {
            InsightChip(
                icon = Icons.Default.Favorite,
                value = "%.1f".format(vo2Max),
                label = "VO₂ Max",
                color = RunningCyan
            )
        }
        if (weeklyLoad > 0) {
            InsightChip(
                icon = Icons.Default.FlashOn,
                value = "$weeklyLoad",
                label = "Load",
                color = CyclingYellow
            )
        }
        val (trendIcon, trendColor, trendLabel) = when (loadTrend) {
            FitnessAnalyticsService.LoadTrend.INCREASING ->
                Triple(Icons.Default.TrendingUp, WalkingGreen, "Building")
            FitnessAnalyticsService.LoadTrend.DECREASING ->
                Triple(Icons.Default.TrendingDown, Color(0xFFFF9F0A), "Tapering")
            FitnessAnalyticsService.LoadTrend.MAINTAINING ->
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
            .background(color.copy(alpha = 0.13f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
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

@Composable
private fun RecentWorkoutsHeader(onSeeAll: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "Recent",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
        TextButton(
            onClick = onSeeAll,
            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)
        ) {
            Text(
                text = "See all",
                style = MaterialTheme.typography.labelMedium,
                color = SecondaryColor
            )
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = SecondaryColor,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

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
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun StravaWorkoutCard(
    activity: RunActivity,
    onClick: () -> Unit
) {
    val typeColor = when (activity.activityType) {
        ActivityType.RUNNING -> RunningCyan
        ActivityType.WALKING -> WalkingGreen
        ActivityType.CYCLING -> CyclingYellow
        ActivityType.HIKING -> HikingPurple
    }
    val typeIcon: ImageVector = when (activity.activityType) {
        ActivityType.RUNNING -> Icons.Default.DirectionsRun
        ActivityType.WALKING -> Icons.Default.DirectionsWalk
        ActivityType.CYCLING -> Icons.Default.DirectionsBike
        ActivityType.HIKING -> Icons.Default.Terrain
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surfaceVariant)
            .clickable { onClick() }
    ) {
        // Strava-style colored left border stripe
        Box(
            modifier = Modifier
                .width(4.dp)
                .fillMaxHeight()
                .background(typeColor)
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Icon badge
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
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
            // Text content
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${activity.formattedDistance} km",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = buildString {
                        append(activity.formattedDate)
                        append("  ·  ")
                        append(activity.formattedDuration)
                        if (activity.formattedPace != "--:--") {
                            append("  ·  ")
                            append(activity.formattedPace)
                            append("/km")
                        }
                    },
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
            // Calories
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

@Composable
private fun WorkoutPanel(
    selectedType: WorkoutType,
    onTypeSelected: (WorkoutType) -> Unit,
    onStart: () -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current

    // Pulse animation on the START button while idle
    val infiniteTransition = rememberInfiniteTransition(label = "startPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.025f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Surface(
        modifier = modifier.fillMaxWidth(),
        color = AppColors.surface,
        shadowElevation = 16.dp,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Workout type chip row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                listOf(WorkoutType.RUN, WorkoutType.WALK, WorkoutType.CYCLE, WorkoutType.HIKE).forEach { type ->
                    WorkoutChip(
                        type = type,
                        isSelected = type == selectedType,
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onTypeSelected(type)
                        },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // Pulsing START button
            Button(
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStart()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .scale(pulseScale),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SecondaryColor)
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
