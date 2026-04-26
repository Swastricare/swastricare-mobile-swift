package com.swastricare.health.presentation.feature.diet

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.services.ImageUtils
import com.swastricare.health.domain.model.DietGoal
import com.swastricare.health.domain.model.FoodItem
import com.swastricare.health.domain.model.MealType
import com.swastricare.health.domain.model.NutritionInfo
import com.swastricare.health.domain.usecase.diet.AddFoodEntryUseCase
import com.swastricare.health.domain.usecase.diet.AnalyzeFoodImageUseCase
import com.swastricare.health.domain.usecase.diet.DeleteFoodEntryUseCase
import com.swastricare.health.domain.usecase.diet.GetDietInsightsUseCase
import com.swastricare.health.domain.usecase.diet.GetFoodEntriesUseCase
import com.swastricare.health.domain.usecase.diet.GetNutritionSummaryUseCase
import com.swastricare.health.domain.usecase.diet.SearchFoodUseCase
import com.swastricare.health.domain.usecase.diet.UpdateDietGoalsUseCase
import com.swastricare.health.domain.repository.DietRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import java.time.LocalDate
import javax.inject.Inject

/**
 * ViewModel for Diet feature.
 * Uses Clean Architecture with use cases for business logic.
 * Hilt-injected for dependency management.
 */
@HiltViewModel
class DietViewModel @Inject constructor(
    private val repository: DietRepository,
    private val addFoodEntryUseCase: AddFoodEntryUseCase,
    private val getFoodEntriesUseCase: GetFoodEntriesUseCase,
    private val getNutritionSummaryUseCase: GetNutritionSummaryUseCase,
    private val getDietInsightsUseCase: GetDietInsightsUseCase,
    private val deleteFoodEntryUseCase: DeleteFoodEntryUseCase,
    private val updateDietGoalsUseCase: UpdateDietGoalsUseCase,
    private val searchFoodUseCase: SearchFoodUseCase,
    private val analyzeFoodImageUseCase: AnalyzeFoodImageUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(DietUiState(isLoading = true))
    val uiState: StateFlow<DietUiState> = _uiState.asStateFlow()

    /** Pending finalize-delete job; cancellation = the user undid before 5s expired. */
    private var undoJob: Job? = null

    init {
        loadData()
    }

    // ─────────────────────────────────────
    // MARK: - Public API
    // ─────────────────────────────────────

    fun onEvent(event: DietUiEvent) {
        when (event) {
            is DietUiEvent.SelectDate -> selectDate(event.date)
            is DietUiEvent.AddFoodFromItem -> addFoodFromItem(
                event.foodItem,
                event.quantity,
                event.mealType
            )
            is DietUiEvent.AddCustomFood -> addCustomFood(
                event.name,
                event.mealType,
                event.quantity,
                event.servingUnit,
                event.calories,
                event.proteinG,
                event.carbsG,
                event.fatG
            )
            is DietUiEvent.DeleteEntry -> deleteEntry(event.entry)
            is DietUiEvent.UndoDelete -> undoDelete()
            is DietUiEvent.UpdateGoals -> updateGoals(event.goals)
            is DietUiEvent.ToggleFavorite -> toggleFavorite(event.foodId)
            is DietUiEvent.SearchFood -> searchFood(event.query)
            is DietUiEvent.AnalyzeFoodImage -> analyzeFoodImage(event.imageUri)
            is DietUiEvent.ClearSnapState -> clearSnapState()
            is DietUiEvent.ClearError -> clearError()
            is DietUiEvent.Refresh -> loadData()
        }
    }

    fun searchFood(query: String): List<FoodItem> {
        if (query.isBlank()) return emptyList()

        val lower = query.lowercase()
        return _uiState.value.cachedFoodItems.filter { item ->
            item.name.lowercase().contains(lower) ||
            item.brand?.lowercase()?.contains(lower) == true
        }
    }

    // ─────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────

    private fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            // Load diet goals
            val goalsResult = repository.getDietGoals()
            val goals = goalsResult.getOrNull() ?: DietGoal.Default

            // Load cached food items
            val cachedFoodsResult = repository.getCachedFoodItems()
            val cachedFoods = cachedFoodsResult.getOrNull() ?: emptyList()

            // Load favorite IDs
            val favoritesResult = repository.getFavoriteFoodIds()
            val favorites = favoritesResult.getOrNull() ?: emptySet()

            // Load food entries for today
            val entriesResult = repository.getAllFoodEntries()
            val allEntries = entriesResult.getOrNull() ?: emptyList()

            // Calculate nutrition summary
            val nutritionResult = getNutritionSummaryUseCase(
                GetNutritionSummaryUseCase.Params(_uiState.value.selectedDate)
            )
            val nutrition = nutritionResult.getOrNull() ?: com.swastricare.health.domain.model.NutritionSummary.Empty

            // Calculate insights
            val insightsResult = getDietInsightsUseCase()
            val insights = insightsResult.getOrNull()

            _uiState.value = _uiState.value.copy(
                foodEntries = allEntries,
                nutritionSummary = nutrition,
                dietGoals = goals,
                cachedFoodItems = cachedFoods,
                favoriteFoodIds = favorites,
                insights = insights,
                isLoading = false
            )

            // Background: fetch fresh food items and sync
            syncInBackground()
        }
    }

    private fun selectDate(date: LocalDate) {
        viewModelScope.launch {
            val nutritionResult = getNutritionSummaryUseCase(
                GetNutritionSummaryUseCase.Params(date)
            )
            val nutrition = nutritionResult.getOrNull() ?: com.swastricare.health.domain.model.NutritionSummary.Empty

            _uiState.value = _uiState.value.copy(
                selectedDate = date,
                nutritionSummary = nutrition
            )
        }
    }

    private fun addFoodFromItem(
        foodItem: FoodItem,
        quantity: Double,
        mealType: MealType
    ) {
        viewModelScope.launch {
            val result = addFoodEntryUseCase(
                AddFoodEntryUseCase.Params.FromFoodItem(
                    foodItem = foodItem,
                    quantity = quantity,
                    mealType = mealType
                )
            )

            when (result) {
                is ResultWrapper.Success -> {
                    refreshLocalData()
                    // Background sync to cloud
                    launch { repository.syncEntries() }
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = result.exception.getUserMessage()
                    )
                }
                is ResultWrapper.Loading -> { /* No-op */ }
            }
        }
    }

    private fun addCustomFood(
        name: String,
        mealType: MealType,
        quantity: Double,
        servingUnit: com.swastricare.health.domain.model.ServingUnit,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) {
        viewModelScope.launch {
            val result = addFoodEntryUseCase(
                AddFoodEntryUseCase.Params.Custom(
                    foodName = name,
                    mealType = mealType,
                    quantity = quantity,
                    servingUnit = servingUnit,
                    nutritionInfo = NutritionInfo(
                        calories = calories,
                        proteinG = proteinG,
                        carbsG = carbsG,
                        fatG = fatG
                    )
                )
            )

            when (result) {
                is ResultWrapper.Success -> {
                    refreshLocalData()
                    launch { repository.syncEntries() }
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = result.exception.getUserMessage()
                    )
                }
                is ResultWrapper.Loading -> { /* No-op */ }
            }
        }
    }

    /**
     * Optimistic delete with 5-second undo window (matches iOS DietViewModel.deleteLog).
     *
     * Flow:
     *   1. If a different entry is already in its undo window, finalize it first
     *      (cancel its timer and commit the cloud delete) so we never have two
     *      entries pending undo simultaneously.
     *   2. Stash the entry, remove from the visible list, and refresh nutrition.
     *      The user sees an immediate change.
     *   3. Start a 5s timer that finalizes the cloud delete on expiry.
     *   4. If `undoDelete()` runs before the timer fires, the entry is restored
     *      via repository.addFoodEntry() (preserves original UUID + loggedAt).
     */
    private fun deleteEntry(entry: com.swastricare.health.domain.model.FoodEntry) {
        // (1) If there's an active undo for a *different* entry, finalize it now.
        val active = _uiState.value.recentlyDeletedEntry
        if (active != null && active.id != entry.id) {
            finalizePreviousDelete(active.id)
        }

        // Cancel any leftover timer for the same entry (rapid re-delete).
        undoJob?.cancel()

        // (2) Optimistic UI update: remove from list, stash for undo.
        val remaining = _uiState.value.foodEntries.filter { it.id != entry.id }
        _uiState.value = _uiState.value.copy(
            foodEntries = remaining,
            recentlyDeletedEntry = entry,
            // Trigger ID changes per delete so the UI re-presents the snackbar
            undoSnackbarTriggerId = UUID.randomUUID().toString()
        )

        viewModelScope.launch {
            refreshNutritionSummary()
        }

        // (3) Schedule cloud finalize after 5s.
        undoJob = viewModelScope.launch {
            delay(5_000)
            // Only finalize if THIS entry is still the active undo.
            if (_uiState.value.recentlyDeletedEntry?.id == entry.id) {
                val result = deleteFoodEntryUseCase(DeleteFoodEntryUseCase.Params(entry.id))
                when (result) {
                    is ResultWrapper.Success -> {
                        // Clear stash; UI already reflects the deletion.
                        _uiState.value = _uiState.value.copy(
                            recentlyDeletedEntry = null
                        )
                    }
                    is ResultWrapper.Error -> {
                        // Surface the failure but keep the entry stashed so user can still undo.
                        _uiState.value = _uiState.value.copy(
                            error = result.exception.getUserMessage()
                        )
                    }
                    is ResultWrapper.Loading -> { /* No-op */ }
                }
            }
        }
    }

    /** Restore the most recently deleted entry. Public so the snackbar action can call it. */
    fun undoDelete() {
        val entry = _uiState.value.recentlyDeletedEntry ?: return

        // Cancel the pending finalize.
        undoJob?.cancel()
        undoJob = null

        viewModelScope.launch {
            val result = repository.addFoodEntry(entry)
            when (result) {
                is ResultWrapper.Success -> {
                    refreshLocalData()
                    _uiState.value = _uiState.value.copy(recentlyDeletedEntry = null)
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = result.exception.getUserMessage(),
                        recentlyDeletedEntry = null
                    )
                }
                is ResultWrapper.Loading -> { /* No-op */ }
            }
        }
    }

    /** Force-commit a stale delete (e.g. when a new delete arrives before the previous timer expired). */
    private fun finalizePreviousDelete(entryId: String) {
        undoJob?.cancel()
        undoJob = null
        viewModelScope.launch {
            // Best-effort cloud delete; if it fails, the silent-error logging in
            // DietRepositoryImpl picks it up and the next syncEntries() will retry.
            deleteFoodEntryUseCase(DeleteFoodEntryUseCase.Params(entryId))
        }
    }

    private fun updateGoals(goals: DietGoal) {
        viewModelScope.launch {
            val result = updateDietGoalsUseCase(
                UpdateDietGoalsUseCase.Params(goals)
            )

            when (result) {
                is ResultWrapper.Success -> {
                    _uiState.value = _uiState.value.copy(dietGoals = goals)
                    refreshNutritionSummary()
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = result.exception.getUserMessage()
                    )
                }
                is ResultWrapper.Loading -> { /* No-op */ }
            }
        }
    }

    private fun toggleFavorite(foodId: String) {
        viewModelScope.launch {
            val result = repository.toggleFavorite(foodId)

            when (result) {
                is ResultWrapper.Success -> {
                    // Refresh favorites
                    val favoritesResult = repository.getFavoriteFoodIds()
                    val favorites = favoritesResult.getOrNull() ?: emptySet()
                    _uiState.value = _uiState.value.copy(favoriteFoodIds = favorites)
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = result.exception.getUserMessage()
                    )
                }
                is ResultWrapper.Loading -> { /* No-op */ }
            }
        }
    }

    private fun analyzeFoodImage(imageUri: Uri) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                snapState = SnapAnalysisState.Analyzing,
                snapImageUri = imageUri.toString()
            )

            // This needs Context - will be passed from UI
            // For now, we'll handle this in a suspend function that takes Context
        }
    }

    /**
     * Analyze food image with context.
     * This should be called from the UI layer with context.
     */
    fun analyzeFoodImageWithContext(context: Context, imageUri: Uri) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                snapState = SnapAnalysisState.Analyzing,
                snapImageUri = imageUri.toString()
            )

            try {
                val base64 = ImageUtils.compressAndEncode(context, imageUri)
                    ?: throw Exception("Failed to process image")

                val result = analyzeFoodImageUseCase(
                    AnalyzeFoodImageUseCase.Params(base64)
                )

                when (result) {
                    is ResultWrapper.Success -> {
                        _uiState.value = _uiState.value.copy(
                            snapState = SnapAnalysisState.Result(result.data)
                        )
                    }
                    is ResultWrapper.Error -> {
                        _uiState.value = _uiState.value.copy(
                            snapState = SnapAnalysisState.Error(
                                result.exception.getUserMessage()
                            )
                        )
                    }
                    is ResultWrapper.Loading -> { /* No-op */ }
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    snapState = SnapAnalysisState.Error(
                        e.message ?: "Failed to analyze image"
                    )
                )
            }
        }
    }

    private fun clearSnapState() {
        _uiState.value = _uiState.value.copy(
            snapState = SnapAnalysisState.Idle,
            snapImageUri = null
        )
    }

    private fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    private suspend fun refreshLocalData() {
        val entriesResult = repository.getAllFoodEntries()
        val entries = entriesResult.getOrNull() ?: emptyList()

        val nutritionResult = getNutritionSummaryUseCase(
            GetNutritionSummaryUseCase.Params(_uiState.value.selectedDate)
        )
        val nutrition = nutritionResult.getOrNull() ?: com.swastricare.health.domain.model.NutritionSummary.Empty

        val insightsResult = getDietInsightsUseCase()
        val insights = insightsResult.getOrNull()

        _uiState.value = _uiState.value.copy(
            foodEntries = entries,
            nutritionSummary = nutrition,
            insights = insights
        )
    }

    private suspend fun refreshNutritionSummary() {
        val nutritionResult = getNutritionSummaryUseCase(
            GetNutritionSummaryUseCase.Params(_uiState.value.selectedDate)
        )
        val nutrition = nutritionResult.getOrNull() ?: com.swastricare.health.domain.model.NutritionSummary.Empty

        _uiState.value = _uiState.value.copy(nutritionSummary = nutrition)
    }

    private suspend fun syncInBackground() {
        // Fetch fresh food items from Supabase
        val foodsResult = repository.fetchFoodItems()
        if (foodsResult is ResultWrapper.Success && foodsResult.data.isNotEmpty()) {
            _uiState.value = _uiState.value.copy(cachedFoodItems = foodsResult.data)
        }

        // Sync unsynced entries to cloud
        repository.syncEntries()
    }
}
