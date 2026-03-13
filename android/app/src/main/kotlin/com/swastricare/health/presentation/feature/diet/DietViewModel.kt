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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
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

    private fun deleteEntry(entry: com.swastricare.health.domain.model.FoodEntry) {
        viewModelScope.launch {
            val result = deleteFoodEntryUseCase(
                DeleteFoodEntryUseCase.Params(entry.id)
            )

            when (result) {
                is ResultWrapper.Success -> refreshLocalData()
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = result.exception.getUserMessage()
                    )
                }
                is ResultWrapper.Loading -> { /* No-op */ }
            }
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
