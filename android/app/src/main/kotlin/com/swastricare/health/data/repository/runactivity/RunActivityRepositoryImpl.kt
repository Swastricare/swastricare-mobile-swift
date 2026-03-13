package com.swastricare.health.data.repository.runactivity

import android.content.SharedPreferences
import com.swastricare.health.data.mapper.RunActivityMapper
import com.swastricare.health.data.remote.dto.runactivity.RunActivityDto
import com.swastricare.health.data.remote.dto.runactivity.WorkoutRecoveryStateDto
import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.model.WorkoutStats
import com.swastricare.health.domain.repository.RunActivityRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of RunActivityRepository using Supabase and local storage.
 *
 * Responsibilities:
 * - Persist workout sessions locally using SharedPreferences
 * - Sync with Supabase cloud storage
 * - Calculate statistics
 * - Manage workout recovery state
 *
 * @param supabaseClient Supabase client for API calls
 * @param sharedPreferences Local storage for caching
 */
@Singleton
class RunActivityRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences
) : RunActivityRepository {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    companion object {
        private const val KEY_RUN_ACTIVITIES = "run_activities"
        private const val KEY_WORKOUT_RECOVERY = "workout_recovery_state"
    }

    // ── Local Storage Operations ──

    override suspend fun loadLocalActivities(): List<WorkoutSession> = withContext(Dispatchers.IO) {
        try {
            val raw = sharedPreferences.getString(KEY_RUN_ACTIVITIES, null) ?: return@withContext emptyList()
            val dtos = json.decodeFromString(
                ListSerializer(RunActivityDto.serializer()),
                raw
            )
            dtos.map { RunActivityMapper.toDomain(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    override suspend fun saveLocalActivities(activities: List<WorkoutSession>) = withContext(Dispatchers.IO) {
        val dtos = activities.map { RunActivityMapper.toDto(it, it.userId) }
        val json = json.encodeToString(
            ListSerializer(RunActivityDto.serializer()),
            dtos
        )
        sharedPreferences.edit().putString(KEY_RUN_ACTIVITIES, json).apply()
    }

    override suspend fun addLocalActivity(activity: WorkoutSession) = withContext(Dispatchers.IO) {
        val current = loadLocalActivities().toMutableList()
        current.add(0, activity) // Add to front (newest first)
        saveLocalActivities(current)
    }

    override suspend fun deleteLocalActivity(id: String) = withContext(Dispatchers.IO) {
        val current = loadLocalActivities().filter { it.id != id }
        saveLocalActivities(current)
    }

    // ── Cloud Sync Operations ──

    override suspend fun syncActivitiesToCloud(
        activities: List<WorkoutSession>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val unsynced = activities.filter { !it.synced }
            if (unsynced.isEmpty()) {
                return@withContext Result.success(Unit)
            }

            val dtos = unsynced.map { RunActivityMapper.toDto(it, profileId) }
            supabaseClient.from("run_activities").upsert(dtos)

            // Mark as synced
            val updated = activities.map { activity ->
                if (!activity.synced) activity.copy(synced = true) else activity
            }
            saveLocalActivities(updated)

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun fetchActivitiesFromCloud(profileId: String): Result<List<WorkoutSession>> =
        withContext(Dispatchers.IO) {
            try {
                val dtos = supabaseClient.from("run_activities").select {
                    filter { eq("health_profile_id", profileId) }
                }.decodeList<RunActivityDto>()

                val activities = dtos.map { RunActivityMapper.toDomain(it) }
                saveLocalActivities(activities)

                Result.success(activities)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    // ── Statistics Operations ──

    override suspend fun calculateStatistics(
        activities: List<WorkoutSession>,
        filter: TimeRangeFilter
    ): WorkoutStats = withContext(Dispatchers.IO) {
        val cutoff = LocalDate.now().minusDays(filter.days.toLong()).atStartOfDay()
        val filtered = activities.filter { activity ->
            activity.startTime?.isAfter(cutoff) ?: false
        }

        val weekCutoff = LocalDate.now().minusDays(7).atStartOfDay()
        val weekActivities = activities.filter { activity ->
            activity.startTime?.isAfter(weekCutoff) ?: false
        }

        WorkoutStats(
            totalDistance = filtered.sumOf { it.distanceMeters },
            totalDuration = filtered.sumOf { it.durationSeconds },
            totalCalories = filtered.sumOf { it.caloriesBurned },
            totalActivities = filtered.size,
            weeklyDistance = weekActivities.sumOf { it.distanceMeters },
            weeklyDuration = weekActivities.sumOf { it.durationSeconds }
        )
    }

    // ── Workout Recovery Operations ──

    override suspend fun saveWorkoutState(state: WorkoutRecoveryState) = withContext(Dispatchers.IO) {
        val dto = RunActivityMapper.toDto(state)
        val json = json.encodeToString(WorkoutRecoveryStateDto.serializer(), dto)
        sharedPreferences.edit().putString(KEY_WORKOUT_RECOVERY, json).apply()
    }

    override suspend fun loadWorkoutState(): WorkoutRecoveryState? = withContext(Dispatchers.IO) {
        try {
            val raw = sharedPreferences.getString(KEY_WORKOUT_RECOVERY, null) ?: return@withContext null
            val dto = json.decodeFromString(WorkoutRecoveryStateDto.serializer(), raw)
            if (dto.isActive) RunActivityMapper.toDomain(dto) else null
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun clearWorkoutState() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().remove(KEY_WORKOUT_RECOVERY).apply()
    }
}
