package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.*
import com.swastricare.health.R
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutUiState
import com.swastricare.health.ui.theme.PremiumColor
import com.swastricare.health.ui.theme.SecondaryColor

/**
 * PAUSED phase - Full-screen map with route overview + pulsing PAUSED indicator.
 */
@Composable
fun WorkoutPhasePaused(
    uiState: LiveWorkoutUiState,
    onResume: () -> Unit,
    onStop: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val isDark = isSystemInDarkTheme()
    val scrimColor = if (isDark) Color.Black else Color.White
    val textColor = if (isDark) Color.White else Color.Black
    val dimTextColor = if (isDark) Color.White.copy(alpha = 0.5f) else Color.Black.copy(alpha = 0.4f)
    val subtextColor = if (isDark) Color.White.copy(alpha = 0.4f) else Color.Black.copy(alpha = 0.35f)
    val statColor = if (isDark) Color.White.copy(alpha = 0.7f) else Color.Black.copy(alpha = 0.7f)
    val statSubColor = if (isDark) Color.White.copy(alpha = 0.4f) else Color.Black.copy(alpha = 0.35f)
    val fallbackBg = if (isDark) Color(0xFF1A1A2E) else Color(0xFFF0F0F5)

    // Pulsing animation for PAUSED indicator
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

    Box(modifier = Modifier.fillMaxSize()) {

        // ═══════════════════════════════════════
        // Layer 1: Full-screen map (static, fits route)
        // ═══════════════════════════════════════
        if (uiState.workoutType.usesGps && uiState.routePoints.size >= 2) {
            PausedFullScreenMap(uiState, isDark)
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(fallbackBg),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.FitnessCenter,
                    contentDescription = null,
                    tint = textColor.copy(alpha = 0.1f),
                    modifier = Modifier.size(120.dp)
                )
            }
        }

        // ═══════════════════════════════════════
        // Layer 2: Gradient scrims
        // ═══════════════════════════════════════
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
                .background(
                    Brush.verticalGradient(
                        listOf(
                            scrimColor.copy(alpha = 0.6f),
                            Color.Transparent
                        )
                    )
                )
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(300.dp)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color.Transparent,
                            scrimColor.copy(alpha = 0.7f),
                            scrimColor.copy(alpha = 0.85f)
                        )
                    )
                )
        )

        // ═══════════════════════════════════════
        // Layer 3: Top bar with PAUSED label
        // ═══════════════════════════════════════
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { onStop() }) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Stop",
                    tint = textColor
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    uiState.workoutType.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = textColor
                )
                Text(
                    "PAUSED",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFFFFD60A).copy(alpha = pulseAlpha),
                    letterSpacing = 2.sp
                )
            }
            Spacer(Modifier.width(48.dp))
        }

        // ═══════════════════════════════════════
        // Layer 4: Bottom overlay — timer, stats, resume/stop
        // ═══════════════════════════════════════
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = uiState.elapsedFormatted,
                fontSize = 64.sp,
                fontWeight = FontWeight.Bold,
                color = dimTextColor,
                letterSpacing = (-1).sp
            )

            Spacer(Modifier.height(4.dp))

            Text(
                text = "Duration",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = subtextColor
            )

            Spacer(Modifier.height(24.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                PausedStatItem(value = uiState.distanceFormatted, label = "km", color = statColor, subColor = statSubColor)
                PausedStatItem(value = uiState.paceFormatted, label = "/km", color = statColor, subColor = statSubColor)
                PausedStatItem(value = if (uiState.caloriesBurned > 0) "${uiState.caloriesBurned}" else "--", label = "kcal", color = statColor, subColor = statSubColor)
            }

            Spacer(Modifier.height(32.dp))

            // Resume + Stop buttons
            Row(
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Stop button (smaller, red outline)
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFFF4757).copy(alpha = 0.2f))
                        .clickable {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            onStop()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Stop,
                        contentDescription = "Stop",
                        tint = Color(0xFFFF4757),
                        modifier = Modifier.size(28.dp)
                    )
                }

                // Resume button (large, green)
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(SecondaryColor)
                        .clickable {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            onResume()
                        },
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
}

// ─────────────────────────────────────
// Full-screen map for paused state (fits entire route)
// ─────────────────────────────────────

@Composable
private fun PausedFullScreenMap(uiState: LiveWorkoutUiState, isDark: Boolean) {
    val context = LocalContext.current
    val cameraPositionState = rememberCameraPositionState()

    val latLngs = remember(uiState.routePoints) {
        uiState.routePoints.map { LatLng(it.latitude, it.longitude) }
    }

    // Fit all route points in view
    LaunchedEffect(latLngs) {
        if (latLngs.size < 2) return@LaunchedEffect
        val boundsBuilder = LatLngBounds.builder()
        latLngs.forEach { boundsBuilder.include(it) }
        try {
            cameraPositionState.animate(
                CameraUpdateFactory.newLatLngBounds(boundsBuilder.build(), 80),
                durationMs = 300
            )
        } catch (_: Exception) {
            cameraPositionState.animate(
                CameraUpdateFactory.newCameraPosition(
                    CameraPosition.fromLatLngZoom(latLngs.first(), 15f)
                )
            )
        }
    }

    val mapStyle = remember(isDark) {
        if (isDark) {
            try {
                MapStyleOptions.loadRawResourceStyle(context, R.raw.map_style_dark)
            } catch (_: Exception) { null }
        } else {
            null
        }
    }

    val mapProperties = remember(mapStyle) {
        MapProperties(
            mapType = MapType.NORMAL,
            isMyLocationEnabled = false,
            mapStyleOptions = mapStyle
        )
    }

    val mapUiSettings = remember {
        MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false,
            myLocationButtonEnabled = false,
            compassEnabled = false,
            scrollGesturesEnabled = true,
            zoomGesturesEnabled = true,
            tiltGesturesEnabled = false,
            rotationGesturesEnabled = false
        )
    }

    GoogleMap(
        modifier = Modifier.fillMaxSize(),
        cameraPositionState = cameraPositionState,
        properties = mapProperties,
        uiSettings = mapUiSettings
    ) {
        if (latLngs.size >= 2) {
            Polyline(
                points = latLngs,
                color = Color(0xFF00E5FF).copy(alpha = 0.2f),
                width = 24f
            )
            Polyline(
                points = latLngs,
                color = Color(0xFF00E5FF),
                width = 12f
            )
            Marker(
                state = MarkerState(position = latLngs.first()),
                title = "Start",
                icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                    .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_GREEN)
            )
            Marker(
                state = MarkerState(position = latLngs.last()),
                title = "Current",
                icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                    .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_CYAN)
            )
        }
    }
}

// ─────────────────────────────────────
// Stat item for paused overlay
// ─────────────────────────────────────

@Composable
private fun PausedStatItem(value: String, label: String, color: Color, subColor: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = label,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = subColor
        )
    }
}
