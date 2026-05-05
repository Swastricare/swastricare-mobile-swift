package com.swastricare.health.ui.screens.runactivity

import android.content.Intent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.OpenInFull
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.AccessTime
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.Landscape
import androidx.compose.material.icons.outlined.Share
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.services.GpxExporter
import com.swastricare.health.data.model.HeartRatePoint
import com.swastricare.health.data.model.RoutePoint
import com.swastricare.health.data.model.SplitData
import com.swastricare.health.data.model.WorkoutDetail
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.ui.components.RouteMapView
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors
import kotlin.math.roundToInt

// ─────────────────────────────────────
// Design tokens (light, clean theme)
// ─────────────────────────────────────

private val CardBorderColor = Color(0xFFE6E8EB)
private val CardSubtleBg = Color(0xFFF8FAFB)
private val SubtleText = Color(0xFF6B7280)
private val FaintText = Color(0xFF9CA3AF)
private val DangerColor = Color(0xFFEF4444)

// HR zone colors (light theme)
private val ZoneRest = Color(0xFF60A5FA)
private val ZoneLight = Color(0xFF34D399)
private val ZoneModerate = Color(0xFFFBBF24)
private val ZoneIntense = Color(0xFFEF4444)
private val ElevationColor = Color(0xFFF59E0B)

// ─────────────────────────────────────
// Activity Detail Screen
// ─────────────────────────────────────

@Composable
fun ActivityDetailScreen(
    workoutId: String,
    onNavigateBack: () -> Unit = {},
    onDelete: (String) -> Unit = {}
) {
    TrackScreen("ActivityDetail")
    val context = LocalContext.current
    val viewModel: ActivityDetailViewModel = hiltViewModel()
    var showDeleteDialog by remember { mutableStateOf(false) }
    var isMapExpanded by remember { mutableStateOf(false) }
    var menuExpanded by remember { mutableStateOf(false) }

    val uiState by viewModel.uiState.collectAsState()
    val workout = uiState.workout
    val isLoading = uiState.isLoading

    LaunchedEffect(workoutId) {
        viewModel.loadActivity(workoutId)
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.White)) {
        when {
            isLoading -> {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AITeal)
                }
            }
            workout == null -> {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        Icons.Default.SearchOff,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = FaintText
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        "Workout not found",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.onBackground
                    )
                }
            }
            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                ) {
                    DetailTopBar(
                        workout = workout,
                        menuExpanded = menuExpanded,
                        onMenuToggle = { menuExpanded = it },
                        onBack = onNavigateBack,
                        onShare = {
                            menuExpanded = false
                            val distanceKm = workout.distanceMeters / 1000.0
                            val duration = formatDuration(workout.durationSeconds)
                            val typeLabel = workout.type.replaceFirstChar { it.uppercase() }
                            val shareText = "Completed a ${"%.2f".format(distanceKm)}km $typeLabel in $duration — SwastriCare"
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                this.type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, shareText)
                            }
                            context.startActivity(Intent.createChooser(intent, "Share Workout"))
                        },
                        onExportGpx = {
                            menuExpanded = false
                            val file = GpxExporter.exportToGpx(
                                context = context,
                                routePoints = workout.routePoints,
                                activityType = workout.type
                            )
                            file?.let { GpxExporter.shareGpxFile(context, it) }
                        },
                        onDeleteRequest = {
                            menuExpanded = false
                            showDeleteDialog = true
                        },
                        hasRoute = workout.routePoints.size >= 2
                    )

                    Spacer(Modifier.height(8.dp))

                    if (workout.routePoints.isNotEmpty()) {
                        MapCard(
                            workout = workout,
                            isExpanded = isMapExpanded,
                            onToggleExpand = { isMapExpanded = !isMapExpanded }
                        )
                        Spacer(Modifier.height(16.dp))
                    }

                    StatsCard(workout = workout)
                    Spacer(Modifier.height(16.dp))

                    val effectiveSplits = remember(workout) { effectiveSplits(workout) }
                    val effectiveAvgPace = remember(workout, effectiveSplits) {
                        if (workout.avgPace > 0) workout.avgPace
                        else effectiveSplits.takeIf { it.isNotEmpty() }
                            ?.map { it.paceSecondsPerKm.toDouble() }?.average() ?: 0.0
                    }

                    if (effectiveSplits.size >= 2) {
                        PaceChartCard(splits = effectiveSplits, avgPace = effectiveAvgPace)
                        Spacer(Modifier.height(16.dp))
                        SplitTimesChartCard(splits = effectiveSplits)
                        Spacer(Modifier.height(16.dp))
                        PaceStatsCard(splits = effectiveSplits, avgPace = effectiveAvgPace)
                        Spacer(Modifier.height(16.dp))
                    }

                    if (effectiveSplits.isNotEmpty()) {
                        SplitsCard(splits = effectiveSplits)
                        Spacer(Modifier.height(16.dp))
                    }

                    if (workout.type == "run" || workout.type == "walk") {
                        CadenceCard(workout = workout, splits = effectiveSplits)
                        Spacer(Modifier.height(16.dp))
                    }

                    if (workout.heartRateData.size >= 2) {
                        HeartRateChartCard(data = workout.heartRateData)
                        Spacer(Modifier.height(16.dp))
                        HeartRateStatsCard(data = workout.heartRateData)
                        Spacer(Modifier.height(16.dp))
                        HeartRateZonesCard(data = workout.heartRateData)
                        Spacer(Modifier.height(16.dp))
                    }

                    if (workout.type == "hike" && hasElevationVariation(workout.routePoints)) {
                        ElevationChartCard(routePoints = workout.routePoints)
                        Spacer(Modifier.height(16.dp))
                    }

                    ActivityDetailsCard(workout = workout)
                    Spacer(Modifier.height(16.dp))

                    NotesCard()
                    Spacer(Modifier.height(40.dp))
                }
            }
        }

        if (showDeleteDialog && workout != null) {
            AlertDialog(
                onDismissRequest = { showDeleteDialog = false },
                title = { Text("Delete Workout") },
                text = { Text("Are you sure you want to delete this workout? This action cannot be undone.") },
                confirmButton = {
                    TextButton(
                        onClick = {
                            showDeleteDialog = false
                            viewModel.deleteActivity(workout.id)
                            onDelete(workout.id)
                            onNavigateBack()
                        },
                        colors = ButtonDefaults.textButtonColors(contentColor = DangerColor)
                    ) { Text("Delete") }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
                },
                containerColor = Color.White
            )
        }
    }
}

// ─────────────────────────────────────
// Top Bar
// ─────────────────────────────────────

@Composable
private fun DetailTopBar(
    workout: WorkoutDetail,
    menuExpanded: Boolean,
    onMenuToggle: (Boolean) -> Unit,
    onBack: () -> Unit,
    onShare: () -> Unit,
    onExportGpx: () -> Unit,
    onDeleteRequest: () -> Unit,
    hasRoute: Boolean
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = AppColors.onBackground
                )
            }
            Spacer(Modifier.weight(1f))
            Box {
                IconButton(onClick = { onMenuToggle(true) }) {
                    Icon(
                        Icons.Default.MoreVert,
                        contentDescription = "More",
                        tint = AppColors.onBackground
                    )
                }
                DropdownMenu(
                    expanded = menuExpanded,
                    onDismissRequest = { onMenuToggle(false) }
                ) {
                    DropdownMenuItem(
                        text = { Text("Share") },
                        onClick = onShare,
                        leadingIcon = { Icon(Icons.Outlined.Share, null, tint = AppColors.onBackground) }
                    )
                    if (hasRoute) {
                        DropdownMenuItem(
                            text = { Text("Export GPX") },
                            onClick = onExportGpx,
                            leadingIcon = { Icon(Icons.Outlined.FileDownload, null, tint = AppColors.onBackground) }
                        )
                    }
                    DropdownMenuItem(
                        text = { Text("Delete", color = DangerColor) },
                        onClick = onDeleteRequest,
                        leadingIcon = { Icon(Icons.Outlined.Delete, null, tint = DangerColor) }
                    )
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Icon(
                imageVector = activityIcon(workout.type),
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(28.dp)
            )
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        workoutTitle(workout),
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onBackground
                    )
                    Spacer(Modifier.width(8.dp))
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = "Rename",
                        tint = FaintText,
                        modifier = Modifier.size(16.dp)
                    )
                }
                Text(
                    formatDateTime(workout.startTime),
                    fontSize = 13.sp,
                    color = SubtleText
                )
            }
        }
    }
}

private fun activityIcon(type: String): ImageVector = when (type) {
    "run" -> Icons.Default.DirectionsRun
    "walk" -> Icons.Default.DirectionsWalk
    "cycle" -> Icons.Default.DirectionsBike
    "hike" -> Icons.Default.Terrain
    else -> Icons.Default.DirectionsRun
}

private fun workoutTitle(workout: WorkoutDetail): String {
    val typeLabel = workout.type.replaceFirstChar { it.uppercase() }
    val hour = parseHourOfDay(workout.startTime) ?: return typeLabel
    val timeOfDay = when (hour) {
        in 5..11 -> "Morning"
        in 12..16 -> "Afternoon"
        in 17..20 -> "Evening"
        else -> "Night"
    }
    return "$timeOfDay $typeLabel"
}

private fun parseHourOfDay(isoString: String): Int? {
    return try {
        val parts = isoString.split("T")
        if (parts.size != 2) return null
        parts[1].take(2).toIntOrNull()
    } catch (_: Exception) {
        null
    }
}

// ─────────────────────────────────────
// Map Card
// ─────────────────────────────────────

@Composable
private fun MapCard(
    workout: WorkoutDetail,
    isExpanded: Boolean,
    onToggleExpand: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .border(1.dp, CardBorderColor, RoundedCornerShape(20.dp))
    ) {
        RouteMapView(
            routePoints = workout.routePoints,
            isLive = false,
            height = if (isExpanded) 360 else 200,
            onExpand = onToggleExpand
        )

        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(10.dp)
                .size(34.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White)
                .clickable { onToggleExpand() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.OpenInFull,
                contentDescription = "Expand map",
                tint = AppColors.onBackground,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// Stats Card (4 columns)
// ─────────────────────────────────────

@Composable
private fun StatsCard(workout: WorkoutDetail) {
    val distanceKm = workout.distanceMeters / 1000.0
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        StatColumn(
            icon = Icons.Default.Straighten,
            value = "%.2f".format(distanceKm),
            unit = "km",
            label = "Distance",
            modifier = Modifier.weight(1f)
        )
        StatDivider()
        StatColumn(
            icon = Icons.Default.Timer,
            value = formatDuration(workout.durationSeconds),
            unit = "min",
            label = "Duration",
            modifier = Modifier.weight(1f)
        )
        StatDivider()
        StatColumn(
            icon = Icons.Default.Speed,
            value = formatPace(workout.avgPace),
            unit = "min/km",
            label = "Avg. Pace",
            modifier = Modifier.weight(1f)
        )
        StatDivider()
        StatColumn(
            icon = Icons.Default.LocalFireDepartment,
            value = "${workout.calories}",
            unit = "kcal",
            label = "Calories",
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun StatColumn(
    icon: ImageVector,
    value: String,
    unit: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AITeal,
            modifier = Modifier.size(18.dp)
        )
        Text(
            value,
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
        Text(unit, fontSize = 11.sp, color = SubtleText)
        Text(label, fontSize = 11.sp, color = FaintText)
    }
}

@Composable
private fun StatDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(48.dp)
            .background(CardBorderColor)
    )
}

// ─────────────────────────────────────
// Pace Chart Card
// ─────────────────────────────────────

@Composable
private fun PaceChartCard(splits: List<SplitData>, avgPace: Double) {
    val textMeasurer = rememberTextMeasurer()
    val paceValues = splits.map { it.paceSecondsPerKm.toFloat() }
    val fastest = paceValues.min()
    val slowest = paceValues.max()
    val displayMin = (fastest - 30f).coerceAtLeast(0f)
    val displayMax = slowest + 30f
    val range = (displayMax - displayMin).coerceAtLeast(60f)

    AnalyticsCard(
        title = "Pace",
        subtitle = "${formatPace(fastest.toDouble())} – ${formatPace(slowest.toDouble())} min/km",
        icon = Icons.Default.Speed
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(CardSubtleBg)
        ) {
            val padLeft = 56f
            val padRight = 16f
            val padTop = 16f
            val padBottom = 28f
            val chartW = size.width - padLeft - padRight
            val chartH = size.height - padTop - padBottom

            fun paceToY(p: Float) = padTop + (p - displayMin) / range * chartH
            fun kmToX(idx: Int) = padLeft + idx.toFloat() / (splits.size - 1).coerceAtLeast(1) * chartW

            val gridColor = CardBorderColor
            val labelStyle = TextStyle(color = FaintText, fontSize = 9.sp)
            for (i in 0..3) {
                val p = displayMin + range * i / 3
                val y = paceToY(p)
                drawLine(gridColor, Offset(padLeft, y), Offset(size.width - padRight, y), 0.5f)
                val text = textMeasurer.measure(AnnotatedString(formatPace(p.toDouble())), labelStyle)
                drawText(text, topLeft = Offset(4f, y - text.size.height / 2f))
            }

            splits.forEachIndexed { i, split ->
                if (i == 0 || i == splits.size - 1 || splits.size <= 8 || i % 2 == 0) {
                    val x = kmToX(i)
                    val text = textMeasurer.measure(
                        AnnotatedString("${split.kilometer}"),
                        labelStyle
                    )
                    drawText(text, topLeft = Offset(x - text.size.width / 2f, size.height - padBottom + 6f))
                }
            }

            // Avg dotted line
            val avgY = paceToY(avgPace.toFloat())
            var dx = padLeft
            while (dx < size.width - padRight) {
                val end = (dx + 6f).coerceAtMost(size.width - padRight)
                drawLine(SubtleText.copy(alpha = 0.5f), Offset(dx, avgY), Offset(end, avgY), 1f)
                dx += 10f
            }

            if (splits.size >= 2) {
                val linePath = Path()
                val fillPath = Path()
                val firstX = kmToX(0)
                val firstY = paceToY(paceValues[0])
                linePath.moveTo(firstX, firstY)
                fillPath.moveTo(firstX, padTop + chartH)
                fillPath.lineTo(firstX, firstY)

                for (i in 1 until splits.size) {
                    val x = kmToX(i)
                    val y = paceToY(paceValues[i])
                    linePath.lineTo(x, y)
                    fillPath.lineTo(x, y)
                }
                fillPath.lineTo(kmToX(splits.size - 1), padTop + chartH)
                fillPath.close()

                drawPath(
                    path = fillPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(AITeal.copy(alpha = 0.25f), AITeal.copy(alpha = 0.02f)),
                        startY = padTop,
                        endY = padTop + chartH
                    )
                )
                drawPath(
                    path = linePath,
                    color = AITeal,
                    style = Stroke(width = 2.5f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )

                splits.forEachIndexed { i, _ ->
                    val cx = kmToX(i)
                    val cy = paceToY(paceValues[i])
                    drawCircle(Color.White, 4f, Offset(cx, cy))
                    drawCircle(AITeal, 2.5f, Offset(cx, cy))
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ChartLegend(label = "Best", value = formatPace(fastest.toDouble()), color = AITeal)
            ChartLegend(label = "Avg", value = formatPace(avgPace), color = SubtleText)
            ChartLegend(label = "Slowest", value = formatPace(slowest.toDouble()), color = SubtleText)
        }
    }
}

// ─────────────────────────────────────
// Pace Stats Card
// ─────────────────────────────────────

@Composable
private fun PaceStatsCard(splits: List<SplitData>, avgPace: Double) {
    val pacesSec = splits.map { it.paceSecondsPerKm.toDouble() }
    val fastest = pacesSec.min()
    val slowest = pacesSec.max()
    val fastestKm = splits.first { it.paceSecondsPerKm.toDouble() == fastest }.kilometer
    val slowestKm = splits.first { it.paceSecondsPerKm.toDouble() == slowest }.kilometer
    val mean = pacesSec.average()
    val variance = pacesSec.map { (it - mean) * (it - mean) }.average()
    val stdDev = kotlin.math.sqrt(variance)
    val range = slowest - fastest

    val firstHalf = splits.take(splits.size / 2)
    val secondHalf = splits.drop(splits.size / 2)
    val firstAvg = firstHalf.map { it.paceSecondsPerKm.toDouble() }.average()
    val secondAvg = if (secondHalf.isNotEmpty())
        secondHalf.map { it.paceSecondsPerKm.toDouble() }.average() else firstAvg
    val splitType = when {
        secondAvg < firstAvg - 5 -> "Negative split"
        secondAvg > firstAvg + 5 -> "Positive split"
        else -> "Even split"
    }

    AnalyticsCard(
        title = "Pace Analysis",
        subtitle = "Per-kilometer breakdown",
        icon = Icons.Default.Speed
    ) {
        StatGrid(
            entries = listOf(
                StatEntry("Best Km", "Km $fastestKm · ${formatPace(fastest)}"),
                StatEntry("Slowest Km", "Km $slowestKm · ${formatPace(slowest)}"),
                StatEntry("Average", "${formatPace(avgPace)} min/km"),
                StatEntry("Range", "${formatPace(range)} min/km"),
                StatEntry("Consistency", "±${formatPace(stdDev)}"),
                StatEntry("Pacing", splitType)
            )
        )
    }
}

// ─────────────────────────────────────
// Split Times Bar Chart
// ─────────────────────────────────────

@Composable
private fun SplitTimesChartCard(splits: List<SplitData>) {
    val textMeasurer = rememberTextMeasurer()
    val times = splits.map { it.timeSeconds.toFloat() }
    val maxTime = times.max()
    val minTime = times.min()
    val totalSeconds = splits.sumOf { it.timeSeconds }
    val avgSeconds = totalSeconds / splits.size

    AnalyticsCard(
        title = "Split Times",
        subtitle = "Time per kilometer",
        icon = Icons.Default.Timer
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(CardSubtleBg)
        ) {
            val padLeft = 48f
            val padRight = 12f
            val padTop = 14f
            val padBottom = 26f
            val chartW = size.width - padLeft - padRight
            val chartH = size.height - padTop - padBottom

            val displayMax = maxTime * 1.1f
            fun timeToY(t: Float) = padTop + chartH - (t / displayMax) * chartH

            val gridColor = CardBorderColor
            val labelStyle = TextStyle(color = FaintText, fontSize = 9.sp)
            for (i in 0..3) {
                val tVal = displayMax * i / 3
                val y = timeToY(tVal)
                drawLine(gridColor, Offset(padLeft, y), Offset(size.width - padRight, y), 0.5f)
                val text = textMeasurer.measure(
                    AnnotatedString(formatDuration(tVal.toLong())),
                    labelStyle
                )
                drawText(text, topLeft = Offset(4f, y - text.size.height / 2f))
            }

            val avgY = timeToY(avgSeconds.toFloat())
            var dx = padLeft
            while (dx < size.width - padRight) {
                val end = (dx + 6f).coerceAtMost(size.width - padRight)
                drawLine(SubtleText.copy(alpha = 0.5f), Offset(dx, avgY), Offset(end, avgY), 1f)
                dx += 10f
            }

            val barCount = splits.size
            val gap = 4f
            val barW = ((chartW - gap * (barCount - 1)) / barCount).coerceAtLeast(2f)
            splits.forEachIndexed { i, split ->
                val x = padLeft + i * (barW + gap)
                val y = timeToY(split.timeSeconds.toFloat())
                val isFastest = split.timeSeconds.toFloat() == minTime
                val isSlowest = split.timeSeconds.toFloat() == maxTime
                val color = when {
                    isFastest -> AITeal
                    isSlowest -> Color(0xFFEF4444).copy(alpha = 0.6f)
                    else -> AITeal.copy(alpha = 0.45f)
                }
                drawRoundRect(
                    color = color,
                    topLeft = Offset(x, y),
                    size = Size(barW, padTop + chartH - y),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f, 3f)
                )

                if (i == 0 || i == splits.size - 1 || splits.size <= 8 || i % 2 == 0) {
                    val text = textMeasurer.measure(
                        AnnotatedString("${split.kilometer}"),
                        labelStyle
                    )
                    drawText(
                        text,
                        topLeft = Offset(x + barW / 2f - text.size.width / 2f, size.height - padBottom + 6f)
                    )
                }
            }
        }

        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ChartLegend("Fastest", formatDuration(minTime.toLong()), AITeal)
            ChartLegend("Avg", formatDuration(avgSeconds), SubtleText)
            ChartLegend("Slowest", formatDuration(maxTime.toLong()), Color(0xFFEF4444))
        }
    }
}

// ─────────────────────────────────────
// Splits Card
// ─────────────────────────────────────

@Composable
private fun SplitsCard(splits: List<SplitData>) {
    var showAll by remember { mutableStateOf(splits.size <= 6) }
    val visibleSplits = if (showAll) splits else splits.take(6)
    val fastestPace = splits.minOf { it.paceSecondsPerKm }
    val slowestPace = splits.maxOf { it.paceSecondsPerKm }
    val paceRange = (slowestPace - fastestPace).coerceAtLeast(1L)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Splits",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onBackground,
                modifier = Modifier.weight(1f)
            )
            if (splits.size > 6) {
                Text(
                    if (showAll) "Show less" else "View all",
                    fontSize = 13.sp,
                    color = AITeal,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.clickable { showAll = !showAll }
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        Row(modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp)) {
            Text("#", fontSize = 11.sp, color = FaintText, modifier = Modifier.width(28.dp))
            Text("PACE", fontSize = 11.sp, color = FaintText, modifier = Modifier.width(72.dp))
            Spacer(Modifier.weight(1f))
            Text("TIME", fontSize = 11.sp, color = FaintText)
        }

        visibleSplits.forEach { split ->
            val barFraction = 1f - (split.paceSecondsPerKm - fastestPace).toFloat() / paceRange
            val finalFraction = (0.25f + 0.75f * barFraction).coerceIn(0.2f, 1f)
            val isFastest = split.paceSecondsPerKm == fastestPace
            SplitRow(
                index = split.kilometer,
                pace = formatPace(split.paceSecondsPerKm.toDouble()),
                time = formatDuration(split.cumulativeSeconds),
                barFraction = finalFraction,
                highlight = isFastest
            )
        }
    }
}

@Composable
private fun SplitRow(
    index: Int,
    pace: String,
    time: String,
    barFraction: Float,
    highlight: Boolean
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "$index",
            fontSize = 13.sp,
            color = AppColors.onBackground,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.width(28.dp)
        )
        Text(
            "$pace min/km",
            fontSize = 12.sp,
            color = if (highlight) AITeal else SubtleText,
            fontWeight = if (highlight) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.width(72.dp)
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 8.dp)
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color(0xFFEEF2F4))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(barFraction)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(4.dp))
                    .background(AITeal)
            )
        }
        Text(
            time,
            fontSize = 12.sp,
            color = AppColors.onBackground,
            fontWeight = FontWeight.Medium
        )
    }
}

// ─────────────────────────────────────
// Heart Rate Chart Card
// ─────────────────────────────────────

@Composable
private fun HeartRateChartCard(data: List<HeartRatePoint>) {
    val textMeasurer = rememberTextMeasurer()
    val bpms = data.map { it.bpm.toFloat() }
    val minBpm = (bpms.min() - 5f).coerceAtLeast(40f)
    val maxBpm = bpms.max() + 5f
    val range = (maxBpm - minBpm).coerceAtLeast(20f)
    val avgBpm = (bpms.sum() / bpms.size).roundToInt()
    val peakBpm = bpms.max().roundToInt()
    val minBpmInt = bpms.min().roundToInt()
    val minTime = data.first().timestamp.toFloat()
    val maxTime = data.last().timestamp.toFloat()
    val timeRange = (maxTime - minTime).coerceAtLeast(1f)

    AnalyticsCard(
        title = "Heart Rate",
        subtitle = "$avgBpm bpm avg · peak $peakBpm bpm",
        icon = Icons.Outlined.FavoriteBorder
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(CardSubtleBg)
        ) {
            val padLeft = 40f
            val padRight = 16f
            val padTop = 12f
            val padBottom = 22f
            val chartW = size.width - padLeft - padRight
            val chartH = size.height - padTop - padBottom

            fun bpmToY(b: Float) = padTop + chartH - (b - minBpm) / range * chartH
            fun timeToX(t: Float) = padLeft + (t - minTime) / timeRange * chartW

            // Zone bands
            val zones = listOf(
                Triple(40f, 60f, ZoneRest),
                Triple(60f, 100f, ZoneLight),
                Triple(100f, 140f, ZoneModerate),
                Triple(140f, 220f, ZoneIntense)
            )
            zones.forEach { (zMin, zMax, color) ->
                val cMin = zMin.coerceIn(minBpm, maxBpm)
                val cMax = zMax.coerceIn(minBpm, maxBpm)
                if (cMax > cMin) {
                    val yTop = bpmToY(cMax)
                    val yBot = bpmToY(cMin)
                    drawRect(
                        color = color.copy(alpha = 0.10f),
                        topLeft = Offset(padLeft, yTop),
                        size = Size(chartW, yBot - yTop)
                    )
                }
            }

            val gridColor = CardBorderColor
            val labelStyle = TextStyle(color = FaintText, fontSize = 9.sp)
            listOf(60, 100, 140, 180).forEach { bpm ->
                if (bpm.toFloat() in minBpm..maxBpm) {
                    val y = bpmToY(bpm.toFloat())
                    drawLine(gridColor, Offset(padLeft, y), Offset(size.width - padRight, y), 0.5f)
                    val text = textMeasurer.measure(AnnotatedString("$bpm"), labelStyle)
                    drawText(text, topLeft = Offset(4f, y - text.size.height / 2f))
                }
            }

            if (data.size >= 2) {
                val linePath = Path()
                val fillPath = Path()
                val first = data.first()
                val firstX = timeToX(first.timestamp.toFloat())
                val firstY = bpmToY(first.bpm.toFloat())
                linePath.moveTo(firstX, firstY)
                fillPath.moveTo(firstX, padTop + chartH)
                fillPath.lineTo(firstX, firstY)

                for (i in 1 until data.size) {
                    val x = timeToX(data[i].timestamp.toFloat())
                    val y = bpmToY(data[i].bpm.toFloat())
                    linePath.lineTo(x, y)
                    fillPath.lineTo(x, y)
                }
                val lastX = timeToX(data.last().timestamp.toFloat())
                fillPath.lineTo(lastX, padTop + chartH)
                fillPath.close()

                drawPath(
                    path = fillPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(DangerColor.copy(alpha = 0.25f), DangerColor.copy(alpha = 0.02f)),
                        startY = padTop,
                        endY = padTop + chartH
                    )
                )
                drawPath(
                    path = linePath,
                    color = DangerColor,
                    style = Stroke(width = 2.5f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ChartLegend("Min", "$minBpmInt bpm", SubtleText)
            ChartLegend("Avg", "$avgBpm bpm", DangerColor)
            ChartLegend("Peak", "$peakBpm bpm", DangerColor)
        }
    }
}

// ─────────────────────────────────────
// Heart Rate Stats Card
// ─────────────────────────────────────

@Composable
private fun HeartRateStatsCard(data: List<HeartRatePoint>) {
    val bpms = data.map { it.bpm }
    val avg = bpms.average().roundToInt()
    val peak = bpms.max()
    val low = bpms.min()
    val mean = bpms.average()
    val variance = bpms.map { (it - mean) * (it - mean) }.average()
    val stdDev = kotlin.math.sqrt(variance).roundToInt()

    val zoneSeconds = computeZoneTime(data)
    val total = zoneSeconds.values.sum().coerceAtLeast(1L)
    val moderateOrHigher = (zoneSeconds["moderate"] ?: 0L) + (zoneSeconds["intense"] ?: 0L)
    val activePct = (moderateOrHigher.toFloat() / total * 100).roundToInt()

    AnalyticsCard(
        title = "Heart Rate Stats",
        subtitle = "Effort and intensity",
        icon = Icons.Outlined.FavoriteBorder
    ) {
        StatGrid(
            entries = listOf(
                StatEntry("Average", "$avg bpm"),
                StatEntry("Peak", "$peak bpm"),
                StatEntry("Lowest", "$low bpm"),
                StatEntry("Variability", "±$stdDev bpm"),
                StatEntry("Active Time", "$activePct%"),
                StatEntry("Samples", "${data.size}")
            )
        )
    }
}

// ─────────────────────────────────────
// Heart Rate Zones Card
// ─────────────────────────────────────

@Composable
private fun HeartRateZonesCard(data: List<HeartRatePoint>) {
    val zoneSeconds = computeZoneTime(data)
    val total = zoneSeconds.values.sum().coerceAtLeast(1L)

    AnalyticsCard(
        title = "Heart Rate Zones",
        subtitle = "Time spent in each zone",
        icon = Icons.Outlined.FavoriteBorder
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ZoneBar("Intense", ">140 bpm", zoneSeconds["intense"] ?: 0L, total, ZoneIntense)
            ZoneBar("Moderate", "100–140", zoneSeconds["moderate"] ?: 0L, total, ZoneModerate)
            ZoneBar("Light", "60–100", zoneSeconds["light"] ?: 0L, total, ZoneLight)
            ZoneBar("Rest", "<60", zoneSeconds["rest"] ?: 0L, total, ZoneRest)
        }
    }
}

@Composable
private fun ZoneBar(
    label: String,
    range: String,
    seconds: Long,
    total: Long,
    color: Color
) {
    val frac = (seconds.toFloat() / total).coerceIn(0f, 1f)
    val percent = (frac * 100).roundToInt()
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(color, CircleShape)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                label,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onBackground,
                modifier = Modifier.weight(1f)
            )
            Text(
                "$percent% · ${formatDuration(seconds)}",
                fontSize = 12.sp,
                color = SubtleText
            )
        }
        Spacer(Modifier.height(4.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .padding(start = 16.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color(0xFFEEF2F4))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(frac)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(4.dp))
                    .background(color)
            )
        }
    }
}

private fun computeZoneTime(data: List<HeartRatePoint>): Map<String, Long> {
    if (data.size < 2) return emptyMap()
    val totals = mutableMapOf("rest" to 0L, "light" to 0L, "moderate" to 0L, "intense" to 0L)
    for (i in 0 until data.size - 1) {
        val a = data[i]
        val b = data[i + 1]
        val deltaSeconds = ((b.timestamp - a.timestamp) / 1000L).coerceAtLeast(0L)
        val avgBpm = (a.bpm + b.bpm) / 2
        val zone = when {
            avgBpm < 60 -> "rest"
            avgBpm < 100 -> "light"
            avgBpm < 140 -> "moderate"
            else -> "intense"
        }
        totals[zone] = (totals[zone] ?: 0L) + deltaSeconds
    }
    return totals
}

// ─────────────────────────────────────
// Elevation Chart Card
// ─────────────────────────────────────

private fun hasElevationVariation(routePoints: List<RoutePoint>): Boolean {
    if (routePoints.size < 2) return false
    val altitudes = routePoints.map { it.altitude }
    return (altitudes.max() - altitudes.min()) > 1.0
}

@Composable
private fun ElevationChartCard(routePoints: List<RoutePoint>) {
    val textMeasurer = rememberTextMeasurer()
    val altitudes = routePoints.map { it.altitude.toFloat() }
    val minAlt = altitudes.min()
    val maxAlt = altitudes.max()
    val range = (maxAlt - minAlt).coerceAtLeast(1f)
    val gain = routePoints.zipWithNext { a, b -> (b.altitude - a.altitude).coerceAtLeast(0.0) }.sum()
    val loss = routePoints.zipWithNext { a, b -> (a.altitude - b.altitude).coerceAtLeast(0.0) }.sum()

    AnalyticsCard(
        title = "Elevation",
        subtitle = "+${gain.roundToInt()} m / −${loss.roundToInt()} m",
        icon = Icons.Outlined.Landscape
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(CardSubtleBg)
        ) {
            val padLeft = 44f
            val padRight = 12f
            val padTop = 12f
            val padBottom = 16f
            val chartW = size.width - padLeft - padRight
            val chartH = size.height - padTop - padBottom

            fun altToY(a: Float) = padTop + chartH - (a - minAlt) / range * chartH
            fun idxToX(i: Int) = padLeft + i.toFloat() / (altitudes.size - 1).coerceAtLeast(1) * chartW

            val gridColor = CardBorderColor
            val labelStyle = TextStyle(color = FaintText, fontSize = 9.sp)
            for (i in 0..2) {
                val a = minAlt + range * i / 2
                val y = altToY(a)
                drawLine(gridColor, Offset(padLeft, y), Offset(size.width - padRight, y), 0.5f)
                val text = textMeasurer.measure(AnnotatedString("${a.roundToInt()}m"), labelStyle)
                drawText(text, topLeft = Offset(4f, y - text.size.height / 2f))
            }

            if (altitudes.size >= 2) {
                val linePath = Path()
                val fillPath = Path()
                linePath.moveTo(idxToX(0), altToY(altitudes[0]))
                fillPath.moveTo(idxToX(0), padTop + chartH)
                fillPath.lineTo(idxToX(0), altToY(altitudes[0]))
                for (i in 1 until altitudes.size) {
                    val x = idxToX(i)
                    val y = altToY(altitudes[i])
                    linePath.lineTo(x, y)
                    fillPath.lineTo(x, y)
                }
                fillPath.lineTo(idxToX(altitudes.size - 1), padTop + chartH)
                fillPath.close()

                drawPath(
                    path = fillPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(ElevationColor.copy(alpha = 0.30f), ElevationColor.copy(alpha = 0.02f)),
                        startY = padTop,
                        endY = padTop + chartH
                    )
                )
                drawPath(
                    path = linePath,
                    color = ElevationColor,
                    style = Stroke(width = 2f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ChartLegend("Min", "${minAlt.roundToInt()} m", SubtleText)
            ChartLegend("Max", "${maxAlt.roundToInt()} m", SubtleText)
            ChartLegend("Gain", "${gain.roundToInt()} m", ElevationColor)
        }
    }
}

// ─────────────────────────────────────
// Cadence Card
// ─────────────────────────────────────

@Composable
private fun CadenceCard(workout: WorkoutDetail, splits: List<SplitData>) {
    val durationMinutes = workout.durationSeconds / 60.0
    val knownCadence = workout.totalSteps > 0 && durationMinutes > 0
    val avgCadence = when {
        knownCadence -> (workout.totalSteps / durationMinutes).roundToInt()
        // Estimate from pace using a typical 0.95m stride
        workout.avgPace > 0 -> ((60.0 / workout.avgPace) * (1000.0 / 0.95)).roundToInt()
        else -> 0
    }
    val distanceMeters = workout.distanceMeters
    val strideMeters = when {
        knownCadence -> distanceMeters / workout.totalSteps
        avgCadence > 0 && durationMinutes > 0 -> distanceMeters / (avgCadence * durationMinutes)
        else -> 0.0
    }

    AnalyticsCard(
        title = "Cadence & Stride",
        subtitle = when {
            knownCadence -> "$avgCadence steps/min average"
            avgCadence > 0 -> "≈ $avgCadence spm (estimated from pace)"
            else -> "Not tracked"
        },
        icon = Icons.Default.DirectionsRun
    ) {
        if (avgCadence == 0) {
            Text(
                "Cadence wasn't recorded for this workout. Enable step tracking during your next run to see step-per-minute insights.",
                fontSize = 12.sp,
                color = SubtleText
            )
        } else {
            CadenceBars(splits = splits, avgCadence = avgCadence)
            Spacer(Modifier.height(12.dp))
            StatGrid(
                entries = listOf(
                    StatEntry("Avg Cadence", "$avgCadence spm"),
                    StatEntry("Total Steps", "${workout.totalSteps}"),
                    StatEntry("Stride Length", "%.2f m".format(strideMeters)),
                    StatEntry(
                        "Form Quality",
                        when {
                            avgCadence >= 175 -> "Excellent"
                            avgCadence >= 165 -> "Good"
                            avgCadence >= 150 -> "Fair"
                            else -> "Below ideal"
                        }
                    )
                )
            )
        }
    }
}

@Composable
private fun CadenceBars(splits: List<SplitData>, avgCadence: Int) {
    val textMeasurer = rememberTextMeasurer()
    val cadences = splits.map { split ->
        // Approximate per-km cadence using pace-ratio scaling around the avg.
        val avgPace = splits.map { it.paceSecondsPerKm }.average()
        val ratio = if (split.paceSecondsPerKm > 0) avgPace / split.paceSecondsPerKm else 1.0
        (avgCadence * ratio).coerceIn(120.0, 220.0).toFloat()
    }
    val maxC = cadences.max()
    val minC = cadences.min()
    val displayMin = (minC - 5f).coerceAtLeast(120f)
    val displayMax = maxC + 5f
    val range = (displayMax - displayMin).coerceAtLeast(10f)

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(140.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(CardSubtleBg)
    ) {
        val padLeft = 44f
        val padRight = 12f
        val padTop = 12f
        val padBottom = 22f
        val chartW = size.width - padLeft - padRight
        val chartH = size.height - padTop - padBottom

        fun cadToY(c: Float) = padTop + chartH - (c - displayMin) / range * chartH

        val gridColor = CardBorderColor
        val labelStyle = TextStyle(color = FaintText, fontSize = 9.sp)
        for (i in 0..2) {
            val cVal = displayMin + range * i / 2
            val y = cadToY(cVal)
            drawLine(gridColor, Offset(padLeft, y), Offset(size.width - padRight, y), 0.5f)
            val text = textMeasurer.measure(AnnotatedString("${cVal.roundToInt()}"), labelStyle)
            drawText(text, topLeft = Offset(4f, y - text.size.height / 2f))
        }

        val avgY = cadToY(avgCadence.toFloat())
        var dx = padLeft
        while (dx < size.width - padRight) {
            val end = (dx + 6f).coerceAtMost(size.width - padRight)
            drawLine(SubtleText.copy(alpha = 0.5f), Offset(dx, avgY), Offset(end, avgY), 1f)
            dx += 10f
        }

        val barCount = cadences.size
        val gap = 4f
        val barW = ((chartW - gap * (barCount - 1)) / barCount).coerceAtLeast(2f)
        cadences.forEachIndexed { i, c ->
            val x = padLeft + i * (barW + gap)
            val y = cadToY(c)
            drawRoundRect(
                color = AITeal.copy(alpha = 0.7f),
                topLeft = Offset(x, y),
                size = Size(barW, padTop + chartH - y),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f, 3f)
            )
        }
    }
}

// ─────────────────────────────────────
// Activity Details Card
// ─────────────────────────────────────

@Composable
private fun ActivityDetailsCard(workout: WorkoutDetail) {
    val typeLabel = workout.type.replaceFirstChar { it.uppercase() }
    val avgSpeedText = if (workout.avgSpeed > 0) "%.1f km/h".format(workout.avgSpeed) else "—"
    val elevationText = if (workout.elevationGain > 0) "${workout.elevationGain.roundToInt()} m" else "—"
    val terrain = terrainLabel(workout.elevationGain, workout.distanceMeters)
    val startedText = formatTimeOnly(workout.startTime)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Text(
            "Activity Details",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onBackground
        )
        Spacer(Modifier.height(8.dp))
        DetailRow(icon = activityIcon(workout.type), label = "Activity Type", value = typeLabel)
        DetailRow(icon = Icons.Default.Speed, label = "Avg. Speed", value = avgSpeedText)
        DetailRow(icon = Icons.Outlined.Landscape, label = "Terrain", value = terrain)
        DetailRow(icon = Icons.Outlined.AccessTime, label = "Started", value = startedText)
        DetailRow(
            icon = Icons.Default.Terrain,
            label = "Elevation Gain",
            value = elevationText,
            isLast = true
        )
    }
}

@Composable
private fun DetailRow(
    icon: ImageVector,
    label: String,
    value: String,
    isLast: Boolean = false
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AITeal,
            modifier = Modifier.size(20.dp)
        )
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            fontSize = 14.sp,
            color = AppColors.onBackground,
            modifier = Modifier.weight(1f)
        )
        Text(
            value,
            fontSize = 14.sp,
            color = SubtleText,
            fontWeight = FontWeight.Medium
        )
    }
    if (!isLast) {
        HorizontalDivider(
            color = CardBorderColor.copy(alpha = 0.6f),
            thickness = 0.5.dp,
            modifier = Modifier.padding(start = 32.dp)
        )
    }
}

private fun terrainLabel(elevationGain: Double, distanceMeters: Double): String {
    if (distanceMeters <= 0) return "—"
    val gainPerKm = elevationGain / (distanceMeters / 1000.0)
    return when {
        gainPerKm < 5 -> "Mostly Flat"
        gainPerKm < 15 -> "Rolling"
        gainPerKm < 30 -> "Hilly"
        else -> "Mountainous"
    }
}

private fun formatTimeOnly(isoString: String): String {
    return try {
        val parts = isoString.split("T")
        if (parts.size != 2) return "—"
        val time = parts[1].take(5)
        val (hourStr, minuteStr) = time.split(":")
        val hour = hourStr.toIntOrNull() ?: return time
        val minute = minuteStr.toIntOrNull() ?: return time
        val suffix = if (hour < 12) "AM" else "PM"
        val display = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        "%d:%02d %s".format(display, minute, suffix)
    } catch (_: Exception) {
        "—"
    }
}

// ─────────────────────────────────────
// Notes Card
// ─────────────────────────────────────

@Composable
private fun NotesCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Text(
            "Notes",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onBackground
        )
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "How did it go?",
                fontSize = 13.sp,
                color = FaintText,
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Default.Edit,
                contentDescription = null,
                tint = FaintText,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// Shared Building Blocks
// ─────────────────────────────────────

@Composable
private fun AnalyticsCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = AITeal, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    title,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground
                )
                Text(subtitle, fontSize = 12.sp, color = SubtleText)
            }
        }
        Spacer(Modifier.height(12.dp))
        content()
    }
}

@Composable
private fun ChartLegend(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, fontSize = 10.sp, color = FaintText)
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = color)
    }
}

private data class StatEntry(val label: String, val value: String)

@Composable
private fun StatGrid(entries: List<StatEntry>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        entries.chunked(2).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                row.forEach { entry ->
                    StatTile(entry = entry, modifier = Modifier.weight(1f))
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun StatTile(entry: StatEntry, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(CardSubtleBg)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            entry.label,
            fontSize = 11.sp,
            color = FaintText
        )
        Text(
            entry.value,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onBackground
        )
    }
}

// ─────────────────────────────────────
// Formatting Helpers
// ─────────────────────────────────────

private fun effectiveSplits(workout: WorkoutDetail): List<SplitData> {
    if (workout.splits.isNotEmpty()) return workout.splits
    if (workout.distanceMeters <= 0 || workout.durationSeconds <= 0) return emptyList()

    val totalKm = workout.distanceMeters / 1000.0
    val avgPace = workout.durationSeconds / totalKm
    val fullKm = totalKm.toInt()

    if (fullKm < 1) {
        // Short workout — split duration into halves so charts can render.
        val halfTime = workout.durationSeconds / 2
        return listOf(
            SplitData(1, halfTime, avgPace.toLong(), halfTime),
            SplitData(2, workout.durationSeconds - halfTime, avgPace.toLong(), workout.durationSeconds)
        )
    }

    val splits = (1..fullKm).map { km ->
        SplitData(
            kilometer = km,
            timeSeconds = avgPace.toLong(),
            paceSecondsPerKm = avgPace.toLong(),
            cumulativeSeconds = (avgPace * km).toLong()
        )
    }
    val remainder = totalKm - fullKm
    return if (remainder > 0.05) {
        splits + SplitData(
            kilometer = fullKm + 1,
            timeSeconds = (avgPace * remainder).toLong(),
            paceSecondsPerKm = avgPace.toLong(),
            cumulativeSeconds = workout.durationSeconds
        )
    } else splits
}

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
    return try {
        val parts = isoString.split("T")
        if (parts.size != 2) return isoString
        val datePart = parts[0]
        val timePart = parts[1].take(5)
        val dateParts = datePart.split("-")
        if (dateParts.size != 3) return isoString
        val months = listOf(
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        )
        val monthIndex = (dateParts[1].toIntOrNull() ?: 1) - 1
        val month = months.getOrElse(monthIndex) { "Jan" }
        val day = dateParts[2].toIntOrNull() ?: 1
        val (hourStr, minuteStr) = timePart.split(":")
        val hour = hourStr.toIntOrNull() ?: 0
        val minute = minuteStr.toIntOrNull() ?: 0
        val suffix = if (hour < 12) "AM" else "PM"
        val display = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        "$month $day, ${dateParts[0]} at %d:%02d %s".format(display, minute, suffix)
    } catch (_: Exception) {
        isoString
    }
}

// ─────────────────────────────────────
// RunActivity → WorkoutDetail Conversion
// ─────────────────────────────────────

private fun RunActivity.toWorkoutDetail(): WorkoutDetail {
    val formatter = java.time.format.DateTimeFormatter.ISO_LOCAL_DATE_TIME
    return WorkoutDetail(
        id = id,
        type = activityType.dbValue,
        startTime = startTime?.format(formatter) ?: "",
        endTime = endTime?.format(formatter) ?: "",
        durationSeconds = durationSeconds,
        distanceMeters = distanceMeters,
        calories = caloriesBurned,
        elevationGain = routeCoordinates.zipWithNext { a, b ->
            val diff = b.altitude - a.altitude
            if (diff > 0) diff else 0.0
        }.sum(),
        avgPace = avgPaceSecondsPerKm.toDouble(),
        avgSpeed = if (durationSeconds > 0) (distanceMeters / 1000.0) / (durationSeconds / 3600.0) else 0.0,
        maxSpeed = 0.0,
        routePoints = routeCoordinates.map { coord ->
            RoutePoint(
                latitude = coord.latitude,
                longitude = coord.longitude,
                altitude = coord.altitude,
                speed = 0f,
                timestamp = coord.timestamp
            )
        },
        splits = splits.map { split ->
            SplitData(
                kilometer = split.kilometer,
                timeSeconds = split.timeSeconds,
                paceSecondsPerKm = split.paceSecondsPerKm,
                cumulativeSeconds = split.timeSeconds * split.kilometer
            )
        }
    )
}
