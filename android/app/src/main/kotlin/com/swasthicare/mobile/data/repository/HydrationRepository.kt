package com.swasthicare.mobile.data.repository

import android.content.SharedPreferences
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.di.AppContainer
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val hydrationJson = Json { ignoreUnknownKeys = true; isLenient = true }

// ─────────────────────────────────────
// MARK: - Repository Interface
// ─────────────────────────────────────

interface HydrationRepository {
    // Local entries
    fun loadLocalEntries(): List<HydrationEntry>
    fun addLocalEntry(entry: HydrationEntry)
    fun deleteLocalEntry(id: String)
    fun markEntriesAsSynced(ids: List<String>)
    // Preferences
    fun loadPreferences(): HydrationPreferences
    fun savePreferences(prefs: HydrationPreferences)
    // Supabase
    suspend fun syncEntriesToCloud(entries: List<HydrationEntry>, profileId: String): Result<Unit>
    suspend fun deleteCloudEntry(id: String): Result<Unit>
}

// ─────────────────────────────────────
// MARK: - Supabase Implementation
// ─────────────────────────────────────

class SupabaseHydrationRepository(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : HydrationRepository {

    // ── Local Entries ──

    override fun loadLocalEntries(): List<HydrationEntry> {
        return try {
            val raw = prefs.getString("hydration_entries", null) ?: return emptyList()
            hydrationJson.decodeFromString<List<HydrationEntry>>(raw)
        } catch (_: Exception) { emptyList() }
    }

    override fun addLocalEntry(entry: HydrationEntry) {
        val current = loadLocalEntries().toMutableList()
        current.add(entry)
        prefs.edit().putString("hydration_entries", hydrationJson.encodeToString(current)).apply()
    }

    override fun deleteLocalEntry(id: String) {
        val current = loadLocalEntries().filter { it.id != id }
        prefs.edit().putString("hydration_entries", hydrationJson.encodeToString(current)).apply()
    }

    override fun markEntriesAsSynced(ids: List<String>) {
        val current = loadLocalEntries().map { entry ->
            if (ids.contains(entry.id)) entry.copy(synced = true) else entry
        }
        prefs.edit().putString("hydration_entries", hydrationJson.encodeToString(current)).apply()
    }

    // ── Preferences ──

    override fun loadPreferences(): HydrationPreferences {
        return try {
            val raw = prefs.getString("hydration_preferences", null) ?: return HydrationPreferences.Default
            hydrationJson.decodeFromString<HydrationPreferences>(raw)
        } catch (_: Exception) { HydrationPreferences.Default }
    }

    override fun savePreferences(prefs: HydrationPreferences) {
        this.prefs.edit().putString("hydration_preferences", hydrationJson.encodeToString(prefs)).apply()
    }

    // ── Supabase: Sync Entries ──

    override suspend fun syncEntriesToCloud(
        entries: List<HydrationEntry>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            if (entries.isEmpty()) return@withContext Result.success(Unit)
            val records = entries.map { HydrationEntryRecord.from(it, profileId) }
            supabaseClient.from("hydration_logs").upsert(records)
            markEntriesAsSynced(entries.map { it.id })
            Result.success(Unit)
        } catch (e: Exception) {
            AppContainer.crashlyticsService.recordException(e)
            Result.failure(e)
        }
    }

    override suspend fun deleteCloudEntry(id: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("hydration_logs").delete {
                    filter { eq("id", id) }
                }
                Result.success(Unit)
            } catch (e: Exception) {
                AppContainer.crashlyticsService.recordException(e)
                Result.failure(e)
            }
        }
}
