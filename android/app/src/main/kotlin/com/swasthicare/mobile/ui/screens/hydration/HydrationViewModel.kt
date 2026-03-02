package com.swasthicare.mobile.ui.screens.hydration

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.HydrationRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.data.services.WeatherData
import com.swasthicare.mobile.data.services.WeatherService
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
    private val weatherService: WeatherService? = null
) : ViewModel() {

    private val _uiState = MutableStateFlow(HydrationUiState(isLoading = true))
    val uiState: StateFlow<HydrationUiState> = _uiState.asStateFlow()

    private val demoProfileId = "demo-profile-id"
    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            val entries = repository.loadLocalEntries()
            val prefs = repository.loadPreferences()
            val goal = HydrationCalculator.calculateGoal(prefs)
            val insights = computeInsights(entries, goal)

            _uiState.value = _uiState.value.copy(
                entries = entries,
                preferences = prefs,
                goal = goal,
                baseGoalMl = goal.dailyGoalMl,
                insights = insights,
                isLoading = false
            )

            // Background sync
            syncInBackground()

            // Fetch weather for adjustment
            fetchWeatherAdjustment()
        }
    }

    fun addDrink(drinkType: DrinkType, amountMl: Int, notes: String? = null) {
        viewModelScope.launch {
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
        var streak = 0
        var date = LocalDate.now()
        while (true) {
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

    private suspend fun syncInBackground() {
        val unsynced = _uiState.value.entries.filter { !it.synced }
        if (unsynced.isNotEmpty()) {
            val profileId = resolveProfileId()
            repository.syncEntriesToCloud(unsynced, profileId)
        }
    }

    private suspend fun syncEntryToCloud(entry: HydrationEntry) {
        try {
            val profileId = resolveProfileId()
            repository.syncEntriesToCloud(listOf(entry), profileId)
        } catch (_: Exception) { }
    }

    private suspend fun resolveProfileId(): String = try {
        profileRepository.getHealthProfile(demoProfileId)?.userId ?: demoProfileId
    } catch (_: Exception) { demoProfileId }
}
