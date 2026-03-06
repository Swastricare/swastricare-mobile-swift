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
import androidx.compose.material.icons.filled.Bed
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalDrink
import androidx.compose.material.icons.filled.Medication
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.ChevronRight
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
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.ui.components.ModelViewer
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
    
    Box(modifier = Modifier.fillMaxSize()) {
        // 1. Premium Animated Background
        PremiumBackground()
        
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            }
        } else {
            // Staggered entrance animation state for each section
            val sectionCount = 7
            val sectionVisible = remember { List(sectionCount) { mutableStateOf(false) } }
            LaunchedEffect(Unit) {
                sectionVisible.forEachIndexed { index, state ->
                    kotlinx.coroutines.delay(index * 80L)
                    state.value = true
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .verticalScroll(scrollState)
            ) {
                // 2. Header
                LivingStatusHeader(
                    userName = uiState.userName,
                    greeting = uiState.greeting,
                    statusColor = SecondaryColor
                )

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
                                modifier = Modifier
                                    .fillMaxSize()
                                    .scale(1.2f),
                                autoRotate = true,
                                allowInteraction = false,
                                rotationDurationMs = 8000
                            )
                        }

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
                                label = "Active Calories",
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
                            modifier = Modifier.weight(1f).height(130.dp),
                            delay = 100,
                            showCameraBadge = true
                        )

                        VitalCard(
                            icon = Icons.Default.Bed,
                            title = "Sleep",
                            value = uiState.sleepHours,
                            unit = "",
                            color = SleepColor,
                            modifier = Modifier.weight(1f).height(130.dp),
                            delay = 200
                        )

                        VitalCard(
                            icon = Icons.Default.DirectionsWalk,
                            title = "Distance",
                            value = "${uiState.distance}",
                            unit = "km",
                            color = SecondaryColor,
                            modifier = Modifier.weight(1f).height(130.dp),
                            delay = 300
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 5. Complex Widgets (Hydration & Medication) (section 3)
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
                                .height(200.dp)
                                .glass(cornerRadius = 24.dp)
                                .clickable { onNavigateToMedications() }
                        ) {
                            val progress = if (uiState.medicationsTotal > 0) (uiState.medicationsTaken.toFloat() / uiState.medicationsTotal.toFloat()).coerceIn(0f, 1f) else 0f
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(RoundedCornerShape(24.dp))
                            ) {
                                // Liquid fill
                                Box(
                                    modifier = Modifier
                                        .align(Alignment.BottomCenter)
                                        .fillMaxWidth()
                                        .fillMaxHeight(progress)
                                        .background(
                                            brush = Brush.verticalGradient(
                                                colors = listOf(
                                                    PrimaryColor.copy(alpha = 0.5f),
                                                    SleepColor.copy(alpha = 0.5f)
                                                )
                                            )
                                        )
                                ) {
                                    RisingBubblesEffect(color = Color.White.copy(alpha = 0.3f))
                                }
                            }

                            // Content — spread top to bottom
                            Column(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.SpaceBetween
                            ) {
                                // Icon with colored background
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

                                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(
                                        "Medication",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
                                    )
                                    Row(verticalAlignment = Alignment.Bottom) {
                                        Text(
                                            "${uiState.medicationsTaken}",
                                            style = MaterialTheme.typography.headlineLarge,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                        Text(
                                            "/${uiState.medicationsTotal}",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                            modifier = Modifier.padding(bottom = 6.dp, start = 2.dp)
                                        )
                                    }
                                }
                            }
                        }

                        // Hydration Card
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(200.dp)
                                .glass(cornerRadius = 24.dp)
                                .clickable { onNavigateToHydration() }
                        ) {
                            val progress = if (uiState.hydrationGoal > 0) (uiState.hydrationCurrent.toFloat() / uiState.hydrationGoal.toFloat()).coerceIn(0f, 1f) else 0f

                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(RoundedCornerShape(24.dp))
                            ) {
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
                            }

                            // Content — spread top to bottom
                            Column(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.SpaceBetween
                            ) {
                                // Icon with colored background
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

                                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(
                                        "Hydration",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
                                    )
                                    Text(
                                        "${uiState.hydrationCurrent} ml",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
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
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Diet Quick Action — full width (section 4)
                StaggeredEntrance(visible = sectionVisible[4].value) {
                    DietQuickActionCard(
                        calorieCurrent = uiState.calorieCurrent,
                        calorieGoal = uiState.calorieGoal,
                        onClick = onNavigateToDiet,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Cycle Tracker — full width (section 5)
                StaggeredEntrance(visible = sectionVisible[5].value) {
                    CycleTrackerCard(
                        phaseLabel = uiState.cyclePhase,
                        onClick = onNavigateToCycleTracker,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }

                Spacer(modifier = Modifier.height(80.dp)) // Bottom padding for nav bar
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
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .width(3.dp)
                .fillMaxHeight()
                .clip(RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
                .background(color)
        )

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
                    color = MaterialTheme.colorScheme.onSurfaceVariant
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
