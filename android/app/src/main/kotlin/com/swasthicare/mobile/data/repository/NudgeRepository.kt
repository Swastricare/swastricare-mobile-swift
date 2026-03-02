package com.swasthicare.mobile.data.repository

import android.content.SharedPreferences
import android.util.Log
import com.swasthicare.mobile.data.model.HealthNudge
import com.swasthicare.mobile.data.model.NudgePriority
import com.swasthicare.mobile.data.model.NudgeType
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Repository interface for health nudges (server-driven nudge cards).
 */
interface NudgeRepository {
    suspend fun fetchActiveNudges(healthProfileId: String): List<HealthNudge>
    suspend fun dismissNudge(nudgeId: String)
    suspend fun markNudgeActedOn(nudgeId: String)
}

/**
 * Supabase-backed implementation with SharedPreferences cache (5-minute TTL).
 */
class SupabaseNudgeRepository(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences
) : NudgeRepository {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    override suspend fun fetchActiveNudges(healthProfileId: String): List<HealthNudge> {
        // Check cache first (scoped to this user's profile)
        val cached = loadFromCache(healthProfileId)
        if (cached != null) return cached

        return try {
            val nudges = supabaseClient.postgrest["health_nudges"]
                .select {
                    filter {
                        eq("health_profile_id", healthProfileId)
                        eq("dismissed", false)
                    }
                }
                .decodeList<HealthNudge>()

            // Cache the result (scoped to this user's profile)
            saveToCache(healthProfileId, nudges)
            nudges
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch nudges from server: ${e.message}")
            // Return empty list on error (graceful degradation)
            emptyList()
        }
    }

    override suspend fun dismissNudge(nudgeId: String) {
        try {
            supabaseClient.postgrest["health_nudges"]
                .update({
                    set("dismissed", true)
                }) {
                    filter {
                        eq("id", nudgeId)
                    }
                }
            // Invalidate cache
            clearCache()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to dismiss nudge: ${e.message}")
        }
    }

    override suspend fun markNudgeActedOn(nudgeId: String) {
        try {
            supabaseClient.postgrest["health_nudges"]
                .update({
                    set("acted_on", true)
                }) {
                    filter {
                        eq("id", nudgeId)
                    }
                }
            clearCache()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to mark nudge as acted on: ${e.message}")
        }
    }

    // ─────────────────────────────────────
    // MARK: - Cache
    // ─────────────────────────────────────

    private fun getCacheKey(profileId: String) = "cached_nudges_$profileId"
    private fun getCacheTimeKey(profileId: String) = "nudge_cache_time_$profileId"

    private fun loadFromCache(profileId: String): List<HealthNudge>? {
        val cachedTime = sharedPreferences.getLong(getCacheTimeKey(profileId), 0L)
        if (System.currentTimeMillis() - cachedTime > CACHE_TTL_MS) return null

        val cachedJson = sharedPreferences.getString(getCacheKey(profileId), null) ?: return null
        return try {
            json.decodeFromString<List<HealthNudge>>(cachedJson)
        } catch (e: Exception) {
            null
        }
    }

    private fun saveToCache(profileId: String, nudges: List<HealthNudge>) {
        try {
            val nudgesJson = json.encodeToString(nudges)
            sharedPreferences.edit()
                .putString(getCacheKey(profileId), nudgesJson)
                .putLong(getCacheTimeKey(profileId), System.currentTimeMillis())
                .apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cache nudges: ${e.message}")
        }
    }

    private fun clearCache() {
        // Clear all nudge cache entries by removing known keys
        // Note: This clears all user caches; a more targeted approach would
        // require tracking the current profileId, but this is safe for invalidation
        val editor = sharedPreferences.edit()
        sharedPreferences.all.keys
            .filter { it.startsWith("cached_nudges_") || it.startsWith("nudge_cache_time_") }
            .forEach { editor.remove(it) }
        editor.apply()
    }

    companion object {
        private const val TAG = "NudgeRepository"
        private const val CACHE_TTL_MS = 5 * 60 * 1000L // 5 minutes
    }
}
