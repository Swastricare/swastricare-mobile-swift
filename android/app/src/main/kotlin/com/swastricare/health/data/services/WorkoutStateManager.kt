package com.swastricare.health.data.services

import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Persistent workout state manager.
 *
 * Saves workout state to SharedPreferences every 10 seconds during an active
 * workout so that the app can detect and recover abandoned sessions on the next
 * launch.  Mirrors the iOS `WorkoutStateManager` behaviour.
 *
 * Also exposes a [stopRequestedFromNotification] flow that is set to `true`
 * when the user taps the "Stop" action in the workout notification.  The
 * [LiveWorkoutViewModel] observes this to stop the workout cleanly even when
 * the app is in the background.
 */
@javax.inject.Singleton
class WorkoutStateManager @javax.inject.Inject constructor(
    private val sharedPreferences: SharedPreferences
) {

    companion object {
        private const val KEY_SAVED_STATE = "workout_saved_state"
        private const val KEY_STOP_REQUESTED = "workout_stop_requested"
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    }

    // Flow observed by LiveWorkoutViewModel to react to notification "Stop" taps
    private val _stopRequestedFromNotification = MutableStateFlow(false)
    val stopRequestedFromNotification: StateFlow<Boolean> =
        _stopRequestedFromNotification.asStateFlow()

    init {
        // Restore any pending stop flag that was written before the ViewModel was alive
        if (sharedPreferences.getBoolean(KEY_STOP_REQUESTED, false)) {
            _stopRequestedFromNotification.value = true
        }
    }

    // ---- public API --------------------------------------------------------

    /**
     * Called by [WorkoutNotificationService] when the user taps "Stop" in the
     * notification.  Persists the flag so it survives if the app process is
     * briefly restarted, and emits on the flow so an active ViewModel can react
     * immediately.
     */
    fun requestStopFromNotification() {
        sharedPreferences.edit()
            .putBoolean(KEY_STOP_REQUESTED, true)
            .apply()
        _stopRequestedFromNotification.value = true
    }

    /**
     * Clear the notification stop request after the ViewModel has handled it.
     */
    fun clearStopRequest() {
        sharedPreferences.edit()
            .remove(KEY_STOP_REQUESTED)
            .apply()
        _stopRequestedFromNotification.value = false
    }

    /**
     * Persist the current workout state (called every 10 s and on pause).
     */
    fun saveState(workoutState: SavedWorkoutState) {
        val encoded = json.encodeToString(workoutState)
        sharedPreferences.edit()
            .putString(KEY_SAVED_STATE, encoded)
            .apply()
    }

    /**
     * Load a previously saved state.  Returns `null` when there is nothing
     * stored or the stored snapshot has `isActive == false`.
     */
    fun loadSavedState(): SavedWorkoutState? {
        val raw = sharedPreferences.getString(KEY_SAVED_STATE, null) ?: return null
        return try {
            val state = json.decodeFromString<SavedWorkoutState>(raw)
            if (state.isActive) state else null
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Remove the persisted state.  Called on normal workout completion or when
     * the user explicitly discards the recovered workout.
     */
    fun clearState() {
        sharedPreferences.edit()
            .remove(KEY_SAVED_STATE)
            .apply()
    }

    /**
     * Quick check that avoids deserializing the full state unless necessary.
     * Returns `true` when there is an active state from a previous session.
     */
    fun hasAbandonedWorkout(): Boolean {
        return loadSavedState() != null
    }
}

// ---------- Data models -----------------------------------------------------

@Serializable
data class SavedWorkoutState(
    val workoutType: String,
    val startTime: String,           // ISO-8601 datetime
    val elapsedSeconds: Long,
    val distanceMeters: Double,
    val routePointsJson: String,     // serialized List<RoutePoint>
    val isActive: Boolean,
    val savedAt: String              // ISO-8601 datetime
)

@Serializable
data class RoutePoint(
    val latitude: Double,
    val longitude: Double,
    val timestamp: Long              // epoch millis
)
