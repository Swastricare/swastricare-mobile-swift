package com.swasthicare.mobile.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.maps.android.compose.*
import com.swasthicare.mobile.data.model.RoutePoint
import com.swasthicare.mobile.data.services.RouteTracker
import com.swasthicare.mobile.ui.screens.home.glass
import kotlin.math.*

// ─────────────────────────────────────
// MARK: - Design Constants
// ─────────────────────────────────────

private val MapBackground = Color(0xFF1A1A2E)
private val GridLineColor = Color(0xFF2A2A4E)
private val RouteStartColor = Color(0xFF00E5FF) // Cyan
private val RouteEndColor = Color(0xFF38EF7D)   // Green
private val StartMarkerColor = Color(0xFF38EF7D) // Green
private val EndMarkerColor = Color(0xFFFF4757)   // Red
private val LivePositionColor = Color(0xFF00B4D8) // Blue
private val DistanceMarkerColor = Color.White.copy(alpha = 0.6f)
private val NorthArrowColor = Color.White.copy(alpha = 0.7f)

// Google Maps route color
private val GoogleMapsRouteColor = android.graphics.Color.rgb(0, 229, 255) // Cyan
private val GoogleMapsRouteEndColor = android.graphics.Color.rgb(56, 239, 125) // Green

// ─────────────────────────────────────
// MARK: - RouteMapView (Google Maps)
// ─────────────────────────────────────

/**
 * Route map composable using Google Maps when available,
 * with a custom Canvas fallback.
 *
 * @param routePoints List of GPS coordinates to display
 * @param isLive Whether this is a live tracking view (auto-follows current position)
 * @param height Height of the map view
 * @param onExpand Optional callback for tap-to-expand
 */
@Composable
fun RouteMapView(
    routePoints: List<RoutePoint>,
    isLive: Boolean = false,
    height: Int = 200,
    onExpand: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val hasGoogleMaps = remember {
        try {
            // Check if Google Maps is available (API key configured)
            val ai = context.packageManager.getApplicationInfo(
                context.packageName,
                android.content.pm.PackageManager.GET_META_DATA
            )
            val key = ai.metaData?.getString("com.google.android.geo.API_KEY")
            !key.isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height.dp)
            .clip(RoundedCornerShape(20.dp))
            .then(if (onExpand != null) Modifier.clickable { onExpand() } else Modifier)
    ) {
        if (routePoints.size < 2) {
            EmptyMapState(isLive = isLive)
        } else if (hasGoogleMaps) {
            GoogleMapsRouteView(
                routePoints = routePoints,
                isLive = isLive
            )
        } else {
            CanvasRouteMapView(
                routePoints = routePoints,
                isLive = isLive
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Google Maps Implementation
// ─────────────────────────────────────

@Composable
private fun GoogleMapsRouteView(
    routePoints: List<RoutePoint>,
    isLive: Boolean
) {
    val latLngs = remember(routePoints) {
        routePoints.map { LatLng(it.latitude, it.longitude) }
    }

    val cameraPositionState = rememberCameraPositionState()

    // Camera: follow user during live tracking, fit bounds in review
    LaunchedEffect(latLngs) {
        if (latLngs.size < 2) return@LaunchedEffect

        if (isLive && latLngs.isNotEmpty()) {
            // Follow the current position during live tracking
            val current = latLngs.last()
            cameraPositionState.animate(
                CameraUpdateFactory.newCameraPosition(
                    CameraPosition.fromLatLngZoom(current, 16f)
                ),
                durationMs = 500
            )
        } else {
            // Fit all points in view for review mode
            val boundsBuilder = LatLngBounds.builder()
            latLngs.forEach { boundsBuilder.include(it) }
            try {
                cameraPositionState.animate(
                    CameraUpdateFactory.newLatLngBounds(boundsBuilder.build(), 60),
                    durationMs = 300
                )
            } catch (_: Exception) {
                // Fallback if bounds are invalid (all points same location)
                cameraPositionState.animate(
                    CameraUpdateFactory.newCameraPosition(
                        CameraPosition.fromLatLngZoom(latLngs.first(), 15f)
                    )
                )
            }
        }
    }

    val mapProperties = remember {
        MapProperties(
            mapType = MapType.NORMAL,
            isMyLocationEnabled = false
        )
    }

    val mapUiSettings = remember {
        MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false,
            myLocationButtonEnabled = false,
            compassEnabled = false,
            scrollGesturesEnabled = !isLive,
            zoomGesturesEnabled = !isLive,
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
        // Route polyline with gradient effect using multiple segments
        if (latLngs.size >= 2) {
            // Draw the full route as a polyline
            Polyline(
                points = latLngs,
                color = androidx.compose.ui.graphics.Color(0xFF00E5FF),
                width = 12f
            )

            // Glow effect (wider, semi-transparent polyline underneath)
            Polyline(
                points = latLngs,
                color = androidx.compose.ui.graphics.Color(0xFF00E5FF).copy(alpha = 0.2f),
                width = 24f
            )

            // Start marker
            Marker(
                state = MarkerState(position = latLngs.first()),
                title = "Start",
                icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                    .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_GREEN)
            )

            // End / current position marker
            if (!isLive) {
                Marker(
                    state = MarkerState(position = latLngs.last()),
                    title = "Finish",
                    icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                        .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_RED)
                )
            } else {
                // Live blue marker for current position
                Circle(
                    center = latLngs.last(),
                    radius = 8.0,
                    fillColor = androidx.compose.ui.graphics.Color(0xFF00B4D8),
                    strokeColor = androidx.compose.ui.graphics.Color.White,
                    strokeWidth = 3f
                )
            }

            // Distance markers every 1km
            var accumulatedDistance = 0.0
            var nextMarkerKm = 1.0
            for (i in 1 until routePoints.size) {
                val dist = RouteTracker.distanceBetween(routePoints[i - 1], routePoints[i])
                accumulatedDistance += dist
                if (accumulatedDistance / 1000.0 >= nextMarkerKm) {
                    Marker(
                        state = MarkerState(
                            position = LatLng(routePoints[i].latitude, routePoints[i].longitude)
                        ),
                        title = "${nextMarkerKm.toInt()} km",
                        icon = com.google.android.gms.maps.model.BitmapDescriptorFactory
                            .defaultMarker(com.google.android.gms.maps.model.BitmapDescriptorFactory.HUE_CYAN)
                    )
                    nextMarkerKm += 1.0
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Canvas Fallback Implementation
// ─────────────────────────────────────

@Composable
private fun CanvasRouteMapView(
    routePoints: List<RoutePoint>,
    isLive: Boolean
) {
    val infiniteTransition = rememberInfiniteTransition(label = "livePosition")

    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 2.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulseScale"
    )

    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulseAlpha"
    )

    val textMeasurer = rememberTextMeasurer()

    Canvas(
        modifier = Modifier
            .fillMaxSize()
            .background(MapBackground)
    ) {
        val padding = 40f
        val canvasWidth = size.width
        val canvasHeight = size.height
        val drawWidth = canvasWidth - padding * 2
        val drawHeight = canvasHeight - padding * 2

        val minLat = routePoints.minOf { it.latitude }
        val maxLat = routePoints.maxOf { it.latitude }
        val minLng = routePoints.minOf { it.longitude }
        val maxLng = routePoints.maxOf { it.longitude }

        val latRange = (maxLat - minLat).coerceAtLeast(0.0001)
        val lngRange = (maxLng - minLng).coerceAtLeast(0.0001)

        val latScale = drawHeight / latRange
        val lngScale = drawWidth / lngRange
        val scale = min(latScale, lngScale)

        val offsetX = padding + (drawWidth - lngRange * scale).toFloat() / 2f
        val offsetY = padding + (drawHeight - latRange * scale).toFloat() / 2f

        fun project(point: RoutePoint): Offset {
            val x = ((point.longitude - minLng) * scale).toFloat() + offsetX
            val y = ((maxLat - point.latitude) * scale).toFloat() + offsetY
            return Offset(x, y)
        }

        // Grid lines
        drawGridLines(canvasWidth, canvasHeight)

        // Route polyline with gradient
        drawRouteGradient(routePoints, ::project)

        // Distance markers
        drawDistanceMarkers(routePoints, ::project, textMeasurer)

        // Start marker
        val startPos = project(routePoints.first())
        drawCircle(color = Color.White, radius = 10f, center = startPos)
        drawCircle(color = StartMarkerColor, radius = 7f, center = startPos)

        // End / current position marker
        val endPos = project(routePoints.last())
        if (isLive) {
            drawCircle(
                color = LivePositionColor.copy(alpha = pulseAlpha),
                radius = 12f * pulseScale,
                center = endPos
            )
            drawCircle(color = Color.White, radius = 9f, center = endPos)
            drawCircle(color = LivePositionColor, radius = 6f, center = endPos)
        } else {
            drawCircle(color = Color.White, radius = 10f, center = endPos)
            drawCircle(color = EndMarkerColor, radius = 7f, center = endPos)
        }

        // North arrow
        drawNorthArrow(canvasWidth)
    }
}

// ─────────────────────────────────────
// MARK: - Drawing Helpers
// ─────────────────────────────────────

private fun DrawScope.drawGridLines(
    canvasWidth: Float,
    canvasHeight: Float
) {
    val gridSpacing = 50f
    val gridColor = GridLineColor

    var x = gridSpacing
    while (x < canvasWidth) {
        drawLine(color = gridColor, start = Offset(x, 0f), end = Offset(x, canvasHeight), strokeWidth = 0.5f)
        x += gridSpacing
    }

    var y = gridSpacing
    while (y < canvasHeight) {
        drawLine(color = gridColor, start = Offset(0f, y), end = Offset(canvasWidth, y), strokeWidth = 0.5f)
        y += gridSpacing
    }
}

private fun DrawScope.drawRouteGradient(
    points: List<RoutePoint>,
    project: (RoutePoint) -> Offset
) {
    if (points.size < 2) return
    val projected = points.map { project(it) }

    for (i in 0 until projected.size - 1) {
        val fraction = i.toFloat() / (projected.size - 1).coerceAtLeast(1)
        val segmentColor = lerp(RouteStartColor, RouteEndColor, fraction)

        drawLine(
            color = segmentColor,
            start = projected[i],
            end = projected[i + 1],
            strokeWidth = 3.dp.toPx(),
            cap = StrokeCap.Round
        )
    }

    // Glow
    for (i in 0 until projected.size - 1) {
        val fraction = i.toFloat() / (projected.size - 1).coerceAtLeast(1)
        val segmentColor = lerp(RouteStartColor, RouteEndColor, fraction)

        drawLine(
            color = segmentColor.copy(alpha = 0.15f),
            start = projected[i],
            end = projected[i + 1],
            strokeWidth = 8.dp.toPx(),
            cap = StrokeCap.Round
        )
    }
}

private fun DrawScope.drawDistanceMarkers(
    points: List<RoutePoint>,
    project: (RoutePoint) -> Offset,
    textMeasurer: TextMeasurer
) {
    if (points.size < 2) return

    var accumulatedDistance = 0.0
    var nextMarkerKm = 1.0

    for (i in 1 until points.size) {
        val dist = RouteTracker.distanceBetween(points[i - 1], points[i])
        accumulatedDistance += dist

        if (accumulatedDistance / 1000.0 >= nextMarkerKm) {
            val pos = project(points[i])
            drawCircle(color = DistanceMarkerColor, radius = 4f, center = pos)
            val label = "${nextMarkerKm.toInt()} km"
            val textResult = textMeasurer.measure(
                text = AnnotatedString(label),
                style = TextStyle(
                    color = DistanceMarkerColor,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Medium
                )
            )
            drawText(
                textLayoutResult = textResult,
                topLeft = Offset(pos.x - textResult.size.width / 2f, pos.y - textResult.size.height - 6f)
            )
            nextMarkerKm += 1.0
        }
    }
}

private fun DrawScope.drawNorthArrow(canvasWidth: Float) {
    val cx = canvasWidth - 28f
    val cy = 28f
    val arrowSize = 14f

    val path = Path().apply {
        moveTo(cx, cy - arrowSize)
        lineTo(cx - arrowSize / 2.5f, cy + arrowSize * 0.4f)
        lineTo(cx, cy + arrowSize * 0.15f)
        lineTo(cx + arrowSize / 2.5f, cy + arrowSize * 0.4f)
        close()
    }
    drawPath(path, color = NorthArrowColor, style = Fill)
}

// ─────────────────────────────────────
// MARK: - Color Interpolation
// ─────────────────────────────────────

private fun lerp(start: Color, end: Color, fraction: Float): Color {
    val f = fraction.coerceIn(0f, 1f)
    return Color(
        red = start.red + (end.red - start.red) * f,
        green = start.green + (end.green - start.green) * f,
        blue = start.blue + (end.blue - start.blue) * f,
        alpha = start.alpha + (end.alpha - start.alpha) * f
    )
}

// ─────────────────────────────────────
// MARK: - Empty Map State
// ─────────────────────────────────────

@Composable
private fun EmptyMapState(isLive: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MapBackground),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = if (isLive) Icons.Default.MyLocation else Icons.Default.GpsFixed,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(32.dp)
            )
            Text(
                text = if (isLive) "Waiting for GPS signal..." else "No route recorded",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.4f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - GPS Status Chip
// ─────────────────────────────────────

@Composable
fun GpsStatusChip(
    gpsStatus: RouteTracker.GpsStatus,
    modifier: Modifier = Modifier
) {
    val (chipColor, label) = when (gpsStatus) {
        RouteTracker.GpsStatus.OFF -> Color.Gray to "GPS Off"
        RouteTracker.GpsStatus.SEARCHING -> Color(0xFFFFA500) to "Searching..."
        RouteTracker.GpsStatus.POOR -> Color(0xFFFF6B6B) to "Poor Signal"
        RouteTracker.GpsStatus.GOOD -> Color(0xFF38EF7D) to "GPS Fixed"
    }

    Row(
        modifier = modifier
            .background(
                color = chipColor.copy(alpha = 0.15f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Canvas(modifier = Modifier.size(6.dp)) {
            drawCircle(color = chipColor)
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = chipColor,
            fontWeight = FontWeight.Medium
        )
    }
}
