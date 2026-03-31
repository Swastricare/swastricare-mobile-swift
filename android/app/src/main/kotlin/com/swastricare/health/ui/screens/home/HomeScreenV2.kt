package com.swastricare.health.ui.screens.home

import androidx.compose.animation.core.*
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import coil.compose.AsyncImage
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.ui.components.ModelViewer
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.medications.MedicationsViewModel
import com.swastricare.health.ui.theme.*
import java.util.*
import kotlinx.coroutines.launch
import kotlin.math.*

// Default goals (same as iOS)
private const val DEFAULT_STEP_GOAL = 4000
private const val DEFAULT_CALORIE_GOAL = 300
private const val DEFAULT_ACTIVE_MINUTES_GOAL = 30
private const val DEFAULT_DISTANCE_GOAL = 5.0

@Composable
fun HomeScreenV2(
    onNavigateToMedications: () -> Unit = {},
    onNavigateToDiet: () -> Unit = {},
    onNavigateToHydration: () -> Unit = {},
    onNavigateToCycleTracker: () -> Unit = {},
    onNavigateToHeartRate: () -> Unit = {},
    onNavigateToBodyScan: () -> Unit = {},
    onNavigateToNotifications: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {},
    onNavigateToRoute: (String) -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
    medicationsViewModel: MedicationsViewModel = hiltViewModel()
) {
    TrackScreen("Home")
    val uiState by viewModel.uiState.collectAsState()
    val medicationsState by medicationsViewModel.uiState.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current

    // Load medications on mount
    LaunchedEffect(Unit) {
        medicationsViewModel.loadMedications()
    }

    // Refresh on resume
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
                medicationsViewModel.loadMedications()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    // Staggered animation
    val sectionCount = 8
    val alreadyLoaded = !uiState.isLoading
    val sectionVisible = remember { List(sectionCount) { mutableStateOf(alreadyLoaded) } }
    LaunchedEffect(uiState.isLoading) {
        if (!uiState.isLoading) {
            sectionVisible.forEachIndexed { index, state ->
                if (!state.value) {
                    kotlinx.coroutines.delay(index * 80L)
                    state.value = true
                }
            }
        }
    }

    // Compute medication counts from MedicationsViewModel (same as HomeScreen.kt)
    val allDoses = medicationsState.allDosesToday
    val medicationsTaken = allDoses.count {
        it.status == AdherenceStatus.TAKEN ||
        it.status == AdherenceStatus.LATE ||
        it.status == AdherenceStatus.EARLY
    }
    val medicationsTotal = allDoses.size

    Box(modifier = Modifier.fillMaxSize()) {

        if (uiState.isLoading) {
            HomeSkeletonLoading()
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(bottom = 76.dp)
            ) {
                // 1. Greeting Section
                StaggeredEntrance(visible = sectionVisible[0].value) {
                    GreetingSectionV2(
                        userName = uiState.userName,
                        greeting = uiState.greeting,
                        avatarUrl = uiState.userAvatarUrl,
                        onNavigateToAnalytics = onNavigateToAnalytics
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Health Connect status banner
                val showPermissionBanner = !uiState.isAuthorized
                val showNoDataBanner = uiState.isAuthorized && uiState.hasNoHealthData
                if (showPermissionBanner || showNoDataBanner) {
                    val bannerTitle = if (showPermissionBanner) "Connect Health Data" else "No Health Data Found"
                    val bannerSubtitle = if (showPermissionBanner)
                        "Grant Health Connect permissions to see your vitals"
                    else
                        "Open Google Fit or Samsung Health to start recording your activity"
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp)
                            .clickable { onNavigateToRoute("health_connect_settings") },
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1C2A3A)),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Favorite,
                                    contentDescription = null,
                                    tint = Color(0xFF4FC3F7),
                                    modifier = Modifier.size(20.dp)
                                )
                                Column {
                                    Text(
                                        text = bannerTitle,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.SemiBold,
                                        color = Color.White
                                    )
                                    Text(
                                        text = bannerSubtitle,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color.White.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Icon(
                                imageVector = Icons.Default.ChevronRight,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.5f),
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }

                // Server Nudges
                if (uiState.serverNudges.isNotEmpty()) {
                    StaggeredEntrance(visible = sectionVisible[1].value) {
                        NudgesCardStrip(
                            nudges = uiState.serverNudges,
                            onDismiss = { id -> viewModel.dismissNudge(id) }
                        )
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                }

                // 2. Daily Activity Section
                StaggeredEntrance(visible = sectionVisible[2].value) {
                    DailyActivitySectionV2(
                        stepCount = uiState.stepCount,
                        calories = uiState.calories,
                        activeMinutes = uiState.activeMinutes,
                        distance = uiState.distance
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 3. Quick Action Section (horizontal scroll)
                StaggeredEntrance(visible = sectionVisible[3].value) {
                    QuickActionSectionV2(
                        hydrationCurrent = uiState.hydrationCurrent,
                        hydrationGoal = uiState.hydrationGoal,
                        medicationsTaken = medicationsTaken,
                        medicationsTotal = medicationsTotal,
                        onNavigateToHydration = onNavigateToHydration,
                        onNavigateToMedications = onNavigateToMedications,
                        onNavigateToDiet = onNavigateToDiet,
                        onNavigateToCycleTracker = onNavigateToCycleTracker
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 4. Health Vitals Section
                StaggeredEntrance(visible = sectionVisible[4].value) {
                    HealthVitalsSectionV2(
                        sleepHours = uiState.sleepHours,
                        heartRate = uiState.heartRate,
                        activeMinutes = uiState.activeMinutes,
                        onNavigateToHeartRate = onNavigateToHeartRate
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}

// ─── Greeting Section ───────────────────────────────────────────────────────

@Composable
private fun GreetingSectionV2(
    userName: String,
    greeting: String,
    avatarUrl: String?,
    onNavigateToAnalytics: () -> Unit
) {
    var hasAppeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(100)
        hasAppeared = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (hasAppeared) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 300f),
        label = "greetingAlpha"
    )
    val offsetY by animateFloatAsState(
        targetValue = if (hasAppeared) 0f else -20f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 300f),
        label = "greetingOffset"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .graphicsLayer {
                this.alpha = alpha
                translationY = offsetY
            }
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Profile Picture
            Box(
                modifier = Modifier
                    .size(50.dp)
                    .clip(CircleShape)
                    .background(AppColors.onSurface.copy(alpha = 0.1f))
                    .border(1.dp, AppColors.onSurface.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                if (!avatarUrl.isNullOrBlank()) {
                    AsyncImage(
                        model = coil.request.ImageRequest.Builder(LocalContext.current)
                            .data(avatarUrl)
                            .crossfade(true)
                            .build(),
                        contentDescription = "Profile picture",
                        modifier = Modifier.fillMaxSize().clip(CircleShape),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = "Profile",
                        tint = AppColors.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier.size(28.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(12.dp))

            // Greeting and Name
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = greeting,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.onSurface.copy(alpha = 0.7f)
                )
                Text(
                    text = userName,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
            }

            // Analytics Button
            IconButton(
                onClick = onNavigateToAnalytics,
                modifier = Modifier.size(40.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.TrackChanges,
                    contentDescription = "Analytics",
                    tint = AppColors.onSurface,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

    }
}

// ─── Daily Activity Section ─────────────────────────────────────────────────

@Composable
private fun DailyActivitySectionV2(
    stepCount: Int,
    calories: Int,
    activeMinutes: Int,
    distance: Double
) {
    Column(modifier = Modifier.padding(horizontal = 20.dp)) {
        Text(
            text = "Daily Activity",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )

        Spacer(modifier = Modifier.height(8.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(280.dp)
        ) {
            // 3D Model (right side)
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .fillMaxHeight()
                    .fillMaxWidth(0.55f),
                contentAlignment = Alignment.BottomCenter
            ) {
                ModelViewer(
                    modelName = "anatomy.2",
                    modifier = Modifier.fillMaxSize(),
                    autoRotate = false,
                    allowInteraction = false,
                    rotationDurationMs = 8000
                )
            }

            // Stats Column (left side)
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth(0.50f)
                    .align(Alignment.CenterStart)
            ) {
                ActivityCountRowV2(
                    color = Color(0xFFEF4444),
                    label = "Steps",
                    value = "$stepCount",
                    goal = "$DEFAULT_STEP_GOAL",
                    unit = "steps"
                )
                ActivityCountRowV2(
                    color = Color(0xFFF97316),
                    label = "Calories",
                    value = "$calories",
                    goal = "$DEFAULT_CALORIE_GOAL",
                    unit = "kcal"
                )
                ActivityCountRowV2(
                    color = Color(0xFF22C55E),
                    label = "Workout",
                    value = "$activeMinutes",
                    goal = "$DEFAULT_ACTIVE_MINUTES_GOAL",
                    unit = "min"
                )
                ActivityCountRowV2(
                    color = Color(0xFF8B5CF6),
                    label = "Distance",
                    value = String.format("%.1f", distance),
                    goal = String.format("%.0f", DEFAULT_DISTANCE_GOAL),
                    unit = "km"
                )
            }
        }
    }
}

@Composable
private fun ActivityCountRowV2(
    color: Color,
    label: String,
    value: String,
    goal: String,
    unit: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Color dot
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
        )

        Column {
            Text(
                text = label,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurfaceVariant
            )
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = value,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Text(
                    text = "/$goal $unit",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ─── Activity Rings Canvas ──────────────────────────────────────────────────

@Composable
private fun ActivityRingsCanvas(
    stepsProgress: Float,
    caloriesProgress: Float,
    workoutProgress: Float,
    distanceProgress: Float
) {
    val ringWidthDp = 14.dp
    val ringGapDp = 4.dp

    // Animated progress with staggered delays
    val animatedSteps = remember { Animatable(0f) }
    val animatedCalories = remember { Animatable(0f) }
    val animatedWorkout = remember { Animatable(0f) }
    val animatedDistance = remember { Animatable(0f) }

    LaunchedEffect(stepsProgress, caloriesProgress, workoutProgress, distanceProgress) {
        launch {
            animatedSteps.animateTo(
                targetValue = stepsProgress,
                animationSpec = spring(dampingRatio = 0.65f, stiffness = 80f)
            )
        }
        launch {
            kotlinx.coroutines.delay(200)
            animatedCalories.animateTo(
                targetValue = caloriesProgress,
                animationSpec = spring(dampingRatio = 0.65f, stiffness = 80f)
            )
        }
        launch {
            kotlinx.coroutines.delay(400)
            animatedWorkout.animateTo(
                targetValue = workoutProgress,
                animationSpec = spring(dampingRatio = 0.65f, stiffness = 80f)
            )
        }
        launch {
            kotlinx.coroutines.delay(600)
            animatedDistance.animateTo(
                targetValue = distanceProgress,
                animationSpec = spring(dampingRatio = 0.65f, stiffness = 80f)
            )
        }
    }

    Canvas(modifier = Modifier.fillMaxSize()) {
        val canvasSize = size.minDimension
        val center = Offset(size.width / 2, size.height / 2)
        val ringWidthPx = ringWidthDp.toPx()
        val ringGapPx = ringGapDp.toPx()

        data class Ring(val color: Color, val progress: Float)

        val rings = listOf(
            Ring(Color(0xFFEF4444), animatedSteps.value),     // Steps - outer
            Ring(Color(0xFFF97316), animatedCalories.value),  // Calories
            Ring(Color(0xFF22C55E), animatedWorkout.value),   // Workout
            Ring(Color(0xFF8B5CF6), animatedDistance.value)   // Distance - inner
        )

        rings.forEachIndexed { index, ring ->
            val radius = (canvasSize / 2) - (index * (ringWidthPx + ringGapPx)) - ringWidthPx / 2

            // Track
            drawCircle(
                color = ring.color.copy(alpha = 0.25f),
                radius = radius,
                center = center,
                style = Stroke(width = ringWidthPx)
            )

            // Progress arc
            val sweepAngle = ring.progress * 360f
            if (sweepAngle > 0f) {
                drawArc(
                    brush = Brush.sweepGradient(
                        colors = listOf(
                            ring.color.copy(alpha = 0.6f),
                            ring.color,
                            ring.color
                        ),
                        center = center
                    ),
                    startAngle = -90f,
                    sweepAngle = sweepAngle,
                    useCenter = false,
                    style = Stroke(width = ringWidthPx, cap = StrokeCap.Round),
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
                )

                // Badge dot at tip
                if (ring.progress > 0.03f) {
                    val angleRad = (-90 + sweepAngle) * (PI / 180f)
                    val badgeX = center.x + radius * cos(angleRad).toFloat()
                    val badgeY = center.y + radius * sin(angleRad).toFloat()
                    val badgeRadius = (ringWidthPx + 5.dp.toPx()) / 2

                    drawCircle(
                        color = ring.color,
                        radius = badgeRadius,
                        center = Offset(badgeX, badgeY)
                    )
                    // White inner dot
                    drawCircle(
                        color = Color.White,
                        radius = badgeRadius * 0.42f,
                        center = Offset(badgeX, badgeY)
                    )
                }
            }
        }
    }
}

// ─── Quick Action Section ───────────────────────────────────────────────────

@Composable
private fun QuickActionSectionV2(
    hydrationCurrent: Int,
    hydrationGoal: Int,
    medicationsTaken: Int,
    medicationsTotal: Int,
    onNavigateToHydration: () -> Unit,
    onNavigateToMedications: () -> Unit,
    onNavigateToDiet: () -> Unit,
    onNavigateToCycleTracker: () -> Unit
) {
    Column {
        Text(
            text = "Quick Action",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            modifier = Modifier.padding(horizontal = 20.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Calculate card width to match the Sleep card width in Health Vitals:
        // both sections use padding(horizontal = 20.dp) and a 16.dp column gap,
        // so each card = (screenWidth - 40dp padding - 16dp gap) / 2
        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
            val cardWidth = (maxWidth - 40.dp - 16.dp) / 2
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                contentPadding = PaddingValues(horizontal = 20.dp)
            ) {
                item {
                    HydrationQuickActionCardV2(
                        current = hydrationCurrent,
                        goal = hydrationGoal,
                        onClick = onNavigateToHydration,
                        cardWidth = cardWidth
                    )
                }
                item {
                    MedicationQuickActionCardV2(
                        taken = medicationsTaken,
                        total = medicationsTotal,
                        onClick = onNavigateToMedications,
                        cardWidth = cardWidth
                    )
                }
                item {
                    DietQuickActionCardV2(onClick = onNavigateToDiet, cardWidth = cardWidth)
                }
                item {
                    CycleQuickActionCardV2(onClick = onNavigateToCycleTracker, cardWidth = cardWidth)
                }
            }
        }
    }
}

@Composable
private fun HydrationQuickActionCardV2(
    current: Int,
    goal: Int,
    onClick: () -> Unit,
    cardWidth: androidx.compose.ui.unit.Dp = 160.dp
) {
    val percentage = if (goal > 0) ((current.toFloat() / goal) * 100).toInt() else 0

    // Animated values
    val animatedCurrent by animateIntAsState(
        targetValue = current,
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "hydrationCurrent"
    )
    val animatedPercentage by animateIntAsState(
        targetValue = percentage,
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "hydrationPercentage"
    )

    Box(
        modifier = Modifier
            .width(cardWidth)
            .height(120.dp)
            .clip(RoundedCornerShape(24.dp))
            .clickable(onClick = onClick)
    ) {
        // Background
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            HydrationColor,
                            HydrationColor.copy(alpha = 0.8f)
                        )
                    )
                )
        )

        // Water wave overlay — level rises with intake
        WaterWaveOverlayV2(fillFraction = if (goal > 0) (current.toFloat() / goal).coerceIn(0f, 1f) else 0f)

        // Content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.18f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.WaterDrop,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                }
                Text(
                    text = "$animatedPercentage%",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            Column {
                Text(
                    text = "Hydration",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.9f)
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "$animatedCurrent",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        text = " / $goal ml",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.75f)
                    )
                }
            }
        }
    }
}

@Composable
private fun WaterWaveOverlayV2(fillFraction: Float = 0.5f) {
    val animatedFill by animateFloatAsState(
        targetValue = fillFraction,
        animationSpec = tween(durationMillis = 800, easing = FastOutSlowInEasing),
        label = "waterLevel"
    )

    val infiniteTransition = rememberInfiniteTransition(label = "wave")
    val waveOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "wavePhase"
    )

    Canvas(modifier = Modifier.fillMaxSize()) {
        val width = size.width
        val height = size.height
        val amp = 8.dp.toPx()
        // Water level: 0% fill = bottom, 100% fill = top
        val waterLineY = height * (1f - animatedFill)

        // Back wave
        val backPath = Path().apply {
            moveTo(0f, waterLineY)
            var x = 0f
            while (x <= width) {
                val y = waterLineY + sin(x / width * PI * 4 + waveOffset).toFloat() * amp
                lineTo(x, y)
                x += 4f
            }
            lineTo(width, height)
            lineTo(0f, height)
            close()
        }
        drawPath(backPath, Color.White.copy(alpha = 0.14f))

        // Front wave
        val frontPath = Path().apply {
            moveTo(0f, waterLineY)
            var x = 0f
            while (x <= width) {
                val y = waterLineY + sin(x / width * PI * 4 + waveOffset + 1.5f).toFloat() * (amp * 0.7f)
                lineTo(x, y)
                x += 4f
            }
            lineTo(width, height)
            lineTo(0f, height)
            close()
        }
        drawPath(frontPath, Color.White.copy(alpha = 0.10f))
    }
}

@Composable
private fun MedicationQuickActionCardV2(
    taken: Int,
    total: Int,
    onClick: () -> Unit,
    cardWidth: androidx.compose.ui.unit.Dp = 160.dp
) {
    val percentage = if (total > 0) ((taken.toFloat() / total) * 100).toInt() else 0

    Box(
        modifier = Modifier
            .width(cardWidth)
            .height(120.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFFAF52DE), Color(0xFF5856D6))
                )
            )
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Icon(
                    imageVector = Icons.Default.Medication,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = "$percentage%",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }

            Column {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "$taken",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        text = " / $total",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
                Text(
                    text = "Medication",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }
        }
    }
}

@Composable
private fun DietQuickActionCardV2(
    onClick: () -> Unit,
    cardWidth: androidx.compose.ui.unit.Dp = 160.dp
) {
    Box(
        modifier = Modifier
            .width(cardWidth)
            .height(120.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFF0EA5E9), Color(0xFF2563EB))
                )
            )
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Icon(
                imageVector = Icons.Default.Restaurant,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.9f),
                modifier = Modifier.size(18.dp)
            )

            Column {
                Text(
                    text = "Diet",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Track meals",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }
        }
    }
}

@Composable
private fun CycleQuickActionCardV2(
    onClick: () -> Unit,
    cardWidth: androidx.compose.ui.unit.Dp = 160.dp
) {
    Box(
        modifier = Modifier
            .width(cardWidth)
            .height(120.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFFEC4899), Color(0xFFBE185D))
                )
            )
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Icon(
                imageVector = Icons.Default.CalendarMonth,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.9f),
                modifier = Modifier.size(18.dp)
            )

            Column {
                Text(
                    text = "Cycle",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Track period",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }
        }
    }
}

// ─── Health Vitals Section ──────────────────────────────────────────────────

@Composable
private fun HealthVitalsSectionV2(
    sleepHours: String,
    heartRate: Int,
    activeMinutes: Int,
    onNavigateToHeartRate: () -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = 20.dp)) {
        Text(
            text = "Health Vitals",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )

        Spacer(modifier = Modifier.height(16.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Sleep Card (Left, full height 172dp)
            SleepCardV2(
                sleepHours = sleepHours,
                modifier = Modifier.weight(1f)
            )

            // Right Column (Stress + BPM)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StressLevelCardV2(
                    heartRate = heartRate,
                    activeMinutes = activeMinutes
                )
                BPMCardV2(
                    heartRate = heartRate,
                    onClick = onNavigateToHeartRate
                )
            }
        }
    }
}

@Composable
private fun SleepCardV2(
    sleepHours: String,
    modifier: Modifier = Modifier
) {
    val parsedHours = remember(sleepHours) { parseSleepHoursV2(sleepHours) }
    val sleepPercentage = remember(parsedHours) {
        minOf(100, ((parsedHours / 8.0) * 100).toInt())
    }
    val sleepHoursValue = remember(parsedHours) {
        String.format("%.0fh", parsedHours)
    }

    Box(
        modifier = modifier
            .height(172.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF1A263D), // rgb(0.1, 0.15, 0.3)
                        Color(0xFF0D0D1A)  // rgb(0.05, 0.05, 0.1)
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top section
            Column(modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp)) {
                Icon(
                    imageVector = Icons.Default.Bedtime,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "$sleepPercentage% Good Sleep",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }

            // Hours display
            Text(
                text = sleepHoursValue,
                fontSize = 48.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(start = 16.dp, top = 8.dp)
            )

            Spacer(modifier = Modifier.weight(1f))

            // Animated waveform at bottom
            SleepWaveformV2(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .padding(bottom = 16.dp)
            )
        }
    }
}

@Composable
private fun SleepWaveformV2(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "sleepWave")
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "sleepPhase"
    )

    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        val centerY = height / 2
        val amplitude = 8.dp.toPx()

        val path = Path().apply {
            moveTo(0f, centerY)
            var x = 0f
            while (x <= width) {
                val relativeX = x / width
                val y = centerY + sin(relativeX * PI * 4 + phase).toFloat() * amplitude
                lineTo(x, y)
                x += 2f
            }
        }

        drawPath(
            path = path,
            brush = Brush.horizontalGradient(
                colors = listOf(
                    Color(0xFF06B6D4).copy(alpha = 0.6f), // cyan
                    Color(0xFF3B82F6).copy(alpha = 0.4f)  // blue
                )
            ),
            style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round)
        )
    }
}

@Composable
private fun StressLevelCardV2(
    heartRate: Int,
    activeMinutes: Int
) {
    val stressLevel = remember(heartRate, activeMinutes) {
        val baseStress = 20
        val heartRateFactor = maxOf(0, minOf(30, (heartRate - 60) / 2))
        val activityFactor = maxOf(0, minOf(20, 20 - (activeMinutes / 3)))
        val stress = baseStress + heartRateFactor + activityFactor
        minOf(100, maxOf(0, 100 - stress))
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF994DCC), // purple
                        Color(0xFFFF6680)  // pink-orange
                    )
                )
            )
            .padding(horizontal = 16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxSize(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "$stressLevel% Good",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Stress Level",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }
            Icon(
                imageVector = Icons.Default.BarChart,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.9f),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
private fun BPMCardV2(
    heartRate: Int,
    onClick: () -> Unit
) {
    // Pulsing heart animation
    val infiniteTransition = rememberInfiniteTransition(label = "heartPulse")
    val heartScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "heartScale"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.Red.copy(alpha = 0.8f),
                        Color(0xFFEC4899).copy(alpha = 0.8f) // pink
                    )
                )
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxSize(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Heart Rate",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "$heartRate",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "BPM",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(24.dp)
                    .scale(heartScale)
            )
        }
    }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

private fun parseSleepHoursV2(sleepString: String): Double {
    var hours = 0.0
    var minutes = 0.0
    sleepString.split(" ").forEach { part ->
        if (part.endsWith("h")) hours = part.dropLast(1).toDoubleOrNull() ?: 0.0
        if (part.endsWith("m")) minutes = part.dropLast(1).toDoubleOrNull() ?: 0.0
    }
    return hours + (minutes / 60.0)
}
