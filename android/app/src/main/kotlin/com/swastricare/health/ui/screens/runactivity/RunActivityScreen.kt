package com.swastricare.health.ui.screens.runactivity

import android.Manifest
import android.os.Build
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size as GeoSize
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import android.location.LocationManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.accompanist.permissions.*
import com.swastricare.health.data.models.ActivityType
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.*
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val ScreenBackground = Color.White
private val CardSurface = Color.White
private val SoftBorder = Color(0xFFE5EAF0)
private val MintTint = Color(0xFFE6F7F2)
private val MintTintDeep = Color(0xFFD3F0E6)
private val TextPrimary = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val DividerSoft = Color(0xFFE5EAF0)

@OptIn(ExperimentalPermissionsApi::class)
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
    val context = LocalContext.current

    // ── Required permissions ──────────────────────────────────────────────────
    val permissionsToRequest = remember {
        buildList {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(Manifest.permission.ACTIVITY_RECOGNITION)
            }
        }
    }
    val permissionsState = rememberMultiplePermissionsState(permissionsToRequest)
    var showPermissionDialog by remember { mutableStateOf(false) }
    var showSettingsDialog by remember { mutableStateOf(false) }
    var showLocationServicesDialog by remember { mutableStateOf(false) }

    if (showPermissionDialog) {
        WorkoutPermissionDialog(
            onAllow = {
                showPermissionDialog = false
                if (permissionsState.shouldShowRationale) {
                    permissionsState.launchMultiplePermissionRequest()
                } else {
                    showSettingsDialog = true
                }
            },
            onDismiss = { showPermissionDialog = false }
        )
    }
    if (showSettingsDialog) {
        WorkoutPermissionSettingsDialog(onDismiss = { showSettingsDialog = false })
    }
    if (showLocationServicesDialog) {
        LocationServicesDialog(onDismiss = { showLocationServicesDialog = false })
    }

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

    // Gated workout launch — checks permissions + GPS before navigating.
    val launchWorkout: (WorkoutType?) -> Unit = { type ->
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        val locationManager = context.getSystemService(android.content.Context.LOCATION_SERVICE) as LocationManager
        val isGpsOn = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        when {
            !permissionsState.allPermissionsGranted -> {
                if (permissionsState.shouldShowRationale) {
                    showPermissionDialog = true
                } else {
                    permissionsState.launchMultiplePermissionRequest()
                }
            }
            !isGpsOn -> showLocationServicesDialog = true
            else -> onNavigateToLiveWorkout(type)
        }
    }

    val today = LocalDate.now()
    var selectedDate by remember { mutableStateOf(today) }
    val isToday = selectedDate == today
    val selectedDateActivities = remember(uiState.activities, selectedDate) {
        uiState.activities.filter { it.startTime?.toLocalDate() == selectedDate }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ScreenBackground)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            ActivityHeader(
                onBack = onNavigateBack,
                onCalendar = onNavigateToCalendar
            )

            val hasWorkoutData = uiState.activities.isNotEmpty()

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = 4.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                item {
                    DateSelectorPill(
                        selectedDate = selectedDate,
                        today = today,
                        onPrev = { selectedDate = selectedDate.minusDays(1) },
                        onNext = { if (selectedDate < today) selectedDate = selectedDate.plusDays(1) },
                        onLabelClick = onNavigateToCalendar
                    )
                }

                if (hasWorkoutData) {
                    item {
                        ActivityRingsCard(
                            steps = if (isToday) uiState.todaySteps else 0,
                            stepsGoal = 10000,
                            calories = maxOf(
                                if (isToday) uiState.todayCalories else 0,
                                selectedDateActivities.sumOf { it.caloriesBurned }
                            ),
                            caloriesGoal = 600,
                            activeMinutes = (selectedDateActivities.sumOf { it.durationSeconds } / 60).toInt(),
                            activeMinutesGoal = 90
                        )
                    }
                    item {
                        WorkoutSummaryCard(
                            sessions = uiState.activities.size,
                            totalDurationFormatted = uiState.statistics.formattedTotalDuration,
                            totalCalories = uiState.statistics.totalCalories,
                            avgHeartRate = uiState.activities.mapNotNull { it.avgHeartRate }
                                .takeIf { it.isNotEmpty() }?.average()?.toInt() ?: 0,
                            onViewAll = onNavigateToCalendar
                        )
                    }
                    item {
                        RecentWorkoutsCard(
                            activities = uiState.activities.take(3),
                            onItemClick = onNavigateToActivityDetail,
                            onViewAll = onNavigateToCalendar
                        )
                    }
                    item {
                        DailyStepsCard(
                            steps = if (isToday) uiState.todaySteps else 0,
                            goal = 10000
                        )
                    }
                    item { StartAnotherButton(onClick = { launchWorkout(null) }) }
                } else {
                    item { EmptyTodayHero(onStartWorkout = { launchWorkout(null) }) }
                    item { IdeasSectionHeader() }
                    item { IdeaCardsRow(onIdeaClick = launchWorkout) }
                    item { TipCard() }
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
        )
    }
}

// ─── Header ──────────────────────────────────────────────────────────────────

@Composable
private fun ActivityHeader(
    onBack: (() -> Unit)?,
    onCalendar: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 12.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack, modifier = Modifier.size(44.dp)) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = TextPrimary
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Activity",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary,
                lineHeight = 22.sp
            )
            Text(
                text = "Track your daily movement and progress",
                fontSize = 12.sp,
                color = TextSecondary,
                lineHeight = 14.sp
            )
        }
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(CardSurface)
                .border(1.dp, SoftBorder, CircleShape)
                .clickable { onCalendar() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.CalendarMonth,
                contentDescription = "Calendar",
                tint = AITeal,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

// ─── Date Selector ───────────────────────────────────────────────────────────

@Composable
private fun DateSelectorPill(
    selectedDate: LocalDate,
    today: LocalDate,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onLabelClick: () -> Unit
) {
    val label = remember(selectedDate, today) {
        when (selectedDate) {
            today -> "Today, " + selectedDate.format(DateTimeFormatter.ofPattern("d MMM"))
            today.minusDays(1) -> "Yesterday, " + selectedDate.format(DateTimeFormatter.ofPattern("d MMM"))
            else -> selectedDate.format(DateTimeFormatter.ofPattern("EEE, d MMM"))
        }
    }
    val canGoNext = selectedDate < today
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier
                .clip(CircleShape)
                .background(CardSurface)
                .border(1.dp, SoftBorder, CircleShape)
                .padding(horizontal = 4.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Box(
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable { onPrev() }
                    .padding(8.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronLeft,
                    contentDescription = "Previous day",
                    tint = TextSecondary,
                    modifier = Modifier.size(18.dp)
                )
            }
            Text(
                text = label,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary,
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable { onLabelClick() }
                    .padding(horizontal = 6.dp, vertical = 8.dp)
            )
            Box(
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable(enabled = canGoNext) { onNext() }
                    .padding(8.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = "Next day",
                    tint = if (canGoNext) TextSecondary else TextSecondary.copy(alpha = 0.3f),
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// ─── Empty State Hero ────────────────────────────────────────────────────────

@Composable
private fun EmptyTodayHero(onStartWorkout: () -> Unit) {
    val context = LocalContext.current
    val bitmap = remember {
        runCatching {
            context.assets.open("icons/no activity illustration 1.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .width(220.dp)
                    .height(170.dp)
            )
        }

        Text(
            text = "No activity yet today",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )

        Text(
            text = "You haven't logged any workout or movement.\nLet's get moving!",
            fontSize = 13.sp,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            lineHeight = 18.sp
        )

        Button(
            onClick = onStartWorkout,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp)
                .height(54.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Start a Workout",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

@Composable
private fun StartAnotherButton(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
    ) {
        Button(
            onClick = onClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Start another workout",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

// ─── Today Activity Card (compact) ───────────────────────────────────────────

@Composable
private fun TodayActivityCard(activity: RunActivity, onClick: () -> Unit) {
    val typeIcon: ImageVector = when (activity.activityType) {
        ActivityType.RUNNING -> Icons.Default.DirectionsRun
        ActivityType.WALKING -> Icons.Default.DirectionsWalk
        ActivityType.CYCLING -> Icons.Default.DirectionsRun
        ActivityType.HIKING -> Icons.Default.Terrain
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(MintTint),
            contentAlignment = Alignment.Center
        ) {
            Icon(typeIcon, null, tint = AITeal, modifier = Modifier.size(22.dp))
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = activity.activityType.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "${activity.formattedDistance} km · ${activity.caloriesBurned} kcal",
                fontSize = 12.sp,
                color = TextSecondary
            )
        }
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ─── Ideas Section ───────────────────────────────────────────────────────────

@Composable
private fun IdeasSectionHeader() {
    Column(modifier = Modifier.padding(horizontal = 20.dp)) {
        Text(
            text = "Ideas to get moving",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )
    }
}

private data class WorkoutIdea(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val type: WorkoutType
)

private val Ideas = listOf(
    WorkoutIdea(
        title = "Go for a Walk",
        subtitle = "Fresh air and steps",
        icon = Icons.Default.DirectionsWalk,
        type = WorkoutType.WALK
    ),
    WorkoutIdea(
        title = "Quick Run",
        subtitle = "Cardio boost",
        icon = Icons.Default.DirectionsRun,
        type = WorkoutType.RUN
    ),
    WorkoutIdea(
        title = "Outdoor Hike",
        subtitle = "Explore the trail",
        icon = Icons.Default.Terrain,
        type = WorkoutType.HIKE
    )
)

@Composable
private fun IdeaCardsRow(onIdeaClick: (WorkoutType) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Max)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Ideas.forEach { idea ->
            IdeaCard(
                idea = idea,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                onClick = { onIdeaClick(idea.type) }
            )
        }
    }
}

@Composable
private fun IdeaCard(
    idea: WorkoutIdea,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(horizontal = 6.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(MintTint),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = idea.icon,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = idea.title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary,
            textAlign = TextAlign.Center,
            maxLines = 2,
            lineHeight = 15.sp
        )
        Text(
            text = idea.subtitle,
            fontSize = 11.sp,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            maxLines = 2,
            lineHeight = 13.sp
        )
    }
}

// ─── Tip Card ────────────────────────────────────────────────────────────────

@Composable
private fun TipCard() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(MintTint)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(Color.White),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.FavoriteBorder,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Stay active, stay healthy",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "Just 30 minutes of activity can boost your mood and energy.",
                fontSize = 11.sp,
                color = TextSecondary,
                lineHeight = 14.sp
            )
        }
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ─── Permission Dialogs (Samsung-style bottom sheet) ─────────────────────────

@Composable
private fun WorkoutPermissionDialog(onAllow: () -> Unit, onDismiss: () -> Unit) {
    PermissionBottomSheet(
        title = "Permissions required",
        reason = "Allow the app to access Location and Physical Activity to track your workout.",
        body = "You won't be able to start a workout unless you grant the required permissions, " +
               "but it won't affect your use of other features. " +
               "You can always change permissions in Settings.",
        denyLabel = "Deny",
        allowLabel = "Allow",
        onDeny = onDismiss,
        onAllow = onAllow
    )
}

@Composable
private fun LocationServicesDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    PermissionBottomSheet(
        title = "Permissions required",
        reason = "Allow the app to access Location Services (GPS) to record your route and distance.",
        body = "Your GPS is currently turned off. You won't be able to start a workout until Location " +
               "Services is enabled. You can turn it on in Settings at any time.",
        denyLabel = "Deny",
        allowLabel = "Allow",
        onDeny = onDismiss,
        onAllow = {
            context.startActivity(android.content.Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS))
            onDismiss()
        }
    )
}

@Composable
private fun WorkoutPermissionSettingsDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    PermissionBottomSheet(
        title = "Permissions required",
        reason = "Allow the app to access Location and Physical Activity.",
        body = "You won't be able to use this feature unless you grant the required permissions, " +
               "but it won't affect your use of other services. " +
               "You can always restrict permissions in Settings.",
        denyLabel = "Deny",
        allowLabel = "Allow",
        onDeny = onDismiss,
        onAllow = {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                android.net.Uri.fromParts("package", context.packageName, null)
            )
            context.startActivity(intent)
            onDismiss()
        }
    )
}

@Composable
private fun PermissionBottomSheet(
    title: String,
    reason: String,
    body: String,
    denyLabel: String,
    allowLabel: String,
    onDeny: () -> Unit,
    onAllow: () -> Unit
) {
    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDeny,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(28.dp))
                    .background(AppColors.surface)
                    .padding(horizontal = 24.dp, vertical = 28.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )

                Text(
                    text = reason,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )

                Text(
                    text = body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant,
                    lineHeight = 22.sp
                )

                Spacer(Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = onDeny,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AppColors.surfaceVariant,
                            contentColor = AppColors.onSurface
                        ),
                        elevation = ButtonDefaults.buttonElevation(0.dp)
                    ) {
                        Text(denyLabel, fontWeight = FontWeight.SemiBold)
                    }
                    Button(
                        onClick = onAllow,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                        elevation = ButtonDefaults.buttonElevation(0.dp)
                    ) {
                        Text(allowLabel, fontWeight = FontWeight.SemiBold, color = Color.White)
                    }
                }

                Spacer(Modifier.navigationBarsPadding())
            }
        }
    }
}

// ─── Dashboard (when workout data is available) ──────────────────────────────

private val MoveColor = Color(0xFF22C55E)
private val StepsColor = Color(0xFF14B8A6)
private val ActiveColor = Color(0xFF8B5CF6)
private val HeartColor = Color(0xFFEF4444)

@Composable
private fun DashboardCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(20.dp))
            .padding(16.dp),
        content = content
    )
}

@Composable
private fun SectionTitleRow(title: String, onViewAll: (() -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            title,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary,
            modifier = Modifier.weight(1f)
        )
        if (onViewAll != null) {
            Row(
                modifier = Modifier.clickable { onViewAll() },
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("View all", fontSize = 12.sp, color = AITeal, fontWeight = FontWeight.Medium)
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = AITeal,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

// ── Activity Rings Card ──────────────────────────────────────────────────────

@Composable
private fun ActivityRingsCard(
    steps: Int,
    stepsGoal: Int,
    calories: Int,
    caloriesGoal: Int,
    activeMinutes: Int,
    activeMinutesGoal: Int
) {
    DashboardCard {
        SectionTitleRow(title = "Activity Rings")
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val moveTarget = (calories.toFloat() / caloriesGoal.coerceAtLeast(1)).coerceIn(0f, 1f)
            val stepsTarget = (steps.toFloat() / stepsGoal.coerceAtLeast(1)).coerceIn(0f, 1f)
            val activeTarget = (activeMinutes.toFloat() / activeMinutesGoal.coerceAtLeast(1)).coerceIn(0f, 1f)

            val animSpec: AnimationSpec<Float> = tween(durationMillis = 600, easing = FastOutSlowInEasing)
            val moveProgress by animateFloatAsState(moveTarget, animSpec, label = "moveRing")
            val stepsProgress by animateFloatAsState(stepsTarget, animSpec, label = "stepsRing")
            val activeProgress by animateFloatAsState(activeTarget, animSpec, label = "activeRing")

            val animatedCalories by animateIntAsState(
                calories, tween(600, easing = FastOutSlowInEasing), label = "cal"
            )
            val animatedSteps by animateIntAsState(
                steps, tween(600, easing = FastOutSlowInEasing), label = "steps"
            )
            val animatedActive by animateIntAsState(
                activeMinutes, tween(600, easing = FastOutSlowInEasing), label = "active"
            )
            val avgPercent = ((moveProgress + stepsProgress + activeProgress) / 3f * 100f).toInt()

            Box(
                modifier = Modifier.size(120.dp),
                contentAlignment = Alignment.Center
            ) {
                ActivityRings(
                    moveProgress = moveProgress,
                    stepsProgress = stepsProgress,
                    activeProgress = activeProgress
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "$avgPercent%",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                    Text("Goal met", fontSize = 10.sp, color = TextSecondary)
                }
            }

            Spacer(Modifier.width(16.dp))

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                RingMetricRow(
                    label = "Move",
                    value = "$animatedCalories",
                    goal = "/$caloriesGoal kcal",
                    color = MoveColor
                )
                RingMetricRow(
                    label = "Steps",
                    value = formatThousands(animatedSteps),
                    goal = "/${formatThousands(stepsGoal)}",
                    color = StepsColor
                )
                RingMetricRow(
                    label = "Active Time",
                    value = "$animatedActive",
                    goal = "/$activeMinutesGoal min",
                    color = ActiveColor
                )
            }
        }
    }
}

@Composable
private fun ActivityRings(
    moveProgress: Float,
    stepsProgress: Float,
    activeProgress: Float
) {
    Canvas(modifier = Modifier.size(120.dp)) {
        val strokeWidth = 10f
        val gap = 6f
        val outer = androidx.compose.ui.geometry.Size(size.width - strokeWidth, size.height - strokeWidth)
        val outerTopLeft = Offset(strokeWidth / 2f, strokeWidth / 2f)

        fun ringAt(inset: Float, color: Color, progress: Float) {
            val s = androidx.compose.ui.geometry.Size(outer.width - inset * 2, outer.height - inset * 2)
            val tl = Offset(outerTopLeft.x + inset, outerTopLeft.y + inset)
            // Track
            drawArc(
                color = color.copy(alpha = 0.15f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = tl,
                size = s,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
            // Progress
            drawArc(
                color = color,
                startAngle = -90f,
                sweepAngle = 360f * progress,
                useCenter = false,
                topLeft = tl,
                size = s,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
        }

        ringAt(0f, MoveColor, moveProgress)
        ringAt(strokeWidth + gap, StepsColor, stepsProgress)
        ringAt((strokeWidth + gap) * 2, ActiveColor, activeProgress)
    }
}

@Composable
private fun RingMetricRow(label: String, value: String, goal: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(color.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(color)
            )
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(label, fontSize = 11.sp, color = TextSecondary)
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    value,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )
                Text(
                    goal,
                    fontSize = 11.sp,
                    color = TextSecondary,
                    modifier = Modifier.padding(start = 2.dp, bottom = 1.dp)
                )
            }
        }
    }
}

// ── Workout Summary Card ─────────────────────────────────────────────────────

@Composable
private fun WorkoutSummaryCard(
    sessions: Int,
    totalDurationFormatted: String,
    totalCalories: Int,
    avgHeartRate: Int,
    onViewAll: () -> Unit
) {
    DashboardCard {
        SectionTitleRow(title = "Workout Summary", onViewAll = onViewAll)
        Spacer(Modifier.height(14.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            SummaryStat(
                icon = Icons.Default.DirectionsRun,
                tint = MoveColor,
                value = "$sessions",
                label = "Sessions",
                title = "Workouts",
                modifier = Modifier.weight(1f)
            )
            SummaryStat(
                icon = Icons.Default.PlayArrow,
                tint = StepsColor,
                value = totalDurationFormatted.ifBlank { "0m" },
                label = "Total",
                title = "Duration",
                modifier = Modifier.weight(1f)
            )
            SummaryStat(
                icon = Icons.Default.Terrain,
                tint = ActiveColor,
                value = "$totalCalories",
                label = "Total",
                title = "Calories",
                modifier = Modifier.weight(1f)
            )
            SummaryStat(
                icon = Icons.Default.FavoriteBorder,
                tint = HeartColor,
                value = if (avgHeartRate > 0) "$avgHeartRate" else "—",
                label = "bpm",
                title = "Avg. HR",
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun SummaryStat(
    icon: ImageVector,
    tint: Color,
    value: String,
    label: String,
    title: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.height(6.dp))
        Text(title, fontSize = 11.sp, color = TextSecondary, textAlign = TextAlign.Center)
        Text(
            value,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary,
            textAlign = TextAlign.Center
        )
        Text(label, fontSize = 10.sp, color = TextSecondary, textAlign = TextAlign.Center)
    }
}

// ── Recent Workouts Card ─────────────────────────────────────────────────────

@Composable
private fun RecentWorkoutsCard(
    activities: List<RunActivity>,
    onItemClick: (String) -> Unit,
    onViewAll: () -> Unit
) {
    DashboardCard {
        SectionTitleRow(title = "Recent Workouts", onViewAll = onViewAll)
        Spacer(Modifier.height(8.dp))
        activities.forEachIndexed { index, activity ->
            RecentWorkoutRow(activity = activity, onClick = { onItemClick(activity.id) })
            if (index < activities.lastIndex) {
                HorizontalDivider(
                    color = DividerSoft,
                    thickness = 0.5.dp,
                    modifier = Modifier.padding(start = 52.dp, top = 4.dp, bottom = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun RecentWorkoutRow(activity: RunActivity, onClick: () -> Unit) {
    val (icon, color) = when (activity.activityType) {
        ActivityType.WALKING -> Icons.Default.DirectionsWalk to MoveColor
        ActivityType.RUNNING -> Icons.Default.DirectionsRun to HeartColor
        ActivityType.CYCLING -> Icons.Default.DirectionsRun to StepsColor
        ActivityType.HIKING -> Icons.Default.Terrain to ActiveColor
    }
    val timeText = activity.startTime?.let { st ->
        val today = LocalDate.now()
        when (st.toLocalDate()) {
            today -> st.format(DateTimeFormatter.ofPattern("h:mm a"))
            today.minusDays(1) -> "Yesterday"
            else -> st.format(DateTimeFormatter.ofPattern("MMM d"))
        }
    } ?: ""

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(color.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                activity.activityType.displayName,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            val durationMin = (activity.durationSeconds / 60).toInt()
            val subtitleParts = buildList {
                if (durationMin > 0) add("${durationMin} min")
                if (activity.caloriesBurned > 0) add("${activity.caloriesBurned} kcal")
            }
            Text(
                subtitleParts.joinToString(" · ").ifBlank { "—" },
                fontSize = 12.sp,
                color = TextSecondary
            )
        }
        Text(timeText, fontSize = 12.sp, color = TextSecondary)
    }
}

// ── Daily Steps Card ─────────────────────────────────────────────────────────

@Composable
private fun DailyStepsCard(steps: Int, goal: Int) {
    val animatedSteps by animateIntAsState(
        steps, tween(600, easing = FastOutSlowInEasing), label = "dailySteps"
    )
    val targetProgress = (steps.toFloat() / goal.coerceAtLeast(1)).coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(
        targetProgress, tween(600, easing = FastOutSlowInEasing), label = "dailyStepsProgress"
    )
    DashboardCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Daily Steps",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                "${formatThousands(animatedSteps)} / ${formatThousands(goal)}",
                fontSize = 12.sp,
                color = TextSecondary
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            "${formatThousands(animatedSteps)} steps today",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = AITeal
        )
        Spacer(Modifier.height(12.dp))
        StepsBarChart(progress = animatedProgress)
    }
}

@Composable
private fun StepsBarChart(progress: Float) {
    val barHeights = remember {
        // Stylized hourly distribution — realistic shape, not real data
        listOf(
            0.05f, 0.04f, 0.03f, 0.02f, 0.02f, 0.05f,
            0.20f, 0.40f, 0.55f, 0.45f, 0.35f, 0.40f,
            0.50f, 0.45f, 0.38f, 0.55f, 0.62f, 0.78f,
            0.85f, 0.65f, 0.45f, 0.30f, 0.18f, 0.10f
        )
    }
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(72.dp)
    ) {
        val barWidth = size.width / (barHeights.size * 1.6f)
        val gap = barWidth * 0.6f
        barHeights.forEachIndexed { i, frac ->
            val h = size.height * frac * (0.6f + 0.4f * progress)
            val x = i * (barWidth + gap)
            val y = size.height - h
            drawRoundRect(
                color = AITeal.copy(alpha = 0.85f),
                topLeft = Offset(x, y),
                size = androidx.compose.ui.geometry.Size(barWidth, h),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(barWidth / 2f, barWidth / 2f)
            )
        }
    }
}

private fun formatThousands(value: Int): String {
    if (value < 1000) return value.toString()
    return "%,d".format(value)
}
