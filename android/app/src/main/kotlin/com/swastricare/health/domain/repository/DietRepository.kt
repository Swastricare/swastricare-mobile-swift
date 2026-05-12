package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.AnalyzedFood
import com.swastricare.health.domain.model.DietGoal
import com.swastricare.health.domain.model.FoodEntry
import com.swastricare.health.domain.model.FoodItem
import java.time.LocalDate

/**
 * Repository interface for Diet operations.
 * This defines the contract that the data layer must implement.
 * Domain layer depends on this abstraction, not on concrete implementations.
 */
interface DietRepository {

    // ─────────────────────────────────────
    // MARK: - Food Items
    // ─────────────────────────────────────

    /**
     * Fetches food items from the remote data source.
     * Results are cached locally for offline access.
     */
    suspend fun fetchFoodItems(limit: Int = 500): ResultWrapper<List<FoodItem>>

    /**
     * Gets cached food items from local storage.
     */
    suspend fun getCachedFoodItems(): ResultWrapper<List<FoodItem>>

    /**
     * Searches food items by name or brand.
     */
    suspend fun searchFoodItems(query: String): ResultWrapper<List<FoodItem>>

    // ─────────────────────────────────────
    // MARK: - Food Entries (Logs)
    // ─────────────────────────────────────

    /**
     * Gets food entries for a specific date.
     */
    suspend fun getFoodEntriesForDate(date: LocalDate): ResultWrapper<List<FoodEntry>>

    /**
     * Gets all food entries (for streak and insights calculation).
     */
    suspend fun getAllFoodEntries(): ResultWrapper<List<FoodEntry>>

    /**
     * Adds a new food entry.
     */
    suspend fun addFoodEntry(entry: FoodEntry): ResultWrapper<Unit>

    /**
     * Deletes a food entry by ID.
     */
    suspend fun deleteFoodEntry(entryId: String): ResultWrapper<Unit>

    /**
     * Syncs unsynced entries to the cloud.
     */
    suspend fun syncEntries(): ResultWrapper<Unit>

    // ─────────────────────────────────────
    // MARK: - Goals
    // ─────────────────────────────────────

    /**
     * Gets the current diet goals.
     */
    suspend fun getDietGoals(): ResultWrapper<DietGoal>

    /**
     * Updates diet goals.
     */
    suspend fun updateDietGoals(goals: DietGoal): ResultWrapper<Unit>

    // ─────────────────────────────────────
    // MARK: - Favorites
    // ─────────────────────────────────────

    /**
     * Gets favorite food item IDs.
     */
    suspend fun getFavoriteFoodIds(): ResultWrapper<Set<String>>

    /**
     * Toggles favorite status for a food item.
     */
    suspend fun toggleFavorite(foodItemId: String): ResultWrapper<Unit>

    /**
     * Gets favorite food items.
     */
    suspend fun getFavoriteFoods(): ResultWrapper<List<FoodItem>>

    // ─────────────────────────────────────
    // MARK: - AI Food Analysis
    // ─────────────────────────────────────

    /**
     * Analyzes a food image using AI.
     */
    suspend fun analyzeFoodImage(imageBase64: String): ResultWrapper<AnalyzedFood>

    // ─────────────────────────────────────
    // MARK: - Family Dashboard
    // ─────────────────────────────────────

    /**
     * Sum the calorie intake from `diet_logs` for the given profile on [date].
     * Returns 0 (wrapped in Success) when the profile has no entries.
     */
    suspend fun getDayCalories(profileId: String, date: LocalDate): ResultWrapper<Int>
}
