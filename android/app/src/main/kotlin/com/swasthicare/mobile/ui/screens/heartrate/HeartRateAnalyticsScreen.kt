package com.swasthicare.mobile.ui.screens.heartrate

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.HeartRateColor
import com.swasthicare.mobile.ui.theme.PremiumColor
import com.swasthicare.mobile.ui.theme.AppColors
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

// Zone colors (same as HeartRateScreen)
private val ZoneNormal = Color(0xFF4CAF50)
private val ZoneElevated = Color(0xFFFFC107)
private val ZoneHigh = Color(0xFFF44336)
private val ZoneLow = Color(0xFF2196F3)

// ─────────────────────────────────────
// MARK: - Time Range
// ─────────────────────────────────────

enum class TimeRange(val label: String, val days: Int) {
    DAY("Day", 1),
    WEEK("Week", 7),
    MONTH("Month", 30)
}

// ─────────────────────────────────────
// MARK: - Analytics ViewModel
// ─────────────────────────────────────

data class HeartRateAnalyticsState(
    val readings: List<HeartRateReading> = emptyList(),
    val selectedRange: TimeRange = TimeRange.WEEK,
    val isLoading: Boolean = true,
    val showClearConfirmation: Boolean = false
) {
    val filteredReadings: List<HeartRateReading>
        get() {
            val cutoff = LocalDateTime.now().minus(selectedRange.days.toLong(), ChronoUnit.DAYS)
            val cutoffStr = cutoff.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            return readings.filter { it.timestamp >= cutoffStr }.sortedBy { it.timestamp }
        }

    val averageBpm: Int
        get() = if (filteredReadings.isEmpty()) 0
        else filteredReadings.map { it.bpm }.average().toInt()

    val minBpm: Int
        get() = filteredReadings.minOfOrNull { it.bpm } ?: 0

    val maxBpm: Int
        get() = filteredReadings.maxOfOrNull { it.bpm } ?: 0
}

// ─────────────────────────────────────
// MARK: - HeartRateAnalyticsScreen
// ─────────────────────────────────────

@Composable
fun HeartRateAnalyticsScreen(
    onNavigateBack: () -> Unit = {}
) {
    val heartRateViewModel = AppContainer.heartRateViewModel
    var state by remember { mutableStateOf(HeartRateAnalyticsState()) }

    // Load data
    LaunchedEffect(Unit) {
        delay(300) // Brief loading shimmer
        val readings = heartRateViewModel.getReadings()
        state = state.copy(readings = readings, isLoading = false)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
        ) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack, "Back",
                        tint = AppColors.onSurface
                    )
                }
                Text(
                    "Heart Rate Analytics",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                // Clear history button
                if (state.readings.isNotEmpty()) {
                    IconButton(onClick = { state = state.copy(showClearConfirmation = true) }) {
                        Icon(
                            Icons.Default.DeleteOutline, "Clear History",
                            tint = AppColors.onSurfaceVariant
                        )
                    }
                }
            }

            when {
                state.isLoading -> AnalyticsSkeletonContent()
                state.readings.isEmpty() -> EmptyAnalyticsContent()
                else -> AnalyticsContent(
                    state = state,
                    onRangeSelected = { range ->
                        state = state.copy(selectedRange = range)
                    }
                )
            }
        }

        // Clear confirmation dialog
        if (state.showClearConfirmation) {
            AlertDialog(
                onDismissRequest = { state = state.copy(showClearConfirmation = false) },
                icon = {
                    Icon(
                        Icons.Default.Warning,
                        contentDescription = null,
                        tint = ZoneHigh
                    )
                },
                title = {
                    Text("Clear History?")
                },
                text = {
                    Text("This will permanently delete all your heart rate readings. This action cannot be undone.")
                },
                confirmButton = {
                    TextButton(
                        onClick = {
                            heartRateViewModel.clearReadings()
                            state = state.copy(
                                readings = emptyList(),
                                showClearConfirmation = false
                            )
                        },
                        colors = ButtonDefaults.textButtonColors(contentColor = ZoneHigh)
                    ) {
                        Text("Clear All")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { state = state.copy(showClearConfirmation = false) }) {
                        Text("Cancel")
                    }
                }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Analytics Content
// ─────────────────────────────────────

@Composable
private fun AnalyticsContent(
    state: HeartRateAnalyticsState,
    onRangeSelected: (TimeRange) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 120.dp)
    ) {
        // Time range selector
        item {
            TimeRangeSelector(
                selectedRange = state.selectedRange,
                onRangeSelected = onRangeSelected,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
            )
        }

        // Summary cards
        item {
            Spacer(Modifier.height(12.dp))
            SummaryCardsRow(
                averageBpm = state.averageBpm,
                minBpm = state.minBpm,
                maxBpm = state.maxBpm
            )
        }

        // Trend chart
        item {
            Spacer(Modifier.height(20.dp))
            HeartRateTrendChart(
                readings = state.filteredReadings,
                modifier = Modifier.padding(horizontal = 20.dp)
            )
        }

        // History header
        item {
            Spacer(Modifier.height(24.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "History",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    "${state.filteredReadings.size} readings",
                    style = MaterialTheme.typography.labelMedium,
                    color = AppColors.onSurfaceVariant
                )
            }
            Spacer(Modifier.height(8.dp))
        }

        // History list
        val reversed = state.filteredReadings.reversed() // newest first
        itemsIndexed(reversed) { index, reading ->
            HistoryRow(
                reading = reading,
                animationDelay = index * 50,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Time Range Selector Chips
// ─────────────────────────────────────

@Composable
private fun TimeRangeSelector(
    selectedRange: TimeRange,
    onRangeSelected: (TimeRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        TimeRange.entries.forEach { range ->
            val isSelected = range == selectedRange
            val chipModifier = if (isSelected) {
                Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(HeartRateColor)
                    .clickable { onRangeSelected(range) }
            } else {
                Modifier
                    .weight(1f)
                    .height(40.dp)
                    .glass(cornerRadius = 12.dp)
                    .clickable { onRangeSelected(range) }
            }
            Box(
                modifier = chipModifier,
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = range.label,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    color = if (isSelected) Color.White
                    else AppColors.onSurface
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Summary Cards Row
// ─────────────────────────────────────

@Composable
private fun SummaryCardsRow(
    averageBpm: Int,
    minBpm: Int,
    maxBpm: Int
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SummaryCard(
            label = "Average",
            value = if (averageBpm > 0) "$averageBpm" else "--",
            unit = "BPM",
            color = HeartRateColor,
            icon = Icons.Default.FavoriteBorder,
            animationDelay = 100,
            modifier = Modifier.weight(1f)
        )
        SummaryCard(
            label = "Min",
            value = if (minBpm > 0) "$minBpm" else "--",
            unit = "BPM",
            color = ZoneLow,
            icon = Icons.Default.ArrowDownward,
            animationDelay = 200,
            modifier = Modifier.weight(1f)
        )
        SummaryCard(
            label = "Max",
            value = if (maxBpm > 0) "$maxBpm" else "--",
            unit = "BPM",
            color = ZoneHigh,
            icon = Icons.Default.ArrowUpward,
            animationDelay = 300,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun SummaryCard(
    label: String,
    value: String,
    unit: String,
    color: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    animationDelay: Int,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(animationDelay.toLong())
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "cardAlpha"
    )

    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.9f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "cardScale"
    )

    Column(
        modifier = modifier
            .graphicsLayer {
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
            }
            .glass(cornerRadius = 16.dp)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            if (value != "--") {
                Text(
                    text = " $unit",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Trend Chart (Canvas-drawn)
// ─────────────────────────────────────

@Composable
private fun HeartRateTrendChart(
    readings: List<HeartRateReading>,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(400)
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(800, easing = FastOutSlowInEasing),
        label = "chartAlpha"
    )

    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(1200, easing = FastOutSlowInEasing),
        label = "chartProgress"
    )

    val isDark = isSystemInDarkTheme()
    val textColor = if (isDark) Color.White.copy(alpha = 0.6f) else Color.Black.copy(alpha = 0.5f)
    val gridColor = if (isDark) Color.White.copy(alpha = 0.08f) else Color.Black.copy(alpha = 0.06f)

    Column(
        modifier = modifier
            .graphicsLayer { alpha = animatedAlpha }
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            "Heart Rate Trend",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        Spacer(Modifier.height(16.dp))

        if (readings.size < 2) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Not enough data to show trend.\nTake at least 2 measurements.",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        } else {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
            ) {
                val chartWidth = size.width
                val chartHeight = size.height
                val paddingLeft = 40.dp.toPx()
                val paddingBottom = 28.dp.toPx()
                val paddingTop = 8.dp.toPx()
                val plotWidth = chartWidth - paddingLeft
                val plotHeight = chartHeight - paddingBottom - paddingTop

                val bpmValues = readings.map { it.bpm }
                val minVal = (bpmValues.min() - 10).coerceAtLeast(40)
                val maxVal = (bpmValues.max() + 10).coerceAtMost(200)
                val bpmRange = (maxVal - minVal).toFloat().coerceAtLeast(1f)

                // Dotted horizontal lines for zone boundaries
                val zoneBoundaries = listOf(60, 100, 120)
                val dashedEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f), 0f)

                zoneBoundaries.forEach { boundary ->
                    if (boundary in minVal..maxVal) {
                        val y = paddingTop + plotHeight * (1f - (boundary - minVal).toFloat() / bpmRange)
                        val zoneColor = when (boundary) {
                            60 -> ZoneLow
                            100 -> ZoneElevated
                            120 -> ZoneHigh
                            else -> gridColor
                        }
                        drawLine(
                            color = zoneColor.copy(alpha = 0.4f),
                            start = Offset(paddingLeft, y),
                            end = Offset(chartWidth, y),
                            strokeWidth = 1.5f,
                            pathEffect = dashedEffect
                        )
                    }
                }

                // Y-axis labels
                val yLabels = listOf(minVal, 60, 80, 100, 120, maxVal).distinct().filter { it in minVal..maxVal }.sorted()
                yLabels.forEach { label ->
                    val y = paddingTop + plotHeight * (1f - (label - minVal).toFloat() / bpmRange)
                    drawContext.canvas.nativeCanvas.drawText(
                        "$label",
                        4.dp.toPx(),
                        y + 4.dp.toPx(),
                        android.graphics.Paint().apply {
                            color = textColor.toArgb()
                            textSize = 10.sp.toPx()
                            isAntiAlias = true
                        }
                    )
                }

                // Color-coded zone fills (semi-transparent background)
                val zones = listOf(
                    Triple(40, 60, ZoneLow),
                    Triple(60, 100, ZoneNormal),
                    Triple(100, 120, ZoneElevated),
                    Triple(120, 200, ZoneHigh)
                )
                zones.forEach { (low, high, color) ->
                    val clampedLow = low.coerceIn(minVal, maxVal)
                    val clampedHigh = high.coerceIn(minVal, maxVal)
                    if (clampedLow < clampedHigh) {
                        val yTop = paddingTop + plotHeight * (1f - (clampedHigh - minVal).toFloat() / bpmRange)
                        val yBottom = paddingTop + plotHeight * (1f - (clampedLow - minVal).toFloat() / bpmRange)
                        drawRect(
                            color = color.copy(alpha = 0.06f),
                            topLeft = Offset(paddingLeft, yTop),
                            size = Size(plotWidth, yBottom - yTop)
                        )
                    }
                }

                // Line chart
                val pointCount = readings.size
                val visiblePoints = (pointCount * animatedProgress).toInt().coerceAtLeast(1)

                if (visiblePoints >= 2) {
                    val path = Path()
                    val gradientPath = Path()

                    for (i in 0 until visiblePoints) {
                        val x = paddingLeft + (i.toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                        val bpm = readings[i].bpm
                        val y = paddingTop + plotHeight * (1f - (bpm - minVal).toFloat() / bpmRange)

                        if (i == 0) {
                            path.moveTo(x, y)
                            gradientPath.moveTo(x, y)
                        } else {
                            // Smooth curve using cubic bezier
                            val prevX = paddingLeft + ((i - 1).toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                            val prevBpm = readings[i - 1].bpm
                            val prevY = paddingTop + plotHeight * (1f - (prevBpm - minVal).toFloat() / bpmRange)
                            val midX = (prevX + x) / 2f
                            path.cubicTo(midX, prevY, midX, y, x, y)
                            gradientPath.cubicTo(midX, prevY, midX, y, x, y)
                        }
                    }

                    // Gradient fill under line
                    val lastX = paddingLeft + ((visiblePoints - 1).toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                    val firstX = paddingLeft
                    gradientPath.lineTo(lastX, paddingTop + plotHeight)
                    gradientPath.lineTo(firstX, paddingTop + plotHeight)
                    gradientPath.close()

                    drawPath(
                        path = gradientPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                HeartRateColor.copy(alpha = 0.25f),
                                HeartRateColor.copy(alpha = 0.02f)
                            ),
                            startY = paddingTop,
                            endY = paddingTop + plotHeight
                        )
                    )

                    // Main line
                    drawPath(
                        path = path,
                        color = HeartRateColor,
                        style = Stroke(width = 2.5f, cap = StrokeCap.Round)
                    )
                }

                // Data points
                for (i in 0 until visiblePoints) {
                    val x = paddingLeft + (i.toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                    val bpm = readings[i].bpm
                    val y = paddingTop + plotHeight * (1f - (bpm - minVal).toFloat() / bpmRange)
                    val pointColor = when {
                        bpm < 60 -> ZoneLow
                        bpm <= 100 -> ZoneNormal
                        bpm <= 120 -> ZoneElevated
                        else -> ZoneHigh
                    }
                    drawCircle(
                        color = pointColor,
                        radius = 4.dp.toPx(),
                        center = Offset(x, y)
                    )
                    drawCircle(
                        color = Color.White,
                        radius = 2.dp.toPx(),
                        center = Offset(x, y)
                    )
                }

                // X-axis time labels (show a few evenly spaced)
                val labelCount = 5.coerceAtMost(pointCount)
                val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")
                val dateFormatter = DateTimeFormatter.ofPattern("MM/dd")
                for (i in 0 until labelCount) {
                    val readingIndex = if (labelCount == 1) 0
                    else (i * (pointCount - 1)) / (labelCount - 1)
                    val reading = readings[readingIndex]
                    val x = paddingLeft + (readingIndex.toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                    val labelText = try {
                        val dt = LocalDateTime.parse(reading.timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                        if (pointCount > 10) dt.format(dateFormatter) else dt.format(timeFormatter)
                    } catch (_: Exception) {
                        ""
                    }
                    drawContext.canvas.nativeCanvas.drawText(
                        labelText,
                        x - 14.dp.toPx(),
                        chartHeight - 4.dp.toPx(),
                        android.graphics.Paint().apply {
                            color = textColor.toArgb()
                            textSize = 9.sp.toPx()
                            isAntiAlias = true
                        }
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - History Row
// ─────────────────────────────────────

@Composable
private fun HistoryRow(
    reading: HeartRateReading,
    animationDelay: Int,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(animationDelay.toLong().coerceAtMost(500))
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "rowAlpha"
    )

    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 15f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 400f),
        label = "rowOffset"
    )

    val zone = getHeartRateZone(reading.bpm)

    // Parse timestamp
    val formattedDate = remember(reading.timestamp) {
        try {
            val dt = LocalDateTime.parse(reading.timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            val dateStr = dt.format(DateTimeFormatter.ofPattern("MMM dd, yyyy"))
            val timeStr = dt.format(DateTimeFormatter.ofPattern("hh:mm a"))
            Pair(dateStr, timeStr)
        } catch (_: Exception) {
            Pair("Unknown", "")
        }
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = animatedAlpha
                translationY = animatedOffset
            }
            .glass(cornerRadius = 14.dp)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Zone color dot
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(zone.color, CircleShape)
        )

        // Date/Time
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = formattedDate.first,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
            Text(
                text = formattedDate.second,
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }

        // Source badge
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(AppColors.surfaceVariant.copy(alpha = 0.5f))
                .padding(horizontal = 8.dp, vertical = 4.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (reading.source == "Camera") Icons.Default.CameraAlt
                    else Icons.Default.Favorite,
                    contentDescription = null,
                    tint = AppColors.onSurfaceVariant,
                    modifier = Modifier.size(10.dp)
                )
                Text(
                    text = reading.source,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        // BPM value
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = "${reading.bpm}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = zone.color
            )
            Text(
                text = " BPM",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 2.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skeleton / Loading
// ─────────────────────────────────────

@Composable
private fun AnalyticsSkeletonContent() {
    val infiniteTransition = rememberInfiniteTransition(label = "shimmer")
    val shimmerAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "shimmerAlpha"
    )

    val shimmerColor = AppColors.onSurface.copy(alpha = shimmerAlpha * 0.1f)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(16.dp))

        // Range selector skeleton
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(40.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(shimmerColor)
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // Summary cards skeleton
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(100.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(shimmerColor)
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // Chart skeleton
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(240.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(shimmerColor)
        )

        Spacer(Modifier.height(20.dp))

        // History rows skeleton
        repeat(5) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp)
                    .padding(vertical = 4.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(shimmerColor)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────

@Composable
private fun EmptyAnalyticsContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(HeartRateColor.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.BarChart,
                contentDescription = null,
                tint = HeartRateColor,
                modifier = Modifier.size(40.dp)
            )
        }

        Spacer(Modifier.height(24.dp))

        Text(
            "No Readings Yet",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )

        Spacer(Modifier.height(8.dp))

        Text(
            "Take your first heart rate measurement to start\ntracking your cardiovascular health over time.",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}
