package com.swastricare.health.data.repository

import android.content.SharedPreferences
import android.util.Log
import com.swastricare.health.data.models.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

private val json = Json { ignoreUnknownKeys = true; isLenient = true }
private const val PREF_KEY_MEDICATIONS = "cached_medications"

// ─────────────────────────────────────
// MARK: - Supabase Implementation
// ─────────────────────────────────────

@Suppress("DEPRECATION")
@javax.inject.Singleton
class SupabaseMedicationRepository @javax.inject.Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : MedicationRepository {

    companion object {
        private const val TAG = "MedicationRepo"
    }

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    override suspend fun fetchMedications(profileId: String): List<MedicationDto> {
        return try {
            supabaseClient.from("medications").select {
                filter {
                    eq("health_profile_id", profileId)
                    // Exclude soft-deleted records; all other statuses (active, completed, paused, stopped) are shown
                    neq("status", "discontinued")
                }
            }.decodeList<MedicationDto>()
        } catch (e: Exception) {
            // Fall back to cache on network error
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            getCachedMedications()
        }
    }

    override suspend fun fetchSchedules(profileId: String): List<MedicationScheduleDto> {
        return try {
            val result = supabaseClient.from("medication_schedules").select {
                filter {
                    eq("health_profile_id", profileId)
                    eq("is_active", true)
                }
            }.decodeList<MedicationScheduleDto>()
            Log.d(TAG, "fetchSchedules: got ${result.size} schedules for profile=$profileId")
            result
        } catch (e: Exception) {
            Log.e(TAG, "fetchSchedules FAILED for profile=$profileId", e)
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            emptyList()
        }
    }

    override suspend fun fetchTodayLogs(profileId: String, date: LocalDate): List<MedicationLogDto> {
        val start = date.atStartOfDay().format(isoFormatter)
        val end = date.plusDays(1).atStartOfDay().format(isoFormatter)
        return try {
            supabaseClient.from("medication_logs").select {
                filter {
                    eq("health_profile_id", profileId)
                    gte("scheduled_time", start)
                    lt("scheduled_time", end)
                }
            }.decodeList<MedicationLogDto>()
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            emptyList()
        }
    }

    override suspend fun fetchWeekLogs(profileId: String, weekStart: LocalDate): List<MedicationLogDto> {
        val start = weekStart.atStartOfDay().format(isoFormatter)
        val end = weekStart.plusDays(7).atStartOfDay().format(isoFormatter)
        return try {
            supabaseClient.from("medication_logs").select {
                filter {
                    eq("health_profile_id", profileId)
                    gte("scheduled_time", start)
                    lt("scheduled_time", end)
                }
            }.decodeList<MedicationLogDto>()
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            emptyList()
        }
    }

    override suspend fun fetchLogsForDateRange(
        profileId: String,
        startDate: LocalDate,
        endDate: LocalDate
    ): List<MedicationLogDto> {
        val start = startDate.atStartOfDay().format(isoFormatter)
        val end = endDate.plusDays(1).atStartOfDay().format(isoFormatter)
        return try {
            supabaseClient.from("medication_logs").select {
                filter {
                    eq("health_profile_id", profileId)
                    gte("scheduled_time", start)
                    lt("scheduled_time", end)
                }
            }.decodeList<MedicationLogDto>()
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            emptyList()
        }
    }

    override suspend fun upsertMedication(medication: MedicationDto): Result<MedicationDto> {
        return try {
            // Upsert and return the input object (we already have all fields with our generated UUID)
            supabaseClient.from("medications").upsert(medication)
            Result.success(medication)
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            Result.failure(e)
        }
    }

    override suspend fun upsertSchedules(schedules: List<MedicationScheduleDto>): Result<Unit> {
        return try {
            if (schedules.isNotEmpty()) {
                Log.d(TAG, "upsertSchedules: upserting ${schedules.size} schedules")
                supabaseClient.from("medication_schedules").upsert(schedules)
                Log.d(TAG, "upsertSchedules: success")
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "upsertSchedules FAILED", e)
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            Result.failure(e)
        }
    }

    override suspend fun markAsTaken(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String?
    ): Result<String> {
        return try {
            val nowStr = LocalDateTime.now().format(isoFormatter)
            val scheduledStr = scheduledTime.format(isoFormatter)
            val id = logId ?: java.util.UUID.randomUUID().toString()
            val log = MedicationLogDto(
                id = id,
                medicationId = medicationId,
                scheduleId = scheduleId,
                healthProfileId = profileId,
                scheduledTime = scheduledStr,
                takenTime = nowStr,
                status = "taken"
            )
            supabaseClient.from("medication_logs").upsert(log)
            Result.success(id)
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            Result.failure(e)
        }
    }

    override suspend fun markAsSkipped(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String?,
        reason: String?
    ): Result<String> {
        return try {
            val scheduledStr = scheduledTime.format(isoFormatter)
            val id = logId ?: java.util.UUID.randomUUID().toString()
            val log = MedicationLogDto(
                id = id,
                medicationId = medicationId,
                scheduleId = scheduleId,
                healthProfileId = profileId,
                scheduledTime = scheduledStr,
                status = "skipped",
                skipReason = reason
            )
            supabaseClient.from("medication_logs").upsert(log)
            Result.success(id)
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            Result.failure(e)
        }
    }

    override suspend fun deleteMedication(id: String): Result<Unit> {
        return try {
            // Soft-delete: set status to 'discontinued' using a JSON partial update
            supabaseClient.from("medications").update(
                buildJsonObject { put("status", "discontinued") }
            ) {
                filter { eq("id", id) }
            }
            // Invalidate local cache so the deleted medication disappears immediately
            val cached = getCachedMedications().filter { it.id != id }
            cacheMedications(cached)
            Result.success(Unit)
        } catch (e: Exception) {
            android.util.Log.e("MedicationRepo", "Error: ${e.message}", e)
            Result.failure(e)
        }
    }

    override fun getCachedMedications(): List<MedicationDto> {
        return try {
            val raw = prefs.getString(PREF_KEY_MEDICATIONS, null) ?: return emptyList()
            json.decodeFromString<List<MedicationDto>>(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    override fun cacheMedications(medications: List<MedicationDto>) {
        try {
            prefs.edit().putString(PREF_KEY_MEDICATIONS, json.encodeToString(medications)).apply()
        } catch (e: Exception) { /* ignore cache write failures */ }
    }
}
