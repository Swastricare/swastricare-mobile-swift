package com.swasthicare.mobile.ui.navigation

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.adamglin.phosphoricons.FillGroup
import com.adamglin.phosphoricons.RegularGroup
import com.adamglin.phosphoricons.fill.Heart as HeartFillIcon
import com.adamglin.phosphoricons.fill.Lock as LockFillIcon
import com.adamglin.phosphoricons.fill.Sneaker as SneakerFillIcon
import com.adamglin.phosphoricons.fill.Sparkle as SparkleFillIcon
import com.adamglin.phosphoricons.fill.User as UserFillIcon
import com.adamglin.phosphoricons.regular.Heart as HeartRegularIcon
import com.adamglin.phosphoricons.regular.Lock as LockRegularIcon
import com.adamglin.phosphoricons.regular.Sneaker as SneakerRegularIcon
import com.adamglin.phosphoricons.regular.Sparkle as SparkleRegularIcon
import com.adamglin.phosphoricons.regular.User as UserRegularIcon
import com.swasthicare.mobile.ui.theme.HeartRateColor
import com.swasthicare.mobile.ui.theme.MedicationColor
import com.swasthicare.mobile.ui.theme.PrimaryColor
import com.swasthicare.mobile.ui.theme.StepsColor
import com.swasthicare.mobile.ui.theme.SystemBlue

// Materialize Phosphor icon ImageVectors by calling the extension properties
// on their respective receiver objects (RegularGroup / FillGroup singletons).
private val iconHeartRegular: ImageVector = with(RegularGroup) { HeartRegularIcon }
private val iconHeartFill: ImageVector = with(FillGroup) { HeartFillIcon }
private val iconLockRegular: ImageVector = with(RegularGroup) { LockRegularIcon }
private val iconLockFill: ImageVector = with(FillGroup) { LockFillIcon }
private val iconSparkleRegular: ImageVector = with(RegularGroup) { SparkleRegularIcon }
private val iconSparkleFill: ImageVector = with(FillGroup) { SparkleFillIcon }
private val iconSneakerRegular: ImageVector = with(RegularGroup) { SneakerRegularIcon }
private val iconSneakerFill: ImageVector = with(FillGroup) { SneakerFillIcon }
private val iconUserRegular: ImageVector = with(RegularGroup) { UserRegularIcon }
private val iconUserFill: ImageVector = with(FillGroup) { UserFillIcon }

/**
 * Defines a bottom navigation tab with route, label, icons, and semantic color.
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
        icon = iconHeartRegular,
        selectedIcon = iconHeartFill,
        color = HeartRateColor
    )
    object Vault : BottomNavTab(
        route = "vault",
        title = "Vault",
        icon = iconLockRegular,
        selectedIcon = iconLockFill,
        color = MedicationColor
    )
    object AI : BottomNavTab(
        route = "ai",
        title = "AI",
        icon = iconSparkleRegular,
        selectedIcon = iconSparkleFill,
        color = PrimaryColor
    )
    object Steps : BottomNavTab(
        route = "steps",
        title = "Steps",
        icon = iconSneakerRegular,
        selectedIcon = iconSneakerFill,
        color = StepsColor
    )
    object Profile : BottomNavTab(
        route = "profile",
        title = "Profile",
        icon = iconUserRegular,
        selectedIcon = iconUserFill,
        color = SystemBlue
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
