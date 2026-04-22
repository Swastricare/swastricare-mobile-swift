package com.swastricare.health.ui.screens.hydration

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.QuickAddPreset
import androidx.core.view.WindowCompat
import com.swastricare.health.ui.theme.AppColors
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.models.DrinkType
import com.swastricare.health.ui.components.TrackScreen
import java.time.format.DateTimeFormatter
import java.util.Locale

// ─────────────────────────────────────
// MARK: - HydrationScreen
// ─────────────────────────────────────

// Drink-type gradient palettes: (lightTop, lightBottom, darkTop, darkBottom)
private data class DrinkGradient(val lightTop: Color, val lightBottom: Color, val darkTop: Color, val darkBottom: Color)

private val drinkGradients = mapOf(
    DrinkType.WATER   to DrinkGradient(Color(0xFF0EA5E9), Color(0xFF2563EB), Color(0xFF0369A1), Color(0xFF1E3A5F)),
    DrinkType.COFFEE  to DrinkGradient(Color(0xFF8B6914), Color(0xFF5C3D0E), Color(0xFF5C3D0E), Color(0xFF3A2508)),
    DrinkType.TEA     to DrinkGradient(Color(0xFF7CB342), Color(0xFF558B2F), Color(0xFF4E6B2F), Color(0xFF2E4A1A)),
    DrinkType.JUICE   to DrinkGradient(Color(0xFFF57C00), Color(0xFFE65100), Color(0xFFC25700), Color(0xFF8B3A00)),
    DrinkType.MILK    to DrinkGradient(Color(0xFF90A4AE), Color(0xFF607D8B), Color(0xFF546E7A), Color(0xFF37474F))
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HydrationScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAI: () -> Unit,
    onNavigateToSettings: () -> Unit = {}
) {
    TrackScreen("Hydration")
    val vm: HydrationViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    val isDark = isSystemInDarkTheme()

    val palette = drinkGradients[uiState.dominantDrinkType] ?: drinkGradients[DrinkType.WATER]!!
    val gradientTop by animateColorAsState(
        targetValue = palette.lightTop,
        animationSpec = tween(durationMillis = 600),
        label = "gradientTop"
    )
    val gradientBottom by animateColorAsState(
        targetValue = palette.lightBottom,
        animationSpec = tween(durationMillis = 600),
        label = "gradientBottom"
    )
    val sheetColor = if (isDark) Color(0xFF0A0A0A) else Color.White

    var showAddDrinkSheet by remember { mutableStateOf(false) }
    var showUrineGuide by remember { mutableStateOf(false) }
    var showOverview by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    // Edge-to-edge is on globally (MainActivity.enableEdgeToEdge), so the
    // gradient Box below already draws behind the status and nav bars —
    // we do NOT need to set window.statusBarColor (deprecated in API 35).
    //
    // Only the system icon tint needs adjusting so the clock/battery are
    // readable on the dark gradient. SideEffect applies this during
    // composition (before the first frame draws), which kills the
    // one-frame flash you get with DisposableEffect.
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val activity = view.context as? Activity ?: return@SideEffect
            val controller = WindowCompat.getInsetsController(activity.window, view)
            controller.isAppearanceLightStatusBars = false // light icons on gradient
            controller.isAppearanceLightNavigationBars = !isDark
        }
        DisposableEffect(isDark) {
            onDispose {
                val activity = view.context as? Activity ?: return@onDispose
                val controller = WindowCompat.getInsetsController(activity.window, view)
                // Restore theme default when leaving the screen.
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
                SheetContent(
                    uiState = uiState,
                    onDeleteEntry = { vm.deleteDrink(it) },
                    onNavigateToAI = onNavigateToAI,
                    onShowAddDrink = { showAddDrinkSheet = true },
                    isToday = uiState.isShowingToday
                )
            },
            sheetPeekHeight = 250.dp,
            sheetShape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
            sheetContainerColor = sheetColor,
            sheetShadowElevation = 8.dp,
            sheetTonalElevation = 0.dp,
            containerColor = Color.Transparent,
            contentColor = Color.White,
        ) { innerPadding ->
            // Fixed gradient content — does NOT scroll.
            // Status bar padding keeps the top bar (back button / title) from
            // sliding under the system clock. The Box above still paints the
            // gradient all the way to the top edge of the screen.
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .padding(bottom = innerPadding.calculateBottomPadding())
            ) {
                // ── Top Bar ──
                com.swastricare.health.ui.components.AppTopBar(
                    title = "Hydration",
                    onBack = onNavigateBack,
                    titleColor = Color.White,
                    iconTint = Color.White,
                    actions = {
                        IconButton(onClick = onNavigateToSettings) {
                            Icon(Icons.Default.Settings, "Settings", tint = Color.White.copy(alpha = 0.8f))
                        }
                    }
                )

                when {
                    uiState.isLoading -> HydrationSkeletonContent()
                    else -> {
                        Spacer(Modifier.height(8.dp))

                        HydrationHeroPager(
                            uiState = uiState,
                            onDragAddMl = { ml -> vm.addDrink(DrinkType.WATER, ml) },
                            onTapAnalytics = { showOverview = true }
                        )

                        Spacer(Modifier.height(16.dp))

                        // Wrap calendar and chips in Box for proper z-ordering of dragged chips
                        Box(modifier = Modifier.fillMaxWidth()) {
                            Column {
                                HydrationCalendarStrip(
                                    selectedDate = uiState.selectedDate,
                                    onDateSelected = { vm.selectDate(it) }
                                )
                                Spacer(Modifier.height(16.dp))

                                // Quick add drink chips
                                QuickAddDrinkChips(
                                    onAddDrink = { drinkType -> vm.addDrink(drinkType, 100) },
                                    modifier = Modifier.padding(bottom = 16.dp)
                                )
                            }
                        }
                        Spacer(Modifier.height(12.dp))

                        if (uiState.isWeatherAdjusted && uiState.weatherData != null) {
                            WeatherAdjustmentBanner(
                                temperature = uiState.weatherData!!.temperatureCelsius,
                                city = uiState.weatherData!!.city,
                                baseGoal = uiState.baseGoalMl,
                                adjustedGoal = uiState.effectiveGoalMl,
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                        }
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
                .padding(bottom = 16.dp)
        )

        // Add drink bottom sheet
        if (showAddDrinkSheet) {
            AddDrinkBottomSheet(
                onDismiss = { showAddDrinkSheet = false },
                onAddDrink = { type, amount -> vm.addDrink(type, amount) },
                onShowUrineGuide = {
                    showAddDrinkSheet = false
                    showUrineGuide = true
                }
            )
        }

        // Urine color guide sheet
        if (showUrineGuide) {
            UrineColorGuideSheet(
                onDismiss = { showUrineGuide = false },
                onLogWater = { amount -> vm.addDrink(DrinkType.WATER, amount) }
            )
        }

        // Analytics sheet (tap on progress ring)
        if (showOverview) {
            HydrationOverviewSheet(
                uiState = uiState,
                onDismiss = { showOverview = false }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - GreetingHeader
// ─────────────────────────────────────

@Composable
private fun GreetingHeader(
    name: String,
    isGoalMet: Boolean,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val subtitle = when {
        isGoalMet -> "Goal reached! Great job today!"
        progress >= 0.7f -> "You're on track! Keep it up."
        else -> "Drink more water to stay healthy."
    }
    val displayName = if (name.isNotBlank()) name else "there"

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            "Hello, $displayName",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Text(
            subtitle,
            fontSize = 15.sp,
            color = Color.White.copy(alpha = 0.85f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - SheetContent (bottom sheet)
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SheetContent(
    uiState: HydrationUiState,
    onDeleteEntry: (String) -> Unit,
    onNavigateToAI: () -> Unit,
    onShowAddDrink: () -> Unit,
    isToday: Boolean = true,
) {
    val isDark = isSystemInDarkTheme()
    val view = LocalView.current
    val dateFormatter = remember {
        DateTimeFormatter.ofPattern("EEE, dd MMM yyyy", Locale.getDefault())
    }
    val formattedDate = uiState.selectedDate.format(dateFormatter)
    val drinkCount = uiState.todaysEntries.size
    val totalMl = uiState.totalIntake

    val titleColor = AppColors.onSurface
    val subtitleColor = AppColors.onSurfaceVariant
    val dividerColor = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)
    val entryBgColor = if (isDark) Color(0xFF141414) else Color(0xFFF9F9FB)
    val entryDividerColor = if (isDark) Color(0xFF2C2C2E) else Color(0xFFE5E5EA)

    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding(),
        contentPadding = PaddingValues(
            start = 20.dp, end = 20.dp,
            top = 4.dp, bottom = 16.dp
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
                        if (drinkCount > 0) "$drinkCount drink${if (drinkCount > 1) "s" else ""} · ${totalMl}ml"
                        else "No drinks yet today",
                        fontSize = 13.sp,
                        color = subtitleColor
                    )
                }
                if (isToday) {
                    IconButton(
                        onClick = {
                            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            onShowAddDrink()
                        },
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = "Add drink",
                            modifier = Modifier.size(24.dp),
                            tint = titleColor
                        )
                    }
                }
            }
            HorizontalDivider(
                color = dividerColor,
                modifier = Modifier.padding(top = 12.dp)
            )
        }

        // Entries or empty state
        if (uiState.todaysEntries.isNotEmpty()) {
            items(
                items = uiState.todaysEntries,
                key = { it.id }
            ) { entry ->
                var isVisible by remember { mutableStateOf(true) }
                val dismissState = rememberSwipeToDismissBoxState(
                    confirmValueChange = { value ->
                        if (isToday && value == SwipeToDismissBoxValue.EndToStart) {
                            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            isVisible = false
                            true
                        } else false
                    }
                )
                LaunchedEffect(isVisible) {
                    if (!isVisible) {
                        kotlinx.coroutines.delay(300)
                        onDeleteEntry(entry.id)
                    }
                }
                AnimatedVisibility(
                    visible = isVisible,
                    exit = shrinkVertically(animationSpec = tween(300)) + fadeOut(animationSpec = tween(300))
                ) {
                    if (isToday) {
                        SwipeToDismissBox(
                            state = dismissState,
                            backgroundContent = {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(Color.Transparent)
                                        .padding(horizontal = 20.dp),
                                    contentAlignment = Alignment.CenterEnd
                                ) {
                                    Icon(
                                        Icons.Default.Delete,
                                        contentDescription = "Delete",
                                        tint = Color(0xFFFF3B30)
                                    )
                                }
                            },
                            enableDismissFromStartToEnd = false
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(entryBgColor)
                            ) {
                                HydrationEntryCard(
                                    entry = entry,
                                    onDelete = { onDeleteEntry(entry.id) },
                                    showDelete = true
                                )
                            }
                        }
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(20.dp))
                                .background(entryBgColor)
                        ) {
                            HydrationEntryCard(
                                entry = entry,
                                onDelete = {},
                                showDelete = false
                            )
                        }
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
                    DrinkIcon(drinkType = DrinkType.WATER, size = 48.dp)
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Text(
                            if (isToday) "No drinks yet today" else "No drinks logged",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = subtitleColor
                        )
                        Text(
                            if (isToday) "Tap + to log your first drink" else "Nothing was logged on this day",
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
