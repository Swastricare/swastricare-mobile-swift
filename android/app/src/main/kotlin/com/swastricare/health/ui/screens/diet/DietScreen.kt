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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.DietInsights
import com.swastricare.health.data.models.MealType
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.EmptyStateView
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors

// ─────────────────────────────────────
// MARK: - DietScreen
// ─────────────────────────────────────

@Composable
fun DietScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAddFood: (String) -> Unit,   // mealType.dbValue
    onNavigateToFoodSearch: (String) -> Unit, // mealType.dbValue
    onNavigateToAI: () -> Unit,
    onNavigateToFoodSnap: (String) -> Unit = {}
) {
    val vm: DietViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()

    val isDark = isSystemInDarkTheme()
    val secondaryBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)
    var showSettingsSheet by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

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
                    Icon(Icons.Default.ArrowBack, "Back",
                        tint = AppColors.onSurface)
                }
                Text(
                    "Diet Chart",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                IconButton(onClick = onNavigateToAI) {
                    Icon(Icons.Default.AutoAwesome, "Ask AI", tint = DietGreen)
                }
                // Ellipsis menu
                var showMenu by remember { mutableStateOf(false) }
                Box {
                    IconButton(onClick = { showMenu = true }) {
                        Icon(Icons.Default.MoreVert, "Menu", tint = DietGreen)
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
                                showSettingsSheet = true
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Add Food") },
                            leadingIcon = { Icon(Icons.Default.AddCircle, null) },
                            onClick = {
                                showMenu = false
                                onNavigateToAddFood(MealType.BREAKFAST.dbValue)
                            }
                        )
                    }
                }
            }

            // ── Content ──
            when {
                uiState.isLoading -> DietSkeletonContent()
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        // Calendar Strip
                        item {
                            Spacer(Modifier.height(4.dp))
                            DietCalendarStrip(
                                selectedDate = uiState.selectedDate,
                                onDateSelected = { vm.selectDate(it) }
                            )
                            Spacer(Modifier.height(16.dp))
                        }

                        // Progress Section
                        item {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp)
                                    .lightBorder(16.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(secondaryBg)
                                    .padding(20.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(16.dp)
                            ) {
                                Text(
                                    uiState.goalDescription,
                                    fontSize = 12.sp,
                                    color = AppColors.onSurface.copy(alpha = 0.5f)
                                )
                                CalorieProgressRing(
                                    current = uiState.totalCalories,
                                    goal = uiState.dietGoals.dailyCalories,
                                    progress = uiState.calorieProgress
                                )
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    DietStatPill(
                                        icon = Icons.Default.LocalFireDepartment,
                                        iconColor = DietGreen,
                                        value = "${uiState.totalCalories}",
                                        label = "of ${uiState.dietGoals.dailyCalories} cal",
                                        modifier = Modifier.weight(1f)
                                    )
                                    DietStatPill(
                                        icon = Icons.Default.ArrowUpward,
                                        iconColor = DietOrange,
                                        value = "${uiState.remainingCalories}",
                                        label = "remaining",
                                        modifier = Modifier.weight(1f)
                                    )
                                    DietStatPill(
                                        icon = Icons.Default.Restaurant,
                                        iconColor = DietBlue,
                                        value = "${uiState.nutritionSummary.mealCount}",
                                        label = "meals",
                                        modifier = Modifier.weight(1f)
                                    )
                                }
                            }
                            Spacer(Modifier.height(16.dp))
                        }

                        // Macro Breakdown
                        item {
                            MacroBreakdownCard(
                                summary = uiState.nutritionSummary,
                                goals = uiState.dietGoals,
                                proteinProgress = uiState.proteinProgress,
                                carbsProgress = uiState.carbsProgress,
                                fatProgress = uiState.fatProgress,
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                            Spacer(Modifier.height(20.dp))
                        }

                        // Today's Meals header
                        item {
                            Text(
                                "Today's Meals",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                            Spacer(Modifier.height(12.dp))
                        }

                        // Empty state when no meals logged
                        if (uiState.nutritionSummary.mealCount == 0) {
                            item {
                                EmptyStateView(
                                    emoji = "\uD83E\uDD57",
                                    title = "No meals logged today",
                                    subtitle = "Tap + to add breakfast, lunch, or dinner.",
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }

                        // Meal Section Cards
                        items(MealType.values().size) { index ->
                            val mealType = MealType.values()[index]
                            MealSectionCard(
                                mealType = mealType,
                                entries = vm.getMealLogs(mealType),
                                onDelete = { entry -> vm.deleteLog(entry) },
                                onAddFood = { onNavigateToAddFood(mealType.dbValue) },
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                            Spacer(Modifier.height(10.dp))
                        }

                        // Insights Card
                        uiState.insights?.let { insights ->
                            item {
                                Spacer(Modifier.height(4.dp))
                                InsightsCard(
                                    insights = insights,
                                    modifier = Modifier.padding(horizontal = 16.dp)
                                )
                                Spacer(Modifier.height(16.dp))
                            }
                        }

                        // Ask AI Button
                        item {
                            Spacer(Modifier.height(4.dp))
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp)
                                    .lightBorder(12.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(DietGreen.copy(alpha = 0.08f))
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
                                        tint = DietGreen,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        "Ask AI about my diet",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = DietGreen
                                    )
                                }
                            }
                            Spacer(Modifier.height(24.dp))
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
            containerColor = Color(0xFF4CAF50),
            contentColor = Color.White
        ) {
            Icon(Icons.Default.CameraAlt, contentDescription = "Snap Food")
        }

        // Error snackbar
        val snackbarHostState = remember { SnackbarHostState() }
        LaunchedEffect(uiState.error) {
            uiState.error?.let { msg ->
                snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
                vm.clearError()
            }
        }
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 96.dp)
        )

        // Settings bottom sheet
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
// MARK: - Insights Card
// ─────────────────────────────────────

@Composable
private fun InsightsCard(insights: DietInsights, modifier: Modifier = Modifier) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .lightBorder(16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(cardBg)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Default.TrendingUp, null, tint = DietGreen, modifier = Modifier.size(20.dp))
            Text("Insights", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            InsightItem("${insights.currentStreak}", "Day Streak", Icons.Default.LocalFireDepartment, DietOrange)
            InsightItem("${insights.weeklyAverageCalories}", "Avg cal/day", Icons.Default.BarChart, DietGreen)
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
                        tint = DietGreen,
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
            Icon(Icons.Default.CheckCircle, null, tint = DietGreen, modifier = Modifier.size(16.dp))
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
// MARK: - Skeleton Loading
// ─────────────────────────────────────

@Composable
private fun DietSkeletonContent() {
    val shimmer = AppColors.onSurface.copy(alpha = 0.07f)
    Column(
        modifier = Modifier.fillMaxSize().padding(top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Calendar row
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(7) {
                Box(Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(12.dp)).background(shimmer))
            }
        }
        // Progress card
        Box(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                .height(220.dp).clip(RoundedCornerShape(16.dp)).background(shimmer)
        )
        // Macro card
        Box(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                .height(140.dp).clip(RoundedCornerShape(16.dp)).background(shimmer)
        )
        // Meal cards
        repeat(3) {
            Box(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                    .height(64.dp).clip(RoundedCornerShape(16.dp)).background(shimmer)
            )
        }
    }
}
