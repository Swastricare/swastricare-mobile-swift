package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.data.models.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val dietJson = Json { ignoreUnknownKeys = true; isLenient = true }

// ─────────────────────────────────────
// MARK: - Repository Interface
// ─────────────────────────────────────

interface DietRepository {
    // Local food cache
    fun getCachedFoodItems(): List<FoodItem>
    fun cacheFoodItems(items: List<FoodItem>)
    // Local logs
    fun loadLocalLogs(): List<DietLogEntry>
    fun addLocalLog(entry: DietLogEntry)
    fun deleteLocalLog(id: String)
    fun markLogsAsSynced(ids: List<String>)
    // Goals
    fun loadGoals(): DietGoals
    fun saveGoals(goals: DietGoals)
    // Favorites
    fun getFavoriteIds(): Set<String>
    fun saveFavoriteIds(ids: Set<String>)
    // Supabase
    suspend fun fetchFoodItems(limit: Int = 500): Result<List<FoodItem>>
    suspend fun syncLogsToCloud(entries: List<DietLogEntry>, profileId: String): Result<Unit>
    suspend fun deleteCloudLog(id: String): Result<Unit>
}

// ─────────────────────────────────────
// MARK: - Supabase Implementation
// ─────────────────────────────────────

@javax.inject.Singleton
class SupabaseDietRepository @javax.inject.Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : DietRepository {

    // ── Local Food Cache ──

    override fun getCachedFoodItems(): List<FoodItem> {
        return try {
            val raw = prefs.getString("diet_food_cache", null) ?: return emptyList()
            dietJson.decodeFromString<List<FoodItem>>(raw)
        } catch (_: Exception) { emptyList() }
    }

    override fun cacheFoodItems(items: List<FoodItem>) {
        try {
            prefs.edit().putString("diet_food_cache", dietJson.encodeToString(items)).apply()
        } catch (_: Exception) { }
    }

    // ── Local Diet Logs ──

    override fun loadLocalLogs(): List<DietLogEntry> {
        return try {
            val raw = prefs.getString("diet_logs", null) ?: return emptyList()
            dietJson.decodeFromString<List<DietLogEntry>>(raw)
        } catch (_: Exception) { emptyList() }
    }

    override fun addLocalLog(entry: DietLogEntry) {
        val current = loadLocalLogs().toMutableList()
        current.add(entry)
        prefs.edit().putString("diet_logs", dietJson.encodeToString(current)).apply()
    }

    override fun deleteLocalLog(id: String) {
        val current = loadLocalLogs().filter { it.id != id }
        prefs.edit().putString("diet_logs", dietJson.encodeToString(current)).apply()
    }

    override fun markLogsAsSynced(ids: List<String>) {
        val current = loadLocalLogs().map { log ->
            if (ids.contains(log.id)) log.copy(synced = true) else log
        }
        prefs.edit().putString("diet_logs", dietJson.encodeToString(current)).apply()
    }

    // ── Goals ──

    override fun loadGoals(): DietGoals {
        return try {
            val raw = prefs.getString("diet_goals", null) ?: return DietGoals.Default
            dietJson.decodeFromString<DietGoals>(raw)
        } catch (_: Exception) { DietGoals.Default }
    }

    override fun saveGoals(goals: DietGoals) {
        prefs.edit().putString("diet_goals", dietJson.encodeToString(goals)).apply()
    }

    // ── Favorites ──

    override fun getFavoriteIds(): Set<String> =
        prefs.getStringSet("diet_favorite_ids", emptySet()) ?: emptySet()

    override fun saveFavoriteIds(ids: Set<String>) {
        prefs.edit().putStringSet("diet_favorite_ids", ids).apply()
    }

    // ── Supabase: Food Items (public SELECT, no auth required) ──

    override suspend fun fetchFoodItems(limit: Int): Result<List<FoodItem>> =
        withContext(Dispatchers.IO) {
            try {
                val items = supabaseClient.from("food_items").select {
                    filter {
                        // Public table — no filter needed. Supabase returns up to default limit.
                    }
                }.decodeList<FoodItem>()
                Result.success(items)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    // ── Supabase: Sync Logs ──

    override suspend fun syncLogsToCloud(
        entries: List<DietLogEntry>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            if (entries.isEmpty()) return@withContext Result.success(Unit)
            val records = entries.map { DietLogRecord.from(it, profileId) }
            supabaseClient.from("diet_logs").upsert(records)
            markLogsAsSynced(entries.map { it.id })
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun deleteCloudLog(id: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("diet_logs").delete {
                    filter { eq("id", id) }
                }
                Result.success(Unit)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
}
