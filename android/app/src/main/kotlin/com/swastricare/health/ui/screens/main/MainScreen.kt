package com.swastricare.health.ui.screens.main

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.swastricare.health.ui.components.OfflineBanner
import com.swastricare.health.ui.navigation.BottomNavTab
import com.swastricare.health.ui.navigation.MainNavGraph
import com.swastricare.health.ui.navigation.MainScaffold
import com.swastricare.health.ui.screens.runactivity.WorkoutType

/**
 * The bottom-nav shell for the authenticated app.
 *
 * Only the 5 tab screens (Vitals, Vault, AI, Steps, Profile) live inside
 * this shell. Any detail/nested screen (Medications, Hydration, etc.) is
 * a top-level destination owned by [AppNavigation] and isn't part of the
 * bottom-nav layout at all — opening one leaves MainScreen.
 *
 * Navigation to those top-level routes is bubbled up via [onNavigateTo].
 */
@Composable
fun MainScreen(
    onSignOut: () -> Unit = {},
    onNavigateTo: (route: String) -> Unit
) {
    val navController = rememberNavController()
    val mainScreenViewModel: MainScreenViewModel = hiltViewModel()

    // Track current route for analytics
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // AI full-screen mode — only reason (besides the keyboard) the bar hides.
    var aiFullScreen by remember { mutableStateOf(false) }

    // Reset AI full-screen when navigating away from the AI tab.
    LaunchedEffect(currentRoute) {
        if (currentRoute != BottomNavTab.AI.route) {
            aiFullScreen = false
        }
    }

    val tabItems = remember { BottomNavTab.items }

    // Analytics: track screen view when route changes.
    LaunchedEffect(currentRoute) {
        if (currentRoute != null) {
            val screenName = tabItems.firstOrNull { it.route == currentRoute }?.title ?: currentRoute
            mainScreenViewModel.trackScreenView(screenName)
        }
    }

    MainScaffold(
        navController = navController,
        aiFullScreen = aiFullScreen
    ) { modifier ->
        Column(modifier = modifier) {
            OfflineBanner(networkMonitor = mainScreenViewModel.networkMonitor)
            MainNavGraph(
                navController = navController,
                modifier = Modifier.weight(1f),
                onSignOut = onSignOut,
                onAiFullScreenChange = { aiFullScreen = it },
                onNavigateTo = onNavigateTo,
                onNavigateToLiveWorkout = { workoutType ->
                    val route = if (workoutType != null) {
                        "live_workout?type=${workoutType.name}"
                    } else {
                        "live_workout"
                    }
                    onNavigateTo(route)
                },
                onNavigateToActivityDetail = { workoutId ->
                    onNavigateTo("activity_detail/$workoutId")
                }
            )
        }
    }
}
