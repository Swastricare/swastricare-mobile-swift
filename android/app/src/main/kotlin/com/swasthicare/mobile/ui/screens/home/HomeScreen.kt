package com.swasthicare.mobile.ui.screens.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalDrink
import androidx.compose.material.icons.filled.Medication
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.components.ModelViewer
import com.swasthicare.mobile.ui.screens.medications.MedicationsViewModel
import com.swasthicare.mobile.ui.theme.*

@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(),
    onNavigateToMedications: () -> Unit = {},
    onNavigateToDiet: () -> Unit = {},
    onNavigateToHydration: () -> Unit = {},
    onNavigateToCycleTracker: () -> Unit = {},
    onNavigateToHeartRate: () -> Unit = {},
    onNavigateToBodyScan: () -> Unit = {},
    onNavigateToNotifications: () -> Unit = {},
    onNavigateToRoute: (String) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()
    val medicationsViewModel = remember { AppContainer.medicationsViewModel }
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
    val sectionCount = 7
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
        PremiumBackground()

        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = AppColors.primary)
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
            ) {
                // 2. Header
                LivingStatusHeader(
                    userName = uiState.userName,
                    greeting = uiState.greeting,
                    statusColor = SecondaryColor
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
                StaggeredEntrance(visible = sectionVisible[1].value) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(300.dp)
                            .padding(horizontal = 16.dp)
                    ) {
                        // 3D Anatomy Model on the right
                        Box(
                            modifier = Modifier
                                .align(Alignment.CenterEnd)
                                .fillMaxHeight()
                                .fillMaxWidth(0.52f),
                            contentAlignment = Alignment.Center
                        ) {
                            ModelViewer(
                                modelName = "anatomy",
                                modifier = Modifier.fillMaxSize(),
                                autoRotate = false,
                                allowInteraction = false,
                                rotationDurationMs = 8000
                            )
                        }

                        // Fade gradient at the bottom — blends the section into content below.
                        // This covers the Activity Stats (left) and background around the model (right).
                        // The 3D model itself is viewport-clipped via its Y offset in ModelViewer.
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .fillMaxWidth()
                                .fillMaxHeight(0.60f)
                                .background(
                                    brush = Brush.verticalGradient(
                                        colorStops = arrayOf(
                                            0.0f to Color.Transparent,
                                            0.18f to AppColors.background.copy(alpha = 0.30f),
                                            0.40f to AppColors.background.copy(alpha = 0.62f),
                                            0.65f to AppColors.background.copy(alpha = 0.88f),
                                            1.0f to AppColors.background
                                        )
                                    )
                                )
                        )

                        // Activity Stats Column on the left
                        Column(
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                            modifier = Modifier
                                .fillMaxWidth(0.48f)
                                .align(Alignment.CenterStart)
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
                            color = HeartRateColor,
                            modifier = Modifier.weight(1f).height(100.dp),
                            delay = 100,
                            showCameraBadge = true
                        )

                        VitalCard(
                            icon = Icons.Default.Bed,
                            title = "Sleep",
                            value = uiState.sleepHours,
                            unit = "",
                            color = SleepColor,
                            modifier = Modifier.weight(1f).height(100.dp),
                            delay = 200
                        )

                        VitalCard(
                            icon = Icons.Default.DirectionsWalk,
                            title = "Distance",
                            value = "${uiState.distance}",
                            unit = "km",
                            color = SecondaryColor,
                            modifier = Modifier.weight(1f).height(100.dp),
                            delay = 300
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 5. Complex Widgets (Hydration & Medication) (section 3)
                Text(
                    "Quick Actions",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
                StaggeredEntrance(visible = sectionVisible[3].value) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Medication Card
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(160.dp)
                                .clip(RoundedCornerShape(24.dp))
                                .background(MedicationColor.copy(alpha = 0.12f))
                                .clickable { onNavigateToMedications() }
                        ) {
                            // Use MedicationsViewModel data for consistent counts
                            val allDoses = medicationsState.allDosesToday
                            val medicationsTaken = allDoses.count { it.status == com.swasthicare.mobile.data.models.AdherenceStatus.TAKEN || it.status == com.swasthicare.mobile.data.models.AdherenceStatus.LATE || it.status == com.swasthicare.mobile.data.models.AdherenceStatus.EARLY }
                            val medicationsTotal = allDoses.size
                            val progress = if (medicationsTotal > 0) medicationsTaken.toFloat() / medicationsTotal.toFloat() else 0f
                            val pendingDoses = allDoses.filter { it.status == com.swasthicare.mobile.data.models.AdherenceStatus.PENDING }.take(3)

                            // Content — spread top to bottom
                            Column(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.SpaceBetween
                            ) {
                                // Icon + quick-log button row
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(36.dp)
                                            .background(MedicationColor.copy(alpha = 0.2f), CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Medication,
                                            contentDescription = null,
                                            tint = MedicationColor,
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                    if (pendingDoses.isNotEmpty()) {
                                        Box(
                                            modifier = Modifier
                                                .size(28.dp)
                                                .background(MedicationColor.copy(alpha = 0.2f), CircleShape)
                                                .clickable(
                                                    indication = null,
                                                    interactionSource = remember { MutableInteractionSource() }
                                                ) { medicationsViewModel.markAsTaken(pendingDoses.first()) },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.CheckCircle,
                                                contentDescription = "Take next dose",
                                                tint = MedicationColor,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        }
                                    }
                                }

                                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(
                                        "Medication",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = AppColors.onSurface.copy(alpha = 0.8f)
                                    )
                                    Row(verticalAlignment = Alignment.Bottom) {
                                        Text(
                                            "$medicationsTaken",
                                            style = MaterialTheme.typography.headlineLarge,
                                            fontWeight = FontWeight.Bold,
                                            color = AppColors.onSurface
                                        )
                                        Text(
                                            "/$medicationsTotal",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = AppColors.onSurface.copy(alpha = 0.6f),
                                            modifier = Modifier.padding(bottom = 6.dp, start = 2.dp)
                                        )
                                    }
                                }

                                // Show pending doses with quick-log
                                if (pendingDoses.isNotEmpty()) {
                                    Column(
                                        verticalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        pendingDoses.take(2).forEach { dose ->
                                            Row(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .clip(RoundedCornerShape(8.dp))
                                                    .background(MedicationColor.copy(alpha = 0.1f))
                                                    .clickable { medicationsViewModel.markAsTaken(dose) }
                                                    .padding(horizontal = 8.dp, vertical = 4.dp),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Text(
                                                    text = dose.medicationName,
                                                    style = MaterialTheme.typography.labelSmall,
                                                    color = AppColors.onSurface,
                                                    maxLines = 1,
                                                    modifier = Modifier.weight(1f)
                                                )
                                                Icon(
                                                    imageVector = Icons.Default.Check,
                                                    contentDescription = "Take",
                                                    tint = MedicationColor,
                                                    modifier = Modifier.size(14.dp)
                                                )
                                            }
                                        }
                                        if (pendingDoses.size > 2) {
                                            Text(
                                                text = "+${pendingDoses.size - 2} more",
                                                style = MaterialTheme.typography.labelSmall,
                                                color = AppColors.onSurface.copy(alpha = 0.5f)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Hydration Card
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(160.dp)
                                .clip(RoundedCornerShape(24.dp))
                                .background(HydrationColor.copy(alpha = 0.12f))
                                .clickable { onNavigateToHydration() }
                        ) {
                            val progress = if (uiState.hydrationGoal > 0) uiState.hydrationCurrent.toFloat() / uiState.hydrationGoal.toFloat() else 0f

                            // Water wave animation
                            WaterWave(
                                progress = progress,
                                color = HydrationColor.copy(alpha = 0.25f),
                                modifier = Modifier.fillMaxSize()
                            )
                            WaterWave(
                                progress = progress,
                                color = HydrationColor.copy(alpha = 0.35f),
                                modifier = Modifier.fillMaxSize().padding(top = 5.dp)
                            )

                            // Content — spread top to bottom
                            Column(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.SpaceBetween
                            ) {
                                // Icon + quick-add button row
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(36.dp)
                                            .background(HydrationColor.copy(alpha = 0.2f), CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.LocalDrink,
                                            contentDescription = null,
                                            tint = HydrationColor,
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                    Box(
                                        modifier = Modifier
                                            .size(28.dp)
                                            .background(HydrationColor.copy(alpha = 0.2f), CircleShape)
                                            .clickable(
                                                indication = null,
                                                interactionSource = remember { MutableInteractionSource() }
                                            ) { viewModel.incrementHydration() },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Add,
                                            contentDescription = "Add 250ml",
                                            tint = HydrationColor,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }

                                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(
                                        "Hydration",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = AppColors.onSurface.copy(alpha = 0.8f)
                                    )
                                    Text(
                                        "${uiState.hydrationCurrent} ml",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold,
                                        color = AppColors.onSurface
                                    )
                                    // Mini progress bar
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(4.dp)
                                            .clip(RoundedCornerShape(2.dp))
                                            .background(HydrationColor.copy(alpha = 0.15f))
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .fillMaxWidth(progress.coerceIn(0f, 1f))
                                                .fillMaxHeight()
                                                .clip(RoundedCornerShape(2.dp))
                                                .background(HydrationColor)
                                        )
                                    }
                                    Text(
                                        "Goal: ${uiState.hydrationGoal}",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = AppColors.onSurface.copy(alpha = 0.5f)
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Diet & Cycle in a row (section 4)
                StaggeredEntrance(visible = sectionVisible[4].value) {
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

                Spacer(modifier = Modifier.height(8.dp))
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
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .alpha(animatedAlpha)
            .offset(x = animatedOffset.dp)
            .glass(cornerRadius = 16.dp, opacity = 0.3f)
    ) {
        // Colored accent strip on left edge
        // Box(
        //     modifier = Modifier
        //         .align(Alignment.CenterStart)
        //         .width(3.dp)
        //         .fillMaxHeight()
        //         .clip(RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
        //         .background(color)
        // )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 10.dp)
        ) {
            // Icon with background circle
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .background(color.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
            }

            // Value and label
            Column {
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
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
