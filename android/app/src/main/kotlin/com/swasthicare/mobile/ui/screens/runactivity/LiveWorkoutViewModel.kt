package com.swasthicare.mobile.ui.screens.runactivity

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.model.RoutePoint
import com.swasthicare.mobile.data.services.RouteTracker
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

// ─────────────────────────────────────
// MARK: - Workout Types
// ─────────────────────────────────────

enum class WorkoutType(val displayName: String, val icon: String, val usesGps: Boolean) {
    RUN("Run", "directions_run", true),
    WALK("Walk", "directions_walk", true),
    CYCLE("Cycle", "directions_bike", true),
    HIKE("Hike", "terrain", true),
    INDOOR_RUN("Indoor Run", "fitness_center", false),
    INDOOR_WALK("Indoor Walk", "fitness_center", false)
}

// ─────────────────────────────────────
// MARK: - Workout State
// ─────────────────────────────────────

enum class WorkoutPhase {
    IDLE,       // Not started
    COUNTDOWN,  // 3-2-1 countdown
    TRACKING,   // Active workout
    PAUSED,     // Workout paused
    COMPLETED   // Workout finished
}

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class LiveWorkoutUiState(
    val phase: WorkoutPhase = WorkoutPhase.IDLE,
    val workoutType: WorkoutType = WorkoutType.RUN,

    // Timer
    val elapsedSeconds: Long = 0,
    val countdownValue: Int = 3,

    // Metrics
    val distanceMeters: Double = 0.0,
    val currentSpeedMps: Float = 0f,       // meters per second
    val averageSpeedMps: Float = 0f,
    val caloriesBurned: Int = 0,
    val currentAltitude: Double = 0.0,

    // GPS
    val routePoints: List<RoutePoint> = emptyList(),
    val gpsStatus: RouteTracker.GpsStatus = RouteTracker.GpsStatus.OFF,
    val hasLocationPermission: Boolean = false,

    // Summary data
    val maxSpeedMps: Float = 0f,
    val elevationGainMeters: Double = 0.0
) {
    val elapsedFormatted: String get() {
        val hours = elapsedSeconds / 3600
        val minutes = (elapsedSeconds % 3600) / 60
        val seconds = elapsedSeconds % 60
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }

    val distanceKm: Double get() = distanceMeters / 1000.0

    val distanceFormatted: String get() = String.format("%.2f", distanceKm)

    val paceFormatted: String get() {
        // Pace in min/km
        if (distanceMeters < 10) return "--:--"
        val paceSeconds = elapsedSeconds / (distanceMeters / 1000.0)
        // Cap at 99:59 to avoid absurd display values
        if (paceSeconds > 5999) return "99:59"
        val paceMin = (paceSeconds / 60).toInt()
        val paceSec = (paceSeconds % 60).toInt()
        return String.format("%d:%02d", paceMin, paceSec)
    }

    val currentSpeedKmh: Float get() = currentSpeedMps * 3.6f

    val averageSpeedKmh: Float get() = averageSpeedMps * 3.6f
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

class LiveWorkoutViewModel(
    private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(LiveWorkoutUiState())
    val uiState: StateFlow<LiveWorkoutUiState> = _uiState.asStateFlow()

    private val routeTracker = RouteTracker(context)

    private var timerJob: Job? = null
    private var maxSpeed: Float = 0f
    private var lastAltitude: Double? = null
    private var totalElevationGain: Double = 0.0

    init {
        // Collect route updates
        viewModelScope.launch {
            routeTracker.routePoints.collect { points ->
                _uiState.update { it.copy(routePoints = points) }
                // Track elevation gain
                if (points.isNotEmpty()) {
                    val currentAlt = points.last().altitude
                    _uiState.update { it.copy(currentAltitude = currentAlt) }
                    lastAltitude?.let { prev ->
                        val gain = currentAlt - prev
                        if (gain > 0) {
                            totalElevationGain += gain
                            _uiState.update { it.copy(elevationGainMeters = totalElevationGain) }
                        }
                    }
                    lastAltitude = currentAlt
                }
            }
        }

        viewModelScope.launch {
            routeTracker.totalDistanceMeters.collect { dist ->
                _uiState.update { it.copy(distanceMeters = dist) }
            }
        }

        viewModelScope.launch {
            routeTracker.gpsStatus.collect { status ->
                _uiState.update { it.copy(gpsStatus = status) }
            }
        }

        viewModelScope.launch {
            routeTracker.currentSpeed.collect { speed ->
                if (speed > maxSpeed) maxSpeed = speed
                _uiState.update { it.copy(
                    currentSpeedMps = speed,
                    maxSpeedMps = maxSpeed
                ) }
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: - Public Actions
    // ─────────────────────────────────────

    fun setWorkoutType(type: WorkoutType) {
        _uiState.update { it.copy(workoutType = type) }
    }

    fun onLocationPermissionResult(granted: Boolean) {
        _uiState.update { it.copy(hasLocationPermission = granted) }
    }

    fun startWorkout() {
        // Guard against double-taps: only start from IDLE
        if (_uiState.value.phase != WorkoutPhase.IDLE) return

        // Begin countdown
        _uiState.update { it.copy(phase = WorkoutPhase.COUNTDOWN, countdownValue = 3) }

        viewModelScope.launch {
            for (i in 3 downTo 1) {
                _uiState.update { it.copy(countdownValue = i) }
                delay(1000)
            }
            beginTracking()
        }
    }

    fun pauseWorkout() {
        _uiState.update { it.copy(phase = WorkoutPhase.PAUSED) }
        timerJob?.cancel()
        routeTracker.pauseTracking()
    }

    fun resumeWorkout() {
        _uiState.update { it.copy(phase = WorkoutPhase.TRACKING) }
        routeTracker.resumeTracking()
        startTimer()
    }

    fun stopWorkout() {
        val currentPhase = _uiState.value.phase
        if (currentPhase != WorkoutPhase.TRACKING && currentPhase != WorkoutPhase.PAUSED) return

        timerJob?.cancel()
        routeTracker.stopTracking()

        // Calculate final average speed
        val state = _uiState.value
        val avgSpeed = if (state.elapsedSeconds > 0) {
            (state.distanceMeters / state.elapsedSeconds).toFloat()
        } else 0f

        // Estimate calories (rough: 1 cal per kg per km, assuming 70kg)
        val calories = (state.distanceKm * 70).toInt()

        _uiState.update {
            it.copy(
                phase = WorkoutPhase.COMPLETED,
                averageSpeedMps = avgSpeed,
                caloriesBurned = calories
            )
        }
    }

    fun resetWorkout() {
        timerJob?.cancel()
        routeTracker.stopTracking()
        routeTracker.reset()
        maxSpeed = 0f
        lastAltitude = null
        totalElevationGain = 0.0
        _uiState.value = LiveWorkoutUiState()
    }

    fun getRouteSnapshot(): List<RoutePoint> = routeTracker.getRouteSnapshot()

    // ─────────────────────────────────────
    // MARK: - Private
    // ─────────────────────────────────────

    private fun beginTracking() {
        _uiState.update { it.copy(phase = WorkoutPhase.TRACKING) }

        // Start GPS if permission granted and workout uses GPS
        val state = _uiState.value
        if (state.hasLocationPermission && state.workoutType.usesGps) {
            routeTracker.startTracking()
        }

        startTimer()
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                _uiState.update { it.copy(elapsedSeconds = it.elapsedSeconds + 1) }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        routeTracker.stopTracking()
        timerJob?.cancel()
    }
}
