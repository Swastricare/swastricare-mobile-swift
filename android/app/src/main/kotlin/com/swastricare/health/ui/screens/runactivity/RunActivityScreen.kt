package com.swastricare.health.ui.screens.runactivity

import android.Manifest
import android.os.Build
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import android.location.LocationManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.LocalOverscrollConfiguration
import com.google.accompanist.permissions.*
import com.swastricare.health.data.models.ActivityType
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.*
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val ScreenBackground = Color.White
private val CardSurface = Color.White
private val SoftBorder = Color(0xFFE9EEF3)
private val MintTint = Color(0xFFE6F7F2)
private val MintTintDeep = Color(0xFFD3F0E6)
private val TextPrimary = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF6B7280)
private val DividerSoft = Color(0xFFEEF1F5)

// Highlight tile tints — soft pastel backgrounds
private val TintMint = Color(0xFFE6F7F2)
private val TintBlue = Color(0xFFE6F0FF)
private val TintAmber = Color(0xFFFFF1DC)
private val TintPink = Color(0xFFFDE6EE)

// Activity row tints
private val RunTint = Color(0xFFE6F4EA)
private val WalkTint = Color(0xFFFFF1DC)
private val CycleTint = Color(0xFFE6F0FF)
private val HikeTint = Color(0xFFEDE9FE)

@OptIn(ExperimentalPermissionsApi::class, ExperimentalFoundationApi::class, ExperimentalAnimationApi::class)
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
    var swipeHintPlayed by remember { mutableStateOf(false) }
    val isToday = selectedDate == today

    LaunchedEffect(selectedDate) {
        if (selectedDate != today) viewModel.loadDaySummary(selectedDate)
    }

    val selectedDateActivities = remember(uiState.activities, selectedDate) {
        uiState.activities.filter { it.startTime?.toLocalDate() == selectedDate }
    }
    val selectedDaySummary = uiState.daySummaries[selectedDate]
    val displaySteps = if (isToday) uiState.todaySteps else selectedDaySummary?.steps ?: 0
    val displayCalories = maxOf(
        if (isToday) uiState.todayCalories else selectedDaySummary?.activeCalories ?: 0,
        selectedDateActivities.sumOf { it.caloriesBurned }
    )
    val displayActiveMinutes = maxOf(
        if (isToday) 0 else selectedDaySummary?.exerciseMinutes ?: 0,
        (selectedDateActivities.sumOf { it.durationSeconds } / 60).toInt()
    )
    val displayDistanceKm = maxOf(
        if (isToday) uiState.todayDistance else selectedDaySummary?.distanceKm ?: 0.0,
        selectedDateActivities.sumOf { it.distanceKm }
    )
    val highlightsTitle = when (selectedDate) {
        today -> "Today's Highlights"
        today.minusDays(1) -> "Yesterday's Highlights"
        else -> selectedDate.format(DateTimeFormatter.ofPattern("EEE, d MMM")) + " Highlights"
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ScreenBackground)
    ) {
        CompositionLocalProvider(LocalOverscrollConfiguration provides null) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                ActivityHeroHeader(
                    onBack = onNavigateBack,
                    onCalendar = onNavigateToCalendar
                )
            }

            item {
                MoveGoalCard(
                    selectedDate = selectedDate,
                    today = today,
                    activities = uiState.activities,
                    todaySteps = uiState.todaySteps,
                    todayCalories = uiState.todayCalories,
                    todayDistanceKm = uiState.todayDistance,
                    daySummaries = uiState.daySummaries,
                    goals = uiState.goals,
                    showSwipeHint = !swipeHintPlayed,
                    onSwipeHintComplete = { swipeHintPlayed = true },
                    onPrevDay = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        selectedDate = selectedDate.minusDays(1)
                    },
                    onNextDay = {
                        if (selectedDate < today) {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            selectedDate = selectedDate.plusDays(1)
                        }
                    }
                )
            }

            item {
                StreakCard(
                    streakDays = computeStreak(uiState.activities, today),
                    activeWeekdays = computeActiveWeekdays(uiState.activities, today)
                )
            }

            item {
                Text(
                    text = highlightsTitle,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            item {
                HighlightsGrid(
                    steps = displaySteps,
                    activeMinutes = displayActiveMinutes,
                    calories = displayCalories,
                    distanceKm = displayDistanceKm
                )
            }

            item {
                RecentActivitiesHeader(onViewAll = onNavigateToCalendar)
            }

            if (uiState.activities.isNotEmpty()) {
                item {
                    RecentActivitiesList(
                        activities = uiState.activities.take(4),
                        onItemClick = onNavigateToActivityDetail
                    )
                }
            } else {
                item {
                    EmptyActivitiesPrompt(onStart = { launchWorkout(null) })
                }
            }
        }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
        )
    }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

@Composable
private fun ActivityHeroHeader(
    onBack: (() -> Unit)?,
    onCalendar: () -> Unit
) {
    val context = LocalContext.current
    val heroBitmap = remember {
        runCatching {
            context.assets.open("images/activity screen hero.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(
                RoundedCornerShape(
                    topStart = 0.dp,
                    topEnd = 0.dp,
                    bottomStart = 36.dp,
                    bottomEnd = 36.dp
                )
            )
    ) {
        // Hero illustration aligned to the right, full-bleed top
        if (heroBitmap != null) {
            Image(
                bitmap = heroBitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.FillHeight,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .fillMaxHeight()
            )
            // Top fade overlay — blends the illustration's top edge into the white screen background
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .height(70.dp)
                    .background(
                        Brush.verticalGradient(
                            0.0f to ScreenBackground,
                            0.45f to ScreenBackground.copy(alpha = 0.85f),
                            1.0f to ScreenBackground.copy(alpha = 0f)
                        )
                    )
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 12.dp, top = 12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f)) {
                if (onBack != null) {
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier
                            .size(40.dp)
                            .offset(x = (-8).dp)
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = TextPrimary
                        )
                    }
                }
                Text(
                    text = "Activity",
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary,
                    lineHeight = 36.sp
                )
                Text(
                    text = "Track your daily movement\nand progress",
                    fontSize = 13.sp,
                    color = TextSecondary,
                    lineHeight = 17.sp
                )
            }

            Box(
                modifier = Modifier
                    .size(36.dp)
                    .shadow(elevation = 5.dp, shape = CircleShape, clip = false)
                    .clip(CircleShape)
                    .background(Color.White)
                    .clickable { onCalendar() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.CalendarMonth,
                    contentDescription = "Calendar",
                    tint = AITeal,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// ─── Move Goal Card (swipeable) ──────────────────────────────────────────────

@OptIn(ExperimentalAnimationApi::class)
@Composable
private fun MoveGoalCard(
    selectedDate: LocalDate,
    today: LocalDate,
    activities: List<RunActivity>,
    todaySteps: Int,
    todayCalories: Int,
    todayDistanceKm: Double,
    daySummaries: Map<LocalDate, com.swastricare.health.data.services.HealthConnectService.DailyHealthSummary>,
    goals: com.swastricare.health.data.models.ActivityGoals,
    showSwipeHint: Boolean,
    onSwipeHintComplete: () -> Unit,
    onPrevDay: () -> Unit,
    onNextDay: () -> Unit
) {
    var totalDrag by remember { mutableStateOf(0f) }
    val density = LocalDensity.current
    val dragThreshold = with(density) { 60.dp.toPx() }

    // Swipe hint nudge — runs once on first appearance
    val nudgeOffset = remember { Animatable(0f) }
    LaunchedEffect(showSwipeHint) {
        if (showSwipeHint) {
            delay(700)
            val px = with(density) { 18.dp.toPx() }
            nudgeOffset.animateTo(px, tween(360, easing = FastOutSlowInEasing))
            nudgeOffset.animateTo(-px, tween(480, easing = FastOutSlowInEasing))
            nudgeOffset.animateTo(0f, tween(360, easing = FastOutSlowInEasing))
            onSwipeHintComplete()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .offset { IntOffset(nudgeOffset.value.toInt(), 0) }
            .pointerInput(selectedDate, today) {
                detectHorizontalDragGestures(
                    onDragEnd = {
                        if (totalDrag > dragThreshold) onPrevDay()
                        else if (totalDrag < -dragThreshold) onNextDay()
                        totalDrag = 0f
                    },
                    onDragCancel = { totalDrag = 0f }
                ) { _, dragAmount -> totalDrag += dragAmount }
            }
    ) {
        AnimatedContent(
            targetState = selectedDate,
            transitionSpec = {
                val forward = targetState.isAfter(initialState)
                if (forward) {
                    (slideInHorizontally(tween(320)) { it } + fadeIn(tween(220)))
                        .togetherWith(slideOutHorizontally(tween(320)) { -it } + fadeOut(tween(220)))
                } else {
                    (slideInHorizontally(tween(320)) { -it } + fadeIn(tween(220)))
                        .togetherWith(slideOutHorizontally(tween(320)) { it } + fadeOut(tween(220)))
                }
            },
            label = "moveGoalSwipe"
        ) { date ->
            val isToday = date == today
            val dayActivities = activities.filter { it.startTime?.toLocalDate() == date }
            val daySummary = daySummaries[date]
            val baseSteps = if (isToday) todaySteps else daySummary?.steps ?: 0
            val baseCalories = if (isToday) todayCalories else daySummary?.activeCalories ?: 0
            val baseDistance = if (isToday) todayDistanceKm else daySummary?.distanceKm ?: 0.0
            val calories = maxOf(baseCalories, dayActivities.sumOf { it.caloriesBurned })
            val steps = baseSteps
            val activeMinutes = maxOf(
                if (isToday) 0 else daySummary?.exerciseMinutes ?: 0,
                (dayActivities.sumOf { it.durationSeconds } / 60).toInt()
            )
            val distanceKm = maxOf(baseDistance, dayActivities.sumOf { it.distanceKm })
            val dateLabel = when (date) {
                today -> "Today"
                today.minusDays(1) -> "Yesterday"
                else -> date.format(DateTimeFormatter.ofPattern("EEE, d MMM"))
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(CardSurface)
                    .border(1.dp, SoftBorder, RoundedCornerShape(20.dp))
                    .padding(horizontal = 16.dp, vertical = 16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "Move Goal",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        dateLabel,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextSecondary
                    )
                }
                Spacer(Modifier.height(12.dp))
                MoveGoalContent(
                    calories = calories,
                    caloriesGoal = goals.dailyCaloriesGoal,
                    steps = steps,
                    stepsGoal = goals.dailyStepsGoal,
                    activeMinutes = activeMinutes,
                    activeMinutesGoal = goals.dailyActiveMinutes,
                    distanceKm = distanceKm,
                    distanceGoalKm = goals.dailyDistanceKm
                )
            }
        }
    }
}

@Composable
private fun MoveGoalContent(
    calories: Int,
    caloriesGoal: Int,
    steps: Int,
    stepsGoal: Int,
    activeMinutes: Int,
    activeMinutesGoal: Int,
    distanceKm: Double,
    distanceGoalKm: Double
) {
    val moveTarget = (calories.toFloat() / caloriesGoal.coerceAtLeast(1)).coerceIn(0f, 1f)
    val animSpec: AnimationSpec<Float> = tween(durationMillis = 600, easing = FastOutSlowInEasing)
    val moveProgress by animateFloatAsState(moveTarget, animSpec, label = "moveRing")
    val animatedCalories by animateIntAsState(
        calories, tween(600, easing = FastOutSlowInEasing), label = "cal"
    )

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.size(130.dp),
            contentAlignment = Alignment.Center
        ) {
            MoveRing(progress = moveProgress)
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "$animatedCalories",
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary,
                    lineHeight = 32.sp
                )
                Text(
                    "of $caloriesGoal kcal",
                    fontSize = 10.sp,
                    color = TextSecondary
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "${(moveProgress * 100).toInt()}%",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AITeal
                )
            }
        }

        Spacer(Modifier.width(14.dp))

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            MoveMetricRow(
                icon = Icons.Outlined.DirectionsRun,
                iconTint = AITeal,
                label = "Steps",
                value = formatThousands(steps),
                goal = "/${formatThousands(stepsGoal)}",
                progress = (steps.toFloat() / stepsGoal.coerceAtLeast(1)).coerceIn(0f, 1f),
                barColor = AITeal
            )
            MoveMetricRow(
                icon = Icons.Default.Schedule,
                iconTint = Color(0xFFEF8B3C),
                label = "Active Time",
                value = "$activeMinutes",
                goal = "/$activeMinutesGoal min",
                progress = (activeMinutes.toFloat() / activeMinutesGoal.coerceAtLeast(1)).coerceIn(0f, 1f),
                barColor = Color(0xFFEF8B3C)
            )
            MoveMetricRow(
                icon = Icons.Default.Place,
                iconTint = Color(0xFFEAB308),
                label = "Distance",
                value = String.format("%.2f", distanceKm),
                goal = "/${distanceGoalKm.toInt()} km",
                progress = (distanceKm / distanceGoalKm.coerceAtLeast(0.001)).toFloat().coerceIn(0f, 1f),
                barColor = Color(0xFFEAB308)
            )
        }
    }
}

@Composable
private fun MoveRing(progress: Float) {
    Canvas(modifier = Modifier.size(130.dp)) {
        val strokeWidth = 14f
        val tl = Offset(strokeWidth / 2f, strokeWidth / 2f)
        val s = androidx.compose.ui.geometry.Size(size.width - strokeWidth, size.height - strokeWidth)
        // Track
        drawArc(
            color = Color(0xFFE6F4EA),
            startAngle = -90f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = tl,
            size = s,
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
        )
        // Progress arc with gradient
        drawArc(
            brush = Brush.sweepGradient(
                colors = listOf(
                    Color(0xFF22C5A6),
                    Color(0xFF22C55E),
                    Color(0xFF22C5A6)
                ),
                center = androidx.compose.ui.geometry.Offset(size.width / 2f, size.height / 2f)
            ),
            startAngle = -90f,
            sweepAngle = 360f * progress,
            useCenter = false,
            topLeft = tl,
            size = s,
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
        )
    }
}

@Composable
private fun MoveMetricRow(
    icon: ImageVector,
    iconTint: Color,
    label: String,
    value: String,
    goal: String,
    progress: Float,
    barColor: Color
) {
    val animatedProgress by animateFloatAsState(
        progress, tween(600, easing = FastOutSlowInEasing), label = "metricBar"
    )
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(iconTint.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = iconTint, modifier = Modifier.size(13.dp))
            }
            Spacer(Modifier.width(8.dp))
            Text(
                label,
                fontSize = 12.sp,
                color = TextSecondary,
                modifier = Modifier.weight(1f)
            )
            Text(
                buildString {
                    append(value)
                    append(" ")
                    append(goal)
                },
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
        }
        // Mini progress bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(5.dp)
                .clip(CircleShape)
                .background(Color(0xFFEFF3F7))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(animatedProgress)
                    .fillMaxHeight()
                    .clip(CircleShape)
                    .background(barColor)
            )
        }
    }
}

// ─── Streak Card ─────────────────────────────────────────────────────────────

@Composable
private fun StreakCard(streakDays: Int, activeWeekdays: Set<DayOfWeek>) {
    val context = LocalContext.current
    val streakBitmap = remember {
        runCatching {
            context.assets.open("icons/activity streak icon.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    val gradient = Brush.linearGradient(
        colors = listOf(Color(0xFF1FB495), Color(0xFF14A07F))
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(gradient)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (streakBitmap != null) {
            Image(
                bitmap = streakBitmap.asImageBitmap(),
                contentDescription = null,
                modifier = Modifier.size(36.dp)
            )
        } else {
            Icon(
                imageVector = Icons.Default.Shield,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(28.dp)
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                "$streakDays Day Streak!",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                "Keep up the great work",
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.85f)
            )
        }
        Spacer(Modifier.width(8.dp))
        WeekdayPills(activeWeekdays)
    }
}

@Composable
private fun WeekdayPills(activeDays: Set<DayOfWeek>) {
    val labels = listOf(
        DayOfWeek.MONDAY to "M",
        DayOfWeek.TUESDAY to "T",
        DayOfWeek.WEDNESDAY to "W",
        DayOfWeek.THURSDAY to "T",
        DayOfWeek.FRIDAY to "F",
        DayOfWeek.SATURDAY to "S",
        DayOfWeek.SUNDAY to "S"
    )
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        labels.forEach { (day, label) ->
            val active = day in activeDays
            Box(
                modifier = Modifier
                    .size(width = 18.dp, height = 22.dp)
                    .clip(CircleShape)
                    .background(
                        if (active) Color.White else Color.White.copy(alpha = 0.22f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    label,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (active) Color(0xFF1FB495) else Color.White
                )
            }
        }
    }
}

// ─── Today's Highlights ──────────────────────────────────────────────────────

@Composable
private fun HighlightsGrid(
    steps: Int,
    activeMinutes: Int,
    calories: Int,
    distanceKm: Double
) {
    val animSpec: AnimationSpec<Float> = tween(durationMillis = 500, easing = FastOutSlowInEasing)
    val animatedSteps by animateIntAsState(
        steps, tween(500, easing = FastOutSlowInEasing), label = "hlSteps"
    )
    val animatedActive by animateIntAsState(
        activeMinutes, tween(500, easing = FastOutSlowInEasing), label = "hlActive"
    )
    val animatedCalories by animateIntAsState(
        calories, tween(500, easing = FastOutSlowInEasing), label = "hlCal"
    )
    val animatedDistance by animateFloatAsState(
        distanceKm.toFloat(), animSpec, label = "hlDist"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HighlightTile(
                icon = Icons.Outlined.DirectionsRun,
                iconTint = AITeal,
                bgTint = TintMint,
                value = formatThousands(animatedSteps),
                label = "Steps",
                modifier = Modifier.weight(1f)
            )
            HighlightTile(
                icon = Icons.Default.Schedule,
                iconTint = Color(0xFF3B82F6),
                bgTint = TintBlue,
                value = "$animatedActive",
                label = "Min Active",
                modifier = Modifier.weight(1f)
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HighlightTile(
                icon = Icons.Default.LocalFireDepartment,
                iconTint = Color(0xFFEF8B3C),
                bgTint = TintAmber,
                value = "$animatedCalories",
                label = "kcal Burned",
                modifier = Modifier.weight(1f)
            )
            HighlightTile(
                icon = Icons.Default.Place,
                iconTint = Color(0xFFE11D74),
                bgTint = TintPink,
                value = String.format("%.2f", animatedDistance),
                label = "km",
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun HighlightTile(
    icon: ImageVector,
    iconTint: Color,
    bgTint: Color,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(18.dp))
            .padding(horizontal = 12.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(CircleShape)
                .background(bgTint),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = iconTint, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(
                value,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary,
                lineHeight = 18.sp
            )
            Text(
                label,
                fontSize = 11.sp,
                color = TextSecondary
            )
        }
    }
}

// ─── Recent Activities ───────────────────────────────────────────────────────

@Composable
private fun RecentActivitiesHeader(onViewAll: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "Recent Activities",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            modifier = Modifier.weight(1f)
        )
        Row(
            modifier = Modifier.clickable { onViewAll() },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("View all", fontSize = 12.sp, color = AITeal, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun RecentActivitiesList(
    activities: List<RunActivity>,
    onItemClick: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        activities.forEach { activity ->
            ActivityRow(activity = activity, onClick = { onItemClick(activity.id) })
        }
    }
}

@Composable
private fun ActivityRow(activity: RunActivity, onClick: () -> Unit) {
    val (icon, color, bg, title) = when (activity.activityType) {
        ActivityType.RUNNING -> Quad(
            Icons.Default.DirectionsRun, Color(0xFF22C55E), RunTint, runTitleFor(activity)
        )
        ActivityType.WALKING -> Quad(
            Icons.Default.DirectionsWalk, Color(0xFFEF8B3C), WalkTint, walkTitleFor(activity)
        )
        ActivityType.CYCLING -> Quad(
            Icons.AutoMirrored.Filled.DirectionsBike, Color(0xFF3B82F6), CycleTint, "Cycling"
        )
        ActivityType.HIKING -> Quad(
            Icons.Default.Terrain, Color(0xFF8B5CF6), HikeTint, "Hiking"
        )
    }

    val timeText = activity.startTime?.let { st ->
        val today = LocalDate.now()
        when (st.toLocalDate()) {
            today -> st.format(DateTimeFormatter.ofPattern("h:mm a"))
            today.minusDays(1) -> "Yesterday"
            else -> st.format(DateTimeFormatter.ofPattern("MMM d"))
        }
    } ?: ""

    val durationFormatted = activity.formattedDuration
    val subtitle = buildString {
        append(activity.formattedDistance)
        append(" km · ")
        append(durationFormatted)
        if (activity.activityType == ActivityType.CYCLING) {
            val avgKmh = if (activity.durationSeconds > 0) {
                activity.distanceKm / (activity.durationSeconds / 3600.0)
            } else 0.0
            append(" · ")
            append(String.format("%.1f km/h", avgKmh))
        } else if (activity.distanceKm > 0) {
            append(" · ")
            append(activity.formattedPace)
            append("/km")
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(18.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(bg),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(22.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                subtitle,
                fontSize = 11.sp,
                color = TextSecondary
            )
        }
        Text(
            timeText,
            fontSize = 11.sp,
            color = TextSecondary
        )
    }
}

@Composable
private fun EmptyActivitiesPrompt(onStart: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(MintTint)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "No activities yet",
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        Text(
            "Start a workout to see it here.",
            fontSize = 12.sp,
            color = TextSecondary,
            textAlign = TextAlign.Center
        )
        Button(
            onClick = onStart,
            modifier = Modifier
                .padding(top = 4.dp)
                .height(44.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(6.dp))
            Text(
                "Start a Workout",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

private data class Quad(
    val icon: ImageVector,
    val color: Color,
    val bg: Color,
    val title: String
)

private fun runTitleFor(activity: RunActivity): String {
    val hour = activity.startTime?.hour ?: return "Run"
    return when (hour) {
        in 5..11 -> "Morning Run"
        in 12..16 -> "Afternoon Run"
        in 17..20 -> "Evening Run"
        else -> "Night Run"
    }
}

private fun walkTitleFor(activity: RunActivity): String {
    val hour = activity.startTime?.hour ?: return "Walk"
    return when (hour) {
        in 5..11 -> "Morning Walk"
        in 12..16 -> "Afternoon Walk"
        in 17..20 -> "Evening Walk"
        else -> "Night Walk"
    }
}

private fun computeStreak(activities: List<RunActivity>, today: LocalDate): Int {
    val days = activities.mapNotNull { it.startTime?.toLocalDate() }.toSet()
    if (days.isEmpty()) return 0
    var streak = 0
    var cursor = today
    while (cursor in days) {
        streak++
        cursor = cursor.minusDays(1)
    }
    if (streak == 0 && today.minusDays(1) in days) {
        // Allow yesterday-based streak when no workout today
        cursor = today.minusDays(1)
        while (cursor in days) {
            streak++
            cursor = cursor.minusDays(1)
        }
    }
    return streak
}

private fun computeActiveWeekdays(activities: List<RunActivity>, today: LocalDate): Set<DayOfWeek> {
    val weekStart = today.minusDays((today.dayOfWeek.value - 1).toLong())
    val weekEnd = weekStart.plusDays(6)
    return activities.mapNotNull { it.startTime?.toLocalDate() }
        .filter { it in weekStart..weekEnd }
        .map { it.dayOfWeek }
        .toSet()
}

private fun formatThousands(value: Int): String {
    if (value < 1000) return value.toString()
    return "%,d".format(value)
}

// ─── Permission Dialogs (unchanged) ──────────────────────────────────────────

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
