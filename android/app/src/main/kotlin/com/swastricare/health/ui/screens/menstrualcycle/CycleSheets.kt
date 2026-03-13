package com.swastricare.health.ui.screens.menstrualcycle

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    onSave: (cycleLength: Int, periodLength: Int) -> Unit,
    onUpdateNotifications: (period: Boolean?, fertile: Boolean?, pms: Boolean?) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var cycleLength by remember { mutableFloatStateOf(settings.averageCycleLength.toFloat()) }
    var periodLength by remember { mutableFloatStateOf(settings.averagePeriodLength.toFloat()) }
    var periodReminder by remember { mutableStateOf(settings.periodReminderEnabled) }
    var fertileReminder by remember { mutableStateOf(settings.fertileWindowReminderEnabled) }
    var pmsReminder by remember { mutableStateOf(settings.pmsReminderEnabled) }

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

            // Save Button
            Button(
                onClick = {
                    onSave(cycleLength.toInt(), periodLength.toInt())
                    onUpdateNotifications(periodReminder, fertileReminder, pmsReminder)
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
