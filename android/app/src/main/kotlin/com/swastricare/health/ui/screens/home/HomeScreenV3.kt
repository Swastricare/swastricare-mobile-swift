package com.swastricare.health.ui.screens.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.MonitorWeight
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.ui.draw.rotate
import androidx.compose.runtime.*
import kotlinx.coroutines.delay
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.health.connect.client.PermissionController
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.medications.MedicationsViewModel
import com.swastricare.health.ui.screens.auth.components.PremiumColors

private val PageBg = Color(0xFFF6FAFC)
private val PageGradient = Brush.verticalGradient(
    colorStops = arrayOf(
        0f to Color(0xFFF6FAFC),
        0.35f to Color(0xFFF6FAFC),
        0.55f to Color.White,
        1f to Color.White
    )
)
private val DarkText = Color(0xFF0F172A)
private val MutedText = Color(0xFF6B7280)
private val SubtleBorder = Color.Black.copy(alpha = 0.06f)
private val RingTrack = Color(0xFFE5E7EB)

private val HydrationTint = Color(0xFFEFF8FE)  // very light blue
private val HydrationAccent = Color(0xFF38BDF8)
private val MedicationTint = Color(0xFFF1FBF7)  // very light teal
private val MedicationAccent = PremiumColors.Teal
private val CycleTint = Color(0xFFFDF1F7)       // very light pink
private val CycleAccent = Color(0xFFF472B6)
private val DietTint = Color(0xFFFEF8E1)        // very light cream/yellow
private val DietAccent = Color(0xFFF59E0B)

private val CalorieAccent = Color(0xFFEF4444)
private val DistanceAccent = Color(0xFF38BDF8)
private val ActiveAccent = Color(0xFF8B5CF6)

@Composable
fun HomeScreenV3(
    onNavigateToMedications: () -> Unit = {},
    onNavigateToDiet: () -> Unit = {},
    onNavigateToHydration: () -> Unit = {},
    onNavigateToCycleTracker: () -> Unit = {},
    onNavigateToHeartRate: () -> Unit = {},
    onNavigateToStress: () -> Unit = {},
    onNavigateToSleep: () -> Unit = {},
    onNavigateToBodyScan: () -> Unit = {},
    onNavigateToNotifications: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {},
    onNavigateToAIChat: () -> Unit = {},
    onNavigateToRoute: (String) -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
    medicationsViewModel: MedicationsViewModel = hiltViewModel()
) {
    TrackScreen("Home")
    val uiState by viewModel.uiState.collectAsState()
    val medicationsState by medicationsViewModel.uiState.collectAsState()

    LaunchedEffect(Unit) { medicationsViewModel.loadMedications() }
    LaunchedEffect(Unit) { viewModel.refreshActivityGoals() }

    // Health Connect permission launcher — opens the system HC dialog directly.
    val healthPermissionLauncher = rememberLauncherForActivityResult(
        contract = PermissionController.createRequestPermissionResultContract()
    ) { grantedPermissions ->
        viewModel.onHealthPermissionsResult(grantedPermissions)
    }

    // Auto-prompt Health Connect once per process when permissions are missing.
    var hasAutoPromptedHealth by remember { mutableStateOf(false) }
    LaunchedEffect(uiState.needsHealthPermissions, uiState.healthConnectAvailable) {
        if (
            !hasAutoPromptedHealth &&
            uiState.needsHealthPermissions &&
            uiState.healthConnectAvailable
        ) {
            hasAutoPromptedHealth = true
            delay(400)
            try {
                healthPermissionLauncher.launch(HealthConnectService.ALL_PERMISSIONS)
                viewModel.markHealthPermissionsPrompted()
            } catch (e: Exception) {
                android.util.Log.w("HomeScreenV3", "HC permission launch failed: ${e.message}")
            }
        }
    }

    var isRefreshing by remember { mutableStateOf(false) }

    LaunchedEffect(isRefreshing) {
        if (isRefreshing) {
            delay(1500)
            isRefreshing = false
        }
    }

    val infiniteTransition = rememberInfiniteTransition(label = "refresh")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(700, easing = LinearEasing)),
        label = "refreshRotation"
    )

    val takenCount = medicationsState.allDosesToday.count {
        it.status == AdherenceStatus.TAKEN ||
            it.status == AdherenceStatus.LATE ||
            it.status == AdherenceStatus.EARLY
    }
    val totalDoses = medicationsState.allDosesToday.size

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        val screenWidth = maxWidth
        // Compact / regular threshold so we adjust spacing on small screens
        val isCompact = maxHeight < 720.dp
        val ringSize = (screenWidth * 0.34f).coerceIn(110.dp, 150.dp)
        val sectionGap: Dp = if (isCompact) 12.dp else 18.dp

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
        ) {
            HeaderSection(
                userName = uiState.userName.ifBlank { "there" },
                greeting = uiState.greeting,
                avatarUrl = uiState.userAvatarUrl,
                onNotifications = onNavigateToNotifications
            )

            Spacer(Modifier.height(sectionGap - 10.dp))

            DailyActivityCard(
                steps = uiState.stepCount,
                stepGoal = uiState.activityGoals.dailyStepsGoal,
                calories = uiState.calories,
                calorieGoal = uiState.activityGoals.dailyCaloriesGoal,
                distance = uiState.distance,
                distanceGoal = uiState.activityGoals.dailyDistanceKm,
                activeMinutes = uiState.activeMinutes,
                activeMinutesGoal = uiState.activityGoals.dailyActiveMinutes,
                ringSize = ringSize,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(Modifier.height(sectionGap))

            SectionHeader(title = "Quick Actions")
            Spacer(Modifier.height(8.dp))
            QuickActionsRow(
                onHydration = onNavigateToHydration,
                onMedication = onNavigateToMedications,
                onCycle = onNavigateToCycleTracker,
                onDiet = onNavigateToDiet,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(Modifier.height(sectionGap))

            SectionHeader(
                title = "Health Vitals",
                trailing = {
                    Text(
                        "View All",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = PremiumColors.Teal,
                        modifier = Modifier.clickable { onNavigateToAnalytics() }
                    )
                }
            )
            Spacer(Modifier.height(8.dp))
            HealthVitalsCard(
                heartRate = uiState.heartRate,
                bloodOxygen = 98,
                sleepHours = uiState.sleepHours,
                weight = 60.5,
                onHeartRate = onNavigateToHeartRate,
                onSleep = onNavigateToSleep,
                onBodyScan = onNavigateToBodyScan,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(Modifier.height(sectionGap))

            SwastriAICard(
                onChat = onNavigateToAIChat,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(Modifier.height(16.dp))
        }
    }
}

// ───────────────────── Header ─────────────────────

@Composable
private fun HeaderSection(
    userName: String,
    greeting: String,
    avatarUrl: String?,
    onNotifications: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.weight(1f)
        ) {
            AvatarBubble(avatarUrl = avatarUrl)
            Column {
                Text(
                    greeting,
                    fontSize = 13.sp,
                    color = MutedText
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        userName,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = DarkText
                    )
                    Icon(
                        Icons.Default.Verified,
                        contentDescription = null,
                        tint = PremiumColors.Teal,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    "Let's take a step towards a healthier you!",
                    fontSize = 12.sp,
                    color = MutedText
                )
            }
        }

        Box(
            modifier = Modifier
                .size(40.dp)
                .lightCardShadow(CircleShape)
                .clip(CircleShape)
                .background(Color.White, CircleShape)
                .border(0.5.dp, SubtleBorder, CircleShape)
                .clickable(onClick = onNotifications),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Notifications,
                contentDescription = "Notifications",
                tint = DarkText,
                modifier = Modifier.size(18.dp)
            )
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-10).dp, y = 10.dp)
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(PremiumColors.Teal)
                    .border(1.5.dp, Color.White, CircleShape)
            )
        }
    }
}

@Composable
private fun AvatarBubble(avatarUrl: String?) {
    Box(modifier = Modifier.size(52.dp)) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(PremiumColors.Teal.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            if (!avatarUrl.isNullOrBlank()) {
                coil.compose.AsyncImage(
                    model = avatarUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircleShape)
                )
            } else {
                Icon(
                    Icons.Default.Verified,
                    contentDescription = null,
                    tint = PremiumColors.Teal,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
        // Small green check overlay at bottom-right
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .size(16.dp)
                .clip(CircleShape)
                .background(PremiumColors.Teal, CircleShape)
                .border(2.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Verified,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(10.dp)
            )
        }
    }
}

// ───────────────────── Daily Activity ─────────────────────

@Composable
private fun DailyActivityCard(
    steps: Int,
    stepGoal: Int,
    calories: Int,
    calorieGoal: Int,
    distance: Double,
    distanceGoal: Double,
    activeMinutes: Int,
    activeMinutesGoal: Int,
    ringSize: Dp,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .lightCardShadow(RoundedCornerShape(20.dp))
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White, RoundedCornerShape(20.dp))
            .border(0.5.dp, SubtleBorder, RoundedCornerShape(20.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Text(
            "Daily Activity",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = DarkText
        )

        Spacer(Modifier.height(10.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Max),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            StepsRing(
                steps = steps,
                goal = stepGoal,
                ringSize = ringSize
            )

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.SpaceEvenly
            ) {
                MiniStatRow(
                    iconAsset = "icons/calories icon.png",
                    label = "Calories",
                    value = calories.toString(),
                    goal = "$calorieGoal kcal",
                    progress = if (calorieGoal > 0) (calories.toFloat() / calorieGoal).coerceIn(0f, 1f) else 0f,
                    accent = CalorieAccent
                )
                MiniStatRow(
                    iconAsset = "icons/distance travel icon.png",
                    label = "Distance",
                    value = String.format("%.1f", distance),
                    goal = "${distanceGoal.toInt()} km",
                    progress = if (distanceGoal > 0) (distance.toFloat() / distanceGoal.toFloat()).coerceIn(0f, 1f) else 0f,
                    accent = DistanceAccent
                )
                MiniStatRow(
                    iconAsset = "icons/active minutes icon.png",
                    label = "Active Minutes",
                    value = activeMinutes.toString(),
                    goal = "$activeMinutesGoal min",
                    progress = if (activeMinutesGoal > 0) (activeMinutes.toFloat() / activeMinutesGoal).coerceIn(0f, 1f) else 0f,
                    accent = ActiveAccent
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        // Separate row — Goal text aligned beneath the steps ring
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier.width(ringSize),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Goal ${formatNumber(stepGoal)}",
                    fontSize = 11.sp,
                    color = PremiumColors.Teal,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun StepsRing(steps: Int, goal: Int, ringSize: Dp) {
    val target = if (goal > 0) (steps.toFloat() / goal).coerceIn(0f, 1f) else 0f
    var triggered by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { triggered = true }
    val progress by animateFloatAsState(
        targetValue = if (triggered) target else 0f,
        animationSpec = tween(durationMillis = 1100, easing = FastOutSlowInEasing),
        label = "stepsRingProgress"
    )

    Box(
        modifier = Modifier.size(ringSize),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val stroke = 7.dp.toPx()
            val arcSize = Size(size.width - stroke, size.height - stroke)
            val topLeft = androidx.compose.ui.geometry.Offset(stroke / 2f, stroke / 2f)
            drawArc(
                color = RingTrack,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
            drawArc(
                brush = Brush.sweepGradient(
                    listOf(PremiumColors.Teal, PremiumColors.NeonGreen, PremiumColors.Teal)
                ),
                startAngle = -90f,
                sweepAngle = 360f * progress,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AssetIcon(asset = "icons/steps shoe icon.png", size = 26.dp)
            Spacer(Modifier.height(2.dp))
            Text(
                formatNumber(steps),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = DarkText
            )
            Text(
                "Steps",
                fontSize = 11.sp,
                color = MutedText
            )
        }
    }
}

@Composable
private fun MiniStatRow(
    iconAsset: String,
    label: String,
    value: String,
    goal: String,
    progress: Float,
    accent: Color
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        AssetIcon(asset = iconAsset, size = 26.dp)
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    label,
                    fontSize = 11.sp,
                    color = DarkText,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    softWrap = false,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Visible
                )
                Text(
                    buildSpan(value, " / $goal"),
                    fontSize = 10.sp,
                    maxLines = 1,
                    softWrap = false,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Visible
                )
            }
            ProgressBarThin(progress = progress, accent = accent)
        }
    }
}

private fun buildSpan(primary: String, secondary: String): AnnotatedString {
    return buildAnnotatedString {
        withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = DarkText)) {
            append(primary)
        }
        withStyle(SpanStyle(color = MutedText, fontWeight = FontWeight.Normal)) {
            append(secondary)
        }
    }
}

@Composable
private fun ProgressBarThin(progress: Float, accent: Color) {
    var triggered by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { triggered = true }
    val animated by animateFloatAsState(
        targetValue = if (triggered) progress else 0f,
        animationSpec = tween(durationMillis = 1000, delayMillis = 200, easing = FastOutSlowInEasing),
        label = "miniProgress"
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(4.dp)
            .clip(RoundedCornerShape(2.dp))
            .background(RingTrack)
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(animated)
                .clip(RoundedCornerShape(2.dp))
                .background(accent)
        )
    }
}

// ───────────────────── Quick Actions ─────────────────────

@Composable
private fun QuickActionsRow(
    onHydration: () -> Unit,
    onMedication: () -> Unit,
    onCycle: () -> Unit,
    onDiet: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        QuickActionTile(
            iconAsset = "icons/hydration icon.png",
            label = "Hydration",
            tint = HydrationTint,
            modifier = Modifier.weight(1f),
            onClick = onHydration
        )
        QuickActionTile(
            iconAsset = "icons/medication icon.png",
            label = "Medication",
            tint = MedicationTint,
            modifier = Modifier.weight(1f),
            onClick = onMedication
        )
        QuickActionTile(
            iconAsset = "icons/cycle icon.png",
            label = "Cycle",
            tint = CycleTint,
            modifier = Modifier.weight(1f),
            onClick = onCycle
        )
        QuickActionTile(
            iconAsset = "icons/diet icon.png",
            label = "Diet",
            tint = DietTint,
            modifier = Modifier.weight(1f),
            onClick = onDiet
        )
    }
}

@Composable
private fun QuickActionTile(
    iconAsset: String,
    label: String,
    tint: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Column(
        modifier = modifier
            .lightCardShadow(RoundedCornerShape(16.dp))
            .clip(RoundedCornerShape(16.dp))
            .background(tint, RoundedCornerShape(16.dp))
            .border(0.3.dp, Color.Black.copy(alpha = 0.04f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 5.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        AssetIcon(asset = iconAsset, size = 55.dp)
        Text(
            label,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = DarkText
        )
    }
}

// ───────────────────── Health Vitals ─────────────────────

@Composable
private fun HealthVitalsCard(
    heartRate: Int,
    bloodOxygen: Int,
    sleepHours: String,
    weight: Double,
    onHeartRate: () -> Unit,
    onSleep: () -> Unit,
    onBodyScan: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .lightCardShadow(RoundedCornerShape(18.dp))
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White, RoundedCornerShape(18.dp))
            .border(0.5.dp, SubtleBorder, RoundedCornerShape(18.dp))
            .padding(horizontal = 4.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        VitalCell(
            iconAsset = "icons/heart rate icon.png",
            label = "Heart Rate",
            value = if (heartRate > 0) heartRate.toString() else "--",
            unit = "bpm",
            modifier = Modifier
                .weight(1f)
                .clickable(onClick = onHeartRate)
        )
        VitalDivider()
        VitalCell(
            iconAsset = "icons/blood oxygen icon.png",
            label = "Blood Oxygen",
            value = "$bloodOxygen",
            unit = "%",
            modifier = Modifier.weight(1f)
        )
        VitalDivider()
        VitalCell(
            iconAsset = "icons/sleep icon.png",
            label = "Sleep",
            value = sleepHours,
            unit = "",
            modifier = Modifier
                .weight(1f)
                .clickable(onClick = onSleep)
        )
        VitalDivider()
        VitalCell(
            iconAsset = "icons/weight icon.png",
            label = "Weight",
            value = String.format("%.1f", weight),
            unit = "kg",
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun VitalDivider() {
    Box(
        modifier = Modifier
            .height(36.dp)
            .width(1.dp)
            .background(SubtleBorder)
    )
}

@Composable
private fun VitalCell(
    iconAsset: String? = null,
    icon: ImageVector? = null,
    iconTint: Color = PremiumColors.Teal,
    label: String,
    value: String,
    unit: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (iconAsset != null) {
            AssetIcon(asset = iconAsset, size = 30.dp)
        } else if (icon != null) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(30.dp))
        }
        Spacer(Modifier.height(6.dp))
        Text(
            label,
            fontSize = 11.sp,
            color = MutedText,
            textAlign = TextAlign.Center,
            maxLines = 1
        )
        Spacer(Modifier.height(2.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                value,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = DarkText
            )
            if (unit.isNotEmpty()) {
                Spacer(Modifier.width(2.dp))
                Text(
                    unit,
                    fontSize = 10.sp,
                    color = MutedText,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
        }
    }
}

// ───────────────────── Swastri AI card ─────────────────────

@Composable
private fun SwastriAICard(
    onChat: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val mascot = remember {
        runCatching {
            context.assets.open("icons/banner ai illustration.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .lightCardShadow(RoundedCornerShape(20.dp))
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.horizontalGradient(
                    listOf(Color(0xFF0F172A), Color(0xFF134E4A))
                ),
                RoundedCornerShape(20.dp)
            )
            .clickable(onClick = onChat)
            .padding(start = 18.dp, end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                "Swastri AI",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = PremiumColors.NeonGreen,
                letterSpacing = 0.5.sp
            )
            Text(
                "Your health companion",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                lineHeight = 20.sp
            )
            Text(
                "Ask anything, get personalized insights and guidance.",
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.65f),
                lineHeight = 15.sp
            )
        }
        if (mascot != null) {
            Image(
                bitmap = mascot.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(110.dp)
            )
        }
    }
}

// ───────────────────── Helpers ─────────────────────

@Composable
private fun SectionHeader(
    title: String,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            title,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = DarkText
        )
        if (trailing != null) trailing()
    }
}

@Composable
private fun AssetIcon(asset: String, size: Dp) {
    val context = LocalContext.current
    val bitmap = remember(asset) {
        runCatching {
            context.assets.open(asset).use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier.size(size)
        )
    } else {
        Spacer(Modifier.size(size))
    }
}

private fun formatNumber(value: Int): String =
    if (value >= 1000) String.format("%,d", value) else value.toString()

@Composable
private fun EnterFromBottom(
    visible: Boolean,
    delayMillis: Int,
    content: @Composable () -> Unit
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(durationMillis = 360, delayMillis = delayMillis)) +
            slideInVertically(
                animationSpec = tween(durationMillis = 420, delayMillis = delayMillis, easing = FastOutSlowInEasing),
                initialOffsetY = { it / 4 }
            )
    ) {
        content()
    }
}

// Standardized soft shadow used across every card
private fun Modifier.lightCardShadow(shape: androidx.compose.ui.graphics.Shape): Modifier =
    this.shadow(
        elevation = 4.dp,
        shape = shape,
        clip = false,
        spotColor = Color(0xFF94A3B8).copy(alpha = 0.30f),
        ambientColor = Color(0xFF94A3B8).copy(alpha = 0.15f)
    )
