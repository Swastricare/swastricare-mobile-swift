package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCaseNoParams
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.DietInsights
import com.swastricare.health.domain.model.MacroBalance
import com.swastricare.health.domain.repository.DietRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for calculating diet insights (weekly average, streak, top foods, macro balance).
 */
class GetDietInsightsUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCaseNoParams<DietInsights?>() {

    override suspend fun execute(): ResultWrapper<DietInsights?> {
        val entriesResult = repository.getAllFoodEntries()
        if (entriesResult !is ResultWrapper.Success) {
            return entriesResult as ResultWrapper.Error
        }

        val allEntries = entriesResult.data
        if (allEntries.isEmpty()) {
            return ResultWrapper.Success(null)
        }

        // Calculate weekly average
        val sevenDaysAgo = LocalDate.now().minusDays(7)
        val weekEntries = allEntries.filter {
            it.loggedAt.toLocalDate() >= sevenDaysAgo
        }

        val byDay = weekEntries.groupBy { it.loggedAt.toLocalDate() }
        val weeklyAvg = if (byDay.isNotEmpty()) {
            (weekEntries.sumOf { it.nutritionInfo.calories } / byDay.size).toInt()
        } else {
            0
        }

        // Calculate streak
        val streak = calculateStreak(allEntries)

        // Top foods
        val topFoods = allEntries
            .groupBy { it.foodName }
            .entries
            .sortedByDescending { it.value.size }
            .take(3)
            .map { it.key }

        // Macro balance (today)
        val todayEntries = allEntries.filter {
            it.loggedAt.toLocalDate() == LocalDate.now()
        }
        val macroBalance = calculateMacroBalance(todayEntries)

        return ResultWrapper.Success(
            DietInsights(
                weeklyAverageCalories = weeklyAvg,
                currentStreak = streak,
                topFoods = topFoods,
                macroBalancePercent = macroBalance
            )
        )
    }

    private fun calculateStreak(entries: List<com.swastricare.health.domain.model.FoodEntry>): Int {
        var streak = 0
        var date = LocalDate.now()

        while (true) {
            val hasEntry = entries.any { it.loggedAt.toLocalDate() == date }
            if (!hasEntry) break
            streak++
            date = date.minusDays(1)
        }

        return streak
    }

    private fun calculateMacroBalance(entries: List<com.swastricare.health.domain.model.FoodEntry>): MacroBalance {
        if (entries.isEmpty()) {
            return MacroBalance(0, 0, 0)
        }

        val totalProteinCal = entries.sumOf { it.nutritionInfo.caloriesFromProtein }
        val totalCarbsCal = entries.sumOf { it.nutritionInfo.caloriesFromCarbs }
        val totalFatCal = entries.sumOf { it.nutritionInfo.caloriesFromFat }
        val total = (totalProteinCal + totalCarbsCal + totalFatCal).coerceAtLeast(1.0)

        return MacroBalance(
            proteinPercent = (totalProteinCal / total * 100).toInt(),
            carbsPercent = (totalCarbsCal / total * 100).toInt(),
            fatPercent = (totalFatCal / total * 100).toInt()
        )
    }
}
