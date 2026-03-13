package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.HydrationMapper
import com.swastricare.health.data.remote.dto.hydration.HydrationEntryDto
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.model.hydration.HydrationPreferences
import com.swastricare.health.domain.repository.HydrationRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Implementation of HydrationRepository.
 * Handles data persistence to SharedPreferences and Supabase.
 */
class HydrationRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences,
    private val json: Json,
    private val logger: Logger
) : HydrationRepository {

    // ── Local entries ──

    override suspend fun loadLocalEntries(): List<HydrationEntry> = withContext(Dispatchers.IO) {
        try {
            val raw = sharedPreferences.getString(KEY_ENTRIES, null) ?: return@withContext emptyList()
            val dtos = json.decodeFromString<List<HydrationEntryDto>>(raw)
            HydrationMapper.toDomainList(dtos)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to load local entries", e)
            emptyList()
        }
    }

    override suspend fun addLocalEntry(entry: HydrationEntry): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val current = loadLocalEntries().toMutableList()
            current.add(entry)
            saveLocalEntries(current)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to add local entry", e)
            ResultWrapper.Error(AppException.UnknownException(e.message, e))
        }
    }

    override suspend fun saveLocalEntries(entries: List<HydrationEntry>): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                // Convert to DTOs (we need profileId for this, using empty string for local storage)
                val localDtos = entries.map { entry ->
                    HydrationEntryDto(
                        id = entry.id,
                        healthProfileId = "", // Not needed for local storage
                        beverageType = entry.drinkType.dbValue,
                        amountMl = entry.amountMl,
                        consumedAt = entry.consumedAt.toString(),
                        notes = entry.notes,
                        hydrationFactor = entry.drinkType.hydrationMultiplier
                    )
                }
                val encoded = json.encodeToString(localDtos)
                sharedPreferences.edit().putString(KEY_ENTRIES, encoded).apply()
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to save local entries", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    override suspend fun deleteLocalEntry(id: String): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val current = loadLocalEntries().filter { it.id != id }
            saveLocalEntries(current)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to delete local entry", e)
            ResultWrapper.Error(AppException.UnknownException(e.message, e))
        }
    }

    override suspend fun markEntriesAsSynced(ids: List<String>): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val current = loadLocalEntries().map { entry ->
                    if (ids.contains(entry.id)) entry.copy(synced = true) else entry
                }
                saveLocalEntries(current)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to mark entries as synced", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    // ── Preferences ──

    override suspend fun loadPreferences(): HydrationPreferences = withContext(Dispatchers.IO) {
        try {
            val raw = sharedPreferences.getString(KEY_PREFERENCES, null)
                ?: return@withContext HydrationPreferences.Default
            val dto = json.decodeFromString<com.swastricare.health.data.remote.dto.hydration.HydrationPreferencesDto>(raw)
            HydrationMapper.preferencesToDomain(dto)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to load preferences", e)
            HydrationPreferences.Default
        }
    }

    override suspend fun savePreferences(prefs: HydrationPreferences): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val dto = HydrationMapper.preferencesToDto(prefs)
                val encoded = json.encodeToString(dto)
                sharedPreferences.edit().putString(KEY_PREFERENCES, encoded).apply()
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to save preferences", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    // ── Cloud sync ──

    override suspend fun fetchFromCloud(profileId: String): ResultWrapper<List<HydrationEntry>> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Fetching hydration entries from cloud for profile: $profileId")

                val dtos = supabaseClient.from("hydration_logs")
                    .select {
                        filter { eq("health_profile_id", profileId) }
                    }
                    .decodeList<HydrationEntryDto>()

                val entries = HydrationMapper.toDomainList(dtos)
                logger.d(TAG, "Fetched ${entries.size} entries from cloud")

                ResultWrapper.Success(entries)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch from cloud", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun syncEntriesToCloud(
        entries: List<HydrationEntry>,
        profileId: String
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            if (entries.isEmpty()) {
                logger.d(TAG, "No entries to sync")
                return@withContext ResultWrapper.Success(Unit)
            }

            logger.d(TAG, "Syncing ${entries.size} entries to cloud")

            val dtos = HydrationMapper.toCreateDtoList(entries, profileId)
            supabaseClient.from("hydration_logs").upsert(dtos)

            // Mark as synced locally
            markEntriesAsSynced(entries.map { it.id })

            logger.d(TAG, "Successfully synced entries to cloud")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to sync entries to cloud", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    override suspend fun deleteCloudEntry(id: String): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            logger.d(TAG, "Deleting entry from cloud: $id")

            supabaseClient.from("hydration_logs").delete {
                filter { eq("id", id) }
            }

            logger.d(TAG, "Successfully deleted entry from cloud")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to delete entry from cloud", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    // ── Helpers ──

    private fun mapException(e: Exception): AppException {
        return when {
            e.message?.contains("network", ignoreCase = true) == true ->
                AppException.NetworkException.Unknown(e)
            e.message?.contains("unauthorized", ignoreCase = true) == true ->
                AppException.ApiException.Unauthorized()
            else -> AppException.UnknownException(cause = e)
        }
    }

    companion object {
        private const val TAG = "HydrationRepository"
        private const val KEY_ENTRIES = "hydration_entries"
        private const val KEY_PREFERENCES = "hydration_preferences"
    }
}
