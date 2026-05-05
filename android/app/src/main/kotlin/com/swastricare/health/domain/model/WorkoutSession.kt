package com.swastricare.health.domain.model

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * Domain model representing a single workout/run activity session.
 * This is the core domain entity used throughout the app.
 */
data class WorkoutSession(
    val id: String = UUID.randomUUID().toString(),
    val userId: String = "",
    val activityType: ActivityType = ActivityType.RUNNING,
    val startTime: LocalDateTime? = null,
    val endTime: LocalDateTime? = null,
    val distanceMeters: Double = 0.0,
    val durationSeconds: Long = 0,
    val avgPaceSecondsPerKm: Long = 0,
    val caloriesBurned: Int = 0,
    val avgHeartRate: Int? = null,
    val steps: Int = 0,
    val routePoints: List<RoutePoint> = emptyList(),
    val splits: List<WorkoutSplit> = emptyList(),
    val synced: Boolean = false
) {
    val distanceKm: Double get() = distanceMeters / 1000.0

    val formattedDuration: String get() {
        val hours = durationSeconds / 3600
        val mins = (durationSeconds % 3600) / 60
        val secs = durationSeconds % 60
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, mins, secs)
        } else {
            String.format("%02d:%02d", mins, secs)
        }
    }

    val formattedPace: String get() {
        if (avgPaceSecondsPerKm <= 0) return "--:--"
        val mins = avgPaceSecondsPerKm / 60
        val secs = avgPaceSecondsPerKm % 60
        return String.format("%d:%02d", mins, secs)
    }

    val formattedDistance: String get() = String.format("%.2f", distanceKm)

    val formattedDate: String get() {
        val formatter = DateTimeFormatter.ofPattern("MMM d, yyyy")
        return startTime?.format(formatter) ?: ""
    }
}

/**
 * Domain model for a single GPS point in a workout route.
 */
data class RoutePoint(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double = 0.0,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Domain model for a kilometer split during a workout.
 */
data class WorkoutSplit(
    val kilometer: Int,
    val timeSeconds: Long,
    val paceSecondsPerKm: Long,
    val elevationGain: Double = 0.0,
    val avgHeartRate: Int? = null
)

/**
 * Type of physical activity.
 */
enum class ActivityType(val dbValue: String, val displayName: String, val emoji: String) {
    WALKING("walking", "Walking", "🚶"),
    RUNNING("running", "Running", "🏃"),
    CYCLING("cycling", "Cycling", "🚴"),
    HIKING("hiking", "Hiking", "🥾");

    companion object {
        fun fromDb(value: String): ActivityType =
            entries.firstOrNull { it.dbValue == value } ?: RUNNING
    }
}

/**
 * Domain model for workout statistics over a time period.
 */
data class WorkoutStats(
    val totalDistance: Double = 0.0, // meters
    val totalDuration: Long = 0, // seconds
    val totalCalories: Int = 0,
    val totalActivities: Int = 0,
    val weeklyDistance: Double = 0.0,
    val weeklyDuration: Long = 0
) {
    val totalDistanceKm: Double get() = totalDistance / 1000.0
    val weeklyDistanceKm: Double get() = weeklyDistance / 1000.0

    val formattedTotalDuration: String get() {
        val hours = totalDuration / 3600
        val mins = (totalDuration % 3600) / 60
        return if (hours > 0) "${hours}h ${mins}m" else "${mins}m"
    }
}

/**
 * Time range filter for statistics.
 */
enum class TimeRangeFilter(val displayName: String, val days: Int) {
    TWO_WEEKS("2 Weeks", 14),
    ONE_MONTH("1 Month", 30),
    THREE_MONTHS("3 Months", 90)
}

/**
 * Current state of a workout session.
 */
enum class WorkoutState {
    IDLE,
    PREPARING,
    COUNTDOWN,
    TRACKING,
    PAUSED,
    FINISHING,
    SUMMARY,
    ERROR
}

/**
 * Workout recovery state for crash recovery.
 */
data class WorkoutRecoveryState(
    val activityType: ActivityType = ActivityType.RUNNING,
    val startTimeMs: Long = 0,
    val elapsedSeconds: Long = 0,
    val distanceMeters: Double = 0.0,
    val caloriesBurned: Int = 0,
    val isActive: Boolean = false
)
