package com.swastricare.health.ui.screens.sleep

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SleepColor
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.*

// Arc constants
private const val ARC_START_ANGLE = 135f      // degrees
private const val ARC_SWEEP = 270f             // degrees = full range
private const val MAX_SLEEP_MINUTES = 720      // 12h

@Composable
fun LogSleepScreen(
    onNavigateBack: () -> Unit,
    viewModel: LogSleepViewModel = hiltViewModel()
) {
    TrackScreen("LogSleep")
    val uiState by viewModel.uiState.collectAsState()

    // Navigate back on save success
    LaunchedEffect(uiState.saveSuccess) {
        if (uiState.saveSuccess) onNavigateBack()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        // Top bar
        LogSleepTopBar(onNavigateBack = onNavigateBack)

        // Date chips
        DateChipsRow(
            selectedDate = uiState.selectedDate,
            disabledDates = uiState.disabledDates,
            onDateSelected = { viewModel.selectDate(it) }
        )

        Spacer(Modifier.height(24.dp))

        // Circular arc slider
        SleepArcSlider(
            durationMinutes = uiState.durationMinutes,
            onDurationChanged = { viewModel.setDuration(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
        )

        Spacer(Modifier.height(24.dp))

        // Bedtime / Wake time chips
        TimeChipsRow(
            bedtimeMillis = uiState.bedtimeMillis,
            wakeTimeMillis = uiState.wakeTimeMillis,
            onBedtimeChanged = { viewModel.setBedtime(it) },
            onWakeTimeChanged = { viewModel.setWakeTime(it) }
        )

        Spacer(Modifier.height(20.dp))

        // Notes
        OutlinedTextField(
            value = uiState.notes,
            onValueChange = { viewModel.setNotes(it) },
            placeholder = {
                Text("How did you feel?", color = AppColors.onSurfaceVariant)
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(12.dp),
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = SleepColor,
                unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.2f)
            )
        )

        Spacer(Modifier.height(24.dp))

        // Error
        uiState.error?.let { err ->
            Text(
                err,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(8.dp))
        }

        // Save button
        Button(
            onClick = { viewModel.save() },
            enabled = uiState.durationMinutes > 0 && !uiState.isSaving,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(52.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = SleepColor)
        ) {
            if (uiState.isSaving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    "Save Sleep",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                    color = Color.White
                )
            }
        }

        Spacer(Modifier.height(40.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────

@Composable
private fun LogSleepTopBar(onNavigateBack: () -> Unit) {
    AppTopBar(title = "Log Sleep", onBack = onNavigateBack)
}

// ─────────────────────────────────────
// MARK: - Date Chips Row
// ─────────────────────────────────────

@Composable
private fun DateChipsRow(
    selectedDate: LocalDate,
    disabledDates: Set<LocalDate>,
    onDateSelected: (LocalDate) -> Unit
) {
    val today = LocalDate.now()
    val dates = (0..6).map { today.minusDays(it.toLong()) }
    val dayFmt = DateTimeFormatter.ofPattern("EEE")
    val dateFmt = DateTimeFormatter.ofPattern("d")

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        dates.forEach { date ->
            val isSelected = date == selectedDate
            val isDisabled = disabledDates.contains(date)
            val label = when (date) {
                today -> "Today"
                today.minusDays(1) -> "Yesterday"
                else -> date.format(dayFmt)
            }

            val bg = when {
                isSelected -> SleepColor
                isDisabled -> AppColors.onSurface.copy(alpha = 0.05f)
                else -> AppColors.onSurface.copy(alpha = 0.08f)
            }
            val textColor = when {
                isSelected -> Color.White
                isDisabled -> AppColors.onSurface.copy(alpha = 0.3f)
                else -> AppColors.onSurface
            }

            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(bg)
                    .clickable(enabled = !isDisabled) { onDateSelected(date) }
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(label, style = MaterialTheme.typography.labelSmall, color = textColor)
                Text(
                    date.format(dateFmt),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = textColor
                )
                if (isDisabled) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        "Synced",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                        color = textColor
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Circular Arc Slider
// ─────────────────────────────────────

@Composable
fun SleepArcSlider(
    durationMinutes: Int,
    onDurationChanged: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val arcSize = 260.dp

    // Progress 0..1 on the arc
    val progress = durationMinutes.toFloat() / MAX_SLEEP_MINUTES

    // Animate arc fill on first appearance
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }
    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) progress else 0f,
        animationSpec = tween(800, easing = FastOutSlowInEasing),
        label = "arcProgress"
    )

    val hours = durationMinutes / 60
    val mins = durationMinutes % 60
    val durationLabel = "${hours}h ${mins}m"

    Box(
        modifier = modifier.aspectRatio(1f),
        contentAlignment = Alignment.Center
    ) {
        Canvas(
            modifier = Modifier
                .size(arcSize)
                .pointerInput(Unit) {
                    detectDragGestures { change, _ ->
                        change.consume()
                        val center = Offset(size.width / 2f, size.height / 2f)
                        val pos = change.position
                        val angle = Math
                            .toDegrees(
                                atan2(
                                    (pos.y - center.y).toDouble(),
                                    (pos.x - center.x).toDouble()
                                )
                            )
                            .toFloat()

                        // Normalize angle relative to arc start (135°)
                        var normalized = angle - ARC_START_ANGLE
                        if (normalized < 0) normalized += 360f
                        if (normalized > ARC_SWEEP) normalized = ARC_SWEEP

                        val newProgress = (normalized / ARC_SWEEP).coerceIn(0f, 1f)
                        // Snap to 15-minute increments
                        val rawMinutes = (newProgress * MAX_SLEEP_MINUTES).roundToInt()
                        val snapped = (rawMinutes / 15) * 15
                        onDurationChanged(snapped.coerceIn(0, MAX_SLEEP_MINUTES))
                    }
                }
        ) {
            val strokeWidth = 22.dp.toPx()
            val padding = strokeWidth / 2 + 4.dp.toPx()
            val diameter = size.width - padding * 2
            val topLeft = Offset(padding, padding)
            val arcSizePx = Size(diameter, diameter)

            // Background arc
            drawArc(
                color = Color.White.copy(alpha = 0.08f),
                startAngle = ARC_START_ANGLE,
                sweepAngle = ARC_SWEEP,
                useCenter = false,
                topLeft = topLeft,
                size = arcSizePx,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )

            // Filled arc
            if (animatedProgress > 0f) {
                drawArc(
                    brush = Brush.sweepGradient(
                        colors = listOf(
                            SleepColor.copy(alpha = 0.7f),
                            SleepColor,
                            Color(0xFF9B5DE5)
                        ),
                        center = center
                    ),
                    startAngle = ARC_START_ANGLE,
                    sweepAngle = ARC_SWEEP * animatedProgress,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSizePx,
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                )
            }

            // Handle position (rendered as a circle indicator)
            val handleAngleDeg = ARC_START_ANGLE + ARC_SWEEP * progress
            val handleAngleRad = Math.toRadians(handleAngleDeg.toDouble())
            val radius = diameter / 2
            val handleX = center.x + radius * cos(handleAngleRad).toFloat()
            val handleY = center.y + radius * sin(handleAngleRad).toFloat()

            drawCircle(
                color = Color.White,
                radius = 14.dp.toPx(),
                center = Offset(handleX, handleY)
            )
            drawCircle(
                color = SleepColor,
                radius = 10.dp.toPx(),
                center = Offset(handleX, handleY)
            )
        }

        // Center label
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                durationLabel,
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                "Sleep Duration",
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Time Chips Row
// ─────────────────────────────────────

@Composable
private fun TimeChipsRow(
    bedtimeMillis: Long,
    wakeTimeMillis: Long,
    onBedtimeChanged: (Long) -> Unit,
    onWakeTimeChanged: (Long) -> Unit
) {
    val context = LocalContext.current
    val zone = ZoneId.systemDefault()
    val timeFmt = DateTimeFormatter.ofPattern("hh:mm a")

    fun millisToLocalTime(millis: Long) = if (millis > 0)
        Instant.ofEpochMilli(millis).atZone(zone).toLocalTime()
    else null

    fun showTimePicker(initialMillis: Long, onPicked: (Long) -> Unit) {
        val lt = millisToLocalTime(initialMillis)
        val cal = java.util.Calendar.getInstance().apply {
            lt?.let { set(java.util.Calendar.HOUR_OF_DAY, it.hour) }
            lt?.let { set(java.util.Calendar.MINUTE, it.minute) }
        }
        android.app.TimePickerDialog(
            context,
            { _, hour, minute ->
                // Keep same date, just update time
                val ld = Instant.ofEpochMilli(initialMillis).atZone(zone).toLocalDate()
                val newMillis = ld.atTime(hour, minute).atZone(zone).toInstant().toEpochMilli()
                onPicked(newMillis)
            },
            cal.get(java.util.Calendar.HOUR_OF_DAY),
            cal.get(java.util.Calendar.MINUTE),
            false
        ).show()
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Bedtime chip
        TimeChip(
            icon = Icons.Default.Bedtime,
            label = "Bedtime",
            timeText = millisToLocalTime(bedtimeMillis)?.format(timeFmt) ?: "--",
            color = SleepColor,
            modifier = Modifier.weight(1f),
            onClick = { showTimePicker(bedtimeMillis, onBedtimeChanged) }
        )
        // Wake chip
        TimeChip(
            icon = Icons.Default.WbSunny,
            label = "Wake Up",
            timeText = millisToLocalTime(wakeTimeMillis)?.format(timeFmt) ?: "--",
            color = Color(0xFFF59E0B),
            modifier = Modifier.weight(1f),
            onClick = { showTimePicker(wakeTimeMillis, onWakeTimeChanged) }
        )
    }
}

@Composable
private fun TimeChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    timeText: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
            Text(
                timeText,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }
    }
}
