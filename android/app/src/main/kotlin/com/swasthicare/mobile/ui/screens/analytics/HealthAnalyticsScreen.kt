package com.swasthicare.mobile.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.AppColors
import kotlin.math.abs
import kotlin.math.roundToInt

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main Screen
// ─────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthAnalyticsScreen(
    viewModel: HealthAnalyticsViewModel = viewModel(),
    onNavigateBack: () -> Unit = {},
    onNavigateToAI: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = AppColors.primary)
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
            ) {
                // ── Top Bar ─────────────────────────────────────────────
                AnalyticsTopBar(onNavigateBack = onNavigateBack)

                Spacer(modifier = Modifier.height(8.dp))

                // ── Time Range Selector ─────────────────────────────────
                TimeRangeSelector(
                    selected = uiState.selectedTimeRange,
                    onSelect = { viewModel.selectTimeRange(it) }
                )

                Spacer(modifier = Modifier.height(16.dp))

                // ── Summary Cards Row ───────────────────────────────────
                SummaryCardsRow(summaries = uiState.summaries)

                Spacer(modifier = Modifier.height(20.dp))

                // ── Main Chart Section ──────────────────────────────────
                MainChartSection(
                    selectedMetric = uiState.selectedMetric,
                    selectedRange = uiState.selectedTimeRange,
                    chartData = uiState.chartData,
                    onMetricSelected = { viewModel.selectMetric(it) }
                )

                Spacer(modifier = Modifier.height(20.dp))

                // ── Metrics Grid ────────────────────────────────────────
                MetricsGrid(summaries = uiState.summaries)

                Spacer(modifier = Modifier.height(20.dp))

                // ── AI Insights Section ─────────────────────────────────
                AIInsightsSection(
                    insight = uiState.aiInsight,
                    onAskAI = onNavigateToAI
                )

                Spacer(modifier = Modifier.height(120.dp)) // space for bottom bar
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AnalyticsTopBar(onNavigateBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .glass(cornerRadius = 20.dp)
                .clickable { onNavigateBack() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = AppColors.onSurface,
                modifier = Modifier.size(20.dp)
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Text(
            text = "Health Analytics",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Time Range Selector
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TimeRangeSelector(
    selected: TimeRange,
    onSelect: (TimeRange) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        TimeRange.entries.forEach { range ->
            val isSelected = range == selected
            FilterChip(
                selected = isSelected,
                onClick = { onSelect(range) },
                label = {
                    Text(
                        text = range.label,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = AppColors.primary,
                    selectedLabelColor = AppColors.onPrimary,
                    containerColor = Color.Transparent,
                    labelColor = AppColors.onSurfaceVariant
                ),
                border = if (isSelected) null else FilterChipDefaults.filterChipBorder(
                    borderColor = AppColors.onSurfaceVariant.copy(alpha = 0.3f),
                    enabled = true,
                    selected = false
                )
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Summary Cards Row
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SummaryCardsRow(summaries: List<MetricSummary>) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        summaries.forEachIndexed { index, summary ->
            SummaryCard(summary = summary, animationDelay = index * 80)
        }
    }
}

@Composable
private fun SummaryCard(
    summary: MetricSummary,
    animationDelay: Int = 0
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animationDelay.toLong())
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "summaryAlpha"
    )
    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.85f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "summaryScale"
    )

    Column(
        modifier = Modifier
            .width(120.dp)
            .graphicsLayer {
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
            }
            .glass(cornerRadius = 20.dp)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .background(summary.type.color.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = iconForMetric(summary.type),
                    contentDescription = null,
                    tint = summary.type.color,
                    modifier = Modifier.size(14.dp)
                )
            }
            TrendArrow(trend = summary.trend)
        }

        Text(
            text = formatValue(summary.currentValue, summary.type),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )

        Text(
            text = summary.type.label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

@Composable
private fun TrendArrow(trend: TrendDirection) {
    val (icon, color) = when (trend) {
        TrendDirection.Up -> Icons.Default.TrendingUp to Color(0xFF4CAF50)
        TrendDirection.Down -> Icons.Default.TrendingDown to Color(0xFFF44336)
        TrendDirection.Flat -> Icons.Default.TrendingFlat to Color.Gray
    }
    Icon(
        imageVector = icon,
        contentDescription = trend.name,
        tint = color,
        modifier = Modifier.size(16.dp)
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main Chart Section
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun MainChartSection(
    selectedMetric: MetricType,
    selectedRange: TimeRange,
    chartData: List<ChartDataPoint>,
    onMetricSelected: (MetricType) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "${selectedMetric.label} Overview",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        // Metric type picker
        MetricTypePicker(
            selected = selectedMetric,
            onSelect = onMetricSelected
        )

        // Chart
        when (selectedRange) {
            TimeRange.Day -> BarChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
            TimeRange.Week -> BarChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
            TimeRange.Month -> LineChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
        }
    }
}

@Composable
private fun MetricTypePicker(
    selected: MetricType,
    onSelect: (MetricType) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        MetricType.entries.forEach { metric ->
            val isSelected = metric == selected
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(
                        if (isSelected) metric.color else metric.color.copy(alpha = 0.1f)
                    )
                    .clickable { onSelect(metric) },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = iconForMetric(metric),
                    contentDescription = metric.label,
                    tint = if (isSelected) Color.White else metric.color,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Bar Chart (Canvas)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun BarChart(
    data: List<ChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var animationProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animationProgress = 0f
        animate(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = tween(durationMillis = 800, easing = FastOutSlowInEasing)
        ) { value, _ -> animationProgress = value }
    }

    val textMeasurer = rememberTextMeasurer()
    val maxValue = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxValue, it) * 1.15f } ?: (maxValue * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp)
    ) {
        val leftPadding = 40.dp.toPx()
        val bottomPadding = 24.dp.toPx()
        val chartWidth = size.width - leftPadding - 8.dp.toPx()
        val chartHeight = size.height - bottomPadding - 8.dp.toPx()
        val barCount = data.size
        val totalGapRatio = 0.3f
        val barWidth = chartWidth / barCount * (1f - totalGapRatio)
        val gap = chartWidth / barCount * totalGapRatio

        // Y-axis labels (3 ticks)
        for (i in 0..2) {
            val yVal = yMax * i / 2f
            val yPos = chartHeight - (yVal / yMax * chartHeight) + 8.dp.toPx()
            val labelText = formatAxisValue(yVal)
            val measured = textMeasurer.measure(
                labelText,
                style = TextStyle(fontSize = 9.sp, color = labelColor)
            )
            drawText(
                measured,
                topLeft = Offset(0f, yPos - measured.size.height / 2f)
            )
            // Gridline
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(leftPadding, yPos),
                end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        // Bars
        data.forEachIndexed { index, point ->
            val x = leftPadding + index * (barWidth + gap) + gap / 2f
            val barHeight = (point.value / yMax * chartHeight) * animationProgress
            val top = chartHeight - barHeight + 8.dp.toPx()
            val cornerPx = 4.dp.toPx()

            drawRoundRect(
                color = color,
                topLeft = Offset(x, top),
                size = Size(barWidth, barHeight),
                cornerRadius = CornerRadius(cornerPx, cornerPx)
            )

            // X-axis label
            if (point.label.isNotEmpty()) {
                val measured = textMeasurer.measure(
                    point.label,
                    style = TextStyle(fontSize = 9.sp, color = labelColor)
                )
                drawText(
                    measured,
                    topLeft = Offset(
                        x + barWidth / 2f - measured.size.width / 2f,
                        chartHeight + 12.dp.toPx()
                    )
                )
            }
        }

        // Goal line
        if (goalValue != null && goalValue <= yMax) {
            val goalY = chartHeight - (goalValue / yMax * chartHeight) + 8.dp.toPx()
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(leftPadding, goalY),
                end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Line Chart (Canvas) with gradient fill
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun LineChart(
    data: List<ChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var animationProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animationProgress = 0f
        animate(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = tween(durationMillis = 1000, easing = FastOutSlowInEasing)
        ) { value, _ -> animationProgress = value }
    }

    val textMeasurer = rememberTextMeasurer()
    val maxValue = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxValue, it) * 1.15f } ?: (maxValue * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp)
    ) {
        val leftPadding = 40.dp.toPx()
        val bottomPadding = 24.dp.toPx()
        val chartWidth = size.width - leftPadding - 8.dp.toPx()
        val chartHeight = size.height - bottomPadding - 8.dp.toPx()
        val topOffset = 8.dp.toPx()
        val pointSpacing = chartWidth / (data.size - 1).coerceAtLeast(1)

        // Y-axis labels
        for (i in 0..2) {
            val yVal = yMax * i / 2f
            val yPos = chartHeight - (yVal / yMax * chartHeight) + topOffset
            val measured = textMeasurer.measure(
                formatAxisValue(yVal),
                style = TextStyle(fontSize = 9.sp, color = labelColor)
            )
            drawText(measured, topLeft = Offset(0f, yPos - measured.size.height / 2f))
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(leftPadding, yPos),
                end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        // Compute points
        val visibleCount = (data.size * animationProgress).toInt().coerceAtLeast(1)
        val points = (0 until visibleCount).map { i ->
            val x = leftPadding + i * pointSpacing
            val y = chartHeight - (data[i].value / yMax * chartHeight) + topOffset
            Offset(x, y)
        }

        // Gradient fill path
        if (points.size >= 2) {
            val fillPath = Path().apply {
                moveTo(points.first().x, chartHeight + topOffset)
                points.forEach { lineTo(it.x, it.y) }
                lineTo(points.last().x, chartHeight + topOffset)
                close()
            }
            drawPath(
                path = fillPath,
                brush = Brush.verticalGradient(
                    colors = listOf(color.copy(alpha = 0.4f), Color.Transparent),
                    startY = 0f,
                    endY = chartHeight + topOffset
                )
            )
        }

        // Line
        if (points.size >= 2) {
            val linePath = Path().apply {
                moveTo(points.first().x, points.first().y)
                for (i in 1 until points.size) {
                    lineTo(points[i].x, points[i].y)
                }
            }
            drawPath(
                path = linePath,
                color = color,
                style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
            )
        }

        // Dots
        points.forEach { pt ->
            drawCircle(color = color, radius = 4.dp.toPx(), center = pt)
            drawCircle(color = Color.White, radius = 2.dp.toPx(), center = pt)
        }

        // X-axis labels
        data.forEachIndexed { i, point ->
            if (point.label.isNotEmpty()) {
                val x = leftPadding + i * pointSpacing
                val measured = textMeasurer.measure(
                    point.label,
                    style = TextStyle(fontSize = 9.sp, color = labelColor)
                )
                drawText(
                    measured,
                    topLeft = Offset(x - measured.size.width / 2f, chartHeight + 12.dp.toPx())
                )
            }
        }

        // Goal line
        if (goalValue != null && goalValue <= yMax) {
            val goalY = chartHeight - (goalValue / yMax * chartHeight) + topOffset
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(leftPadding, goalY),
                end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Metrics Grid (2 columns)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun MetricsGrid(summaries: List<MetricSummary>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "All Metrics",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        // 2-column grid
        val rows = summaries.chunked(2)
        rows.forEachIndexed { rowIdx, row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                row.forEachIndexed { colIdx, summary ->
                    MetricGridCard(
                        summary = summary,
                        animationDelay = (rowIdx * 2 + colIdx) * 100,
                        modifier = Modifier.weight(1f)
                    )
                }
                // fill remaining space if odd count
                if (row.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun MetricGridCard(
    summary: MetricSummary,
    animationDelay: Int = 0,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animationDelay.toLong())
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "gridAlpha"
    )
    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "gridOffset"
    )

    Column(
        modifier = modifier
            .graphicsLayer {
                alpha = animatedAlpha
                translationY = animatedOffset
            }
            .glass(cornerRadius = 20.dp)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .background(summary.type.color.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = iconForMetric(summary.type),
                    contentDescription = null,
                    tint = summary.type.color,
                    modifier = Modifier.size(16.dp)
                )
            }
            Text(
                text = summary.type.label,
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.onSurfaceVariant
            )
        }

        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = formatValue(summary.currentValue, summary.type),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                text = summary.type.unit,
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 3.dp)
            )
        }

        // Change badge
        val pct = abs(summary.changePercent).roundToInt()
        val (badgeColor, badgeText) = when (summary.trend) {
            TrendDirection.Up -> Color(0xFF4CAF50) to "+$pct%"
            TrendDirection.Down -> Color(0xFFF44336) to "-$pct%"
            TrendDirection.Flat -> Color.Gray to "0%"
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(badgeColor.copy(alpha = 0.15f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(
                    text = badgeText,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = badgeColor
                )
            }
            Text(
                text = "vs prev",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant.copy(alpha = 0.6f)
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AI Insights Section
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AIInsightsSection(
    insight: String,
    onAskAI: () -> Unit
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(600)
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "aiAlpha"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .graphicsLayer { alpha = animatedAlpha }
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(Color(0xFF7C4DFF), Color(0xFF448AFF))
                        ),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }

            Text(
                text = "AI Health Insights",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }

        Text(
            text = insight,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant,
            lineHeight = 22.sp
        )

        Button(
            onClick = onAskAI,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = AppColors.primary.copy(alpha = 0.15f),
                contentColor = AppColors.primary
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.AutoAwesome,
                contentDescription = null,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Ask AI for more insights",
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

private fun iconForMetric(type: MetricType): ImageVector = when (type) {
    MetricType.Steps -> Icons.Default.DirectionsWalk
    MetricType.Calories -> Icons.Default.LocalFireDepartment
    MetricType.HeartRate -> Icons.Default.Favorite
    MetricType.Sleep -> Icons.Default.Bedtime
    MetricType.Exercise -> Icons.Default.FitnessCenter
    MetricType.Distance -> Icons.Default.NearMe
}

private fun formatValue(value: Float, type: MetricType): String = when (type) {
    MetricType.Steps -> "${value.roundToInt()}"
    MetricType.Calories -> "${value.roundToInt()}"
    MetricType.HeartRate -> "${value.roundToInt()}"
    MetricType.Sleep -> String.format("%.1f", value)
    MetricType.Exercise -> "${value.roundToInt()}"
    MetricType.Distance -> String.format("%.1f", value)
}

private fun formatAxisValue(value: Float): String =
    if (value >= 1000f) "${(value / 1000f).let { if (it == it.toLong().toFloat()) "${it.toLong()}k" else String.format("%.1fk", it) }}"
    else if (value == value.toLong().toFloat()) "${value.toLong()}"
    else String.format("%.1f", value)
