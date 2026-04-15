package com.swastricare.health.ui.screens.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bed
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalDrink
import androidx.compose.material.icons.filled.Medication
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.ModelViewer
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.medications.MedicationsViewModel
import com.swastricare.health.ui.theme.*

@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToMedications: () -> Unit = {},
    onNavigateToDiet: () -> Unit = {},
    onNavigateToHydration: () -> Unit = {},
    onNavigateToCycleTracker: () -> Unit = {},
    onNavigateToHeartRate: () -> Unit = {},
    onNavigateToBodyScan: () -> Unit = {},
    onNavigateToNotifications: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {},
    onNavigateToRoute: (String) -> Unit = {}
) {
    TrackScreen("Home")
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()
    val medicationsViewModel: MedicationsViewModel = hiltViewModel()
    val medicationsState by medicationsViewModel.uiState.collectAsState()

    // Load medications on first composition
    LaunchedEffect(Unit) {
        medicationsViewModel.loadMedications()
    }

    // Refresh data when this screen resumes (e.g. navigating back from hydration/diet)
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
                medicationsViewModel.loadMedications()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Staggered entrance animation — initialized as visible if data is already loaded
    // (e.g. returning to the tab), so there's no blank-flash on tab switch.
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

    Box(modifier = Modifier.fillMaxSize()) {
        // 1. Premium Animated Background

        if (uiState.isLoading) {
            HomeSkeletonLoading()
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(bottom = 16.dp)
            ) {
                // 2. Header
                LivingStatusHeader(
                    userName = uiState.userName,
                    greeting = uiState.greeting,
                    statusColor = SecondaryColor,
                    onNotificationClick = onNavigateToNotifications
                )

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
                                androidx.compose.foundation.layout.Column {
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

                // Server Nudges (section 0)
                if (uiState.serverNudges.isNotEmpty()) {
                    StaggeredEntrance(visible = sectionVisible[0].value) {
                        NudgesCardStrip(
                            nudges = uiState.serverNudges,
                            onDismiss = { id -> viewModel.dismissNudge(id) }
                        )
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                }

                // 3. Body Status Section — refined proportions
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(320.dp)   // enough height for full body
                ) {

                    // 3D Model Section
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .fillMaxHeight()
                            .fillMaxWidth(0.60f),
                        contentAlignment = Alignment.BottomCenter
                    ) {

                        ModelViewer(
                            modelName = "anatomy.2",
                            modifier = Modifier
                                .fillMaxSize(), // prevents cropping
                            autoRotate = false,
                            allowInteraction = false,
                            rotationDurationMs = 8000
                        )
                    }

                    // Left Stats Section
                    Column(
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier
                            .fillMaxWidth(0.48f)
                            .align(Alignment.CenterStart)
                            .padding(start = 16.dp)
                    ) {

                        ActivityStatRow(
                            icon = Icons.Default.LocalFireDepartment,
                            value = "${uiState.calories}",
                            label = "Calories",
                            color = ActivityColor,
                            animationDelay = 300
                        )

                        ActivityStatRow(
                            icon = Icons.Default.Favorite,
                            value = "${uiState.activeMinutes}",
                            label = "Exercise Min",
                            color = DistanceColor,
                            animationDelay = 400
                        )

                        ActivityStatRow(
                            icon = Icons.Default.Accessibility,
                            value = "${uiState.standHours}",
                            label = "Stand Hours",
                            color = SleepColor,
                            animationDelay = 500
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 4. Vitals Grid (section 2)
                StaggeredEntrance(visible = sectionVisible[2].value) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        VitalCard(
                            icon = Icons.Default.Favorite,
                            title = "Heart Rate",
                            value = "${uiState.heartRate}",
                            unit = "BPM",
                            color = Color(0xFFF44336),
                            modifier = Modifier.weight(1f).height(130.dp),
                            delay = 100
                        )

                        VitalCard(
                            icon = Icons.Default.Bed,
                            title = "Sleep",
                            value = uiState.sleepHours,
                            unit = "",
                            color = Color(0xFF3F51B5),
                            modifier = Modifier.weight(1f).height(130.dp),
                            delay = 200
                        )

                        VitalCard(
                            icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                            title = "Distance",
                            value = "${uiState.distance}",
                            unit = "km",
                            color = StepsColor,
                            modifier = Modifier.weight(1f).height(130.dp),
                            delay = 300
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Health Analytics card (section 3)
                StaggeredEntrance(visible = sectionVisible[3].value) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .clip(RoundedCornerShape(24.dp))
                            .background(
                                Brush.linearGradient(
                                    colors = listOf(
                                        Color(0xFF7C4DFF).copy(alpha = 0.25f),
                                        Color(0xFF4F46E5).copy(alpha = 0.15f)
                                    )
                                )
                            )
                            .semantics { contentDescription = "Health Analytics" }
                            .clickable { onNavigateToAnalytics() }
                            .padding(horizontal = 20.dp, vertical = 16.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(14.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(42.dp)
                                        .background(
                                            color = Color(0xFF7C4DFF),
                                            shape = CircleShape
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.TrendingUp,
                                        contentDescription = null,
                                        tint = Color.White,
                                        modifier = Modifier.size(22.dp)
                                    )
                                }
                                Column {
                                    Text(
                                        "Health Analytics",
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.SemiBold,
                                        color = AppColors.onSurface
                                    )
                                    Text(
                                        "Track trends & insights",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = AppColors.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Icon(
                                imageVector = Icons.Default.ChevronRight,
                                contentDescription = null,
                                tint = AppColors.onSurface.copy(alpha = 0.5f),
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 5. Complex Widgets (Hydration & Medication) (section 4)
                Text(
                    "Quick Actions",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
                StaggeredEntrance(visible = sectionVisible[4].value) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Medication Card
                        val allDoses = medicationsState.allDosesToday
                        val medicationsTaken = allDoses.count {
                            it.status == com.swastricare.health.data.models.AdherenceStatus.TAKEN ||
                            it.status == com.swastricare.health.data.models.AdherenceStatus.LATE ||
                            it.status == com.swastricare.health.data.models.AdherenceStatus.EARLY
                        }
                        val medicationsTotal = allDoses.size
                        val pendingDoses = allDoses.filter {
                            it.status == com.swastricare.health.data.models.AdherenceStatus.PENDING
                        }.take(3)

                        PremiumMedicationCard(
                            medicationsTaken = medicationsTaken,
                            medicationsTotal = medicationsTotal,
                            pendingDoses = pendingDoses,
                            onNavigate = onNavigateToMedications,
                            onMarkTaken = { medicationsViewModel.markAsTaken(it) },
                            modifier = Modifier
                                .weight(1f)
                                .height(160.dp)
                        )

                        // Hydration Card
                        PremiumHydrationCard(
                            currentMl = uiState.hydrationCurrent,
                            goalMl = uiState.hydrationGoal,
                            onNavigate = onNavigateToHydration,
                            onQuickAdd = { viewModel.incrementHydration() },
                            modifier = Modifier
                                .weight(1f)
                                .height(160.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Diet & Cycle in a row (section 5)
                StaggeredEntrance(visible = sectionVisible[5].value) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        DietQuickActionCard(
                            calorieCurrent = uiState.calorieCurrent,
                            calorieGoal = uiState.calorieGoal,
                            onClick = onNavigateToDiet,
                            modifier = Modifier
                                .weight(1f)
                                .height(160.dp)
                        )
                        CycleTrackerCard(
                            phaseLabel = uiState.cyclePhase,
                            onClick = onNavigateToCycleTracker,
                            modifier = Modifier
                                .weight(1f)
                                .height(160.dp)
                        )
                    }
                }

            }
        }
    }
}

@Composable
fun ActivityStatRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String,
    color: Color,
    animationDelay: Int = 0
) {
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animationDelay.toLong())
        isVisible = true
    }
    
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(durationMillis = 500, easing = FastOutSlowInEasing),
        label = "statAlpha"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else -20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "statOffset"
    )
    
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .alpha(animatedAlpha)
            .offset(x = animatedOffset.dp)
            .padding(horizontal = 4.dp, vertical = 4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        }
        Column {
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
}

// MARK: - Staggered Entrance Animation Wrapper
@Composable
fun StaggeredEntrance(
    visible: Boolean,
    slideDistance: Int = 40,
    content: @Composable () -> Unit
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(
            animationSpec = tween(durationMillis = 400, easing = FastOutSlowInEasing)
        ) + slideInVertically(
            initialOffsetY = { slideDistance },
            animationSpec = spring(dampingRatio = 0.8f, stiffness = 300f)
        )
    ) {
        content()
    }
}

// MARK: - Skeleton Loading
@Composable
private fun ShimmerBox(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 12.dp
) {
    val isDark = isSystemInDarkTheme()
    val baseColor = if (isDark) Color.White.copy(alpha = 0.06f) else Color.Gray.copy(alpha = 0.12f)
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(baseColor)
            .shimmer()
    )
}

@Composable
fun HomeSkeletonLoading() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(bottom = 16.dp)
    ) {
        // Header skeleton
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                ShimmerBox(
                    modifier = Modifier.width(80.dp).height(14.dp),
                    cornerRadius = 7.dp
                )
                ShimmerBox(
                    modifier = Modifier.width(140.dp).height(28.dp),
                    cornerRadius = 8.dp
                )
            }
            ShimmerBox(
                modifier = Modifier.size(44.dp),
                cornerRadius = 22.dp
            )
        }

        // Body status section skeleton (3D model + stats area)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(320.dp)
                .padding(horizontal = 16.dp)
        ) {
            // Left stats placeholders
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth(0.48f)
                    .align(Alignment.CenterStart)
            ) {
                repeat(3) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp)
                    ) {
                        ShimmerBox(
                            modifier = Modifier.size(38.dp),
                            cornerRadius = 19.dp
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            ShimmerBox(
                                modifier = Modifier.width(50.dp).height(20.dp),
                                cornerRadius = 6.dp
                            )
                            ShimmerBox(
                                modifier = Modifier.width(70.dp).height(12.dp),
                                cornerRadius = 4.dp
                            )
                        }
                    }
                }
            }

            // Right side model placeholder
            ShimmerBox(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .fillMaxWidth(0.55f)
                    .fillMaxHeight(0.85f),
                cornerRadius = 20.dp
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Vitals grid skeleton (3 cards)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            repeat(3) {
                ShimmerBox(
                    modifier = Modifier
                        .weight(1f)
                        .height(130.dp),
                    cornerRadius = 20.dp
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Health Analytics card skeleton
        ShimmerBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .padding(horizontal = 16.dp),
            cornerRadius = 24.dp
        )

        Spacer(modifier = Modifier.height(16.dp))

        // "Quick Actions" title skeleton
        ShimmerBox(
            modifier = Modifier
                .width(120.dp)
                .height(18.dp)
                .padding(start = 16.dp),
            cornerRadius = 6.dp
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Medication + Hydration row skeleton
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            ShimmerBox(
                modifier = Modifier
                    .weight(1f)
                    .height(160.dp),
                cornerRadius = 24.dp
            )
            ShimmerBox(
                modifier = Modifier
                    .weight(1f)
                    .height(160.dp),
                cornerRadius = 24.dp
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Diet + Cycle row skeleton
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            ShimmerBox(
                modifier = Modifier
                    .weight(1f)
                    .height(160.dp),
                cornerRadius = 24.dp
            )
            ShimmerBox(
                modifier = Modifier
                    .weight(1f)
                    .height(160.dp),
                cornerRadius = 24.dp
            )
        }
    }
}
