package com.swasthicare.mobile.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * Marker interface for screens that should not show the bottom navigation bar.
 * Implement this on screen composables to indicate they are full-screen.
 */
interface FullScreenRoute

/**
 * Defines a bottom navigation tab route.
 */
sealed class BottomNavTab(
    val route: String,
    val title: String,
    val selectedIcon: String,
    val unselectedIcon: String
) {
    object Vitals : BottomNavTab(
        route = "vitals",
        title = "Vitals",
        selectedIcon = "favorite",
        unselectedIcon = "favorite_border"
    )
    object Vault : BottomNavTab(
        route = "vault",
        title = "Vault",
        selectedIcon = "lock",
        unselectedIcon = "lock_outline"
    )
    object AI : BottomNavTab(
        route = "ai",
        title = "AI",
        selectedIcon = "auto_awesome",
        unselectedIcon = "auto_awesome"
    )
    object Steps : BottomNavTab(
        route = "steps",
        title = "Steps",
        selectedIcon = "directions_run",
        unselectedIcon = "directions_run"
    )
    object Profile : BottomNavTab(
        route = "profile",
        title = "Profile",
        selectedIcon = "person",
        unselectedIcon = "person_outline"
    )

    companion object {
        val items = listOf(Vitals, Vault, AI, Steps, Profile)

        /**
         * Returns true if the given route is a bottom nav tab route.
         */
        fun isTabRoute(route: String): Boolean = items.any { it.route == route }
    }
}

/**
 * Routes where bottom navigation should be hidden.
 */
object BottomNavConfig {
    val hiddenRoutes = setOf(
        "live_workout",
        "workout_summary",
        "ar_body_scan"
    )

    /**
     * Returns true if bottom navigation should be shown for the given route.
     */
    fun shouldShowBottomNav(currentRoute: String?): Boolean {
        if (currentRoute == null) return true
        // Don't hide on tab routes - they're the main containers
        if (BottomNavTab.isTabRoute(currentRoute)) return true
        return currentRoute !in hiddenRoutes
    }
}

/**
 * Navigation argument keys for type-safe navigation.
 */
object NavArgs {
    const val MEDICATION_ID = "medicationId"
    const val WORKOUT_ID = "workoutId"
    const val MEAL_TYPE = "mealTypeDb"
    const val WORKOUT_TYPE = "type"
    const val FAMILY_CODE = "code"
}
