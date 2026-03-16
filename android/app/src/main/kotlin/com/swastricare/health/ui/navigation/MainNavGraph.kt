package com.swastricare.health.ui.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.swastricare.health.ui.screens.ai.AIScreen
import com.swastricare.health.ui.screens.analytics.HealthAnalyticsScreen
import com.swastricare.health.ui.screens.analytics.HealthMetricDetailScreen
import com.swastricare.health.ui.screens.ar.ARBodyScanScreen
import com.swastricare.health.ui.screens.diet.AddFoodScreen
import com.swastricare.health.ui.screens.diet.DietScreen
import com.swastricare.health.ui.screens.diet.FoodSearchScreen
import com.swastricare.health.ui.screens.diet.FoodSnapScreen
import com.swastricare.health.ui.screens.family.FamilyScreen
import com.swastricare.health.ui.screens.heartrate.HeartRateAnalyticsScreen
import com.swastricare.health.ui.screens.heartrate.HeartRateScreen
import com.swastricare.health.ui.screens.home.HomeScreen
import com.swastricare.health.ui.screens.hydration.HydrationScreen
import com.swastricare.health.ui.screens.hydration.HydrationSettingsScreen
import com.swastricare.health.ui.screens.medications.AddMedicationScreen
import com.swastricare.health.ui.screens.medications.MedicationDetailScreen
import com.swastricare.health.ui.screens.medications.MedicationsScreen
import com.swastricare.health.ui.screens.menstrualcycle.MenstrualCycleScreen
import com.swastricare.health.ui.screens.notifications.NotificationHistoryScreen
import com.swastricare.health.ui.screens.notifications.NotificationSettingsScreen
import com.swastricare.health.ui.screens.profile.EditProfileScreen
import com.swastricare.health.ui.screens.profile.ProfileViewModel
import com.swastricare.health.ui.screens.runactivity.ActivityDetailScreen
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutScreen
import com.swastricare.health.ui.screens.runactivity.RunActivityScreen
import com.swastricare.health.ui.screens.runactivity.RunCalendarScreen
import com.swastricare.health.ui.screens.runactivity.WorkoutType
import com.swastricare.health.ui.screens.settings.GarminConnectSettingsScreen
import com.swastricare.health.ui.screens.settings.GoogleHealthSettingsScreen
import com.swastricare.health.ui.screens.settings.HealthAppId
import com.swastricare.health.ui.screens.settings.HealthConnectSettingsScreen
import com.swastricare.health.ui.screens.settings.HealthDataSyncScreen
import com.swastricare.health.ui.screens.settings.SamsungHealthSettingsScreen
import com.swastricare.health.ui.screens.settings.SettingsScreen
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutViewModel

/**
 * Navigation graph for the main content area (inside Scaffold).
 * This contains all tab screens and nested screens.
 *
 * Key points:
 * - Screens receive Modifier without needing to apply innerPadding (already applied in MainScaffold)
 * - Nested screens that need back navigation should include a back button in their content
 * - Tab switching uses popUpTo with saveState/restoreState for state preservation
 */
@Composable
fun MainNavGraph(
    navController: NavHostController,
    modifier: Modifier = Modifier,
    profileViewModel: ProfileViewModel,
    onSignOut: () -> Unit,
    onAiFullScreenChange: (Boolean) -> Unit = {}
) {
    NavHost(
        navController = navController,
        startDestination = BottomNavTab.AI.route,
        modifier = modifier,
        enterTransition = { fadeIn(animationSpec = tween(250)) },
        exitTransition = { fadeOut(animationSpec = tween(250)) },
        popEnterTransition = { fadeIn(animationSpec = tween(250)) },
        popExitTransition = { fadeOut(animationSpec = tween(250)) }
    ) {
        // ═══════════════════════════════════════════════════════════
        // TAB SCREENS (Bottom Navigation)
        // ═══════════════════════════════════════════════════════════

        // Tab: Vitals (Home)
        composable(BottomNavTab.Vitals.route) {
            HomeScreen(
                onNavigateToMedications = { navController.navigate("medications") },
                onNavigateToDiet = { navController.navigate("diet") },
                onNavigateToHydration = { navController.navigate("hydration") },
                onNavigateToCycleTracker = { navController.navigate("cycle_tracker") },
                onNavigateToHeartRate = { navController.navigate("heart_rate") },
                onNavigateToBodyScan = { navController.navigate("ar_body_scan") },
                onNavigateToNotifications = { navController.navigate("notification_history") },
                onNavigateToAnalytics = { navController.navigate("health_analytics") },
                onNavigateToRoute = { route ->
                    try { navController.navigate(route) } catch (_: Exception) { }
                }
            )
        }

        // Tab: Vault
        composable(BottomNavTab.Vault.route) {
            com.swastricare.health.ui.screens.vault.VaultScreen(
                onNavigateToAIChat = {
                    navController.navigate(BottomNavTab.AI.route) {
                        launchSingleTop = true
                    }
                }
            )
        }

        // Tab: AI (expands to full screen when chat is active)
        composable(BottomNavTab.AI.route) {
            AIScreen(
                onFullScreenChange = onAiFullScreenChange
            )
        }

        // Tab: Steps
        composable(BottomNavTab.Steps.route) {
            RunActivityScreen(
                onNavigateToLiveWorkout = { workoutType ->
                    if (workoutType != null) {
                        navController.navigate("live_workout?workout_type=${workoutType.name}")
                    } else {
                        navController.navigate("live_workout")
                    }
                },
                onNavigateToActivityDetail = { workoutId ->
                    navController.navigate("activity_detail/$workoutId")
                },
                onNavigateToCalendar = { navController.navigate("run_calendar") }
            )
        }

        // Tab: Profile
        composable(BottomNavTab.Profile.route) {
            SettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToEditProfile = { navController.navigate("edit_profile") },
                onNavigateToFamily = { navController.navigate("family") },
                onNavigateToNotificationSettings = { navController.navigate("notification_settings") },
                onNavigateToHydrationSettings = { navController.navigate("hydration_settings") },
                onNavigateToHealthDataSync = { navController.navigate("health_data_sync") },
                onSignOut = onSignOut
            )
        }

        // ═══════════════════════════════════════════════════════════
        // NESTED SCREENS (Full screen, back navigation required)
        // ═══════════════════════════════════════════════════════════

        // ─── Medications ───
        composable("medications") {
            MedicationsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToAddMedication = { navController.navigate("add_medication") },
                onNavigateToDetail = { id -> navController.navigate("medication_detail/$id") },
                onNavigateToAI = { navigateToTab(navController, BottomNavTab.AI.route) }
            )
        }

        composable("add_medication") {
            AddMedicationScreen(onDismiss = { navController.popBackStack() })
        }

        composable(
            route = "medication_detail/{${NavArgs.MEDICATION_ID}}",
            arguments = listOf(
                navArgument(NavArgs.MEDICATION_ID) { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val id = backStackEntry.arguments?.getString(NavArgs.MEDICATION_ID) ?: return@composable
            MedicationDetailScreen(
                medicationId = id,
                onBack = { navController.popBackStack() }
            )
        }

        // ─── Diet ───
        composable("diet") {
            DietScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToAddFood = { mealTypeDb ->
                    navController.navigate("add_food/$mealTypeDb")
                },
                onNavigateToFoodSearch = { mealTypeDb ->
                    navController.navigate("food_search/$mealTypeDb")
                },
                onNavigateToAI = { navigateToTab(navController, BottomNavTab.AI.route) },
                onNavigateToFoodSnap = { mealTypeDb ->
                    navController.navigate("food_snap/$mealTypeDb")
                }
            )
        }

        composable(
            route = "add_food/{${NavArgs.MEAL_TYPE}}",
            arguments = listOf(
                navArgument(NavArgs.MEAL_TYPE) {
                    type = NavType.StringType
                    defaultValue = "breakfast"
                }
            )
        ) { backStackEntry ->
            val mealTypeDb = backStackEntry.arguments?.getString(NavArgs.MEAL_TYPE) ?: "breakfast"
            AddFoodScreen(
                initialMealTypeDb = mealTypeDb,
                onDismiss = { navController.popBackStack() },
                onNavigateToFoodSearch = { mt -> navController.navigate("food_search/$mt") },
                onNavigateToFoodSnap = { mt -> navController.navigate("food_snap/$mt") }
            )
        }

        composable(
            route = "food_search/{${NavArgs.MEAL_TYPE}}",
            arguments = listOf(
                navArgument(NavArgs.MEAL_TYPE) {
                    type = NavType.StringType
                    defaultValue = "breakfast"
                }
            )
        ) { backStackEntry ->
            val mealTypeDb = backStackEntry.arguments?.getString(NavArgs.MEAL_TYPE) ?: "breakfast"
            FoodSearchScreen(
                mealTypeDb = mealTypeDb,
                onFoodSelected = { navController.popBackStack() },
                onDismiss = { navController.popBackStack() }
            )
        }

        composable(
            route = "food_snap/{${NavArgs.MEAL_TYPE}}",
            arguments = listOf(
                navArgument(NavArgs.MEAL_TYPE) {
                    type = NavType.StringType
                    defaultValue = "breakfast"
                }
            )
        ) { backStackEntry ->
            val mealTypeDb = backStackEntry.arguments?.getString(NavArgs.MEAL_TYPE) ?: "breakfast"
            FoodSnapScreen(
                mealTypeDb = mealTypeDb,
                onDismiss = { navController.popBackStack() },
                onNavigateToAddFood = { mt -> navController.navigate("add_food/$mt") }
            )
        }

        // ─── Hydration ───
        composable("hydration") {
            HydrationScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToAI = { navigateToTab(navController, BottomNavTab.AI.route) },
                onNavigateToSettings = { navController.navigate("hydration_settings") }
            )
        }

        composable("hydration_settings") {
            HydrationSettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToNotifications = { navController.navigate("notification_settings") }
            )
        }

        // ─── Menstrual Cycle ───
        composable("cycle_tracker") {
            MenstrualCycleScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ─── Heart Rate ───
        composable("heart_rate") {
            HeartRateScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToAnalytics = { navController.navigate("heart_rate_analytics") },
                onNavigateToAI = { navigateToTab(navController, BottomNavTab.AI.route) }
            )
        }

        composable("heart_rate_analytics") {
            HeartRateAnalyticsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ─── AR Body Scan (Full Screen) ───
        composable("ar_body_scan") {
            ARBodyScanScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ─── Live Workout (Full Screen) ───
        composable(
            route = "live_workout?{NavArgs.WORKOUT_TYPE}={type}",
            arguments = listOf(
                navArgument(NavArgs.WORKOUT_TYPE) {
                    type = NavType.StringType
                    defaultValue = ""
                }
            )
        ) { backStackEntry ->
            val workoutType = backStackEntry.arguments?.getString(NavArgs.WORKOUT_TYPE) ?: ""
            val liveWorkoutViewModel: LiveWorkoutViewModel = hiltViewModel()
            if (workoutType.isNotEmpty()) {
                val wType = try {
                    WorkoutType.valueOf(workoutType.uppercase())
                } catch (_: IllegalArgumentException) { null }
                if (wType != null) {
                    liveWorkoutViewModel.setWorkoutType(wType)
                }
            }
            LiveWorkoutScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ─── Run Calendar ───
        composable("run_calendar") {
            RunCalendarScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToActivityDetail = { workoutId ->
                    navController.navigate("activity_detail/$workoutId")
                }
            )
        }

        // ─── Health Analytics ───
        composable("health_analytics") {
            HealthAnalyticsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToAI = { navigateToTab(navController, BottomNavTab.AI.route) },
                onNavigateToMetricDetail = { metric ->
                    navController.navigate("metric_detail/${metric.name}")
                }
            )
        }

        // ─── Metric Detail ───
        composable(
            route = "metric_detail/{${NavArgs.METRIC_TYPE}}",
            arguments = listOf(
                navArgument(NavArgs.METRIC_TYPE) { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val metricName = backStackEntry.arguments?.getString(NavArgs.METRIC_TYPE) ?: "Steps"
            HealthMetricDetailScreen(
                metricTypeName = metricName,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ─── Activity Detail ───
        composable(
            route = "activity_detail/{${NavArgs.WORKOUT_ID}}",
            arguments = listOf(
                navArgument(NavArgs.WORKOUT_ID) { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val workoutId = backStackEntry.arguments?.getString(NavArgs.WORKOUT_ID) ?: return@composable
            ActivityDetailScreen(
                workoutId = workoutId,
                onNavigateBack = { navController.popBackStack() },
                onDelete = { navController.popBackStack() }
            )
        }

        // ─── Family ───
        composable("family") {
            FamilyScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "family_join/{${NavArgs.FAMILY_CODE}}",
            arguments = listOf(
                navArgument(NavArgs.FAMILY_CODE) { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val code = backStackEntry.arguments?.getString(NavArgs.FAMILY_CODE) ?: ""
            FamilyScreen(
                onNavigateBack = { navController.popBackStack() },
                initialJoinCode = code
            )
        }

        // ─── Settings & Profile ───
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

        // ─── Health Data Sync (list) ───
        composable("health_data_sync") {
            HealthDataSyncScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateTo = { appId ->
                    when (appId) {
                        HealthAppId.HEALTH_CONNECT -> navController.navigate("health_connect_settings")
                        HealthAppId.GOOGLE_HEALTH  -> navController.navigate("google_health_settings")
                        HealthAppId.SAMSUNG_HEALTH -> navController.navigate("samsung_health_settings")
                        HealthAppId.GARMIN_CONNECT -> navController.navigate("garmin_connect_settings")
                    }
                }
            )
        }

        // ─── Individual health app screens ───
        composable("health_connect_settings") {
            HealthConnectSettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable("google_health_settings") {
            GoogleHealthSettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToHealthConnect = { navController.navigate("health_connect_settings") }
            )
        }

        composable("samsung_health_settings") {
            SamsungHealthSettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToHealthConnect = { navController.navigate("health_connect_settings") }
            )
        }

        composable("garmin_connect_settings") {
            GarminConnectSettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToHealthConnect = { navController.navigate("health_connect_settings") }
            )
        }
    }
}

/**
 * Navigate to a bottom tab, properly popping back stack and restoring state.
 */
private fun navigateToTab(navController: NavHostController, tabRoute: String) {
    navController.navigate(tabRoute) {
        popUpTo(navController.graph.startDestinationId) {
            saveState = true
        }
        launchSingleTop = true
        restoreState = true
    }
}
