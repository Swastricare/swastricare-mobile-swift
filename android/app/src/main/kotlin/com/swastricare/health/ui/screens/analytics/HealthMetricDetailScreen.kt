package com.swastricare.health.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.TextStyle as DateTextStyle
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun HealthMetricDetailScreen(
    metricTypeName: String,
    viewModel: HealthAnalyticsViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val metric = remember(metricTypeName) {
        LegacyMetricType.entries.firstOrNull { it.name == metricTypeName }
            ?: LegacyMetricType.Steps
    }
    val uiState by viewModel.uiState.collectAsState()
    val stats = remember(uiState.summaries) { viewModel.getMetricStats(metric) }
    val chartData = remember(uiState.summaries) {
        viewModel.generatePublicChartData(metric, LegacyTimeRange.Week)
    }
    val today = remember { LocalDate.now() }
    val historyDays = remember { (6 downTo 0).map { today.minusDays(it.toLong()) } }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            DetailTopBar(metric = metric, onBack = onNavigateBack)
            Spacer(Modifier.height(12.dp))
            DetailChartCard(metric = metric, chartData = chartData)
            Spacer(Modifier.height(16.dp))
            DetailStatsRow(stats = stats, metric = metric)
            Spacer(Modifier.height(16.dp))
            if (metric.goal != null) {
                DetailGoalCard(stats = stats, metric = metric)
                Spacer(Modifier.height(16.dp))
            }
            DetailHistoryCard(metric = metric, days = historyDays, chartData = chartData)
            Spacer(Modifier.height(120.dp))
        }
    }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

@Composable
private fun DetailTopBar(metric: LegacyMetricType, onBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .glass(cornerRadius = 20.dp),
            contentAlignment = Alignment.Center
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = AppColors.onSurface,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(metric.color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = iconForMetric(metric),
                contentDescription = null,
                tint = metric.color,
                modifier = Modifier.size(18.dp)
            )
        }
        Spacer(Modifier.width(10.dp))
        Text(
            text = metric.label,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
    }
}

// ── Chart Card ────────────────────────────────────────────────────────────────

@Composable
private fun DetailChartCard(metric: LegacyMetricType, chartData: List<LegacyChartDataPoint>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "7-Day Trend",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        DetailBezierChart(data = chartData, color = metric.color, goalValue = metric.goal)
    }
}

@Composable
private fun DetailBezierChart(
    data: List<LegacyChartDataPoint>,
    color: Color,
    goalValue: Float?,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(data) {
        animProgress = 0f
        animate(0f, 1f, animationSpec = tween(1000, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    val textMeasurer = rememberTextMeasurer()
    val maxVal = data.maxOf { it.value }.coerceAtLeast(1f)
    val yMax = goalValue?.let { maxOf(maxVal, it) * 1.15f } ?: (maxVal * 1.15f)
    val labelColor = AppColors.onSurfaceVariant

    Canvas(modifier = modifier.fillMaxWidth().height(320.dp)) {
        val lp = 44.dp.toPx()
        val bp = 28.dp.toPx()
        val cw = size.width - lp - 8.dp.toPx()
        val ch = size.height - bp - 8.dp.toPx()
        val top = 8.dp.toPx()
        val spacing = cw / (data.size - 1).coerceAtLeast(1)

        // 4 Y-axis gridlines
        for (i in 0..3) {
            val yVal = yMax * i / 3f
            val yPos = ch - (yVal / yMax * ch) + top
            val m = textMeasurer.measure(detailFormatAxisValue(yVal), style = TextStyle(fontSize = 9.sp, color = labelColor))
            drawText(m, topLeft = Offset(0f, yPos - m.size.height / 2f))
            drawLine(color = labelColor.copy(alpha = 0.1f), start = Offset(lp, yPos), end = Offset(size.width - 8.dp.toPx(), yPos), strokeWidth = 1f)
        }

        val allPts = data.mapIndexed { i, pt -> Offset(lp + i * spacing, ch - (pt.value / yMax * ch) + top) }
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
            drawPath(fillPath, brush = Brush.verticalGradient(
                colors = listOf(color.copy(alpha = 0.35f), Color.Transparent),
                startY = top, endY = ch + top
            ))
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
            drawCircle(color = color, radius = 5.dp.toPx(), center = pt)
            drawCircle(color = Color.White, radius = 2.5f.dp.toPx(), center = pt)
            if (data[i].label.isNotEmpty()) {
                val m = textMeasurer.measure(data[i].label, style = TextStyle(fontSize = 9.sp, color = labelColor))
                drawText(m, topLeft = Offset(pt.x - m.size.width / 2f, ch + 12.dp.toPx()))
            }
        }

        if (goalValue != null && goalValue <= yMax) {
            val goalY = ch - (goalValue / yMax * ch) + top
            drawLine(
                color = Color.White.copy(alpha = 0.5f),
                start = Offset(lp, goalY), end = Offset(size.width - 8.dp.toPx(), goalY),
                strokeWidth = 2f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
            )
        }
    }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

@Composable
private fun DetailStatsRow(stats: MetricStats, metric: LegacyMetricType) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        listOf(
            "Current" to detailFormatValue(stats.current, metric),
            "Average" to detailFormatValue(stats.average, metric),
            "Best" to detailFormatValue(stats.best, metric),
            "Goal" to (stats.goal?.let { detailFormatValue(it, metric) } ?: "—")
        ).forEach { (label, value) ->
            Column(
                modifier = Modifier
                    .weight(1f)
                    .glass(cornerRadius = 14.dp)
                    .padding(vertical = 12.dp, horizontal = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(text = value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = AppColors.onSurface)
                Text(text = label, style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
            }
        }
    }
}

// ── Goal Progress Card ────────────────────────────────────────────────────────

@Composable
private fun DetailGoalCard(stats: MetricStats, metric: LegacyMetricType) {
    val goal = stats.goal ?: return
    val progress = (stats.current / goal).coerceIn(0f, 1f)
    var animProgress by remember { mutableStateOf(0f) }
    LaunchedEffect(progress) {
        animate(0f, progress, animationSpec = tween(1200, easing = FastOutSlowInEasing)) { v, _ ->
            animProgress = v
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(text = "Goal Progress", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(160.dp)) {
            Canvas(modifier = Modifier.size(160.dp)) {
                val stroke = 14.dp.toPx()
                val inset = stroke / 2f
                drawArc(
                    color = metric.color.copy(alpha = 0.15f),
                    startAngle = -90f, sweepAngle = 360f, useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - stroke, size.height - stroke),
                    style = Stroke(stroke, cap = StrokeCap.Round)
                )
                drawArc(
                    color = metric.color,
                    startAngle = -90f, sweepAngle = 360f * animProgress, useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - stroke, size.height - stroke),
                    style = Stroke(stroke, cap = StrokeCap.Round)
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(text = "${(progress * 100).roundToInt()}%", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = metric.color)
                Text(text = "of goal", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
            }
        }
        val remaining = (goal - stats.current).coerceAtLeast(0f)
        Text(
            text = if (remaining == 0f) "Goal achieved!" else "${detailFormatValue(remaining, metric)} ${metric.unit} remaining",
            style = MaterialTheme.typography.bodyMedium,
            color = if (remaining == 0f) metric.color else AppColors.onSurfaceVariant
        )
    }
}

// ── 7-Day History ─────────────────────────────────────────────────────────────

@Composable
private fun DetailHistoryCard(
    metric: LegacyMetricType,
    days: List<LocalDate>,
    chartData: List<LegacyChartDataPoint>
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            text = "Recent History",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface,
            modifier = Modifier.padding(bottom = 12.dp)
        )
        val maxVal = chartData.maxOfOrNull { it.value }?.coerceAtLeast(1f) ?: 1f
        days.forEachIndexed { i, date ->
            val value = chartData.getOrNull(i)?.value ?: 0f
            val barFraction = (value / maxVal).coerceIn(0f, 1f)
            val dayLabel = date.dayOfWeek.getDisplayName(DateTextStyle.SHORT, Locale.getDefault())
            val dateLabel = "${date.dayOfMonth} ${date.month.getDisplayName(DateTextStyle.SHORT, Locale.getDefault())}"
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(text = dayLabel, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = AppColors.onSurface, modifier = Modifier.width(36.dp))
                Text(text = dateLabel, style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant, modifier = Modifier.width(52.dp))
                Box(
                    modifier = Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(4.dp)).background(metric.color.copy(alpha = 0.12f))
                ) {
                    Box(modifier = Modifier.fillMaxHeight().fillMaxWidth(barFraction).clip(RoundedCornerShape(4.dp)).background(metric.color))
                }
                Text(
                    text = if (value == 0f) "—" else detailFormatValue(value, metric),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (value == 0f) AppColors.onSurfaceVariant else AppColors.onSurface,
                    modifier = Modifier.width(52.dp)
                )
            }
            if (i < days.lastIndex) HorizontalDivider(color = AppColors.onSurfaceVariant.copy(alpha = 0.08f), thickness = 0.5.dp)
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun iconForMetric(type: LegacyMetricType) = when (type) {
    LegacyMetricType.Steps -> Icons.AutoMirrored.Filled.DirectionsWalk
    LegacyMetricType.Calories -> Icons.Default.LocalFireDepartment
    LegacyMetricType.HeartRate -> Icons.Default.Favorite
    LegacyMetricType.Sleep -> Icons.Default.Bedtime
    LegacyMetricType.Exercise -> Icons.Default.FitnessCenter
    LegacyMetricType.Distance -> Icons.Default.NearMe
    LegacyMetricType.Hydration -> Icons.Default.LocalDrink
    LegacyMetricType.MedAdherence -> Icons.Default.Medication
}

private fun detailFormatValue(value: Float, type: LegacyMetricType): String = when (type) {
    LegacyMetricType.Steps -> "${value.roundToInt()}"
    LegacyMetricType.Calories -> "${value.roundToInt()}"
    LegacyMetricType.HeartRate -> "${value.roundToInt()}"
    LegacyMetricType.Sleep -> String.format("%.1f", value)
    LegacyMetricType.Exercise -> "${value.roundToInt()}"
    LegacyMetricType.Distance -> String.format("%.1f", value)
    LegacyMetricType.Hydration -> "${value.roundToInt()}"
    LegacyMetricType.MedAdherence -> "${value.roundToInt()}"
}

private fun detailFormatAxisValue(value: Float): String =
    if (value >= 1000f) {
        val k = value / 1000f
        if (k == k.toLong().toFloat()) "${k.toLong()}k" else String.format("%.1fk", k)
    } else if (value == value.toLong().toFloat()) "${value.toLong()}"
    else String.format("%.1f", value)
