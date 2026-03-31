package com.swastricare.health.ui.screens.nutritrack

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

@Composable
fun NutriTrackNavigation() {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = "nutritrack_dashboard",
        enterTransition = { slideInHorizontally(initialOffsetX = { it }) + fadeIn(tween(300)) },
        exitTransition = { slideOutHorizontally(targetOffsetX = { -it / 3 }) + fadeOut(tween(300)) },
        popEnterTransition = { slideInHorizontally(initialOffsetX = { -it / 3 }) + fadeIn(tween(300)) },
        popExitTransition = { slideOutHorizontally(targetOffsetX = { it }) + fadeOut(tween(300)) }
    ) {
        composable("nutritrack_dashboard") {
            NutriTrackDashboardScreen(
                onNavigateToActivity = { navController.navigate("nutritrack_activity") },
                onNavigateToAddBreakfast = { navController.navigate("nutritrack_add_breakfast") }
            )
        }

        composable("nutritrack_activity") {
            ActivityScheduleScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToAddBreakfast = { navController.navigate("nutritrack_add_breakfast") }
            )
        }

        composable("nutritrack_add_breakfast") {
            AddBreakfastScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
