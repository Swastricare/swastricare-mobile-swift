package com.swastricare.health.ui.screens.runactivity

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.ActivityType
import com.swastricare.health.data.services.FitnessAnalyticsService
import com.swastricare.health.data.models.RunActivity
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor

// ─────────────────────────────────────
// MARK: - RunActivityScreen
// ─────────────────────────────────────

@Composable
fun RunActivityScreen(
    onNavigateToLiveWorkout: (WorkoutType?) -> Unit = {},
    onNavigateToActivityDetail: (String) -> Unit = {},
    onNavigateToCalendar: () -> Unit = {},
    onNavigateBack: (() -> Unit)? = null
) {
    val viewModel: RunActivityViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()
    val haptic = LocalHapticFeedback.current

    // Refresh data when screen appears
    LaunchedEffect(Unit) { viewModel.loadData() }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            Spacer(Modifier.height(16.dp))

            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                if (onNavigateBack != null) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = AppColors.onBackground
                        )
                    }
                }

                Text(
                    "Activity",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground,
                    modifier = if (onNavigateBack == null) Modifier else Modifier
                )

                Spacer(Modifier.weight(1f))
            }

            Spacer(Modifier.height(20.dp))

            // Today's stats from Health Connect
            TodayStatsRow(
                steps = uiState.todaySteps,
                distanceKm = uiState.todayDistance,
                calories = uiState.todayCalories
            )

            // Fitness insights
            if (uiState.vo2Max != null || uiState.weeklyTrainingLoad > 0) {
                Spacer(Modifier.height(16.dp))
                FitnessCard(
                    vo2Max = uiState.vo2Max,
                    vo2MaxSource = uiState.vo2MaxSource,
                    weeklyLoad = uiState.weeklyTrainingLoad,
                    loadTrend = uiState.loadTrend
                )
            }

            Spacer(Modifier.height(20.dp))

            // Start workout hero card
            StartWorkoutCard(onClick = {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                onNavigateToLiveWorkout(null)
            })

            Spacer(Modifier.height(20.dp))

            // Quick start buttons
            Text(
                "Quick Start",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onBackground
            )

            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                QuickStartButton(
                    icon = Icons.Default.DirectionsRun,
                    label = "Run",
                    color = Color(0xFF00E5FF),
                    onClick = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onNavigateToLiveWorkout(WorkoutType.RUN)
                    },
                    modifier = Modifier.weight(1f)
                )
                QuickStartButton(
                    icon = Icons.Default.DirectionsWalk,
                    label = "Walk",
                    color = PremiumColor.NeonGreenEnd,
                    onClick = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onNavigateToLiveWorkout(WorkoutType.WALK)
                    },
                    modifier = Modifier.weight(1f)
                )
                QuickStartButton(
                    icon = Icons.Default.DirectionsBike,
                    label = "Cycle",
                    color = Color(0xFFFFD60A),
                    onClick = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onNavigateToLiveWorkout(WorkoutType.CYCLE)
                    },
                    modifier = Modifier.weight(1f)
                )
                QuickStartButton(
                    icon = Icons.Default.Terrain,
                    label = "Hike",
                    color = Color(0xFFBF5AF2),
                    onClick = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onNavigateToLiveWorkout(WorkoutType.HIKE)
                    },
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(Modifier.height(24.dp))

            // Weekly statistics
            if (uiState.statistics.totalActivities > 0) {
                WeeklyStatsCard(uiState.statistics)
                Spacer(Modifier.height(24.dp))
            }

            // Recent workouts
            Text(
                "Recent Workouts",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onBackground
            )

            Spacer(Modifier.height(12.dp))

            if (uiState.activities.isEmpty()) {
                EmptyWorkoutsCard()
            } else {
                // Show up to 10 recent workouts
                uiState.activities.take(10).forEach { activity ->
                    WorkoutHistoryCard(
                        activity = activity,
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onNavigateToActivityDetail(activity.id)
                        }
                    )
                    Spacer(Modifier.height(10.dp))
                }
            }

            // Bottom spacer for navigation bar
            Spacer(Modifier.height(120.dp))
        }
    }
}

// ─────────────────────────────────────
// MARK: - Today's Stats Row
// ─────────────────────────────────────

@Composable
private fun TodayStatsRow(steps: Int, distanceKm: Double, calories: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        TodayStatItem(
            icon = Icons.Default.DirectionsWalk,
            value = if (steps > 0) "%,d".format(steps) else "--",
            label = "Steps",
            color = Color(0xFF00E5FF)
        )
        TodayStatItem(
            icon = Icons.Default.Route,
            value = if (distanceKm > 0) "%.1f".format(distanceKm) else "--",
            label = "km",
            color = PremiumColor.NeonGreenEnd
        )
        TodayStatItem(
            icon = Icons.Default.LocalFireDepartment,
            value = if (calories > 0) "$calories" else "--",
            label = "kcal",
            color = Color(0xFFFF9F0A)
        )
    }
}

@Composable
private fun TodayStatItem(
    icon: ImageVector,
    value: String,
    label: String,
    color: Color
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = color,
            modifier = Modifier.size(20.dp)
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
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

// ─────────────────────────────────────
// MARK: - Weekly Stats Card
// ─────────────────────────────────────

@Composable
private fun WeeklyStatsCard(
    statistics: com.swastricare.health.data.models.ActivityStatistics
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            "This Period",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        Spacer(Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            StatColumn(
                value = String.format("%.1f", statistics.totalDistanceKm),
                label = "km total",
                color = PremiumColor.NeonGreenEnd
            )
            StatColumn(
                value = statistics.formattedTotalDuration,
                label = "duration",
                color = Color(0xFF00E5FF)
            )
            StatColumn(
                value = "${statistics.totalActivities}",
                label = "workouts",
                color = Color(0xFFFFD60A)
            )
            StatColumn(
                value = "${statistics.totalCalories}",
                label = "kcal",
                color = Color(0xFFFF9F0A)
            )
        }
    }
}

@Composable
private fun StatColumn(value: String, label: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - Workout History Card (Strava-like)
// ─────────────────────────────────────

@Composable
private fun WorkoutHistoryCard(
    activity: RunActivity,
    onClick: () -> Unit
) {
    val typeIcon = when (activity.activityType) {
        ActivityType.RUNNING -> Icons.Default.DirectionsRun
        ActivityType.WALKING -> Icons.Default.DirectionsWalk
        ActivityType.CYCLING -> Icons.Default.DirectionsBike
        ActivityType.HIKING -> Icons.Default.Terrain
    }

    val typeColor = when (activity.activityType) {
        ActivityType.RUNNING -> Color(0xFF00E5FF)
        ActivityType.WALKING -> PremiumColor.NeonGreenEnd
        ActivityType.CYCLING -> Color(0xFFFFD60A)
        ActivityType.HIKING -> Color(0xFFBF5AF2)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .clickable { onClick() }
            .padding(14.dp)
    ) {
        // Top row: type icon + name + date
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(typeColor.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = typeIcon,
                    contentDescription = null,
                    tint = typeColor,
                    modifier = Modifier.size(18.dp)
                )
            }

            Spacer(Modifier.width(10.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = activity.activityType.displayName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Text(
                    text = activity.formattedDate,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = AppColors.onSurfaceVariant.copy(alpha = 0.4f),
                modifier = Modifier.size(20.dp)
            )
        }

        Spacer(Modifier.height(10.dp))

        // Stats row: distance, duration, pace
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            WorkoutStatItem(
                value = activity.formattedDistance,
                label = "km"
            )
            WorkoutStatItem(
                value = activity.formattedDuration,
                label = "time"
            )
            WorkoutStatItem(
                value = activity.formattedPace,
                label = "/km"
            )
            WorkoutStatItem(
                value = "${activity.caloriesBurned}",
                label = "kcal"
            )
        }
    }
}

@Composable
private fun WorkoutStatItem(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant.copy(alpha = 0.7f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Start Workout Hero Card
// ─────────────────────────────────────

@Composable
private fun StartWorkoutCard(onClick: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition(label = "heroPulse")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(160.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(PremiumColor.NeonGreenEnd.copy(alpha = 0.85f))
            .clickable { onClick() }
    ) {
        // Decorative circle
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 40.dp, y = (-30).dp)
                .size(160.dp)
                .background(
                    Color.White.copy(alpha = glowAlpha * 0.15f),
                    CircleShape
                )
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    "Start a Workout",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    "Track your run, walk, or cycle\nwith live GPS route mapping",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }

            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = "Start",
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Quick Start Button
// ─────────────────────────────────────

@Composable
private fun QuickStartButton(
    icon: ImageVector,
    label: String,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .clickable { onClick() }
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = color,
                modifier = Modifier.size(20.dp)
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurface,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - Fitness Insights Card
// ─────────────────────────────────────

@Composable
private fun FitnessCard(
    vo2Max: Double?,
    vo2MaxSource: String,
    weeklyLoad: Int,
    loadTrend: FitnessAnalyticsService.LoadTrend
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            "Fitness Insights",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        Spacer(Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            if (vo2Max != null) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "%.1f".format(vo2Max),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF00E5FF)
                    )
                    Text(
                        "VO2 Max",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }

            if (weeklyLoad > 0) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "$weeklyLoad",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = PremiumColor.NeonGreenEnd
                    )
                    Text(
                        "Weekly Load",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val (trendIcon, trendColor, trendLabel) = when (loadTrend) {
                    FitnessAnalyticsService.LoadTrend.INCREASING ->
                        Triple(Icons.Default.TrendingUp, PremiumColor.NeonGreenEnd, "Building")
                    FitnessAnalyticsService.LoadTrend.DECREASING ->
                        Triple(Icons.Default.TrendingDown, Color(0xFFFF9F0A), "Tapering")
                    FitnessAnalyticsService.LoadTrend.MAINTAINING ->
                        Triple(Icons.Default.TrendingFlat, Color(0xFF00E5FF), "Steady")
                }
                Icon(
                    trendIcon,
                    contentDescription = null,
                    tint = trendColor,
                    modifier = Modifier.size(24.dp)
                )
                Text(
                    trendLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Empty Workouts Card
// ─────────────────────────────────────

@Composable
private fun EmptyWorkoutsCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            Icons.Default.DirectionsRun,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(48.dp)
        )
        Text(
            "No workouts yet",
            style = MaterialTheme.typography.titleSmall,
            color = AppColors.onSurfaceVariant,
            fontWeight = FontWeight.Medium
        )
        Text(
            "Start your first workout to see your\nactivity history and route maps here",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant.copy(alpha = 0.6f),
            textAlign = TextAlign.Center
        )
    }
}
