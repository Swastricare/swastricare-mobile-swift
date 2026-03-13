package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.runactivity.RouteCoordinateDto
import com.swastricare.health.data.remote.dto.runactivity.RunActivityDto
import com.swastricare.health.data.remote.dto.runactivity.WorkoutRecoveryStateDto
import com.swastricare.health.domain.model.ActivityType
import com.swastricare.health.domain.model.RoutePoint
import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.model.WorkoutSession
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper for converting between domain models and data transfer objects.
 * Follows Clean Architecture principle of dependency inversion.
 */
object RunActivityMapper {

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
    private val json = Json {
        encodeDefaults = true
        ignoreUnknownKeys = true
        isLenient = true
    }

    // ── WorkoutSession ↔ RunActivityDto ──

    /**
     * Convert domain WorkoutSession to API DTO.
     */
    fun toDto(session: WorkoutSession, profileId: String): RunActivityDto {
        val routeCoordsJson = if (session.routePoints.isNotEmpty()) {
            json.encodeToString(
                ListSerializer(RouteCoordinateDto.serializer()),
                session.routePoints.map { point ->
                    RouteCoordinateDto(
                        lat = point.latitude,
                        lng = point.longitude,
                        alt = point.altitude,
                        ts = point.timestamp
                    )
                }
            )
        } else null

        return RunActivityDto(
            id = session.id,
            healthProfileId = profileId,
            activityType = session.activityType.dbValue,
            startTime = session.startTime?.format(isoFormatter),
            endTime = session.endTime?.format(isoFormatter),
            distanceMeters = session.distanceMeters,
            durationSeconds = session.durationSeconds,
            avgPaceSecondsPerKm = session.avgPaceSecondsPerKm,
            caloriesBurned = session.caloriesBurned,
            avgHeartRate = session.avgHeartRate,
            routeCoordinates = routeCoordsJson,
            splits = null // TODO: Implement splits serialization if needed
        )
    }

    /**
     * Convert API DTO to domain WorkoutSession.
     */
    fun toDomain(dto: RunActivityDto): WorkoutSession {
        val routePoints = dto.routeCoordinates?.let { coordsJson ->
            try {
                json.decodeFromString(
                    ListSerializer(RouteCoordinateDto.serializer()),
                    coordsJson
                ).map { coordDto ->
                    RoutePoint(
                        latitude = coordDto.lat,
                        longitude = coordDto.lng,
                        altitude = coordDto.alt,
                        timestamp = coordDto.ts
                    )
                }
            } catch (e: Exception) {
                emptyList()
            }
        } ?: emptyList()

        return WorkoutSession(
            id = dto.id,
            userId = dto.healthProfileId,
            activityType = ActivityType.fromDb(dto.activityType),
            startTime = dto.startTime?.let {
                try {
                    LocalDateTime.parse(it, isoFormatter)
                } catch (e: Exception) {
                    null
                }
            },
            endTime = dto.endTime?.let {
                try {
                    LocalDateTime.parse(it, isoFormatter)
                } catch (e: Exception) {
                    null
                }
            },
            distanceMeters = dto.distanceMeters,
            durationSeconds = dto.durationSeconds,
            avgPaceSecondsPerKm = dto.avgPaceSecondsPerKm,
            caloriesBurned = dto.caloriesBurned,
            avgHeartRate = dto.avgHeartRate,
            routePoints = routePoints,
            splits = emptyList(), // TODO: Implement splits deserialization if needed
            synced = true
        )
    }

    // ── WorkoutRecoveryState ↔ WorkoutRecoveryStateDto ──

    /**
     * Convert domain WorkoutRecoveryState to DTO.
     */
    fun toDto(state: WorkoutRecoveryState): WorkoutRecoveryStateDto {
        return WorkoutRecoveryStateDto(
            activityType = state.activityType.dbValue,
            startTimeMs = state.startTimeMs,
            elapsedSeconds = state.elapsedSeconds,
            distanceMeters = state.distanceMeters,
            caloriesBurned = state.caloriesBurned,
            isActive = state.isActive
        )
    }

    /**
     * Convert DTO to domain WorkoutRecoveryState.
     */
    fun toDomain(dto: WorkoutRecoveryStateDto): WorkoutRecoveryState {
        return WorkoutRecoveryState(
            activityType = ActivityType.fromDb(dto.activityType),
            startTimeMs = dto.startTimeMs,
            elapsedSeconds = dto.elapsedSeconds,
            distanceMeters = dto.distanceMeters,
            caloriesBurned = dto.caloriesBurned,
            isActive = dto.isActive
        )
    }
}
