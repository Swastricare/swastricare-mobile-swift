package com.swasthicare.mobile.ui.screens.runactivity

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.data.repository.RunActivityRepository
import com.swasthicare.mobile.data.repository.WorkoutRecoveryState
import com.swasthicare.mobile.data.services.LocationTrackingService
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.util.UUID

// ------------------------------------
// MARK: - UI State
// ------------------------------------

data class LiveWorkoutUiState(
    val workoutState: WorkoutState = WorkoutState.IDLE,
    val activityType: ActivityType = ActivityType.RUNNING,
    val elapsedSeconds: Long = 0,
    val distanceMeters: Double = 0.0,
    val currentPace: Long = 0, // sec/km
    val avgPace: Long = 0, // sec/km
    val caloriesBurned: Int = 0,
    val splits: List<ActivitySplit> = emptyList(),
    val routeCoordinates: List<RouteCoordinate> = emptyList(),
    val countdown: Int = 3,
    val error: String? = null,
    // Summary
    val savedSuccessfully: Boolean = false
) {
    val formattedElapsed: String get() {
        val hours = elapsedSeconds / 3600
        val mins = (elapsedSeconds % 3600) / 60
        val secs = elapsedSeconds % 60
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, mins, secs)
        } else {
            String.format("%02d:%02d", mins, secs)
        }
    }

    val formattedDistance: String get() = String.format("%.2f", distanceMeters / 1000.0)

    val formattedCurrentPace: String get() {
        if (currentPace <= 0 || currentPace > 3600) return "--:--"
        val mins = currentPace / 60
        val secs = currentPace % 60
        return String.format("%d:%02d", mins, secs)
    }

    val formattedAvgPace: String get() {
        if (avgPace <= 0 || avgPace > 3600) return "--:--"
        val mins = avgPace / 60
        val secs = avgPace % 60
        return String.format("%d:%02d", mins, secs)
    }
}

// ------------------------------------
// MARK: - ViewModel
// ------------------------------------

class LiveWorkoutViewModel(
    private val context: Context,
    private val repository: RunActivityRepository,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(LiveWorkoutUiState())
    val uiState: StateFlow<LiveWorkoutUiState> = _uiState.asStateFlow()

    private val locationService = LocationTrackingService(context)
    private var timerJob: Job? = null
    private var autoSaveJob: Job? = null
    private var startTime: LocalDateTime? = null
    private val demoProfileId = "demo-profile-id"

    init {
        // Check for crash recovery
        checkRecoveryState()

        // Observe location service
        viewModelScope.launch {
            locationService.totalDistanceMeters.collect { dist ->
                _uiState.value = _uiState.value.copy(distanceMeters = dist)
            }
        }
        viewModelScope.launch {
            locationService.currentPaceSecondsPerKm.collect { pace ->
                _uiState.value = _uiState.value.copy(currentPace = pace)
            }
        }
        viewModelScope.launch {
            locationService.avgPaceSecondsPerKm.collect { pace ->
                _uiState.value = _uiState.value.copy(avgPace = pace)
            }
        }
        viewModelScope.launch {
            locationService.splits.collect { splits ->
                _uiState.value = _uiState.value.copy(splits = splits)
            }
        }
        viewModelScope.launch {
            locationService.caloriesBurned.collect { cal ->
                _uiState.value = _uiState.value.copy(caloriesBurned = cal)
            }
        }
        viewModelScope.launch {
            locationService.routeCoordinates.collect { route ->
                _uiState.value = _uiState.value.copy(routeCoordinates = route)
            }
        }
    }

    fun selectActivityType(type: ActivityType) {
        _uiState.value = _uiState.value.copy(activityType = type)
    }

    fun startWorkout() {
        _uiState.value = _uiState.value.copy(workoutState = WorkoutState.COUNTDOWN, countdown = 3)

        viewModelScope.launch {
            // 3-2-1 countdown
            for (i in 3 downTo 1) {
                _uiState.value = _uiState.value.copy(countdown = i)
                delay(1000)
            }

            // Start tracking
            startTime = LocalDateTime.now()
            _uiState.value = _uiState.value.copy(
                workoutState = WorkoutState.TRACKING,
                elapsedSeconds = 0
            )

            locationService.startTracking(_uiState.value.activityType.dbValue)
            startTimer()
            startAutoSave()
        }
    }

    fun pauseWorkout() {
        _uiState.value = _uiState.value.copy(workoutState = WorkoutState.PAUSED)
        locationService.pauseTracking()
        timerJob?.cancel()
    }

    fun resumeWorkout() {
        _uiState.value = _uiState.value.copy(workoutState = WorkoutState.TRACKING)
        locationService.resumeTracking()
        startTimer()
    }

    fun stopWorkout() {
        _uiState.value = _uiState.value.copy(workoutState = WorkoutState.FINISHING)
        locationService.stopTracking()
        timerJob?.cancel()
        autoSaveJob?.cancel()
        repository.clearWorkoutState()

        _uiState.value = _uiState.value.copy(workoutState = WorkoutState.SUMMARY)
    }

    fun saveWorkout() {
        viewModelScope.launch {
            val state = _uiState.value
            val activity = RunActivity(
                id = UUID.randomUUID().toString(),
                userId = demoProfileId,
                activityType = state.activityType,
                startTime = startTime,
                endTime = LocalDateTime.now(),
                distanceMeters = state.distanceMeters,
                durationSeconds = state.elapsedSeconds,
                avgPaceSecondsPerKm = state.avgPace,
                caloriesBurned = state.caloriesBurned,
                routeCoordinates = state.routeCoordinates,
                splits = state.splits,
                synced = false
            )

            repository.addLocalActivity(activity)
            repository.clearWorkoutState()

            // Sync to cloud
            try {
                val profileId = resolveProfileId()
                repository.syncActivitiesToCloud(listOf(activity), profileId)
            } catch (_: Exception) { }

            _uiState.value = _uiState.value.copy(savedSuccessfully = true)
        }
    }

    fun discardWorkout() {
        repository.clearWorkoutState()
        resetState()
    }

    fun resetState() {
        _uiState.value = LiveWorkoutUiState()
    }

    fun hasLocationPermission(): Boolean = locationService.hasLocationPermission()

    // ------------------------------------
    // Private
    // ------------------------------------

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                _uiState.value = _uiState.value.copy(
                    elapsedSeconds = _uiState.value.elapsedSeconds + 1
                )
            }
        }
    }

    private fun startAutoSave() {
        autoSaveJob?.cancel()
        autoSaveJob = viewModelScope.launch {
            while (true) {
                delay(10_000) // Every 10 seconds
                val state = _uiState.value
                if (state.workoutState == WorkoutState.TRACKING || state.workoutState == WorkoutState.PAUSED) {
                    repository.saveWorkoutState(
                        WorkoutRecoveryState(
                            activityType = state.activityType.dbValue,
                            startTimeMs = startTime?.let {
                                java.time.ZoneOffset.UTC.let { offset ->
                                    it.toEpochSecond(offset) * 1000
                                }
                            } ?: 0,
                            elapsedSeconds = state.elapsedSeconds,
                            distanceMeters = state.distanceMeters,
                            caloriesBurned = state.caloriesBurned,
                            isActive = true
                        )
                    )
                }
            }
        }
    }

    private fun checkRecoveryState() {
        val recovered = repository.loadWorkoutState()
        if (recovered != null && recovered.isActive) {
            // There was an active workout when app crashed
            _uiState.value = _uiState.value.copy(
                workoutState = WorkoutState.PAUSED,
                activityType = ActivityType.fromDb(recovered.activityType),
                elapsedSeconds = recovered.elapsedSeconds,
                distanceMeters = recovered.distanceMeters,
                caloriesBurned = recovered.caloriesBurned
            )
        }
    }

    private suspend fun resolveProfileId(): String = try {
        profileRepository.getHealthProfile(demoProfileId)?.userId ?: demoProfileId
    } catch (_: Exception) { demoProfileId }

    override fun onCleared() {
        super.onCleared()
        locationService.stopTracking()
        timerJob?.cancel()
        autoSaveJob?.cancel()
    }
}
