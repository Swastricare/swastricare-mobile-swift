package com.swastricare.health.ui.screens.runactivity

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swastricare.health.data.model.RoutePoint
import com.swastricare.health.data.services.RouteTracker
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor

// ─────────────────────────────────────
// MARK: - Elevation Tab
// ─────────────────────────────────────

@Composable
fun ElevationTab(
    routePoints: List<RoutePoint>,
    modifier: Modifier = Modifier
) {
    if (routePoints.size < 2) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "No elevation data available",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
        }
        return
    }

    val altitudes = routePoints.map { it.altitude }
    val minAlt = altitudes.min()
    val maxAlt = altitudes.max()
    val elevationGain = calculateElevationGain(routePoints)

    val distances = mutableListOf(0.0)
    for (i in 1 until routePoints.size) {
        distances.add(distances.last() + RouteTracker.distanceBetween(routePoints[i - 1], routePoints[i]))
    }
    val totalDistanceKm = distances.last() / 1000.0

    Column(modifier = modifier.fillMaxWidth()) {
        // ── Stats Row ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ElevationStat("Min", "%.0f m".format(minAlt), Color(0xFF00E5FF))
            ElevationStat("Max", "%.0f m".format(maxAlt), Color(0xFFFF9F0A))
            ElevationStat("Gain", "%.0f m".format(elevationGain), PremiumColor.NeonGreenEnd)
        }

        Spacer(Modifier.height(16.dp))

        // ── Chart ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .glass(cornerRadius = 16.dp)
                .padding(16.dp)
        ) {
            ElevationChart(
                altitudes = altitudes,
                distances = distances,
                minAlt = minAlt,
                maxAlt = maxAlt
            )
        }

        Spacer(Modifier.height(8.dp))

        // ── Distance axis labels ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                "0 km",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
            Text(
                "%.1f km".format(totalDistanceKm),
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Elevation Stat Cell
// ─────────────────────────────────────

@Composable
private fun ElevationStat(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - Canvas Chart
// ─────────────────────────────────────

@Composable
private fun ElevationChart(
    altitudes: List<Double>,
    distances: List<Double>,
    minAlt: Double,
    maxAlt: Double
) {
    val lineColor = PremiumColor.NeonGreenEnd
    val fillColor = PremiumColor.NeonGreenEnd.copy(alpha = 0.2f)
    val gridColor = AppColors.onSurfaceVariant.copy(alpha = 0.1f)
    val altRange = (maxAlt - minAlt).coerceAtLeast(1.0)
    val totalDist = distances.last().coerceAtLeast(1.0)

    Canvas(modifier = Modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val padding = 4.dp.toPx()

        // ── Horizontal grid lines (5 rows) ──
        for (i in 0..4) {
            val y = padding + (h - 2 * padding) * i / 4
            drawLine(
                color = gridColor,
                start = Offset(0f, y),
                end = Offset(w, y),
                strokeWidth = 1f
            )
        }

        // ── Build elevation paths ──
        val path = Path()
        val fillPath = Path()

        for (i in altitudes.indices) {
            val x = (distances[i] / totalDist * w).toFloat()
            val y = (h - padding - ((altitudes[i] - minAlt) / altRange * (h - 2 * padding))).toFloat()

            if (i == 0) {
                path.moveTo(x, y)
                fillPath.moveTo(x, h)
                fillPath.lineTo(x, y)
            } else {
                path.lineTo(x, y)
                fillPath.lineTo(x, y)
            }
        }

        // Close fill path at bottom-right
        fillPath.lineTo(w, h)
        fillPath.close()

        // ── Draw gradient fill ──
        drawPath(
            fillPath,
            brush = Brush.verticalGradient(
                colors = listOf(fillColor, Color.Transparent),
                startY = 0f,
                endY = h
            )
        )

        // ── Draw elevation line ──
        drawPath(
            path,
            color = lineColor,
            style = Stroke(width = 2.dp.toPx())
        )
    }
}

// ─────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────

private fun calculateElevationGain(points: List<RoutePoint>): Double {
    var gain = 0.0
    for (i in 1 until points.size) {
        val diff = points[i].altitude - points[i - 1].altitude
        if (diff > 0) gain += diff
    }
    return gain
}
