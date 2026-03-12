package com.swastricare.health.ui.navigation

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.composables.icons.lucide.Footprints
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
private val iconFootprints: ImageVector = Lucide.Footprints
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
        title = "Steps",
        icon = iconFootprints,
        selectedIcon = iconFootprints,
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
 * Routes where bottom navigation should be hidden.
 */
object BottomNavConfig {
    val hiddenRoutes = setOf(
        "live_workout",
        "workout_summary",
        "ar_body_scan"
    )

    fun shouldShowBottomNav(currentRoute: String?): Boolean {
        if (currentRoute == null) return true
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
