package com.swasthicare.mobile.ui.screens.main

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
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
import com.swasthicare.mobile.ui.screens.home.glass
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

    Scaffold(
        containerColor = Color.Transparent, // Let the background show through
        bottomBar = {
            // Floating Glass Navigation Bar
            Box(
                modifier = Modifier
                    .padding(horizontal = 20.dp, vertical = 20.dp)
                    .glass(cornerRadius = 32.dp, opacity = 0.8f) // Use our glass modifier
            ) {
                NavigationBar(
                    containerColor = Color.Transparent,
                    tonalElevation = 0.dp,
                    windowInsets = NavigationBarDefaults.windowInsets,
                    modifier = Modifier.height(70.dp) // Slightly taller for floating look
                ) {
                    val navBackStackEntry by navController.currentBackStackEntryAsState()
                    val currentDestination = navBackStackEntry?.destination

                    items.forEach { screen ->
                        val isSelected = currentDestination?.hierarchy?.any { it.route == screen.route } == true
                        val selectedColor = MaterialTheme.colorScheme.primary
                        val unselectedColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)

                        NavigationBarItem(
                            icon = {
                                Icon(
                                    imageVector = if (isSelected) screen.selectedIcon else screen.unselectedIcon,
                                    contentDescription = screen.title,
                                    modifier = Modifier.size(24.dp)
                                )
                            },
                            label = null, // Remove labels for cleaner "Apple-like" look
                            selected = isSelected,
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = selectedColor,
                                selectedTextColor = selectedColor,
                                indicatorColor = selectedColor.copy(alpha = 0.1f),
                                unselectedIconColor = unselectedColor,
                                unselectedTextColor = unselectedColor
                            ),
                            onClick = {
                                if (currentDestination?.route != screen.route) {
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                }

                                navController.navigate(screen.route) {
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
                    onNavigateToNotifications = { navController.navigate("notification_history") }
                )
            }
            composable(MainTab.AI.route) { AIScreen() }
            composable(MainTab.Vault.route) { VaultScreen() }
            composable(MainTab.Steps.route) {
                RunActivityScreen(
                    onNavigateToLiveWorkout = { navController.navigate("live_workout") }
                )
            }
            composable(MainTab.Profile.route) {
                ProfileScreen(
                    viewModel = profileViewModel,
                    onSignOut = onSignOut,
                    onNavigateToNotificationSettings = { navController.navigate("notification_settings") },
                    onNavigateToEditProfile = { navController.navigate("edit_profile") },
                    onNavigateToFamily = { navController.navigate("family") }
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
            composable("live_workout") {
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
