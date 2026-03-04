package com.swasthicare.mobile.ui.screens.main

import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.navigation.DeepLinkHandler
import com.swasthicare.mobile.navigation.DeepLinkRoute
import com.swasthicare.mobile.ui.screens.ai.AIScreen
import com.swasthicare.mobile.ui.screens.diet.AddFoodScreen
import com.swasthicare.mobile.ui.screens.diet.DietScreen
import com.swasthicare.mobile.ui.screens.diet.FoodSearchScreen
import com.swasthicare.mobile.ui.screens.ar.ARBodyScanScreen
import com.swasthicare.mobile.ui.screens.family.FamilyScreen
import com.swasthicare.mobile.ui.screens.heartrate.HeartRateAnalyticsScreen
import com.swasthicare.mobile.ui.screens.heartrate.HeartRateScreen
import com.swasthicare.mobile.ui.screens.home.HomeScreen
import com.swasthicare.mobile.ui.screens.hydration.HydrationScreen
import com.swasthicare.mobile.ui.screens.hydration.HydrationSettingsScreen
import com.swasthicare.mobile.ui.screens.medications.AddMedicationScreen
import com.swasthicare.mobile.ui.screens.medications.MedicationDetailScreen
import com.swasthicare.mobile.ui.screens.medications.MedicationsScreen
import com.swasthicare.mobile.ui.screens.notifications.NotificationHistoryScreen
import com.swasthicare.mobile.ui.screens.notifications.NotificationSettingsScreen
import com.swasthicare.mobile.ui.screens.menstrualcycle.MenstrualCycleScreen
import com.swasthicare.mobile.ui.screens.profile.EditProfileScreen
import com.swasthicare.mobile.ui.screens.profile.ProfileScreen
import com.swasthicare.mobile.ui.screens.profile.ProfileViewModel
import com.swasthicare.mobile.ui.screens.runactivity.LiveWorkoutScreen
import com.swasthicare.mobile.ui.screens.runactivity.RunActivityScreen
import com.swasthicare.mobile.ui.screens.runactivity.WorkoutSummaryScreen
import com.swasthicare.mobile.ui.screens.vault.VaultScreen
import com.swasthicare.mobile.ui.screens.analytics.HealthAnalyticsScreen
import com.swasthicare.mobile.ui.screens.runactivity.ActivityDetailScreen
import com.swasthicare.mobile.ui.screens.runactivity.RunCalendarScreen
import com.swasthicare.mobile.ui.screens.settings.SettingsScreen
import com.swasthicare.mobile.di.AppContainer
import androidx.lifecycle.viewmodel.compose.viewModel

sealed class MainTab(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    object Vitals : MainTab(
        route = "vitals",
        title = "Vitals",
        selectedIcon = Icons.Filled.Favorite,
        unselectedIcon = Icons.Outlined.FavoriteBorder
    )
    object Vault : MainTab(
        route = "vault",
        title = "Vault",
        selectedIcon = Icons.Filled.Lock,
        unselectedIcon = Icons.Outlined.Lock
    )
    object AI : MainTab(
        route = "ai",
        title = "AI",
        selectedIcon = Icons.Filled.AutoAwesome,
        unselectedIcon = Icons.Outlined.AutoAwesome
    )
    object Steps : MainTab(
        route = "steps",
        title = "Steps",
        selectedIcon = Icons.Filled.DirectionsRun,
        unselectedIcon = Icons.Outlined.DirectionsRun
    )
    object Profile : MainTab(
        route = "profile",
        title = "Profile",
        selectedIcon = Icons.Filled.Person,
        unselectedIcon = Icons.Outlined.Person
    )
}

@Composable
fun MainScreen(
    onSignOut: () -> Unit = {},
    deepLinkRoute: DeepLinkRoute? = null,
    onDeepLinkConsumed: () -> Unit = {}
) {
    val navController = rememberNavController()
    val haptic = LocalHapticFeedback.current

    val items = listOf(
        MainTab.Vitals,
        MainTab.Vault,
        MainTab.AI,
        MainTab.Steps,
        MainTab.Profile
    )

    // Handle deep link navigation
    LaunchedEffect(deepLinkRoute) {
        if (deepLinkRoute != null) {
            val navRoute = DeepLinkHandler.toNavRoute(deepLinkRoute)

            // Check if it's a tab route or a nested screen route
            val isTabRoute = items.any { it.route == navRoute }
            if (isTabRoute) {
                navController.navigate(navRoute) {
                    popUpTo(navController.graph.findStartDestination().id) {
                        saveState = true
                    }
                    launchSingleTop = true
                    restoreState = true
                }
            } else {
                navController.navigate(navRoute) {
                    launchSingleTop = true
                }
            }
            onDeepLinkConsumed()
        }
    }

    // Track screen views when tab changes
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    LaunchedEffect(currentRoute) {
        if (currentRoute != null) {
            val screenName = items.firstOrNull { it.route == currentRoute }?.title ?: currentRoute
            AppContainer.firebaseAnalyticsService.logScreenView(screenName)
            AppContainer.appAnalyticsService.trackScreenView(screenName)
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            val navBackStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = navBackStackEntry?.destination?.route

            // Hide nav bar on full-screen routes
            val hideNavBarRoutes = listOf("live_workout", "workout_summary", "ar_body_scan")
            if (currentRoute !in hideNavBarRoutes) {
                FloatingGlassNavBar(
                    items = items,
                    currentRoute = currentRoute,
                    onTabSelected = { tab ->
                        if (currentRoute != tab.route) {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        }
                        navController.navigate(tab.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
        }
    ) { innerPadding ->
        // Shared ProfileViewModel scoped to the MainScreen so Profile and EditProfile share state
        val profileViewModel: ProfileViewModel = viewModel()

        // We want content to go behind the floating bar, so we ignore bottom padding mostly
        // but we add a spacer at the bottom of screens instead (already added in HomeScreen)
        NavHost(
            navController = navController,
            startDestination = MainTab.Vitals.route,
            modifier = Modifier.fillMaxSize(), // Fill entire screen including behind bar
            enterTransition = { fadeIn(animationSpec = tween(250)) },
            exitTransition = { fadeOut(animationSpec = tween(250)) },
            popEnterTransition = { fadeIn(animationSpec = tween(250)) },
            popExitTransition = { fadeOut(animationSpec = tween(250)) }
        ) {
            composable(MainTab.Vitals.route) {
                HomeScreen(
                    onNavigateToMedications = { navController.navigate("medications") },
                    onNavigateToDiet = { navController.navigate("diet") },
                    onNavigateToHydration = { navController.navigate("hydration") },
                    onNavigateToCycleTracker = { navController.navigate("cycle_tracker") },
                    onNavigateToHeartRate = { navController.navigate("heart_rate") },
                    onNavigateToBodyScan = { navController.navigate("ar_body_scan") },
                    onNavigateToNotifications = { navController.navigate("notification_history") },
                    onNavigateToRoute = { route -> try { navController.navigate(route) } catch (_: Exception) {} }
                )
            }
            composable(MainTab.AI.route) { AIScreen() }
            composable(MainTab.Vault.route) { VaultScreen() }
            composable(MainTab.Steps.route) {
                RunActivityScreen(
                    onNavigateToLiveWorkout = { navController.navigate("live_workout") },
                    onNavigateToActivityDetail = { workoutId ->
                        navController.navigate("activity_detail/$workoutId")
                    },
                    onNavigateToCalendar = { navController.navigate("run_calendar") }
                )
            }
            composable(MainTab.Profile.route) {
                ProfileScreen(
                    viewModel = profileViewModel,
                    onSignOut = onSignOut,
                    onNavigateToNotificationSettings = { navController.navigate("notification_settings") },
                    onNavigateToEditProfile = { navController.navigate("edit_profile") },
                    onNavigateToFamily = { navController.navigate("family") },
                    onNavigateToSettings = { navController.navigate("settings") }
                )
            }
            // Settings
            composable("settings") {
                SettingsScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToEditProfile = { navController.navigate("edit_profile") },
                    onNavigateToFamily = { navController.navigate("family") },
                    onNavigateToNotificationSettings = { navController.navigate("notification_settings") },
                    onNavigateToHydrationSettings = { navController.navigate("hydration_settings") },
                    onSignOut = onSignOut
                )
            }
            composable("notification_settings") {
                NotificationSettingsScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            composable("notification_history") {
                NotificationHistoryScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            composable("edit_profile") {
                EditProfileScreen(
                    viewModel = profileViewModel,
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            // Medications flow
            composable("medications") {
                MedicationsScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToAddMedication = { navController.navigate("add_medication") },
                    onNavigateToDetail = { id -> navController.navigate("medication_detail/$id") },
                    onNavigateToAI = {
                        navController.navigate(MainTab.AI.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
            composable("add_medication") {
                AddMedicationScreen(onDismiss = { navController.popBackStack() })
            }
            composable("medication_detail/{medicationId}") { backStackEntry ->
                val id = backStackEntry.arguments?.getString("medicationId") ?: return@composable
                MedicationDetailScreen(
                    medicationId = id,
                    onBack = { navController.popBackStack() }
                )
            }
            // Diet flow
            composable("diet") {
                DietScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToAddFood = { mealTypeDb ->
                        navController.navigate("add_food/$mealTypeDb")
                    },
                    onNavigateToFoodSearch = { mealTypeDb ->
                        navController.navigate("food_search/$mealTypeDb")
                    },
                    onNavigateToAI = {
                        navController.navigate(MainTab.AI.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
            composable("add_food/{mealTypeDb}") { backStackEntry ->
                val mealTypeDb = backStackEntry.arguments?.getString("mealTypeDb") ?: "breakfast"
                AddFoodScreen(
                    initialMealTypeDb = mealTypeDb,
                    onDismiss = { navController.popBackStack() },
                    onNavigateToFoodSearch = { mt -> navController.navigate("food_search/$mt") }
                )
            }
            composable("food_search/{mealTypeDb}") { backStackEntry ->
                val mealTypeDb = backStackEntry.arguments?.getString("mealTypeDb") ?: "breakfast"
                FoodSearchScreen(
                    mealTypeDb = mealTypeDb,
                    onFoodSelected = { navController.popBackStack() },
                    onDismiss = { navController.popBackStack() }
                )
            }
            // AR Body Scan (Feature 16)
            composable("ar_body_scan") {
                ARBodyScanScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            // Hydration flow
            composable("hydration") {
                HydrationScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToAI = {
                        navController.navigate(MainTab.AI.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    onNavigateToSettings = { navController.navigate("hydration_settings") }
                )
            }
            composable("hydration_settings") {
                HydrationSettingsScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToNotifications = { navController.navigate("notification_settings") }
                )
            }
            // Menstrual Cycle Tracker
            composable("cycle_tracker") {
                MenstrualCycleScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            // Heart Rate Measurement
            composable("heart_rate") {
                HeartRateScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToAnalytics = { navController.navigate("heart_rate_analytics") },
                    onNavigateToAI = {
                        navController.navigate(MainTab.AI.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
            composable("heart_rate_analytics") {
                HeartRateAnalyticsScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            // Live Workout flow
            composable(
                route = "live_workout?type={type}",
                arguments = listOf(navArgument("type") {
                    type = NavType.StringType
                    defaultValue = ""
                })
            ) { backStackEntry ->
                val workoutType = backStackEntry.arguments?.getString("type") ?: ""
                if (workoutType.isNotEmpty()) {
                    val wType = try {
                        com.swasthicare.mobile.ui.screens.runactivity.WorkoutType.valueOf(workoutType.uppercase())
                    } catch (_: IllegalArgumentException) { null }
                    if (wType != null) {
                        AppContainer.liveWorkoutViewModel.setWorkoutType(wType)
                    }
                }
                LiveWorkoutScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToSummary = { navController.navigate("workout_summary") }
                )
            }
            composable("workout_summary") {
                WorkoutSummaryScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onDone = {
                        navController.popBackStack("steps", inclusive = false)
                    }
                )
            }
            // Run Calendar
            composable("run_calendar") {
                RunCalendarScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToActivityDetail = { workoutId ->
                        navController.navigate("activity_detail/$workoutId")
                    }
                )
            }
            // Health Analytics
            composable("health_analytics") {
                HealthAnalyticsScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToAI = {
                        navController.navigate(MainTab.AI.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
            // Activity Detail
            composable("activity_detail/{workoutId}") { backStackEntry ->
                val workoutId = backStackEntry.arguments?.getString("workoutId") ?: return@composable
                ActivityDetailScreen(
                    workoutId = workoutId,
                    onNavigateBack = { navController.popBackStack() },
                    onDelete = { navController.popBackStack() }
                )
            }
            // Family flow
            composable("family") {
                FamilyScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }
            composable("family_join/{code}") { backStackEntry ->
                val code = backStackEntry.arguments?.getString("code") ?: ""
                FamilyScreen(
                    onNavigateBack = { navController.popBackStack() },
                    initialJoinCode = code
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Floating Glass Navigation Bar
// ─────────────────────────────────────

private val AIGreenColor = Color(0xFF22C55E) // iOS accentGreen

@Composable
private fun FloatingGlassNavBar(
    items: List<MainTab>,
    currentRoute: String?,
    onTabSelected: (MainTab) -> Unit
) {
    val isDark = isSystemInDarkTheme()

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Glass container
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(
                    if (isDark)
                        Color(0xFF1C1C1E).copy(alpha = 0.85f)
                    else
                        Color.White.copy(alpha = 0.85f)
                )
                .padding(horizontal = 8.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { tab ->
                val isSelected = currentRoute == tab.route
                val isAI = tab is MainTab.AI

                NavBarItem(
                    tab = tab,
                    isSelected = isSelected,
                    isAI = isAI,
                    isDark = isDark,
                    onClick = { onTabSelected(tab) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun NavBarItem(
    tab: MainTab,
    isSelected: Boolean,
    isAI: Boolean,
    isDark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Bounce animation on selection
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1f else 0.9f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "tabScale"
    )

    // AI tab icon color is always green; others follow selected/unselected
    val iconColor = when {
        isAI -> AIGreenColor
        isSelected -> if (isDark) Color.White else Color(0xFF007AFF)
        else -> if (isDark) Color.White.copy(alpha = 0.4f) else Color(0xFF8E8E93)
    }

    val labelColor = when {
        isAI && isSelected -> AIGreenColor
        isSelected -> if (isDark) Color.White else Color(0xFF007AFF)
        else -> if (isDark) Color.White.copy(alpha = 0.35f) else Color(0xFF8E8E93)
    }

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onClick() }
            .padding(vertical = 6.dp)
            .scale(scale),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        // Glow dot above selected icon
        Box(
            modifier = Modifier
                .size(4.dp)
                .clip(CircleShape)
                .background(
                    if (isSelected) {
                        if (isAI) AIGreenColor else iconColor
                    } else Color.Transparent
                )
        )

        Icon(
            imageVector = if (isSelected) tab.selectedIcon else tab.unselectedIcon,
            contentDescription = tab.title,
            tint = iconColor,
            modifier = Modifier.size(22.dp)
        )

        Text(
            text = tab.title,
            fontSize = 10.sp,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = labelColor,
            maxLines = 1
        )
    }
}
