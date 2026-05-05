package com.swastricare.health.ui.screens.diet

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.swastricare.health.data.models.DietInsights
import com.swastricare.health.data.models.MealType
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AppColors

// ─────────────────────────────────────
// MARK: - DietScreen
// ─────────────────────────────────────

@Composable
fun DietScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAddFood: (String) -> Unit,
    onNavigateToFoodSearch: (String) -> Unit,
    onNavigateToAI: () -> Unit,
    onNavigateToFoodSnap: (String) -> Unit = {}
) {
    TrackScreen("Diet")
    val vm: DietViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) vm.refresh()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    var showSettingsSheet by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // ── Content ──
            when {
                uiState.isLoading -> DietSkeletonContent()
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 96.dp)
                    ) {
                        // Hero header — illustration as background, title/icons overlaid
                        // Today's Progress card overlaps the hero's bottom for a stacked feel
                        item {
                            DietHeroHeader(
                                onSettingsClick = { showSettingsSheet = true }
                            )
                            TodaysProgressCard(
                                summary = uiState.nutritionSummary,
                                goals = uiState.dietGoals,
                                calorieProgress = uiState.calorieProgress,
                                proteinProgress = uiState.proteinProgress,
                                carbsProgress = uiState.carbsProgress,
                                fatProgress = uiState.fatProgress,
                                modifier = Modifier
                                    .padding(horizontal = 16.dp)
                                    .layout { measurable, constraints ->
                                        // Pull the card up by 40dp AND shrink the reported
                                        // height by the same amount so the next card sits
                                        // flush below it (no dead space).
                                        val placeable = measurable.measure(constraints)
                                        val pullPx = 40.dp.roundToPx()
                                        layout(
                                            placeable.width,
                                            (placeable.height - pullPx).coerceAtLeast(0)
                                        ) {
                                            placeable.place(0, -pullPx)
                                        }
                                    }
                            )
                            Spacer(Modifier.height(12.dp))
                        }

                        // Macro chip row
                        item {
                            MacroChipRow(
                                summary = uiState.nutritionSummary,
                                goals = uiState.dietGoals,
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                            Spacer(Modifier.height(20.dp))
                        }

                        // Today's Meals section header
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    "Today's Meals",
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AppColors.onSurface
                                )
                                Text(
                                    "View all",
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = DietAccent,
                                    modifier = Modifier.clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null
                                    ) { onNavigateToFoodSearch(MealType.BREAKFAST.dbValue) }
                                )
                            }
                            Spacer(Modifier.height(10.dp))
                        }

                        // Meal rows (only the 4 primary slots like the reference)
                        val primaryMeals = listOf(
                            MealType.BREAKFAST,
                            MealType.LUNCH,
                            MealType.EVENING_SNACK,
                            MealType.DINNER
                        )
                        items(primaryMeals.size) { index ->
                            val mealType = primaryMeals[index]
                            CompactMealRow(
                                mealType = mealType,
                                entries = vm.getMealLogs(mealType),
                                onAddFood = { onNavigateToAddFood(mealType.dbValue) },
                                onDelete = { entry -> vm.deleteLog(entry) },
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                        }

                        // Insights
                        uiState.insights?.let { insights ->
                            item {
                                InsightsCard(
                                    insights = insights,
                                    modifier = Modifier.padding(horizontal = 16.dp)
                                )
                                Spacer(Modifier.height(12.dp))
                            }
                        }

                        // Ask AI
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp)
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(DietAccent.copy(alpha = 0.08f))
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null
                                    ) { onNavigateToAI() }
                                    .padding(vertical = 14.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Icon(
                                        Icons.Default.AutoAwesome,
                                        contentDescription = null,
                                        tint = DietAccent,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Text(
                                        "Ask AI about my diet",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = DietAccent
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // FAB — Snap Food Photo
        FloatingActionButton(
            onClick = {
                val hour = java.time.LocalTime.now().hour
                val mealType = when {
                    hour < 10 -> MealType.BREAKFAST
                    hour < 14 -> MealType.LUNCH
                    hour < 17 -> MealType.EVENING_SNACK
                    else -> MealType.DINNER
                }
                onNavigateToFoodSnap(mealType.dbValue)
            },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 16.dp, bottom = 16.dp),
            containerColor = DietAccent,
            contentColor = Color.White
        ) {
            Icon(Icons.Default.CameraAlt, contentDescription = "Snap Food")
        }

        LaunchedEffect(uiState.error) {
            uiState.error?.let { msg ->
                snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
                vm.clearError()
            }
        }
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
        )

        if (showSettingsSheet) {
            DietSettingsSheet(
                currentGoals = uiState.dietGoals,
                onSave = { goals -> vm.updateGoals(goals) },
                onDismiss = { showSettingsSheet = false }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - DietHeroHeader
// ─────────────────────────────────────

/**
 * Hero illustration acts as the header background.
 * Title/subtitle overlay on the left; calendar + menu icons on the top right.
 * The salad bowl in the asset shows on the right.
 */
@Composable
private fun DietHeroHeader(
    onSettingsClick: () -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxWidth()) {
        // Bottom layer — full-bleed hero illustration, pushed down so the
        // title/icons sit above it on the white background
        DietHeroBanner(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 64.dp)
        )

        // Top-right menu
        Row(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(horizontal = 4.dp, vertical = 4.dp)
        ) {
            Box {
                IconButton(onClick = { showMenu = true }) {
                    Icon(
                        Icons.Default.MoreVert,
                        contentDescription = "Menu",
                        tint = AppColors.onSurface.copy(alpha = 0.75f)
                    )
                }
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Goals & Settings") },
                        leadingIcon = { Icon(Icons.Default.Settings, null) },
                        onClick = {
                            showMenu = false
                            onSettingsClick()
                        }
                    )
                }
            }
        }

        // Left-aligned title + subtitle, overlaid on the hero
        Column(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 20.dp, top = 20.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                "Diet",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                "Eat healthy, stay happy :)",
                fontSize = 13.sp,
                color = AppColors.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Insights Card
// ─────────────────────────────────────

@Composable
private fun InsightsCard(insights: DietInsights, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .dietCardShadow(radius = 16.dp, elevation = 5.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Default.TrendingUp, null, tint = DietAccent, modifier = Modifier.size(20.dp))
            Text("Insights", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            InsightItem("${insights.currentStreak}", "Day Streak", Icons.Default.LocalFireDepartment, DietOrange)
            InsightItem("${insights.weeklyAverageCalories}", "Avg cal/day", Icons.Default.BarChart, DietAccent)
        }

        if (insights.topFoods.isNotEmpty()) {
            Divider(color = AppColors.onSurface.copy(alpha = 0.08f))
            Text(
                "Top Foods",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface.copy(alpha = 0.5f)
            )
            insights.topFoods.forEach { food ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        Icons.Default.Circle, null,
                        tint = DietAccent,
                        modifier = Modifier.size(6.dp)
                    )
                    Text(food, fontSize = 14.sp, color = AppColors.onSurface)
                }
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Default.CheckCircle, null, tint = DietAccent, modifier = Modifier.size(16.dp))
            Text(
                "Macro balance: ${insights.macroBalance}",
                fontSize = 13.sp,
                color = AppColors.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun InsightItem(value: String, label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(22.dp))
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.onSurface)
        Text(label, fontSize = 12.sp, color = AppColors.onSurface.copy(alpha = 0.5f))
    }
}

// ─────────────────────────────────────
// MARK: - Skeleton
// ─────────────────────────────────────

@Composable
private fun DietSkeletonContent() {
    val shimmer = AppColors.onSurface.copy(alpha = 0.07f)
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(20.dp)).background(shimmer)
        )
        Box(
            Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(20.dp)).background(shimmer)
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            repeat(4) {
                Box(
                    Modifier.weight(1f).height(72.dp).clip(RoundedCornerShape(14.dp)).background(shimmer)
                )
            }
        }
        repeat(4) {
            Box(
                Modifier.fillMaxWidth().height(64.dp).clip(RoundedCornerShape(16.dp)).background(shimmer)
            )
        }
    }
}
