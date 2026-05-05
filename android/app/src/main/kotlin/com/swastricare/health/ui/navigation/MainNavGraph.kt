package com.swastricare.health.ui.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.swastricare.health.ui.screens.ai.AIScreen
import com.swastricare.health.ui.screens.home.HomeScreenV2
import com.swastricare.health.ui.screens.home.HomeScreenV3
import com.swastricare.health.ui.screens.runactivity.RunActivityScreen
import com.swastricare.health.ui.screens.runactivity.WorkoutType
import com.swastricare.health.ui.screens.settings.SettingsScreen
import com.swastricare.health.ui.screens.vault.VaultScreen

/**
 * Inner navigation graph for the 5 bottom-nav tabs.
 *
 * The 5 tabs (Vitals, Vault, AI, Steps, Profile) are the only destinations
 * in this graph. Any detail or nested screen opened from a tab lives at
 * the top-level [AppNavigation] graph — so when a nested screen is shown
 * it is *not* inside [MainScaffold] at all, and the bottom nav bar isn't
 * part of that screen's layout.
 *
 * [onNavigateTo] is the single callback used to leave this graph and open
 * a top-level route (Medications, Hydration, Diet, etc.). The route
 * string is passed as-is to the root NavController in [AppNavigation].
 */
@Composable
fun MainNavGraph(
    navController: NavHostController,
    modifier: Modifier = Modifier,
    onSignOut: () -> Unit,
    onAiFullScreenChange: (Boolean) -> Unit = {},
    onNavigateTo: (route: String) -> Unit,
    onNavigateToLiveWorkout: (WorkoutType?) -> Unit,
    onNavigateToActivityDetail: (workoutId: String) -> Unit
) {
    // Tab→tab switches fade through — no horizontal slide, since tabs are
    // peers, not forward/back navigation.
    NavHost(
        navController = navController,
        startDestination = BottomNavTab.Vitals.route,
        modifier = modifier,
        enterTransition = { fadeIn(tween(180)) },
        exitTransition = { fadeOut(tween(180)) },
        popEnterTransition = { fadeIn(tween(180)) },
        popExitTransition = { fadeOut(tween(180)) }
    ) {
        composable(BottomNavTab.Vitals.route) {
            HomeScreenV3(
                onNavigateToMedications = { onNavigateTo("medications") },
                onNavigateToDiet = { onNavigateTo("diet") },
                onNavigateToHydration = { onNavigateTo("hydration") },
                onNavigateToCycleTracker = { onNavigateTo("cycle_tracker") },
                onNavigateToHeartRate = { onNavigateTo("heart_rate") },
                onNavigateToStress = { onNavigateTo("stress") },
                onNavigateToSleep = { onNavigateTo("sleep") },
                onNavigateToBodyScan = { onNavigateTo("ar_body_scan") },
                onNavigateToNotifications = { onNavigateTo("notification_history") },
                onNavigateToAnalytics = { onNavigateTo("health_analytics") },
                onNavigateToAIChat = {
                    navController.navigate(BottomNavTab.AI.route) {
                        popUpTo(navController.graph.startDestinationId) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                },
                onNavigateToRoute = { route -> onNavigateTo(route) }
            )
        }

        composable(BottomNavTab.Vault.route) {
            VaultScreen(
                onNavigateToAIChat = {
                    navController.navigate(BottomNavTab.AI.route) {
                        popUpTo(navController.graph.startDestinationId) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            )
        }

        composable(BottomNavTab.AI.route) {
            AIScreen(onFullScreenChange = onAiFullScreenChange)
        }

        composable(BottomNavTab.Steps.route) {
            RunActivityScreen(
                onNavigateToLiveWorkout = onNavigateToLiveWorkout,
                onNavigateToActivityDetail = onNavigateToActivityDetail,
                onNavigateToCalendar = { onNavigateTo("run_calendar") }
            )
        }

        composable(BottomNavTab.Profile.route) {
            SettingsScreen(
                onNavigateBack = { /* Profile is a root tab, nothing to pop */ },
                onNavigateToEditProfile = { onNavigateTo("edit_profile") },
                onNavigateToFamily = { onNavigateTo("family") },
                onNavigateToNotificationSettings = { onNavigateTo("notification_settings") },
                onNavigateToHydrationSettings = { onNavigateTo("hydration_settings") },
                onNavigateToHealthDataSync = { onNavigateTo("health_data_sync") },
                onNavigateToThemeSettings = { onNavigateTo("theme_settings") },
                onNavigateToActivityGoals = { onNavigateTo("activity_goals") },
                onSignOut = onSignOut
            )
        }
    }
}
