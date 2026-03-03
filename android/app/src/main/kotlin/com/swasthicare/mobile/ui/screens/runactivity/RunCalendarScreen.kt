package com.swasthicare.mobile.ui.screens.runactivity

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PremiumColor
import kotlinx.coroutines.delay
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

// ─────────────────────────────────────
// MARK: - Activity Type Colors & Icons
// ─────────────────────────────────────

private val RunningGreen = Color(0xFF34C759)
private val WalkingBlue = Color(0xFF007AFF)
private val CyclingOrange = Color(0xFFFF9500)
private val AccentIndigo = Color(0xFF4F46E5)

private fun workoutTypeColor(type: String): Color = when (type) {
    "running" -> RunningGreen
    "walking" -> WalkingBlue
    "cycling" -> CyclingOrange
    else -> Color.Gray
}

private fun workoutTypeIcon(type: String): ImageVector = when (type) {
    "running" -> Icons.Default.DirectionsRun
    "walking" -> Icons.Default.DirectionsWalk
    "cycling" -> Icons.Default.DirectionsBike
    else -> Icons.Default.DirectionsRun
}

private fun workoutTypeLabel(type: String): String = when (type) {
    "running" -> "Run"
    "walking" -> "Walk"
    "cycling" -> "Cycle"
    else -> type.replaceFirstChar { it.uppercase() }
}

// ─────────────────────────────────────
// MARK: - RunCalendarScreen
// ─────────────────────────────────────

@Composable
fun RunCalendarScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToActivityDetail: (String) -> Unit = {},
    viewModel: RunCalendarViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    Box(modifier = Modifier.fillMaxSize()) {
        // 1. Premium Animated Background
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // 2. Top Bar
            TopBar(onNavigateBack = onNavigateBack)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                Spacer(modifier = Modifier.height(4.dp))

                // 3. Month Navigation
                MonthNavigationHeader(
                    selectedMonth = uiState.selectedMonth,
                    activeDays = uiState.monthlyStats.activeDays,
                    canGoForward = !uiState.selectedMonth.equals(YearMonth.now()),
                    onPrevious = { viewModel.changeMonth(-1) },
                    onNext = { viewModel.changeMonth(1) }
                )

                // 4. Calendar Grid
                CalendarGrid(
                    selectedMonth = uiState.selectedMonth,
                    workoutsByDate = uiState.workoutsByDate,
                    selectedDate = uiState.selectedDate,
                    onDateSelected = { viewModel.selectDate(it) }
                )

                // 5. Selected Date Detail
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

                // 6. Monthly Summary
                MonthlySummarySection(stats = uiState.monthlyStats)

                // Extra bottom space for scrolling past bottom nav
                Spacer(modifier = Modifier.height(120.dp))
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────

@Composable
private fun TopBar(onNavigateBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = MaterialTheme.colorScheme.onBackground
            )
        }

        Text(
            text = "Activity Calendar",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.weight(1f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Month Navigation Header
// ─────────────────────────────────────

@Composable
private fun MonthNavigationHeader(
    selectedMonth: YearMonth,
    activeDays: Int,
    canGoForward: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "headerAlpha"
    )
    val offsetY by animateFloatAsState(
        targetValue = if (isVisible) 0f else 10f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "headerOffset"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; translationY = offsetY },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        // Previous month button
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(AccentIndigo.copy(alpha = 0.1f))
                .clickable { onPrevious() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.ChevronLeft,
                contentDescription = "Previous month",
                tint = AccentIndigo,
                modifier = Modifier.size(20.dp)
            )
        }

        // Month / Year label
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = selectedMonth.format(DateTimeFormatter.ofPattern("MMMM yyyy")),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onBackground
            )
            Text(
                text = "$activeDays active days",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Next month button
        val nextEnabled = canGoForward
        val nextTint = if (nextEnabled) AccentIndigo else Color.Gray
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(nextTint.copy(alpha = 0.1f))
                .then(if (nextEnabled) Modifier.clickable { onNext() } else Modifier),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = "Next month",
                tint = nextTint,
                modifier = Modifier.size(20.dp)
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
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(100)
        isVisible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "gridAlpha"
    )
    val offsetY by animateFloatAsState(
        targetValue = if (isVisible) 0f else 15f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "gridOffset"
    )

    val today = LocalDate.now()
    val daysOfWeek = listOf("S", "M", "T", "W", "T", "F", "S")

    // Build the grid: leading blanks + days of month
    val firstDayOfMonth = selectedMonth.atDay(1)
    // Sunday = 7 in DayOfWeek, but we want Sunday = 0 for our grid
    val firstDayIndex = (firstDayOfMonth.dayOfWeek.value % 7) // Monday=1..Sunday=7 -> Sun=0,Mon=1..Sat=6
    val daysInMonth = selectedMonth.lengthOfMonth()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; translationY = offsetY }
            .glass(cornerRadius = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Day-of-week headers
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            daysOfWeek.forEach { day ->
                Text(
                    text = day,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Calendar rows
        val totalCells = firstDayIndex + daysInMonth
        val rows = (totalCells + 6) / 7

        for (row in 0 until rows) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
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
                        // Empty cell
                        Spacer(modifier = Modifier.weight(1f).height(48.dp))
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Calendar Day Cell
// ─────────────────────────────────────

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
    val isDark = isSystemInDarkTheme()

    val textColor = when {
        isSelected -> Color.White
        isFuture -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
        isToday -> AccentIndigo
        else -> MaterialTheme.colorScheme.onSurface
    }

    val backgroundColor = when {
        isSelected -> AccentIndigo
        else -> Color.Transparent
    }

    Column(
        modifier = modifier
            .height(48.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(backgroundColor)
            .then(
                if (isToday && !isSelected) {
                    Modifier.border(
                        width = 2.dp,
                        color = AccentIndigo.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(10.dp)
                    )
                } else Modifier
            )
            .clickable(enabled = !isFuture) { onClick() },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "$dayNumber",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Medium,
            color = textColor,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(2.dp))

        // Activity dots
        if (hasWorkouts) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Show up to 3 dots based on workout types
                val uniqueTypes = workouts!!.map { it.type }.distinct().take(3)
                uniqueTypes.forEach { type ->
                    Canvas(modifier = Modifier.size(6.dp)) {
                        drawCircle(
                            color = if (isSelected) Color.White.copy(alpha = 0.9f) else workoutTypeColor(type),
                            radius = size.minDimension / 2f
                        )
                    }
                }
            }
        } else {
            // Invisible placeholder so layout doesn't shift
            Spacer(modifier = Modifier.height(6.dp))
        }
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
    val dateFormatter = remember { DateTimeFormatter.ofPattern("EEEE, d MMMM") }
    val totalDistance = workouts.sumOf { it.distanceKm }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = date.format(dateFormatter),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onBackground
            )
            if (workouts.isNotEmpty()) {
                Text(
                    text = String.format("%.1f km", totalDistance),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = AccentIndigo
                )
            }
        }

        if (workouts.isNotEmpty()) {
            workouts.forEachIndexed { index, workout ->
                WorkoutCard(
                    workout = workout,
                    delay = index * 80,
                    onClick = { onWorkoutClick(workout.id) }
                )
            }
        } else {
            EmptyDayCard()
        }
    }
}

// ─────────────────────────────────────
// MARK: - Workout Card
// ─────────────────────────────────────

@Composable
private fun WorkoutCard(
    workout: WorkoutSummary,
    delay: Int = 0,
    onClick: () -> Unit
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(delay.toLong())
        isVisible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "cardAlpha"
    )
    val scale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.95f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "cardScale"
    )
    val offsetY by animateFloatAsState(
        targetValue = if (isVisible) 0f else 12f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "cardOffset"
    )

    val typeColor = workoutTypeColor(workout.type)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                this.alpha = alpha
                scaleX = scale
                scaleY = scale
                translationY = offsetY
            }
            .glass(cornerRadius = 16.dp)
            .clickable { onClick() }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Type icon
        Box(
            modifier = Modifier
                .size(44.dp)
                .background(typeColor.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = workoutTypeIcon(workout.type),
                contentDescription = null,
                tint = typeColor,
                modifier = Modifier.size(22.dp)
            )
        }

        // Middle info
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = workoutTypeLabel(workout.type),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = formatDuration(workout.durationMinutes),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Stats column
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = String.format("%.2f km", workout.distanceKm),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AccentIndigo
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Pace (if available)
                workout.avgPaceMinPerKm?.let { pace ->
                    Text(
                        text = formatPace(pace),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                // Calories
                Text(
                    text = "${workout.caloriesBurned} cal",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Chevron
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = "View detail",
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.size(16.dp)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Empty Day Card
// ─────────────────────────────────────

@Composable
private fun EmptyDayCard() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = Icons.Default.DirectionsRun,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(28.dp)
        )

        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "No activities",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "Rest day or no tracked workouts",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Monthly Summary Section
// ─────────────────────────────────────

@Composable
private fun MonthlySummarySection(stats: MonthlyStats) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(200)
        isVisible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "summaryAlpha"
    )
    val offsetY by animateFloatAsState(
        targetValue = if (isVisible) 0f else 20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "summaryOffset"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; translationY = offsetY },
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Monthly Summary",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SummaryStatCard(
                icon = Icons.Default.Map,
                value = String.format("%.1f km", stats.totalDistanceKm),
                label = "Total Distance",
                color = AccentIndigo,
                modifier = Modifier.weight(1f),
                delay = 250
            )
            SummaryStatCard(
                icon = Icons.Default.DirectionsRun,
                value = "${stats.totalWorkouts}",
                label = "Workouts",
                color = RunningGreen,
                modifier = Modifier.weight(1f),
                delay = 350
            )
            SummaryStatCard(
                icon = Icons.Default.CalendarMonth,
                value = "${stats.activeDays}",
                label = "Active Days",
                color = CyclingOrange,
                modifier = Modifier.weight(1f),
                delay = 450
            )
        }

        // Second row with calories and duration
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SummaryStatCard(
                icon = Icons.Default.LocalFireDepartment,
                value = "${stats.totalCalories}",
                label = "Calories",
                color = Color(0xFFFF2D55),
                modifier = Modifier.weight(1f),
                delay = 550
            )
            SummaryStatCard(
                icon = Icons.Default.Schedule,
                value = formatDuration(stats.totalDurationMinutes),
                label = "Total Time",
                color = PremiumColor.DeepPurpleStart,
                modifier = Modifier.weight(1f),
                delay = 650
            )
            // Empty spacer for 3-column alignment
            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

// ─────────────────────────────────────
// MARK: - Summary Stat Card
// ─────────────────────────────────────

@Composable
private fun SummaryStatCard(
    icon: ImageVector,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
    delay: Int = 0
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(delay.toLong())
        isVisible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "statAlpha"
    )
    val scale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.85f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "statScale"
    )

    Column(
        modifier = modifier
            .graphicsLayer {
                this.alpha = alpha
                scaleX = scale
                scaleY = scale
            }
            .glass(cornerRadius = 16.dp)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
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

        Text(
            text = value,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center
        )

        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1
        )
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

private fun formatPace(paceMinPerKm: Double): String {
    val wholeMinutes = paceMinPerKm.toInt()
    val seconds = ((paceMinPerKm - wholeMinutes) * 60).toInt()
    return "${wholeMinutes}'${String.format("%02d", seconds)}\"/km"
}
