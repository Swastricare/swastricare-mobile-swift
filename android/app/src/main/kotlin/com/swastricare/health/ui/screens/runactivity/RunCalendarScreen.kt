package com.swastricare.health.ui.screens.runactivity

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Hiking
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.ai.Poppins
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - Activity Type Colors & Icons
// ─────────────────────────────────────

private val RunningGreen = Color(0xFF34C759)
private val WalkingTeal = Color(0xFF22C5A6)   // matches AI teal accent
private val CyclingPurple = Color(0xFF8B5CF6)
private val HikingOrange = Color(0xFFF97316)
private val DividerGray = Color(0xFFE5E8EB)

private fun workoutTypeColor(type: String): Color = when (type) {
    "running" -> RunningGreen
    "walking" -> WalkingTeal
    "cycling" -> CyclingPurple
    "hiking" -> HikingOrange
    else -> Color.Gray
}

private fun workoutTypeIcon(type: String): ImageVector = when (type) {
    "running" -> Icons.Default.DirectionsRun
    "walking" -> Icons.Default.DirectionsWalk
    "cycling" -> Icons.Default.DirectionsBike
    "hiking" -> Icons.Default.Hiking
    else -> Icons.Default.DirectionsRun
}

private fun workoutTypeLabel(type: String): String = when (type) {
    "running" -> "Run"
    "walking" -> "Walk"
    "cycling" -> "Cycle"
    "hiking" -> "Hike"
    else -> type.replaceFirstChar { it.uppercase() }
}

// ─────────────────────────────────────
// MARK: - RunCalendarScreen
// ─────────────────────────────────────

@Composable
fun RunCalendarScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToActivityDetail: (String) -> Unit = {},
    viewModel: RunCalendarViewModel = hiltViewModel()
) {
    TrackScreen("RunCalendar")
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    Box(modifier = Modifier.fillMaxSize().background(Color.White)) {
        Column(modifier = Modifier.fillMaxSize()) {
            CalendarHeader(onBack = onNavigateBack)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                Spacer(modifier = Modifier.height(4.dp))

                MonthNavigationHeader(
                    selectedMonth = uiState.selectedMonth,
                    canGoForward = !uiState.selectedMonth.equals(YearMonth.now()),
                    onPrevious = { viewModel.changeMonth(-1) },
                    onNext = { viewModel.changeMonth(1) }
                )

                CalendarGrid(
                    selectedMonth = uiState.selectedMonth,
                    workoutsByDate = uiState.workoutsByDate,
                    selectedDate = uiState.selectedDate,
                    onDateSelected = { viewModel.selectDate(it) }
                )

                ActivityTypeLegend(stats = uiState.monthlyStats)

                AnimatedVisibility(
                    visible = uiState.selectedDate != null,
                    enter = expandVertically(animationSpec = spring(dampingRatio = 0.8f)) + fadeIn(),
                    exit = shrinkVertically() + fadeOut()
                ) {
                    uiState.selectedDate?.let { date ->
                        SelectedDaySection(
                            date = date,
                            workouts = uiState.workoutsByDate[date] ?: emptyList(),
                            onWorkoutClick = onNavigateToActivityDetail
                        )
                    }
                }

                StatsOverviewSection(stats = uiState.monthlyStats)

                Spacer(modifier = Modifier.height(120.dp))
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Header
// ─────────────────────────────────────

@Composable
private fun CalendarHeader(onBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = AppColors.onBackground
            )
        }
        Column(modifier = Modifier.weight(1f).padding(start = 4.dp)) {
            Text(
                text = "Activity Calendar",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
            Text(
                text = "Track your activities and stay consistent",
                fontSize = 11.sp,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Month Nav (left-aligned compact)
// ─────────────────────────────────────

@Composable
private fun MonthNavigationHeader(
    selectedMonth: YearMonth,
    canGoForward: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    val haptic = LocalHapticFeedback.current

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        IconButton(
            onClick = {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                onPrevious()
            },
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Default.ChevronLeft,
                contentDescription = "Previous month",
                tint = AppColors.onBackground,
                modifier = Modifier.size(22.dp)
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Text(
            text = selectedMonth.format(DateTimeFormatter.ofPattern("MMMM yyyy")),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = Poppins,
            color = AppColors.onBackground
        )

        Spacer(modifier = Modifier.width(12.dp))

        IconButton(
            onClick = {
                if (canGoForward) {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onNext()
                }
            },
            enabled = canGoForward,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = "Next month",
                tint = if (canGoForward) AppColors.onBackground else AppColors.onSurfaceVariant.copy(alpha = 0.4f),
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Calendar Grid
// ─────────────────────────────────────

@Composable
private fun CalendarGrid(
    selectedMonth: YearMonth,
    workoutsByDate: Map<LocalDate, List<WorkoutSummary>>,
    selectedDate: LocalDate?,
    onDateSelected: (LocalDate) -> Unit
) {
    val today = LocalDate.now()
    val daysOfWeek = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

    val firstDayOfMonth = selectedMonth.atDay(1)
    // DayOfWeek: Mon=1..Sun=7. We want grid columns Sun=0..Sat=6.
    val firstDayIndex = (firstDayOfMonth.dayOfWeek.value % 7)
    val daysInMonth = selectedMonth.lengthOfMonth()

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        // Day-of-week headers
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            daysOfWeek.forEach { day ->
                Text(
                    text = day,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = Poppins,
                    color = AppColors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        val totalCells = firstDayIndex + daysInMonth
        val rows = (totalCells + 6) / 7

        for (row in 0 until rows) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                for (col in 0..6) {
                    val cellIndex = row * 7 + col
                    val dayNumber = cellIndex - firstDayIndex + 1

                    if (dayNumber in 1..daysInMonth) {
                        val date = selectedMonth.atDay(dayNumber)
                        val workouts = workoutsByDate[date]
                        val isToday = date == today
                        val isSelected = date == selectedDate

                        CalendarDayCell(
                            dayNumber = dayNumber,
                            workouts = workouts,
                            isToday = isToday,
                            isSelected = isSelected,
                            isFuture = date.isAfter(today),
                            onClick = { onDateSelected(date) },
                            modifier = Modifier.weight(1f)
                        )
                    } else {
                        Spacer(modifier = Modifier.weight(1f).height(48.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun CalendarDayCell(
    dayNumber: Int,
    workouts: List<WorkoutSummary>?,
    isToday: Boolean,
    isSelected: Boolean,
    isFuture: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val hasWorkouts = !workouts.isNullOrEmpty()
    val haptic = LocalHapticFeedback.current

    val textColor = when {
        isSelected -> Color.White
        isFuture -> AppColors.onSurfaceVariant.copy(alpha = 0.3f)
        else -> AppColors.onBackground
    }

    Column(
        modifier = modifier
            .height(54.dp)
            .clickable(enabled = !isFuture) {
                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onClick()
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .then(
                    when {
                        isSelected -> Modifier.background(AITeal)
                        isToday -> Modifier.border(1.5.dp, AITeal, CircleShape)
                        else -> Modifier
                    }
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "$dayNumber",
                fontSize = 13.sp,
                fontWeight = if (isToday || isSelected) FontWeight.Bold else FontWeight.Medium,
                fontFamily = Poppins,
                color = if (isToday && !isSelected) AITeal else textColor,
                textAlign = TextAlign.Center
            )
        }

        Spacer(modifier = Modifier.height(3.dp))

        if (hasWorkouts) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val uniqueTypes = workouts!!.map { it.type }.distinct().take(3)
                uniqueTypes.forEach { type ->
                    Canvas(modifier = Modifier.size(5.dp)) {
                        drawCircle(
                            color = if (isSelected) Color.White else workoutTypeColor(type),
                            radius = size.minDimension / 2f
                        )
                    }
                }
            }
        } else {
            Spacer(modifier = Modifier.height(5.dp))
        }
    }
}

// ─────────────────────────────────────
// MARK: - Activity Type Legend
// ─────────────────────────────────────

@Composable
private fun ActivityTypeLegend(stats: MonthlyStats) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        LegendItem(
            icon = Icons.Default.DirectionsRun,
            color = RunningGreen,
            count = stats.runsCount,
            label = "Runs"
        )
        LegendItem(
            icon = Icons.Default.DirectionsWalk,
            color = WalkingTeal,
            count = stats.walksCount,
            label = "Walks"
        )
        LegendItem(
            icon = Icons.Default.DirectionsBike,
            color = CyclingPurple,
            count = stats.cyclesCount,
            label = "Cycling"
        )
        LegendItem(
            icon = Icons.Default.Hiking,
            color = HikingOrange,
            count = stats.hikesCount,
            label = "Hike"
        )
    }
}

@Composable
private fun LegendItem(
    icon: ImageVector,
    color: Color,
    count: Int,
    label: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(16.dp)
        )
        Text(
            text = "$count",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = Poppins,
            color = AppColors.onBackground
        )
        Text(
            text = label,
            fontSize = 11.sp,
            fontFamily = Poppins,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - Selected Day Section
// ─────────────────────────────────────

@Composable
private fun SelectedDaySection(
    date: LocalDate,
    workouts: List<WorkoutSummary>,
    onWorkoutClick: (String) -> Unit
) {
    val dateFormatter = remember { DateTimeFormatter.ofPattern("MMM d, yyyy") }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = date.format(dateFormatter),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
            if (workouts.isNotEmpty()) {
                Text(
                    text = "${workouts.size} ${if (workouts.size == 1) "Activity" else "Activities"}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = Poppins,
                    color = AITeal
                )
            }
        }

        if (workouts.isNotEmpty()) {
            workouts.forEach { workout ->
                WorkoutCard(workout = workout, onClick = { onWorkoutClick(workout.id) })
            }
        } else {
            EmptyDayCard()
        }
    }
}

@Composable
private fun WorkoutCard(workout: WorkoutSummary, onClick: () -> Unit) {
    val typeColor = workoutTypeColor(workout.type)
    val haptic = LocalHapticFeedback.current
    val timeFormatter = remember { DateTimeFormatter.ofPattern("h:mm a") }
    val timeText = workout.startTime?.format(timeFormatter) ?: ""

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, DividerGray, RoundedCornerShape(14.dp))
            .clickable {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                onClick()
            }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(typeColor.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = workoutTypeIcon(workout.type),
                contentDescription = null,
                tint = typeColor,
                modifier = Modifier.size(20.dp)
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = workoutTitle(workout),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "${String.format("%.2f km", workout.distanceKm)}  ·  ${formatDuration(workout.durationMinutes)}",
                fontSize = 11.sp,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant
            )
        }

        Column(horizontalAlignment = Alignment.End) {
            if (timeText.isNotBlank()) {
                Text(
                    text = timeText,
                    fontSize = 12.sp,
                    fontFamily = Poppins,
                    color = AppColors.onSurfaceVariant
                )
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = "View",
                tint = AppColors.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

private fun workoutTitle(workout: WorkoutSummary): String {
    val timeOfDay = workout.startTime?.toLocalTime()?.hour
    val period = when (timeOfDay) {
        in 5..11 -> "Morning"
        in 12..16 -> "Afternoon"
        in 17..20 -> "Evening"
        in 21..23, in 0..4 -> "Night"
        else -> ""
    }
    val activityName = when (workout.type) {
        "running" -> "Run"
        "walking" -> "Walk"
        "cycling" -> "Cycle"
        "hiking" -> "Hike"
        else -> workoutTypeLabel(workout.type)
    }
    return if (period.isNotEmpty()) "$period $activityName" else activityName
}

@Composable
private fun EmptyDayCard() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, DividerGray, RoundedCornerShape(14.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = Icons.Default.DirectionsRun,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(28.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "No activities",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant
            )
            Text(
                text = "Rest day or no tracked workouts",
                fontSize = 11.sp,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant.copy(alpha = 0.7f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Stats Overview (2×2 grid)
// ─────────────────────────────────────

@Composable
private fun StatsOverviewSection(stats: MonthlyStats) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Stats Overview",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
            Text(
                text = "This Month",
                fontSize = 12.sp,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OverviewStatCard(
                icon = Icons.Default.DirectionsRun,
                tint = WalkingTeal,
                value = String.format("%.2f", stats.totalDistanceKm),
                label = "Total km",
                modifier = Modifier.weight(1f)
            )
            OverviewStatCard(
                icon = Icons.Default.Schedule,
                tint = WalkingTeal,
                value = formatDurationHms(stats.totalDurationMinutes),
                label = "Total Time",
                modifier = Modifier.weight(1f)
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OverviewStatCard(
                icon = Icons.Default.LocalFireDepartment,
                tint = HikingOrange,
                value = "${stats.totalCalories}",
                label = "Total kcal",
                modifier = Modifier.weight(1f)
            )
            OverviewStatCard(
                icon = Icons.Default.CalendarToday,
                tint = WalkingTeal,
                value = "${stats.totalWorkouts}",
                label = "Total Activities",
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun OverviewStatCard(
    icon: ImageVector,
    tint: Color,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, DividerGray, RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(20.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = value,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = Poppins,
                color = AppColors.onBackground
            )
            Text(
                text = label,
                fontSize = 11.sp,
                fontFamily = Poppins,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Formatting Helpers
// ─────────────────────────────────────

private fun formatDuration(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

/** HH:MM:SS — used by the Stats Overview "Total Time" tile. */
private fun formatDurationHms(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return String.format("%02d:%02d:00", hours, minutes)
}
