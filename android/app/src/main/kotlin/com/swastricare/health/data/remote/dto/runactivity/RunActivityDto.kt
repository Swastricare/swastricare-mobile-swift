package com.swastricare.health.data.remote.dto.runactivity

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Data Transfer Object for run activity API operations.
 * Maps to the Supabase `run_activities` table schema.
 */
@Serializable
data class RunActivityDto(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("health_profile_id") val healthProfileId: String = "",
    @SerialName("activity_type") val activityType: String = "running",
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("end_time") val endTime: String? = null,
    @SerialName("distance_meters") val distanceMeters: Double = 0.0,
    @SerialName("duration_seconds") val durationSeconds: Long = 0,
    @SerialName("avg_pace_seconds_per_km") val avgPaceSecondsPerKm: Long = 0,
    @SerialName("calories_burned") val caloriesBurned: Int = 0,
    @SerialName("avg_heart_rate") val avgHeartRate: Int? = null,
    @SerialName("route_coordinates") val routeCoordinates: String? = null, // JSON string
    val splits: String? = null, // JSON string
    @SerialName("created_at") val createdAt: String? = null
)

/**
 * DTO for route coordinates (stored as JSON in database).
 */
@Serializable
data class RouteCoordinateDto(
    val lat: Double,
    val lng: Double,
    val alt: Double = 0.0,
    val ts: Long = 0
)

/**
 * DTO for workout recovery state (stored in SharedPreferences).
 */
@Serializable
data class WorkoutRecoveryStateDto(
    val activityType: String = "running",
    val startTimeMs: Long = 0,
    val elapsedSeconds: Long = 0,
    val distanceMeters: Double = 0.0,
    val caloriesBurned: Int = 0,
    val isActive: Boolean = false
)
