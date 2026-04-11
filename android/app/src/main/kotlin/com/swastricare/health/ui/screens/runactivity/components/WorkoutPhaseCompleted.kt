package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.*
import com.swastricare.health.R
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutUiState
import com.swastricare.health.ui.theme.SecondaryColor

/**
 * COMPLETED phase - full-screen map with route + overlaid summary stats.
 */
@Composable
fun WorkoutPhaseCompleted(
    uiState: LiveWorkoutUiState,
    onDone: () -> Unit,
    onDiscard: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val isDark = isSystemInDarkTheme()
    val scrimColor = if (isDark) Color.Black else Color.White
    val textColor = if (isDark) Color.White else Color.Black
    val subtextColor = if (isDark) Color.White.copy(alpha = 0.6f) else Color.Black.copy(alpha = 0.5f)
    val cardBg = if (isDark) Color.White.copy(alpha = 0.08f) else Color.Black.copy(alpha = 0.05f)
    val solidGreen = SecondaryColor

    Box(modifier = Modifier.fillMaxSize()) {

        // ═══════════════════════════════════════
        // Layer 1: Full-screen map (always shown)
        // ═══════════════════════════════════════
        CompletedRouteMap(uiState, isDark)

        // Gradient scrims
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .background(
                    Brush.verticalGradient(
                        listOf(scrimColor.copy(alpha = 0.7f), Color.Transparent)
                    )
                )
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.6f)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color.Transparent,
                            scrimColor.copy(alpha = 0.8f),
                            scrimColor.copy(alpha = 0.95f)
                        )
                    )
                )
        )

        // ═══════════════════════════════════════
        // Layer 3: Top header
        // ═══════════════════════════════════════
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                "Workout Complete",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = solidGreen
            )
            Spacer(Modifier.height(2.dp))
            Text(
                uiState.workoutType.displayName,
                style = MaterialTheme.typography.bodySmall,
                color = subtextColor
            )
        }

        // ═══════════════════════════════════════
        // Layer 4: Bottom content — stats + buttons
        // ═══════════════════════════════════════
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Duration (hero stat)
            Text(
                text = uiState.elapsedFormatted,
                fontSize = 52.sp,
                fontWeight = FontWeight.Bold,
                color = textColor,
                letterSpacing = (-1).sp
            )
            Text(
                "Duration",
                fontSize = 13.sp,
                color = subtextColor
            )

            Spacer(Modifier.height(20.dp))

            // Stats grid: 2x2
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                CompletedStatCard(
                    icon = Icons.Default.Place,
                    value = "${uiState.distanceFormatted} km",
                    label = "Distance",
                    iconColor = Color(0xFF00B4D8),
                    bgColor = cardBg,
                    textColor = textColor,
                    subtextColor = subtextColor,
                    modifier = Modifier.weight(1f)
                )
                CompletedStatCard(
                    icon = Icons.Default.Speed,
                    value = "${uiState.paceFormatted} /km",
                    label = "Avg Pace",
                    iconColor = Color(0xFFFF9F1C),
                    bgColor = cardBg,
                    textColor = textColor,
                    subtextColor = subtextColor,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                CompletedStatCard(
                    icon = Icons.Default.LocalFireDepartment,
                    value = if (uiState.caloriesBurned > 0) "${uiState.caloriesBurned} kcal" else "-- kcal",
                    label = "Calories",
                    iconColor = Color(0xFFFF4757),
                    bgColor = cardBg,
                    textColor = textColor,
                    subtextColor = subtextColor,
                    modifier = Modifier.weight(1f)
                )
                CompletedStatCard(
                    icon = Icons.Default.TrendingUp,
                    value = String.format("%.1f km/h", uiState.averageSpeedKmh),
                    label = "Avg Speed",
                    iconColor = Color(0xFF4F46E5),
                    bgColor = cardBg,
                    textColor = textColor,
                    subtextColor = subtextColor,
                    modifier = Modifier.weight(1f)
                )
            }

            // Extra stats row if available
            if (uiState.elevationGainMeters > 0 || uiState.maxSpeedMps > 0) {
                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    CompletedStatCard(
                        icon = Icons.Default.Terrain,
                        value = String.format("%.0f m", uiState.elevationGainMeters),
                        label = "Elevation",
                        iconColor = Color(0xFF8B5CF6),
                        bgColor = cardBg,
                        textColor = textColor,
                        subtextColor = subtextColor,
                        modifier = Modifier.weight(1f)
                    )
                    CompletedStatCard(
                        icon = Icons.Default.Bolt,
                        value = String.format("%.1f km/h", uiState.maxSpeedMps * 3.6f),
                        label = "Max Speed",
                        iconColor = Color(0xFFFFD60A),
                        bgColor = cardBg,
                        textColor = textColor,
                        subtextColor = subtextColor,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            // Save button
            Button(
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onDone()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                colors = ButtonDefaults.buttonColors(containerColor = solidGreen),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text("Save Workout", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }

            Spacer(Modifier.height(8.dp))

            // Discard
            TextButton(
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onDiscard()
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    "Discard",
                    color = Color(0xFFFF4757).copy(alpha = 0.6f),
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

// ─────────────────────────────────────
// Full-screen map showing completed route
// ─────────────────────────────────────

@Composable
private fun CompletedRouteMap(uiState: LiveWorkoutUiState, isDark: Boolean) {
    val context = LocalContext.current
    val cameraPositionState = rememberCameraPositionState()

    val latLngs = remember(uiState.routePoints) {
        uiState.routePoints.map { LatLng(it.latitude, it.longitude) }
    }

    LaunchedEffect(latLngs, uiState.currentLocation) {
        if (latLngs.size >= 2) {
            val boundsBuilder = LatLngBounds.builder()
            latLngs.forEach { boundsBuilder.include(it) }
            try {
                cameraPositionState.animate(
                    CameraUpdateFactory.newLatLngBounds(boundsBuilder.build(), 100),
                    durationMs = 600
                )
            } catch (_: Exception) {
                cameraPositionState.animate(
                    CameraUpdateFactory.newLatLngZoom(latLngs.first(), 15f)
                )
            }
        } else if (uiState.currentLocation != null) {
            cameraPositionState.animate(
                CameraUpdateFactory.newLatLngZoom(
                    LatLng(uiState.currentLocation.first, uiState.currentLocation.second),
                    15f
                ),
                durationMs = 600
            )
        }
    }

    val mapStyle = remember(isDark) {
        if (isDark) {
            try {
                MapStyleOptions.loadRawResourceStyle(context, R.raw.map_style_dark)
            } catch (_: Exception) { null }
        } else null
    }

    GoogleMap(
        modifier = Modifier.fillMaxSize(),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(
            mapType = MapType.NORMAL,
            isMyLocationEnabled = false,
            mapStyleOptions = mapStyle
        ),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false,
            myLocationButtonEnabled = false,
            compassEnabled = false,
            scrollGesturesEnabled = true,
            zoomGesturesEnabled = true,
            tiltGesturesEnabled = false,
            rotationGesturesEnabled = false
        )
    ) {
        if (latLngs.size >= 2) {
            // Glow
            Polyline(
                points = latLngs,
                color = SecondaryColor.copy(alpha = 0.2f),
                width = 24f
            )
            // Route
            Polyline(
                points = latLngs,
                color = SecondaryColor,
                width = 10f
            )
            // Start marker
            Marker(
                state = MarkerState(position = latLngs.first()),
                title = "Start",
                icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                    .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_GREEN)
            )
            // End marker
            Marker(
                state = MarkerState(position = latLngs.last()),
                title = "Finish",
                icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                    .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_RED)
            )
        } else if (uiState.currentLocation != null) {
            Circle(
                center = LatLng(uiState.currentLocation.first, uiState.currentLocation.second),
                radius = 10.0,
                fillColor = SecondaryColor,
                strokeColor = Color.White,
                strokeWidth = 3f
            )
        }
    }
}

// ─────────────────────────────────────
// Stat card for completed screen
// ─────────────────────────────────────

@Composable
private fun CompletedStatCard(
    icon: ImageVector,
    value: String,
    label: String,
    iconColor: Color,
    bgColor: Color,
    textColor: Color,
    subtextColor: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = bgColor),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = value,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = textColor
            )
            Text(
                text = label,
                fontSize = 11.sp,
                color = subtextColor
            )
        }
    }
}
