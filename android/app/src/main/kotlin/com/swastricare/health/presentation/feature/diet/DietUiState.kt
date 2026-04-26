package com.swastricare.health.presentation.feature.diet

import com.swastricare.health.domain.model.DietGoal
import com.swastricare.health.domain.model.DietInsights
import com.swastricare.health.domain.model.FoodEntry
import com.swastricare.health.domain.model.FoodItem
import com.swastricare.health.domain.model.MealType
import com.swastricare.health.domain.model.NutritionSummary
import java.time.LocalDate

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

/**
 * UI state for Diet feature.
 * Represents the complete state of the diet screen.
 */
data class DietUiState(
    val selectedDate: LocalDate = LocalDate.now(),
    val foodEntries: List<FoodEntry> = emptyList(),
    val nutritionSummary: NutritionSummary = NutritionSummary.Empty,
    val dietGoals: DietGoal = DietGoal.Default,
    val cachedFoodItems: List<FoodItem> = emptyList(),
    val favoriteFoodIds: Set<String> = emptySet(),
    val insights: DietInsights? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val snapState: SnapAnalysisState = SnapAnalysisState.Idle,
    val snapImageUri: String? = null,
    /** Entry just deleted; non-null while undo is still possible. */
    val recentlyDeletedEntry: FoodEntry? = null,
    /** One-shot trigger for the undo snackbar — changes whenever a new delete occurs so UI re-presents. */
    val undoSnackbarTriggerId: String? = null
) {
    /**
     * Food entries for the selected date, sorted by time (newest first).
     */
    val todaysEntries: List<FoodEntry>
        get() = foodEntries
            .filter { it.loggedAt.toLocalDate() == selectedDate }
            .sortedByDescending { it.loggedAt }

    /**
     * Gets entries for a specific meal type.
     */
    fun getEntriesForMeal(mealType: MealType): List<FoodEntry> {
        return todaysEntries.filter { it.mealType == mealType }
    }

    /**
     * Total calories consumed today.
     */
    val totalCalories: Int
        get() = nutritionSummary.totalCalories.toInt()

    /**
     * Remaining calories for the day.
     */
    val remainingCalories: Int
        get() = maxOf(0, dietGoals.dailyCalories - totalCalories)

    /**
     * Calorie progress (0.0 to 1.0+).
     */
    val calorieProgress: Float
        get() = if (dietGoals.dailyCalories > 0) {
            (totalCalories.toFloat() / dietGoals.dailyCalories).coerceIn(0f, 1f)
        } else {
            0f
        }

    /**
     * Protein progress (0.0 to 1.0+).
     */
    val proteinProgress: Float
        get() = if (dietGoals.proteinGrams > 0) {
            (nutritionSummary.totalProteinG / dietGoals.proteinGrams).toFloat().coerceIn(0f, 1f)
        } else {
            0f
        }

    /**
     * Carbs progress (0.0 to 1.0+).
     */
    val carbsProgress: Float
        get() = if (dietGoals.carbsGrams > 0) {
            (nutritionSummary.totalCarbsG / dietGoals.carbsGrams).toFloat().coerceIn(0f, 1f)
        } else {
            0f
        }

    /**
     * Fat progress (0.0 to 1.0+).
     */
    val fatProgress: Float
        get() = if (dietGoals.fatGrams > 0) {
            (nutritionSummary.totalFatG / dietGoals.fatGrams).toFloat().coerceIn(0f, 1f)
        } else {
            0f
        }

    /**
     * Goal description for UI display.
     */
    val goalDescription: String
        get() = "Daily goal: ${dietGoals.dailyCalories} cal"

    /**
     * Recent foods (from all entries, deduplicated).
     */
    fun getRecentFoods(limit: Int = 10): List<FoodItem> {
        val seen = mutableSetOf<String>()
        val result = mutableListOf<FoodItem>()

        for (entry in foodEntries.sortedByDescending { it.loggedAt }) {
            if (seen.contains(entry.foodName)) continue
            seen.add(entry.foodName)

            val foodItem = cachedFoodItems.firstOrNull { it.name == entry.foodName }
            if (foodItem != null) {
                result.add(foodItem)
                if (result.size >= limit) break
            }
        }

        return result
    }

    /**
     * Favorite foods.
     */
    val favoriteFoods: List<FoodItem>
        get() = cachedFoodItems.filter { favoriteFoodIds.contains(it.id) }

    /**
     * Checks if a food item is favorited.
     */
    fun isFavorite(foodId: String): Boolean = favoriteFoodIds.contains(foodId)
}

// ─────────────────────────────────────
// MARK: - Snap Analysis State
// ─────────────────────────────────────

/**
 * State for food image analysis.
 */
sealed class SnapAnalysisState {
    data object Idle : SnapAnalysisState()
    data object Analyzing : SnapAnalysisState()
    data class Result(val food: com.swastricare.health.domain.model.AnalyzedFood) : SnapAnalysisState()
    data class Error(val message: String) : SnapAnalysisState()
}

// ─────────────────────────────────────
// MARK: - UI Events
// ─────────────────────────────────────

/**
 * Events that can be triggered from the UI.
 */
sealed class DietUiEvent {
    data class SelectDate(val date: LocalDate) : DietUiEvent()
    data class AddFoodFromItem(
        val foodItem: FoodItem,
        val quantity: Double,
        val mealType: MealType
    ) : DietUiEvent()
    data class AddCustomFood(
        val name: String,
        val mealType: MealType,
        val quantity: Double,
        val servingUnit: com.swastricare.health.domain.model.ServingUnit,
        val calories: Double,
        val proteinG: Double,
        val carbsG: Double,
        val fatG: Double
    ) : DietUiEvent()
    data class DeleteEntry(val entry: FoodEntry) : DietUiEvent()
    /** Restore the most recently deleted entry (only valid for ~5s after delete). */
    data object UndoDelete : DietUiEvent()
    data class UpdateGoals(val goals: DietGoal) : DietUiEvent()
    data class ToggleFavorite(val foodId: String) : DietUiEvent()
    data class SearchFood(val query: String) : DietUiEvent()
    data class AnalyzeFoodImage(val imageUri: android.net.Uri) : DietUiEvent()
    data object ClearSnapState : DietUiEvent()
    data object ClearError : DietUiEvent()
    data object Refresh : DietUiEvent()
}
