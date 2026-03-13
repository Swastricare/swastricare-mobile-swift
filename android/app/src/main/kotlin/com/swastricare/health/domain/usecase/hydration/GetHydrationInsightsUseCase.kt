package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.model.hydration.HydrationGoal
import com.swastricare.health.domain.model.hydration.HydrationInsights
import com.swastricare.health.domain.repository.HydrationRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case: Calculate hydration insights and statistics.
 */
class GetHydrationInsightsUseCase @Inject constructor(
    private val repository: HydrationRepository
) {
    /**
     * Calculate hydration insights from entries.
     *
     * @param goal Current hydration goal for streak calculation
     * @return Insights or null if no data available
     */
    suspend operator fun invoke(goal: HydrationGoal): HydrationInsights? {
        val entries = repository.loadLocalEntries()
        if (entries.isEmpty()) return null

        return HydrationInsights(
            streakDays = calculateStreak(entries, goal),
            avgDailyIntake = calculateAvgDailyIntake(entries),
            mostCommonDrink = findMostCommonDrink(entries),
            caffeineCount = calculateCaffeineCount(entries),
            caffeineAmountMl = calculateCaffeineAmount(entries)
        )
    }

    /**
     * Calculate streak of days meeting hydration goal.
     */
    private fun calculateStreak(entries: List<HydrationEntry>, goal: HydrationGoal): Int {
        if (goal.dailyGoalMl <= 0) return 0

        var streak = 0
        var date = LocalDate.now()
        val maxDays = 365

        while (streak < maxDays) {
            val dayEffective = entries
                .filter { it.consumedAt.toLocalDate() == date }
                .sumOf { it.effectiveMl }

            // Require at least 50% of goal to count as streak day
            if (dayEffective < goal.dailyGoalMl * 0.5) break

            streak++
            date = date.minusDays(1)
        }

        return streak
    }

    /**
     * Calculate average daily intake over the last 7 days.
     */
    private fun calculateAvgDailyIntake(entries: List<HydrationEntry>): Int {
        val sevenDaysAgo = LocalDate.now().minusDays(7)
        val weekEntries = entries.filter { it.consumedAt.toLocalDate() >= sevenDaysAgo }

        if (weekEntries.isEmpty()) return 0

        val byDay = weekEntries.groupBy { it.consumedAt.toLocalDate() }
        return byDay.values.sumOf { dayEntries ->
            dayEntries.sumOf { it.effectiveMl }
        } / byDay.size
    }

    /**
     * Find the most commonly consumed drink type.
     */
    private fun findMostCommonDrink(entries: List<HydrationEntry>): String? {
        return entries
            .groupBy { it.drinkType }
            .maxByOrNull { it.value.size }
            ?.key
            ?.displayName
    }

    /**
     * Calculate number of caffeinated drinks consumed today.
     */
    private fun calculateCaffeineCount(entries: List<HydrationEntry>): Int {
        val today = LocalDate.now()
        return entries.count {
            it.consumedAt.toLocalDate() == today && it.containsCaffeine()
        }
    }

    /**
     * Calculate total caffeine amount consumed today (ml).
     */
    private fun calculateCaffeineAmount(entries: List<HydrationEntry>): Int {
        val today = LocalDate.now()
        return entries
            .filter { it.consumedAt.toLocalDate() == today && it.containsCaffeine() }
            .sumOf { it.amountMl }
    }
}
