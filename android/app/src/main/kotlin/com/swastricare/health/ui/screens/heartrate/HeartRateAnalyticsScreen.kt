package com.swastricare.health.ui.screens.heartrate

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.domain.model.heartrate.MeasurementSource
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.HeartRateColor
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.delay
import java.time.format.DateTimeFormatter

// Zone colors (same as HeartRateScreen)
private val ZoneNormal = Color(0xFF4CAF50)
private val ZoneElevated = Color(0xFFFFC107)
private val ZoneHigh = Color(0xFFF44336)
private val ZoneLow = Color(0xFF2196F3)

// Source badge colors
private val CloudColor = Color(0xFF7C3AED)
private val DeviceColor = Color(0xFF0EA5E9)

// ─────────────────────────────────────
// MARK: - HeartRateAnalyticsScreen
// ─────────────────────────────────────

@Composable
fun HeartRateAnalyticsScreen(
    onNavigateBack: () -> Unit = {}
) {
    TrackScreen("HeartRateAnalytics")
    val viewModel: HeartRateAnalyticsViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()

    val filteredReadings = remember(uiState) { viewModel.getFilteredReadings() }
    val summary = remember(uiState) { viewModel.getSummary() }
    val dailyAggregates = remember(uiState) { viewModel.getDailyAggregates() }
    val groupedHistory = remember(uiState) { viewModel.getGroupedHistory() }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize()
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
                // Refresh button
                if (uiState.allReadings.isNotEmpty()) {
                    IconButton(
                        onClick = { viewModel.refresh() },
                        enabled = !uiState.isRefreshing
                    ) {
                        if (uiState.isRefreshing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp,
                                color = AppColors.onSurfaceVariant
                            )
                        } else {
                            Icon(
                                Icons.Default.Refresh, "Refresh",
                                tint = AppColors.onSurfaceVariant
                            )
                        }
                    }
                }
                if (uiState.allReadings.isNotEmpty()) {
                    IconButton(onClick = { viewModel.showClearConfirmation() }) {
                        Icon(
                            Icons.Default.DeleteOutline, "Clear History",
                            tint = AppColors.onSurfaceVariant
                        )
                    }
                }
            }

            when {
                uiState.isLoading -> AnalyticsSkeletonContent()
                uiState.allReadings.isEmpty() -> EmptyAnalyticsContent()
                else -> AnalyticsContent(
                    uiState = uiState,
                    filteredReadings = filteredReadings,
                    summary = summary,
                    dailyAggregates = dailyAggregates,
                    groupedHistory = groupedHistory,
                    onRangeSelected = { viewModel.setTimeRange(it) },
                    onSourceSelected = { viewModel.setSourceFilter(it) }
                )
            }
        }

        // Clear confirmation dialog
        if (uiState.showClearConfirmation) {
            AlertDialog(
                onDismissRequest = { viewModel.dismissClearConfirmation() },
                icon = {
                    Icon(
                        Icons.Default.Warning,
                        contentDescription = null,
                        tint = ZoneHigh
                    )
                },
                title = { Text("Clear History?") },
                text = {
                    Text("This will permanently delete all your heart rate readings. This action cannot be undone.")
                },
                confirmButton = {
                    TextButton(
                        onClick = { viewModel.clearHistory() },
                        colors = ButtonDefaults.textButtonColors(contentColor = ZoneHigh)
                    ) {
                        Text("Clear All")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { viewModel.dismissClearConfirmation() }) {
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
    uiState: HeartRateAnalyticsUiState,
    filteredReadings: List<AnalyticsReading>,
    summary: AnalyticsSummary,
    dailyAggregates: List<DailyAggregate>,
    groupedHistory: List<DayGroup>,
    onRangeSelected: (AnalyticsTimeRange) -> Unit,
    onSourceSelected: (SourceFilter) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 120.dp)
    ) {
        // Time range selector
        item {
            TimeRangeSelector(
                selectedRange = uiState.selectedRange,
                onRangeSelected = onRangeSelected,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }

        // Source filter selector
        item {
            SourceFilterSelector(
                selectedSource = uiState.selectedSource,
                cloudAvailable = uiState.cloudAvailable,
                onSourceSelected = onSourceSelected,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Summary cards (2x2 grid)
        item {
            Spacer(Modifier.height(12.dp))
            SummaryCardsGrid(summary = summary)
        }

        // Trend chart
        item {
            Spacer(Modifier.height(20.dp))
            DailyAverageTrendChart(
                dailyAggregates = dailyAggregates,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // History header
        item {
            Spacer(Modifier.height(24.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "History",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    "${filteredReadings.size} readings",
                    style = MaterialTheme.typography.labelMedium,
                    color = AppColors.onSurfaceVariant
                )
            }
            Spacer(Modifier.height(8.dp))
        }

        // Day-grouped history
        if (groupedHistory.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "No readings in this time range",
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
        } else {
            groupedHistory.forEach { group ->
                // Day header
                item(key = "header_${group.date}") {
                    DayGroupHeader(
                        label = group.label,
                        count = group.readings.size,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
                    )
                }
                // Readings in that day
                items(
                    items = group.readings,
                    key = { "${it.timestamp}_${it.bpm}_${it.source}" }
                ) { reading ->
                    HistoryRow(
                        reading = reading,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Time Range Selector
// ─────────────────────────────────────

@Composable
private fun TimeRangeSelector(
    selectedRange: AnalyticsTimeRange,
    onRangeSelected: (AnalyticsTimeRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        AnalyticsTimeRange.entries.forEach { range ->
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
                    color = if (isSelected) Color.White else AppColors.onSurface
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Source Filter Selector
// ─────────────────────────────────────

@Composable
private fun SourceFilterSelector(
    selectedSource: SourceFilter,
    cloudAvailable: Boolean,
    onSourceSelected: (SourceFilter) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        SourceFilter.entries.forEach { filter ->
            val isSelected = filter == selectedSource
            val isCloudDisabled = filter == SourceFilter.CLOUD && !cloudAvailable

            val chipColor = if (isSelected) HeartRateColor.copy(alpha = 0.15f)
            else Color.Transparent
            val borderColor = if (isSelected) HeartRateColor
            else AppColors.onSurfaceVariant.copy(alpha = 0.3f)
            val textColor = when {
                isCloudDisabled -> AppColors.onSurfaceVariant.copy(alpha = 0.4f)
                isSelected -> HeartRateColor
                else -> AppColors.onSurfaceVariant
            }

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(chipColor)
                    .then(
                        if (!isCloudDisabled) Modifier.clickable { onSourceSelected(filter) }
                        else Modifier
                    )
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = filter.label,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = textColor
                    )
                    if (isCloudDisabled) {
                        Icon(
                            Icons.Default.CloudOff,
                            contentDescription = "Cloud unavailable",
                            tint = AppColors.onSurfaceVariant.copy(alpha = 0.4f),
                            modifier = Modifier.size(12.dp)
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Summary Cards Grid (2x2)
// ─────────────────────────────────────

@Composable
private fun SummaryCardsGrid(summary: AnalyticsSummary) {
    val latestBpmText = summary.latest?.let { "${it.bpm}" } ?: "--"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Top row: Average + Latest
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SummaryCard(
                label = "Average",
                value = if (summary.average > 0) "${summary.average}" else "--",
                unit = "BPM",
                color = HeartRateColor,
                icon = Icons.Default.FavoriteBorder,
                animationDelay = 100,
                modifier = Modifier.weight(1f)
            )
            SummaryCard(
                label = "Latest",
                value = latestBpmText,
                unit = "BPM",
                color = Color(0xFFF59E0B),
                icon = Icons.Default.Schedule,
                animationDelay = 200,
                modifier = Modifier.weight(1f)
            )
        }
        // Bottom row: Min + Max
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SummaryCard(
                label = "Min",
                value = if (summary.min > 0) "${summary.min}" else "--",
                unit = "BPM",
                color = ZoneLow,
                icon = Icons.Default.ArrowDownward,
                animationDelay = 300,
                modifier = Modifier.weight(1f)
            )
            SummaryCard(
                label = "Max",
                value = if (summary.max > 0) "${summary.max}" else "--",
                unit = "BPM",
                color = ZoneHigh,
                icon = Icons.Default.ArrowUpward,
                animationDelay = 400,
                modifier = Modifier.weight(1f)
            )
        }
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

    Row(
        modifier = modifier
            .graphicsLayer {
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
            }
            .glass(cornerRadius = 16.dp)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(18.dp))
        }
        Column {
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
}

// ─────────────────────────────────────
// MARK: - Daily Average Trend Chart
// ─────────────────────────────────────

@Composable
private fun DailyAverageTrendChart(
    dailyAggregates: List<DailyAggregate>,
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

    Column(
        modifier = modifier
            .graphicsLayer { alpha = animatedAlpha }
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Daily Average Trend",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                "${dailyAggregates.size} days",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }

        Spacer(Modifier.height(16.dp))

        if (dailyAggregates.size < 2) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Not enough data to show trend.\nTake measurements on at least 2 days.",
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

                val bpmValues = dailyAggregates.map { it.avgBpm }
                val minVal = (bpmValues.min() - 10).coerceAtLeast(40)
                val maxVal = (bpmValues.max() + 10).coerceAtMost(200)
                val bpmRange = (maxVal - minVal).toFloat().coerceAtLeast(1f)

                // Zone boundary lines
                val zoneBoundaries = listOf(60, 100, 120)
                val dashedEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f), 0f)

                zoneBoundaries.forEach { boundary ->
                    if (boundary in minVal..maxVal) {
                        val y = paddingTop + plotHeight * (1f - (boundary - minVal).toFloat() / bpmRange)
                        val zoneColor = when (boundary) {
                            60 -> ZoneLow
                            100 -> ZoneElevated
                            120 -> ZoneHigh
                            else -> Color.Gray
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
                val yLabels = listOf(minVal, 60, 80, 100, 120, maxVal)
                    .distinct()
                    .filter { it in minVal..maxVal }
                    .sorted()
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

                // Zone fills
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

                // Line chart with daily aggregates
                val pointCount = dailyAggregates.size
                val visiblePoints = (pointCount * animatedProgress).toInt().coerceAtLeast(1)

                if (visiblePoints >= 2) {
                    val path = Path()
                    val gradientPath = Path()

                    for (i in 0 until visiblePoints) {
                        val x = paddingLeft + (i.toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                        val bpm = dailyAggregates[i].avgBpm
                        val y = paddingTop + plotHeight * (1f - (bpm - minVal).toFloat() / bpmRange)

                        if (i == 0) {
                            path.moveTo(x, y)
                            gradientPath.moveTo(x, y)
                        } else {
                            val prevX = paddingLeft + ((i - 1).toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                            val prevBpm = dailyAggregates[i - 1].avgBpm
                            val prevY = paddingTop + plotHeight * (1f - (prevBpm - minVal).toFloat() / bpmRange)
                            val midX = (prevX + x) / 2f
                            path.cubicTo(midX, prevY, midX, y, x, y)
                            gradientPath.cubicTo(midX, prevY, midX, y, x, y)
                        }
                    }

                    // Gradient fill
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
                    val bpm = dailyAggregates[i].avgBpm
                    val y = paddingTop + plotHeight * (1f - (bpm - minVal).toFloat() / bpmRange)
                    val pointColor = when {
                        bpm < 60 -> ZoneLow
                        bpm <= 100 -> ZoneNormal
                        bpm <= 120 -> ZoneElevated
                        else -> ZoneHigh
                    }
                    drawCircle(color = pointColor, radius = 4.dp.toPx(), center = Offset(x, y))
                    drawCircle(color = Color.White, radius = 2.dp.toPx(), center = Offset(x, y))
                }

                // X-axis date labels
                val labelCount = 5.coerceAtMost(pointCount)
                val dateFormatter = DateTimeFormatter.ofPattern("MMM d")
                for (i in 0 until labelCount) {
                    val dataIndex = if (labelCount == 1) 0
                    else (i * (pointCount - 1)) / (labelCount - 1)
                    val aggregate = dailyAggregates[dataIndex]
                    val x = paddingLeft + (dataIndex.toFloat() / (pointCount - 1).coerceAtLeast(1)) * plotWidth
                    val labelText = aggregate.date.format(dateFormatter)
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
// MARK: - Day Group Header
// ─────────────────────────────────────

@Composable
private fun DayGroupHeader(
    label: String,
    count: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Text(
            text = "$count reading${if (count != 1) "s" else ""}",
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - History Row
// ─────────────────────────────────────

@Composable
private fun HistoryRow(
    reading: AnalyticsReading,
    modifier: Modifier = Modifier
) {
    val zone = getHeartRateZone(reading.bpm)
    val timeFormatter = DateTimeFormatter.ofPattern("hh:mm a")
    val formattedTime = reading.timestamp.format(timeFormatter)
    val confidencePercent = (reading.confidence * 100).toInt()

    Row(
        modifier = modifier
            .fillMaxWidth()
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

        // Time + confidence
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = formattedTime,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
            Text(
                text = "${confidencePercent}% confidence",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }

        // Source badge
        val (sourceBadgeColor, sourceBadgeText, sourceBadgeIcon) = when (reading.source) {
            ReadingSource.CLOUD -> Triple(
                CloudColor,
                "Cloud",
                Icons.Default.Cloud
            )
            ReadingSource.LOCAL -> Triple(
                DeviceColor,
                reading.measurementSource.displayName,
                if (reading.measurementSource == MeasurementSource.CAMERA) Icons.Default.CameraAlt
                else Icons.Default.Favorite
            )
        }

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(sourceBadgeColor.copy(alpha = 0.1f))
                .padding(horizontal = 8.dp, vertical = 4.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = sourceBadgeIcon,
                    contentDescription = null,
                    tint = sourceBadgeColor,
                    modifier = Modifier.size(10.dp)
                )
                Text(
                    text = sourceBadgeText,
                    style = MaterialTheme.typography.labelSmall,
                    color = sourceBadgeColor
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
            .padding(horizontal = 16.dp)
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

        Spacer(Modifier.height(12.dp))

        // Source filter skeleton
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .width(80.dp)
                        .height(32.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(shimmerColor)
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // Summary cards skeleton (2x2)
        repeat(2) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                repeat(2) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(80.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(shimmerColor)
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        Spacer(Modifier.height(8.dp))

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
