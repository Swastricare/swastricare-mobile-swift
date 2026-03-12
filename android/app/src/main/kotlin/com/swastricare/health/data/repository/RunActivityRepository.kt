package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.data.models.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime

private val runJson = Json { ignoreUnknownKeys = true; isLenient = true }

// ------------------------------------
// MARK: - Repository Interface
// ------------------------------------

interface RunActivityRepository {
    fun loadLocalActivities(): List<RunActivity>
    fun saveLocalActivities(activities: List<RunActivity>)
    fun addLocalActivity(activity: RunActivity)
    fun deleteLocalActivity(id: String)
    suspend fun syncActivitiesToCloud(activities: List<RunActivity>, profileId: String): Result<Unit>
    suspend fun fetchActivitiesFromCloud(profileId: String): Result<List<RunActivity>>
    fun calculateStatistics(activities: List<RunActivity>, filter: TimeRangeFilter): ActivityStatistics
    // Workout crash recovery
    fun saveWorkoutState(state: WorkoutRecoveryState)
    fun loadWorkoutState(): WorkoutRecoveryState?
    fun clearWorkoutState()
}

// ------------------------------------
// MARK: - Workout Recovery State
// ------------------------------------

@kotlinx.serialization.Serializable
data class WorkoutRecoveryState(
    val activityType: String = "running",
    val startTimeMs: Long = 0,
    val elapsedSeconds: Long = 0,
    val distanceMeters: Double = 0.0,
    val caloriesBurned: Int = 0,
    val isActive: Boolean = false
)

// ------------------------------------
// MARK: - Supabase Implementation
// ------------------------------------

class SupabaseRunActivityRepository(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : RunActivityRepository {

    // ── Local Activities ──

    override fun loadLocalActivities(): List<RunActivity> {
        return try {
            val raw = prefs.getString("run_activities", null) ?: return emptyList()
            runJson.decodeFromString<List<RunActivityDto>>(raw).map { it.toDomain() }
        } catch (_: Exception) { emptyList() }
    }

    override fun saveLocalActivities(activities: List<RunActivity>) {
        val dtos = activities.map { it.toDto("") }
        prefs.edit().putString("run_activities", runJson.encodeToString(dtos)).apply()
    }

    override fun addLocalActivity(activity: RunActivity) {
        val current = loadLocalActivities().toMutableList()
        current.add(0, activity) // Add to front (newest first)
        saveLocalActivities(current)
    }

    override fun deleteLocalActivity(id: String) {
        val current = loadLocalActivities().filter { it.id != id }
        saveLocalActivities(current)
    }

    // ── Cloud Sync ──

    override suspend fun syncActivitiesToCloud(
        activities: List<RunActivity>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val unsynced = activities.filter { !it.synced }
            if (unsynced.isEmpty()) return@withContext Result.success(Unit)
            val dtos = unsynced.map { it.toDto(profileId) }
            supabaseClient.from("run_activities").upsert(dtos)
            val updated = activities.map { it.copy(synced = true) }
            saveLocalActivities(updated)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun fetchActivitiesFromCloud(profileId: String): Result<List<RunActivity>> =
        withContext(Dispatchers.IO) {
            try {
                val dtos = supabaseClient.from("run_activities").select {
                    filter { eq("health_profile_id", profileId) }
                }.decodeList<RunActivityDto>()
                val activities = dtos.map { it.toDomain() }
                saveLocalActivities(activities)
                Result.success(activities)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    // ── Statistics ──

    override fun calculateStatistics(
        activities: List<RunActivity>,
        filter: TimeRangeFilter
    ): ActivityStatistics {
        val cutoff = LocalDate.now().minusDays(filter.days.toLong()).atStartOfDay()
        val filtered = activities.filter { activity ->
            activity.startTime?.isAfter(cutoff) ?: false
        }

        val weekCutoff = LocalDate.now().minusDays(7).atStartOfDay()
        val weekActivities = activities.filter { activity ->
            activity.startTime?.isAfter(weekCutoff) ?: false
        }

        return ActivityStatistics(
            totalDistance = filtered.sumOf { it.distanceMeters },
            totalDuration = filtered.sumOf { it.durationSeconds },
            totalCalories = filtered.sumOf { it.caloriesBurned },
            totalActivities = filtered.size,
            weeklyDistance = weekActivities.sumOf { it.distanceMeters },
            weeklyDuration = weekActivities.sumOf { it.durationSeconds }
        )
    }

    // ── Workout Recovery ──

    override fun saveWorkoutState(state: WorkoutRecoveryState) {
        prefs.edit().putString("workout_recovery_state", runJson.encodeToString(state)).apply()
    }

    override fun loadWorkoutState(): WorkoutRecoveryState? {
        return try {
            val raw = prefs.getString("workout_recovery_state", null) ?: return null
            val state = runJson.decodeFromString<WorkoutRecoveryState>(raw)
            if (state.isActive) state else null
        } catch (_: Exception) { null }
    }

    override fun clearWorkoutState() {
        prefs.edit().remove("workout_recovery_state").apply()
    }
}
