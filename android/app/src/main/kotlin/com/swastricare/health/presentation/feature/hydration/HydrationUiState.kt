package com.swastricare.health.presentation.feature.hydration

import com.swastricare.health.data.services.WeatherData
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.model.hydration.HydrationGoal
import com.swastricare.health.domain.model.hydration.HydrationInsights
import com.swastricare.health.domain.model.hydration.HydrationPreferences
import java.time.LocalDate

/**
 * UI state for Hydration screens.
 * Represents all possible UI states and computed properties.
 */
data class HydrationUiState(
    val entries: List<HydrationEntry> = emptyList(),
    val preferences: HydrationPreferences = HydrationPreferences.Default,
    val goal: HydrationGoal = HydrationGoal(),
    val insights: HydrationInsights? = null,
    val selectedDate: LocalDate = LocalDate.now(),
    val isLoading: Boolean = false,
    val isSyncing: Boolean = false,
    val error: String? = null,

    // Weather adjustment
    val weatherData: WeatherData? = null,
    val weatherAdjustmentFactor: Double = 1.0,
    val baseGoalMl: Int = 2500
) {
    /**
     * Entries for selected date, sorted newest first.
     */
    val todaysEntries: List<HydrationEntry>
        get() = entries
            .filter { it.consumedAt.toLocalDate() == selectedDate }
            .sortedByDescending { it.consumedAt }

    /**
     * Total intake (raw ml) for selected date.
     */
    val totalIntake: Int
        get() = todaysEntries.sumOf { it.amountMl }

    /**
     * Effective intake (adjusted for drink type) for selected date.
     */
    val effectiveIntake: Int
        get() = todaysEntries.sumOf { it.effectiveMl }

    /**
     * Effective goal adjusted for weather.
     */
    val effectiveGoalMl: Int
        get() = (baseGoalMl * weatherAdjustmentFactor).toInt()

    /**
     * Remaining ml to reach goal.
     */
    val remainingMl: Int
        get() = maxOf(0, effectiveGoalMl - effectiveIntake)

    /**
     * Progress towards goal (0.0 - 1.5, capped at 150%).
     */
    val progress: Float
        get() = if (effectiveGoalMl > 0) {
            (effectiveIntake.toFloat() / effectiveGoalMl).coerceIn(0f, 1.5f)
        } else {
            0f
        }

    /**
     * Whether daily goal is met.
     */
    val isGoalMet: Boolean
        get() = effectiveIntake >= effectiveGoalMl

    /**
     * Whether goal has been adjusted for weather.
     */
    val isWeatherAdjusted: Boolean
        get() = weatherAdjustmentFactor > 1.0

    /**
     * Number of caffeinated drinks today.
     */
    val caffeineEntries: Int
        get() = todaysEntries.count { it.containsCaffeine() }

    /**
     * Total caffeine amount today (ml).
     */
    val caffeineAmountMl: Int
        get() = todaysEntries
            .filter { it.containsCaffeine() }
            .sumOf { it.amountMl }

    /**
     * Check if showing today's data.
     */
    val isShowingToday: Boolean
        get() = selectedDate == LocalDate.now()

    /**
     * Check if has any entries.
     */
    val hasEntries: Boolean
        get() = entries.isNotEmpty()

    /**
     * Check if should show empty state.
     */
    val showEmptyState: Boolean
        get() = !isLoading && !hasEntries && error == null

    /**
     * Get drink type breakdown for today.
     */
    fun getDrinkTypeBreakdown(): Map<DrinkType, Int> {
        return todaysEntries
            .groupBy { it.drinkType }
            .mapValues { (_, entries) -> entries.sumOf { it.amountMl } }
    }

    /**
     * Get hourly distribution for today.
     */
    fun getHourlyDistribution(): Map<Int, Int> {
        return todaysEntries
            .groupBy { it.consumedAt.hour }
            .mapValues { (_, entries) -> entries.sumOf { it.amountMl } }
    }
}
