package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.data.models.ActivityGoals
import com.swastricare.health.data.models.ActivityGoalsDto
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

interface ActivityGoalsRepository {
    fun loadLocalGoals(): ActivityGoals
    fun saveLocalGoals(goals: ActivityGoals)
    suspend fun fetchFromCloud(profileId: String): Result<ActivityGoals>
    suspend fun upsertToCloud(profileId: String, goals: ActivityGoals): Result<Unit>
}

private val goalsJson = Json { ignoreUnknownKeys = true; isLenient = true }
private const val PREFS_KEY_GOALS = "activity_goals_local"

@javax.inject.Singleton
class SupabaseActivityGoalsRepository @javax.inject.Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : ActivityGoalsRepository {

    override fun loadLocalGoals(): ActivityGoals {
        val raw = prefs.getString(PREFS_KEY_GOALS, null) ?: return ActivityGoals()
        return runCatching { goalsJson.decodeFromString<ActivityGoals>(raw) }
            .getOrDefault(ActivityGoals())
    }

    override fun saveLocalGoals(goals: ActivityGoals) {
        prefs.edit()
            .putString(PREFS_KEY_GOALS, goalsJson.encodeToString(goals))
            .apply()
    }

    override suspend fun fetchFromCloud(profileId: String): Result<ActivityGoals> =
        withContext(Dispatchers.IO) {
            runCatching {
                val dtos = supabaseClient.from("activity_goals")
                    .select(columns = Columns.ALL) {
                        filter { eq("health_profile_id", profileId) }
                    }
                    .decodeList<ActivityGoalsDto>()
                val goals = dtos.firstOrNull()?.toDomain() ?: ActivityGoals()
                saveLocalGoals(goals)
                goals
            }
        }

    override suspend fun upsertToCloud(profileId: String, goals: ActivityGoals): Result<Unit> =
        withContext(Dispatchers.IO) {
            runCatching {
                val dto = ActivityGoalsDto(
                    healthProfileId = profileId,
                    dailyStepsGoal = goals.dailyStepsGoal,
                    dailyDistanceMeters = goals.dailyDistanceMeters,
                    dailyCaloriesGoal = goals.dailyCaloriesGoal,
                    dailyActiveMinutes = goals.dailyActiveMinutes
                )
                supabaseClient.from("activity_goals").upsert(dto)
                saveLocalGoals(goals)
            }
        }
}
