package com.swastricare.health.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.*
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.roundToInt

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main Screen
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun HealthAnalyticsScreen(
    viewModel: HealthAnalyticsViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {},
    onNavigateToAI: () -> Unit = {},
    onNavigateToMetricDetail: (LegacyMetricType) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        if (uiState.isLoading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.primary)
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 120.dp)
            ) {
                item {
                    AnalyticsTopBar(onNavigateBack = onNavigateBack)
                    Spacer(Modifier.height(8.dp))
                }
                item {
                    HeroCard(summaries = uiState.summaries, healthScore = uiState.healthScore)
                    Spacer(Modifier.height(16.dp))
                }
                item {
                    TimeRangeChips(
                        selected = uiState.selectedTimeRange,
                        onSelect = { viewModel.selectTimeRange(it) }
                    )
                    Spacer(Modifier.height(16.dp))
                }
                item {
                    ChartCard(
                        selectedMetric = uiState.selectedMetric,
                        selectedRange = uiState.selectedTimeRange,
                        chartData = uiState.chartData,
                        onMetricSelected = { viewModel.selectMetric(it) }
                    )
                    Spacer(Modifier.height(16.dp))
                }
                item {
                    Text(
                        text = "All Metrics",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onBackground,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                    Spacer(Modifier.height(12.dp))
                }
                val rows = uiState.summaries.chunked(2)
                items(rows) { row ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        row.forEachIndexed { colIdx, summary ->
                            MetricCard(
                                summary = summary,
                                animationDelay = (rows.indexOf(row) * 2 + colIdx) * 80,
                                modifier = Modifier.weight(1f),
                                onClick = { onNavigateToMetricDetail(summary.type) }
                            )
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(12.dp))
                }
                item {
                    Spacer(Modifier.height(8.dp))
                    AIInsightsCard(insight = uiState.aiInsight, onAskAI = onNavigateToAI)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - TopBar
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
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = AppColors.onSurface,
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(Modifier.width(12.dp))
        Text(
            text = "Health Analytics",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground,
            modifier = Modifier.weight(1f)
        )
        val today = remember { LocalDate.now().format(DateTimeFormatter.ofPattern("MMM d")) }
        Box(
            modifier = Modifier
                .glass(cornerRadius = 12.dp)
                .padding(horizontal = 10.dp, vertical = 4.dp)
        ) {
            Text(
                text = "Today, $today",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Hero Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun HeroCard(summaries: List<LegacyMetricSummary>, healthScore: Int) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(100); isVisible = true }
    val animAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600),
        label = "heroAlpha"
    )
    val animOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 24f,
        animationSpec = tween(600),
        label = "heroOffset"
    )

    val scoreColor = when {
        healthScore >= 90 -> PrimaryColor
        healthScore >= 70 -> SecondaryColor
        healthScore >= 40 -> WarningOrange
        else -> DangerRed
    }
    val scoreLabel = when {
        healthScore >= 90 -> "Excellent"
        healthScore >= 70 -> "Good"
        healthScore >= 40 -> "Fair"
        else -> "Needs Attention"
    }
    val keyMetrics = summaries.filter {
        it.type in listOf(
            LegacyMetricType.Steps,
            LegacyMetricType.HeartRate,
            LegacyMetricType.Sleep,
            LegacyMetricType.Hydration
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .graphicsLayer { alpha = animAlpha; translationY = animOffset }
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            HealthScoreRing(score = healthScore, scoreColor = scoreColor, scoreLabel = scoreLabel)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                keyMetrics.forEach { HeroMetricPill(summary = it) }
            }
        }
    }
}

@Composable
private fun HealthScoreRing(score: Int, scoreColor: Color, scoreLabel: String) {
    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(score) {
        animProgress = 0f
        animate(
            initialValue = 0f,
            targetValue = score / 100f,
            animationSpec = tween(1200, easing = FastOutSlowInEasing)
        ) { v, _ -> animProgress = v }
    }
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(110.dp)) {
        Canvas(modifier = Modifier.size(110.dp)) {
            val stroke = 10.dp.toPx()
            val inset = stroke / 2f
            drawArc(
                color = scoreColor.copy(alpha = 0.15f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(size.width - stroke, size.height - stroke),
                style = Stroke(stroke, cap = StrokeCap.Round)
            )
            drawArc(
                color = scoreColor,
                startAngle = -90f,
                sweepAngle = 360f * animProgress,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(size.width - stroke, size.height - stroke),
                style = Stroke(stroke, cap = StrokeCap.Round)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "$score",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = scoreColor,
                fontSize = 28.sp
            )
            Text(
                text = scoreLabel,
                style = MaterialTheme.typography.labelSmall,
                color = scoreColor,
                fontSize = 10.sp
            )
        }
    }
}

@Composable
private fun HeroMetricPill(summary: LegacyMetricSummary) {
    val goal = summary.type.goal
    val progress = if (goal != null && goal > 0f) (summary.currentValue / goal).coerceIn(0f, 1f) else 0f
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(summary.type.color, CircleShape)
            )
            Text(
                text = summary.type.label,
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant,
                fontSize = 11.sp
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "${formatValue(summary.currentValue, summary.type)} ${summary.type.unit}",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface,
                fontSize = 12.sp
            )
        }
        if (goal != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(summary.type.color.copy(alpha = 0.15f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(progress)
                        .clip(RoundedCornerShape(2.dp))
                        .background(summary.type.color)
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Time Range Chips
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TimeRangeChips(
    selected: LegacyTimeRange,
    onSelect: (LegacyTimeRange) -> Unit
) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(LegacyTimeRange.entries) { range ->
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
// MARK: - Chart Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ChartCard(
    selectedMetric: LegacyMetricType,
    selectedRange: LegacyTimeRange,
    chartData: List<LegacyChartDataPoint>,
    onMetricSelected: (LegacyMetricType) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(
            text = "${selectedMetric.label} Overview",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(LegacyMetricType.entries) { metric ->
                val isSelected = metric == selectedMetric
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.clickable { onMetricSelected(metric) }
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(
                                if (isSelected) metric.color else metric.color.copy(alpha = 0.1f)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = iconFor(metric),
                            contentDescription = metric.label,
                            tint = if (isSelected) Color.White else metric.color,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Text(
                        text = metric.label.split(" ").first(),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) metric.color else AppColors.onSurfaceVariant,
                        fontSize = 9.sp
                    )
                }
            }
        }
        when (selectedRange) {
            LegacyTimeRange.Month -> BezierLineChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
            else -> GradientBarChart(
                data = chartData,
                color = selectedMetric.color,
                goalValue = selectedMetric.goal
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Gradient Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun GradientBarChart(
    data: List<LegacyChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return
    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animProgress = 0f
        animate(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = tween(800, easing = FastOutSlowInEasing)
        ) { v, _ -> animProgress = v }
    }
    var dragX by remember { mutableStateOf<Float?>(null) }
    val scope = rememberCoroutineScope()
    var dismissJob by remember { mutableStateOf<Job?>(null) }
    val textMeasurer = rememberTextMeasurer()
    val maxVal = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxVal, it) * 1.15f } ?: (maxVal * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(280.dp)
            .pointerInput(data) {
                detectDragGestures(
                    onDragStart = { offset -> dragX = offset.x },
                    onDrag = { _, drag -> dragX = (dragX ?: 0f) + drag.x },
                    onDragEnd = {
                        dismissJob?.cancel()
                        dismissJob = scope.launch { delay(1500); dragX = null }
                    },
                    onDragCancel = { dragX = null }
                )
            }
    ) {
        val lp = 44.dp.toPx()
        val cw = size.width - lp - 8.dp.toPx()
        val ch = size.height - 28.dp.toPx() - 8.dp.toPx()
        val count = data.size
        val gapRatio = 0.3f
        val bw = cw / count * (1f - gapRatio)
        val gap = cw / count * gapRatio

        for (i in 0..3) {
            val yVal = yMax * i / 3f
            val yPos = ch - (yVal / yMax * ch) + 8.dp.toPx()
            val m = textMeasurer.measure(
                formatAxis(yVal),
                style = TextStyle(fontSize = 9.sp, color = labelColor)
            )
            drawText(m, topLeft = Offset(0f, yPos - m.size.height / 2f))
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(lp, yPos),
                end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        var hoveredIdx: Int? = null
        data.forEachIndexed { idx, point ->
            val x = lp + idx * (bw + gap) + gap / 2f
            val isHovered = dragX != null && dragX!! >= x && dragX!! <= x + bw
            if (isHovered) hoveredIdx = idx
            val barH = (point.value / yMax * ch) * animProgress
            val top = ch - barH + 8.dp.toPx()
            drawRoundRect(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        if (isHovered) color else color.copy(alpha = 0.85f),
                        color.copy(alpha = 0.5f)
                    ),
                    startY = top,
                    endY = top + barH
                ),
                topLeft = Offset(x, top),
                size = Size(bw, barH),
                cornerRadius = CornerRadius(6.dp.toPx(), 6.dp.toPx())
            )
            if (point.label.isNotEmpty()) {
                val m = textMeasurer.measure(
                    point.label,
                    style = TextStyle(fontSize = 9.sp, color = labelColor)
                )
                drawText(m, topLeft = Offset(x + bw / 2f - m.size.width / 2f, ch + 12.dp.toPx()))
            }
        }

        if (goalValue != null && goalValue <= yMax) {
            val goalY = ch - (goalValue / yMax * ch) + 8.dp.toPx()
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(lp, goalY),
                end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }

        val ti = hoveredIdx
        if (ti != null) {
            val point = data[ti]
            val x = lp + ti * (bw + gap) + gap / 2f
            val tooltipText = "${point.label}: ${formatAxis(point.value)}"
            val tm = textMeasurer.measure(
                tooltipText,
                style = TextStyle(fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.SemiBold)
            )
            val tPad = 6.dp.toPx()
            val tW = tm.size.width + tPad * 2
            val tH = tm.size.height + tPad * 2
            val tX = (x + bw / 2f - tW / 2f).coerceIn(lp, size.width - tW - 4.dp.toPx())
            val barH = (point.value / yMax * ch) * animProgress
            val tY = (ch - barH + 8.dp.toPx() - tH - 8.dp.toPx()).coerceAtLeast(4.dp.toPx())
            drawRoundRect(color = color, topLeft = Offset(tX, tY), size = Size(tW, tH), cornerRadius = CornerRadius(6.dp.toPx()))
            drawText(tm, topLeft = Offset(tX + tPad, tY + tPad))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Bezier Line Chart
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun BezierLineChart(
    data: List<LegacyChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return
    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animProgress = 0f
        animate(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = tween(1000, easing = FastOutSlowInEasing)
        ) { v, _ -> animProgress = v }
    }
    var dragX by remember { mutableStateOf<Float?>(null) }
    val scope = rememberCoroutineScope()
    var dismissJob by remember { mutableStateOf<Job?>(null) }
    val textMeasurer = rememberTextMeasurer()
    val maxVal = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxVal, it) * 1.15f } ?: (maxVal * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(280.dp)
            .pointerInput(data) {
                detectDragGestures(
                    onDragStart = { offset -> dragX = offset.x },
                    onDrag = { _, drag -> dragX = (dragX ?: 0f) + drag.x },
                    onDragEnd = {
                        dismissJob?.cancel()
                        dismissJob = scope.launch { delay(1500); dragX = null }
                    },
                    onDragCancel = { dragX = null }
                )
            }
    ) {
        val lp = 44.dp.toPx()
        val cw = size.width - lp - 8.dp.toPx()
        val ch = size.height - 28.dp.toPx() - 8.dp.toPx()
        val top = 8.dp.toPx()
        val spacing = cw / (data.size - 1).coerceAtLeast(1)

        for (i in 0..3) {
            val yVal = yMax * i / 3f
            val yPos = ch - (yVal / yMax * ch) + top
            val m = textMeasurer.measure(
                formatAxis(yVal),
                style = TextStyle(fontSize = 9.sp, color = labelColor)
            )
            drawText(m, topLeft = Offset(0f, yPos - m.size.height / 2f))
            drawLine(
                color = labelColor.copy(alpha = 0.1f),
                start = Offset(lp, yPos),
                end = Offset(size.width - 8.dp.toPx(), yPos),
                strokeWidth = 1f
            )
        }

        val allPts = data.mapIndexed { i, pt ->
            Offset(lp + i * spacing, ch - (pt.value / yMax * ch) + top)
        }
        val visibleCount = (allPts.size * animProgress).toInt().coerceAtLeast(1)
        val pts = allPts.take(visibleCount)

        if (pts.size >= 2) {
            val fillPath = Path().apply {
                moveTo(pts.first().x, ch + top)
                lineTo(pts.first().x, pts.first().y)
                for (i in 1 until pts.size) {
                    val cpX = (pts[i - 1].x + pts[i].x) / 2f
                    cubicTo(cpX, pts[i - 1].y, cpX, pts[i].y, pts[i].x, pts[i].y)
                }
                lineTo(pts.last().x, ch + top)
                close()
            }
            drawPath(
                fillPath,
                brush = Brush.verticalGradient(
                    colors = listOf(color.copy(alpha = 0.4f), Color.Transparent),
                    startY = top,
                    endY = ch + top
                )
            )
            val linePath = Path().apply {
                moveTo(pts.first().x, pts.first().y)
                for (i in 1 until pts.size) {
                    val cpX = (pts[i - 1].x + pts[i].x) / 2f
                    cubicTo(cpX, pts[i - 1].y, cpX, pts[i].y, pts[i].x, pts[i].y)
                }
            }
            drawPath(linePath, color = color, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
        }

        pts.forEachIndexed { i, pt ->
            drawCircle(color = color, radius = 4.dp.toPx(), center = pt)
            drawCircle(color = Color.White, radius = 2.dp.toPx(), center = pt)
            if (data[i].label.isNotEmpty()) {
                val m = textMeasurer.measure(
                    data[i].label,
                    style = TextStyle(fontSize = 9.sp, color = labelColor)
                )
                drawText(m, topLeft = Offset(pt.x - m.size.width / 2f, ch + 12.dp.toPx()))
            }
        }

        if (goalValue != null && goalValue <= yMax) {
            val goalY = ch - (goalValue / yMax * ch) + top
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(lp, goalY),
                end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }

        val dx = dragX
        if (dx != null && dx >= lp) {
            val closestIdx = allPts.indices.minByOrNull { abs(allPts[it].x - dx) } ?: return@Canvas
            val pt = pts.getOrNull(closestIdx) ?: return@Canvas
            drawLine(
                color = color.copy(alpha = 0.6f),
                start = Offset(pt.x, top),
                end = Offset(pt.x, ch + top),
                strokeWidth = 1.5f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
            )
            val tooltipText = "${data[closestIdx].label}: ${formatAxis(data[closestIdx].value)}"
            val tm = textMeasurer.measure(
                tooltipText,
                style = TextStyle(fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.SemiBold)
            )
            val tPad = 6.dp.toPx()
            val tW = tm.size.width + tPad * 2
            val tH = tm.size.height + tPad * 2
            val tX = (pt.x - tW / 2f).coerceIn(lp, size.width - tW - 4.dp.toPx())
            val tY = (pt.y - tH - 10.dp.toPx()).coerceAtLeast(top)
            drawRoundRect(color = color, topLeft = Offset(tX, tY), size = Size(tW, tH), cornerRadius = CornerRadius(6.dp.toPx()))
            drawText(tm, topLeft = Offset(tX + tPad, tY + tPad))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Metric Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun MetricCard(
    summary: LegacyMetricSummary,
    animationDelay: Int = 0,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {}
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(animationDelay.toLong()); isVisible = true }
    val animAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500),
        label = "alpha"
    )
    val animOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "offset"
    )

    val goal = summary.type.goal
    val progress = if (goal != null && goal > 0f) (summary.currentValue / goal).coerceIn(0f, 1f) else 0f
    var ringProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(isVisible, progress) {
        if (isVisible) {
            animate(0f, progress, animationSpec = tween(900)) { v, _ -> ringProgress = v }
        }
    }

    Column(
        modifier = modifier
            .graphicsLayer { alpha = animAlpha; translationY = animOffset }
            .glass(cornerRadius = 20.dp)
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
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
                        imageVector = iconFor(summary.type),
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
            if (goal != null) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(48.dp)) {
                    Canvas(modifier = Modifier.size(48.dp)) {
                        val stroke = 4.dp.toPx()
                        val inset = stroke / 2f
                        drawArc(
                            color = summary.type.color.copy(alpha = 0.15f),
                            startAngle = -90f,
                            sweepAngle = 360f,
                            useCenter = false,
                            topLeft = Offset(inset, inset),
                            size = Size(size.width - stroke, size.height - stroke),
                            style = Stroke(stroke, cap = StrokeCap.Round)
                        )
                        drawArc(
                            color = summary.type.color,
                            startAngle = -90f,
                            sweepAngle = 360f * ringProgress,
                            useCenter = false,
                            topLeft = Offset(inset, inset),
                            size = Size(size.width - stroke, size.height - stroke),
                            style = Stroke(stroke, cap = StrokeCap.Round)
                        )
                    }
                    Text(
                        text = "${(progress * 100).roundToInt()}%",
                        style = MaterialTheme.typography.labelSmall,
                        fontSize = 8.sp,
                        color = summary.type.color,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
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

        val pct = abs(summary.changePercent).roundToInt()
        val (badgeColor, badgeText) = when (summary.trend) {
            LegacyTrendDirection.Up -> Color(0xFF4CAF50) to "+$pct%"
            LegacyTrendDirection.Down -> Color(0xFFF44336) to "-$pct%"
            LegacyTrendDirection.Flat -> Color.Gray to "—"
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
// MARK: - AI Insights Card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AIInsightsCard(insight: String, onAskAI: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition(label = "aiPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
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
                    .graphicsLayer { scaleX = pulseScale; scaleY = pulseScale }
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(PremiumColor.DeepPurpleStart, PremiumColor.DeepPurpleEnd)
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
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            contentPadding = PaddingValues(0.dp),
            shape = RoundedCornerShape(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(PremiumColor.DeepPurpleStart, PremiumColor.DeepPurpleEnd)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "Ask AI for more insights",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

private fun iconFor(type: LegacyMetricType): ImageVector = when (type) {
    LegacyMetricType.Steps -> Icons.Default.DirectionsWalk
    LegacyMetricType.Calories -> Icons.Default.LocalFireDepartment
    LegacyMetricType.HeartRate -> Icons.Default.Favorite
    LegacyMetricType.Sleep -> Icons.Default.Bedtime
    LegacyMetricType.Exercise -> Icons.Default.FitnessCenter
    LegacyMetricType.Distance -> Icons.Default.NearMe
    LegacyMetricType.Hydration -> Icons.Default.LocalDrink
    LegacyMetricType.MedAdherence -> Icons.Default.Medication
}

private fun formatValue(value: Float, type: LegacyMetricType): String = when (type) {
    LegacyMetricType.Steps,
    LegacyMetricType.Calories,
    LegacyMetricType.HeartRate,
    LegacyMetricType.Exercise,
    LegacyMetricType.Hydration,
    LegacyMetricType.MedAdherence -> "${value.roundToInt()}"
    LegacyMetricType.Sleep,
    LegacyMetricType.Distance -> String.format("%.1f", value)
}

private fun formatAxis(value: Float): String =
    if (value >= 1000f) {
        val k = value / 1000f
        if (k == k.toLong().toFloat()) "${k.toLong()}k" else String.format("%.1fk", k)
    } else if (value == value.toLong().toFloat()) "${value.toLong()}"
    else String.format("%.1f", value)
