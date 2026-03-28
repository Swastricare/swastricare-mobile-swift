package com.swastricare.health.ui.screens.menstrualcycle

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
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
import androidx.compose.material.icons.filled.*
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.cos
import kotlin.math.sin
import com.swastricare.health.ui.components.TrackScreen

// ─────────────────────────────────────
// MARK: - Color Constants
// ─────────────────────────────────────

internal val CyclePink = Color(0xFFE91E63)
internal val CyclePurple = Color(0xFF9C27B0)
internal val MenstrualColor = Color(0xFFE91E63)
internal val FollicularColor = Color(0xFF4CAF50)
internal val OvulationColor = Color(0xFFFF9800)
internal val LutealColor = Color(0xFF9C27B0)

// ─────────────────────────────────────
// MARK: - Main Screen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MenstrualCycleScreen(
    viewModel: MenstrualCycleViewModel = viewModel(),
    onNavigateBack: () -> Unit = {}
) {
    TrackScreen("MenstrualCycle")
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    var showSettingsSheet by remember { mutableStateOf(false) }
    var showStatisticsSheet by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize()) {

        Column(
            modifier = Modifier
                .fillMaxSize()
        ) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack, "Back",
                        tint = AppColors.onSurface
                    )
                }
                Text(
                    "Cycle Tracker",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 4.dp)
                )
                IconButton(onClick = { showSettingsSheet = true }) {
                    Icon(
                        Icons.Default.Settings, "Settings",
                        tint = AppColors.onSurfaceVariant
                    )
                }
            }

            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = CyclePink)
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(scrollState),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Spacer(modifier = Modifier.height(4.dp))

                    // 1. Cycle Status Card (progress ring)
                    CycleStatusCard(
                        currentDay = uiState.currentDayInCycle,
                        totalDays = uiState.totalCycleDays,
                        phase = uiState.currentPhase,
                        daysUntilNextPeriod = uiState.daysUntilNextPeriod,
                        progress = uiState.cycleProgress
                    )

                    // 2. Calendar
                    CycleCalendar(
                        selectedMonth = uiState.selectedMonth,
                        loggedPeriodDates = uiState.loggedPeriodDates,
                        predictedPeriodDates = uiState.predictedPeriodDates,
                        fertileWindowDates = uiState.fertileWindowDates,
                        onDateTap = { viewModel.togglePeriodDate(it) },
                        onMonthChange = { viewModel.changeMonth(it) }
                    )

                    // 3. Phase Info Card
                    PhaseInfoCard(phase = uiState.currentPhase)

                    // 4. Tips Section
                    TipsSection(phase = uiState.currentPhase)

                    // 5. Statistics Preview Card
                    uiState.statistics?.let { stats ->
                        StatisticsPreviewCard(
                            stats = stats,
                            onTap = { showStatisticsSheet = true },
                            formatDate = { viewModel.formatDate(it) }
                        )
                    }

                    Spacer(modifier = Modifier.height(120.dp))
                }
            }
        }
    }

    // ── Bottom Sheets ──
    if (showSettingsSheet) {
        CycleSettingsSheet(
            settings = uiState.settings,
            onDismiss = { showSettingsSheet = false },
            onSave = { cycleLen, periodLen ->
                viewModel.updateCycleSettings(cycleLen, periodLen)
            },
            onUpdateNotifications = { period, fertile, pms ->
                viewModel.updateNotificationSettings(period, fertile, pms)
            }
        )
    }

    if (showStatisticsSheet) {
        uiState.statistics?.let { stats ->
            CycleStatisticsSheet(
                stats = stats,
                onDismiss = { showStatisticsSheet = false },
                formatDate = { viewModel.formatDate(it) }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - CycleStatusCard
// ─────────────────────────────────────

@Composable
private fun CycleStatusCard(
    currentDay: Int,
    totalDays: Int,
    phase: CyclePhase,
    daysUntilNextPeriod: Int,
    progress: Float
) {
    // Animate the progress ring on appearance
    var targetProgress by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(progress) { targetProgress = progress }

    val animatedProgress by animateFloatAsState(
        targetValue = targetProgress,
        animationSpec = tween(durationMillis = 1200, easing = FastOutSlowInEasing),
        label = "ringProgress"
    )

    // Stagger-in animation
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }

    val cardAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600),
        label = "statusAlpha"
    )
    val cardScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.9f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "statusScale"
    )

    Box(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .graphicsLayer { alpha = cardAlpha; scaleX = cardScale; scaleY = cardScale }
            .glass(cornerRadius = 24.dp)
    ) {
        // Gradient overlay
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            CyclePink.copy(alpha = 0.08f),
                            CyclePurple.copy(alpha = 0.08f)
                        )
                    )
                )
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Progress Ring
            Box(
                modifier = Modifier.size(120.dp),
                contentAlignment = Alignment.Center
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val strokeWidth = 10.dp.toPx()
                    val radius = (size.minDimension - strokeWidth) / 2
                    val center = Offset(size.width / 2, size.height / 2)

                    // Background ring
                    drawCircle(
                        color = Color.Gray.copy(alpha = 0.15f),
                        radius = radius,
                        center = center,
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                    )

                    // Sweep gradient arc
                    val sweepAngle = animatedProgress * 360f
                    val phaseColors = listOf(
                        MenstrualColor,
                        FollicularColor,
                        OvulationColor,
                        LutealColor,
                        MenstrualColor
                    )
                    drawArc(
                        brush = Brush.sweepGradient(
                            colors = phaseColors,
                            center = center
                        ),
                        startAngle = -90f,
                        sweepAngle = sweepAngle,
                        useCenter = false,
                        topLeft = Offset(center.x - radius, center.y - radius),
                        size = Size(radius * 2, radius * 2),
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                    )

                    // Dot at the end of the arc
                    val endAngleRad = Math.toRadians((-90.0 + sweepAngle))
                    val dotX = center.x + radius * cos(endAngleRad).toFloat()
                    val dotY = center.y + radius * sin(endAngleRad).toFloat()
                    drawCircle(
                        color = Color.White,
                        radius = strokeWidth / 2 + 2.dp.toPx(),
                        center = Offset(dotX, dotY)
                    )
                    drawCircle(
                        color = phase.color,
                        radius = strokeWidth / 2,
                        center = Offset(dotX, dotY)
                    )
                }

                // Center text
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "Day",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                    Text(
                        text = "$currentDay",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = phase.color
                    )
                    Text(
                        text = "of $totalDays",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }

            // Phase info text
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.weight(1f)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(text = phase.icon, fontSize = 20.sp)
                    Text(
                        text = phase.displayName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = phase.color
                    )
                }

                HorizontalDivider(
                    color = phase.color.copy(alpha = 0.2f),
                    thickness = 1.dp
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        Icons.Default.Schedule,
                        contentDescription = null,
                        tint = AppColors.onSurfaceVariant,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = if (daysUntilNextPeriod > 0)
                            "$daysUntilNextPeriod days until next period"
                        else
                            "Period expected today",
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Cycle Calendar
// ─────────────────────────────────────

@Composable
private fun CycleCalendar(
    selectedMonth: LocalDate,
    loggedPeriodDates: Set<LocalDate>,
    predictedPeriodDates: Set<LocalDate>,
    fertileWindowDates: Set<LocalDate>,
    onDateTap: (LocalDate) -> Unit,
    onMonthChange: (Int) -> Unit
) {
    val yearMonth = YearMonth.from(selectedMonth)
    val daysInMonth = yearMonth.lengthOfMonth()
    val firstDayOfWeek = yearMonth.atDay(1).dayOfWeek
    // Offset so Sunday = 0
    val startOffset = (firstDayOfWeek.value % 7)
    val today = LocalDate.now()
    val dayNames = listOf("S", "M", "T", "W", "T", "F", "S")

    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        // Month header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { onMonthChange(-1) }) {
                Icon(
                    Icons.Default.ChevronLeft,
                    contentDescription = "Previous month",
                    tint = AppColors.onSurfaceVariant
                )
            }
            Text(
                text = "${selectedMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${selectedMonth.year}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            IconButton(onClick = { onMonthChange(1) }) {
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = "Next month",
                    tint = AppColors.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Day-of-week headers
        Row(modifier = Modifier.fillMaxWidth()) {
            dayNames.forEach { day ->
                Text(
                    text = day,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Calendar grid
        val totalCells = startOffset + daysInMonth
        val rows = (totalCells + 6) / 7

        for (row in 0 until rows) {
            Row(modifier = Modifier.fillMaxWidth()) {
                for (col in 0..6) {
                    val cellIndex = row * 7 + col
                    val dayNumber = cellIndex - startOffset + 1

                    if (dayNumber in 1..daysInMonth) {
                        val date = yearMonth.atDay(dayNumber)
                        val isToday = date == today
                        val isLogged = loggedPeriodDates.contains(date)
                        val isPredicted = predictedPeriodDates.contains(date)
                        val isFertile = fertileWindowDates.contains(date)

                        val bgColor = when {
                            isLogged -> MenstrualColor.copy(alpha = 0.7f)
                            isPredicted -> MenstrualColor.copy(alpha = 0.25f)
                            isFertile -> OvulationColor.copy(alpha = 0.25f)
                            else -> Color.Transparent
                        }

                        val textColor = when {
                            isLogged -> Color.White
                            isToday -> CyclePink
                            else -> AppColors.onSurface
                        }

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f)
                                .padding(2.dp)
                                .clip(CircleShape)
                                .background(bgColor)
                                .then(
                                    if (isToday && !isLogged) Modifier.border(
                                        1.5.dp, CyclePink, CircleShape
                                    ) else Modifier
                                )
                                .clickable { onDateTap(date) },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "$dayNumber",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
                                color = textColor
                            )
                        }
                    } else {
                        Spacer(modifier = Modifier.weight(1f).aspectRatio(1f))
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Legend
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            CalendarLegendItem(color = MenstrualColor.copy(alpha = 0.7f), label = "Period")
            CalendarLegendItem(color = MenstrualColor.copy(alpha = 0.25f), label = "Predicted")
            CalendarLegendItem(color = OvulationColor.copy(alpha = 0.25f), label = "Fertile")
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
                .size(10.dp)
                .background(color, CircleShape)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ─────────────────────────────────────
// MARK: - PhaseInfoCard
// ─────────────────────────────────────

@Composable
private fun PhaseInfoCard(phase: CyclePhase) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(200)
        isVisible = true
    }

    val cardAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600),
        label = "phaseAlpha"
    )

    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .graphicsLayer { alpha = cardAlpha }
            .glass(cornerRadius = 20.dp)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(phase.color.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(text = phase.icon, fontSize = 22.sp)
            }
            Column {
                Text(
                    text = phase.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = phase.color
                )
                Text(
                    text = "Current Phase",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        // Colored accent bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(3.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(phase.color, phase.color.copy(alpha = 0.2f))
                    )
                )
        )

        // Description
        Text(
            text = phase.description,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface.copy(alpha = 0.85f),
            lineHeight = 22.sp
        )

        // Symptoms
        Text(
            text = "Typical Symptoms",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            phase.symptoms.forEach { symptom ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(phase.color, CircleShape)
                    )
                    Text(
                        text = symptom,
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurface.copy(alpha = 0.8f)
                    )
                }
            }
        }

        // Recommendations
        Text(
            text = "Recommendations",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            phase.recommendations.forEachIndexed { index, rec ->
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "${index + 1}.",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Bold,
                        color = phase.color
                    )
                    Text(
                        text = rec,
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurface.copy(alpha = 0.8f)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - TipsSection
// ─────────────────────────────────────

@Composable
private fun TipsSection(phase: CyclePhase) {
    val tips = tipsForPhase(phase)

    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(400)
        isVisible = true
    }

    AnimatedVisibility(
        visible = isVisible,
        enter = fadeIn(tween(600)) + slideInVertically(tween(600)) { it / 4 }
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "Phase Tips",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )

            tips.forEachIndexed { index, tip ->
                TipCard(tip = tip, phase = phase, delay = index * 100)
            }
        }
    }
}

@Composable
private fun TipCard(tip: PhaseTip, phase: CyclePhase, delay: Int) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(delay.toLong())
        isVisible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500),
        label = "tipAlpha"
    )
    val offsetY by animateFloatAsState(
        targetValue = if (isVisible) 0f else 16f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "tipOffset"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; translationY = offsetY }
            .glass(cornerRadius = 16.dp)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(phase.color.copy(alpha = 0.12f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(text = tip.icon, fontSize = 20.sp)
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = tip.title,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Text(
                text = tip.description,
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurface.copy(alpha = 0.7f),
                lineHeight = 18.sp
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - StatisticsPreviewCard
// ─────────────────────────────────────

@Composable
private fun StatisticsPreviewCard(
    stats: CycleStatistics,
    onTap: () -> Unit,
    formatDate: (LocalDate) -> String
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(600)
        isVisible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600),
        label = "statsAlpha"
    )
    val scale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.95f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "statsScale"
    )

    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; scaleX = scale; scaleY = scale }
            .glass(cornerRadius = 20.dp)
            .clickable { onTap() }
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Cycle Statistics",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = "View details",
                tint = AppColors.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatItem(
                label = "Avg Cycle",
                value = "${stats.averageCycleLength.toInt()} days",
                color = CyclePurple
            )
            StatItem(
                label = "Avg Period",
                value = "${stats.averagePeriodLength.toInt()} days",
                color = CyclePink
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatItem(
                label = "Last Period",
                value = stats.lastPeriodDate?.let { formatDate(it) } ?: "--",
                color = MenstrualColor
            )
            StatItem(
                label = "Next Period",
                value = stats.predictedNextPeriod?.let { formatDate(it) } ?: "--",
                color = OvulationColor
            )
        }

        // Regularity badge
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .background(
                        stats.regularity.color.copy(alpha = 0.12f),
                        RoundedCornerShape(20.dp)
                    )
                    .padding(horizontal = 16.dp, vertical = 6.dp)
            ) {
                Text(
                    text = stats.regularity.displayName,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = stats.regularity.color
                )
            }
        }
    }
}

@Composable
private fun StatItem(label: String, value: String, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.padding(horizontal = 4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = color,
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - Bottom Sheets (see CycleSheets.kt)
// CycleSettingsSheet, CycleStatisticsSheet, StatChartSection,
// and SymptomFrequencyBar have been extracted to CycleSheets.kt.
// ─────────────────────────────────────
