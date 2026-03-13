package com.swastricare.health.ui.screens.runactivity

import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.health.connect.client.records.ExerciseSessionRecord
import com.swastricare.health.data.model.RoutePoint
import com.swastricare.health.data.models.ActivityType
import com.swastricare.health.data.models.WorkoutTemplate
import com.swastricare.health.data.models.RouteCoordinate
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.data.repository.RunActivityRepository
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.GpsMode
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.data.services.RouteTracker
import com.swastricare.health.data.services.SavedWorkoutState
import com.swastricare.health.data.services.WorkoutNotificationService
import com.swastricare.health.data.services.WorkoutStateManager
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.format.DateTimeFormatter
import javax.inject.Inject

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
    val currentSpeedMps: Float = 0f,       // meters per second (smoothed)
    val averageSpeedMps: Float = 0f,
    val caloriesBurned: Int = 0,
    val currentAltitude: Double = 0.0,

    // GPS
    val routePoints: List<RoutePoint> = emptyList(),
    val gpsStatus: RouteTracker.GpsStatus = RouteTracker.GpsStatus.OFF,
    val gpsMode: GpsMode = GpsMode.HIGH_ACCURACY,
    val hasLocationPermission: Boolean = false,
    val isAutopaused: Boolean = false,
    val currentLocation: Pair<Double, Double>? = null,

    // Summary data
    val maxSpeedMps: Float = 0f,
    val elevationGainMeters: Double = 0.0,

    // Templates
    val templates: List<WorkoutTemplate> = emptyList(),
    val activeTemplate: WorkoutTemplate? = null
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

@HiltViewModel
class LiveWorkoutViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val workoutStateManager: WorkoutStateManager,
    private val runActivityRepository: RunActivityRepository,
    private val analyticsService: AnalyticsService,
    private val appAnalyticsService: AppAnalyticsService,
    private val sharedPreferences: SharedPreferences,
    private val healthConnectService: HealthConnectService
) : ViewModel() {

    private val _uiState = MutableStateFlow(LiveWorkoutUiState())
    val uiState: StateFlow<LiveWorkoutUiState> = _uiState.asStateFlow()

    private val routeTracker = RouteTracker(context)

    private var timerJob: Job? = null
    private var autoSaveJob: Job? = null
    private var countdownJob: Job? = null
    private var maxSpeed: Float = 0f
    private var totalElevationGain: Double = 0.0
    private var workoutStartTime: Instant? = null

    // Elevation smoothing: rolling window to filter GPS altitude noise
    private val altitudeBuffer = ArrayDeque<Double>(5)
    private val ALTITUDE_BUFFER_SIZE = 5
    private val MIN_ELEVATION_CHANGE = 3.0  // ignore < 3m altitude fluctuations
    private var smoothedAltitude: Double? = null

    private val autoSaveJson = Json { encodeDefaults = true }
    private val isoFormatter = DateTimeFormatter.ISO_INSTANT

    init {
        // Collect route updates with elevation smoothing
        viewModelScope.launch {
            routeTracker.routePoints.collect { points ->
                _uiState.update { it.copy(routePoints = points) }
                if (points.isNotEmpty()) {
                    val rawAlt = points.last().altitude

                    // Rolling average for altitude smoothing
                    if (altitudeBuffer.size >= ALTITUDE_BUFFER_SIZE) altitudeBuffer.removeFirst()
                    altitudeBuffer.addLast(rawAlt)
                    val currentSmoothedAlt = altitudeBuffer.average()

                    _uiState.update { it.copy(currentAltitude = currentSmoothedAlt) }

                    // Only count elevation gain above the noise threshold
                    smoothedAltitude?.let { prev ->
                        val gain = currentSmoothedAlt - prev
                        if (gain > MIN_ELEVATION_CHANGE) {
                            totalElevationGain += gain
                            _uiState.update { it.copy(elevationGainMeters = totalElevationGain) }
                        }
                    }
                    smoothedAltitude = currentSmoothedAlt
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

        viewModelScope.launch {
            routeTracker.gpsMode.collect { mode ->
                _uiState.update { it.copy(gpsMode = mode) }
            }
        }

        // Collect auto-pause state from RouteTracker
        viewModelScope.launch {
            routeTracker.isAutopaused.collect { autopaused ->
                _uiState.update { it.copy(isAutopaused = autopaused) }
            }
        }

        // Collect raw current location (for map centering before route is built)
        viewModelScope.launch {
            routeTracker.currentLocation.collect { loc ->
                _uiState.update { it.copy(currentLocation = loc) }
            }
        }

        loadTemplates()
    }

    // ─────────────────────────────────────
    // MARK: - Public Actions
    // ─────────────────────────────────────

    fun loadTemplates() {
        val templates = WorkoutTemplate.loadTemplates(sharedPreferences)
        _uiState.update { it.copy(templates = templates) }
    }

    fun selectTemplate(template: WorkoutTemplate) {
        val type = WorkoutType.entries.find { it.name == template.activityType } ?: WorkoutType.RUN
        _uiState.update { it.copy(
            workoutType = type,
            activeTemplate = template
        ) }
    }

    fun clearTemplate() {
        _uiState.update { it.copy(activeTemplate = null) }
    }

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

        countdownJob = viewModelScope.launch {
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
        autoSaveJob?.cancel()
        routeTracker.pauseTracking()
        // Save state on pause so recovery knows we were paused
        saveCurrentState()
    }

    fun resumeWorkout() {
        _uiState.update { it.copy(phase = WorkoutPhase.TRACKING) }
        routeTracker.resumeTracking()
        startTimer()
        startAutoSave()
    }

    fun stopWorkout() {
        val currentPhase = _uiState.value.phase
        if (currentPhase != WorkoutPhase.TRACKING && currentPhase != WorkoutPhase.PAUSED) return

        countdownJob?.cancel()
        timerJob?.cancel()
        autoSaveJob?.cancel()
        routeTracker.stopTracking()
        WorkoutNotificationService.stop(context)

        // Workout completed normally — clear persisted recovery state
        workoutStateManager.clearState()

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

        // Log workout completion to analytics
        val activityType = state.workoutType.displayName
        analyticsService.logWorkoutComplete(activityType, state.elapsedSeconds, state.distanceKm)
        appAnalyticsService.trackWorkoutCompleted(activityType, state.elapsedSeconds, state.distanceMeters)
    }

    fun resetWorkout() {
        countdownJob?.cancel()
        timerJob?.cancel()
        autoSaveJob?.cancel()
        routeTracker.stopTracking()
        routeTracker.reset()
        WorkoutNotificationService.stop(context)

        // Discard — clear persisted recovery state
        workoutStateManager.clearState()

        maxSpeed = 0f
        smoothedAltitude = null
        altitudeBuffer.clear()
        totalElevationGain = 0.0
        workoutStartTime = null
        _uiState.value = LiveWorkoutUiState()
    }

    fun getRouteSnapshot(): List<RoutePoint> = routeTracker.getRouteSnapshot()

    /**
     * Save the completed workout as a RunActivity and persist it locally.
     * Called when user taps "Save Workout" on the summary.
     */
    fun saveCompletedWorkout() {
        val state = _uiState.value
        if (state.phase != WorkoutPhase.COMPLETED) return

        val activityType = when (state.workoutType) {
            WorkoutType.RUN, WorkoutType.INDOOR_RUN -> ActivityType.RUNNING
            WorkoutType.WALK, WorkoutType.INDOOR_WALK -> ActivityType.WALKING
            WorkoutType.CYCLE -> ActivityType.CYCLING
            WorkoutType.HIKE -> ActivityType.HIKING
        }

        val routeCoords = state.routePoints.map { rp ->
            RouteCoordinate(
                latitude = rp.latitude,
                longitude = rp.longitude,
                altitude = rp.altitude,
                timestamp = rp.timestamp
            )
        }

        val paceSecondsPerKm = if (state.distanceMeters > 10) {
            (state.elapsedSeconds / (state.distanceMeters / 1000.0)).toLong()
        } else 0L

        val activity = RunActivity(
            activityType = activityType,
            startTime = workoutStartTime?.let {
                java.time.LocalDateTime.ofInstant(it, java.time.ZoneId.systemDefault())
            },
            endTime = java.time.LocalDateTime.now(),
            distanceMeters = state.distanceMeters,
            durationSeconds = state.elapsedSeconds,
            avgPaceSecondsPerKm = paceSecondsPerKm,
            caloriesBurned = state.caloriesBurned,
            routeCoordinates = routeCoords,
            synced = false
        )

        runActivityRepository.addLocalActivity(activity)

        // Write exercise session to Health Connect
        viewModelScope.launch {
            val hcExerciseType = when (activityType) {
                ActivityType.RUNNING -> ExerciseSessionRecord.EXERCISE_TYPE_RUNNING
                ActivityType.WALKING -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
                ActivityType.CYCLING -> ExerciseSessionRecord.EXERCISE_TYPE_BIKING
                ActivityType.HIKING -> ExerciseSessionRecord.EXERCISE_TYPE_HIKING
            }
            healthConnectService.writeExerciseSession(
                exerciseType = hcExerciseType,
                startTime = workoutStartTime ?: Instant.now().minusSeconds(state.elapsedSeconds),
                endTime = Instant.now(),
                title = state.workoutType.displayName
            )
        }
    }

    // ─────────────────────────────────────
    // MARK: - Private
    // ─────────────────────────────────────

    private fun beginTracking() {
        _uiState.update { it.copy(phase = WorkoutPhase.TRACKING) }
        workoutStartTime = Instant.now()

        // Log workout start to analytics
        val activityType = _uiState.value.workoutType.displayName
        analyticsService.logWorkoutStart(activityType)
        appAnalyticsService.trackWorkoutStarted(activityType)

        // Start GPS if permission granted and workout uses GPS
        val state = _uiState.value
        if (state.hasLocationPermission && state.workoutType.usesGps) {
            routeTracker.startTracking()
        }

        WorkoutNotificationService.start(context)
        startTimer()
        startAutoSave()
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                _uiState.update { it.copy(elapsedSeconds = it.elapsedSeconds + 1) }
                val state = _uiState.value
                if (state.elapsedSeconds % 5 == 0L) {
                    val distanceKm = "%.2f km".format(state.distanceMeters / 1000.0)
                    WorkoutNotificationService.update(
                        context,
                        state.elapsedFormatted,
                        distanceKm,
                        state.paceFormatted,
                        state.caloriesBurned
                    )
                }
            }
        }
    }

    /**
     * Launches a coroutine that persists workout state every 10 seconds.
     * If the app crashes mid-workout the most recent snapshot can be
     * recovered on the next launch via [WorkoutStateManager.loadSavedState].
     */
    private fun startAutoSave() {
        autoSaveJob?.cancel()
        autoSaveJob = viewModelScope.launch {
            while (isActive) {
                delay(10_000)
                saveCurrentState()
            }
        }
    }

    /**
     * Snapshot the live workout into a [SavedWorkoutState] and persist it
     * via [WorkoutStateManager].
     */
    private fun saveCurrentState() {
        val state = _uiState.value
        val startIso = workoutStartTime?.let { isoFormatter.format(it) } ?: return
        val nowIso = isoFormatter.format(Instant.now())

        // Convert model RoutePoints to the serializable format used by WorkoutStateManager
        val routePointsSerialized = autoSaveJson.encodeToString(
            state.routePoints.map { rp ->
                com.swastricare.health.data.services.RoutePoint(
                    latitude = rp.latitude,
                    longitude = rp.longitude,
                    timestamp = rp.timestamp
                )
            }
        )

        val savedState = SavedWorkoutState(
            workoutType = state.workoutType.name,
            startTime = startIso,
            elapsedSeconds = state.elapsedSeconds,
            distanceMeters = state.distanceMeters,
            routePointsJson = routePointsSerialized,
            isActive = state.phase == WorkoutPhase.TRACKING || state.phase == WorkoutPhase.PAUSED,
            savedAt = nowIso
        )

        workoutStateManager.saveState(savedState)
    }

    override fun onCleared() {
        super.onCleared()
        routeTracker.stopTracking()
        timerJob?.cancel()
        autoSaveJob?.cancel()
    }
}
