package com.swastricare.health.ui.navigation

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.composables.icons.lucide.Activity
import com.composables.icons.lucide.Heart
import com.composables.icons.lucide.Lock
import com.composables.icons.lucide.Lucide
import com.composables.icons.lucide.Sparkles
import com.composables.icons.lucide.User
import com.swastricare.health.ui.theme.PrimaryColor

// Materialize Lucide icon ImageVectors (stroke-only; same icon for default and selected states —
// selection is communicated via color change only).
private val iconHeart: ImageVector = Lucide.Heart
private val iconLock: ImageVector = Lucide.Lock
private val iconSparkles: ImageVector = Lucide.Sparkles
private val iconActivity: ImageVector = Lucide.Activity
private val iconUser: ImageVector = Lucide.User

/**
 * Defines a bottom navigation tab with route, label, icons, and semantic color.
 * The [color] field is retained for API compatibility but all tabs use [PrimaryColor].
 */
sealed class BottomNavTab(
    val route: String,
    val title: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector,
    val color: Color
) {
    object Vitals : BottomNavTab(
        route = "vitals",
        title = "Vitals",
        icon = iconHeart,
        selectedIcon = iconHeart,
        color = PrimaryColor
    )
    object Vault : BottomNavTab(
        route = "vault",
        title = "Vault",
        icon = iconLock,
        selectedIcon = iconLock,
        color = PrimaryColor
    )
    object AI : BottomNavTab(
        route = "ai",
        title = "AI",
        icon = iconSparkles,
        selectedIcon = iconSparkles,
        color = PrimaryColor
    )
    object Steps : BottomNavTab(
        route = "steps",
        title = "Activity",
        icon = iconActivity,
        selectedIcon = iconActivity,
        color = PrimaryColor
    )
    object Profile : BottomNavTab(
        route = "profile",
        title = "Profile",
        icon = iconUser,
        selectedIcon = iconUser,
        color = PrimaryColor
    )

    companion object {
        val items = listOf(Vitals, Vault, AI, Steps, Profile)

        fun isTabRoute(route: String): Boolean = items.any { it.route == route }
    }
}

/**
 * Bottom navigation is shown ONLY on the 5 main tab routes.
 * Every nested / sub-screen hides the bar automatically.
 */
object BottomNavConfig {
    fun shouldShowBottomNav(currentRoute: String?): Boolean {
        if (currentRoute == null) return false
        // Show only when the current route is one of the 5 tabs
        return BottomNavTab.isTabRoute(currentRoute)
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
    const val METRIC_TYPE = "metricType"
}
