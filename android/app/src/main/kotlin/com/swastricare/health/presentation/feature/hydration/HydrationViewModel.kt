package com.swastricare.health.presentation.feature.hydration

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.DrinkingPatternService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.data.services.WeatherService
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationGoal
import com.swastricare.health.domain.model.hydration.HydrationPreferences
import com.swastricare.health.domain.usecase.hydration.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

/**
 * ViewModel for Hydration feature.
 * Manages UI state and coordinates use cases.
 *
 * Migrated to Clean Architecture with:
 * - @HiltViewModel for dependency injection
 * - Use cases instead of direct repository access
 * - Separated UI state in HydrationUiState.kt
 * - Business logic moved to domain layer
 */
@HiltViewModel
class HydrationViewModel @Inject constructor(
    private val addHydrationEntryUseCase: AddHydrationEntryUseCase,
    private val getHydrationEntriesUseCase: GetHydrationEntriesUseCase,
    private val deleteHydrationEntryUseCase: DeleteHydrationEntryUseCase,
    private val syncHydrationUseCase: SyncHydrationUseCase,
    private val getHydrationInsightsUseCase: GetHydrationInsightsUseCase,
    private val updateHydrationPreferencesUseCase: UpdateHydrationPreferencesUseCase,
    private val profileRepository: ProfileRepository,
    private val hydrationRepository: HydrationRepository,
    private val weatherService: WeatherService,
    private val analyticsService: AnalyticsService,
    private val patternService: DrinkingPatternService,
    private val healthConnectService: HealthConnectService,
    private val authRepository: AuthRepository,
    private val logger: Logger
) : ViewModel() {

    private val _uiState = MutableStateFlow(HydrationUiState(isLoading = true))
    val uiState: StateFlow<HydrationUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    /**
     * Load hydration data from local storage and sync with cloud.
     */
    fun loadData() {
        viewModelScope.launch {
            try {
                logger.d(TAG, "Loading hydration data")

                val profileId = resolveProfileId()

                // Load preferences first
                val preferences = getPreferencesInternal()
                val goal = HydrationGoal.calculate(preferences)

                // Load entries (with fallback to local if no profileId)
                val entries = if (profileId != null) {
                    when (val result = getHydrationEntriesUseCase(profileId)) {
                        is ResultWrapper.Success -> result.data
                        else -> hydrationRepository.loadLocalEntries()
                    }
                } else {
                    hydrationRepository.loadLocalEntries()
                }

                val insights = getHydrationInsightsUseCase(goal)

                _uiState.update {
                    it.copy(
                        entries = entries,
                        preferences = preferences,
                        goal = goal,
                        baseGoalMl = goal.dailyGoalMl,
                        insights = insights,
                        isLoading = false
                    )
                }

                // Analyze drinking patterns
                analyzePatterns()

                // Sync with cloud in background
                if (profileId != null) {
                    syncWithCloud(profileId)
                }

                // Fetch weather adjustment
                fetchWeatherAdjustment()

            } catch (e: Exception) {
                logger.e(TAG, "Error loading hydration data", e)
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = "Failed to load hydration data"
                    )
                }
            }
        }
    }

    /**
     * Add a new hydration entry.
     */
    fun addDrink(drinkType: DrinkType, amountMl: Int, notes: String? = null) {
        viewModelScope.launch {
            logger.d(TAG, "Adding drink: ${drinkType.displayName}, ${amountMl}ml")

            // Log analytics
            analyticsService.logHydrationLogged(amountMl, drinkType.dbValue)

            // Add entry via use case
            when (val result = addHydrationEntryUseCase(drinkType, amountMl, notes)) {
                is ResultWrapper.Success -> {
                    logger.d(TAG, "Entry added successfully")

                    // Refresh local data
                    refreshFromLocal()

                    // Sync to cloud in background
                    val profileId = resolveProfileId()
                    if (profileId != null) {
                        syncSingleEntryToCloud(result.data, profileId)
                    }

                    // Write to Health Connect
                    launch {
                        healthConnectService.writeHydration(amountMl.toDouble())
                    }
                }

                is ResultWrapper.Error -> {
                    logger.e(TAG, "Failed to add entry", result.exception)
                    _uiState.update {
                        it.copy(error = result.exception.getUserMessage())
                    }
                }

                else -> {}
            }
        }
    }

    /**
     * Delete a hydration entry.
     */
    fun deleteDrink(entryId: String) {
        viewModelScope.launch {
            logger.d(TAG, "Deleting entry: $entryId")

            when (val result = deleteHydrationEntryUseCase.deleteFromBoth(entryId)) {
                is ResultWrapper.Success -> {
                    logger.d(TAG, "Entry deleted successfully")
                    refreshFromLocal()
                }

                is ResultWrapper.Error -> {
                    logger.e(TAG, "Failed to delete entry", result.exception)
                    _uiState.update {
                        it.copy(error = result.exception.getUserMessage())
                    }
                }

                else -> {}
            }
        }
    }

    /**
     * Update hydration preferences.
     */
    fun updatePreferences(newPrefs: HydrationPreferences) {
        viewModelScope.launch {
            logger.d(TAG, "Updating preferences")

            when (val result = updateHydrationPreferencesUseCase(newPrefs)) {
                is ResultWrapper.Success -> {
                    val goal = HydrationGoal.calculate(newPrefs)
                    val insights = getHydrationInsightsUseCase(goal)

                    _uiState.update {
                        it.copy(
                            preferences = newPrefs,
                            goal = goal,
                            baseGoalMl = goal.dailyGoalMl,
                            insights = insights
                        )
                    }

                    logger.d(TAG, "Preferences updated successfully")
                }

                is ResultWrapper.Error -> {
                    logger.e(TAG, "Failed to update preferences", result.exception)
                    _uiState.update {
                        it.copy(error = result.exception.getUserMessage())
                    }
                }

                else -> {}
            }
        }
    }

    /**
     * Select a date to view.
     */
    fun selectDate(date: LocalDate) {
        logger.d(TAG, "Selecting date: $date")
        _uiState.update { it.copy(selectedDate = date) }
    }

    /**
     * Clear error message.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Manually trigger sync.
     */
    fun sync() {
        viewModelScope.launch {
            val profileId = resolveProfileId()
            if (profileId != null) {
                syncWithCloud(profileId)
            }
        }
    }

    // ── Private helpers ──

    private suspend fun syncWithCloud(profileId: String) {
        _uiState.update { it.copy(isSyncing = true) }

        when (val result = syncHydrationUseCase(profileId)) {
            is ResultWrapper.Success -> {
                logger.d(TAG, "Sync completed successfully")
                refreshFromLocal()
            }

            is ResultWrapper.Error -> {
                logger.e(TAG, "Sync failed", result.exception)
                // Don't show error to user for background sync
            }

            else -> {}
        }

        _uiState.update { it.copy(isSyncing = false) }
    }

    private suspend fun syncSingleEntryToCloud(
        entry: com.swastricare.health.domain.model.hydration.HydrationEntry,
        profileId: String
    ) {
        viewModelScope.launch {
            try {
                hydrationRepository.syncEntriesToCloud(listOf(entry), profileId)
            } catch (e: Exception) {
                logger.w(TAG, "Failed to sync entry to cloud: ${e.message}")
            }
        }
    }

    private suspend fun refreshFromLocal() {
        val entries = hydrationRepository.loadLocalEntries()
        val goal = _uiState.value.goal
        val insights = getHydrationInsightsUseCase(goal)

        _uiState.update {
            it.copy(
                entries = entries,
                insights = insights
            )
        }

        analyzePatterns()
    }

    private suspend fun getPreferencesInternal(): HydrationPreferences {
        return hydrationRepository.loadPreferences()
    }

    private suspend fun analyzePatterns() {
        val timestamps = _uiState.value.entries.map { it.consumedAt.toString() }
        patternService.analyzePatterns(timestamps)
    }

    private suspend fun fetchWeatherAdjustment() {
        val service = weatherService ?: return

        try {
            val weather = service.getCurrentWeather()
            val factor = if (weather != null && weather.temperatureCelsius > WeatherService.HOT_WEATHER_THRESHOLD) {
                WeatherService.HOT_WEATHER_MULTIPLIER
            } else {
                1.0
            }

            _uiState.update {
                it.copy(
                    weatherData = weather,
                    weatherAdjustmentFactor = factor
                )
            }
        } catch (e: Exception) {
            logger.w(TAG, "Failed to fetch weather: ${e.message}")
            // Silent failure - weather is best effort
        }
    }

    private suspend fun resolveProfileId(): String? {
        return try {
            val currentUserId = authRepository.getCurrentUser()?.id
                ?: return null
            val healthProfileResult = profileRepository.getHealthProfile(currentUserId)
            when (healthProfileResult) {
                is ResultWrapper.Success -> healthProfileResult.data?.id
                else -> null
            }
        } catch (e: Exception) {
            logger.w(TAG, "Failed to resolve profile ID: ${e.message}")
            null
        }
    }

    companion object {
        private const val TAG = "HydrationViewModel"
    }
}
