package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.stress.StressCategory
import com.swastricare.health.domain.model.stress.StressEntry
import com.swastricare.health.domain.model.stress.StressMood
import com.swastricare.health.domain.model.stress.StressSource
import com.swastricare.health.domain.repository.StressRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject

// ── Local DTO ──

@Serializable
private data class StressEntryDto(
    val id: String,
    @SerialName("stress_level") val stressLevel: Int,
    @SerialName("calculated_stress_percent") val calculatedStressPercent: Int,
    val mood: String,
    val notes: String,
    val timestamp: String,
    val source: String,
    val synced: Boolean
)

// ── Supabase DTO ──

@Serializable
private data class DailyHealthMetricStressRecord(
    val id: String? = null,
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("metric_date") val metricDate: String,
    @SerialName("stress_level") val stressLevel: Int,
    @SerialName("mood") val mood: String? = null,
    @SerialName("notes") val notes: String? = null
)

class StressRepositoryImpl @Inject constructor(
    private val sharedPreferences: SharedPreferences,
    private val supabaseClient: SupabaseClient,
    private val json: Json,
    private val logger: Logger
) : StressRepository {

    companion object {
        private const val TAG = "StressRepository"
        private const val KEY_ENTRIES = "stress_entries"
        private const val MAX_ENTRIES = 500
    }

    // ── Local storage ──

    override suspend fun loadLocalEntries(): List<StressEntry> = withContext(Dispatchers.IO) {
        try {
            val raw = sharedPreferences.getString(KEY_ENTRIES, null)
                ?: return@withContext emptyList()
            val dtos = json.decodeFromString<List<StressEntryDto>>(raw)
            dtos.map { it.toDomain() }
        } catch (e: Exception) {
            logger.e(TAG, "Failed to load stress entries", e)
            emptyList()
        }
    }

    override suspend fun loadEntriesForDate(date: LocalDate): List<StressEntry> =
        withContext(Dispatchers.IO) {
            loadLocalEntries().filter { it.timestamp.toLocalDate() == date }
        }

    override suspend fun loadEntriesForDateRange(
        startDate: LocalDate,
        endDate: LocalDate
    ): List<StressEntry> = withContext(Dispatchers.IO) {
        loadLocalEntries().filter {
            val d = it.timestamp.toLocalDate()
            !d.isBefore(startDate) && !d.isAfter(endDate)
        }
    }

    override suspend fun addEntry(entry: StressEntry): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val current = loadLocalEntries().toMutableList()
                current.add(entry)
                val trimmed = if (current.size > MAX_ENTRIES) {
                    current.sortedByDescending { it.timestamp }.take(MAX_ENTRIES)
                } else {
                    current
                }
                saveEntries(trimmed)
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to add stress entry", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    override suspend fun deleteEntry(id: String): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val current = loadLocalEntries().filter { it.id != id }
                saveEntries(current)
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to delete stress entry", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    override suspend fun getLatestEntry(): StressEntry? = withContext(Dispatchers.IO) {
        loadLocalEntries().maxByOrNull { it.timestamp }
    }

    override suspend fun getTodayEntry(): StressEntry? = withContext(Dispatchers.IO) {
        val today = LocalDate.now()
        loadLocalEntries()
            .filter { it.timestamp.toLocalDate() == today }
            .maxByOrNull { it.timestamp }
    }

    // ── Cloud sync ──

    override suspend fun fetchFromCloud(profileId: String): ResultWrapper<List<StressEntry>> =
        withContext(Dispatchers.IO) {
            try {
                val records = supabaseClient.from("daily_health_metrics").select {
                    filter { eq("health_profile_id", profileId) }
                }.decodeList<DailyHealthMetricStressRecord>()
                    .filter { it.stressLevel > 0 }

                val entries = records.mapNotNull { record ->
                    try {
                        StressEntry(
                            id = record.id ?: java.util.UUID.randomUUID().toString(),
                            healthProfileId = record.healthProfileId,
                            stressLevel = record.stressLevel,
                            calculatedStressPercent = ((10 - record.stressLevel) * 100) / 10,
                            mood = record.mood?.let { name ->
                                try { StressMood.valueOf(name.uppercase()) } catch (_: Exception) { StressMood.NEUTRAL }
                            } ?: StressMood.NEUTRAL,
                            notes = record.notes ?: "",
                            timestamp = LocalDate.parse(record.metricDate)
                                .atStartOfDay(),
                            source = StressSource.MANUAL,
                            synced = true
                        )
                    } catch (_: Exception) { null }
                }
                ResultWrapper.Success(entries)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch stress from cloud", e)
                ResultWrapper.Error(AppException.UnknownException("Cloud fetch failed", e))
            }
        }

    override suspend fun syncToCloud(
        entries: List<StressEntry>,
        profileId: String
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val records = entries.map { entry ->
                DailyHealthMetricStressRecord(
                    id = entry.id,
                    healthProfileId = profileId,
                    metricDate = entry.timestamp.toLocalDate()
                        .format(DateTimeFormatter.ISO_LOCAL_DATE),
                    stressLevel = entry.stressLevel,
                    mood = entry.mood.name,
                    notes = entry.notes.ifBlank { null }
                )
            }
            supabaseClient.from("daily_health_metrics").upsert(records)
            logger.d(TAG, "Synced ${records.size} stress entries to cloud")

            // Mark entries as synced locally
            val all = loadLocalEntries().toMutableList()
            val syncedIds = entries.map { it.id }.toSet()
            val updated = all.map {
                if (it.id in syncedIds) it.copy(synced = true) else it
            }
            saveEntries(updated)

            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to sync stress to cloud", e)
            ResultWrapper.Error(AppException.UnknownException("Cloud sync failed", e))
        }
    }

    // ── Private helpers ──

    private fun saveEntries(entries: List<StressEntry>) {
        val dtos = entries.map { it.toDto() }
        val encoded = json.encodeToString(dtos)
        sharedPreferences.edit().putString(KEY_ENTRIES, encoded).apply()
    }

    // ── Mapping ──

    private fun StressEntry.toDto(): StressEntryDto = StressEntryDto(
        id = id,
        stressLevel = stressLevel,
        calculatedStressPercent = calculatedStressPercent,
        mood = mood.name,
        notes = notes,
        timestamp = timestamp.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
        source = source.name,
        synced = synced
    )

    private fun StressEntryDto.toDomain(): StressEntry = StressEntry(
        id = id,
        stressLevel = stressLevel,
        calculatedStressPercent = calculatedStressPercent,
        mood = try { StressMood.valueOf(mood) } catch (_: Exception) { StressMood.NEUTRAL },
        notes = notes,
        timestamp = LocalDateTime.parse(timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME),
        source = try { StressSource.valueOf(source) } catch (_: Exception) { StressSource.MANUAL },
        synced = synced
    )
}
