package com.swastricare.health.presentation.feature.runactivity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.data.services.FitnessAnalyticsService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.usecase.runactivity.DeleteWorkoutUseCase
import com.swastricare.health.domain.usecase.runactivity.GetWorkoutHistoryUseCase
import com.swastricare.health.domain.usecase.runactivity.SyncWorkoutsUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for the Run Activity screen.
 *
 * Following Clean Architecture and MVVM principles:
 * - Depends on use cases (not repositories directly)
 * - Exposes immutable UI state via StateFlow
 * - Handles user events through methods
 * - No business logic (delegated to use cases)
 * - Uses Hilt for dependency injection
 *
 * @param getWorkoutHistoryUseCase Use case for loading workout history
 * @param deleteWorkoutUseCase Use case for deleting workouts
 * @param syncWorkoutsUseCase Use case for syncing with cloud
 * @param authRepository Repository for getting current user
 * @param healthConnectService Service for Health Connect integration
 * @param fitnessAnalyticsService Service for fitness analytics
 */
@HiltViewModel
class RunActivityViewModel @Inject constructor(
    private val getWorkoutHistoryUseCase: GetWorkoutHistoryUseCase,
    private val deleteWorkoutUseCase: DeleteWorkoutUseCase,
    private val syncWorkoutsUseCase: SyncWorkoutsUseCase,
    private val authRepository: AuthRepository,
    private val healthConnectService: HealthConnectService,
    private val fitnessAnalyticsService: FitnessAnalyticsService
) : ViewModel() {

    private val _uiState = MutableStateFlow(RunActivityUiState(isLoading = true))
    val uiState: StateFlow<RunActivityUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    /**
     * Handle UI events.
     */
    fun onEvent(event: RunActivityEvent) {
        when (event) {
            is RunActivityEvent.LoadData -> loadData()
            is RunActivityEvent.SetTimeRange -> setTimeRange(event.filter)
            is RunActivityEvent.DeleteActivity -> deleteActivity(event.id)
            is RunActivityEvent.ClearError -> clearError()
            is RunActivityEvent.SyncWithCloud -> syncWithCloud()
        }
    }

    /**
     * Load workout data and statistics.
     */
    private fun loadData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            try {
                // Load workout history with current time filter
                val result = getWorkoutHistoryUseCase(
                    timeRange = _uiState.value.timeRangeFilter
                )

                result.fold(
                    onSuccess = { data ->
                        // Load Health Connect data
                        val summary = healthConnectService.getTodaySummary()

                        // Update state with workout data
                        _uiState.update { state ->
                            state.copy(
                                activities = data.activities,
                                statistics = data.statistics,
                                isLoading = false,
                                todaySteps = summary.steps,
                                todayDistance = summary.distanceKm,
                                todayCalories = summary.activeCalories
                            )
                        }

                        // Load fitness analytics in background
                        loadFitnessAnalytics(data.activities)

                        // Sync with cloud in background
                        syncInBackground()
                    },
                    onFailure = { error ->
                        _uiState.update { state ->
                            state.copy(
                                isLoading = false,
                                error = "Failed to load workouts: ${error.message}"
                            )
                        }
                    }
                )
            } catch (e: Exception) {
                _uiState.update { state ->
                    state.copy(
                        isLoading = false,
                        error = "Unexpected error: ${e.message}"
                    )
                }
            }
        }
    }

    /**
     * Change the time range filter and recalculate statistics.
     */
    private fun setTimeRange(filter: TimeRangeFilter) {
        viewModelScope.launch {
            try {
                val result = getWorkoutHistoryUseCase(timeRange = filter)

                result.fold(
                    onSuccess = { data ->
                        _uiState.update { state ->
                            state.copy(
                                timeRangeFilter = filter,
                                statistics = data.statistics,
                                activities = data.activities
                            )
                        }
                    },
                    onFailure = { error ->
                        _uiState.update { state ->
                            state.copy(error = "Failed to update filter: ${error.message}")
                        }
                    }
                )
            } catch (e: Exception) {
                _uiState.update { state ->
                    state.copy(error = "Failed to update filter: ${e.message}")
                }
            }
        }
    }

    /**
     * Delete a workout activity.
     */
    private fun deleteActivity(id: String) {
        viewModelScope.launch {
            try {
                val result = deleteWorkoutUseCase(id)

                result.fold(
                    onSuccess = {
                        // Reload data after deletion
                        loadData()
                    },
                    onFailure = { error ->
                        _uiState.update { state ->
                            state.copy(error = "Failed to delete workout: ${error.message}")
                        }
                    }
                )
            } catch (e: Exception) {
                _uiState.update { state ->
                    state.copy(error = "Failed to delete workout: ${e.message}")
                }
            }
        }
    }

    /**
     * Clear error message.
     */
    private fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Manually trigger cloud sync.
     */
    private fun syncWithCloud() {
        viewModelScope.launch {
            syncInBackground()
        }
    }

    /**
     * Sync unsynced activities with cloud in background.
     */
    private suspend fun syncInBackground() {
        try {
            val profileId = authRepository.getCurrentUser()?.id ?: return

            val result = syncWorkoutsUseCase(profileId)

            result.onFailure { error ->
                android.util.Log.w("RunActivityVM", "Sync failed: ${error.message}")
                // Don't update UI state for background sync failures
                // User doesn't need to be notified of automatic sync issues
            }
        } catch (e: Exception) {
            android.util.Log.w("RunActivityVM", "Sync error: ${e.message}")
        }
    }

    /**
     * Load fitness analytics data.
     */
    private suspend fun loadFitnessAnalytics(activities: List<com.swastricare.health.domain.model.WorkoutSession>) {
        try {
            // Convert domain models to legacy models for analytics service
            // TODO: Refactor FitnessAnalyticsService to use domain models
            val legacyActivities = activities.map { session ->
                com.swastricare.health.data.models.RunActivity(
                    id = session.id,
                    userId = session.userId,
                    activityType = com.swastricare.health.data.models.ActivityType.fromDb(session.activityType.dbValue),
                    startTime = session.startTime,
                    endTime = session.endTime,
                    distanceMeters = session.distanceMeters,
                    durationSeconds = session.durationSeconds,
                    avgPaceSecondsPerKm = session.avgPaceSecondsPerKm,
                    caloriesBurned = session.caloriesBurned,
                    avgHeartRate = session.avgHeartRate,
                    routeCoordinates = session.routePoints.map { point ->
                        com.swastricare.health.data.models.RouteCoordinate(
                            latitude = point.latitude,
                            longitude = point.longitude,
                            altitude = point.altitude,
                            timestamp = point.timestamp
                        )
                    },
                    splits = emptyList(),
                    synced = session.synced
                )
            }

            val fitnessData = fitnessAnalyticsService.getFitnessData(legacyActivities)

            _uiState.update { state ->
                state.copy(
                    vo2Max = fitnessData.vo2Max,
                    vo2MaxSource = fitnessData.vo2MaxSource,
                    weeklyTrainingLoad = fitnessData.weeklyTrainingLoad,
                    loadTrend = fitnessData.loadTrend
                )
            }
        } catch (e: Exception) {
            // Fitness analytics is optional, don't fail the whole screen
            android.util.Log.w("RunActivityVM", "Failed to load fitness analytics: ${e.message}")
        }
    }
}
