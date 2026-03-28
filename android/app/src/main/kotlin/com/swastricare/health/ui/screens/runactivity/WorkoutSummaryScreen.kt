package com.swastricare.health.ui.screens.runactivity

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.RouteMapView
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

// ─────────────────────────────────────
// MARK: - WorkoutSummaryScreen
// ─────────────────────────────────────

private val GreenAccent = Color(0xFF22C55E)
private val CyanAccent = Color(0xFF00E5FF)
private val OrangeAccent = Color(0xFFFF9F0A)

@Composable
fun WorkoutSummaryScreen(
    onNavigateBack: () -> Unit = {},
    onDone: () -> Unit = {}
) {
    TrackScreen("WorkoutSummary")
    val viewModel: LiveWorkoutViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()

    // Entrance animation
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }

    val checkScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "checkScale"
    )

    // Use real workout data from the ViewModel
    val workoutType = uiState.workoutType.displayName
    val duration = uiState.elapsedFormatted
    val distance = "${uiState.distanceFormatted} km"
    val avgPace = "${uiState.paceFormatted}/km"
    val calories = "${uiState.caloriesBurned} kcal"
    val elevationGain = String.format("%.0f m", uiState.elevationGainMeters)
    val avgSpeed = String.format("%.1f km/h", uiState.averageSpeedKmh)

    Box(modifier = Modifier.fillMaxSize()) {

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(32.dp))

            // Success check icon
            Box(
                modifier = Modifier
                    .size((80 * checkScale).dp)
                    .clip(CircleShape)
                    .background(GreenAccent),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = "Complete",
                    tint = Color.White,
                    modifier = Modifier.size(40.dp)
                )
            }

            Spacer(Modifier.height(16.dp))

            Text(
                "Workout Complete!",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onBackground
            )

            Spacer(Modifier.height(4.dp))

            Text(
                workoutType,
                fontSize = 16.sp,
                color = AppColors.onBackground.copy(alpha = 0.6f)
            )

            Spacer(Modifier.height(24.dp))

            // Route map
            if (uiState.routePoints.size >= 2) {
                RouteMapView(
                    routePoints = uiState.routePoints,
                    isLive = false,
                    height = 200
                )
                Spacer(Modifier.height(24.dp))
            }

            // Main stats grid
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                SummaryStatCard(
                    icon = Icons.Default.Timer,
                    label = "Duration",
                    value = duration,
                    color = CyanAccent,
                    modifier = Modifier.weight(1f)
                )
                SummaryStatCard(
                    icon = Icons.Default.Route,
                    label = "Distance",
                    value = distance,
                    color = GreenAccent,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                SummaryStatCard(
                    icon = Icons.Default.Speed,
                    label = "Avg Pace",
                    value = avgPace,
                    color = OrangeAccent,
                    modifier = Modifier.weight(1f)
                )
                SummaryStatCard(
                    icon = Icons.Default.LocalFireDepartment,
                    label = "Calories",
                    value = calories,
                    color = Color(0xFFFF4757),
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                SummaryStatCard(
                    icon = Icons.Default.Speed,
                    label = "Avg Speed",
                    value = avgSpeed,
                    color = Color(0xFFFF6B6B),
                    modifier = Modifier.weight(1f)
                )
                SummaryStatCard(
                    icon = Icons.Default.Terrain,
                    label = "Elevation",
                    value = elevationGain,
                    color = Color(0xFF8B5CF6),
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(Modifier.weight(1f))
            Spacer(Modifier.height(24.dp))

            // Done button
            Button(
                onClick = onDone,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text("Done", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }

            Spacer(Modifier.height(100.dp))
        }
    }
}

@Composable
private fun SummaryStatCard(
    icon: ImageVector,
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .glass(cornerRadius = 16.dp)
            .padding(16.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                icon,
                contentDescription = label,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
            Spacer(Modifier.height(8.dp))
            Text(
                value,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(2.dp))
            Text(
                label,
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f)
            )
        }
    }
}
