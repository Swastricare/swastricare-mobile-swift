package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.model.hydration.HydrationPreferences

/**
 * Repository contract for Hydration data.
 * Implemented in data layer.
 */
interface HydrationRepository {

    // ── Local entries ──

    /**
     * Load all hydration entries from local storage.
     */
    suspend fun loadLocalEntries(): List<HydrationEntry>

    /**
     * Add a hydration entry to local storage.
     */
    suspend fun addLocalEntry(entry: HydrationEntry): ResultWrapper<Unit>

    /**
     * Save hydration entries to local storage (replaces all).
     */
    suspend fun saveLocalEntries(entries: List<HydrationEntry>): ResultWrapper<Unit>

    /**
     * Delete a hydration entry from local storage.
     */
    suspend fun deleteLocalEntry(id: String): ResultWrapper<Unit>

    /**
     * Mark entries as synced.
     */
    suspend fun markEntriesAsSynced(ids: List<String>): ResultWrapper<Unit>

    // ── Preferences ──

    /**
     * Load hydration preferences from local storage.
     */
    suspend fun loadPreferences(): HydrationPreferences

    /**
     * Save hydration preferences to local storage.
     */
    suspend fun savePreferences(prefs: HydrationPreferences): ResultWrapper<Unit>

    // ── Cloud sync ──

    /**
     * Fetch hydration entries from cloud for a specific health profile.
     */
    suspend fun fetchFromCloud(profileId: String): ResultWrapper<List<HydrationEntry>>

    /**
     * Sync hydration entries to cloud.
     */
    suspend fun syncEntriesToCloud(
        entries: List<HydrationEntry>,
        profileId: String
    ): ResultWrapper<Unit>

    /**
     * Delete a hydration entry from cloud.
     */
    suspend fun deleteCloudEntry(id: String): ResultWrapper<Unit>

    /**
     * Sum hydration intake (`amount_ml`) for a target profile on a UTC day.
     * Used by the family-member dashboard. Returns 0 on empty / error windows.
     */
    suspend fun getTodayTotalMl(
        profileId: String,
        date: java.time.LocalDate
    ): ResultWrapper<Int>
}
