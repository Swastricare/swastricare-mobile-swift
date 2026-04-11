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
private fun WeeklyBarChart(activities: List<RunActivity>) {}

@Composable
private fun FitnessInsightChips(
    vo2Max: Double?,
    weeklyLoad: Int,
    loadTrend: FitnessAnalyticsService.LoadTrend
) {}

@Composable
private fun RecentWorkoutsHeader(onSeeAll: () -> Unit) {}

@Composable
private fun EmptyWorkoutsState() {}

@Composable
private fun StravaWorkoutCard(
    activity: RunActivity,
    onClick: () -> Unit
) {}

@Composable
private fun WorkoutPanel(
    selectedType: WorkoutType,
    onTypeSelected: (WorkoutType) -> Unit,
    onStart: () -> Unit,
    modifier: Modifier = Modifier
) {}
