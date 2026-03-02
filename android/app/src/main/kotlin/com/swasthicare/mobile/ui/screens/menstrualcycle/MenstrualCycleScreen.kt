package com.swasthicare.mobile.ui.screens.menstrualcycle

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.*
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

private val CyclePurple = Color(0xFFBF5AF2)
private val CycleRed = Color(0xFFFF375F)
private val CycleGreen = Color(0xFF30D158)
private val CycleBlue = Color(0xFF0A84FF)
private val CycleOrange = Color(0xFFFF9F0A)

// ------------------------------------
// MARK: - Main Screen
// ------------------------------------

@Composable
fun MenstrualCycleScreen(
    onNavigateBack: () -> Unit
) {
    val vm = remember { AppContainer.menstrualCycleViewModel }
    val uiState by vm.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack, "Back",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    "Cycle Tracker",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                IconButton(onClick = { vm.showSettingsSheet() }) {
                    Icon(Icons.Default.Settings, "Settings", tint = CyclePurple)
                }
            }

            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = CyclePurple)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    // Phase Status Card
                    item {
                        CycleStatusCard(
                            phase = uiState.currentPhase,
                            dayOfCycle = uiState.currentDayOfCycle,
                            daysUntilNext = uiState.daysUntilNextPeriod,
                            hasActivePeriod = uiState.cycles.any { it.isActive },
                            onLogPeriodStart = { vm.logPeriodStart() },
                            onLogPeriodEnd = { vm.logPeriodEnd() },
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                        )
                    }

                    // Calendar
                    item {
                        Spacer(Modifier.height(16.dp))
                        MonthlyCalendar(
                            selectedMonth = uiState.selectedMonth,
                            calendarData = uiState.calendarData,
                            selectedDate = uiState.selectedDate,
                            onDateSelected = { vm.selectDate(it) },
                            onPreviousMonth = { vm.navigateMonth(false) },
                            onNextMonth = { vm.navigateMonth(true) },
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Phase Info Card
                    item {
                        Spacer(Modifier.height(16.dp))
                        PhaseInfoCard(
                            phase = uiState.currentPhase,
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Quick Actions
                    item {
                        Spacer(Modifier.height(16.dp))
                        QuickActionsRow(
                            onAddLog = { vm.showDailyLogSheet() },
                            onViewStats = { vm.showStatisticsSheet() },
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }

                    // Selected Day Log
                    uiState.selectedDayLog?.let { log ->
                        item {
                            Spacer(Modifier.height(16.dp))
                            DayLogCard(
                                log = log,
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                        }
                    }

                    // Predictions Card
                    uiState.predictions?.let { predictions ->
                        item {
                            Spacer(Modifier.height(16.dp))
                            PredictionsCard(
                                predictions = predictions,
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                        }
                    }

                    // Statistics Summary
                    if (uiState.statistics.totalCyclesTracked > 0) {
                        item {
                            Spacer(Modifier.height(16.dp))
                            StatisticsSummaryCard(
                                statistics = uiState.statistics,
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                        }
                    }
                }
            }
        }

        // Daily Log Bottom Sheet
        if (uiState.showDailyLogSheet) {
            DailyLogBottomSheet(
                existingLog = uiState.selectedDayLog,
                onSave = { flow, symptoms, mood, pain, notes ->
                    vm.addDailyLog(flow, symptoms, mood, pain, notes)
                },
                onDismiss = { vm.hideDailyLogSheet() }
            )
        }

        // Settings Bottom Sheet
        if (uiState.showSettingsSheet) {
            SettingsBottomSheet(
                settings = uiState.settings,
                onSave = { vm.updateSettings(it) },
                onDismiss = { vm.hideSettingsSheet() }
            )
        }

        // Statistics Bottom Sheet
        if (uiState.showStatisticsSheet) {
            StatisticsBottomSheet(
                statistics = uiState.statistics,
                onDismiss = { vm.hideStatisticsSheet() }
            )
        }

        // Error snackbar
        uiState.error?.let { errorMsg ->
            Snackbar(
                modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                action = { TextButton(onClick = { vm.clearError() }) { Text("Dismiss") } }
            ) { Text(errorMsg) }
        }
    }
}

// ------------------------------------
// MARK: - Cycle Status Card
// ------------------------------------

@Composable
private fun CycleStatusCard(
    phase: CyclePhase,
    dayOfCycle: Int?,
    daysUntilNext: Int?,
    hasActivePeriod: Boolean,
    onLogPeriodStart: () -> Unit,
    onLogPeriodEnd: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "statusPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "statusScale"
    )

    val phaseColor = when (phase) {
        CyclePhase.MENSTRUAL -> CycleRed
        CyclePhase.FOLLICULAR -> CycleGreen
        CyclePhase.OVULATION -> CycleBlue
        CyclePhase.LUTEAL -> CycleOrange
        CyclePhase.UNKNOWN -> CyclePurple
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 24.dp)
    ) {
        // Gradient overlay
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(
                    brush = Brush.horizontalGradient(
                        colors = listOf(
                            phaseColor.copy(alpha = 0.4f),
                            phaseColor.copy(alpha = 0.1f)
                        )
                    )
                )
                .padding(20.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            phase.emoji + " " + phase.displayName,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        dayOfCycle?.let {
                            Text(
                                "Day $it of cycle",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                            )
                        }
                    }

                    // Animated phase indicator
                    Box(
                        modifier = Modifier
                            .size(60.dp)
                            .scale(pulseScale)
                            .background(phaseColor.copy(alpha = 0.3f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(phase.emoji, fontSize = 24.sp)
                    }
                }

                // Next period prediction
                daysUntilNext?.let { days ->
                    if (days > 0 && !hasActivePeriod) {
                        Text(
                            "Next period in $days days",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }

                // Log Period Button
                Button(
                    onClick = { if (hasActivePeriod) onLogPeriodEnd() else onLogPeriodStart() },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (hasActivePeriod) CycleRed else CyclePurple
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(
                        if (hasActivePeriod) Icons.Default.Stop else Icons.Default.PlayArrow,
                        null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        if (hasActivePeriod) "End Period" else "Log Period Start",
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

// ------------------------------------
// MARK: - Monthly Calendar
// ------------------------------------

@Composable
private fun MonthlyCalendar(
    selectedMonth: YearMonth,
    calendarData: List<CalendarDayData>,
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    modifier: Modifier = Modifier
) {
    val monthFormatter = DateTimeFormatter.ofPattern("MMMM yyyy")

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Month navigation
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onPreviousMonth) {
                Icon(Icons.Default.ChevronLeft, "Previous")
            }
            Text(
                selectedMonth.atDay(1).format(monthFormatter),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = onNextMonth) {
                Icon(Icons.Default.ChevronRight, "Next")
            }
        }

        // Day of week headers
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf("S", "M", "T", "W", "T", "F", "S").forEach { day ->
                Text(
                    day,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(36.dp),
                    textAlign = TextAlign.Center
                )
            }
        }

        // Calendar grid
        val firstDayOfMonth = selectedMonth.atDay(1)
        val startDayOffset = (firstDayOfMonth.dayOfWeek.value % 7) // Sunday = 0

        val totalSlots = startDayOffset + selectedMonth.lengthOfMonth()
        val rows = (totalSlots + 6) / 7

        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            for (row in 0 until rows) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    for (col in 0..6) {
                        val index = row * 7 + col - startDayOffset
                        if (index in 0 until selectedMonth.lengthOfMonth()) {
                            val dayData = calendarData.getOrNull(index)
                            val date = selectedMonth.atDay(index + 1)
                            CalendarDayCell(
                                day = index + 1,
                                dayData = dayData,
                                isSelected = date == selectedDate,
                                isToday = date == LocalDate.now(),
                                onClick = { onDateSelected(date) }
                            )
                        } else {
                            Spacer(modifier = Modifier.size(36.dp))
                        }
                    }
                }
            }
        }

        // Legend
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            CalendarLegendItem(color = CycleRed, label = "Period")
            CalendarLegendItem(color = CycleGreen, label = "Fertile")
            CalendarLegendItem(color = CycleBlue, label = "Ovulation")
            CalendarLegendItem(color = CycleRed.copy(alpha = 0.4f), label = "Predicted")
        }
    }
}

@Composable
private fun CalendarDayCell(
    day: Int,
    dayData: CalendarDayData?,
    isSelected: Boolean,
    isToday: Boolean,
    onClick: () -> Unit
) {
    val backgroundColor = when {
        dayData?.isCurrentPeriod == true -> CycleRed.copy(alpha = 0.7f)
        dayData?.isPredicted == true -> CycleRed.copy(alpha = 0.3f)
        dayData?.phase == CyclePhase.OVULATION -> CycleBlue.copy(alpha = 0.5f)
        dayData?.phase == CyclePhase.FOLLICULAR && dayData.date.isAfter(LocalDate.now().minusDays(3)) -> CycleGreen.copy(alpha = 0.3f)
        else -> Color.Transparent
    }

    val textColor = when {
        dayData?.isCurrentPeriod == true -> Color.White
        isSelected -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurface
    }

    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(backgroundColor)
            .then(
                if (isSelected) Modifier.border(2.dp, CyclePurple, CircleShape)
                else if (isToday) Modifier.border(1.dp, MaterialTheme.colorScheme.primary, CircleShape)
                else Modifier
            )
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "$day",
                style = MaterialTheme.typography.bodySmall,
                fontWeight = if (isToday || isSelected) FontWeight.Bold else FontWeight.Normal,
                color = textColor
            )
            if (dayData?.hasLog == true) {
                Box(
                    modifier = Modifier
                        .size(4.dp)
                        .background(CyclePurple, CircleShape)
                )
            }
        }
    }
}

@Composable
private fun CalendarLegendItem(color: Color, label: String) {
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
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// ------------------------------------
// MARK: - Phase Info Card
// ------------------------------------

@Composable
private fun PhaseInfoCard(
    phase: CyclePhase,
    modifier: Modifier = Modifier
) {
    val tips = when (phase) {
        CyclePhase.MENSTRUAL -> listOf(
            "Take it easy with gentle exercise",
            "Stay hydrated and eat iron-rich foods",
            "Use a heating pad for cramps"
        )
        CyclePhase.FOLLICULAR -> listOf(
            "Great time for high-intensity workouts",
            "Your energy is building up",
            "Focus on protein-rich meals"
        )
        CyclePhase.OVULATION -> listOf(
            "Peak energy and confidence levels",
            "Great time for social activities",
            "Stay hydrated"
        )
        CyclePhase.LUTEAL -> listOf(
            "You may crave carbs and comfort food",
            "Gentle yoga and walking help with PMS",
            "Prioritize sleep and relaxation"
        )
        CyclePhase.UNKNOWN -> listOf(
            "Log your period to start tracking",
            "Track symptoms for better predictions"
        )
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Phase Guide",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Text(
            phase.description,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            tips.forEach { tip ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        null,
                        tint = CycleGreen,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        tip,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
                    )
                }
            }
        }
    }
}

// ------------------------------------
// MARK: - Quick Actions
// ------------------------------------

@Composable
private fun QuickActionsRow(
    onAddLog: () -> Unit,
    onViewStats: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        QuickActionButton(
            icon = Icons.Default.Edit,
            label = "Add Log",
            color = CyclePurple,
            onClick = onAddLog,
            modifier = Modifier.weight(1f)
        )
        QuickActionButton(
            icon = Icons.Default.BarChart,
            label = "Statistics",
            color = CycleBlue,
            onClick = onViewStats,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun QuickActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .height(70.dp)
            .glass(cornerRadius = 16.dp)
            .clickable { onClick() }
            .padding(12.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(color.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = color, modifier = Modifier.size(18.dp))
            }
            Text(
                label,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

// ------------------------------------
// MARK: - Day Log Card
// ------------------------------------

@Composable
private fun DayLogCard(
    log: MenstrualDailyLog,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(
            "Log for ${log.date.format(DateTimeFormatter.ofPattern("MMM d, yyyy"))}",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )

        if (log.flowLevel != FlowLevel.NONE) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Flow:", style = MaterialTheme.typography.bodyMedium)
                Text(
                    log.flowLevel.emoji + " " + log.flowLevel.displayName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        if (log.symptoms.isNotEmpty()) {
            Text("Symptoms:", style = MaterialTheme.typography.bodyMedium)
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                log.symptoms.take(4).forEach { symptom ->
                    Box(
                        modifier = Modifier
                            .background(CyclePurple.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            "${symptom.emoji} ${symptom.displayName}",
                            style = MaterialTheme.typography.labelSmall
                        )
                    }
                }
            }
        }

        log.mood?.let { mood ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Mood:", style = MaterialTheme.typography.bodyMedium)
                Text(
                    "${mood.emoji} ${mood.displayName}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        if (log.painLevel > 0) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Pain Level:", style = MaterialTheme.typography.bodyMedium)
                Text(
                    "${log.painLevel}/10",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (log.painLevel > 5) CycleRed else MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}

// ------------------------------------
// MARK: - Predictions Card
// ------------------------------------

@Composable
private fun PredictionsCard(
    predictions: CyclePrediction,
    modifier: Modifier = Modifier
) {
    val dateFormatter = DateTimeFormatter.ofPattern("MMM d")

    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Predictions",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            PredictionItem(
                emoji = "🩸",
                label = "Next Period",
                date = predictions.nextPeriodDate.format(dateFormatter),
                color = CycleRed
            )
            PredictionItem(
                emoji = "🌸",
                label = "Ovulation",
                date = predictions.ovulationDate.format(dateFormatter),
                color = CycleBlue
            )
            PredictionItem(
                emoji = "🌱",
                label = "Fertile Window",
                date = "${predictions.fertileWindowStart.format(dateFormatter)} - ${predictions.fertileWindowEnd.format(dateFormatter)}",
                color = CycleGreen
            )
        }
    }
}

@Composable
private fun PredictionItem(
    emoji: String,
    label: String,
    date: String,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(emoji, fontSize = 24.sp)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            date,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = color,
            textAlign = TextAlign.Center
        )
    }
}

// ------------------------------------
// MARK: - Statistics Summary Card
// ------------------------------------

@Composable
private fun StatisticsSummaryCard(
    statistics: CycleStatistics,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Cycle Statistics",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatItem(
                value = String.format("%.0f", statistics.averageCycleLength),
                label = "Avg Cycle",
                unit = "days"
            )
            StatItem(
                value = String.format("%.0f", statistics.averagePeriodLength),
                label = "Avg Period",
                unit = "days"
            )
            StatItem(
                value = "${statistics.totalCyclesTracked}",
                label = "Total",
                unit = "cycles"
            )
        }
    }
}

@Composable
private fun StatItem(value: String, label: String, unit: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            value,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = CyclePurple
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            unit,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
        )
    }
}

// ------------------------------------
// MARK: - Daily Log Bottom Sheet
// ------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DailyLogBottomSheet(
    existingLog: MenstrualDailyLog?,
    onSave: (FlowLevel, List<MenstrualSymptom>, MenstrualMood?, Int, String?) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedFlow by remember { mutableStateOf(existingLog?.flowLevel ?: FlowLevel.NONE) }
    var selectedSymptoms by remember { mutableStateOf(existingLog?.symptoms?.toSet() ?: emptySet()) }
    var selectedMood by remember { mutableStateOf(existingLog?.mood) }
    var painLevel by remember { mutableFloatStateOf((existingLog?.painLevel ?: 0).toFloat()) }
    var notes by remember { mutableStateOf(existingLog?.notes ?: "") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        LazyColumn(
            modifier = Modifier.padding(horizontal = 20.dp),
            contentPadding = PaddingValues(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            item {
                Text(
                    "Daily Log",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            // Flow Level
            item {
                Text(
                    "Flow Level",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FlowLevel.entries.forEach { flow ->
                        FilterChip(
                            selected = selectedFlow == flow,
                            onClick = { selectedFlow = flow },
                            label = { Text(flow.emoji + " " + flow.displayName, fontSize = 11.sp) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = CycleRed.copy(alpha = 0.2f)
                            ),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // Symptoms
            item {
                Text(
                    "Symptoms",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(8.dp))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    MenstrualSymptom.entries.chunked(3).forEach { row ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            row.forEach { symptom ->
                                FilterChip(
                                    selected = symptom in selectedSymptoms,
                                    onClick = {
                                        selectedSymptoms = if (symptom in selectedSymptoms) {
                                            selectedSymptoms - symptom
                                        } else {
                                            selectedSymptoms + symptom
                                        }
                                    },
                                    label = { Text("${symptom.emoji} ${symptom.displayName}", fontSize = 11.sp) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = CyclePurple.copy(alpha = 0.2f)
                                    ),
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            // Fill remaining space if row is incomplete
                            repeat(3 - row.size) {
                                Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // Mood
            item {
                Text(
                    "Mood",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(8.dp))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    MenstrualMood.entries.chunked(4).forEach { row ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            row.forEach { mood ->
                                FilterChip(
                                    selected = selectedMood == mood,
                                    onClick = { selectedMood = if (selectedMood == mood) null else mood },
                                    label = { Text("${mood.emoji} ${mood.displayName}", fontSize = 11.sp) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = CycleBlue.copy(alpha = 0.2f)
                                    ),
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            repeat(4 - row.size) {
                                Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // Pain Level
            item {
                Text(
                    "Pain Level: ${painLevel.toInt()}/10",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(4.dp))
                Slider(
                    value = painLevel,
                    onValueChange = { painLevel = it },
                    valueRange = 0f..10f,
                    steps = 9,
                    colors = SliderDefaults.colors(
                        thumbColor = CyclePurple,
                        activeTrackColor = CyclePurple
                    )
                )
            }

            // Notes
            item {
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    minLines = 2,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = CyclePurple,
                        cursorColor = CyclePurple
                    )
                )
            }

            // Save Button
            item {
                Button(
                    onClick = {
                        onSave(
                            selectedFlow,
                            selectedSymptoms.toList(),
                            selectedMood,
                            painLevel.toInt(),
                            notes.ifBlank { null }
                        )
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = CyclePurple),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth().height(50.dp)
                ) {
                    Text("Save Log", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// ------------------------------------
// MARK: - Settings Bottom Sheet
// ------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsBottomSheet(
    settings: MenstrualSettings,
    onSave: (MenstrualSettings) -> Unit,
    onDismiss: () -> Unit
) {
    var cycleLength by remember { mutableFloatStateOf(settings.averageCycleLength.toFloat()) }
    var periodLength by remember { mutableFloatStateOf(settings.averagePeriodLength.toFloat()) }
    var reminderEnabled by remember { mutableStateOf(settings.reminderEnabled) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Text(
                "Cycle Settings",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    "Average Cycle Length: ${cycleLength.toInt()} days",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Slider(
                    value = cycleLength,
                    onValueChange = { cycleLength = it },
                    valueRange = 21f..35f,
                    steps = 13,
                    colors = SliderDefaults.colors(
                        thumbColor = CyclePurple,
                        activeTrackColor = CyclePurple
                    )
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    "Average Period Length: ${periodLength.toInt()} days",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Slider(
                    value = periodLength,
                    onValueChange = { periodLength = it },
                    valueRange = 2f..10f,
                    steps = 7,
                    colors = SliderDefaults.colors(
                        thumbColor = CyclePurple,
                        activeTrackColor = CyclePurple
                    )
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "Period Reminders",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Switch(
                    checked = reminderEnabled,
                    onCheckedChange = { reminderEnabled = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = CyclePurple)
                )
            }

            Button(
                onClick = {
                    onSave(
                        settings.copy(
                            averageCycleLength = cycleLength.toInt(),
                            averagePeriodLength = periodLength.toInt(),
                            reminderEnabled = reminderEnabled
                        )
                    )
                },
                colors = ButtonDefaults.buttonColors(containerColor = CyclePurple),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth().height(50.dp)
            ) {
                Text("Save Settings", fontWeight = FontWeight.Bold)
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

// ------------------------------------
// MARK: - Statistics Bottom Sheet
// ------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StatisticsBottomSheet(
    statistics: CycleStatistics,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "Cycle Statistics",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            if (statistics.totalCyclesTracked == 0) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("📊", fontSize = 48.sp)
                    Text(
                        "No cycle data yet",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                    Text(
                        "Log at least 2 cycles to see statistics",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                    )
                }
            } else {
                StatRow("Average Cycle Length", "${String.format("%.1f", statistics.averageCycleLength)} days")
                StatRow("Average Period Length", "${String.format("%.1f", statistics.averagePeriodLength)} days")
                StatRow("Longest Cycle", "${statistics.longestCycle} days")
                StatRow("Shortest Cycle", "${statistics.shortestCycle} days")
                StatRow("Total Cycles Tracked", "${statistics.totalCyclesTracked}")
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(12.dp)
            )
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = CyclePurple
        )
    }
}
