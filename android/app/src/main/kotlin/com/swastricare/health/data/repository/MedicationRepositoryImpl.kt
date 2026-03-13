package com.swastricare.health.data.repository

import android.content.SharedPreferences
import android.util.Log
import com.swastricare.health.data.mapper.MedicationMapper
import com.swastricare.health.data.mapper.MedicationMapper.toDomain
import com.swastricare.health.data.mapper.MedicationMapper.toDto
import com.swastricare.health.data.remote.dto.medication.MedicationDto
import com.swastricare.health.data.remote.dto.medication.MedicationLogDto
import com.swastricare.health.data.remote.dto.medication.MedicationScheduleDto
import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationLog
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.repository.MedicationRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of MedicationRepository using Supabase.
 * Handles all medication-related data operations.
 */
@Singleton
class MedicationRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences,
    private val json: Json
) : MedicationRepository {

    companion object {
        private const val TAG = "MedicationRepoImpl"
        private const val PREF_KEY_MEDICATIONS = "cached_medications_v2"
    }

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    // ─────────────────────────────────────
    // MARK: - Fetch Operations
    // ─────────────────────────────────────

    override suspend fun getMedications(profileId: String): Result<List<Medication>> {
        return try {
            val dtos = supabaseClient.from("medications").select {
                filter {
                    eq("health_profile_id", profileId)
                    eq("status", "active")
                }
            }.decodeList<MedicationDto>()

            val medications = dtos.map { it.toDomain() }
            Result.success(medications)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch medications", e)
            // Return cached medications on error
            val cached = getCachedMedications()
            if (cached.isNotEmpty()) {
                Result.success(cached)
            } else {
                Result.failure(e)
            }
        }
    }

    override suspend fun getSchedules(profileId: String): Result<List<MedicationSchedule>> {
        return try {
            val dtos = supabaseClient.from("medication_schedules").select {
                filter {
                    eq("health_profile_id", profileId)
                    eq("is_active", true)
                }
            }.decodeList<MedicationScheduleDto>()

            val schedules = dtos.map { it.toDomain() }
            Log.d(TAG, "Fetched ${schedules.size} schedules for profile=$profileId")
            Result.success(schedules)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch schedules for profile=$profileId", e)
            Result.failure(e)
        }
    }

    override suspend fun getLogsForDate(
        profileId: String,
        date: LocalDate
    ): Result<List<MedicationLog>> {
        val start = date.atStartOfDay().format(isoFormatter)
        val end = date.plusDays(1).atStartOfDay().format(isoFormatter)

        return try {
            val dtos = supabaseClient.from("medication_logs").select {
                filter {
                    eq("health_profile_id", profileId)
                    gte("scheduled_time", start)
                    lt("scheduled_time", end)
                }
            }.decodeList<MedicationLogDto>()

            val logs = dtos.map { it.toDomain() }
            Result.success(logs)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch logs for date=$date", e)
            Result.failure(e)
        }
    }

    override suspend fun getLogsForRange(
        profileId: String,
        startDate: LocalDate,
        endDate: LocalDate
    ): Result<List<MedicationLog>> {
        val start = startDate.atStartOfDay().format(isoFormatter)
        val end = endDate.plusDays(1).atStartOfDay().format(isoFormatter)

        return try {
            val dtos = supabaseClient.from("medication_logs").select {
                filter {
                    eq("health_profile_id", profileId)
                    gte("scheduled_time", start)
                    lt("scheduled_time", end)
                }
            }.decodeList<MedicationLogDto>()

            val logs = dtos.map { it.toDomain() }
            Result.success(logs)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch logs for range $startDate to $endDate", e)
            Result.failure(e)
        }
    }

    // ─────────────────────────────────────
    // MARK: - Mutation Operations
    // ─────────────────────────────────────

    override suspend fun addMedication(medication: Medication): Result<Medication> {
        return try {
            val dto = medication.toDto()
            supabaseClient.from("medications").upsert(dto)
            Result.success(medication)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add medication", e)
            Result.failure(e)
        }
    }

    override suspend fun updateMedication(medication: Medication): Result<Medication> {
        return try {
            val dto = medication.toDto()
            supabaseClient.from("medications").upsert(dto)
            Result.success(medication)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update medication", e)
            Result.failure(e)
        }
    }

    override suspend fun deleteMedication(id: String): Result<Unit> {
        return try {
            // Soft-delete: set status to 'discontinued'
            supabaseClient.from("medications").update(
                buildJsonObject { put("status", "discontinued") }
            ) {
                filter { eq("id", id) }
            }

            // Remove from cache
            val cached = getCachedMedications().filter { it.id != id }
            cacheMedications(cached)

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete medication", e)
            Result.failure(e)
        }
    }

    override suspend fun addSchedules(schedules: List<MedicationSchedule>): Result<Unit> {
        return try {
            if (schedules.isEmpty()) {
                return Result.success(Unit)
            }

            val dtos = schedules.map { it.toDto() }
            Log.d(TAG, "Adding ${dtos.size} schedules")
            supabaseClient.from("medication_schedules").upsert(dtos)
            Log.d(TAG, "Successfully added schedules")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add schedules", e)
            Result.failure(e)
        }
    }

    override suspend fun updateSchedule(schedule: MedicationSchedule): Result<Unit> {
        return try {
            val dto = schedule.toDto()
            supabaseClient.from("medication_schedules").upsert(dto)
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update schedule", e)
            Result.failure(e)
        }
    }

    // ─────────────────────────────────────
    // MARK: - Adherence Logging
    // ─────────────────────────────────────

    override suspend fun markDoseTaken(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String?
    ): Result<String> {
        return try {
            val nowStr = LocalDateTime.now().format(isoFormatter)
            val scheduledStr = scheduledTime.format(isoFormatter)
            val id = logId ?: UUID.randomUUID().toString()

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
            Log.e(TAG, "Failed to mark dose as taken", e)
            Result.failure(e)
        }
    }

    override suspend fun markDoseSkipped(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        reason: String?,
        logId: String?
    ): Result<String> {
        return try {
            val scheduledStr = scheduledTime.format(isoFormatter)
            val id = logId ?: UUID.randomUUID().toString()

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
            Log.e(TAG, "Failed to mark dose as skipped", e)
            Result.failure(e)
        }
    }

    // ─────────────────────────────────────
    // MARK: - Cache Operations
    // ─────────────────────────────────────

    override fun getCachedMedications(): List<Medication> {
        return try {
            val raw = prefs.getString(PREF_KEY_MEDICATIONS, null) ?: return emptyList()
            val dtos = json.decodeFromString<List<MedicationDto>>(raw)
            dtos.map { it.toDomain() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read cached medications", e)
            emptyList()
        }
    }

    override fun cacheMedications(medications: List<Medication>) {
        try {
            val dtos = medications.map { it.toDto() }
            val encoded = json.encodeToString(dtos)
            prefs.edit().putString(PREF_KEY_MEDICATIONS, encoded).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cache medications", e)
        }
    }
}
