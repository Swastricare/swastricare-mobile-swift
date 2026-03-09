package com.swasthicare.mobile.ui.screens.hydration

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.HydrationRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.data.services.AnalyticsService
import com.swasthicare.mobile.data.services.DrinkingPatternService
import com.swasthicare.mobile.data.services.WeatherData
import com.swasthicare.mobile.data.services.WeatherService
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

// -----------------------------------------------
// MARK: - UI State
// -----------------------------------------------

data class HydrationUiState(
    val entries: List<HydrationEntry> = emptyList(),
    val preferences: HydrationPreferences = HydrationPreferences.Default,
    val goal: HydrationGoal = HydrationGoal(),
    val insights: HydrationInsights? = null,
    val selectedDate: LocalDate = LocalDate.now(),
    val isLoading: Boolean = false,
    val error: String? = null,
    // Weather adjustment
    val weatherData: WeatherData? = null,
    val weatherAdjustmentFactor: Double = 1.0,
    val baseGoalMl: Int = 2500
) {
    /** Entries for selectedDate, sorted newest first */
    val todaysEntries: List<HydrationEntry> get() {
        val dateStr = selectedDate.toString()
        return entries
            .filter { it.consumedAt.startsWith(dateStr) }
            .sortedByDescending { it.consumedAt }
    }

    val totalIntake: Int get() = todaysEntries.sumOf { it.amountMl }

    val effectiveIntake: Int get() = todaysEntries.sumOf { it.effectiveMl }

    val effectiveGoalMl: Int get() = (baseGoalMl * weatherAdjustmentFactor).toInt()

    val remainingMl: Int get() = maxOf(0, effectiveGoalMl - effectiveIntake)

    val progress: Float get() =
        if (effectiveGoalMl > 0)
            (effectiveIntake.toFloat() / effectiveGoalMl).coerceIn(0f, 1.5f)
        else 0f

    val isGoalMet: Boolean get() = effectiveIntake >= effectiveGoalMl

    val isWeatherAdjusted: Boolean get() = weatherAdjustmentFactor > 1.0

    val caffeineEntries: Int get() = todaysEntries.count {
        DrinkType.fromDb(it.drinkType).containsCaffeine
    }

    val caffeineAmountMl: Int get() = todaysEntries
        .filter { DrinkType.fromDb(it.drinkType).containsCaffeine }
        .sumOf { it.amountMl }
}

// -----------------------------------------------
// MARK: - ViewModel
// -----------------------------------------------

class HydrationViewModel(
    private val repository: HydrationRepository,
    private val profileRepository: ProfileRepository,
    private val weatherService: WeatherService? = null,
    private val analyticsService: AnalyticsService = AppContainer.firebaseAnalyticsService,
    private val patternService: DrinkingPatternService = DrinkingPatternService(AppContainer.sharedPreferences)
) : ViewModel() {

    private val _uiState = MutableStateFlow(HydrationUiState(isLoading = true))
    val uiState: StateFlow<HydrationUiState> = _uiState.asStateFlow()

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            // Show local data immediately so UI is not blank
            val localEntries = repository.loadLocalEntries()
            val prefs = repository.loadPreferences()
            val goal = HydrationCalculator.calculateGoal(prefs)

            _uiState.value = _uiState.value.copy(
                entries = localEntries,
                preferences = prefs,
                goal = goal,
                baseGoalMl = goal.dailyGoalMl,
                insights = computeInsights(localEntries, goal),
                isLoading = false
            )

            analyzePatterns()

            // Fetch from cloud and merge with local (fixes data loss after reinstall / clear)
            val profileId = resolveProfileId()
            if (profileId != null) {
                repository.fetchFromCloud(profileId).onSuccess { cloudEntries ->
                    if (cloudEntries.isNotEmpty()) {
                        val localUnsynced = repository.loadLocalEntries().filter { !it.synced }
                        val cloudIds = cloudEntries.map { it.id }.toSet()
                        val merged = cloudEntries + localUnsynced.filter { it.id !in cloudIds }
                        repository.saveLocalEntries(merged)
                        _uiState.value = _uiState.value.copy(
                            entries = merged,
                            insights = computeInsights(merged, goal)
                        )
                        analyzePatterns()
                        // Push any local-only entries to cloud
                        val stillUnsynced = merged.filter { !it.synced }
                        if (stillUnsynced.isNotEmpty()) {
                            repository.syncEntriesToCloud(stillUnsynced, profileId)
                        }
                    }
                }
            }

            fetchWeatherAdjustment()
        }
    }

    fun addDrink(drinkType: DrinkType, amountMl: Int, notes: String? = null) {
        viewModelScope.launch {
            analyticsService.logHydrationLogged(amountMl, drinkType.dbValue)
            val effectiveMl = (amountMl * drinkType.hydrationMultiplier).toInt()
            val entry = HydrationEntry(
                id = UUID.randomUUID().toString(),
                drinkType = drinkType.dbValue,
                amountMl = amountMl,
                effectiveMl = effectiveMl,
                consumedAt = LocalDateTime.now().format(isoFormatter),
                notes = notes,
                synced = false
            )
            repository.addLocalEntry(entry)
            refreshFromLocal()
            launch { syncEntryToCloud(entry) }
        }
    }

    fun deleteDrink(entryId: String) {
        viewModelScope.launch {
            repository.deleteLocalEntry(entryId)
            refreshFromLocal()
            launch { repository.deleteCloudEntry(entryId) }
        }
    }

    fun updatePreferences(newPrefs: HydrationPreferences) {
        viewModelScope.launch {
            repository.savePreferences(newPrefs)
            val goal = HydrationCalculator.calculateGoal(newPrefs)
            val insights = computeInsights(_uiState.value.entries, goal)
            _uiState.value = _uiState.value.copy(
                preferences = newPrefs,
                goal = goal,
                baseGoalMl = goal.dailyGoalMl,
                insights = insights
            )
        }
    }

    fun selectDate(date: LocalDate) {
        _uiState.value = _uiState.value.copy(selectedDate = date)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    // -----------------------------------------------
    // MARK: - Weather Adjustment
    // -----------------------------------------------

    private fun fetchWeatherAdjustment() {
        val service = weatherService ?: return
        viewModelScope.launch {
            try {
                val weather = service.getCurrentWeather()
                val factor = if (weather != null && weather.temperatureCelsius > WeatherService.HOT_WEATHER_THRESHOLD) {
                    WeatherService.HOT_WEATHER_MULTIPLIER
                } else {
                    1.0
                }
                _uiState.value = _uiState.value.copy(
                    weatherData = weather,
                    weatherAdjustmentFactor = factor
                )
            } catch (_: Exception) {
                // Silently fail — weather is best effort
            }
        }
    }

    // -----------------------------------------------
    // MARK: - Private Helpers
    // -----------------------------------------------

    private fun analyzePatterns() {
        val timestamps = _uiState.value.entries.map { it.consumedAt }
        patternService.analyzePatterns(timestamps)
    }

    private fun refreshFromLocal() {
        val entries = repository.loadLocalEntries()
        val insights = computeInsights(entries, _uiState.value.goal)
        _uiState.value = _uiState.value.copy(
            entries = entries,
            insights = insights
        )
    }

    private fun computeInsights(entries: List<HydrationEntry>, goal: HydrationGoal): HydrationInsights? {
        if (entries.isEmpty()) return null

        // Streak calculation
        val streak = computeStreak(entries, goal)

        // Average daily intake (last 7 days)
        val sevenDaysAgo = LocalDate.now().minusDays(7).toString()
        val weekEntries = entries.filter { it.consumedAt >= sevenDaysAgo }
        val byDay = weekEntries.groupBy { it.consumedAt.take(10) }
        val avgIntake = if (byDay.isNotEmpty()) {
            byDay.values.sumOf { dayEntries -> dayEntries.sumOf { it.effectiveMl } } / byDay.size
        } else 0

        // Most common drink
        val mostCommon = entries.groupBy { it.drinkType }
            .maxByOrNull { it.value.size }
            ?.let { DrinkType.fromDb(it.key).displayName }

        // Caffeine today
        val todayStr = LocalDate.now().toString()
        val todayEntries = entries.filter { it.consumedAt.startsWith(todayStr) }
        val caffeineCount = todayEntries.count { DrinkType.fromDb(it.drinkType).containsCaffeine }
        val caffeineMl = todayEntries
            .filter { DrinkType.fromDb(it.drinkType).containsCaffeine }
            .sumOf { it.amountMl }

        return HydrationInsights(
            streakDays = streak,
            avgDailyIntake = avgIntake,
            mostCommonDrink = mostCommon,
            caffeineCount = caffeineCount,
            caffeineAmountMl = caffeineMl
        )
    }

    private fun computeStreak(entries: List<HydrationEntry>, goal: HydrationGoal): Int {
        if (goal.dailyGoalMl <= 0) return 0
        var streak = 0
        var date = LocalDate.now()
        val maxDays = 365
        while (streak < maxDays) {
            val dateStr = date.toString()
            val dayEffective = entries
                .filter { it.consumedAt.startsWith(dateStr) }
                .sumOf { it.effectiveMl }
            if (dayEffective < goal.dailyGoalMl * 0.5) break
            streak++
            date = date.minusDays(1)
        }
        return streak
    }

    private suspend fun syncEntryToCloud(entry: HydrationEntry) {
        try {
            val profileId = resolveProfileId() ?: return
            repository.syncEntriesToCloud(listOf(entry), profileId)
        } catch (e: Exception) {
            android.util.Log.w("HydrationViewModel", "Sync entry failed: ${e.message}")
        }
    }

    private suspend fun resolveProfileId(): String? {
        val userId = AppContainer.authRepository.currentUser?.id ?: return null
        val healthProfile = profileRepository.getHealthProfile(userId) ?: return null
        return healthProfile.id
    }
}
