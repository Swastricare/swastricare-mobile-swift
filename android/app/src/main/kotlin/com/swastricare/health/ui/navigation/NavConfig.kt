package com.swastricare.health.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.swastricare.health.ui.theme.PrimaryColor

sealed class BottomNavTab(
    val route: String,
    val title: String,
    val icon: ImageVector,        // outlined — unselected
    val selectedIcon: ImageVector // filled — selected
) {
    object Vitals : BottomNavTab(
        route = "vitals",
        title = "Vitals",
        icon = Icons.Outlined.FavoriteBorder,
        selectedIcon = Icons.Filled.Favorite
    )
    object Vault : BottomNavTab(
        route = "vault",
        title = "Vault",
        icon = Icons.Outlined.LockOpen,
        selectedIcon = Icons.Filled.Lock
    )
    object AI : BottomNavTab(
        route = "ai",
        title = "AI",
        icon = Icons.Outlined.AutoAwesome,
        selectedIcon = Icons.Filled.AutoAwesome
    )
    object Steps : BottomNavTab(
        route = "steps",
        title = "Activity",
        icon = Icons.Outlined.DirectionsRun,
        selectedIcon = Icons.Filled.DirectionsRun
    )
    object Profile : BottomNavTab(
        route = "profile",
        title = "Profile",
        icon = Icons.Outlined.PersonOutline,
        selectedIcon = Icons.Filled.Person
    )

    companion object {
        val items = listOf(Vitals, Vault, AI, Steps, Profile)

        fun isTabRoute(route: String): Boolean = items.any { it.route == route }
    }
}

object BottomNavConfig {
    fun shouldShowBottomNav(currentRoute: String?): Boolean {
        if (currentRoute == null) return false
        return BottomNavTab.isTabRoute(currentRoute)
    }
}

object NavArgs {
    const val MEDICATION_ID = "medicationId"
    const val WORKOUT_ID = "workoutId"
    const val MEAL_TYPE = "mealTypeDb"
    const val WORKOUT_TYPE = "type"
    const val FAMILY_CODE = "code"
    const val METRIC_TYPE = "metricType"
}
