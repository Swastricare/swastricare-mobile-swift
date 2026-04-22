package com.swastricare.health.ui.screens.hydration

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.*
import com.swastricare.health.data.repository.HydrationRepository
import com.swastricare.health.data.repository.ProfileRepository
import com.swastricare.health.data.repository.SupabaseHydrationRepository
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.DrinkingPatternService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.data.services.WeatherData
import com.swastricare.health.data.services.WeatherService
import com.swastricare.health.domain.repository.AuthRepository
import androidx.glance.appwidget.updateAll
import com.swastricare.health.widgets.HydrationWidget
import com.swastricare.health.widgets.WidgetDataManager
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID
import javax.inject.Inject

// -----------------------------------------------
// MARK: - UI State
// -----------------------------------------------

data class HydrationUiState(
    val userName: String = "",
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
    val weatherAdjustmentEnabled: Boolean = true,
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

    val isShowingToday: Boolean get() = selectedDate == LocalDate.now()

    val caffeineEntries: Int get() = todaysEntries.count {
        DrinkType.fromDb(it.drinkType).containsCaffeine
    }

    val caffeineAmountMl: Int get() = todaysEntries
        .filter { DrinkType.fromDb(it.drinkType).containsCaffeine }
        .sumOf { it.amountMl }

    /** The drink type with the highest total ml today, or WATER if no entries */
    val dominantDrinkType: DrinkType get() {
        if (todaysEntries.isEmpty()) return DrinkType.WATER
        return todaysEntries
            .groupBy { DrinkType.fromDb(it.drinkType) }
            .maxByOrNull { it.value.sumOf { e -> e.amountMl } }
            ?.key ?: DrinkType.WATER
    }
}

// -----------------------------------------------
// MARK: - ViewModel
// -----------------------------------------------

@HiltViewModel
class HydrationViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val repository: SupabaseHydrationRepository,
    private val profileRepository: SupabaseProfileRepository,
    private val weatherService: WeatherService,
    private val analyticsService: AnalyticsService,
    private val healthConnectService: HealthConnectService,
    private val authRepository: AuthRepository,
    private val patternService: DrinkingPatternService
) : ViewModel() {

    private val _uiState = MutableStateFlow(HydrationUiState(isLoading = true))
    val uiState: StateFlow<HydrationUiState> = _uiState.asStateFlow()

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            // Load user name from auth
            val currentUser = authRepository.getCurrentUser()
            val resolvedName = currentUser?.fullName
                ?: currentUser?.email?.substringBefore("@")
                ?: ""
            _uiState.value = _uiState.value.copy(userName = resolvedName)

            // Show local data immediately so UI is not blank
            val localEntries = repository.loadLocalEntries()
            var prefs = repository.loadPreferences()

            // Auto-populate weight from health profile if not set in hydration prefs
            if (prefs.weightKg == null) {
                val userId = authRepository.getCurrentUser()?.id
                if (userId != null) {
                    val profile = try { profileRepository.getHealthProfile(userId) } catch (_: Exception) { null }
                    if (profile != null && profile.weightKg > 0) {
                        prefs = prefs.copy(weightKg = profile.weightKg)
                        repository.savePreferences(prefs)
                    }
                }
            }

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
            pushWidgetSnapshot()

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
                        pushWidgetSnapshot()
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
        if (!_uiState.value.isShowingToday) return
        viewModelScope.launch {
            analyticsService.logHydrationLogged(amountMl, drinkType.dbValue)
            val effectiveMl = (amountMl * drinkType.hydrationMultiplier).toInt()
            val entry = HydrationEntry(
                id = UUID.randomUUID().toString(),
                drinkType = drinkType.dbValue,
                amountMl = amountMl,
                effectiveMl = effectiveMl,
                consumedAt = _uiState.value.selectedDate.atTime(java.time.LocalTime.now()).format(isoFormatter),
                notes = notes,
                synced = false
            )
            repository.addLocalEntry(entry)
            refreshFromLocal()
            pushWidgetSnapshot()

            launch { syncEntryToCloud(entry) }
            launch { healthConnectService.writeHydration(amountMl.toDouble()) }
        }
    }

    fun deleteDrink(entryId: String) {
        viewModelScope.launch {
            repository.deleteLocalEntry(entryId)
            refreshFromLocal()
            pushWidgetSnapshot()
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
            pushWidgetSnapshot()
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
        viewModelScope.launch {
            try {
                val weather = weatherService.getCurrentWeather()
                val enabled = repository.loadWeatherAdjustmentEnabled()
                val factor = if (
                    enabled &&
                    weather != null &&
                    weather.temperatureCelsius > WeatherService.HOT_WEATHER_THRESHOLD
                ) {
                    WeatherService.HOT_WEATHER_MULTIPLIER
                } else {
                    1.0
                }
                _uiState.value = _uiState.value.copy(
                    weatherData = weather,
                    weatherAdjustmentEnabled = enabled,
                    weatherAdjustmentFactor = factor
                )
                pushWidgetSnapshot()
            } catch (_: Exception) {
                // Silently fail — weather is best effort
            }
        }
    }

    fun setWeatherAdjustmentEnabled(enabled: Boolean) {
        repository.saveWeatherAdjustmentEnabled(enabled)
        val currentWeather = _uiState.value.weatherData
        val factor = if (
            enabled &&
            currentWeather != null &&
            currentWeather.temperatureCelsius > WeatherService.HOT_WEATHER_THRESHOLD
        ) {
            WeatherService.HOT_WEATHER_MULTIPLIER
        } else {
            1.0
        }
        _uiState.value = _uiState.value.copy(
            weatherAdjustmentEnabled = enabled,
            weatherAdjustmentFactor = factor
        )
        pushWidgetSnapshot()
    }

    /**
     * Push a fresh snapshot of today's hydration to the home-screen widget.
     *
     * Always recomputes from `_uiState.value.entries` filtered to **today** (not
     * `selectedDate`, which may be a past day the user is browsing) and uses
     * `effectiveMl` so the value matches the in-app progress ring and the
     * widget's own quick-log buttons (which also use effectiveMl).
     */
    private fun pushWidgetSnapshot() {
        val todayStr = LocalDate.now().toString()
        val todayEffectiveMl = _uiState.value.entries
            .filter { it.consumedAt.startsWith(todayStr) }
            .sumOf { it.effectiveMl }
        val goal = _uiState.value.effectiveGoalMl
        WidgetDataManager.updateHydrationWidget(appContext, todayEffectiveMl, goal)
        viewModelScope.launch { HydrationWidget().updateAll(appContext) }
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
        val userId = authRepository.getCurrentUser()?.id ?: return null
        val healthProfile = profileRepository.getHealthProfile(userId) ?: return null
        return healthProfile.id
    }
}
