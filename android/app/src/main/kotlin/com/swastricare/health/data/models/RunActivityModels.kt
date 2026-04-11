package com.swastricare.health.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

// ------------------------------------
// MARK: - Enums
// ------------------------------------

enum class ActivityType(val dbValue: String, val displayName: String, val emoji: String) {
    WALKING("walk", "Walking", "🚶"),
    RUNNING("run", "Running", "🏃"),
    CYCLING("cycling", "Cycling", "🚴"),
    HIKING("hike", "Hiking", "🥾");

    companion object {
        fun fromDb(value: String): ActivityType =
            entries.firstOrNull { it.dbValue == value } ?: RUNNING
    }
}

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

// ------------------------------------
// MARK: - Domain Models
// ------------------------------------

data class RouteCoordinate(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double = 0.0,
    val timestamp: Long = System.currentTimeMillis()
)

data class ActivitySplit(
    val kilometer: Int,
    val timeSeconds: Long,
    val paceSecondsPerKm: Long,
    val elevationGain: Double = 0.0,
    val avgHeartRate: Int? = null
)

data class RunActivity(
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
    val routeCoordinates: List<RouteCoordinate> = emptyList(),
    val splits: List<ActivitySplit> = emptyList(),
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

data class WorkoutSummary(
    val activityType: ActivityType,
    val duration: Long, // seconds
    val distance: Double, // meters
    val avgPace: Long, // seconds per km
    val calories: Int,
    val splits: List<ActivitySplit>,
    val routeCoordinates: List<RouteCoordinate>
)

data class ActivityStatistics(
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

// ------------------------------------
// MARK: - Time Range Filter
// ------------------------------------

enum class TimeRangeFilter(val displayName: String, val days: Int) {
    TWO_WEEKS("2 Weeks", 14),
    ONE_MONTH("1 Month", 30),
    THREE_MONTHS("3 Months", 90)
}

// ------------------------------------
// MARK: - Supabase DTOs
// ------------------------------------

@Serializable
data class RunActivityDto(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("health_profile_id") val healthProfileId: String = "",
    @SerialName("activity_type") val activityType: String = "run",
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("ended_at") val endedAt: String? = null,
    @SerialName("distance_meters") val distanceMeters: Double = 0.0,
    @SerialName("duration_seconds") val durationSeconds: Long = 0,
    @SerialName("avg_pace_seconds_per_km") val avgPaceSecondsPerKm: Long = 0,
    @SerialName("calories_burned") val caloriesBurned: Int = 0,
    @SerialName("avg_heart_rate") val avgHeartRate: Int? = null,
    @SerialName("route_coordinates") val routeCoordinates: String? = null, // JSON string
    val splits: String? = null, // JSON string
    val steps: Int = 0, // Required by database schema
    @SerialName("created_at") val createdAt: String? = null
)

// ------------------------------------
// MARK: - Conversion
// ------------------------------------

// Use ISO instant formatter for Supabase TIMESTAMPTZ columns
private val isoFormatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME
private val routeJson = kotlinx.serialization.json.Json { encodeDefaults = true }

// Helper to convert LocalDateTime to ISO string with timezone
private fun LocalDateTime.toIsoStringWithZone(): String {
    return this.atZone(java.time.ZoneId.systemDefault()).format(isoFormatter)
}

@Serializable
private data class RouteCoordinateDto(
    val lat: Double,
    val lng: Double,
    val alt: Double = 0.0,
    val ts: Long = 0
)

@Serializable
private data class ActivitySplitDto(
    val km: Int,
    val time: Long,
    val pace: Long,
    val elev: Double = 0.0,
    val hr: Int? = null
)

fun RunActivity.toDto(profileId: String): RunActivityDto {
    val routeCoordsJson = if (routeCoordinates.isNotEmpty()) {
        routeJson.encodeToString(
            kotlinx.serialization.builtins.ListSerializer(RouteCoordinateDto.serializer()),
            routeCoordinates.map { rc ->
                RouteCoordinateDto(lat = rc.latitude, lng = rc.longitude, alt = rc.altitude, ts = rc.timestamp)
            }
        )
    } else null

    val splitsJson = if (splits.isNotEmpty()) {
        routeJson.encodeToString(
            kotlinx.serialization.builtins.ListSerializer(ActivitySplitDto.serializer()),
            splits.map { s ->
                ActivitySplitDto(
                    km = s.kilometer,
                    time = s.timeSeconds,
                    pace = s.paceSecondsPerKm,
                    elev = s.elevationGain,
                    hr = s.avgHeartRate
                )
            }
        )
    } else null

    return RunActivityDto(
        id = id,
        healthProfileId = profileId,
        activityType = activityType.dbValue,
        startedAt = startTime?.toIsoStringWithZone(),
        endedAt = endTime?.toIsoStringWithZone(),
        distanceMeters = distanceMeters,
        durationSeconds = durationSeconds,
        avgPaceSecondsPerKm = avgPaceSecondsPerKm,
        caloriesBurned = caloriesBurned,
        avgHeartRate = avgHeartRate,
        routeCoordinates = routeCoordsJson,
        splits = splitsJson,
        steps = 0 // TODO: Add step counting from Health Connect if available
    )
}

fun RunActivityDto.toDomain(): RunActivity {
    val coords = routeCoordinates?.let { json ->
        try {
            routeJson.decodeFromString(
                kotlinx.serialization.builtins.ListSerializer(RouteCoordinateDto.serializer()),
                json
            ).map { dto ->
                RouteCoordinate(latitude = dto.lat, longitude = dto.lng, altitude = dto.alt, timestamp = dto.ts)
            }
        } catch (_: Exception) { emptyList() }
    } ?: emptyList()

    val decodedSplits = splits?.let { json ->
        try {
            routeJson.decodeFromString(
                kotlinx.serialization.builtins.ListSerializer(ActivitySplitDto.serializer()),
                json
            ).map { dto ->
                ActivitySplit(
                    kilometer = dto.km,
                    timeSeconds = dto.time,
                    paceSecondsPerKm = dto.pace,
                    elevationGain = dto.elev,
                    avgHeartRate = dto.hr
                )
            }
        } catch (_: Exception) { emptyList() }
    } ?: emptyList()

    return RunActivity(
        id = id,
        userId = healthProfileId,
        activityType = ActivityType.fromDb(activityType),
        startTime = startedAt?.let {
            try {
                java.time.ZonedDateTime.parse(it, isoFormatter).toLocalDateTime()
            } catch (_: Exception) { null }
        },
        endTime = endedAt?.let {
            try {
                java.time.ZonedDateTime.parse(it, isoFormatter).toLocalDateTime()
            } catch (_: Exception) { null }
        },
        distanceMeters = distanceMeters,
        durationSeconds = durationSeconds,
        avgPaceSecondsPerKm = avgPaceSecondsPerKm,
        caloriesBurned = caloriesBurned,
        avgHeartRate = avgHeartRate,
        routeCoordinates = coords,
        splits = decodedSplits,
        synced = true
    )
}
