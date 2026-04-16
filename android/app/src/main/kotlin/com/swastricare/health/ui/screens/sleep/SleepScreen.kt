package com.swastricare.health.ui.screens.sleep

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.model.sleep.SleepStageType
import com.swastricare.health.domain.model.sleep.SleepStats
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SleepColor
import kotlinx.coroutines.delay
import java.time.format.DateTimeFormatter

// Stage colors
private val DeepColor = Color(0xFF1E3A5F)
private val LightColor = Color(0xFF5B8FB9)
private val RemColor = Color(0xFF7C3AED)
private val AwakeColor = Color(0xFFEF4444)

@Composable
fun SleepScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToLog: () -> Unit = {},
    viewModel: SleepViewModel = hiltViewModel()
) {
    TrackScreen("Sleep")
    val uiState by viewModel.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            SleepTopBar(onNavigateBack = onNavigateBack)

            when {
                uiState.isLoading -> SleepSkeletonContent()
                uiState.todaySession == null && uiState.sleepHistory.isEmpty() ->
                    EmptySleepContent(onLogSleep = onNavigateToLog)
                else -> SleepContent(
                    uiState = uiState,
                    onRangeSelected = { viewModel.selectTimeRange(it) }
                )
            }
        }

        // FAB — only when today has no Health Connect data
        if (!uiState.isLoading && uiState.todaySession == null) {
            FloatingActionButton(
                onClick = onNavigateToLog,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(bottom = 24.dp, end = 16.dp),
                containerColor = SleepColor,
                contentColor = Color.White
            ) {
                Icon(Icons.Default.Bedtime, contentDescription = "Log Sleep")
            }
        }
    }
}

@Composable
private fun SleepTopBar(onNavigateBack: () -> Unit) {
    AppTopBar(title = "Sleep", onBack = onNavigateBack)
}

@Composable
private fun SleepContent(
    uiState: SleepUiState,
    onRangeSelected: (SleepTimeRange) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        // Today's summary
        uiState.todaySession?.let { session ->
            item {
                TodaySummaryCard(
                    session = session,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }

            // Sleep stages breakdown
            if (session.hasStageData) {
                item {
                    Spacer(Modifier.height(12.dp))
                    SleepStagesCard(
                        session = session,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }
            }
        }

        // Time range selector
        item {
            Spacer(Modifier.height(16.dp))
            TimeRangeSelector(
                selectedRange = uiState.selectedRange,
                onRangeSelected = onRangeSelected,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Trend chart
        if (uiState.filteredHistory.size >= 2) {
            item {
                Spacer(Modifier.height(16.dp))
                SleepTrendCard(
                    sessions = uiState.filteredHistory,
                    selectedRange = uiState.selectedRange,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }

        // Stats row
        item {
            Spacer(Modifier.height(16.dp))
            SleepStatsRow(
                stats = uiState.stats,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // History header
        if (uiState.filteredHistory.isNotEmpty()) {
            item {
                Spacer(Modifier.height(20.dp))
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
                        "${uiState.filteredHistory.size} nights",
                        style = MaterialTheme.typography.labelMedium,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Spacer(Modifier.height(8.dp))
            }

            // History list
            val reversed = uiState.filteredHistory.sortedByDescending { it.date }
            itemsIndexed(reversed) { index, session ->
                SleepHistoryRow(
                    session = session,
                    animationDelay = index * 50,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Today Summary Card
// ─────────────────────────────────────

@Composable
private fun TodaySummaryCard(
    session: SleepSession,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(100)
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "todayAlpha"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer { alpha = animatedAlpha }
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF1A263D),
                        Color(0xFF0D0D1A)
                    )
                )
            )
            .padding(20.dp)
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column {
                    Text(
                        "Last Night",
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        session.totalFormatted,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                // Quality badge
                QualityBadge(
                    label = session.qualityLabel,
                    score = session.qualityScore
                )
            }

            Spacer(Modifier.height(16.dp))

            // Bedtime / Wake time row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                session.bedtime?.let { bedtime ->
                    TimeChip(
                        icon = Icons.Default.Bedtime,
                        label = "Bedtime",
                        time = bedtime.format(DateTimeFormatter.ofPattern("hh:mm a"))
                    )
                }
                session.wakeTime?.let { wakeTime ->
                    TimeChip(
                        icon = Icons.Default.WbSunny,
                        label = "Wake up",
                        time = wakeTime.format(DateTimeFormatter.ofPattern("hh:mm a"))
                    )
                }
            }
        }
    }
}

@Composable
private fun QualityBadge(label: String, score: Int) {
    val bgColor = when {
        score >= 80 -> Color(0xFF22C55E).copy(alpha = 0.2f)
        score >= 60 -> Color(0xFF3B82F6).copy(alpha = 0.2f)
        score >= 40 -> Color(0xFFF59E0B).copy(alpha = 0.2f)
        else -> Color(0xFFEF4444).copy(alpha = 0.2f)
    }
    val textColor = when {
        score >= 80 -> Color(0xFF22C55E)
        score >= 60 -> Color(0xFF3B82F6)
        score >= 40 -> Color(0xFFF59E0B)
        else -> Color(0xFFEF4444)
    }

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(
            "$label $score%",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = textColor
        )
    }
}

@Composable
private fun TimeChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    time: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            icon, null,
            tint = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.size(16.dp)
        )
        Column {
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.5f)
            )
            Text(
                time,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Sleep Stages Card
// ─────────────────────────────────────

@Composable
private fun SleepStagesCard(
    session: SleepSession,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            "Sleep Stages",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        Spacer(Modifier.height(16.dp))

        // Stacked bar
        SleepStagesBar(session = session)

        Spacer(Modifier.height(16.dp))

        // Stage pills
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StagePill("Deep", session.deepMinutes, DeepColor)
            StagePill("Light", session.lightMinutes, LightColor)
            StagePill("REM", session.remMinutes, RemColor)
            StagePill("Awake", session.awakeMinutes, AwakeColor)
        }
    }
}

@Composable
private fun SleepStagesBar(session: SleepSession) {
    val total = (session.deepMinutes + session.lightMinutes + session.remMinutes + session.awakeMinutes)
        .coerceAtLeast(1)

    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(200)
        isVisible = true
    }

    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "stagesProgress"
    )

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(28.dp)
    ) {
        val barWidth = size.width * animatedProgress
        val barHeight = size.height
        val cornerRadius = 8.dp.toPx()

        // Draw rounded background
        drawRoundRect(
            color = Color.White.copy(alpha = 0.05f),
            cornerRadius = CornerRadius(cornerRadius, cornerRadius),
            size = Size(size.width, barHeight)
        )

        if (barWidth <= 0f) return@Canvas

        val deepFrac = session.deepMinutes.toFloat() / total
        val lightFrac = session.lightMinutes.toFloat() / total
        val remFrac = session.remMinutes.toFloat() / total
        val awakeFrac = session.awakeMinutes.toFloat() / total

        val segments = listOf(
            deepFrac to DeepColor,
            lightFrac to LightColor,
            remFrac to RemColor,
            awakeFrac to AwakeColor
        ).filter { it.first > 0f }

        var x = 0f
        segments.forEachIndexed { index, (frac, color) ->
            val segWidth = frac * barWidth
            if (segWidth > 0f) {
                // Use rounded rect for first and last, regular rect for middle
                if (index == 0 && segments.size == 1) {
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(x, 0f),
                        size = Size(segWidth, barHeight),
                        cornerRadius = CornerRadius(cornerRadius, cornerRadius)
                    )
                } else if (index == 0) {
                    // First segment: round left corners
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(x, 0f),
                        size = Size(segWidth + cornerRadius, barHeight),
                        cornerRadius = CornerRadius(cornerRadius, cornerRadius)
                    )
                    // Cover the right rounding with a rect
                    if (segWidth > cornerRadius) {
                        drawRect(
                            color = color,
                            topLeft = Offset(x + segWidth - 1f, 0f),
                            size = Size(cornerRadius + 1f, barHeight)
                        )
                    }
                } else if (index == segments.size - 1) {
                    // Last segment: round right corners
                    drawRect(
                        color = color,
                        topLeft = Offset(x, 0f),
                        size = Size(cornerRadius, barHeight)
                    )
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(x, 0f),
                        size = Size(segWidth, barHeight),
                        cornerRadius = CornerRadius(cornerRadius, cornerRadius)
                    )
                } else {
                    drawRect(
                        color = color,
                        topLeft = Offset(x, 0f),
                        size = Size(segWidth, barHeight)
                    )
                }
                x += segWidth
            }
        }
    }
}

@Composable
private fun StagePill(label: String, minutes: Int, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(Modifier.height(4.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
        Text(
            formatMinutes(minutes),
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
    }
}

// ─────────────────────────────────────
// MARK: - Time Range Selector
// ─────────────────────────────────────

@Composable
private fun TimeRangeSelector(
    selectedRange: SleepTimeRange,
    onRangeSelected: (SleepTimeRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        SleepTimeRange.entries.forEach { range ->
            val isSelected = range == selectedRange
            val chipModifier = if (isSelected) {
                Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(SleepColor)
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
// MARK: - Sleep Trend Chart
// ─────────────────────────────────────

@Composable
private fun SleepTrendCard(
    sessions: List<SleepSession>,
    selectedRange: SleepTimeRange,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(300)
        isVisible = true
    }

    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "chartProgress"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            "Sleep Trend",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        Spacer(Modifier.height(16.dp))

        when (selectedRange) {
            SleepTimeRange.WEEK -> WeeklyStackedBarChart(
                sessions = sessions,
                animatedProgress = animatedProgress
            )
            SleepTimeRange.MONTH -> MonthlyLineChart(
                sessions = sessions,
                animatedProgress = animatedProgress
            )
        }
    }
}

@Composable
private fun WeeklyStackedBarChart(
    sessions: List<SleepSession>,
    animatedProgress: Float
) {
    val dayFormatter = DateTimeFormatter.ofPattern("EEE")
    val textColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp)
    ) {
        val chartWidth = size.width
        val chartHeight = size.height
        val paddingBottom = 24.dp.toPx()
        val paddingTop = 8.dp.toPx()
        val plotHeight = chartHeight - paddingBottom - paddingTop

        val sorted = sessions.sortedBy { it.date }.takeLast(7)
        if (sorted.isEmpty()) return@Canvas

        val maxMinutes = sorted.maxOf { it.totalMinutes }.coerceAtLeast(480).toFloat()
        val barCount = sorted.size
        val totalGap = 8.dp.toPx() * (barCount - 1)
        val barWidth = ((chartWidth - totalGap) / barCount).coerceAtMost(40.dp.toPx())
        val actualTotalWidth = barWidth * barCount + 8.dp.toPx() * (barCount - 1)
        val startX = (chartWidth - actualTotalWidth) / 2

        // 8h goal line
        val goalY = paddingTop + plotHeight * (1f - 480f / maxMinutes)
        drawLine(
            color = Color(0xFF22C55E).copy(alpha = 0.3f),
            start = Offset(0f, goalY),
            end = Offset(chartWidth, goalY),
            strokeWidth = 1f,
            pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                floatArrayOf(8f, 8f), 0f
            )
        )

        sorted.forEachIndexed { index, session ->
            val x = startX + index * (barWidth + 8.dp.toPx())

            if (session.hasStageData) {
                // Stacked bar with stages
                val total = session.totalMinutes.toFloat()
                val barTotalHeight = (total / maxMinutes) * plotHeight * animatedProgress
                var currentY = paddingTop + plotHeight - barTotalHeight

                val stageSegments = listOf(
                    session.deepMinutes to DeepColor,
                    session.lightMinutes to LightColor,
                    session.remMinutes to RemColor,
                    session.awakeMinutes to AwakeColor
                ).filter { it.first > 0 }

                stageSegments.forEachIndexed { segIndex, (minutes, color) ->
                    val segHeight = (minutes / total) * barTotalHeight
                    val cornerRad = if (segIndex == 0) 4.dp.toPx() else 0f
                    if (segIndex == 0) {
                        drawRoundRect(
                            color = color,
                            topLeft = Offset(x, currentY),
                            size = Size(barWidth, segHeight),
                            cornerRadius = CornerRadius(cornerRad, cornerRad)
                        )
                    } else {
                        drawRect(
                            color = color,
                            topLeft = Offset(x, currentY),
                            size = Size(barWidth, segHeight)
                        )
                    }
                    currentY += segHeight
                }
            } else {
                // Single color bar
                val barH = (session.totalMinutes / maxMinutes) * plotHeight * animatedProgress
                val y = paddingTop + plotHeight - barH
                drawRoundRect(
                    color = SleepColor,
                    topLeft = Offset(x, y),
                    size = Size(barWidth, barH),
                    cornerRadius = CornerRadius(4.dp.toPx(), 4.dp.toPx())
                )
            }

            // Day label
            val dayLabel = session.date.format(dayFormatter)
            val paint = android.graphics.Paint().apply {
                this.color = textColor.toArgb()
                textSize = 10.sp.toPx()
                textAlign = android.graphics.Paint.Align.CENTER
            }
            drawContext.canvas.nativeCanvas.drawText(
                dayLabel,
                x + barWidth / 2,
                chartHeight - 4.dp.toPx(),
                paint
            )
        }
    }
}

@Composable
private fun MonthlyLineChart(
    sessions: List<SleepSession>,
    animatedProgress: Float
) {
    val textColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp)
    ) {
        val chartWidth = size.width
        val chartHeight = size.height
        val paddingBottom = 24.dp.toPx()
        val paddingTop = 8.dp.toPx()
        val paddingLeft = 32.dp.toPx()
        val plotWidth = chartWidth - paddingLeft
        val plotHeight = chartHeight - paddingBottom - paddingTop

        val sorted = sessions.sortedBy { it.date }
        if (sorted.size < 2) return@Canvas

        val hoursValues = sorted.map { it.totalMinutes / 60f }
        val minVal = (hoursValues.min() - 1f).coerceAtLeast(0f)
        val maxVal = (hoursValues.max() + 1f).coerceAtMost(14f)
        val range = (maxVal - minVal).coerceAtLeast(1f)

        // 8h goal line
        val goalY = paddingTop + plotHeight * (1f - (8f - minVal) / range)
        drawLine(
            color = Color(0xFF22C55E).copy(alpha = 0.3f),
            start = Offset(paddingLeft, goalY),
            end = Offset(chartWidth, goalY),
            strokeWidth = 1f,
            pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                floatArrayOf(8f, 8f), 0f
            )
        )

        // Y-axis labels
        val yLabels = listOf(minVal.toInt(), (minVal + range / 2).toInt(), maxVal.toInt()).distinct()
        val paint = android.graphics.Paint().apply {
            color = textColor.toArgb()
            textSize = 10.sp.toPx()
            textAlign = android.graphics.Paint.Align.RIGHT
        }
        yLabels.forEach { label ->
            val y = paddingTop + plotHeight * (1f - (label - minVal) / range)
            drawContext.canvas.nativeCanvas.drawText(
                "${label}h",
                paddingLeft - 6.dp.toPx(),
                y + 4.dp.toPx(),
                paint
            )
        }

        // Build line path with progress animation
        val visibleCount = (sorted.size * animatedProgress).toInt().coerceAtLeast(2)
        val visibleSorted = sorted.take(visibleCount)

        val path = Path()
        val fillPath = Path()

        visibleSorted.forEachIndexed { index, session ->
            val hours = session.totalMinutes / 60f
            val x = paddingLeft + (index.toFloat() / (sorted.size - 1)) * plotWidth
            val y = paddingTop + plotHeight * (1f - (hours - minVal) / range)

            if (index == 0) {
                path.moveTo(x, y)
                fillPath.moveTo(x, paddingTop + plotHeight)
                fillPath.lineTo(x, y)
            } else {
                // Bezier smoothing
                val prevSession = visibleSorted[index - 1]
                val prevX = paddingLeft + ((index - 1).toFloat() / (sorted.size - 1)) * plotWidth
                val prevHours = prevSession.totalMinutes / 60f
                val prevY = paddingTop + plotHeight * (1f - (prevHours - minVal) / range)
                val cpX = (prevX + x) / 2
                path.cubicTo(cpX, prevY, cpX, y, x, y)
                fillPath.cubicTo(cpX, prevY, cpX, y, x, y)
            }
        }

        // Fill under curve
        val lastX = paddingLeft + ((visibleCount - 1).toFloat() / (sorted.size - 1)) * plotWidth
        fillPath.lineTo(lastX, paddingTop + plotHeight)
        fillPath.close()

        drawPath(
            fillPath,
            brush = Brush.verticalGradient(
                colors = listOf(
                    SleepColor.copy(alpha = 0.3f),
                    SleepColor.copy(alpha = 0.0f)
                ),
                startY = paddingTop,
                endY = paddingTop + plotHeight
            )
        )

        drawPath(
            path,
            color = SleepColor,
            style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round)
        )

        // Data points
        visibleSorted.forEachIndexed { index, session ->
            val hours = session.totalMinutes / 60f
            val x = paddingLeft + (index.toFloat() / (sorted.size - 1)) * plotWidth
            val y = paddingTop + plotHeight * (1f - (hours - minVal) / range)
            drawCircle(color = SleepColor, radius = 3.dp.toPx(), center = Offset(x, y))
            drawCircle(color = Color.White, radius = 1.5.dp.toPx(), center = Offset(x, y))
        }
    }
}

// ─────────────────────────────────────
// MARK: - Sleep Stats Row
// ─────────────────────────────────────

@Composable
private fun SleepStatsRow(
    stats: SleepStats,
    modifier: Modifier = Modifier
) {
    val timeFormatter = DateTimeFormatter.ofPattern("hh:mm a")

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatCard(
                label = "Avg Sleep",
                value = stats.averageFormatted,
                icon = Icons.Default.Bedtime,
                color = SleepColor,
                animationDelay = 100,
                modifier = Modifier.weight(1f)
            )
            StatCard(
                label = "Best Night",
                value = stats.bestNightFormatted,
                icon = Icons.Default.Star,
                color = Color(0xFF22C55E),
                animationDelay = 200,
                modifier = Modifier.weight(1f)
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatCard(
                label = "Consistency",
                value = if (stats.consistencyScore > 0) "${stats.consistencyScore}%" else "--",
                icon = Icons.Default.TrendingUp,
                color = Color(0xFF3B82F6),
                animationDelay = 300,
                modifier = Modifier.weight(1f)
            )
            StatCard(
                label = "Avg Bedtime",
                value = stats.avgBedtime?.format(timeFormatter) ?: "--",
                icon = Icons.Default.NightsStay,
                color = Color(0xFF8B5CF6),
                animationDelay = 400,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
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
        label = "statAlpha"
    )

    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.9f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "statScale"
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
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - Sleep History Row
// ─────────────────────────────────────

@Composable
private fun SleepHistoryRow(
    session: SleepSession,
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
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "histAlpha"
    )

    val dateFormatter = DateTimeFormatter.ofPattern("EEE, MMM d")
    val timeFormatter = DateTimeFormatter.ofPattern("hh:mm a")

    Row(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer { alpha = animatedAlpha }
            .glass(cornerRadius = 14.dp)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Date column
        Column(modifier = Modifier.weight(1f)) {
            Text(
                session.date.format(dateFormatter),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                session.bedtime?.let {
                    Text(
                        it.format(timeFormatter),
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                session.wakeTime?.let {
                    Text(
                        "- ${it.format(timeFormatter)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
        }

        // Mini stage bar
        if (session.hasStageData) {
            MiniStageBar(
                session = session,
                modifier = Modifier
                    .width(60.dp)
                    .height(8.dp)
                    .padding(horizontal = 4.dp)
            )
        }

        Spacer(Modifier.width(8.dp))

        // Duration + quality
        Column(horizontalAlignment = Alignment.End) {
            Text(
                session.totalFormatted,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold
            )
            val qualityColor = when {
                session.qualityScore >= 80 -> Color(0xFF22C55E)
                session.qualityScore >= 60 -> Color(0xFF3B82F6)
                session.qualityScore >= 40 -> Color(0xFFF59E0B)
                else -> Color(0xFFEF4444)
            }
            Text(
                session.qualityLabel,
                style = MaterialTheme.typography.labelSmall,
                color = qualityColor
            )
        }
    }
}

@Composable
private fun MiniStageBar(
    session: SleepSession,
    modifier: Modifier = Modifier
) {
    val total = (session.deepMinutes + session.lightMinutes + session.remMinutes + session.awakeMinutes)
        .coerceAtLeast(1)

    Canvas(modifier = modifier) {
        val barWidth = size.width
        val barHeight = size.height

        drawRoundRect(
            color = Color.White.copy(alpha = 0.1f),
            cornerRadius = CornerRadius(barHeight / 2, barHeight / 2),
            size = Size(barWidth, barHeight)
        )

        var x = 0f
        val segments = listOf(
            session.deepMinutes to DeepColor,
            session.lightMinutes to LightColor,
            session.remMinutes to RemColor,
            session.awakeMinutes to AwakeColor
        ).filter { it.first > 0 }

        segments.forEach { (minutes, color) ->
            val segWidth = (minutes.toFloat() / total) * barWidth
            drawRect(
                color = color,
                topLeft = Offset(x, 0f),
                size = Size(segWidth, barHeight)
            )
            x += segWidth
        }
    }
}

// ─────────────────────────────────────
// MARK: - Empty & Skeleton States
// ─────────────────────────────────────

@Composable
private fun EmptySleepContent(onLogSleep: () -> Unit = {}) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(32.dp)
        ) {
            Icon(
                Icons.Default.Bedtime,
                contentDescription = null,
                tint = SleepColor.copy(alpha = 0.5f),
                modifier = Modifier.size(64.dp)
            )
            Text(
                "No Sleep Data",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                "Sleep data will appear here once it's recorded by your wearable or sleep tracking app via Health Connect.",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = onLogSleep,
                colors = ButtonDefaults.buttonColors(containerColor = SleepColor),
                shape = RoundedCornerShape(14.dp)
            ) {
                Icon(
                    Icons.Default.Bedtime,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text("Log Sleep Manually", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun SleepSkeletonContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Shimmer placeholders
        repeat(3) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(if (it == 0) 140.dp else 100.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(AppColors.onSurface.copy(alpha = 0.06f))
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────

private fun formatMinutes(minutes: Int): String {
    if (minutes <= 0) return "0m"
    val h = minutes / 60
    val m = minutes % 60
    return if (h > 0) "${h}h ${m}m" else "${m}m"
}
