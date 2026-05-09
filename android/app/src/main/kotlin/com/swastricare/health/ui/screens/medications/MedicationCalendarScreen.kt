package com.swastricare.health.ui.screens.medications

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationDose
import com.swastricare.health.ui.theme.AITeal
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

private val Teal = AITeal
private val TealLight = Color(0xFFE8FAF6)
private val BackgroundGray = Color(0xFFF7FBFA)

// ─────────────────────────────────────
// MARK: - Screen
// ─────────────────────────────────────

@Composable
fun MedicationCalendarScreen(
    onBack: () -> Unit,
    onAddMedication: () -> Unit
) {
    val vm: MedicationAnalyticsViewModel = hiltViewModel()
    val state by vm.state.collectAsState()

    val view = LocalView.current
    if (!view.isInEditMode) {
        DisposableEffect(Unit) {
            val activity = view.context as? Activity ?: return@DisposableEffect onDispose {}
            val origStatus = activity.window.statusBarColor
            activity.window.statusBarColor = android.graphics.Color.WHITE
            WindowCompat.getInsetsController(activity.window, view).isAppearanceLightStatusBars = true
            onDispose { activity.window.statusBarColor = origStatus }
        }
    }

    Scaffold(
        containerColor = Color.White,
        floatingActionButton = {
            FloatingActionButton(
                onClick = onAddMedication,
                containerColor = Teal,
                contentColor = Color.White,
                shape = RoundedCornerShape(16.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                    Text("Add Medication", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                }
            }
        },
        floatingActionButtonPosition = FabPosition.Center
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(bottom = 100.dp)
        ) {
            item {
                CalendarTopBar(onBack = onBack)
            }
            item {
                MonthCalendar(
                    month = YearMonth.from(state.calendarMonth),
                    calendarData = state.calendarData,
                    selectedDate = state.calendarSelectedDate,
                    onPrev = { vm.navigateCalendarMonth(-1) },
                    onNext = { vm.navigateCalendarMonth(1) },
                    onDateSelected = { vm.selectCalendarDate(it) }
                )
                Spacer(Modifier.height(8.dp))
            }
            item {
                CalendarDayHeader(
                    date = state.calendarSelectedDate,
                    count = state.calendarDoses.size
                )
            }
            if (state.calendarDoses.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 40.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "No medications scheduled",
                            color = Color(0xFFAAAAAA),
                            fontSize = 15.sp
                        )
                    }
                }
            } else {
                items(state.calendarDoses) { dose ->
                    CalendarDoseRow(dose = dose)
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────

@Composable
private fun CalendarTopBar(onBack: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = Color(0xFF1A1A2E)
                )
            }
            Text(
                "Medication Calendar",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1A1A2E),
                modifier = Modifier.weight(1f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Month Calendar
// ─────────────────────────────────────

@Composable
private fun MonthCalendar(
    month: YearMonth,
    calendarData: Map<LocalDate, Float?>,
    selectedDate: LocalDate,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onDateSelected: (LocalDate) -> Unit
) {
    val today = LocalDate.now()
    val canGoNext = month.isBefore(YearMonth.from(today))

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(TealLight)
            .padding(horizontal = 16.dp, vertical = 20.dp)
    ) {
        // Month header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onPrev) {
                Icon(Icons.Default.ChevronLeft, contentDescription = "Prev", tint = Teal)
            }
            Text(
                month.format(DateTimeFormatter.ofPattern("MMMM yyyy")),
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = Color(0xFF1A1A2E)
            )
            IconButton(onClick = onNext, enabled = canGoNext) {
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = "Next",
                    tint = if (canGoNext) Teal else Color(0xFFCCCCCC)
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        // Day headers
        val dayLabels = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        Row(modifier = Modifier.fillMaxWidth()) {
            dayLabels.forEach { d ->
                Text(
                    d,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF888888)
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        // Calendar grid
        val firstDay = month.atDay(1)
        val startOffset = firstDay.dayOfWeek.value % 7 // Sunday=0
        val daysInMonth = month.lengthOfMonth()
        val cells = startOffset + daysInMonth

        for (row in 0 until (cells + 6) / 7) {
            Row(modifier = Modifier.fillMaxWidth()) {
                for (col in 0 until 7) {
                    val cellIdx = row * 7 + col
                    val dayNum = cellIdx - startOffset + 1
                    if (dayNum < 1 || dayNum > daysInMonth) {
                        Spacer(Modifier.weight(1f))
                    } else {
                        val date = month.atDay(dayNum)
                        val isFuture = date.isAfter(today)
                        val isSelected = date == selectedDate
                        val adherence = calendarData[date]
                        CalendarCell(
                            day = dayNum,
                            isSelected = isSelected,
                            isToday = date == today,
                            isFuture = isFuture,
                            adherence = adherence,
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f),
                            onClick = { if (!isFuture) onDateSelected(date) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CalendarCell(
    day: Int,
    isSelected: Boolean,
    isToday: Boolean,
    isFuture: Boolean,
    adherence: Float?,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val dotColor = when {
        adherence == null -> Color.Transparent
        adherence >= 1f -> Teal
        adherence > 0f -> Color(0xFFFFB347)
        else -> Color(0xFFFF6B6B)
    }
    val textColor = when {
        isSelected -> Color.White
        isToday -> Teal
        isFuture -> Color(0xFFCCCCCC)
        else -> Color(0xFF333333)
    }
    val bgColor = when {
        isSelected -> Teal
        isToday -> Teal.copy(alpha = 0.1f)
        else -> Color.Transparent
    }

    Column(
        modifier = modifier
            .padding(2.dp)
            .clip(CircleShape)
            .background(bgColor)
            .clickable(enabled = !isFuture) { onClick() },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            "$day",
            fontSize = 14.sp,
            fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Normal,
            color = textColor
        )
        if (dotColor != Color.Transparent) {
            Spacer(Modifier.height(2.dp))
            Box(
                modifier = Modifier
                    .size(4.dp)
                    .clip(CircleShape)
                    .background(if (isSelected) Color.White.copy(alpha = 0.8f) else dotColor)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Day Header + Dose List
// ─────────────────────────────────────

@Composable
private fun CalendarDayHeader(date: LocalDate, count: Int) {
    val today = LocalDate.now()
    val label = when (date) {
        today -> "Today"
        today.minusDays(1) -> "Yesterday"
        else -> date.format(DateTimeFormatter.ofPattern("EEEE, d MMM"))
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
            color = Color(0xFF1A1A2E)
        )
        Text(
            "$count Medication${if (count != 1) "s" else ""}",
            fontSize = 13.sp,
            color = Teal,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun CalendarDoseRow(dose: MedicationDose) {
    val isTaken = dose.status == AdherenceStatus.TAKEN ||
        dose.status == AdherenceStatus.LATE ||
        dose.status == AdherenceStatus.EARLY
    val isMissed = dose.status == AdherenceStatus.MISSED
    val isSkipped = dose.status == AdherenceStatus.SKIPPED
    val periodLabel = dose.scheduledTime.format(DateTimeFormatter.ofPattern("a")).uppercase()

    val cardBg = when {
        isTaken -> TealLight
        isMissed -> Color(0xFFFFF0EF)
        isSkipped -> Color(0xFFFFF8EE)
        else -> Color(0xFFF8F8F8)
    }
    val iconTint = when {
        isTaken -> Teal
        isMissed -> Color(0xFFFF3B30)
        isSkipped -> Color(0xFFFF9500)
        else -> Color(0xFFCCCCCC)
    }
    val icon = when {
        isTaken -> Icons.Default.CheckCircle
        isMissed -> Icons.Default.Cancel
        else -> Icons.Default.RadioButtonUnchecked
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Time column
        Column(
            modifier = Modifier.width(70.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                dose.scheduledTime.format(DateTimeFormatter.ofPattern("hh:mm")),
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                color = Color(0xFF333333)
            )
            Text(
                periodLabel,
                fontSize = 11.sp,
                color = Color(0xFF888888)
            )
        }

        Spacer(Modifier.width(12.dp))

        // Card
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(14.dp))
                .background(cardBg)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    dose.medicationName,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp,
                    color = Color(0xFF1A1A2E)
                )
                val subtitle = when {
                    isMissed -> "Missed"
                    isSkipped -> "Skipped"
                    dose.dosage.isNotBlank() -> dose.dosage
                    else -> null
                }
                if (subtitle != null) {
                    Text(
                        subtitle,
                        fontSize = 12.sp,
                        color = if (isMissed) Color(0xFFFF3B30) else Color(0xFF888888),
                        fontWeight = if (isMissed) FontWeight.SemiBold else FontWeight.Normal
                    )
                }
            }
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}
