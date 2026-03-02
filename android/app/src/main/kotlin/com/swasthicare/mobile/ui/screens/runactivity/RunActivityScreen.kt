package com.swasthicare.mobile.ui.screens.runactivity

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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.*

private val RunGreen = Color(0xFF30D158)
private val RunBlue = Color(0xFF0A84FF)
private val RunOrange = Color(0xFFFF9F0A)

// ------------------------------------
// MARK: - Run Activity Screen (Tab)
// ------------------------------------

@Composable
fun RunActivityScreen(
    onNavigateToLiveWorkout: () -> Unit
) {
    val vm = remember { AppContainer.runActivityViewModel }
    val uiState by vm.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // Header
            Text(
                "Activity",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)
            )

            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = RunGreen)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    // Today's Metrics
                    item {
                        TodayMetricsCard(
                            steps = uiState.todaySteps,
                            distance = uiState.todayDistance,
                            calories = uiState.todayCalories,
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Time Range Selector
                    item {
                        Spacer(Modifier.height(16.dp))
                        TimeRangeSelector(
                            selected = uiState.timeRangeFilter,
                            onSelect = { vm.setTimeRange(it) },
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Statistics
                    item {
                        Spacer(Modifier.height(16.dp))
                        StatisticsRow(
                            statistics = uiState.statistics,
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Start Workout Button
                    item {
                        Spacer(Modifier.height(20.dp))
                        StartWorkoutButton(
                            onClick = onNavigateToLiveWorkout,
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Recent Activities
                    item {
                        Spacer(Modifier.height(20.dp))
                        Text(
                            "Recent Activities",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                        Spacer(Modifier.height(8.dp))
                    }

                    if (uiState.activities.isEmpty()) {
                        item {
                            EmptyActivitiesCard(
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                        }
                    } else {
                        items(uiState.activities.take(10)) { activity ->
                            ActivityCard(
                                activity = activity,
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

// ------------------------------------
// MARK: - Today's Metrics Card
// ------------------------------------

@Composable
private fun TodayMetricsCard(
    steps: Int,
    distance: Double,
    calories: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        MetricCard(
            icon = Icons.Default.DirectionsWalk,
            value = "$steps",
            label = "Steps",
            color = RunGreen,
            modifier = Modifier.weight(1f)
        )
        MetricCard(
            icon = Icons.Default.Route,
            value = String.format("%.1f", distance),
            label = "km",
            color = RunBlue,
            modifier = Modifier.weight(1f)
        )
        MetricCard(
            icon = Icons.Default.LocalFireDepartment,
            value = "$calories",
            label = "kcal",
            color = RunOrange,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun MetricCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(18.dp))
        }
        Text(
            value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// ------------------------------------
// MARK: - Time Range Selector
// ------------------------------------

@Composable
private fun TimeRangeSelector(
    selected: TimeRangeFilter,
    onSelect: (TimeRangeFilter) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 12.dp)
            .padding(4.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        TimeRangeFilter.entries.forEach { filter ->
            val isSelected = filter == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isSelected) RunGreen else Color.Transparent)
                    .clickable { onSelect(filter) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    filter.displayName,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                    color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

// ------------------------------------
// MARK: - Statistics Row
// ------------------------------------

@Composable
private fun StatisticsRow(
    statistics: ActivityStatistics,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Summary",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatItem(
                value = String.format("%.1f", statistics.totalDistanceKm),
                label = "Total km"
            )
            StatItem(
                value = statistics.formattedTotalDuration,
                label = "Duration"
            )
            StatItem(
                value = "${statistics.totalCalories}",
                label = "Calories"
            )
            StatItem(
                value = "${statistics.totalActivities}",
                label = "Workouts"
            )
        }
    }
}

@Composable
private fun StatItem(value: String, label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = RunGreen
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// ------------------------------------
// MARK: - Start Workout Button
// ------------------------------------

@Composable
private fun StartWorkoutButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "startPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.03f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "startScale"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(80.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(
                brush = Brush.horizontalGradient(
                    colors = listOf(RunGreen, RunGreen.copy(alpha = 0.7f))
                )
            )
            .clickable { onClick() }
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(Color.White.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    null,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }
            Column {
                Text(
                    "Start Workout",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    "GPS tracking with live metrics",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
}

// ------------------------------------
// MARK: - Activity Card
// ------------------------------------

@Composable
private fun ActivityCard(
    activity: RunActivity,
    modifier: Modifier = Modifier
) {
    val typeColor = when (activity.activityType) {
        ActivityType.RUNNING -> RunGreen
        ActivityType.WALKING -> RunBlue
        ActivityType.CYCLING -> RunOrange
        ActivityType.HIKING -> Color(0xFF8E8E93)
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Activity type icon
        Box(
            modifier = Modifier
                .size(44.dp)
                .background(typeColor.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(activity.activityType.emoji, fontSize = 20.sp)
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                activity.activityType.displayName,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                activity.formattedDate,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                "${activity.formattedDistance} km",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = typeColor
            )
            Text(
                activity.formattedDuration,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// ------------------------------------
// MARK: - Empty State
// ------------------------------------

@Composable
private fun EmptyActivitiesCard(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("🏃", fontSize = 48.sp)
        Text(
            "No activities yet",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Text(
            "Start a workout to begin tracking your activities",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
            textAlign = TextAlign.Center
        )
    }
}
