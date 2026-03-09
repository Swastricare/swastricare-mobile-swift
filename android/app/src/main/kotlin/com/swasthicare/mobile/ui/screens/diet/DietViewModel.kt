package com.swasthicare.mobile.ui.screens.diet

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.DietRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.data.services.AIService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

// ─────────────────────────────────────
// MARK: - Snap Analysis State
// ─────────────────────────────────────

sealed class SnapAnalysisState {
    object Idle : SnapAnalysisState()
    object Analyzing : SnapAnalysisState()
    data class Result(val food: SnapFoodResult) : SnapAnalysisState()
    data class Error(val message: String) : SnapAnalysisState()
}

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class DietUiState(
    val dietLogs: List<DietLogEntry> = emptyList(),
    val dietGoals: DietGoals = DietGoals.Default,
    val nutritionSummary: NutritionSummary = NutritionSummary.Empty,
    val foodItemsCache: List<FoodItem> = emptyList(),
    val favoriteFoodIds: Set<String> = emptySet(),
    val insights: DietInsights? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val selectedDate: LocalDate = LocalDate.now(),
    val snapState: SnapAnalysisState = SnapAnalysisState.Idle,
    val snapImageUri: String? = null
) {
    /** Logs for selectedDate, sorted newest first */
    val todaysLogs: List<DietLogEntry> get() {
        val dateStr = selectedDate.toString()
        return dietLogs
            .filter { it.loggedAt.startsWith(dateStr) }
            .sortedByDescending { it.loggedAt }
    }

    val totalCalories: Int get() = nutritionSummary.totalCalories.toInt()
    val remainingCalories: Int get() = maxOf(0, dietGoals.dailyCalories - totalCalories)
    val calorieProgress: Float get() =
        if (dietGoals.dailyCalories > 0)
            (totalCalories.toFloat() / dietGoals.dailyCalories).coerceIn(0f, 1f)
        else 0f
    val proteinProgress: Float get() =
        if (dietGoals.proteinGrams > 0)
            (nutritionSummary.totalProteinG / dietGoals.proteinGrams).toFloat().coerceIn(0f, 1f)
        else 0f
    val carbsProgress: Float get() =
        if (dietGoals.carbsGrams > 0)
            (nutritionSummary.totalCarbsG / dietGoals.carbsGrams).toFloat().coerceIn(0f, 1f)
        else 0f
    val fatProgress: Float get() =
        if (dietGoals.fatGrams > 0)
            (nutritionSummary.totalFatG / dietGoals.fatGrams).toFloat().coerceIn(0f, 1f)
        else 0f
    val goalDescription: String get() = "Daily goal: ${dietGoals.dailyCalories} cal"
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

class DietViewModel(
    private val repository: DietRepository,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(DietUiState(isLoading = true))
    val uiState: StateFlow<DietUiState> = _uiState.asStateFlow()

    private val aiService = AIService(com.swasthicare.mobile.di.AppContainer.supabaseClient)

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            // Load from local storage immediately
            val logs = repository.loadLocalLogs()
            val goals = repository.loadGoals()
            val cachedFoods = repository.getCachedFoodItems()
            val favoriteIds = repository.getFavoriteIds()
            val nutrition = computeNutrition(logs, _uiState.value.selectedDate)
            val insights = computeInsights(logs, goals)

            _uiState.value = _uiState.value.copy(
                dietLogs = logs,
                dietGoals = goals,
                nutritionSummary = nutrition,
                foodItemsCache = cachedFoods,
                favoriteFoodIds = favoriteIds,
                insights = insights,
                isLoading = false
            )

            // Background: fetch food items from Supabase + sync unsynced logs
            syncInBackground()
        }
    }

    fun selectDate(date: LocalDate) {
        val nutrition = computeNutrition(_uiState.value.dietLogs, date)
        _uiState.value = _uiState.value.copy(selectedDate = date, nutritionSummary = nutrition)
    }

    fun logFood(
        item: FoodItem,
        quantity: Double,
        mealType: MealType
    ) {
        viewModelScope.launch {
            val multiplier = quantity / item.servingSize
            val entry = DietLogEntry(
                id = UUID.randomUUID().toString(),
                foodItemId = item.id,
                mealType = mealType.dbValue,
                foodName = item.name,
                quantity = quantity,
                servingUnit = item.servingUnit,
                calories = item.calories * multiplier,
                proteinG = item.proteinG * multiplier,
                carbsG = item.carbsG * multiplier,
                fatG = item.fatG * multiplier,
                fiberG = item.fiberG?.let { it * multiplier },
                loggedAt = LocalDateTime.now().format(isoFormatter),
                synced = false
            )
            repository.addLocalLog(entry)
            refreshFromLocal()
            // Background cloud sync
            launch { syncLogToCloud(entry) }
        }
    }

    fun logCustomFood(
        name: String,
        mealType: MealType,
        quantity: Double,
        servingUnit: ServingUnit,
        calories: Double,
        proteinG: Double = 0.0,
        carbsG: Double = 0.0,
        fatG: Double = 0.0
    ) {
        viewModelScope.launch {
            val entry = DietLogEntry(
                id = UUID.randomUUID().toString(),
                mealType = mealType.dbValue,
                foodName = name,
                quantity = quantity,
                servingUnit = servingUnit.dbValue,
                calories = calories,
                proteinG = proteinG,
                carbsG = carbsG,
                fatG = fatG,
                loggedAt = LocalDateTime.now().format(isoFormatter),
                synced = false
            )
            repository.addLocalLog(entry)
            refreshFromLocal()
            launch { syncLogToCloud(entry) }
        }
    }

    fun deleteLog(entry: DietLogEntry) {
        viewModelScope.launch {
            repository.deleteLocalLog(entry.id)
            refreshFromLocal()
            launch { repository.deleteCloudLog(entry.id) }
        }
    }

    fun updateGoals(goals: DietGoals) {
        viewModelScope.launch {
            repository.saveGoals(goals)
            val nutrition = computeNutrition(_uiState.value.dietLogs, _uiState.value.selectedDate)
            _uiState.value = _uiState.value.copy(dietGoals = goals, nutritionSummary = nutrition)
        }
    }

    fun toggleFavorite(foodId: String) {
        val current = _uiState.value.favoriteFoodIds.toMutableSet()
        if (current.contains(foodId)) current.remove(foodId) else current.add(foodId)
        repository.saveFavoriteIds(current)
        _uiState.value = _uiState.value.copy(favoriteFoodIds = current)
    }

    fun isFavorite(foodId: String): Boolean = _uiState.value.favoriteFoodIds.contains(foodId)

    fun getMealLogs(mealType: MealType): List<DietLogEntry> =
        _uiState.value.todaysLogs.filter { it.mealType == mealType.dbValue }

    fun searchFoods(query: String): List<FoodItem> {
        if (query.isBlank()) return emptyList()
        val lower = query.lowercase()
        return _uiState.value.foodItemsCache.filter {
            it.name.lowercase().contains(lower) ||
            it.brand?.lowercase()?.contains(lower) == true
        }
    }

    val recentFoods: List<FoodItem> get() {
        val cache = _uiState.value.foodItemsCache
        val seen = mutableSetOf<String>()
        val result = mutableListOf<FoodItem>()
        for (log in _uiState.value.dietLogs.sortedByDescending { it.loggedAt }) {
            if (seen.contains(log.foodName)) continue
            seen.add(log.foodName)
            cache.firstOrNull { it.name == log.foodName }?.let { result.add(it) }
            if (result.size >= 10) break
        }
        return result
    }

    val favoriteFoods: List<FoodItem> get() {
        val ids = _uiState.value.favoriteFoodIds
        return _uiState.value.foodItemsCache.filter { ids.contains(it.id) }
    }

    fun analyzeFood(context: android.content.Context, imageUri: android.net.Uri) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                snapState = SnapAnalysisState.Analyzing,
                snapImageUri = imageUri.toString()
            )
            try {
                val base64 = com.swasthicare.mobile.data.services.ImageUtils.compressAndEncode(context, imageUri)
                    ?: throw Exception("Failed to process image")
                val result = aiService.analyzeFoodImage(base64)
                _uiState.value = _uiState.value.copy(
                    snapState = SnapAnalysisState.Result(result)
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    snapState = SnapAnalysisState.Error(e.message ?: "Analysis failed")
                )
            }
        }
    }

    fun clearSnapState() {
        _uiState.value = _uiState.value.copy(
            snapState = SnapAnalysisState.Idle,
            snapImageUri = null
        )
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    // ─────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────

    private fun refreshFromLocal() {
        val logs = repository.loadLocalLogs()
        val nutrition = computeNutrition(logs, _uiState.value.selectedDate)
        val insights = computeInsights(logs, _uiState.value.dietGoals)
        _uiState.value = _uiState.value.copy(
            dietLogs = logs,
            nutritionSummary = nutrition,
            insights = insights
        )
    }

    private fun computeNutrition(logs: List<DietLogEntry>, date: LocalDate): NutritionSummary {
        val dateStr = date.toString()
        val dayLogs = logs.filter { it.loggedAt.startsWith(dateStr) }
        return NutritionSummary(
            totalCalories = dayLogs.sumOf { it.calories },
            totalProteinG = dayLogs.sumOf { it.proteinG },
            totalCarbsG = dayLogs.sumOf { it.carbsG },
            totalFatG = dayLogs.sumOf { it.fatG },
            totalFiberG = dayLogs.sumOf { it.fiberG ?: 0.0 },
            mealCount = dayLogs.map { it.mealType }.distinct().size
        )
    }

    private fun computeInsights(logs: List<DietLogEntry>, goals: DietGoals): DietInsights? {
        if (logs.isEmpty()) return null
        val sevenDaysAgo = LocalDate.now().minusDays(7).toString()
        val weekLogs = logs.filter { it.loggedAt >= sevenDaysAgo }
        if (weekLogs.isEmpty()) return null
        val byDay = weekLogs.groupBy { it.loggedAt.take(10) }
        val weeklyAvg = (weekLogs.sumOf { it.calories } / byDay.size.coerceAtLeast(1)).toInt()
        val streak = computeStreak(logs)
        val topFoods = logs.groupBy { it.foodName }
            .entries.sortedByDescending { it.value.size }
            .take(3).map { it.key }
        val todayLogs = logs.filter { it.loggedAt.startsWith(LocalDate.now().toString()) }
        val protein = todayLogs.sumOf { it.proteinG }
        val carbs = todayLogs.sumOf { it.carbsG }
        val fat = todayLogs.sumOf { it.fatG }
        val total = (protein * 4 + carbs * 4 + fat * 9).coerceAtLeast(1.0)
        val proteinPct = (protein * 4 / total * 100).toInt()
        val carbsPct = (carbs * 4 / total * 100).toInt()
        val fatPct = (fat * 9 / total * 100).toInt()
        val macroBalance = "P${proteinPct}% · C${carbsPct}% · F${fatPct}%"
        return DietInsights(
            weeklyAverageCalories = weeklyAvg,
            currentStreak = streak,
            topFoods = topFoods,
            macroBalance = macroBalance
        )
    }

    private fun computeStreak(logs: List<DietLogEntry>): Int {
        var streak = 0
        var date = LocalDate.now()
        while (true) {
            val dateStr = date.toString()
            val hasLog = logs.any { it.loggedAt.startsWith(dateStr) }
            if (!hasLog) break
            streak++
            date = date.minusDays(1)
        }
        return streak
    }

    private suspend fun syncInBackground() {
        // Fetch food items from Supabase and cache
        val foodResult = repository.fetchFoodItems()
        if (foodResult.isSuccess) {
            val items = foodResult.getOrDefault(emptyList())
            if (items.isNotEmpty()) {
                repository.cacheFoodItems(items)
                _uiState.value = _uiState.value.copy(foodItemsCache = items)
            }
        }

        // Sync unsynced logs
        val unsynced = _uiState.value.dietLogs.filter { !it.synced }
        if (unsynced.isNotEmpty()) {
            val profileId = resolveProfileId()
            repository.syncLogsToCloud(unsynced, profileId)
        }
    }

    private suspend fun syncLogToCloud(entry: DietLogEntry) {
        try {
            val profileId = resolveProfileId()
            repository.syncLogsToCloud(listOf(entry), profileId)
        } catch (e: Exception) {
            android.util.Log.w("DietViewModel", "Sync log failed: ${e.message}")
        }
    }

    private suspend fun resolveProfileId(): String {
        val userId = com.swasthicare.mobile.di.AppContainer.authRepository.currentUser?.id
            ?: throw IllegalStateException("No authenticated user")
        val healthProfile = profileRepository.getHealthProfile(userId)
            ?: throw IllegalStateException("No health profile found")
        return healthProfile.id
            ?: throw IllegalStateException("Health profile has no ID")
    }
}
