package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.*
import com.swastricare.health.R
import com.swastricare.health.ui.components.GpsStatusChip
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutUiState
import com.swastricare.health.ui.theme.*
import kotlinx.coroutines.launch
import kotlin.math.*

/**
 * Full-screen map tracking layout.
 * Map fills the entire screen; timer, stats, and controls float on top.
 */
@Composable
fun WorkoutPhaseTracking(
    uiState: LiveWorkoutUiState,
    isPaused: Boolean = false,
    onPause: () -> Unit,
    onResume: () -> Unit = {},
    onStop: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val isDark = isSystemInDarkTheme()
    val scrimColor = if (isDark) Color.Black else Color.White
    val textColor = if (isDark) Color.White else Color.Black
    val subtextColor = if (isDark) Color.White.copy(alpha = 0.6f) else Color.Black.copy(alpha = 0.5f)
    val statSubColor = if (isDark) Color.White.copy(alpha = 0.5f) else Color.Black.copy(alpha = 0.4f)
    val pauseBg = if (isDark) Color.White else Color.Black
    val pauseIcon = if (isDark) Color.Black else Color.White
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
        // Layer 1: Full-screen Google Map
        // ═══════════════════════════════════════
        if (uiState.workoutType.usesGps && uiState.hasLocationPermission) {
            FullScreenTrackingMap(uiState, isDark)
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(fallbackBg),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    when (uiState.workoutType) {
                        com.swastricare.health.ui.screens.runactivity.WorkoutType.SWIM -> Icons.Default.Pool
                        else -> Icons.Default.FitnessCenter
                    },
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
                .height(280.dp)
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
        // Layer 3: Top bar
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
                if (isPaused) {
                    Text(
                        "PAUSED",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFFFD60A).copy(alpha = pulseAlpha),
                        letterSpacing = 2.sp
                    )
                }
            }
            Spacer(Modifier.width(48.dp))
        }

        // ═══════════════════════════════════════
        // Layer 4: Bottom overlay — timer, stats, pause
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
                color = if (isPaused) textColor.copy(alpha = 0.5f) else textColor,
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
                    .padding(horizontal = 24.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TrackingStatItem(value = uiState.distanceFormatted, label = "km", color = textColor, subColor = statSubColor)
                TrackingStatItem(value = uiState.currentPaceFormatted, label = "pace", color = textColor, subColor = statSubColor)
                TrackingStatItem(value = uiState.paceFormatted, label = "avg", color = textColor, subColor = statSubColor)
                TrackingStatItem(value = if (uiState.caloriesBurned > 0) "${uiState.caloriesBurned}" else "--", label = "kcal", color = textColor, subColor = statSubColor)
            }

            if (uiState.distanceMeters > 10) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "KM ${uiState.currentKmSplit}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF00E5FF).copy(alpha = 0.8f),
                    letterSpacing = 1.sp
                )
            }

            Spacer(Modifier.height(32.dp))

            // ── Control buttons: Stop | Pause | Play ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Stop (hold 3s)
                HoldToStopButton(
                    enabled = isPaused,
                    onComplete = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        onStop()
                    }
                )

                // Pause
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(
                            if (!isPaused) pauseBg else pauseBg.copy(alpha = 0.2f)
                        )
                        .then(
                            if (!isPaused) Modifier.clickable {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                onPause()
                            } else Modifier
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Pause,
                        contentDescription = "Pause",
                        tint = if (!isPaused) pauseIcon else pauseIcon.copy(alpha = 0.3f),
                        modifier = Modifier.size(32.dp)
                    )
                }

                // Play / Resume
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(
                            if (isPaused) SecondaryColor else SecondaryColor.copy(alpha = 0.2f)
                        )
                        .then(
                            if (isPaused) Modifier.clickable {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                onResume()
                            } else Modifier
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.PlayArrow,
                        contentDescription = "Resume",
                        tint = if (isPaused) Color.White else Color.White.copy(alpha = 0.3f),
                        modifier = Modifier.size(36.dp)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// Full-screen Google Map for tracking
// ─────────────────────────────────────

@Composable
private fun FullScreenTrackingMap(uiState: LiveWorkoutUiState, isDark: Boolean) {
    val context = LocalContext.current
    val cameraPositionState = rememberCameraPositionState()

    val latLngs = remember(uiState.routePoints) {
        uiState.routePoints.map { LatLng(it.latitude, it.longitude) }
    }

    // Adaptive zoom based on speed
    val adaptiveZoom = remember(uiState.currentSpeedMps) {
        val speedKmh = uiState.currentSpeedMps * 3.6f
        when {
            speedKmh > 30f -> 14f
            speedKmh > 15f -> 15f
            speedKmh > 5f  -> 16f
            else           -> 17f
        }
    }

    // Follow current position
    LaunchedEffect(latLngs, uiState.currentLocation, adaptiveZoom) {
        val target = if (latLngs.size >= 2) {
            latLngs.last()
        } else if (uiState.currentLocation != null) {
            LatLng(uiState.currentLocation.first, uiState.currentLocation.second)
        } else {
            return@LaunchedEffect
        }

        val bearing = if (latLngs.size >= 2) {
            computeBearing(latLngs[latLngs.size - 2], latLngs.last())
        } else 0f

        cameraPositionState.animate(
            CameraUpdateFactory.newCameraPosition(
                CameraPosition.Builder()
                    .target(target)
                    .zoom(adaptiveZoom)
                    .bearing(bearing)
                    .tilt(if (uiState.currentSpeedMps > 2f) 30f else 0f)
                    .build()
            ),
            durationMs = 500
        )
    }

    val mapStyle = remember(isDark) {
        if (isDark) {
            try {
                MapStyleOptions.loadRawResourceStyle(context, R.raw.map_style_dark)
            } catch (_: Exception) { null }
        } else {
            null // default Google Maps light style
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
            // Glow polyline
            Polyline(
                points = latLngs,
                color = Color(0xFF00E5FF).copy(alpha = 0.2f),
                width = 24f
            )
            // Route polyline
            Polyline(
                points = latLngs,
                color = Color(0xFF00E5FF),
                width = 12f
            )
            // Start marker
            Marker(
                state = MarkerState(position = latLngs.first()),
                title = "Start",
                icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                    .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_GREEN)
            )
            // Live position circle
            Circle(
                center = latLngs.last(),
                radius = 8.0,
                fillColor = Color(0xFF00B4D8),
                strokeColor = Color.White,
                strokeWidth = 3f
            )
        } else if (uiState.currentLocation != null) {
            Circle(
                center = LatLng(uiState.currentLocation.first, uiState.currentLocation.second),
                radius = 8.0,
                fillColor = Color(0xFF00B4D8),
                strokeColor = Color.White,
                strokeWidth = 3f
            )
        }
    }
}

// ─────────────────────────────────────
// Stat item for overlay
// ─────────────────────────────────────

@Composable
private fun TrackingStatItem(value: String, label: String, color: Color, subColor: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = label,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = subColor
        )
    }
}

// ─────────────────────────────────────
// Hold-to-stop button with circular progress
// ─────────────────────────────────────

@Composable
private fun HoldToStopButton(enabled: Boolean, onComplete: () -> Unit) {
    val progress = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    var completed by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    val stopRed = Color(0xFFFF4757)
    val alpha = if (enabled) 1f else 0.3f

    Box(
        modifier = Modifier
            .size(72.dp)
            .drawBehind {
                drawCircle(
                    color = stopRed.copy(alpha = 0.15f * alpha),
                    radius = size.minDimension / 2f
                )
                if (progress.value > 0f) {
                    val strokeWidth = 4.dp.toPx()
                    val arcSize = size.minDimension - strokeWidth
                    drawArc(
                        color = stopRed,
                        startAngle = -90f,
                        sweepAngle = 360f * progress.value,
                        useCenter = false,
                        topLeft = Offset(strokeWidth / 2f, strokeWidth / 2f),
                        size = Size(arcSize, arcSize),
                        style = Stroke(width = strokeWidth)
                    )
                }
            }
            .then(
                if (enabled && !completed) {
                    Modifier.pointerInput(Unit) {
                        detectTapGestures(
                            onPress = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                val job = scope.launch {
                                    progress.animateTo(
                                        targetValue = 1f,
                                        animationSpec = tween(
                                            durationMillis = 3000,
                                            easing = LinearEasing
                                        )
                                    )
                                    completed = true
                                    onComplete()
                                }
                                tryAwaitRelease()
                                if (!completed) {
                                    job.cancel()
                                    scope.launch {
                                        progress.animateTo(0f, animationSpec = tween(200))
                                    }
                                }
                            }
                        )
                    }
                } else Modifier
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            Icons.Default.Stop,
            contentDescription = "Hold to stop",
            tint = stopRed.copy(alpha = alpha),
            modifier = Modifier.size(28.dp)
        )
    }
}

// ─────────────────────────────────────
// Bearing helper
// ─────────────────────────────────────

private fun computeBearing(from: LatLng, to: LatLng): Float {
    val fromLat = Math.toRadians(from.latitude)
    val toLat = Math.toRadians(to.latitude)
    val dLng = Math.toRadians(to.longitude - from.longitude)
    val y = sin(dLng) * cos(toLat)
    val x = cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(dLng)
    val bearing = Math.toDegrees(atan2(y, x)).toFloat()
    return (bearing + 360f) % 360f
}
