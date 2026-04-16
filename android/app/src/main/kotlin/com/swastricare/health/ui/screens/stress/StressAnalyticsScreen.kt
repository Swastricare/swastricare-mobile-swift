package com.swastricare.health.ui.screens.stress

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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
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
import com.swastricare.health.domain.model.stress.StressCategory
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.delay
import java.time.format.DateTimeFormatter

// Zone colors
private val ZoneLow = Color(0xFF4CAF50)
private val ZoneModerate = Color(0xFFFFC107)
private val ZoneHigh = Color(0xFFFF9800)
private val ZoneSevere = Color(0xFFF44336)

private val StressAccent = Color(0xFF7C3AED)

@Composable
fun StressAnalyticsScreen(
    onNavigateBack: () -> Unit = {}
) {
    TrackScreen("StressAnalytics")
    val viewModel: StressViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()

    val filteredEntries = remember(uiState) { viewModel.getFilteredEntries() }
    val summary = remember(uiState) { viewModel.getSummary() }
    val dailyAggregates = remember(uiState) { viewModel.getDailyAggregates() }
    val groupedHistory = remember(uiState) { viewModel.getGroupedHistory() }
    val categoryDistribution = remember(uiState) { viewModel.getCategoryDistribution() }

    Column(modifier = Modifier.fillMaxSize()) {
        // ── Top Bar ──
        AppTopBar(title = "Stress Analytics", onBack = onNavigateBack)

        when {
            uiState.isLoading -> AnalyticsSkeletonContent()
            uiState.allEntries.isEmpty() -> EmptyAnalyticsContent()
            else -> AnalyticsContent(
                uiState = uiState,
                filteredEntries = filteredEntries,
                summary = summary,
                dailyAggregates = dailyAggregates,
                groupedHistory = groupedHistory,
                categoryDistribution = categoryDistribution,
                onRangeSelected = { viewModel.setTimeRange(it) }
            )
        }
    }
}

// ── Analytics Content ──

@Composable
private fun AnalyticsContent(
    uiState: StressUiState,
    filteredEntries: List<com.swastricare.health.domain.model.stress.StressEntry>,
    summary: StressSummary,
    dailyAggregates: List<StressDailyAggregate>,
    groupedHistory: List<StressDayGroup>,
    categoryDistribution: Map<StressCategory, Float>,
    onRangeSelected: (StressTimeRange) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        // Time range selector
        item {
            TimeRangeSelector(
                selectedRange = uiState.selectedRange,
                onRangeSelected = onRangeSelected,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }

        // Summary cards
        item {
            Spacer(Modifier.height(12.dp))
            SummaryCardsRow(summary = summary)
        }

        // Trend chart
        item {
            Spacer(Modifier.height(20.dp))
            StressTrendChart(
                dailyAggregates = dailyAggregates,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Category distribution
        if (categoryDistribution.isNotEmpty()) {
            item {
                Spacer(Modifier.height(20.dp))
                CategoryDistributionCard(
                    distribution = categoryDistribution,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
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
                    "${filteredEntries.size} entries",
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
                        "No entries in this time range",
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
        } else {
            groupedHistory.forEach { group ->
                item(key = "header_${group.date}") {
                    DayGroupHeader(
                        label = group.label,
                        count = group.entries.size,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
                    )
                }
                items(
                    items = group.entries,
                    key = { "${it.timestamp}_${it.stressLevel}" }
                ) { entry ->
                    HistoryRow(
                        entry = entry,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                    )
                }
            }
        }
    }
}

// ── Time Range Selector ──

@Composable
private fun TimeRangeSelector(
    selectedRange: StressTimeRange,
    onRangeSelected: (StressTimeRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        StressTimeRange.entries.forEach { range ->
            val isSelected = range == selectedRange
            val chipModifier = if (isSelected) {
                Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(StressAccent)
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

// ── Summary Cards ──

@Composable
private fun SummaryCardsRow(summary: StressSummary) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SummaryCard(
            label = "Average",
            value = if (summary.average > 0) "${summary.average}" else "--",
            unit = "/10",
            color = StressAccent,
            icon = Icons.AutoMirrored.Filled.TrendingDown,
            animationDelay = 100,
            modifier = Modifier.weight(1f)
        )
        SummaryCard(
            label = "Min",
            value = if (summary.min > 0) "${summary.min}" else "--",
            unit = "/10",
            color = ZoneLow,
            icon = Icons.Default.ArrowDownward,
            animationDelay = 200,
            modifier = Modifier.weight(1f)
        )
        SummaryCard(
            label = "Max",
            value = if (summary.max > 0) "${summary.max}" else "--",
            unit = "/10",
            color = ZoneSevere,
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
        label = "alpha"
    )
    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.9f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "scale"
    )

    Column(
        modifier = modifier
            .graphicsLayer { alpha = animatedAlpha; scaleX = animatedScale; scaleY = animatedScale }
            .glass(cornerRadius = 16.dp)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(16.dp))
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            if (value != "--") {
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ── Stress Trend Chart ──

@Composable
private fun StressTrendChart(
    dailyAggregates: List<StressDailyAggregate>,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(400); isVisible = true }

    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(1200, easing = FastOutSlowInEasing),
        label = "chartProgress"
    )

    val isDark = isSystemInDarkTheme()
    val textColor = if (isDark) Color.White.copy(alpha = 0.6f) else Color.Black.copy(alpha = 0.5f)

    Column(
        modifier = modifier
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Stress Trend",
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
                modifier = Modifier.fillMaxWidth().height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Need at least 2 days of data\nto show trend",
                    style = MaterialTheme.typography.bodyMedium,
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
                val width = size.width
                val height = size.height
                val leftPadding = 40f
                val rightPadding = 16f
                val topPadding = 16f
                val bottomPadding = 24f
                val chartWidth = width - leftPadding - rightPadding
                val chartHeight = height - topPadding - bottomPadding

                // Zone backgrounds
                val zones = listOf(
                    Triple(1f, 3f, ZoneLow.copy(alpha = 0.08f)),
                    Triple(3f, 6f, ZoneModerate.copy(alpha = 0.08f)),
                    Triple(6f, 8f, ZoneHigh.copy(alpha = 0.08f)),
                    Triple(8f, 10f, ZoneSevere.copy(alpha = 0.08f))
                )
                zones.forEach { (low, high, color) ->
                    val yBottom = topPadding + chartHeight * (1f - (low - 1f) / 9f)
                    val yTop = topPadding + chartHeight * (1f - (high - 1f) / 9f)
                    drawRect(
                        color = color,
                        topLeft = Offset(leftPadding, yTop),
                        size = androidx.compose.ui.geometry.Size(chartWidth, yBottom - yTop)
                    )
                }

                // Dashed zone boundaries
                val dashEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f))
                listOf(3f, 6f, 8f).forEach { boundary ->
                    val y = topPadding + chartHeight * (1f - (boundary - 1f) / 9f)
                    drawLine(
                        color = textColor.copy(alpha = 0.3f),
                        start = Offset(leftPadding, y),
                        end = Offset(width - rightPadding, y),
                        pathEffect = dashEffect,
                        strokeWidth = 1f
                    )
                }

                // Y-axis labels
                val labelPaint = android.graphics.Paint().apply {
                    this.color = textColor.toArgb()
                    textSize = 24f
                    isAntiAlias = true
                }
                listOf(1, 3, 6, 8, 10).forEach { level ->
                    val y = topPadding + chartHeight * (1f - (level - 1f) / 9f)
                    drawContext.canvas.nativeCanvas.drawText(
                        "$level",
                        8f,
                        y + 8f,
                        labelPaint
                    )
                }

                // Draw line
                if (dailyAggregates.isNotEmpty()) {
                    val path = Path()
                    val fillPath = Path()
                    val pointCount = (dailyAggregates.size * animatedProgress).toInt()
                        .coerceAtLeast(1)
                    val visibleData = dailyAggregates.take(pointCount)

                    visibleData.forEachIndexed { index, aggregate ->
                        val x = leftPadding + (index.toFloat() / (dailyAggregates.size - 1).coerceAtLeast(1)) * chartWidth
                        val y = topPadding + chartHeight * (1f - (aggregate.avgLevel - 1f) / 9f)
                        if (index == 0) {
                            path.moveTo(x, y)
                            fillPath.moveTo(x, topPadding + chartHeight)
                            fillPath.lineTo(x, y)
                        } else {
                            path.lineTo(x, y)
                            fillPath.lineTo(x, y)
                        }
                    }

                    // Gradient fill
                    val lastX = leftPadding + ((visibleData.size - 1).toFloat() / (dailyAggregates.size - 1).coerceAtLeast(1)) * chartWidth
                    fillPath.lineTo(lastX, topPadding + chartHeight)
                    fillPath.close()

                    drawPath(
                        path = fillPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                StressAccent.copy(alpha = 0.3f),
                                StressAccent.copy(alpha = 0.02f)
                            ),
                            startY = topPadding,
                            endY = topPadding + chartHeight
                        )
                    )

                    // Line stroke
                    drawPath(
                        path = path,
                        color = StressAccent,
                        style = Stroke(width = 3f, cap = StrokeCap.Round)
                    )

                    // Data points
                    visibleData.forEachIndexed { index, aggregate ->
                        val x = leftPadding + (index.toFloat() / (dailyAggregates.size - 1).coerceAtLeast(1)) * chartWidth
                        val y = topPadding + chartHeight * (1f - (aggregate.avgLevel - 1f) / 9f)
                        val dotColor = when {
                            aggregate.avgLevel <= 3 -> ZoneLow
                            aggregate.avgLevel <= 6 -> ZoneModerate
                            aggregate.avgLevel <= 8 -> ZoneHigh
                            else -> ZoneSevere
                        }
                        drawCircle(color = Color.White, radius = 6f, center = Offset(x, y))
                        drawCircle(color = dotColor, radius = 4f, center = Offset(x, y))
                    }
                }
            }
        }
    }
}

// ── Category Distribution ──

@Composable
private fun CategoryDistributionCard(
    distribution: Map<StressCategory, Float>,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Category Distribution",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        StressCategory.entries.forEach { category ->
            val fraction = distribution[category] ?: 0f
            val percent = (fraction * 100).toInt()
            val color = Color(category.colorHex)

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(color)
                )
                Text(
                    text = category.displayName,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.width(70.dp)
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(color.copy(alpha = 0.15f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(fraction.coerceIn(0f, 1f))
                            .clip(RoundedCornerShape(4.dp))
                            .background(color)
                    )
                }
                Text(
                    text = "$percent%",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    modifier = Modifier.width(36.dp),
                    textAlign = TextAlign.End
                )
            }
        }
    }
}

// ── Day Group Header ──

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
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Text(
            text = "$count ${if (count == 1) "entry" else "entries"}",
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ── History Row ──

@Composable
private fun HistoryRow(
    entry: com.swastricare.health.domain.model.stress.StressEntry,
    modifier: Modifier = Modifier
) {
    val categoryColor = Color(entry.category.colorHex)
    val timeFormatter = DateTimeFormatter.ofPattern("h:mm a")

    Row(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 12.dp)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Category color dot
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(categoryColor)
        )

        // Time
        Text(
            text = entry.timestamp.format(timeFormatter),
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant,
            modifier = Modifier.width(70.dp)
        )

        // Mood emoji
        Text(text = entry.mood.emoji, fontSize = 18.sp)

        // Stress level
        Text(
            text = "${entry.stressLevel}/10",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = categoryColor,
            modifier = Modifier.weight(1f)
        )

        // Category label
        Text(
            text = entry.category.displayName,
            style = MaterialTheme.typography.labelSmall,
            color = categoryColor
        )
    }
}

// ── Skeleton ──

@Composable
private fun AnalyticsSkeletonContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Time range placeholder
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(AppColors.onSurface.copy(alpha = 0.06f))
        )
        // Summary cards placeholder
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(90.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(AppColors.onSurface.copy(alpha = 0.06f))
                )
            }
        }
        // Chart placeholder
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(250.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(AppColors.onSurface.copy(alpha = 0.06f))
        )
    }
}

// ── Empty State ──

@Composable
private fun EmptyAnalyticsContent() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                Icons.Default.SelfImprovement,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = AppColors.onSurfaceVariant.copy(alpha = 0.4f)
            )
            Text(
                "No stress data yet",
                style = MaterialTheme.typography.titleMedium,
                color = AppColors.onSurfaceVariant
            )
            Text(
                "Log your first stress entry to see analytics",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )
        }
    }
}
