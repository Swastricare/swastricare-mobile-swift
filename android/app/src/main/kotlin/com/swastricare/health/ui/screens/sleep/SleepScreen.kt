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
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.model.sleep.SleepStageType
import com.swastricare.health.domain.model.sleep.SleepStats
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SleepColor
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

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

    // Re-fetch when the screen regains focus (e.g. returning from LogSleepScreen)
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            SleepTopBar(onNavigateBack = onNavigateBack)

            when {
                uiState.isLoading -> SleepSkeletonContent()
                uiState.todaySession == null && uiState.sleepHistory.isEmpty() ->
                    EmptySleepContent(onLogSleep = onNavigateToLog)
                else -> SleepContent(
                    uiState = uiState,
                    onRangeSelected = { viewModel.selectTimeRange(it) },
                    onDateSelected = { viewModel.selectDate(it) }
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
    onRangeSelected: (SleepTimeRange) -> Unit,
    onDateSelected: (LocalDate) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        // Date header + week strip
        item {
            Spacer(Modifier.height(4.dp))
            SleepDateHeader(
                selectedDate = uiState.selectedDate,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(12.dp))
            SleepWeekStrip(
                selectedDate = uiState.selectedDate,
                sessionsByDate = uiState.sleepHistory.associateBy { it.date } +
                    (uiState.todaySession?.let { mapOf(it.date to it) } ?: emptyMap()),
                onDateSelected = onDateSelected,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Circular sleep clock
        item {
            Spacer(Modifier.height(20.dp))
            SleepClockCard(
                session = uiState.selectedSession,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Duration section
        item {
            Spacer(Modifier.height(20.dp))
            SleepSectionLabel(
                text = "Duration",
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(8.dp))
            SleepDurationRow(
                session = uiState.selectedSession,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(10.dp))
            SleepTwoUpStatRow(
                session = uiState.selectedSession,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Efficiency section
        item {
            Spacer(Modifier.height(20.dp))
            SleepSectionLabel(
                text = "Efficiency",
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(8.dp))
            SleepEfficiencyRow(
                session = uiState.selectedSession,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Sleep stages breakdown (only for days with stage data)
        uiState.selectedSession?.takeIf { it.hasStageData }?.let { session ->
            item {
                Spacer(Modifier.height(20.dp))
                SleepStagesCard(
                    session = session,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }

        // Time range selector
        item {
            Spacer(Modifier.height(20.dp))
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
// MARK: - Date Header + Week Strip
// ─────────────────────────────────────

@Composable
private fun SleepDateHeader(
    selectedDate: LocalDate,
    modifier: Modifier = Modifier
) {
    val weekday = selectedDate.format(DateTimeFormatter.ofPattern("EEEE"))
    val dateStr = selectedDate.format(DateTimeFormatter.ofPattern("d MMMM yyyy"))
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(
            weekday,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Text(
            dateStr,
            style = MaterialTheme.typography.labelMedium,
            color = AppColors.onSurfaceVariant
        )
    }
}

@Composable
private fun SleepWeekStrip(
    selectedDate: LocalDate,
    sessionsByDate: Map<LocalDate, SleepSession>,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
    val dayFmt = DateTimeFormatter.ofPattern("EEE")

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        days.forEach { date ->
            val isSelected = date == selectedDate
            val hasData = sessionsByDate.containsKey(date)
            val isFuture = date.isAfter(today)

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .clip(RoundedCornerShape(14.dp))
                    .clickable(enabled = !isFuture) { onDateSelected(date) }
                    .padding(horizontal = 6.dp, vertical = 4.dp)
            ) {
                Text(
                    text = date.format(dayFmt),
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(if (isSelected) SleepColor else Color.Transparent),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = date.dayOfMonth.toString(),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        color = when {
                            isSelected -> Color.White
                            isFuture -> AppColors.onSurfaceVariant.copy(alpha = 0.4f)
                            hasData -> AppColors.onSurface
                            else -> AppColors.onSurfaceVariant
                        }
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Circular Sleep Clock
// ─────────────────────────────────────

@Composable
private fun SleepClockCard(
    session: SleepSession?,
    modifier: Modifier = Modifier
) {
    var isVisible by remember(session) { mutableStateOf(false) }
    LaunchedEffect(session) {
        delay(150)
        isVisible = true
    }

    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(900, easing = FastOutSlowInEasing),
        label = "clockProgress"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 24.dp)
            .padding(vertical = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        SleepClockDial(
            session = session,
            animatedProgress = animatedProgress,
            modifier = Modifier.size(260.dp)
        )
    }
}

@Composable
private fun SleepClockDial(
    session: SleepSession?,
    animatedProgress: Float,
    modifier: Modifier = Modifier
) {
    val trackColor = AppColors.outlineVariant.copy(alpha = 0.5f)
    val tickColor = AppColors.onSurfaceVariant
    val labelColor = AppColors.onSurfaceVariant.copy(alpha = 0.7f)
    val centerLabel = AppColors.onSurfaceVariant
    val centerValue = AppColors.onSurface

    val moonBg = Color(0xFF7C3AED)
    val sunBg = Color(0xFFF59E0B)

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeWidth = 18.dp.toPx()
            val radius = min(size.width, size.height) / 2f - strokeWidth / 2f - 4.dp.toPx()
            val center = Offset(size.width / 2f, size.height / 2f)

            // Track ring
            drawCircle(
                color = trackColor,
                radius = radius,
                center = center,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )

            // Sleep arc (bedtime -> wake)
            val bed = session?.bedtime
            val wake = session?.wakeTime
            if (bed != null && wake != null && session.totalMinutes > 0) {
                val bedAngleDeg = timeToAngleDegrees(bed)
                val wakeAngleDeg = timeToAngleDegrees(wake)
                var sweep = (wakeAngleDeg - bedAngleDeg + 360f) % 360f
                if (sweep == 0f) sweep = 360f
                val animatedSweep = sweep * animatedProgress

                drawArc(
                    brush = Brush.sweepGradient(
                        colors = listOf(
                            Color(0xFF7C3AED),
                            Color(0xFFA78BFA),
                            Color(0xFFC4B5FD),
                            Color(0xFF7C3AED)
                        ),
                        center = center
                    ),
                    startAngle = bedAngleDeg - 90f,
                    sweepAngle = animatedSweep,
                    useCenter = false,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = Size(radius * 2f, radius * 2f),
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                )
            }

            // Major tick labels: 12, 3, 6, 9
            val tickRadius = radius - strokeWidth / 2f - 18.dp.toPx()
            val tickTextSizePx = 11.sp.toPx()
            val paint = android.graphics.Paint().apply {
                color = labelColor.toArgb()
                textSize = tickTextSizePx
                textAlign = android.graphics.Paint.Align.CENTER
                isAntiAlias = true
            }
            val labels = listOf(0 to "12", 90 to "3", 180 to "6", 270 to "9")
            labels.forEach { (deg, label) ->
                val rad = Math.toRadians((deg - 90).toDouble())
                val x = center.x + tickRadius * cos(rad).toFloat()
                val y = center.y + tickRadius * sin(rad).toFloat() + tickTextSizePx / 3f
                drawContext.canvas.nativeCanvas.drawText(label, x, y, paint)
            }

            // Minor tick marks around the dial (every 30°, skipping label positions)
            val innerTickR = radius - strokeWidth / 2f - 4.dp.toPx()
            val outerTickR = radius - strokeWidth / 2f - 1.dp.toPx()
            for (i in 0 until 12) {
                if (i % 3 == 0) continue
                val angle = Math.toRadians((i * 30 - 90).toDouble())
                val start = Offset(
                    center.x + innerTickR * cos(angle).toFloat(),
                    center.y + innerTickR * sin(angle).toFloat()
                )
                val end = Offset(
                    center.x + outerTickR * cos(angle).toFloat(),
                    center.y + outerTickR * sin(angle).toFloat()
                )
                drawLine(
                    color = tickColor.copy(alpha = 0.3f),
                    start = start,
                    end = end,
                    strokeWidth = 1.dp.toPx()
                )
            }

            // Bedtime moon + wake sun markers — drawn as filled circles in Canvas,
            // with the vector icon overlaid via the outer Box (below).
            if (bed != null && wake != null && session.totalMinutes > 0) {
                val markerRadius = 14.dp.toPx()
                val bedRad = Math.toRadians((timeToAngleDegrees(bed) - 90).toDouble())
                val wakeRad = Math.toRadians((timeToAngleDegrees(wake) - 90).toDouble())

                drawCircle(
                    color = moonBg,
                    radius = markerRadius,
                    center = Offset(
                        center.x + radius * cos(bedRad).toFloat(),
                        center.y + radius * sin(bedRad).toFloat()
                    )
                )
                drawCircle(
                    color = sunBg,
                    radius = markerRadius,
                    center = Offset(
                        center.x + radius * cos(wakeRad).toFloat(),
                        center.y + radius * sin(wakeRad).toFloat()
                    )
                )
            }
        }

        // Center text
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            if (session != null && session.totalMinutes > 0) {
                val h = session.totalMinutes / 60
                val m = session.totalMinutes % 60
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = if (h < 10) "0$h" else "$h",
                        fontSize = 44.sp,
                        fontWeight = FontWeight.Bold,
                        color = centerValue
                    )
                    Text(
                        text = "hr",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = centerValue,
                        modifier = Modifier.padding(bottom = 8.dp, start = 2.dp)
                    )
                }
                Text(
                    text = "${m}min",
                    style = MaterialTheme.typography.labelMedium,
                    color = centerLabel
                )
            } else {
                Text(
                    text = "--",
                    fontSize = 44.sp,
                    fontWeight = FontWeight.Bold,
                    color = centerValue
                )
                Text(
                    text = "No sleep data",
                    style = MaterialTheme.typography.labelMedium,
                    color = centerLabel
                )
            }
        }
    }
}

/** Converts a clock time to a 0-360° angle where 12 o'clock = 0°. */
private fun timeToAngleDegrees(time: LocalTime): Float {
    val hour12 = time.hour % 12
    val totalMinutes = hour12 * 60 + time.minute
    return (totalMinutes / 720f) * 360f
}

// ─────────────────────────────────────
// MARK: - Duration + Efficiency sections
// ─────────────────────────────────────

@Composable
private fun SleepSectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.onSurface,
        modifier = modifier
    )
}

@Composable
private fun SleepDurationRow(
    session: SleepSession?,
    modifier: Modifier = Modifier
) {
    val minutes = session?.totalMinutes ?: 0
    val title = when {
        minutes <= 0 -> "No data"
        minutes in 420..540 -> "Asleep"
        minutes < 420 -> "Under-slept"
        else -> "Over-slept"
    }
    val subtitle = "People usually need 7-9 hrs"
    val badgeColor = when {
        minutes in 420..540 -> Color(0xFFB6F09C)
        minutes <= 0 -> AppColors.outlineVariant
        else -> Color(0xFFFCD34D)
    }
    val iconTint = when {
        minutes in 420..540 -> Color(0xFF166534)
        minutes <= 0 -> AppColors.onSurfaceVariant
        else -> Color(0xFF92400E)
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(badgeColor),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Check,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(20.dp)
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.onSurfaceVariant
            )
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant
        )
    }
}

@Composable
private fun SleepTwoUpStatRow(
    session: SleepSession?,
    modifier: Modifier = Modifier
) {
    val hours = session?.let { it.totalMinutes / 60 } ?: 0
    val pts = session?.qualityScore ?: 0
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        SmallInfoCard(
            icon = Icons.Default.Schedule,
            value = if (session != null && hours > 0) "${if (hours < 10) "0$hours" else "$hours"} Hours" else "-- Hours",
            modifier = Modifier.weight(1f)
        )
        SmallInfoCard(
            icon = Icons.Default.Star,
            value = if (session != null) "$pts pts" else "-- pts",
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun SmallInfoCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .glass(cornerRadius = 14.dp)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
    }
}

@Composable
private fun SleepEfficiencyRow(
    session: SleepSession?,
    modifier: Modifier = Modifier
) {
    val efficiencyText = remember(session) {
        if (session == null || session.totalMinutes <= 0) {
            "--"
        } else {
            val inBedMinutes = ((session.endTimeEpochMillis - session.startTimeEpochMillis) / 60_000L).toInt()
            if (inBedMinutes <= 0) "--"
            else {
                val pct = (session.totalMinutes.toFloat() / inBedMinutes * 100f)
                    .coerceIn(0f, 100f)
                    .toInt()
                "$pct%"
            }
        }
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(SleepColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Schedule,
                contentDescription = null,
                tint = SleepColor,
                modifier = Modifier.size(20.dp)
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Efficiency",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Spacer(Modifier.weight(1f))
                Text(
                    text = efficiencyText,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SleepColor
                )
            }
            Text(
                text = "Time spent in bed asleep. Aim 85%+",
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.onSurfaceVariant
            )
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant
        )
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
