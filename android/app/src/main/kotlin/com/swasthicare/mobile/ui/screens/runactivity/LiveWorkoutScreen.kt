package com.swasthicare.mobile.ui.screens.runactivity

import android.Manifest
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

private val WorkoutGreen = Color(0xFF30D158)
private val WorkoutRed = Color(0xFFFF375F)
private val WorkoutBlue = Color(0xFF0A84FF)

// ------------------------------------
// MARK: - Live Workout Screen
// ------------------------------------

@Composable
fun LiveWorkoutScreen(
    onNavigateBack: () -> Unit,
    onNavigateToSummary: () -> Unit
) {
    val vm = remember { AppContainer.liveWorkoutViewModel }
    val uiState by vm.uiState.collectAsState()

    // Navigate to summary when workout finishes
    LaunchedEffect(uiState.workoutState) {
        if (uiState.workoutState == WorkoutState.SUMMARY) {
            onNavigateToSummary()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // Top Bar (only in certain states)
            if (uiState.workoutState == WorkoutState.IDLE) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, "Back", tint = MaterialTheme.colorScheme.onSurface)
                    }
                    Text(
                        "Start Workout",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f).padding(start = 4.dp)
                    )
                }
            }

            when (uiState.workoutState) {
                WorkoutState.IDLE -> {
                    ActivityTypeSelection(
                        selectedType = uiState.activityType,
                        onTypeSelected = { vm.selectActivityType(it) },
                        onStart = { vm.startWorkout() },
                        hasPermission = vm.hasLocationPermission()
                    )
                }
                WorkoutState.COUNTDOWN -> {
                    CountdownOverlay(count = uiState.countdown)
                }
                WorkoutState.TRACKING, WorkoutState.PAUSED -> {
                    LiveMetricsView(
                        uiState = uiState,
                        onPause = { vm.pauseWorkout() },
                        onResume = { vm.resumeWorkout() },
                        onStop = { vm.stopWorkout() }
                    )
                }
                WorkoutState.FINISHING -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = WorkoutGreen)
                    }
                }
                else -> {} // SUMMARY and ERROR handled elsewhere
            }
        }
    }
}

// ------------------------------------
// MARK: - Activity Type Selection
// ------------------------------------

@Composable
private fun ActivityTypeSelection(
    selectedType: ActivityType,
    onTypeSelected: (ActivityType) -> Unit,
    onStart: () -> Unit,
    hasPermission: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Spacer(Modifier.height(20.dp))

        Text(
            "Choose Activity",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )

        // Activity type grid
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            ActivityType.entries.forEach { type ->
                val isSelected = type == selectedType
                val typeColor = when (type) {
                    ActivityType.WALKING -> WorkoutBlue
                    ActivityType.RUNNING -> WorkoutGreen
                    ActivityType.CYCLING -> Color(0xFFFF9F0A)
                    ActivityType.HIKING -> Color(0xFF8E8E93)
                }

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .glass(cornerRadius = 16.dp)
                        .then(
                            if (isSelected) Modifier.background(
                                typeColor.copy(alpha = 0.2f),
                                RoundedCornerShape(16.dp)
                            ) else Modifier
                        )
                        .clickable { onTypeSelected(type) }
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(type.emoji, fontSize = 32.sp)
                    Text(
                        type.displayName,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        color = if (isSelected) typeColor else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        if (!hasPermission) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFFFF9F0A).copy(alpha = 0.1f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.LocationOn,
                        null,
                        tint = Color(0xFFFF9F0A)
                    )
                    Text(
                        "Location permission is required for GPS tracking. Please grant it in Settings.",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        Spacer(Modifier.weight(1f))

        // Start button
        Button(
            onClick = onStart,
            colors = ButtonDefaults.buttonColors(containerColor = WorkoutGreen),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth().height(60.dp)
        ) {
            Icon(Icons.Default.PlayArrow, null, modifier = Modifier.size(24.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                "Start ${selectedType.displayName}",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
        }

        Spacer(Modifier.height(40.dp))
    }
}

// ------------------------------------
// MARK: - Countdown Overlay
// ------------------------------------

@Composable
private fun CountdownOverlay(count: Int) {
    val animatedScale by animateFloatAsState(
        targetValue = if (count > 0) 1.5f else 0.5f,
        animationSpec = tween(300, easing = FastOutSlowInEasing),
        label = "countScale"
    )

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "$count",
                style = MaterialTheme.typography.displayLarge,
                fontWeight = FontWeight.Bold,
                color = WorkoutGreen,
                fontSize = 96.sp,
                modifier = Modifier.scale(animatedScale)
            )
            Text(
                "Get Ready!",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// ------------------------------------
// MARK: - Live Metrics View
// ------------------------------------

@Composable
private fun LiveMetricsView(
    uiState: LiveWorkoutUiState,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit
) {
    val isPaused = uiState.workoutState == WorkoutState.PAUSED

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Activity Type Badge
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(uiState.activityType.emoji, fontSize = 20.sp)
            Text(
                uiState.activityType.displayName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            if (isPaused) {
                Box(
                    modifier = Modifier
                        .background(WorkoutRed.copy(alpha = 0.2f), RoundedCornerShape(6.dp))
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                ) {
                    Text(
                        "PAUSED",
                        style = MaterialTheme.typography.labelSmall,
                        color = WorkoutRed,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // Timer (large)
        val infiniteTransition = rememberInfiniteTransition(label = "timerPulse")
        val timerAlpha by infiniteTransition.animateFloat(
            initialValue = 1f,
            targetValue = if (isPaused) 0.3f else 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(800),
                repeatMode = RepeatMode.Reverse
            ),
            label = "timerAlpha"
        )

        Text(
            uiState.formattedElapsed,
            style = MaterialTheme.typography.displayLarge,
            fontWeight = FontWeight.Bold,
            fontSize = 56.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = timerAlpha)
        )

        // Metrics Grid
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            LiveMetricCard(
                label = "Distance",
                value = uiState.formattedDistance,
                unit = "km",
                color = WorkoutGreen,
                modifier = Modifier.weight(1f)
            )
            LiveMetricCard(
                label = "Pace",
                value = uiState.formattedCurrentPace,
                unit = "/km",
                color = WorkoutBlue,
                modifier = Modifier.weight(1f)
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            LiveMetricCard(
                label = "Avg Pace",
                value = uiState.formattedAvgPace,
                unit = "/km",
                color = Color(0xFFFF9F0A),
                modifier = Modifier.weight(1f)
            )
            LiveMetricCard(
                label = "Calories",
                value = "${uiState.caloriesBurned}",
                unit = "kcal",
                color = Color(0xFFFF375F),
                modifier = Modifier.weight(1f)
            )
        }

        // Splits
        if (uiState.splits.isNotEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .glass(cornerRadius = 16.dp)
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    "Splits",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold
                )
                uiState.splits.takeLast(3).forEach { split ->
                    val paceMin = split.paceSecondsPerKm / 60
                    val paceSec = split.paceSecondsPerKm % 60
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            "KM ${split.kilometer}",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Text(
                            "${paceMin}:${String.format("%02d", paceSec)} /km",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.Bold,
                            color = WorkoutGreen
                        )
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))

        // Control Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Stop button
            FloatingActionButton(
                onClick = onStop,
                containerColor = WorkoutRed,
                modifier = Modifier.size(56.dp)
            ) {
                Icon(Icons.Default.Stop, null, tint = Color.White, modifier = Modifier.size(24.dp))
            }

            // Pause/Resume button (larger)
            FloatingActionButton(
                onClick = { if (isPaused) onResume() else onPause() },
                containerColor = WorkoutGreen,
                modifier = Modifier.size(72.dp)
            ) {
                Icon(
                    if (isPaused) Icons.Default.PlayArrow else Icons.Default.Pause,
                    null,
                    tint = Color.White,
                    modifier = Modifier.size(32.dp)
                )
            }

            // Spacer for symmetry
            Spacer(modifier = Modifier.size(56.dp))
        }

        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun LiveMetricCard(
    label: String,
    value: String,
    unit: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                value,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                unit,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 4.dp)
            )
        }
    }
}

// ------------------------------------
// MARK: - Workout Summary Screen
// ------------------------------------

@Composable
fun WorkoutSummaryScreen(
    onNavigateBack: () -> Unit,
    onDone: () -> Unit
) {
    val vm = remember { AppContainer.liveWorkoutViewModel }
    val uiState by vm.uiState.collectAsState()

    // Navigate back after save
    LaunchedEffect(uiState.savedSuccessfully) {
        if (uiState.savedSuccessfully) {
            kotlinx.coroutines.delay(500)
            vm.resetState()
            onDone()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            Text(
                "Workout Complete!",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )

            Text(
                uiState.activityType.emoji + " " + uiState.activityType.displayName,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(Modifier.height(8.dp))

            // Summary Metrics
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .glass(cornerRadius = 20.dp)
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                SummaryRow("Duration", uiState.formattedElapsed)
                SummaryRow("Distance", "${uiState.formattedDistance} km")
                SummaryRow("Avg Pace", "${uiState.formattedAvgPace} /km")
                SummaryRow("Calories", "${uiState.caloriesBurned} kcal")
            }

            // Splits
            if (uiState.splits.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 20.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        "Splits",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    uiState.splits.forEach { split ->
                        val paceMin = split.paceSecondsPerKm / 60
                        val paceSec = split.paceSecondsPerKm % 60
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                "KM ${split.kilometer}",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(
                                "${paceMin}:${String.format("%02d", paceSec)} /km",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = WorkoutGreen
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.weight(1f))

            // Save Button
            Button(
                onClick = { vm.saveWorkout() },
                colors = ButtonDefaults.buttonColors(containerColor = WorkoutGreen),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth().height(56.dp)
            ) {
                Icon(Icons.Default.Save, null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Save Workout", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }

            // Discard Button
            OutlinedButton(
                onClick = {
                    vm.discardWorkout()
                    onNavigateBack()
                },
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.Delete, null, tint = WorkoutRed)
                Spacer(Modifier.width(8.dp))
                Text("Discard", color = WorkoutRed)
            }
        }
    }
}

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Bold
        )
    }
}
