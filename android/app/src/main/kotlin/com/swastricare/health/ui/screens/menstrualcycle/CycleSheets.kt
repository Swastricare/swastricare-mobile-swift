package com.swastricare.health.ui.screens.menstrualcycle

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

// ─────────────────────────────────────
// MARK: - CycleSettingsSheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CycleSettingsSheet(
    settings: CycleSettings,
    onDismiss: () -> Unit,
    onSave: (cycleLength: Int, periodLength: Int, reminderDaysBefore: Int) -> Unit,
    onUpdateNotifications: (
        period: Boolean?,
        fertile: Boolean?,
        pms: Boolean?,
        ovulation: Boolean?
    ) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var cycleLength by remember { mutableFloatStateOf(settings.averageCycleLength.toFloat()) }
    var periodLength by remember { mutableFloatStateOf(settings.averagePeriodLength.toFloat()) }
    var reminderDaysBefore by remember { mutableFloatStateOf(settings.reminderDaysBefore.toFloat()) }
    var periodReminder by remember { mutableStateOf(settings.periodReminderEnabled) }
    var fertileReminder by remember { mutableStateOf(settings.fertileWindowReminderEnabled) }
    var pmsReminder by remember { mutableStateOf(settings.pmsReminderEnabled) }
    var ovulationReminder by remember { mutableStateOf(settings.ovulationReminderEnabled) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Text(
                text = "Cycle Settings",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )

            // Cycle Length Slider
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        "Average Cycle Length",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        "${cycleLength.toInt()} days",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = CyclePurple
                    )
                }
                Slider(
                    value = cycleLength,
                    onValueChange = { cycleLength = it },
                    valueRange = 21f..45f,
                    steps = 23,
                    colors = SliderDefaults.colors(
                        thumbColor = CyclePurple,
                        activeTrackColor = CyclePurple
                    )
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("21", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
                    Text("45", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
                }
            }

            // Period Length Slider
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        "Average Period Length",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        "${periodLength.toInt()} days",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = CyclePink
                    )
                }
                Slider(
                    value = periodLength,
                    onValueChange = { periodLength = it },
                    valueRange = 2f..10f,
                    steps = 7,
                    colors = SliderDefaults.colors(
                        thumbColor = CyclePink,
                        activeTrackColor = CyclePink
                    )
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("2", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
                    Text("10", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
                }
            }

            HorizontalDivider(color = AppColors.outlineVariant)

            // Notification Preferences
            Text(
                text = "Notifications",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Period Reminder", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "Get notified before your period starts",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Switch(
                    checked = periodReminder,
                    onCheckedChange = { periodReminder = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = CyclePink)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Fertile Window Reminder", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "Get notified during your fertile window",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Switch(
                    checked = fertileReminder,
                    onCheckedChange = { fertileReminder = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = OvulationColor)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("PMS Reminder", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "Get tips when PMS phase begins",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Switch(
                    checked = pmsReminder,
                    onCheckedChange = { pmsReminder = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = LutealColor)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Ovulation Reminder", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "Notify me on my predicted ovulation day",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Switch(
                    checked = ovulationReminder,
                    onCheckedChange = { ovulationReminder = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = OvulationColor)
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        "Remind me this many days before period",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        "${reminderDaysBefore.toInt()} ${if (reminderDaysBefore.toInt() == 1) "day" else "days"}",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = CyclePink
                    )
                }
                Slider(
                    value = reminderDaysBefore,
                    onValueChange = { reminderDaysBefore = it },
                    valueRange = 1f..7f,
                    steps = 5,
                    colors = SliderDefaults.colors(
                        thumbColor = CyclePink,
                        activeTrackColor = CyclePink
                    )
                )
            }

            // Save Button
            Button(
                onClick = {
                    onSave(cycleLength.toInt(), periodLength.toInt(), reminderDaysBefore.toInt())
                    onUpdateNotifications(periodReminder, fertileReminder, pmsReminder, ovulationReminder)
                    onDismiss()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = CyclePink
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text(
                    "Save",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - CycleStatisticsSheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CycleStatisticsSheet(
    stats: CycleStatistics,
    onDismiss: () -> Unit,
    formatDate: (LocalDate) -> String
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scrollState = rememberScrollState()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(scrollState)
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Text(
                text = "Cycle Statistics",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )

            // Regularity
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                Box(
                    modifier = Modifier
                        .background(
                            stats.regularity.color.copy(alpha = 0.12f),
                            RoundedCornerShape(24.dp)
                        )
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = "Cycle Regularity: ${stats.regularity.displayName}",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = stats.regularity.color
                    )
                }
            }

            // Cycle Length Chart
            StatChartSection(
                title = "Cycle Length (last 6 cycles)",
                averageLabel = "Avg: ${String.format("%.1f", stats.averageCycleLength)} days",
                values = stats.recentCycles.map { it.cycleLength.toFloat() },
                labels = stats.recentCycles.map {
                    it.startDate.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())
                },
                barColor = CyclePurple,
                maxValue = 45f
            )

            // Period Length Chart
            StatChartSection(
                title = "Period Length (last 6 cycles)",
                averageLabel = "Avg: ${String.format("%.1f", stats.averagePeriodLength)} days",
                values = stats.recentCycles.map { it.periodLength.toFloat() },
                labels = stats.recentCycles.map {
                    it.startDate.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())
                },
                barColor = CyclePink,
                maxValue = 10f
            )

            // Symptom Frequency
            if (stats.symptomFrequencies.isNotEmpty()) {
                Text(
                    text = "Symptom Frequency",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )

                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    stats.symptomFrequencies.forEach { sf ->
                        SymptomFrequencyBar(
                            symptom = sf.symptom,
                            percentage = sf.percentage
                        )
                    }
                }
            }

            HorizontalDivider(color = AppColors.outlineVariant)

            // History List
            Text(
                text = "Cycle History",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                stats.recentCycles.forEach { record ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                AppColors.surfaceVariant.copy(alpha = 0.5f),
                                RoundedCornerShape(12.dp)
                            )
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = formatDate(record.startDate),
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = "Period: ${record.periodLength} days",
                                style = MaterialTheme.typography.labelSmall,
                                color = CyclePink
                            )
                        }
                        Text(
                            text = "${record.cycleLength} days",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = CyclePurple
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Canvas Bar Chart Section
// ─────────────────────────────────────

@Composable
internal fun StatChartSection(
    title: String,
    averageLabel: String,
    values: List<Float>,
    labels: List<String>,
    barColor: Color,
    maxValue: Float
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = averageLabel,
                style = MaterialTheme.typography.labelMedium,
                color = barColor,
                fontWeight = FontWeight.Medium
            )
        }

        // Canvas bar chart
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
        ) {
            val barCount = values.size
            if (barCount == 0) return@Canvas

            val chartWidth = size.width
            val chartHeight = size.height - 24.dp.toPx() // Leave room for labels
            val barSpacing = 12.dp.toPx()
            val barWidth = (chartWidth - barSpacing * (barCount + 1)) / barCount
            val cornerRadius = 4.dp.toPx()

            // Average line
            val avg = values.average().toFloat()
            val avgY = chartHeight * (1f - avg / maxValue)
            drawLine(
                color = barColor.copy(alpha = 0.3f),
                start = Offset(0f, avgY),
                end = Offset(chartWidth, avgY),
                strokeWidth = 1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(
                    floatArrayOf(8.dp.toPx(), 4.dp.toPx())
                )
            )

            values.forEachIndexed { index, value ->
                val barHeight = chartHeight * (value / maxValue)
                val x = barSpacing + index * (barWidth + barSpacing)
                val y = chartHeight - barHeight

                // Bar
                drawRoundRect(
                    color = barColor.copy(alpha = 0.7f),
                    topLeft = Offset(x, y),
                    size = Size(barWidth, barHeight),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(cornerRadius)
                )

                // Value label on top
                drawContext.canvas.nativeCanvas.apply {
                    val paint = android.graphics.Paint().apply {
                        color = barColor.copy(alpha = 0.9f).hashCode()
                        textSize = 10.sp.toPx()
                        textAlign = android.graphics.Paint.Align.CENTER
                        isAntiAlias = true
                    }
                    drawText(
                        "${value.toInt()}",
                        x + barWidth / 2,
                        y - 4.dp.toPx(),
                        paint
                    )
                }

                // Month label at bottom
                if (index < labels.size) {
                    drawContext.canvas.nativeCanvas.apply {
                        val paint = android.graphics.Paint().apply {
                            color = android.graphics.Color.GRAY
                            textSize = 10.sp.toPx()
                            textAlign = android.graphics.Paint.Align.CENTER
                            isAntiAlias = true
                        }
                        drawText(
                            labels[index],
                            x + barWidth / 2,
                            size.height - 2.dp.toPx(),
                            paint
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Symptom Frequency Bar
// ─────────────────────────────────────

@Composable
internal fun SymptomFrequencyBar(
    symptom: String,
    percentage: Float
) {
    val animatedWidth by animateFloatAsState(
        targetValue = percentage,
        animationSpec = tween(800, easing = FastOutSlowInEasing),
        label = "symptomBar"
    )

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = symptom,
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurface
            )
            Text(
                text = "${(percentage * 100).toInt()}%",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = CyclePink
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(AppColors.surfaceVariant)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(animatedWidth)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(4.dp))
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(CyclePink, CyclePurple)
                        )
                    )
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - LogPeriodSheet (6-step flow)
// ─────────────────────────────────────

private data class LogPeriodData(
    val startDate: java.time.LocalDate = java.time.LocalDate.now(),
    val flowLevel: com.swastricare.health.domain.model.menstrualcycle.FlowLevel = com.swastricare.health.domain.model.menstrualcycle.FlowLevel.MEDIUM,
    val symptoms: Set<com.swastricare.health.domain.model.menstrualcycle.Symptom> = emptySet(),
    val mood: com.swastricare.health.domain.model.menstrualcycle.Mood? = null,
    val painLevel: Int = 0,
    val notes: String = ""
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
internal fun LogPeriodSheet(
    onDismiss: () -> Unit,
    onConfirm: (
        startDate: java.time.LocalDate,
        flowLevel: com.swastricare.health.domain.model.menstrualcycle.FlowLevel,
        symptoms: List<com.swastricare.health.domain.model.menstrualcycle.Symptom>,
        mood: com.swastricare.health.domain.model.menstrualcycle.Mood?,
        painLevel: Int,
        notes: String?
    ) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var step by remember { mutableIntStateOf(0) }
    var data by remember { mutableStateOf(LogPeriodData()) }
    val totalSteps = 6

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.surface,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.85f)
                .navigationBarsPadding()
        ) {
            // ── Step dots ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(totalSteps) { index ->
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .size(if (index == step) 10.dp else 7.dp)
                            .background(
                                if (index <= step) CyclePink else CyclePink.copy(alpha = 0.25f),
                                CircleShape
                            )
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // ── Animated step content ──
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    if (targetState > initialState) {
                        (slideInHorizontally { it } togetherWith slideOutHorizontally { -it })
                    } else {
                        (slideInHorizontally { -it } togetherWith slideOutHorizontally { it })
                    }
                },
                label = "LogStep",
                modifier = Modifier.weight(1f)
            ) { currentStep ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 24.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    when (currentStep) {
                        0 -> StepDate(data.startDate) { data = data.copy(startDate = it) }
                        1 -> StepFlow(data.flowLevel) { data = data.copy(flowLevel = it) }
                        2 -> StepSymptoms(data.symptoms) { data = data.copy(symptoms = it) }
                        3 -> StepMood(data.mood) { data = data.copy(mood = it) }
                        4 -> StepPain(data.painLevel) { data = data.copy(painLevel = it) }
                        5 -> StepNotes(data.notes, data) { data = data.copy(notes = it) }
                    }
                }
            }

            // ── Navigation buttons ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (step > 0) {
                    OutlinedButton(
                        onClick = { step-- },
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = CyclePink),
                        border = BorderStroke(1.dp, CyclePink),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.ArrowBack, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Back")
                    }
                } else {
                    Spacer(Modifier.weight(1f))
                }

                if (step < totalSteps - 1) {
                    Button(
                        onClick = { step++ },
                        colors = ButtonDefaults.buttonColors(containerColor = CyclePink),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Next")
                        Spacer(Modifier.width(4.dp))
                        Icon(Icons.Default.ArrowForward, null, modifier = Modifier.size(16.dp))
                    }
                } else {
                    Button(
                        onClick = {
                            onConfirm(
                                data.startDate,
                                data.flowLevel,
                                data.symptoms.toList(),
                                data.mood,
                                data.painLevel,
                                data.notes.ifBlank { null }
                            )
                            onDismiss()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = CyclePink),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(0.6f)
                    ) {
                        Text("Log Period", fontWeight = FontWeight.Bold)
                    }
                }
            }

            Spacer(Modifier.height(8.dp))
        }
    }
}

// ── Step 1: Date ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StepDate(selected: java.time.LocalDate, onChange: (java.time.LocalDate) -> Unit) {
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = selected.atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
    )
    LaunchedEffect(datePickerState.selectedDateMillis) {
        datePickerState.selectedDateMillis?.let { millis ->
            val date = java.time.Instant.ofEpochMilli(millis).atZone(java.time.ZoneId.systemDefault()).toLocalDate()
            if (date != selected) onChange(date)
        }
    }
    Text("When did it start?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    DatePicker(
        state = datePickerState,
        colors = DatePickerDefaults.colors(
            selectedDayContainerColor = CyclePink,
            todayDateBorderColor = CyclePink
        )
    )
}

// ── Step 2: Flow Level ──
@Composable
private fun StepFlow(
    selected: com.swastricare.health.domain.model.menstrualcycle.FlowLevel,
    onChange: (com.swastricare.health.domain.model.menstrualcycle.FlowLevel) -> Unit
) {
    val levels = listOf(
        com.swastricare.health.domain.model.menstrualcycle.FlowLevel.NONE to ("\uD83D\uDCA7" to "None"),
        com.swastricare.health.domain.model.menstrualcycle.FlowLevel.LIGHT to ("\uD83E\uDE78" to "Light"),
        com.swastricare.health.domain.model.menstrualcycle.FlowLevel.MEDIUM to ("\uD83E\uDE78\uD83E\uDE78" to "Medium"),
        com.swastricare.health.domain.model.menstrualcycle.FlowLevel.HEAVY to ("\uD83E\uDE78\uD83E\uDE78\uD83E\uDE78" to "Heavy"),
        com.swastricare.health.domain.model.menstrualcycle.FlowLevel.VERY_HEAVY to ("\uD83E\uDE78\uD83E\uDE78\uD83E\uDE78\uD83E\uDE78" to "Very Heavy")
    )
    Text("How heavy is the flow?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        levels.forEach { (level, display) ->
            val (emoji, label) = display
            val isSelected = selected == level
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (isSelected) CyclePink.copy(alpha = 0.12f) else AppColors.surfaceVariant.copy(alpha = 0.5f))
                    .border(
                        width = if (isSelected) 1.5.dp else 0.dp,
                        color = if (isSelected) CyclePink else Color.Transparent,
                        shape = RoundedCornerShape(14.dp)
                    )
                    .clickable { onChange(level) }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(emoji, fontSize = 22.sp)
                Text(
                    label,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                    color = if (isSelected) CyclePink else AppColors.onSurface
                )
                if (isSelected) {
                    Spacer(Modifier.weight(1f))
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .background(CyclePink, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("\u2713", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

// ── Step 3: Symptoms ──
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun StepSymptoms(
    selected: Set<com.swastricare.health.domain.model.menstrualcycle.Symptom>,
    onChange: (Set<com.swastricare.health.domain.model.menstrualcycle.Symptom>) -> Unit
) {
    val allSymptoms = listOf(
        com.swastricare.health.domain.model.menstrualcycle.Symptom.CRAMPS to "\uD83E\uDD15 Cramps",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.BLOATING to "\uD83E\uDEB7 Bloating",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.FATIGUE to "\uD83D\uDE34 Fatigue",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.MOOD_SWINGS to "\uD83C\uDF0A Mood Swings",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.HEADACHE to "\uD83E\uDD2F Headache",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.BACKACHE to "\uD83D\uDD19 Backache",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.NAUSEA to "\uD83E\uDD22 Nausea",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.ACNE to "\uD83D\uDE24 Acne",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.INSOMNIA to "\uD83C\uDF19 Insomnia",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.CRAVINGS to "\uD83C\uDF6B Cravings",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.BREAST_TENDERNESS to "\uD83D\uDC97 Tenderness",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.SPOTTING to "\uD83E\uDE79 Spotting",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.ANXIETY to "\uD83D\uDE30 Anxiety",
        com.swastricare.health.domain.model.menstrualcycle.Symptom.IRRITABILITY to "\uD83D\uDE20 Irritability"
    )
    Text("Any symptoms?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Text("Select all that apply", style = MaterialTheme.typography.bodySmall, color = AppColors.onSurfaceVariant)
    Spacer(Modifier.height(8.dp))
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        allSymptoms.forEach { (symptom, label) ->
            val isSelected = symptom in selected
            FilterChip(
                selected = isSelected,
                onClick = {
                    onChange(if (isSelected) selected - symptom else selected + symptom)
                },
                label = { Text(label, style = MaterialTheme.typography.bodySmall) },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = CyclePink.copy(alpha = 0.15f),
                    selectedLabelColor = CyclePink
                ),
                border = FilterChipDefaults.filterChipBorder(
                    enabled = true,
                    selected = isSelected,
                    selectedBorderColor = CyclePink,
                    selectedBorderWidth = 1.5.dp
                )
            )
        }
    }
}

// ── Step 4: Mood ──
private data class MoodEntry(val mood: com.swastricare.health.domain.model.menstrualcycle.Mood, val emoji: String, val label: String)

@Composable
private fun StepMood(
    selected: com.swastricare.health.domain.model.menstrualcycle.Mood?,
    onChange: (com.swastricare.health.domain.model.menstrualcycle.Mood?) -> Unit
) {
    val moods = listOf(
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.HAPPY, "\uD83D\uDE0A", "Happy"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.CALM, "\uD83D\uDE0C", "Calm"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.ENERGETIC, "\u26A1", "Energetic"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.ANXIOUS, "\uD83D\uDE30", "Anxious"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.SAD, "\uD83D\uDE22", "Sad"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.IRRITABLE, "\uD83D\uDE24", "Irritable"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.TIRED, "\uD83D\uDE34", "Tired"),
        MoodEntry(com.swastricare.health.domain.model.menstrualcycle.Mood.NEUTRAL, "\uD83D\uDE10", "Neutral")
    )
    Text("How's your mood?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    val chunked = moods.chunked(4)
    chunked.forEach { row ->
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            row.forEach { entry ->
                val mood = entry.mood
                val emoji = entry.emoji
                val label = entry.label
                val isSelected = selected == mood
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (isSelected) CyclePink.copy(alpha = 0.12f) else AppColors.surfaceVariant.copy(alpha = 0.4f))
                        .border(
                            width = if (isSelected) 1.5.dp else 0.dp,
                            color = if (isSelected) CyclePink else Color.Transparent,
                            shape = RoundedCornerShape(14.dp)
                        )
                        .clickable { onChange(if (isSelected) null else mood) }
                        .padding(vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(emoji, fontSize = 28.sp)
                    Text(
                        label,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) CyclePink else AppColors.onSurfaceVariant,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

// ── Step 5: Pain Level ──
@Composable
private fun StepPain(level: Int, onChange: (Int) -> Unit) {
    val emoji = when {
        level == 0 -> "\uD83D\uDE0A"
        level <= 2 -> "\uD83D\uDE42"
        level <= 4 -> "\uD83D\uDE10"
        level <= 6 -> "\uD83D\uDE1F"
        level <= 8 -> "\uD83D\uDE23"
        else -> "\uD83D\uDE2D"
    }
    Text("Pain level?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(16.dp))
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(emoji, fontSize = 56.sp)
            Text(
                "$level / 10",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = when {
                    level <= 3 -> FollicularColor
                    level <= 6 -> OvulationColor
                    else -> CyclePink
                }
            )
            Text(
                when {
                    level == 0 -> "No pain"
                    level <= 2 -> "Mild"
                    level <= 4 -> "Moderate"
                    level <= 6 -> "Uncomfortable"
                    level <= 8 -> "Severe"
                    else -> "Unbearable"
                },
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
        }
    }
    Spacer(Modifier.height(16.dp))
    Slider(
        value = level.toFloat(),
        onValueChange = { onChange(it.toInt()) },
        valueRange = 0f..10f,
        steps = 9,
        colors = SliderDefaults.colors(
            thumbColor = CyclePink,
            activeTrackColor = CyclePink,
            inactiveTrackColor = CyclePink.copy(alpha = 0.2f)
        )
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text("0", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
        Text("10", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
    }
}

// ── Step 6: Notes + Summary ──
@Composable
private fun StepNotes(notes: String, data: LogPeriodData, onChange: (String) -> Unit) {
    Text("Anything else?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    OutlinedTextField(
        value = notes,
        onValueChange = onChange,
        modifier = Modifier.fillMaxWidth(),
        placeholder = { Text("Optional notes...", color = AppColors.onSurfaceVariant) },
        minLines = 3,
        maxLines = 5,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = CyclePink,
            cursorColor = CyclePink
        ),
        shape = RoundedCornerShape(12.dp)
    )
    Spacer(Modifier.height(8.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text("Summary", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, color = CyclePink)
        SummaryRow("\uD83D\uDCC5 Start", data.startDate.toString())
        SummaryRow("\uD83E\uDE78 Flow", data.flowLevel.name.lowercase().replaceFirstChar { it.uppercase() })
        if (data.symptoms.isNotEmpty()) {
            SummaryRow("\uD83E\uDD15 Symptoms", "${data.symptoms.size} selected")
        }
        data.mood?.let { SummaryRow("\uD83D\uDE0A Mood", it.name.lowercase().replaceFirstChar { it.uppercase() }) }
        SummaryRow("\uD83D\uDC8A Pain", "${data.painLevel}/10")
    }
}

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium, color = AppColors.onSurface)
    }
}
