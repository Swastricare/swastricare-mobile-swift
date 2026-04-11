package com.swastricare.health.ui.screens.menstrualcycle

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.ui.layout.layout
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.ReadOnlyComposable
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
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
// MARK: - Theme-Aware Cycle Colors
// ─────────────────────────────────────

internal object CycleTheme {
    val cardBg: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF1C1C1E) else Color.White

    val subtle: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF8E8E93) else Color.Gray

    val trackBg: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.12f) else Color.Gray.copy(alpha = 0.12f)
}

// ─────────────────────────────────────
// MARK: - Phase Helpers
// ─────────────────────────────────────

@Composable @ReadOnlyComposable
private fun phaseBackgroundColor(phase: CyclePhase): Color {
    val isDark = isSystemInDarkTheme()
    return when (phase) {
        CyclePhase.MENSTRUAL  -> if (isDark) Color(0xFF1A0A0F) else Color(0xFFFFF0F4)
        CyclePhase.FOLLICULAR -> if (isDark) Color(0xFF0A1A0F) else Color(0xFFF0FFF5)
        CyclePhase.OVULATION  -> if (isDark) Color(0xFF0A0F1A) else Color(0xFFEFF8FF)
        CyclePhase.LUTEAL     -> if (isDark) Color(0xFF140A1A) else Color(0xFFF5F0FF)
        else                  -> if (isDark) Color(0xFF121212) else Color(0xFFF8F8F8)
    }
}

private fun phaseBlobAsset(phase: CyclePhase): String = when (phase) {
    CyclePhase.MENSTRUAL  -> "blob_sad.png"
    CyclePhase.FOLLICULAR -> "blob_energetic.png"
    CyclePhase.OVULATION  -> "blob_happy.png"
    CyclePhase.LUTEAL     -> "blob_tired.png"
    else                  -> "blob_neutral.png"
}

/** Color that matches the blob illustration for the inner circle fill. */
private fun blobMatchColor(phase: CyclePhase): Color = when (phase) {
    CyclePhase.MENSTRUAL  -> Color(0xFF5B8DEF) // blob_sad – blue
    CyclePhase.FOLLICULAR -> Color(0xFFFFAA33) // blob_energetic – orange/amber
    CyclePhase.OVULATION  -> Color(0xFFFFCC02) // blob_happy – golden yellow
    CyclePhase.LUTEAL     -> Color(0xFF9B8EC4) // blob_tired – soft purple
    else                  -> Color(0xFFA0A0A0) // blob_neutral – gray
}

private fun pregnancyChances(phase: CyclePhase): Triple<String, Color, String> = when (phase) {
    CyclePhase.OVULATION  -> Triple("High",   Color(0xFFE91E63), "\uD83E\uDD5A")
    CyclePhase.FOLLICULAR -> Triple("Medium", Color(0xFFFF9800), "\uD83C\uDF31")
    else                  -> Triple("Low",    Color(0xFF4CAF50), "\uD83C\uDF19")
}

private fun LocalDate.toOrdinalString(): String {
    val day = dayOfMonth
    val suffix = when {
        day in 11..13 -> "th"
        day % 10 == 1 -> "st"
        day % 10 == 2 -> "nd"
        day % 10 == 3 -> "rd"
        else          -> "th"
    }
    val monthName = month.getDisplayName(TextStyle.FULL, Locale.getDefault())
    return "$day$suffix $monthName, $year"
}

// ─────────────────────────────────────
// MARK: - Main Screen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MenstrualCycleScreen(
    viewModel: MenstrualCycleViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {},
    onNavigateToLog: () -> Unit = {},
    onNavigateToCalendar: () -> Unit = {}
) {
    TrackScreen("MenstrualCycle")
    val uiState by viewModel.uiState.collectAsState()
    val today = LocalDate.now()

    var showSettingsSheet by remember { mutableStateOf(false) }
    var showStatisticsSheet by remember { mutableStateOf(false) }

    val animatedBg = AppColors.background

    val subtleColor = CycleTheme.subtle
    val cardBg = CycleTheme.cardBg

    val density = LocalDensity.current
    val statusBarTop = WindowInsets.statusBars.getTop(density)
    val statusBarDp = with(density) { statusBarTop.toDp() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            // Shift up by status bar height so background bleeds behind status bar
            .offset(y = -statusBarDp)
            .background(animatedBg)
            // Pad content back down so it sits below status bar
            .padding(top = statusBarDp)
    ) {
        if (uiState.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = CyclePink)
            }
        } else if (uiState.isNotSetUp) {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, "Back", tint = AppColors.onSurface)
                    }
                    Text(
                        "Cycle Tracker",
                        modifier = Modifier.weight(1f),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurface,
                        textAlign = TextAlign.Center
                    )
                    IconButton(onClick = { showSettingsSheet = true }) {
                        Icon(Icons.Default.Settings, "Settings", tint = AppColors.onSurface.copy(alpha = 0.8f))
                    }
                }
                CycleOnboardingContent(onLogPeriod = onNavigateToLog)
            }
        } else {
            var weekOffset by remember { mutableIntStateOf(0) }

            Column(
                modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            ) {
                // ── Top Bar (matches Hydration style) ──
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, "Back", tint = AppColors.onSurface)
                    }
                    Text(
                        "Cycle Tracker",
                        modifier = Modifier.weight(1f),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurface,
                        textAlign = TextAlign.Center
                    )
                    IconButton(onClick = { showSettingsSheet = true }) {
                        Icon(Icons.Default.Settings, "Settings", tint = AppColors.onSurface.copy(alpha = 0.8f))
                    }
                }

                // ── Horizontal Week Strip ──
                WeekCalendarStrip(
                    today = today,
                    weekOffset = weekOffset,
                    loggedPeriodDates = uiState.loggedPeriodDates,
                    fertileWindowDates = uiState.fertileWindowDates,
                    predictedPeriodDates = uiState.predictedPeriodDates,
                    onDateTap = { viewModel.togglePeriodDate(it) },
                    onWeekChange = { weekOffset += it }
                )

                Spacer(Modifier.height(8.dp))

                // ── Large Ring + Blob ──
                LargeRingWithBlob(uiState = uiState)

                Spacer(Modifier.height(8.dp))

                // ── Legend ──
                Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    LegendDot(MenstrualColor, "Period phase")
                    LegendDot(OvulationColor.copy(alpha = 0.6f), "Fertile window")
                }

                Spacer(Modifier.height(8.dp))

                // ── Log Period + View Calendar row ──
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    // Log Period
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp)).background(CyclePink.copy(alpha = 0.10f))
                            .clickable { onNavigateToLog() }.padding(horizontal = 20.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Add, null, tint = CyclePink, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Log Period", style = MaterialTheme.typography.labelLarge,
                            color = CyclePink, fontWeight = FontWeight.SemiBold)
                    }
                    // View Calendar
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp)).background(CyclePurple.copy(alpha = 0.10f))
                            .clickable { onNavigateToCalendar() }.padding(horizontal = 20.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.DateRange, null, tint = CyclePurple, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("View Calendar", style = MaterialTheme.typography.labelLarge,
                            color = CyclePurple, fontWeight = FontWeight.SemiBold)
                    }
                }

                Spacer(Modifier.height(12.dp))

                // ── Pregnancy Chances Card ──
                PregnancyChancesCard(phase = uiState.currentPhase)

                Spacer(Modifier.height(16.dp))

                // ── Phase Info Card ──
                PhaseInfoCard(phase = uiState.currentPhase)

                Spacer(Modifier.height(16.dp))

                // ── Tips ──
                TipsSection(phase = uiState.currentPhase)

                Spacer(Modifier.height(16.dp))

                // ── Statistics ──
                uiState.statistics?.let { stats ->
                    StatisticsPreviewCard(
                        stats = stats,
                        onTap = { viewModel.trackCyclePredictionViewed(); showStatisticsSheet = true },
                        formatDate = { viewModel.formatDate(it) }
                    )
                }

                Spacer(Modifier.height(120.dp))
            }

        }

        // ── Error Snackbar ──
        uiState.error?.let { errorMsg ->
            Snackbar(
                modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                action = { TextButton(onClick = { viewModel.dismissError() }) { Text("Dismiss", color = Color.White) } },
                containerColor = Color(0xFFB71C1C)
            ) { Text(errorMsg, color = Color.White) }
        }
    }

    // ── Bottom Sheets ──
    if (showSettingsSheet) {
        CycleSettingsSheet(
            settings = uiState.settings,
            onDismiss = { showSettingsSheet = false },
            onSave = { cycleLen, periodLen -> viewModel.updateCycleSettings(cycleLen, periodLen) },
            onUpdateNotifications = { period, fertile, pms -> viewModel.updateNotificationSettings(period, fertile, pms) }
        )
    }
    if (showStatisticsSheet) {
        uiState.statistics?.let { stats ->
            CycleStatisticsSheet(stats = stats, onDismiss = { showStatisticsSheet = false },
                formatDate = { viewModel.formatDate(it) })
        }
    }
}

// ─────────────────────────────────────
// MARK: - Large Ring With Blob
// ─────────────────────────────────────

@Composable
private fun LargeRingWithBlob(uiState: MenstrualCycleUiState) {
    val context = LocalContext.current
    val phase = uiState.currentPhase
    val subtleColor = CycleTheme.subtle
    val trackColor = CycleTheme.trackBg
    val isDark = isSystemInDarkTheme()
    val ringFillAlpha = if (isDark) 0.12f else 0.06f

    val blobColor = blobMatchColor(phase)

    var targetProgress by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(uiState.cycleProgress) { targetProgress = uiState.cycleProgress }
    val animatedProgress by animateFloatAsState(
        targetValue = targetProgress,
        animationSpec = tween(1200, easing = FastOutSlowInEasing), label = "ringProgress"
    )

    Box(Modifier.fillMaxWidth().height(300.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(260.dp)) {
            val strokeWidth = 12.dp.toPx()
            val radius = (size.minDimension - strokeWidth) / 2f
            val center = Offset(size.width / 2f, size.height / 2f)

            // Soft fill
            drawCircle(color = blobColor.copy(alpha = ringFillAlpha), radius = radius * 0.88f, center = center)

            // Track ring
            drawCircle(color = trackColor, radius = radius, center = center,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round))

            // Progress arc in blob color
            val sweepAngle = animatedProgress * 360f
            drawArc(
                color = blobColor,
                startAngle = -90f, sweepAngle = sweepAngle, useCenter = false,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = Size(radius * 2f, radius * 2f),
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )

            // End dot
            val endRad = Math.toRadians((-90.0 + sweepAngle))
            val dotX = center.x + radius * cos(endRad).toFloat()
            val dotY = center.y + radius * sin(endRad).toFloat()
            drawCircle(color = Color.White, radius = strokeWidth / 2 + 2.dp.toPx(), center = Offset(dotX, dotY))
            drawCircle(color = blobColor, radius = strokeWidth / 2, center = Offset(dotX, dotY))
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Day", style = MaterialTheme.typography.labelSmall, color = subtleColor)
            Text("${uiState.currentDayInCycle}", style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Bold, color = blobColor)
            Text(phase.displayName, style = MaterialTheme.typography.bodyMedium, color = subtleColor)
            Spacer(Modifier.height(4.dp))
            AsyncImage(
                model = ImageRequest.Builder(context)
                    .data("file:///android_asset/illustrations/${phaseBlobAsset(phase)}")
                    .crossfade(true).build(),
                contentDescription = "Phase mood", modifier = Modifier.size(100.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Legend Dot
// ─────────────────────────────────────

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(10.dp).background(color, CircleShape))
        Text(label, style = MaterialTheme.typography.labelSmall, color = CycleTheme.subtle)
    }
}

// ─────────────────────────────────────
// MARK: - Week Calendar Strip
// ─────────────────────────────────────

@Composable
private fun WeekCalendarStrip(
    today: LocalDate,
    weekOffset: Int,
    loggedPeriodDates: Set<LocalDate>,
    fertileWindowDates: Set<LocalDate>,
    predictedPeriodDates: Set<LocalDate>,
    onDateTap: (LocalDate) -> Unit,
    onWeekChange: (Int) -> Unit
) {
    val daysFromSunday = today.dayOfWeek.value % 7
    val baseSunday = today.minusDays(daysFromSunday.toLong())
    val weekStart = baseSunday.plusWeeks(weekOffset.toLong())
    val weekDays = (0..6).map { weekStart.plusDays(it.toLong()) }
    val dayLetters = listOf("S", "M", "T", "W", "T", "F", "S")
    val subtle = CycleTheme.subtle
    val cardBg = CycleTheme.cardBg

    // Month label
    val monthLabel = weekStart.month.getDisplayName(TextStyle.SHORT, Locale.getDefault()) +
            " ${weekStart.year}"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(cardBg)
            .padding(vertical = 10.dp)
    ) {
        // Month nav row
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            IconButton(onClick = { onWeekChange(-1) }, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Default.ChevronLeft, null, tint = subtle, modifier = Modifier.size(20.dp))
            }
            Text(monthLabel, style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold, color = subtle)
            IconButton(onClick = { onWeekChange(1) }, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Default.ChevronRight, null, tint = subtle, modifier = Modifier.size(20.dp))
            }
        }

        Spacer(Modifier.height(8.dp))

        // Day cells
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            weekDays.forEachIndexed { index, date ->
                val isToday = date == today
                val isLogged = loggedPeriodDates.contains(date)
                val isFertile = fertileWindowDates.contains(date)
                val isPredicted = predictedPeriodDates.contains(date)

                val dayBgColor = when {
                    isToday     -> Color(0xFF2196F3)
                    isLogged    -> MenstrualColor.copy(alpha = 0.80f)
                    isFertile   -> OvulationColor.copy(alpha = 0.30f)
                    isPredicted -> MenstrualColor.copy(alpha = 0.20f)
                    else        -> Color.Transparent
                }
                val dayTextColor = when {
                    isToday || isLogged -> Color.White
                    else -> AppColors.onSurface
                }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    // Day letter
                    Text(
                        dayLetters[index],
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isToday) Color(0xFF2196F3) else subtle,
                        fontWeight = FontWeight.Medium
                    )

                    // Day number
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(dayBgColor)
                            .clickable { onDateTap(date) },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "${date.dayOfMonth}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = dayTextColor,
                            fontWeight = if (isToday || isLogged) FontWeight.Bold else FontWeight.Normal
                        )
                    }

                    // "Today" indicator dot
                    if (isToday) {
                        Box(Modifier.size(4.dp).background(Color(0xFF2196F3), CircleShape))
                    } else {
                        Spacer(Modifier.height(4.dp))
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Full Calendar Screen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CycleCalendarScreen(
    viewModel: MenstrualCycleViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val isDark = isSystemInDarkTheme()
    val screenBg = if (isDark) Color(0xFF121212) else Color(0xFFF8F8F8)
    val subtle = CycleTheme.subtle

    Column(
        modifier = Modifier.fillMaxSize().background(screenBg)
    ) {
        // Top bar
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(Icons.Default.ArrowBack, "Back", tint = AppColors.onSurface)
            }
            Text("Cycle Calendar", style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f).padding(start = 4.dp))
        }

        if (uiState.isLoading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = CyclePink)
            }
        } else {
            Column(
                modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                    .padding(bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Calendar
                CycleCalendar(
                    selectedMonth = uiState.selectedMonth,
                    loggedPeriodDates = uiState.loggedPeriodDates,
                    predictedPeriodDates = uiState.predictedPeriodDates,
                    fertileWindowDates = uiState.fertileWindowDates,
                    onDateTap = { viewModel.togglePeriodDate(it) },
                    onMonthChange = { viewModel.changeMonth(it) }
                )

                // Phase info summary
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                        .clip(RoundedCornerShape(16.dp)).background(CycleTheme.cardBg)
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Day", style = MaterialTheme.typography.labelSmall, color = subtle)
                        Text("${uiState.currentDayInCycle}", style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold, color = uiState.currentPhase.color)
                        Text("of ${uiState.totalCycleDays}", style = MaterialTheme.typography.labelSmall, color = subtle)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Phase", style = MaterialTheme.typography.labelSmall, color = subtle)
                        Text(uiState.currentPhase.icon, fontSize = 28.sp)
                        Text(uiState.currentPhase.displayName.replace(" Phase", ""),
                            style = MaterialTheme.typography.labelSmall, color = uiState.currentPhase.color,
                            fontWeight = FontWeight.SemiBold)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Next Period", style = MaterialTheme.typography.labelSmall, color = subtle)
                        Text("${uiState.daysUntilNextPeriod}", style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold, color = CyclePink)
                        Text("days", style = MaterialTheme.typography.labelSmall, color = subtle)
                    }
                }

                // Pregnancy chances
                PregnancyChancesCard(phase = uiState.currentPhase)
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Pregnancy Chances Card
// ─────────────────────────────────────

@Composable
private fun PregnancyChancesCard(phase: CyclePhase) {
    val (chanceLabel, chanceColor, icon) = pregnancyChances(phase)
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp)).background(CycleTheme.cardBg)
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(icon, fontSize = 22.sp)
            Text("Chances of Pregnancy", style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium, color = AppColors.onSurface)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(10.dp).background(chanceColor, CircleShape))
            Text(chanceLabel, style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold, color = chanceColor)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Full Month Calendar
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
    val startOffset = yearMonth.atDay(1).dayOfWeek.value % 7
    val today = LocalDate.now()
    val dayNames = listOf("S", "M", "T", "W", "T", "F", "S")
    val subtle = CycleTheme.subtle
    val cardBg = CycleTheme.cardBg

    Column(
        modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth()
            .clip(RoundedCornerShape(20.dp)).background(cardBg).padding(16.dp)
    ) {
        // Month header
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { onMonthChange(-1) }) {
                Icon(Icons.Default.ChevronLeft, "Previous", tint = subtle)
            }
            Text(
                "${selectedMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${selectedMonth.year}",
                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold
            )
            IconButton(onClick = { onMonthChange(1) }) {
                Icon(Icons.Default.ChevronRight, "Next", tint = subtle)
            }
        }

        Spacer(Modifier.height(8.dp))

        Row(Modifier.fillMaxWidth()) {
            dayNames.forEach { day ->
                Text(day, modifier = Modifier.weight(1f), textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.labelSmall, color = subtle, fontWeight = FontWeight.Medium)
            }
        }

        Spacer(Modifier.height(4.dp))

        val totalCells = startOffset + daysInMonth
        val rows = (totalCells + 6) / 7
        for (row in 0 until rows) {
            Row(Modifier.fillMaxWidth()) {
                for (col in 0..6) {
                    val dayNumber = row * 7 + col - startOffset + 1
                    if (dayNumber in 1..daysInMonth) {
                        val date = yearMonth.atDay(dayNumber)
                        val isToday = date == today
                        val isLogged = loggedPeriodDates.contains(date)
                        val isPredicted = predictedPeriodDates.contains(date)
                        val isFertile = fertileWindowDates.contains(date)
                        val bgColor = when {
                            isLogged    -> MenstrualColor.copy(alpha = 0.7f)
                            isPredicted -> MenstrualColor.copy(alpha = 0.20f)
                            isFertile   -> OvulationColor.copy(alpha = 0.20f)
                            else        -> Color.Transparent
                        }
                        val textColor = when {
                            isLogged -> Color.White
                            isToday  -> CyclePink
                            else     -> AppColors.onSurface
                        }
                        Box(
                            modifier = Modifier.weight(1f).aspectRatio(1f).padding(2.dp)
                                .clip(CircleShape).background(bgColor)
                                .then(if (isToday && !isLogged) Modifier.border(1.5.dp, CyclePink, CircleShape) else Modifier)
                                .clickable { onDateTap(date) },
                            contentAlignment = Alignment.Center
                        ) {
                            Text("$dayNumber", style = MaterialTheme.typography.bodySmall,
                                fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal, color = textColor)
                        }
                    } else {
                        Spacer(Modifier.weight(1f).aspectRatio(1f))
                    }
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            CalendarLegendItem(MenstrualColor.copy(alpha = 0.7f), "Period")
            CalendarLegendItem(MenstrualColor.copy(alpha = 0.20f), "Predicted")
            CalendarLegendItem(OvulationColor.copy(alpha = 0.20f), "Fertile")
        }
    }
}

@Composable
private fun CalendarLegendItem(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(10.dp).background(color, CircleShape))
        Text(label, style = MaterialTheme.typography.labelSmall, color = CycleTheme.subtle)
    }
}

// ─────────────────────────────────────
// MARK: - Phase Info Card
// ─────────────────────────────────────

@Composable
private fun PhaseInfoCard(phase: CyclePhase) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(200); isVisible = true }
    val cardAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f, animationSpec = tween(600), label = "phaseAlpha"
    )

    Column(
        modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth()
            .graphicsLayer { alpha = cardAlpha }
            .clip(RoundedCornerShape(20.dp)).background(CycleTheme.cardBg).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(44.dp).background(phase.color.copy(alpha = 0.12f), CircleShape),
                contentAlignment = Alignment.Center) { Text(phase.icon, fontSize = 22.sp) }
            Column {
                Text(phase.displayName, style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold, color = phase.color)
                Text("Current Phase", style = MaterialTheme.typography.labelSmall, color = CycleTheme.subtle)
            }
        }

        Box(Modifier.fillMaxWidth().height(3.dp).clip(RoundedCornerShape(2.dp))
            .background(Brush.horizontalGradient(listOf(phase.color, phase.color.copy(alpha = 0.2f)))))

        Text(phase.description, style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface.copy(alpha = 0.85f), lineHeight = 22.sp)

        Text("Typical Symptoms", style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            phase.symptoms.forEach { symptom ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(6.dp).background(phase.color, CircleShape))
                    Text(symptom, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface.copy(alpha = 0.8f))
                }
            }
        }

        Text("Recommendations", style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            phase.recommendations.forEachIndexed { index, rec ->
                Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("${index + 1}.", style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Bold, color = phase.color)
                    Text(rec, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface.copy(alpha = 0.8f))
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Tips Section
// ─────────────────────────────────────

@Composable
private fun TipsSection(phase: CyclePhase) {
    val tips = tipsForPhase(phase)
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(400); isVisible = true }

    AnimatedVisibility(visible = isVisible,
        enter = fadeIn(tween(600)) + slideInVertically(tween(600)) { it / 4 }) {
        Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Phase Tips", style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold, color = AppColors.onSurface)
            tips.forEachIndexed { index, tip -> TipCard(tip, phase, index * 100) }
        }
    }
}

@Composable
private fun TipCard(tip: PhaseTip, phase: CyclePhase, delay: Int) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(delay.toLong()); isVisible = true }
    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f, animationSpec = tween(500), label = "tipAlpha")
    val offsetY by animateFloatAsState(
        targetValue = if (isVisible) 0f else 16f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f), label = "tipOffset")

    Row(
        modifier = Modifier.fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; translationY = offsetY }
            .clip(RoundedCornerShape(16.dp)).background(CycleTheme.cardBg).padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top
    ) {
        Box(Modifier.size(40.dp).background(phase.color.copy(alpha = 0.10f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center) { Text(tip.icon, fontSize = 20.sp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(tip.title, style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
            Text(tip.description, style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurface.copy(alpha = 0.7f), lineHeight = 18.sp)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Statistics Preview Card
// ─────────────────────────────────────

@Composable
private fun StatisticsPreviewCard(
    stats: CycleStatistics, onTap: () -> Unit, formatDate: (LocalDate) -> String
) {
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(600); isVisible = true }
    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f, animationSpec = tween(600), label = "statsAlpha")
    val scale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.95f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f), label = "statsScale")

    Column(
        modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth()
            .graphicsLayer { this.alpha = alpha; scaleX = scale; scaleY = scale }
            .clip(RoundedCornerShape(20.dp)).background(CycleTheme.cardBg)
            .clickable { onTap() }.padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically) {
            Text("Cycle Statistics", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Icon(Icons.Default.ChevronRight, "Details", tint = CycleTheme.subtle, modifier = Modifier.size(20.dp))
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            StatItem("Avg Cycle", "${stats.averageCycleLength.toInt()} days", CyclePurple)
            StatItem("Avg Period", "${stats.averagePeriodLength.toInt()} days", CyclePink)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            StatItem("Last Period", stats.lastPeriodDate?.let { formatDate(it) } ?: "--", MenstrualColor)
            StatItem("Next Period", stats.predictedNextPeriod?.let { formatDate(it) } ?: "--", OvulationColor)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            Box(Modifier.background(stats.regularity.color.copy(alpha = 0.12f), RoundedCornerShape(20.dp))
                .padding(horizontal = 16.dp, vertical = 6.dp)) {
                Text(stats.regularity.displayName, style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold, color = stats.regularity.color)
            }
        }
    }
}

@Composable
private fun StatItem(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(horizontal = 4.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = CycleTheme.subtle)
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold,
            color = color, textAlign = TextAlign.Center)
    }
}

// ─────────────────────────────────────
// MARK: - Onboarding
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CycleOnboardingContent(onLogPeriod: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
    ) {
        Spacer(Modifier.height(48.dp))
        Spacer(Modifier.height(24.dp))
        Text("Track Your Cycle", style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(12.dp))
        Text("Log your period to get predictions for your next cycle, fertile window, and ovulation day.",
            style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center, lineHeight = 22.sp)

        Spacer(Modifier.height(32.dp))

        Column(
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp))
                .background(CycleTheme.cardBg).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OnboardingFeatureRow("\uD83D\uDCC5", "Period Tracking", "Log start and end dates of your period")
            OnboardingFeatureRow("\uD83D\uDD2E", "Cycle Predictions", "Get accurate predictions for your next period")
            OnboardingFeatureRow("\uD83E\uDD5A", "Fertility Window", "Know your most fertile days and ovulation")
            OnboardingFeatureRow("\uD83D\uDCC8", "Cycle Insights", "Track patterns with statistics and charts")
        }

        Spacer(Modifier.height(32.dp))

        Button(
            onClick = { onLogPeriod() }, modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = CyclePink), shape = RoundedCornerShape(16.dp)
        ) {
            Icon(Icons.Default.Add, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Log Your Period", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(8.dp))
        Text("You can always edit this later", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
        Spacer(Modifier.height(48.dp))
    }
}

@Composable
private fun OnboardingFeatureRow(icon: String, title: String, description: String) {
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(40.dp).background(CyclePink.copy(alpha = 0.1f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center) { Text(icon, fontSize = 20.sp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
            Text(description, style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurface.copy(alpha = 0.7f))
        }
    }
}
