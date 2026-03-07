package com.swasthicare.mobile.ui.screens.runactivity

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.animation.*
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.rememberMultiplePermissionsState
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.shouldShowRationale
import com.swasthicare.mobile.data.services.RouteTracker
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.components.GpsStatusChip
import com.swasthicare.mobile.ui.components.RouteMapView
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PremiumColor

// ─────────────────────────────────────
// MARK: - LiveWorkoutScreen
// ─────────────────────────────────────

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun LiveWorkoutScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToSummary: () -> Unit = {}
) {
    val context = LocalContext.current
    val viewModel = AppContainer.liveWorkoutViewModel
    val uiState by viewModel.uiState.collectAsState()

    // ── Location Permission ──
    val locationPermissions = rememberMultiplePermissionsState(
        permissions = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    ) { permissionsResult ->
        val fineGranted = permissionsResult[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = permissionsResult[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        viewModel.onLocationPermissionResult(fineGranted || coarseGranted)
    }

    // Check permission on composition
    LaunchedEffect(locationPermissions.permissions) {
        val hasAny = locationPermissions.permissions.any { it.status.isGranted }
        viewModel.onLocationPermissionResult(hasAny)
    }

    // Request permissions when in IDLE phase for GPS-based workouts
    LaunchedEffect(uiState.phase, uiState.workoutType.usesGps) {
        if (uiState.phase == WorkoutPhase.IDLE &&
            uiState.workoutType.usesGps &&
            !locationPermissions.allPermissionsGranted
        ) {
            locationPermissions.launchMultiplePermissionRequest()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF0D0D1A),
                        Color(0xFF1A1A2E),
                        Color(0xFF0D0D1A)
                    )
                )
            )
    ) {
        when (uiState.phase) {
            WorkoutPhase.IDLE -> IdlePhaseContent(
                uiState = uiState,
                hasLocationPermission = uiState.hasLocationPermission,
                usesGps = uiState.workoutType.usesGps,
                isPermanentlyDenied = locationPermissions.permissions.any {
                    !it.status.isGranted && !it.status.shouldShowRationale
                } && !locationPermissions.allPermissionsGranted,
                onSelectWorkoutType = { viewModel.setWorkoutType(it) },
                onStart = { viewModel.startWorkout() },
                onBack = onNavigateBack,
                onOpenSettings = {
                    context.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", context.packageName, null)
                        }
                    )
                }
            )

            WorkoutPhase.COUNTDOWN -> CountdownPhaseContent(
                countdownValue = uiState.countdownValue
            )

            WorkoutPhase.TRACKING -> TrackingPhaseContent(
                uiState = uiState,
                onPause = { viewModel.pauseWorkout() },
                onStop = { viewModel.stopWorkout() }
            )

            WorkoutPhase.PAUSED -> PausedPhaseContent(
                uiState = uiState,
                onResume = { viewModel.resumeWorkout() },
                onStop = { viewModel.stopWorkout() }
            )

            WorkoutPhase.COMPLETED -> WorkoutSummaryContent(
                uiState = uiState,
                onDone = {
                    viewModel.saveCompletedWorkout()
                    viewModel.resetWorkout()
                    onNavigateBack()
                },
                onDiscard = {
                    viewModel.resetWorkout()
                    onNavigateBack()
                }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - IDLE Phase
// ─────────────────────────────────────

@Composable
private fun IdlePhaseContent(
    uiState: LiveWorkoutUiState,
    hasLocationPermission: Boolean,
    usesGps: Boolean,
    isPermanentlyDenied: Boolean,
    onSelectWorkoutType: (WorkoutType) -> Unit,
    onStart: () -> Unit,
    onBack: () -> Unit,
    onOpenSettings: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Top bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    tint = Color.White
                )
            }
            Text(
                "Start Workout",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(Modifier.size(48.dp))
        }

        Spacer(Modifier.height(32.dp))

        // Workout type selector
        Text(
            "Choose Activity",
            style = MaterialTheme.typography.titleMedium,
            color = Color.White.copy(alpha = 0.7f),
            fontWeight = FontWeight.Medium
        )

        Spacer(Modifier.height(16.dp))

        // Workout type grid
        val types = WorkoutType.entries.toList()
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            for (row in types.chunked(3)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    for (type in row) {
                        WorkoutTypeCard(
                            type = type,
                            isSelected = uiState.workoutType == type,
                            onClick = { onSelectWorkoutType(type) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                    // Fill remaining space if row has fewer than 3 items
                    repeat(3 - row.size) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }

        Spacer(Modifier.height(24.dp))

        // GPS warning card
        if (usesGps && !hasLocationPermission) {
            NoGpsWarningCard(
                isPermanentlyDenied = isPermanentlyDenied,
                onOpenSettings = onOpenSettings
            )
            Spacer(Modifier.height(16.dp))
        }

        // GPS status
        if (usesGps && hasLocationPermission) {
            Row(
                modifier = Modifier
                    .glass(cornerRadius = 16.dp)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    Icons.Default.GpsFixed,
                    contentDescription = null,
                    tint = Color(0xFF38EF7D),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    "GPS ready - route will be recorded",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }
            Spacer(Modifier.height(16.dp))
        }

        Spacer(Modifier.weight(1f))

        // Start button
        Box(
            modifier = Modifier
                .size(120.dp)
                .clip(CircleShape)
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            PremiumColor.NeonGreenStart,
                            PremiumColor.NeonGreenEnd
                        )
                    )
                )
                .clickable { onStart() },
            contentAlignment = Alignment.Center
        ) {
            Text(
                "START",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = Color.White,
                fontSize = 22.sp
            )
        }

        Spacer(Modifier.height(40.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Workout Type Card
// ─────────────────────────────────────

@Composable
private fun WorkoutTypeCard(
    type: WorkoutType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val icon: ImageVector = when (type) {
        WorkoutType.RUN -> Icons.Default.DirectionsRun
        WorkoutType.WALK -> Icons.Default.DirectionsWalk
        WorkoutType.CYCLE -> Icons.Default.DirectionsBike
        WorkoutType.HIKE -> Icons.Default.Terrain
        WorkoutType.INDOOR_RUN -> Icons.Default.FitnessCenter
        WorkoutType.INDOOR_WALK -> Icons.Default.FitnessCenter
    }

    val borderColor = if (isSelected) PremiumColor.NeonGreenEnd else Color.Transparent

    Column(
        modifier = modifier
            .glass(cornerRadius = 16.dp, opacity = if (isSelected) 0.4f else 0.2f)
            .then(
                if (isSelected) {
                    Modifier.background(
                        color = PremiumColor.NeonGreenEnd.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(16.dp)
                    )
                } else Modifier
            )
            .clickable { onClick() }
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = type.displayName,
            tint = if (isSelected) PremiumColor.NeonGreenEnd else Color.White.copy(alpha = 0.6f),
            modifier = Modifier.size(28.dp)
        )
        Text(
            text = type.displayName,
            style = MaterialTheme.typography.labelSmall,
            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.6f),
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
            textAlign = TextAlign.Center
        )
        if (type.usesGps) {
            Icon(
                Icons.Default.GpsFixed,
                contentDescription = "GPS",
                tint = Color.White.copy(alpha = 0.3f),
                modifier = Modifier.size(10.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - No GPS Warning Card
// ─────────────────────────────────────

@Composable
private fun NoGpsWarningCard(
    isPermanentlyDenied: Boolean,
    onOpenSettings: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color(0xFFFF6B6B).copy(alpha = 0.1f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.Default.GpsOff,
                contentDescription = null,
                tint = Color(0xFFFF6B6B),
                modifier = Modifier.size(20.dp)
            )
            Text(
                "Location Permission Required",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFFFF6B6B)
            )
        }
        Text(
            if (isPermanentlyDenied) {
                "Location access was permanently denied. Open settings to enable it for GPS route tracking."
            } else {
                "GPS location is needed to track your route. The workout will still work without it, but no route map will be shown."
            },
            style = MaterialTheme.typography.bodySmall,
            color = Color.White.copy(alpha = 0.6f)
        )
        if (isPermanentlyDenied) {
            TextButton(onClick = onOpenSettings) {
                Text(
                    "Open Settings",
                    color = Color(0xFFFF6B6B),
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Countdown Phase
// ─────────────────────────────────────

@Composable
private fun CountdownPhaseContent(countdownValue: Int) {
    val scale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = spring(dampingRatio = 0.5f, stiffness = 300f),
        label = "countdownScale"
    )

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "$countdownValue",
            fontSize = 120.sp,
            fontWeight = FontWeight.Black,
            color = PremiumColor.NeonGreenEnd,
            modifier = Modifier.scale(scale)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Tracking Phase
// ─────────────────────────────────────

@Composable
private fun TrackingPhaseContent(
    uiState: LiveWorkoutUiState,
    onPause: () -> Unit,
    onStop: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(16.dp))

        // Top bar with workout type and GPS status
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                uiState.workoutType.displayName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            if (uiState.workoutType.usesGps) {
                GpsStatusChip(gpsStatus = uiState.gpsStatus)
            }
        }

        Spacer(Modifier.height(16.dp))

        // Route map (live)
        if (uiState.workoutType.usesGps && uiState.hasLocationPermission) {
            RouteMapView(
                routePoints = uiState.routePoints,
                isLive = true,
                height = 200
            )
            Spacer(Modifier.height(16.dp))
        }

        // Main timer display
        Text(
            text = uiState.elapsedFormatted,
            fontSize = 64.sp,
            fontWeight = FontWeight.Black,
            color = Color.White,
            letterSpacing = 2.sp
        )

        Spacer(Modifier.height(24.dp))

        // Metric cards grid
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            MetricCard(
                label = "Distance",
                value = uiState.distanceFormatted,
                unit = "km",
                color = Color(0xFF00E5FF),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                label = "Pace",
                value = uiState.paceFormatted,
                unit = "min/km",
                color = PremiumColor.NeonGreenEnd,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            MetricCard(
                label = "Speed",
                value = String.format("%.1f", uiState.currentSpeedKmh),
                unit = "km/h",
                color = Color(0xFFFFD60A),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                label = "Altitude",
                value = String.format("%.0f", uiState.currentAltitude),
                unit = "m",
                color = Color(0xFFBF5AF2),
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.weight(1f))

        // Control buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 40.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Stop button
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFFF4757).copy(alpha = 0.2f))
                    .clickable { onStop() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Stop,
                    contentDescription = "Stop",
                    tint = Color(0xFFFF4757),
                    modifier = Modifier.size(28.dp)
                )
            }

            // Pause button (large)
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(
                                PremiumColor.RoyalBlueStart,
                                PremiumColor.RoyalBlueEnd
                            )
                        )
                    )
                    .clickable { onPause() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Pause,
                    contentDescription = "Pause",
                    tint = Color.White,
                    modifier = Modifier.size(36.dp)
                )
            }

            // Spacer for symmetry
            Spacer(Modifier.size(64.dp))
        }
    }
}

// ─────────────────────────────────────
// MARK: - Paused Phase
// ─────────────────────────────────────

@Composable
private fun PausedPhaseContent(
    uiState: LiveWorkoutUiState,
    onResume: () -> Unit,
    onStop: () -> Unit
) {
    val pulseAnim = rememberInfiniteTransition(label = "pausePulse")
    val pulseAlpha by pulseAnim.animateFloat(
        initialValue = 0.5f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pauseAlpha"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(16.dp))

        // Paused label
        Text(
            "PAUSED",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color(0xFFFFD60A).copy(alpha = pulseAlpha),
            letterSpacing = 4.sp
        )

        Spacer(Modifier.height(16.dp))

        // Route map (static, showing current route)
        if (uiState.workoutType.usesGps && uiState.routePoints.size >= 2) {
            RouteMapView(
                routePoints = uiState.routePoints,
                isLive = false,
                height = 180
            )
            Spacer(Modifier.height(16.dp))
        }

        // Timer (dimmed)
        Text(
            text = uiState.elapsedFormatted,
            fontSize = 56.sp,
            fontWeight = FontWeight.Black,
            color = Color.White.copy(alpha = 0.5f),
            letterSpacing = 2.sp
        )

        Spacer(Modifier.height(16.dp))

        // Quick metrics
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            MetricCard(
                label = "Distance",
                value = uiState.distanceFormatted,
                unit = "km",
                color = Color(0xFF00E5FF),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                label = "Pace",
                value = uiState.paceFormatted,
                unit = "min/km",
                color = PremiumColor.NeonGreenEnd,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.weight(1f))

        // Resume & Stop buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 40.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Stop button
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFFF4757).copy(alpha = 0.2f))
                    .clickable { onStop() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Stop,
                    contentDescription = "Stop",
                    tint = Color(0xFFFF4757),
                    modifier = Modifier.size(32.dp)
                )
            }

            // Resume button (large, green)
            Box(
                modifier = Modifier
                    .size(88.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(
                                PremiumColor.NeonGreenStart,
                                PremiumColor.NeonGreenEnd
                            )
                        )
                    )
                    .clickable { onResume() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = "Resume",
                    tint = Color.White,
                    modifier = Modifier.size(40.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Workout Summary (Completed)
// ─────────────────────────────────────

@Composable
private fun WorkoutSummaryContent(
    uiState: LiveWorkoutUiState,
    onDone: () -> Unit,
    onDiscard: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(16.dp))

        Text(
            "Workout Complete!",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Black,
            color = PremiumColor.NeonGreenEnd
        )

        Text(
            uiState.workoutType.displayName,
            style = MaterialTheme.typography.titleMedium,
            color = Color.White.copy(alpha = 0.6f)
        )

        Spacer(Modifier.height(24.dp))

        // Route map (static review)
        if (uiState.routePoints.size >= 2) {
            RouteMapView(
                routePoints = uiState.routePoints,
                isLive = false,
                height = 220
            )
            Spacer(Modifier.height(20.dp))
        }

        // Summary metrics
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Duration
            SummaryRow(label = "Duration", value = uiState.elapsedFormatted)

            // Distance
            SummaryRow(
                label = "Distance",
                value = "${uiState.distanceFormatted} km"
            )

            // Average Pace
            SummaryRow(label = "Avg Pace", value = "${uiState.paceFormatted} /km")

            // Average Speed
            SummaryRow(
                label = "Avg Speed",
                value = String.format("%.1f km/h", uiState.averageSpeedKmh)
            )

            // Max Speed
            SummaryRow(
                label = "Max Speed",
                value = String.format("%.1f km/h", uiState.maxSpeedMps * 3.6f)
            )

            // Elevation Gain
            if (uiState.elevationGainMeters > 0) {
                SummaryRow(
                    label = "Elevation Gain",
                    value = String.format("%.0f m", uiState.elevationGainMeters)
                )
            }

            // Calories
            if (uiState.caloriesBurned > 0) {
                SummaryRow(
                    label = "Calories",
                    value = "${uiState.caloriesBurned} kcal"
                )
            }
        }

        Spacer(Modifier.height(32.dp))

        // Done button
        Button(
            onClick = onDone,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = PremiumColor.NeonGreenStart
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Text(
                "Save Workout",
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp
            )
        }

        Spacer(Modifier.height(12.dp))

        // Discard button
        TextButton(
            onClick = onDiscard,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                "Discard",
                color = Color.White.copy(alpha = 0.4f),
                fontWeight = FontWeight.Medium
            )
        }

        Spacer(Modifier.height(40.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Summary Row
// ─────────────────────────────────────

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 12.dp, opacity = 0.2f)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.6f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

// ─────────────────────────────────────
// MARK: - Metric Card
// ─────────────────────────────────────

@Composable
private fun MetricCard(
    label: String,
    value: String,
    unit: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 16.dp, opacity = 0.2f)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color.copy(alpha = 0.8f),
            fontWeight = FontWeight.Medium
        )
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = unit,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.5f),
                modifier = Modifier.padding(bottom = 4.dp)
            )
        }
    }
}
