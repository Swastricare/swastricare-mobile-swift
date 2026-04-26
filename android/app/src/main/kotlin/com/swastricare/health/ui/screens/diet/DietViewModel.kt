package com.swastricare.health.ui.screens.diet

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.*
import com.swastricare.health.data.repository.SupabaseDietRepository
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.data.services.AIService
import com.swastricare.health.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID
import javax.inject.Inject

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
    val snapImageUri: String? = null,
    /** Entry just deleted; non-null while undo is still possible (~5s window). */
    val recentlyDeletedEntry: DietLogEntry? = null,
    /** Changes whenever a new delete fires so the UI re-presents the undo snackbar. */
    val undoSnackbarTriggerId: String? = null,
    /** True while a cloud sync is in flight. Drives spinning indicator in the banner. */
    val isSyncing: Boolean = false,
    /** Count of locally-saved entries that haven't reached the cloud yet. */
    val pendingSyncCount: Int = 0,
    /** User-readable message for the most recent sync failure; null = healthy. */
    val lastSyncError: String? = null
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

@HiltViewModel
class DietViewModel @Inject constructor(
    private val repository: SupabaseDietRepository,
    private val profileRepository: SupabaseProfileRepository,
    private val aiService: AIService,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(DietUiState(isLoading = true))
    val uiState: StateFlow<DietUiState> = _uiState.asStateFlow()

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    /** Pending finalize-delete job. Cancellation = undo before 5s expired. */
    private var undoJob: Job? = null

    /** Lazy ICU transliterator (API 24+); only instantiated when first Devanagari query arrives. */
    private val devanagariTransliterator by lazy {
        android.icu.text.Transliterator.getInstance("Devanagari-Latin")
    }
    /** Combining-mark regex used to strip diacritics post-NFD. */
    private val diacriticRegex = "\\p{InCombiningDiacriticalMarks}+".toRegex()

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

    /**
     * Optimistic delete with 5-second undo (matches iOS DietViewModel.deleteLog).
     *
     * Flow:
     *   1. If a different entry is already in its undo window, finalize it now
     *      (cancel its timer + commit cloud delete) so we never have two pending undos.
     *   2. Remove from local storage immediately and refresh nutrition.
     *   3. Stash the entry + bump trigger ID so the UI presents the undo snackbar.
     *   4. Start a 5s timer that finalizes the cloud delete on expiry.
     *   5. If `undoDelete()` runs before the timer fires, the entry is restored
     *      via repository.addLocalLog() (preserves original ID + loggedAt).
     */
    fun deleteLog(entry: DietLogEntry) {
        // (1) Finalize any pending undo for a different entry first.
        val active = _uiState.value.recentlyDeletedEntry
        if (active != null && active.id != entry.id) {
            undoJob?.cancel()
            viewModelScope.launch {
                try {
                    repository.deleteCloudLog(active.id)
                } catch (e: Exception) {
                    android.util.Log.e("DietViewModel", "Cloud delete failed (finalize prev) id=${active.id}", e)
                }
            }
        }
        undoJob?.cancel()

        viewModelScope.launch {
            // (2) Local-only delete now; cloud delete is deferred 5s.
            repository.deleteLocalLog(entry.id)
            refreshFromLocal()
            // (3) Stash for undo + bump trigger so snackbar re-presents.
            _uiState.value = _uiState.value.copy(
                recentlyDeletedEntry = entry,
                undoSnackbarTriggerId = UUID.randomUUID().toString()
            )
        }

        // (4) Schedule cloud delete after 5s.
        undoJob = viewModelScope.launch {
            delay(5_000)
            // Only finalize if THIS entry is still the active undo target.
            if (_uiState.value.recentlyDeletedEntry?.id == entry.id) {
                try {
                    repository.deleteCloudLog(entry.id)
                } catch (e: Exception) {
                    android.util.Log.e("DietViewModel", "Cloud delete failed id=${entry.id}", e)
                }
                _uiState.value = _uiState.value.copy(recentlyDeletedEntry = null)
            }
        }
    }

    /** Restore the most recently deleted entry. Called by the snackbar Undo action. */
    fun undoDelete() {
        val entry = _uiState.value.recentlyDeletedEntry ?: return
        undoJob?.cancel()
        undoJob = null

        viewModelScope.launch {
            repository.addLocalLog(entry)  // preserves original UUID + loggedAt
            _uiState.value = _uiState.value.copy(recentlyDeletedEntry = null)
            refreshFromLocal()
        }
    }

    /**
     * Suggest DietGoals using Mifflin-St Jeor + activity multiplier, derived from the user's
     * health profile (date of birth → age, height_cm, weight_kg, gender). Returns null if
     * the profile is missing or DOB cannot be parsed; the UI should hide the "Use suggested"
     * action in that case rather than guessing.
     *
     * Default args (MODERATE / MAINTENANCE) are the safest baseline; the settings sheet may
     * override either as a future enhancement.
     */
    suspend fun getSuggestedGoals(
        activityLevel: ActivityLevel = ActivityLevel.MODERATE,
        goalType: GoalType = GoalType.MAINTENANCE
    ): DietGoals? = try {
        val userId = authRepository.getCurrentUser()?.id
        val profile = userId?.let { profileRepository.getHealthProfile(it) }
        val age = CalorieCalculator.ageFromDateOfBirth(profile?.dateOfBirth)

        if (profile == null || age == null || profile.weightKg <= 0 || profile.heightCm <= 0) {
            null
        } else {
            CalorieCalculator.computeGoals(
                weightKg = profile.weightKg,
                heightCm = profile.heightCm.toInt(),
                age = age,
                gender = profile.gender.name.lowercase(),
                activityLevel = activityLevel,
                goalType = goalType
            )
        }
    } catch (e: Exception) {
        android.util.Log.w("DietViewModel", "getSuggestedGoals failed", e)
        null
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

    /**
     * Token-based fuzzy search with relevance scoring.
     * Ports iOS DietService.swift:259-338 — same heuristics, same point values.
     *
     * Score model (per food, max ≈ 200 + boost):
     *   • Exact name match              → +100
     *   • Name prefix                   → +80
     *   • Name contains                 → +60
     *   • Per-token name contains       → +30
     *   • Per-token brand contains      → +15
     *   • Per-token category contains   → +10
     *   • Word-boundary prefix (≥2ch)   → +20
     *   • Char-set similarity ≥ 0.6     → up to +25 (single-token only)
     *   • Frequency boost (recent logs) → +5 per rank, capped at +30
     *
     * Sorted by score desc, then alphabetic. Returns all matches; UI handles truncation.
     */
    /**
     * Normalize for fuzzy search:
     *   1. Romanize Devanagari (`पनीर` → `panīra`) via ICU Transliterator (API 24+).
     *   2. Apply NFD normalization and strip combining marks (`panīr` → `panir`, `ḍāl` → `dal`).
     *   3. Lowercase.
     *
     * Result: "paneer", "panīr", "पनीर" all collapse to a comparable token.
     * Cached internally because Transliterator instantiation isn't free.
     */
    private fun normalizeForSearch(s: String): String {
        if (s.isEmpty()) return s
        val romanized = if (s.any { ch ->
                Character.UnicodeBlock.of(ch) == Character.UnicodeBlock.DEVANAGARI
            }) {
            try {
                devanagariTransliterator.transliterate(s)
            } catch (_: Exception) {
                s
            }
        } else {
            s
        }
        val nfd = java.text.Normalizer.normalize(romanized, java.text.Normalizer.Form.NFD)
        return diacriticRegex.replace(nfd, "").lowercase()
    }

    fun searchFoods(query: String): List<FoodItem> {
        if (query.isBlank()) return emptyList()

        val lowered = normalizeForSearch(query)
        val tokens = lowered.split(' ').filter { it.isNotEmpty() }

        // Frequency rank: 1 = most-eaten, higher = less-eaten. Capped at top 50 distinct names.
        val freqRanks: Map<String, Int> = run {
            val counts = _uiState.value.dietLogs
                .groupingBy { it.foodName }
                .eachCount()
            counts.entries
                .sortedByDescending { it.value }
                .take(50)
                .mapIndexed { idx, entry -> entry.key to (50 - idx) }  // top of list = highest rank
                .toMap()
        }

        val scored = ArrayList<Pair<FoodItem, Int>>()

        for (food in _uiState.value.foodItemsCache) {
            val name = normalizeForSearch(food.name)
            val brand = food.brand?.let { normalizeForSearch(it) }.orEmpty()
            val category = normalizeForSearch(food.category)
            var score = 0

            when {
                name == lowered -> score += 100
                name.startsWith(lowered) -> score += 80
                name.contains(lowered) -> score += 60
            }

            for (token in tokens) {
                if (name.contains(token)) score += 30
                if (brand.contains(token)) score += 15
                if (category.contains(token)) score += 10
                if (token.length >= 2) {
                    for (word in name.split(' ')) {
                        if (word.startsWith(token)) score += 20
                    }
                }
            }

            // Single-token char-set similarity (cheap fuzzy match, catches typos)
            if (tokens.size == 1 && lowered.length > 2) {
                val querySet = lowered.toHashSet()
                for (word in name.split(' ')) {
                    if (word.length > 2) {
                        val common = word.toHashSet().intersect(querySet)
                        val similarity = common.size.toDouble() / maxOf(word.length, lowered.length)
                        if (similarity >= 0.6) {
                            score += (similarity * 25).toInt()
                        }
                    }
                }
            }

            if (score > 0) {
                freqRanks[food.name]?.let { rank ->
                    score += minOf(rank, 30)  // cap at +30 to avoid drowning relevance
                }
                scored.add(food to score)
            }
        }

        return scored
            .sortedWith(
                compareByDescending<Pair<FoodItem, Int>> { it.second }
                    .thenBy { it.first.name }
            )
            .map { it.first }
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
                val base64 = com.swastricare.health.data.services.ImageUtils.compressAndEncode(context, imageUri)
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

    /** Full sync round-trip: fetch food items + push unsynced logs. Captures errors into uiState
     *  so DietScreen's sync banner can surface them to the user. */
    private suspend fun syncInBackground() {
        val unsyncedAtStart = _uiState.value.dietLogs.count { !it.synced }
        _uiState.value = _uiState.value.copy(
            isSyncing = true,
            pendingSyncCount = unsyncedAtStart
        )

        var firstError: String? = null

        // Fetch food items from Supabase and cache.
        val foodResult = repository.fetchFoodItems()
        if (foodResult.isSuccess) {
            val items = foodResult.getOrDefault(emptyList())
            if (items.isNotEmpty()) {
                repository.cacheFoodItems(items)
                _uiState.value = _uiState.value.copy(foodItemsCache = items)
            }
        } else {
            firstError = foodResult.exceptionOrNull()?.message ?: "Couldn't refresh food list"
            android.util.Log.w("DietViewModel", "fetchFoodItems failed: $firstError")
        }

        // Sync unsynced logs.
        val unsynced = _uiState.value.dietLogs.filter { !it.synced }
        if (unsynced.isNotEmpty()) {
            try {
                val profileId = resolveProfileId()
                val pushResult = repository.syncLogsToCloud(unsynced, profileId)
                if (pushResult.isFailure && firstError == null) {
                    firstError = pushResult.exceptionOrNull()?.message ?: "Sync failed"
                    android.util.Log.w("DietViewModel", "syncLogsToCloud failed: $firstError")
                }
            } catch (e: Exception) {
                if (firstError == null) firstError = e.message ?: "Sync failed"
                android.util.Log.w("DietViewModel", "syncInBackground threw: ${e.message}")
            }
        }

        // Recompute pending count from local storage post-sync (synced flags may have flipped).
        val freshLogs = repository.loadLocalLogs()
        val pendingNow = freshLogs.count { !it.synced }

        _uiState.value = _uiState.value.copy(
            dietLogs = freshLogs,
            isSyncing = false,
            pendingSyncCount = pendingNow,
            lastSyncError = firstError
        )
    }

    /** User-triggered retry from the sync error banner. Clears error then re-runs sync. */
    fun retrySync() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(lastSyncError = null)
            syncInBackground()
        }
    }

    private suspend fun syncLogToCloud(entry: DietLogEntry) {
        try {
            val profileId = resolveProfileId()
            val result = repository.syncLogsToCloud(listOf(entry), profileId)
            if (result.isFailure) {
                _uiState.value = _uiState.value.copy(
                    lastSyncError = result.exceptionOrNull()?.message ?: "Sync failed",
                    pendingSyncCount = _uiState.value.pendingSyncCount + 1
                )
                android.util.Log.w("DietViewModel", "single-entry sync failed: ${result.exceptionOrNull()?.message}")
            }
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                lastSyncError = e.message ?: "Sync failed",
                pendingSyncCount = _uiState.value.pendingSyncCount + 1
            )
            android.util.Log.w("DietViewModel", "Sync log failed: ${e.message}")
        }
    }

    private suspend fun resolveProfileId(): String {
        val userId = authRepository.getCurrentUser()?.id
            ?: throw IllegalStateException("No authenticated user")
        val healthProfile = profileRepository.getHealthProfile(userId)
            ?: throw IllegalStateException("No health profile found")
        return healthProfile.id
            ?: throw IllegalStateException("Health profile has no ID")
    }
}
