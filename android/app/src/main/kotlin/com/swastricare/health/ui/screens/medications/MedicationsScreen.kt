package com.swastricare.health.ui.screens.medications

import android.app.Activity
import android.view.HapticFeedbackConstants
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationDose
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.EmptyStateView
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

// ─────────────────────────────────────
// MARK: - Timeline Slot Model
// ─────────────────────────────────────

private data class TimelineSlot(
    val key: String,                 // "HH:mm" sort key
    val doses: List<MedicationDose>
) {
    val allTaken: Boolean get() = doses.all {
        it.status == AdherenceStatus.TAKEN ||
        it.status == AdherenceStatus.LATE ||
        it.status == AdherenceStatus.EARLY
    }
    val hasOverdue: Boolean get() = doses.any { it.isOverdue }
    val dotColor: Color get() = when {
        allTaken   -> Color(0xFF34C759)
        hasOverdue -> Color(0xFFFF3B30)
        else       -> Color(0xFF8E8E93).copy(alpha = 0.4f)
    }
    val formattedTime: String get() {
        val parts = key.split(":")
        val h = parts[0].toIntOrNull() ?: 0
        val m = parts.getOrNull(1)?.toIntOrNull() ?: 0
        val ampm = if (h < 12) "AM" else "PM"
        val dh = if (h == 0) 12 else if (h > 12) h - 12 else h
        return String.format("%d:%02d %s", dh, m, ampm)
    }
}

// Gradient palettes for medication adherence states
private data class MedGradient(val top: Color, val bottom: Color)

private val adherenceGradients = mapOf(
    "excellent" to MedGradient(Color(0xFF11998E), Color(0xFF0D7377)),  // teal — high adherence
    "good"      to MedGradient(Color(0xFF2E3192), Color(0xFF1B1464)),  // brand blue — moderate
    "low"       to MedGradient(Color(0xFFE65100), Color(0xFFBF360C)),  // warm orange — needs attention
    "none"      to MedGradient(Color(0xFF2E3192), Color(0xFF1B1464))   // default brand blue
)

private fun adherenceLevel(rate: Float): String = when {
    rate >= 0.8f -> "excellent"
    rate >= 0.5f -> "good"
    rate > 0f    -> "low"
    else         -> "none"
}

// ─────────────────────────────────────
// MARK: - MedicationsScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MedicationsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAddMedication: () -> Unit,
    onNavigateToDetail: (String) -> Unit,
    onNavigateToAI: () -> Unit
) {
    TrackScreen("Medications")
    val vm: MedicationsViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    val isDark = isSystemInDarkTheme()
    var skipDialogDose by remember { mutableStateOf<MedicationDose?>(null) }
    var deleteMedicationId by remember { mutableStateOf<String?>(null) }
    var deleteMedicationName by remember { mutableStateOf("") }

    val slotFormatter = remember { DateTimeFormatter.ofPattern("HH:mm") }
    val timelineSlots = remember(uiState.allDosesToday) {
        uiState.allDosesToday
            .groupBy { it.scheduledTime.format(slotFormatter) }
            .entries
            .sortedBy { it.key }
            .map { (key, doses) -> TimelineSlot(key, doses) }
    }

    // Gradient based on adherence
    val level = adherenceLevel(uiState.statistics.adherenceRate)
    val palette = adherenceGradients[level] ?: adherenceGradients["none"]!!
    val gradientTop by animateColorAsState(
        targetValue = palette.top,
        animationSpec = tween(durationMillis = 600),
        label = "gradientTop"
    )
    val gradientBottom by animateColorAsState(
        targetValue = palette.bottom,
        animationSpec = tween(durationMillis = 600),
        label = "gradientBottom"
    )
    val sheetColor = if (isDark) Color(0xFF0A0A0A) else Color.White

    val snackbarHostState = remember { SnackbarHostState() }

    // Fill status bar & navigation bar with gradient colors
    val view = LocalView.current
    if (!view.isInEditMode) {
        DisposableEffect(isDark, gradientTop) {
            val activity = view.context as? Activity ?: return@DisposableEffect onDispose {}
            val originalStatusBarColor = activity.window.statusBarColor
            val originalNavBarColor = activity.window.navigationBarColor
            activity.window.statusBarColor = gradientTop.toArgb()
            activity.window.navigationBarColor = sheetColor.toArgb()
            val controller = WindowCompat.getInsetsController(activity.window, view)
            controller.isAppearanceLightStatusBars = false
            controller.isAppearanceLightNavigationBars = !isDark
            onDispose {
                activity.window.statusBarColor = originalStatusBarColor
                activity.window.navigationBarColor = originalNavBarColor
                controller.isAppearanceLightStatusBars = !isDark
                controller.isAppearanceLightNavigationBars = !isDark
            }
        }
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let { msg ->
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            vm.clearError()
        }
    }

    val bottomSheetState = rememberBottomSheetScaffoldState(
        bottomSheetState = rememberStandardBottomSheetState(
            initialValue = SheetValue.PartiallyExpanded,
            confirmValueChange = { it != SheetValue.Hidden }
        )
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(gradientTop, gradientBottom)))
    ) {
        BottomSheetScaffold(
            scaffoldState = bottomSheetState,
            sheetContent = {
                MedSheetContent(
                    uiState = uiState,
                    timelineSlots = timelineSlots,
                    onTaken = { vm.markAsTaken(it) },
                    onSkip = { skipDialogDose = it },
                    onTap = { onNavigateToDetail(it.medicationId) },
                    onDelete = { dose ->
                        deleteMedicationId = dose.medicationId
                        deleteMedicationName = dose.medicationName
                    },
                    onNavigateToAI = onNavigateToAI,
                    onNavigateToAddMedication = onNavigateToAddMedication
                )
            },
            sheetPeekHeight = 280.dp,
            sheetShape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
            sheetContainerColor = sheetColor,
            sheetShadowElevation = 8.dp,
            sheetTonalElevation = 0.dp,
            containerColor = Color.Transparent,
            contentColor = Color.White,
        ) { innerPadding ->
            // Fixed gradient content — does NOT scroll
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = innerPadding.calculateBottomPadding())
            ) {
                // ── Top Bar ──
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Color.White)
                    }
                    Text(
                        "Medications",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = onNavigateToAI) {
                        Icon(Icons.Default.AutoAwesome, "Ask AI", tint = Color.White.copy(alpha = 0.8f))
                    }
                    IconButton(onClick = onNavigateToAddMedication) {
                        Icon(Icons.Default.Add, "Add Medication", tint = Color.White)
                    }
                }

                when {
                    uiState.isLoading -> MedicationsSkeletonContent()
                    uiState.medicationsWithDoses.isEmpty() -> {
                        MedicationsEmptyContent(onAdd = onNavigateToAddMedication)
                    }
                    else -> {
                        Spacer(Modifier.height(8.dp))

                        // ── Progress Hero ──
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            PillBottleView(progress = uiState.statistics.adherenceRate)
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                MedGradientStatPill(
                                    icon = Icons.Default.CheckCircle,
                                    iconColor = Color(0xFF34C759),
                                    value = "${uiState.statistics.takenDoses}",
                                    label = "taken",
                                    modifier = Modifier.weight(1f)
                                )
                                MedGradientStatPill(
                                    icon = Icons.Default.Schedule,
                                    iconColor = Color(0xFFFF9500),
                                    value = "${uiState.statistics.pendingDoses}",
                                    label = "remaining",
                                    modifier = Modifier.weight(1f)
                                )
                                MedGradientStatPill(
                                    icon = Icons.AutoMirrored.Filled.ShowChart,
                                    iconColor = Color(0xFF34C759),
                                    value = "${(uiState.statistics.adherenceRate * 100).toInt()}%",
                                    label = "adherence",
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }

                        Spacer(Modifier.height(16.dp))

                        // ── Calendar Strip (on gradient) ──
                        MedGradientCalendarStrip(
                            selectedDate = uiState.selectedDate,
                            onDateSelected = { vm.selectDate(it) }
                        )

                        Spacer(Modifier.height(12.dp))
                    }
                }
            }
        }

        // Snackbar
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 88.dp)
        )
    }

    // ── Skip Reason Dialog ──
    skipDialogDose?.let { dose ->
        SkipReasonDialog(
            medicationName = dose.medicationName,
            onConfirm = { reason ->
                vm.markAsSkipped(dose, reason)
                skipDialogDose = null
            },
            onDismiss = { skipDialogDose = null }
        )
    }

    // ── Delete Confirmation Dialog ──
    deleteMedicationId?.let { medId ->
        AlertDialog(
            onDismissRequest = { deleteMedicationId = null },
            title = { Text("Delete Medication") },
            text = {
                Text("Are you sure you want to delete $deleteMedicationName? This will cancel all scheduled reminders.")
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteMedication(medId)
                    deleteMedicationId = null
                }) { Text("Delete", color = Color(0xFFFF3B30)) }
            },
            dismissButton = {
                TextButton(onClick = { deleteMedicationId = null }) { Text("Cancel") }
            }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Gradient Stat Pill (white text for gradient bg)
// ─────────────────────────────────────

@Composable
private fun MedGradientStatPill(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconColor: Color,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(vertical = 10.dp, horizontal = 8.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = value,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Text(
            text = label,
            fontSize = 11.sp,
            color = Color.White.copy(alpha = 0.7f),
            maxLines = 1
        )
    }
}

// ─────────────────────────────────────
// MARK: - Gradient Calendar Strip
// ─────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MedGradientCalendarStrip(
    selectedDate: java.time.LocalDate,
    onDateSelected: (java.time.LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = java.time.LocalDate.now()
    val baseDate = remember { today.minusDays(500) }
    val todayPageIndex = remember { (today.toEpochDay() - baseDate.toEpochDay()).toInt() }
    val totalDays = remember { todayPageIndex + 4 }

    val selectedPageIndex = remember(selectedDate) {
        (selectedDate.toEpochDay() - baseDate.toEpochDay()).toInt().coerceIn(0, todayPageIndex)
    }

    val pagerState = rememberPagerState(
        initialPage = selectedPageIndex,
        pageCount = { totalDays }
    )

    val view = LocalView.current

    // Block scrolling past today
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage to pagerState.currentPageOffsetFraction }
            .collect { (page, fraction) ->
                if (page > todayPageIndex || (page == todayPageIndex && fraction > 0.01f)) {
                    pagerState.scrollToPage(todayPageIndex)
                }
            }
    }

    // Haptic + update selected date when page settles
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.settledPage }
            .collect { page ->
                if (page <= todayPageIndex) {
                    val newDate = baseDate.plusDays(page.toLong())
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    onDateSelected(newDate)
                }
            }
    }

    // When selected date changes externally, animate pager
    LaunchedEffect(selectedDate) {
        if (pagerState.settledPage != selectedPageIndex) {
            pagerState.animateScrollToPage(selectedPageIndex)
        }
    }

    BoxWithConstraints(modifier = modifier.fillMaxWidth()) {
        val itemWidth = maxWidth / 7

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxWidth(),
            pageSize = PageSize.Fixed(itemWidth),
            contentPadding = PaddingValues(horizontal = (maxWidth - itemWidth) / 2),
            beyondBoundsPageCount = 3,
            pageSpacing = 0.dp,
            userScrollEnabled = true
        ) { page ->
            val date = baseDate.plusDays(page.toLong())
            val isFuture = page > todayPageIndex
            val rawOffset = (pagerState.currentPage - page).toFloat() + pagerState.currentPageOffsetFraction
            val pageOffset = kotlin.math.abs(rawOffset).coerceIn(0f, 3f)
            val scale = 1f - pageOffset * 0.08f
            val alpha = if (isFuture) 0.35f else 1f - pageOffset * 0.185f

            MedGradientCalendarDay(
                date = date,
                isSelected = page == pagerState.currentPage && !isFuture,
                isFuture = isFuture,
                scale = scale,
                alpha = alpha,
                onClick = { if (!isFuture) onDateSelected(date) }
            )
        }
    }
}

@Composable
private fun MedGradientCalendarDay(
    date: java.time.LocalDate,
    isSelected: Boolean,
    isFuture: Boolean,
    scale: Float,
    alpha: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val view = LocalView.current
    val dayAbbr = date.dayOfWeek.getDisplayName(
        java.time.format.TextStyle.SHORT, java.util.Locale.getDefault()
    ).take(3)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer(
                scaleX = scale,
                scaleY = scale,
                alpha = alpha
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                enabled = !isFuture
            ) {
                view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                onClick()
            }
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = dayAbbr,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.75f)
        )
        Box(
            modifier = Modifier
                .size(40.dp)
                .then(
                    if (isSelected) Modifier
                        .background(Color.White.copy(alpha = 0.25f), CircleShape)
                        .border(1.dp, Color.White.copy(alpha = 0.6f), CircleShape)
                    else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = date.dayOfMonth.toString(),
                fontSize = if (isSelected) 17.sp else 16.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = Color.White
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - SheetContent (bottom sheet)
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MedSheetContent(
    uiState: MedicationsUiState,
    timelineSlots: List<TimelineSlot>,
    onTaken: (MedicationDose) -> Unit,
    onSkip: (MedicationDose) -> Unit,
    onTap: (MedicationDose) -> Unit,
    onDelete: (MedicationDose) -> Unit,
    onNavigateToAI: () -> Unit,
    onNavigateToAddMedication: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val dateFormatter = remember {
        DateTimeFormatter.ofPattern("EEE, dd MMM yyyy", java.util.Locale.getDefault())
    }
    val formattedDate = uiState.selectedDate.format(dateFormatter)
    val doseCount = uiState.allDosesToday.size
    val takenCount = uiState.statistics.takenDoses

    val titleColor = AppColors.onSurface
    val subtitleColor = AppColors.onSurfaceVariant
    val dividerColor = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding(),
        contentPadding = PaddingValues(
            start = 20.dp, end = 20.dp,
            top = 4.dp, bottom = 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Date header with add button
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        formattedDate,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = titleColor
                    )
                    Text(
                        if (doseCount > 0) "$takenCount of $doseCount doses taken"
                        else "No medications scheduled",
                        fontSize = 13.sp,
                        color = subtitleColor
                    )
                }
                IconButton(
                    onClick = onNavigateToAddMedication,
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = "Add medication",
                        modifier = Modifier.size(24.dp),
                        tint = titleColor
                    )
                }
            }
            HorizontalDivider(
                color = dividerColor,
                modifier = Modifier.padding(top = 12.dp)
            )
        }

        // Timeline or empty state
        if (timelineSlots.isNotEmpty()) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    timelineSlots.forEachIndexed { index, slot ->
                        TimelineSlotRow(
                            slot = slot,
                            isLast = index == timelineSlots.lastIndex,
                            onTaken = { dose -> onTaken(dose) },
                            onSkip  = { dose -> onSkip(dose) },
                            onTap   = { dose -> onTap(dose) },
                            onDelete = { dose -> onDelete(dose) }
                        )
                    }
                }
            }

            // Ask AI button
            item {
                Spacer(Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .lightBorder(12.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(MedBrandBlue.copy(alpha = 0.08f))
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) { onNavigateToAI() }
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            Icons.Default.AutoAwesome, null,
                            tint = MedBrandBlue,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            "Ask AI about my medications",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MedBrandBlue
                        )
                    }
                }
            }
        } else {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        Icons.Default.Medication,
                        contentDescription = null,
                        tint = subtitleColor,
                        modifier = Modifier.size(48.dp)
                    )
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Text(
                            "No doses scheduled",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = subtitleColor
                        )
                        Text(
                            "Tap + to add a medication",
                            fontSize = 13.sp,
                            color = AppColors.onSurfaceVariant,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Timeline Slot Row
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimelineSlotRow(
    slot: TimelineSlot,
    isLast: Boolean,
    onTaken: (MedicationDose) -> Unit,
    onSkip: (MedicationDose) -> Unit,
    onTap: (MedicationDose) -> Unit,
    onDelete: (MedicationDose) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.Top
    ) {
        // Left column: time + dot + connecting line
        Column(
            modifier = Modifier
                .width(65.dp)
                .fillMaxHeight(),
            horizontalAlignment = Alignment.End
        ) {
            Text(
                text = slot.formattedTime,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.End,
                color = if (slot.hasOverdue) Color(0xFFFF3B30)
                        else AppColors.onSurface.copy(alpha = 0.5f)
            )
            Spacer(Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(slot.dotColor, CircleShape)
            )
            // Connecting line (not shown on last slot)
            if (!isLast) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .weight(1f)
                        .background(
                            AppColors.onSurface.copy(alpha = 0.10f)
                        )
                )
            } else {
                Spacer(Modifier.weight(1f))
            }
        }

        // Right column: medication cards with swipe-to-delete
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(bottom = if (!isLast) 16.dp else 0.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            slot.doses.forEach { dose ->
                val dismissState = rememberSwipeToDismissBoxState(
                    confirmValueChange = { value ->
                        if (value == SwipeToDismissBoxValue.EndToStart) {
                            onDelete(dose)
                            false // Don't auto-dismiss; let the dialog handle it
                        } else false
                    }
                )
                SwipeToDismissBox(
                    state = dismissState,
                    enableDismissFromStartToEnd = false,
                    backgroundContent = {
                        val color by animateColorAsState(
                            when (dismissState.targetValue) {
                                SwipeToDismissBoxValue.EndToStart -> Color(0xFFFF3B30)
                                else -> Color.Transparent
                            },
                            label = "swipeDeleteBg"
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(14.dp))
                                .background(color)
                                .padding(horizontal = 20.dp),
                            contentAlignment = Alignment.CenterEnd
                        ) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = "Delete",
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    }
                ) {
                    TimelineMedicationCard(
                        dose = dose,
                        onTaken = { onTaken(dose) },
                        onTap = { onTap(dose) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skeleton Loading
// ─────────────────────────────────────

@Composable
private fun MedicationsSkeletonContent() {
    val shimmer = Color.White.copy(alpha = 0.15f)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 8.dp)
    ) {
        // Progress hero placeholder
        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(180.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(shimmer)
        )
        Spacer(Modifier.height(16.dp))
        // Calendar row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(7) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(Modifier.fillMaxWidth(0.7f).height(10.dp).clip(RoundedCornerShape(4.dp)).background(shimmer))
                    Box(Modifier.size(36.dp).clip(CircleShape).background(shimmer))
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────

@Composable
private fun MedicationsEmptyContent(onAdd: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        EmptyStateView(
            title = "No medications added",
            subtitle = "Tap + to add your first medication and set reminders.",
            illustrationAsset = "illustrations/medication - holding pill bottle .png"
        )
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onAdd,
            colors = ButtonDefaults.buttonColors(containerColor = Color.White),
            shape = RoundedCornerShape(14.dp)
        ) {
            Icon(Icons.Default.Add, null, modifier = Modifier.size(18.dp), tint = MedBrandBlue)
            Spacer(Modifier.width(8.dp))
            Text("Add Medication", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = MedBrandBlue)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skip Reason Dialog
// ─────────────────────────────────────

@Composable
private fun SkipReasonDialog(
    medicationName: String,
    onConfirm: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    var reason by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Skip $medicationName?") },
        text = {
            OutlinedTextField(
                value = reason,
                onValueChange = { reason = it },
                label = { Text("Reason (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(reason.ifBlank { null }) }) {
                Text("Skip", color = Color(0xFFFF9500))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
