package com.swastricare.health.ui.screens.medications

import android.app.Activity
import android.graphics.BitmapFactory
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.theme.AITeal
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

private val AnalyticsTeal = AITeal
private val AnalyticsTealLight = Color(0xFFE8FAF6)
private val AnalyticsCardBg = Color(0xFFF7FBFA)

// ─────────────────────────────────────
// MARK: - Screen
// ─────────────────────────────────────

@Composable
fun MedicationAnalyticsScreen(onBack: () -> Unit) {
    val vm: MedicationAnalyticsViewModel = hiltViewModel()
    val state by vm.state.collectAsState()

    val view = LocalView.current
    if (!view.isInEditMode) {
        DisposableEffect(Unit) {
            val activity = view.context as? Activity ?: return@DisposableEffect onDispose {}
            val orig = activity.window.statusBarColor
            activity.window.statusBarColor = android.graphics.Color.WHITE
            WindowCompat.getInsetsController(activity.window, view).isAppearanceLightStatusBars = true
            onDispose { activity.window.statusBarColor = orig }
        }
    }

    if (state.isLoading) {
        Box(Modifier.fillMaxSize().background(Color.White), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = AnalyticsTeal)
        }
        return
    }

    val context = LocalContext.current
    val leafBitmap = remember {
        runCatching {
            context.assets.open("icons/background leaf illustration left.png").use {
                BitmapFactory.decodeStream(it)
            }.asImageBitmap()
        }.getOrNull()
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.White)) {
        if (leafBitmap != null) {
            Image(
                bitmap = leafBitmap,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset(y = 32.dp)
                    .width(360.dp)
            )
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 48.dp)
        ) {
        item { AnalyticsTopBar(state.period, onBack = onBack, onPeriodChange = vm::setPeriod) }
        item { Spacer(Modifier.height(20.dp)) }
        item {
            Text(
                "Overview",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp,
                color = Color(0xFF1A1A2E),
                modifier = Modifier.padding(horizontal = 20.dp)
            )
            Spacer(Modifier.height(12.dp))
            OverviewCards(state)
        }
        item { Spacer(Modifier.height(24.dp)) }
        item {
            Text(
                "Adherence Trend",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp,
                color = Color(0xFF1A1A2E),
                modifier = Modifier.padding(horizontal = 20.dp)
            )
            Spacer(Modifier.height(12.dp))
            AdherenceTrendChart(points = state.dailyAdherence)
        }
        item { Spacer(Modifier.height(24.dp)) }
        item {
            Text(
                "Medication Overview",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp,
                color = Color(0xFF1A1A2E),
                modifier = Modifier.padding(horizontal = 20.dp)
            )
            Spacer(Modifier.height(12.dp))
            MedicationOverviewCard(
                taken = state.donutTaken,
                missed = state.donutMissed,
                upcoming = state.donutUpcoming
            )
        }
        item { Spacer(Modifier.height(24.dp)) }
        item { MotivationBanner(state.adherencePercent) }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────

@Composable
private fun AnalyticsTopBar(
    currentPeriod: MedAnalyticsPeriod,
    onBack: () -> Unit,
    onPeriodChange: (MedAnalyticsPeriod) -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .statusBarsPadding()
            .padding(horizontal = 4.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color(0xFF1A1A2E))
        }
        Text(
            "Analytics",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFF1A1A2E),
            modifier = Modifier.weight(1f)
        )
        Box {
            OutlinedButton(
                onClick = { showMenu = true },
                shape = RoundedCornerShape(20.dp),
                border = ButtonDefaults.outlinedButtonBorder.copy(
                    brush = SolidColor(AnalyticsTeal.copy(alpha = 0.4f))
                ),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = AnalyticsTeal)
            ) {
                Text(currentPeriod.label, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                Icon(Icons.Default.ArrowDropDown, contentDescription = null, modifier = Modifier.size(16.dp))
            }
            DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                MedAnalyticsPeriod.entries.forEach { p ->
                    DropdownMenuItem(
                        text = { Text(p.label) },
                        onClick = { onPeriodChange(p); showMenu = false }
                    )
                }
            }
        }
        Spacer(Modifier.width(8.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Overview Cards
// ─────────────────────────────────────

@Composable
private fun OverviewCards(state: MedicationAnalyticsState) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        StatCard(
            icon = Icons.Default.Percent,
            value = "${state.adherencePercent}%",
            label = "Adherence",
            modifier = Modifier.weight(1f)
        )
        StatCard(
            icon = Icons.Default.Medication,
            value = "${state.dosesTaken}",
            label = "Doses Taken",
            modifier = Modifier.weight(1f)
        )
    }
    Spacer(Modifier.height(10.dp))
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        StatCard(
            icon = Icons.Default.CalendarToday,
            value = "${state.daysOnTrack}",
            label = "Days on Track",
            modifier = Modifier.weight(1f)
        )
        StatCard(
            icon = Icons.Default.NotificationsOff,
            value = "${state.remindersSkipped}",
            label = "Reminders Skipped",
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun StatCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(AnalyticsCardBg)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AnalyticsTealLight),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = AnalyticsTeal, modifier = Modifier.size(18.dp))
            }
            Text(value, fontWeight = FontWeight.Bold, fontSize = 22.sp, color = Color(0xFF1A1A2E))
        }
        Text(label, fontSize = 12.sp, color = Color(0xFF888888), lineHeight = 16.sp)
    }
}

// ─────────────────────────────────────
// MARK: - Adherence Trend Chart
// ─────────────────────────────────────

@Composable
private fun AdherenceTrendChart(points: List<DailyAdherencePoint>) {
    if (points.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .padding(horizontal = 16.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(AnalyticsCardBg),
            contentAlignment = Alignment.Center
        ) {
            Text("No data yet", color = Color(0xFFAAAAAA), fontSize = 14.sp)
        }
        return
    }

    val animate by animateFloatAsState(1f, tween(800), label = "chart")

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AnalyticsCardBg)
            .padding(16.dp)
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
        ) {
            val w = size.width
            val h = size.height
            val maxVal = 100f
            val step = w / (points.size - 1).coerceAtLeast(1)
            val xPad = 0f

            // Build path
            val linePath = Path()
            val fillPath = Path()
            points.forEachIndexed { i, point ->
                val x = xPad + i * step
                val y = h - (point.percentage / maxVal) * h * animate
                if (i == 0) {
                    linePath.moveTo(x, y)
                    fillPath.moveTo(x, h)
                    fillPath.lineTo(x, y)
                } else {
                    // Smooth bezier
                    val prevX = xPad + (i - 1) * step
                    val prevY = h - (points[i - 1].percentage / maxVal) * h * animate
                    val cx = (prevX + x) / 2
                    linePath.cubicTo(cx, prevY, cx, y, x, y)
                    fillPath.cubicTo(cx, prevY, cx, y, x, y)
                }
            }
            fillPath.lineTo(xPad + (points.size - 1) * step, h)
            fillPath.close()

            // Grid lines
            for (pct in listOf(0f, 50f, 100f)) {
                val y = h - (pct / maxVal) * h
                drawLine(
                    Color(0xFFE0E0E0),
                    Offset(0f, y),
                    Offset(w, y),
                    strokeWidth = 1.dp.toPx()
                )
            }

            // Fill
            drawPath(
                fillPath,
                brush = Brush.verticalGradient(
                    listOf(AnalyticsTeal.copy(alpha = 0.3f), AnalyticsTeal.copy(alpha = 0.02f)),
                    startY = 0f,
                    endY = h
                )
            )

            // Line
            drawPath(
                linePath,
                color = AnalyticsTeal,
                style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
            )

            // Dots at data points
            points.forEachIndexed { i, point ->
                val x = xPad + i * step
                val y = h - (point.percentage / maxVal) * h * animate
                drawCircle(Color.White, radius = 4.dp.toPx(), center = Offset(x, y))
                drawCircle(
                    AnalyticsTeal,
                    radius = 3.dp.toPx(),
                    center = Offset(x, y),
                    style = Stroke(1.5.dp.toPx())
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        // X-axis labels: first, middle, last — pinned to the chart edges
        val fmt = DateTimeFormatter.ofPattern("d MMM")
        val first = points.first()
        val middle = points[points.size / 2]
        val last = points.last()
        val labelStyle = @Composable { text: String, align: TextAlign ->
            Text(
                text,
                fontSize = 10.sp,
                color = Color(0xFF888888),
                textAlign = align,
                maxLines = 1
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            labelStyle(first.date.format(fmt), TextAlign.Start)
            if (points.size > 2) {
                labelStyle(middle.date.format(fmt), TextAlign.Center)
            }
            labelStyle(last.date.format(fmt), TextAlign.End)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Donut Chart
// ─────────────────────────────────────

@Composable
private fun MedicationOverviewCard(taken: Int, missed: Int, upcoming: Int) {
    val total = taken + missed + upcoming
    val takenAngle = if (total > 0) 360f * taken / total else 0f
    val missedAngle = if (total > 0) 360f * missed / total else 0f
    val upcomingAngle = if (total > 0) 360f * upcoming / total else 360f

    val animate by animateFloatAsState(1f, tween(800), label = "donut")

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AnalyticsCardBg)
            .padding(20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        // Donut
        Box(
            modifier = Modifier.size(120.dp),
            contentAlignment = Alignment.Center
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val stroke = 18.dp.toPx()
                val inset = stroke / 2
                val rect = Size(size.width - stroke, size.height - stroke)
                val topLeft = Offset(inset, inset)
                val startAngle = -90f

                if (total == 0) {
                    drawArc(
                        color = Color(0xFFE8E8E8),
                        startAngle = 0f,
                        sweepAngle = 360f,
                        useCenter = false,
                        topLeft = topLeft,
                        size = rect,
                        style = Stroke(stroke, cap = StrokeCap.Round)
                    )
                } else {
                    var currentAngle = startAngle
                    // Taken (teal)
                    if (takenAngle > 0) {
                        drawArc(
                            color = AnalyticsTeal,
                            startAngle = currentAngle,
                            sweepAngle = takenAngle * animate,
                            useCenter = false,
                            topLeft = topLeft,
                            size = rect,
                            style = Stroke(stroke, cap = StrokeCap.Butt)
                        )
                        currentAngle += takenAngle
                    }
                    // Missed (red-ish)
                    if (missedAngle > 0) {
                        drawArc(
                            color = Color(0xFFFF6B6B),
                            startAngle = currentAngle,
                            sweepAngle = missedAngle * animate,
                            useCenter = false,
                            topLeft = topLeft,
                            size = rect,
                            style = Stroke(stroke, cap = StrokeCap.Butt)
                        )
                        currentAngle += missedAngle
                    }
                    // Upcoming (orange)
                    if (upcomingAngle > 0) {
                        drawArc(
                            color = Color(0xFFFFB347),
                            startAngle = currentAngle,
                            sweepAngle = upcomingAngle * animate,
                            useCenter = false,
                            topLeft = topLeft,
                            size = rect,
                            style = Stroke(stroke, cap = StrokeCap.Butt)
                        )
                    }
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "$total",
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 22.sp,
                    color = Color(0xFF1A1A2E)
                )
                Text("Total", fontSize = 11.sp, color = Color(0xFF888888))
            }
        }

        Spacer(Modifier.width(20.dp))

        // Legend
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            val takenPct = if (total > 0) (taken * 100 / total) else 0
            val missedPct = if (total > 0) (missed * 100 / total) else 0
            val upcomingPct = if (total > 0) (upcoming * 100 / total) else 0
            DonutLegendItem(color = AnalyticsTeal, label = "Taken", count = taken, pct = takenPct)
            DonutLegendItem(color = Color(0xFFFF6B6B), label = "Missed", count = missed, pct = missedPct)
            DonutLegendItem(color = Color(0xFFFFB347), label = "Upcoming", count = upcoming, pct = upcomingPct)
        }
    }
}

@Composable
private fun DonutLegendItem(color: Color, label: String, count: Int, pct: Int) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(label, fontSize = 13.sp, color = Color(0xFF555555), modifier = Modifier.width(70.dp))
        Text(
            "$count ($pct%)",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF1A1A2E)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Motivation Banner
// ─────────────────────────────────────

@Composable
private fun MotivationBanner(adherencePercent: Int) {
    val message = when {
        adherencePercent >= 90 -> "Excellent! You're a medication champion!"
        adherencePercent >= 75 -> "Great job! You're building a healthy habit."
        adherencePercent >= 50 -> "Good effort! Keep pushing for better adherence."
        else -> "Every dose counts. Let's improve together!"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AnalyticsTealLight)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("🌟", fontSize = 28.sp)
        Text(
            message,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF1A6B5A),
            lineHeight = 20.sp
        )
    }
}
