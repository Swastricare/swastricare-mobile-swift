package com.swasthicare.mobile.ui.screens.runactivity

import android.content.Intent
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.model.HeartRatePoint
import com.swasthicare.mobile.data.model.RoutePoint
import com.swasthicare.mobile.data.model.SplitData
import com.swasthicare.mobile.data.model.WorkoutDetail
import com.swasthicare.mobile.ui.components.RouteMapView
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

// ─────────────────────────────────────
// MARK: - Design Constants
// ─────────────────────────────────────

private val CyanAccent = Color(0xFF00E5FF)
private val GreenAccent = Color(0xFF38EF7D)
private val RedAccent = Color(0xFFFF4757)
private val OrangeAccent = Color(0xFFFF9F0A)
private val PurpleAccent = Color(0xFFBF5AF2)
private val ChartBackground = Color(0xFF1A1A2E)

// Heart rate zone colors
private val HrZoneBlue = Color(0xFF64B5F6)
private val HrZoneGreen = Color(0xFF66BB6A)
private val HrZoneYellow = Color(0xFFFFCA28)
private val HrZoneRed = Color(0xFFEF5350)

// ─────────────────────────────────────
// MARK: - Tab Enum
// ─────────────────────────────────────

private enum class DetailTab(val label: String) {
    OVERVIEW("Overview"),
    SPLITS("Splits"),
    PACE("Pace"),
    HEART_RATE("Heart Rate")
}

// ─────────────────────────────────────
// MARK: - ActivityDetailScreen
// ─────────────────────────────────────

@Composable
fun ActivityDetailScreen(
    workoutId: String,
    onNavigateBack: () -> Unit = {},
    onDelete: (String) -> Unit = {}
) {
    val context = LocalContext.current
    var selectedTab by remember { mutableStateOf(DetailTab.OVERVIEW) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var isMapExpanded by remember { mutableStateOf(false) }

    // TODO: Replace with real data fetching from repository
    val workout = remember { generateSampleWorkout(workoutId) }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .statusBarsPadding()
        ) {
            // ── Top Bar ──
            ActivityDetailTopBar(
                onBack = onNavigateBack,
                onShare = {
                    val distanceKm = workout.distanceMeters / 1000.0
                    val duration = formatDuration(workout.durationSeconds)
                    val typeLabel = workout.type.replaceFirstChar { it.uppercase() }
                    val shareText = "Completed a ${"%.2f".format(distanceKm)}km $typeLabel in $duration \u2014 SwasthiCare"
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        this.type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, shareText)
                    }
                    context.startActivity(Intent.createChooser(intent, "Share Workout"))
                }
            )

            // ── Route Map ──
            RouteMapView(
                routePoints = workout.routePoints,
                isLive = false,
                height = if (isMapExpanded) 350 else 200,
                onExpand = { isMapExpanded = !isMapExpanded }
            )

            Spacer(Modifier.height(16.dp))

            // ── Activity Header Card ──
            ActivityHeaderCard(
                workout = workout,
                modifier = Modifier.padding(horizontal = 20.dp)
            )

            Spacer(Modifier.height(16.dp))

            // ── Tab Selector ──
            DetailTabRow(
                selectedTab = selectedTab,
                onTabSelected = { selectedTab = it },
                modifier = Modifier.padding(horizontal = 20.dp)
            )

            Spacer(Modifier.height(16.dp))

            // ── Tab Content ──
            when (selectedTab) {
                DetailTab.OVERVIEW -> OverviewTab(
                    workout = workout,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )
                DetailTab.SPLITS -> SplitsTab(
                    splits = workout.splits,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )
                DetailTab.PACE -> PaceTab(
                    splits = workout.splits,
                    avgPace = workout.avgPace,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )
                DetailTab.HEART_RATE -> HeartRateTab(
                    heartRateData = workout.heartRateData,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )
            }

            Spacer(Modifier.height(24.dp))

            // ── Delete Button ──
            DeleteWorkoutButton(
                onClick = { showDeleteDialog = true },
                modifier = Modifier.padding(horizontal = 20.dp)
            )

            // Bottom spacer for navigation bar
            Spacer(Modifier.height(120.dp))
        }
    }

    // ── Delete Confirmation Dialog ──
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Workout") },
            text = { Text("Are you sure you want to delete this workout? This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        onDelete(workout.id)
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = RedAccent)
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            },
            containerColor = MaterialTheme.colorScheme.surface,
            titleContentColor = MaterialTheme.colorScheme.onSurface,
            textContentColor = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────

@Composable
private fun ActivityDetailTopBar(
    onBack: () -> Unit,
    onShare: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Icon(
                Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = MaterialTheme.colorScheme.onBackground
            )
        }

        Text(
            "Activity Detail",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground
        )

        IconButton(onClick = onShare) {
            Icon(
                Icons.Default.Share,
                contentDescription = "Share",
                tint = MaterialTheme.colorScheme.onBackground
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Activity Header Card
// ─────────────────────────────────────

@Composable
private fun ActivityHeaderCard(
    workout: WorkoutDetail,
    modifier: Modifier = Modifier
) {
    val typeIcon = when (workout.type) {
        "run" -> Icons.Default.DirectionsRun
        "walk" -> Icons.Default.DirectionsWalk
        "cycle" -> Icons.Default.DirectionsBike
        "hike" -> Icons.Default.Terrain
        else -> Icons.Default.DirectionsRun
    }

    val typeColor = when (workout.type) {
        "run" -> CyanAccent
        "walk" -> GreenAccent
        "cycle" -> Color(0xFFFFD60A)
        "hike" -> PurpleAccent
        else -> CyanAccent
    }

    val typeLabel = workout.type.replaceFirstChar { it.uppercase() }
    val distanceKm = workout.distanceMeters / 1000.0
    val duration = formatDuration(workout.durationSeconds)
    val avgPaceFormatted = formatPace(workout.avgPace)

    // Staggered entry
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "headerAlpha"
    )
    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 30f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "headerOffset"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = animatedAlpha
                translationY = animatedOffset
            }
            .glass(cornerRadius = 20.dp)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(typeColor.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = typeIcon,
                    contentDescription = null,
                    tint = typeColor,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = typeLabel,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = formatDateTime(workout.startTime),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        HorizontalDivider(
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
            thickness = 1.dp
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            HeaderStat(
                value = "${"%.2f".format(distanceKm)}",
                unit = "km",
                label = "Distance"
            )
            HeaderStat(
                value = duration,
                unit = "",
                label = "Duration"
            )
            HeaderStat(
                value = avgPaceFormatted,
                unit = "/km",
                label = "Avg Pace"
            )
            HeaderStat(
                value = "${workout.calories}",
                unit = "kcal",
                label = "Calories"
            )
        }
    }
}

@Composable
private fun HeaderStat(
    value: String,
    unit: String,
    label: String
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            if (unit.isNotEmpty()) {
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 2.dp, start = 2.dp)
                )
            }
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - Tab Selector
// ─────────────────────────────────────

@Composable
private fun DetailTabRow(
    selectedTab: DetailTab,
    onTabSelected: (DetailTab) -> Unit,
    modifier: Modifier = Modifier
) {
    TabRow(
        selectedTabIndex = selectedTab.ordinal,
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .glass(cornerRadius = 16.dp, opacity = 0.15f),
        containerColor = Color.Transparent,
        contentColor = MaterialTheme.colorScheme.onSurface,
        indicator = { tabPositions ->
            TabRowDefaults.SecondaryIndicator(
                modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab.ordinal]),
                height = 3.dp,
                color = MaterialTheme.colorScheme.primary
            )
        },
        divider = {}
    ) {
        DetailTab.entries.forEach { tab ->
            val isSelected = tab == selectedTab
            Tab(
                selected = isSelected,
                onClick = { onTabSelected(tab) },
                text = {
                    Text(
                        text = tab.label,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (isSelected)
                            MaterialTheme.colorScheme.primary
                        else
                            MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Overview Tab
// ─────────────────────────────────────

@Composable
private fun OverviewTab(
    workout: WorkoutDetail,
    modifier: Modifier = Modifier
) {
    val distanceKm = workout.distanceMeters / 1000.0

    val stats = listOf(
        OverviewStatData(Icons.Default.Straighten, "${"%.2f".format(distanceKm)}", "km", "Distance", CyanAccent),
        OverviewStatData(Icons.Default.Timer, formatDuration(workout.durationSeconds), "", "Duration", GreenAccent),
        OverviewStatData(Icons.Default.Speed, formatPace(workout.avgPace), "/km", "Avg Pace", OrangeAccent),
        OverviewStatData(Icons.Default.TrendingUp, "${"%.1f".format(workout.avgSpeed)}", "km/h", "Avg Speed", PurpleAccent),
        OverviewStatData(Icons.Default.LocalFireDepartment, "${workout.calories}", "kcal", "Calories", RedAccent),
        OverviewStatData(Icons.Default.Terrain, "${"%.0f".format(workout.elevationGain)}", "m", "Elevation", Color(0xFFFFD60A))
    )

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // 2x3 grid
        for (rowIndex in 0..2) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                for (colIndex in 0..1) {
                    val index = rowIndex * 2 + colIndex
                    if (index < stats.size) {
                        val s = stats[index]
                        StatCardContent(
                            icon = s.icon,
                            value = s.value,
                            unit = s.unit,
                            label = s.label,
                            color = s.color,
                            delay = index * 80,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }
}

private data class OverviewStatData(
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val value: String,
    val unit: String,
    val label: String,
    val color: Color
)

@Composable
private fun StatCardContent(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    unit: String,
    label: String,
    color: Color,
    delay: Int,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(delay.toLong())
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
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
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(16.dp)
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (unit.isNotEmpty()) {
                    Text(
                        text = unit,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 3.dp, start = 2.dp)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Splits Tab
// ─────────────────────────────────────

@Composable
private fun SplitsTab(
    splits: List<SplitData>,
    modifier: Modifier = Modifier
) {
    if (splits.isEmpty()) {
        EmptyTabPlaceholder(
            icon = Icons.Default.TableChart,
            message = "No split data available",
            modifier = modifier
        )
        return
    }

    val fastestPace = splits.minOf { it.paceSecondsPerKm }
    val slowestPace = splits.maxOf { it.paceSecondsPerKm }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
    ) {
        // Header row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.3f))
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            SplitHeaderCell("KM", Modifier.weight(0.8f))
            SplitHeaderCell("Split", Modifier.weight(1f))
            SplitHeaderCell("Pace", Modifier.weight(1f))
            SplitHeaderCell("Total", Modifier.weight(1f))
        }

        HorizontalDivider(
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
            thickness = 1.dp
        )

        // Data rows
        splits.forEachIndexed { index, split ->
            val isFastest = split.paceSecondsPerKm == fastestPace
            val isSlowest = split.paceSecondsPerKm == slowestPace
            val backgroundColor = when {
                isFastest -> GreenAccent.copy(alpha = 0.1f)
                isSlowest -> RedAccent.copy(alpha = 0.1f)
                index % 2 == 0 -> Color.Transparent
                else -> MaterialTheme.colorScheme.surface.copy(alpha = 0.1f)
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(backgroundColor)
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // KM number
                Text(
                    text = "${split.kilometer}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(0.8f)
                )

                // Split time
                Text(
                    text = formatDuration(split.timeSeconds),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )

                // Pace with color indicator
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    if (isFastest) {
                        Icon(
                            Icons.Default.KeyboardArrowUp,
                            contentDescription = "Fastest",
                            tint = GreenAccent,
                            modifier = Modifier.size(14.dp)
                        )
                    } else if (isSlowest) {
                        Icon(
                            Icons.Default.KeyboardArrowDown,
                            contentDescription = "Slowest",
                            tint = RedAccent,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                    Text(
                        text = formatPace(split.paceSecondsPerKm.toDouble()),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isFastest || isSlowest) FontWeight.Bold else FontWeight.Normal,
                        color = when {
                            isFastest -> GreenAccent
                            isSlowest -> RedAccent
                            else -> MaterialTheme.colorScheme.onSurface
                        }
                    )
                }

                // Cumulative time
                Text(
                    text = formatDuration(split.cumulativeSeconds),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
            }

            if (index < splits.size - 1) {
                HorizontalDivider(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.05f),
                    thickness = 0.5.dp,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }
    }
}

@Composable
private fun SplitHeaderCell(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier
    )
}

// ─────────────────────────────────────
// MARK: - Pace Tab (Canvas Line Chart)
// ─────────────────────────────────────

@Composable
private fun PaceTab(
    splits: List<SplitData>,
    avgPace: Double,
    modifier: Modifier = Modifier
) {
    if (splits.isEmpty()) {
        EmptyTabPlaceholder(
            icon = Icons.Default.ShowChart,
            message = "No pace data available",
            modifier = modifier
        )
        return
    }

    val textMeasurer = rememberTextMeasurer()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Pace (min/km)",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(ChartBackground)
        ) {
            val padding = 50f
            val chartWidth = size.width - padding * 2
            val chartHeight = size.height - padding * 2

            val paceValues = splits.map { it.paceSecondsPerKm.toFloat() }
            val minPace = paceValues.min() - 30f
            val maxPace = paceValues.max() + 30f
            val paceRange = (maxPace - minPace).coerceAtLeast(60f)

            // Y-axis: pace is inverted (lower pace = faster = higher on chart)
            fun paceToY(pace: Float): Float {
                return padding + (pace - minPace) / paceRange * chartHeight
            }

            fun kmToX(km: Int): Float {
                return padding + (km - 1).toFloat() / (splits.size - 1).coerceAtLeast(1) * chartWidth
            }

            // Grid lines
            val gridColor = Color.White.copy(alpha = 0.08f)
            val gridLabelColor = Color.White.copy(alpha = 0.4f)
            val gridSteps = 4
            for (i in 0..gridSteps) {
                val pace = minPace + paceRange * i / gridSteps
                val y = paceToY(pace)
                drawLine(
                    color = gridColor,
                    start = Offset(padding, y),
                    end = Offset(size.width - padding, y),
                    strokeWidth = 0.5f
                )
                // Y-axis label
                val labelText = formatPace(pace.toDouble())
                val textResult = textMeasurer.measure(
                    text = AnnotatedString(labelText),
                    style = TextStyle(color = gridLabelColor, fontSize = 9.sp)
                )
                drawText(
                    textLayoutResult = textResult,
                    topLeft = Offset(4f, y - textResult.size.height / 2f)
                )
            }

            // X-axis labels
            splits.forEach { split ->
                val x = kmToX(split.kilometer)
                val labelText = "${split.kilometer}"
                val textResult = textMeasurer.measure(
                    text = AnnotatedString(labelText),
                    style = TextStyle(color = gridLabelColor, fontSize = 9.sp)
                )
                drawText(
                    textLayoutResult = textResult,
                    topLeft = Offset(x - textResult.size.width / 2f, size.height - padding + 8f)
                )
            }

            // Average pace dotted line
            val avgPaceY = paceToY(avgPace.toFloat())
            val dashLength = 8f
            val gapLength = 6f
            var dashX = padding
            while (dashX < size.width - padding) {
                val endX = (dashX + dashLength).coerceAtMost(size.width - padding)
                drawLine(
                    color = Color.White.copy(alpha = 0.5f),
                    start = Offset(dashX, avgPaceY),
                    end = Offset(endX, avgPaceY),
                    strokeWidth = 1.5f
                )
                dashX += dashLength + gapLength
            }
            // "Avg" label
            val avgLabel = textMeasurer.measure(
                text = AnnotatedString("Avg"),
                style = TextStyle(color = Color.White.copy(alpha = 0.5f), fontSize = 8.sp)
            )
            drawText(
                textLayoutResult = avgLabel,
                topLeft = Offset(size.width - padding + 4f, avgPaceY - avgLabel.size.height / 2f)
            )

            // Build path for line and fill
            if (splits.size >= 2) {
                val linePath = Path()
                val fillPath = Path()

                val firstX = kmToX(splits.first().kilometer)
                val firstY = paceToY(paceValues.first())
                linePath.moveTo(firstX, firstY)
                fillPath.moveTo(firstX, paceToY(maxPace)) // bottom
                fillPath.lineTo(firstX, firstY)

                for (i in 1 until splits.size) {
                    val x = kmToX(splits[i].kilometer)
                    val y = paceToY(paceValues[i])
                    linePath.lineTo(x, y)
                    fillPath.lineTo(x, y)
                }

                val lastX = kmToX(splits.last().kilometer)
                fillPath.lineTo(lastX, paceToY(maxPace)) // bottom
                fillPath.close()

                // Fill gradient under line
                drawPath(
                    path = fillPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            CyanAccent.copy(alpha = 0.3f),
                            CyanAccent.copy(alpha = 0.02f)
                        ),
                        startY = padding,
                        endY = padding + chartHeight
                    )
                )

                // Line
                drawPath(
                    path = linePath,
                    color = CyanAccent,
                    style = Stroke(
                        width = 2.5f,
                        cap = StrokeCap.Round,
                        join = StrokeJoin.Round
                    )
                )

                // Data points
                splits.forEachIndexed { i, split ->
                    val x = kmToX(split.kilometer)
                    val y = paceToY(paceValues[i])
                    drawCircle(
                        color = Color.White,
                        radius = 4f,
                        center = Offset(x, y)
                    )
                    drawCircle(
                        color = CyanAccent,
                        radius = 2.5f,
                        center = Offset(x, y)
                    )
                }
            }
        }

        // Legend
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Canvas(modifier = Modifier.size(12.dp, 2.dp)) {
                drawLine(
                    color = CyanAccent,
                    start = Offset(0f, size.height / 2),
                    end = Offset(size.width, size.height / 2),
                    strokeWidth = 2f
                )
            }
            Spacer(Modifier.width(6.dp))
            Text(
                "Pace",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.width(16.dp))
            Canvas(modifier = Modifier.size(12.dp, 2.dp)) {
                // Dotted line
                drawLine(
                    color = Color.White.copy(alpha = 0.5f),
                    start = Offset(0f, size.height / 2),
                    end = Offset(4f, size.height / 2),
                    strokeWidth = 1.5f
                )
                drawLine(
                    color = Color.White.copy(alpha = 0.5f),
                    start = Offset(8f, size.height / 2),
                    end = Offset(12f, size.height / 2),
                    strokeWidth = 1.5f
                )
            }
            Spacer(Modifier.width(6.dp))
            Text(
                "Average",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Heart Rate Tab (Canvas Area Chart)
// ─────────────────────────────────────

@Composable
private fun HeartRateTab(
    heartRateData: List<HeartRatePoint>,
    modifier: Modifier = Modifier
) {
    if (heartRateData.isEmpty()) {
        EmptyTabPlaceholder(
            icon = Icons.Default.MonitorHeart,
            message = "No heart rate data recorded for this workout",
            modifier = modifier
        )
        return
    }

    val textMeasurer = rememberTextMeasurer()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Heart Rate (bpm)",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(ChartBackground)
        ) {
            val padding = 50f
            val chartWidth = size.width - padding * 2
            val chartHeight = size.height - padding * 2

            val bpmValues = heartRateData.map { it.bpm.toFloat() }
            val minBpm = (bpmValues.min() - 10f).coerceAtLeast(40f)
            val maxBpm = bpmValues.max() + 10f
            val bpmRange = (maxBpm - minBpm).coerceAtLeast(20f)

            val minTime = heartRateData.first().timestamp.toFloat()
            val maxTime = heartRateData.last().timestamp.toFloat()
            val timeRange = (maxTime - minTime).coerceAtLeast(1f)

            fun bpmToY(bpm: Float): Float {
                return padding + chartHeight - (bpm - minBpm) / bpmRange * chartHeight
            }

            fun timeToX(timestamp: Float): Float {
                return padding + (timestamp - minTime) / timeRange * chartWidth
            }

            // Zone backgrounds
            val zones = listOf(
                Triple(40f, 60f, HrZoneBlue),
                Triple(60f, 100f, HrZoneGreen),
                Triple(100f, 140f, HrZoneYellow),
                Triple(140f, 220f, HrZoneRed)
            )

            zones.forEach { (zoneMin, zoneMax, zoneColor) ->
                val clampedMin = zoneMin.coerceIn(minBpm, maxBpm)
                val clampedMax = zoneMax.coerceIn(minBpm, maxBpm)
                if (clampedMax > clampedMin) {
                    val yTop = bpmToY(clampedMax)
                    val yBottom = bpmToY(clampedMin)
                    drawRect(
                        color = zoneColor.copy(alpha = 0.08f),
                        topLeft = Offset(padding, yTop),
                        size = Size(chartWidth, yBottom - yTop)
                    )
                }
            }

            // Grid lines
            val gridColor = Color.White.copy(alpha = 0.08f)
            val gridLabelColor = Color.White.copy(alpha = 0.4f)
            val bpmSteps = listOf(60f, 80f, 100f, 120f, 140f, 160f, 180f)
            bpmSteps.forEach { bpm ->
                if (bpm in minBpm..maxBpm) {
                    val y = bpmToY(bpm)
                    drawLine(
                        color = gridColor,
                        start = Offset(padding, y),
                        end = Offset(size.width - padding, y),
                        strokeWidth = 0.5f
                    )
                    val textResult = textMeasurer.measure(
                        text = AnnotatedString("${bpm.toInt()}"),
                        style = TextStyle(color = gridLabelColor, fontSize = 9.sp)
                    )
                    drawText(
                        textLayoutResult = textResult,
                        topLeft = Offset(4f, y - textResult.size.height / 2f)
                    )
                }
            }

            // Build the area chart path
            if (heartRateData.size >= 2) {
                // For each segment, draw a filled area colored by HR zone
                for (i in 0 until heartRateData.size - 1) {
                    val p1 = heartRateData[i]
                    val p2 = heartRateData[i + 1]
                    val x1 = timeToX(p1.timestamp.toFloat())
                    val x2 = timeToX(p2.timestamp.toFloat())
                    val y1 = bpmToY(p1.bpm.toFloat())
                    val y2 = bpmToY(p2.bpm.toFloat())
                    val bottomY = bpmToY(minBpm)

                    val avgBpm = (p1.bpm + p2.bpm) / 2f
                    val segmentColor = hrZoneColor(avgBpm)

                    val segmentPath = Path().apply {
                        moveTo(x1, bottomY)
                        lineTo(x1, y1)
                        lineTo(x2, y2)
                        lineTo(x2, bottomY)
                        close()
                    }

                    drawPath(
                        path = segmentPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                segmentColor.copy(alpha = 0.5f),
                                segmentColor.copy(alpha = 0.05f)
                            ),
                            startY = y1.coerceAtMost(y2),
                            endY = bottomY
                        )
                    )
                }

                // Draw the line on top
                val linePath = Path().apply {
                    moveTo(
                        timeToX(heartRateData.first().timestamp.toFloat()),
                        bpmToY(heartRateData.first().bpm.toFloat())
                    )
                    for (i in 1 until heartRateData.size) {
                        lineTo(
                            timeToX(heartRateData[i].timestamp.toFloat()),
                            bpmToY(heartRateData[i].bpm.toFloat())
                        )
                    }
                }

                drawPath(
                    path = linePath,
                    color = Color.White.copy(alpha = 0.8f),
                    style = Stroke(width = 2f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )
            }
        }

        // Zone Legend
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            HrZoneLegendItem(color = HrZoneBlue, label = "<60", zone = "Rest")
            HrZoneLegendItem(color = HrZoneGreen, label = "60-100", zone = "Light")
            HrZoneLegendItem(color = HrZoneYellow, label = "100-140", zone = "Moderate")
            HrZoneLegendItem(color = HrZoneRed, label = ">140", zone = "Intense")
        }
    }
}

@Composable
private fun HrZoneLegendItem(
    color: Color,
    label: String,
    zone: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(color, CircleShape)
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 9.sp
            )
        }
        Text(
            text = zone,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            fontSize = 8.sp
        )
    }
}

private fun hrZoneColor(bpm: Float): Color {
    return when {
        bpm < 60 -> HrZoneBlue
        bpm < 100 -> HrZoneGreen
        bpm < 140 -> HrZoneYellow
        else -> HrZoneRed
    }
}

// ─────────────────────────────────────
// MARK: - Delete Button
// ─────────────────────────────────────

@Composable
private fun DeleteWorkoutButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = RedAccent
        ),
        border = ButtonDefaults.outlinedButtonBorder.copy(
            brush = SolidColor(RedAccent.copy(alpha = 0.5f))
        )
    ) {
        Icon(
            Icons.Outlined.Delete,
            contentDescription = null,
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            "Delete Workout",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold
        )
    }
}

// ─────────────────────────────────────
// MARK: - Empty Tab Placeholder
// ─────────────────────────────────────

@Composable
private fun EmptyTabPlaceholder(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    message: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(40.dp)
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - Formatting Helpers
// ─────────────────────────────────────

private fun formatDuration(seconds: Long): String {
    val hrs = seconds / 3600
    val mins = (seconds % 3600) / 60
    val secs = seconds % 60
    return if (hrs > 0) {
        "%d:%02d:%02d".format(hrs, mins, secs)
    } else {
        "%d:%02d".format(mins, secs)
    }
}

private fun formatPace(secondsPerKm: Double): String {
    val totalSeconds = secondsPerKm.roundToInt()
    val mins = totalSeconds / 60
    val secs = totalSeconds % 60
    return "%d:%02d".format(mins, secs)
}

private fun formatDateTime(isoString: String): String {
    // Simplified formatter: extract date/time from ISO string
    return try {
        val parts = isoString.split("T")
        if (parts.size == 2) {
            val datePart = parts[0] // e.g. "2026-03-03"
            val timePart = parts[1].take(5) // e.g. "07:30"
            val dateParts = datePart.split("-")
            if (dateParts.size == 3) {
                val months = listOf(
                    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
                )
                val monthIndex = (dateParts[1].toIntOrNull() ?: 1) - 1
                val month = months.getOrElse(monthIndex) { "Jan" }
                val day = dateParts[2].toIntOrNull() ?: 1
                "$month $day, ${dateParts[0]} at $timePart"
            } else {
                isoString
            }
        } else {
            isoString
        }
    } catch (_: Exception) {
        isoString
    }
}

// ─────────────────────────────────────
// MARK: - Sample Data Generator
// ─────────────────────────────────────

private fun generateSampleWorkout(id: String): WorkoutDetail {
    // Generate a realistic sample route (a loop around a park)
    val baseLat = 12.9716
    val baseLng = 77.5946
    val routePoints = (0..100).map { i ->
        val angle = i * 0.0628 // ~360 degrees over 100 points
        val radius = 0.005 + 0.001 * kotlin.math.sin(angle * 3) // Slight variation
        RoutePoint(
            latitude = baseLat + radius * kotlin.math.cos(angle),
            longitude = baseLng + radius * kotlin.math.sin(angle),
            altitude = 920.0 + 5.0 * kotlin.math.sin(angle * 2),
            speed = (3.0 + kotlin.math.sin(angle) * 0.5).toFloat(),
            timestamp = System.currentTimeMillis() - (100 - i) * 30000L
        )
    }

    val splits = (1..5).map { km ->
        val basePace = 330L + (km * 5L) + (if (km == 3) -20L else 0L)
        SplitData(
            kilometer = km,
            timeSeconds = basePace,
            paceSecondsPerKm = basePace,
            cumulativeSeconds = (1..km).sumOf { k -> 330L + (k * 5L) + (if (k == 3) -20L else 0L) }
        )
    }

    val heartRateData = (0..60).map { i ->
        HeartRatePoint(
            timestamp = System.currentTimeMillis() - (60 - i) * 60000L,
            bpm = when {
                i < 5 -> 72 + i * 3           // Warmup
                i < 15 -> 85 + i * 2          // Building
                i < 45 -> 120 + (i % 10) * 3  // Steady state with variation
                else -> 140 - (i - 45) * 4    // Cooldown
            }
        )
    }

    return WorkoutDetail(
        id = id,
        type = "run",
        startTime = "2026-03-03T07:30:00Z",
        endTime = "2026-03-03T08:02:00Z",
        durationSeconds = 1920L,
        distanceMeters = 5230.0,
        calories = 420,
        elevationGain = 45.0,
        avgPace = 367.0,
        avgSpeed = 9.8,
        maxSpeed = 12.5,
        routePoints = routePoints,
        splits = splits,
        heartRateData = heartRateData
    )
}
