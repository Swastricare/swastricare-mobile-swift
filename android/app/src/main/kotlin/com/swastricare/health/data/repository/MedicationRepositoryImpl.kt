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
import com.swastricare.health.domain.model.MedicationDoseSummary
import com.swastricare.health.domain.model.MedicationLog
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.model.MedicationWithSchedule
import com.swastricare.health.domain.repository.MedicationRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
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

    // ─────────────────────────────────────
    // MARK: - Family Dashboard
    // ─────────────────────────────────────

    /**
     * Embedded-select row used to fetch a medication log along with the parent
     * medication's name in a single PostgREST query.
     */
    @Serializable
    private data class MedicationLogWithMedDto(
        val id: String,
        @SerialName("medication_id") val medicationId: String,
        @SerialName("scheduled_time") val scheduledTime: String? = null,
        val status: String,
        val medications: EmbeddedMedicationName? = null
    )

    @Serializable
    private data class EmbeddedMedicationName(
        val id: String,
        val name: String
    )

    override suspend fun getDosesForDay(
        profileId: String,
        date: LocalDate
    ): Result<List<MedicationDoseSummary>> {
        val start = date.atStartOfDay().format(isoFormatter)
        val end = date.plusDays(1).atStartOfDay().format(isoFormatter)

        return try {
            // 1. Fetch today's logs joined with their medication name.
            val logRows = supabaseClient.from("medication_logs").select(
                columns = io.github.jan.supabase.postgrest.query.Columns.raw(
                    "id, scheduled_time, status, medication_id, medications(id, name)"
                )
            ) {
                filter {
                    eq("health_profile_id", profileId)
                    gte("scheduled_time", start)
                    lt("scheduled_time", end)
                }
            }.decodeList<MedicationLogWithMedDto>()

            // 2. Fetch active daily schedules to synthesise expected doses.
            val scheduleDtos = supabaseClient.from("medication_schedules").select {
                filter {
                    eq("health_profile_id", profileId)
                    eq("is_active", true)
                    eq("schedule_type", "daily")
                }
            }.decodeList<com.swastricare.health.data.remote.dto.medication.MedicationScheduleDto>()

            // 3. Fetch the medications referenced by those schedules (for names).
            val medIds = (scheduleDtos.map { it.medicationId } +
                logRows.map { it.medicationId }).toSet()
            val medsById: Map<String, String> = if (medIds.isEmpty()) {
                emptyMap()
            } else {
                supabaseClient.from("medications").select(
                    columns = io.github.jan.supabase.postgrest.query.Columns.raw("id, name")
                ) {
                    filter { isIn("id", medIds.toList()) }
                }.decodeList<EmbeddedMedicationName>().associate { it.id to it.name }
            }

            // 4. Build summaries from existing logs.
            val matchedLogIds = mutableSetOf<String>()
            val logSummaries = logRows.map { row ->
                val parsed = runCatching {
                    LocalDateTime.parse(
                        row.scheduledTime?.substringBefore("+")?.substringBefore("Z")
                            ?: "",
                        isoFormatter
                    )
                }.getOrNull()
                MedicationDoseSummary(
                    logId = row.id,
                    medicationId = row.medicationId,
                    medicationName = row.medications?.name
                        ?: medsById[row.medicationId]
                        ?: "Medication",
                    scheduledAt = parsed?.format(isoFormatter) ?: (row.scheduledTime ?: ""),
                    status = row.status
                )
            }

            // 5. For each active daily schedule, synthesise an expected dose at
            //    today's `time_of_day`. If a log already exists for the same
            //    medication within ±1 hour, treat the log as the canonical
            //    record and skip the placeholder.
            val syntheticDoses = mutableListOf<MedicationDoseSummary>()
            scheduleDtos.forEach { schedule ->
                val timeOfDay = runCatching {
                    java.time.LocalTime.parse(
                        schedule.timeOfDay.take(8) // "HH:mm:ss"
                    )
                }.getOrNull() ?: return@forEach

                val expectedAt = date.atTime(timeOfDay)

                val match = logRows.firstOrNull { log ->
                    if (log.medicationId != schedule.medicationId) return@firstOrNull false
                    val ts = log.scheduledTime ?: return@firstOrNull false
                    val parsedTs = runCatching {
                        LocalDateTime.parse(
                            ts.substringBefore("+").substringBefore("Z"),
                            isoFormatter
                        )
                    }.getOrNull() ?: return@firstOrNull false
                    val diffMinutes = java.time.Duration.between(parsedTs, expectedAt)
                        .abs().toMinutes()
                    diffMinutes <= 60
                }

                if (match != null) {
                    matchedLogIds += match.id
                    return@forEach
                }

                syntheticDoses += MedicationDoseSummary(
                    logId = null,
                    medicationId = schedule.medicationId,
                    medicationName = medsById[schedule.medicationId] ?: "Medication",
                    scheduledAt = expectedAt.format(isoFormatter),
                    status = "pending"
                )
            }

            val merged = (logSummaries + syntheticDoses)
                .sortedBy { it.scheduledAt }
            Result.success(merged)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch doses for profile=$profileId date=$date", e)
            Result.failure(e)
        }
    }

    // ─────────────────────────────────────
    // MARK: - Family Reminder Editing (Batch J)
    // ─────────────────────────────────────

    /** PostgREST embed row: schedule + parent medication name. */
    @Serializable
    private data class ScheduleWithMedDto(
        val id: String,
        @SerialName("time_of_day") val timeOfDay: String = "00:00:00",
        @SerialName("schedule_type") val scheduleType: String = "daily",
        @SerialName("frequency_per_day") val frequencyPerDay: Int = 1,
        @SerialName("reminder_enabled") val reminderEnabled: Boolean = true,
        @SerialName("is_active") val isActive: Boolean = true,
        val medications: EmbeddedMedicationName? = null
    )

    override suspend fun listMedicationsForProfile(
        profileId: String
    ): Result<List<MedicationWithSchedule>> {
        return try {
            val rows = supabaseClient.from("medication_schedules").select(
                columns = io.github.jan.supabase.postgrest.query.Columns.raw(
                    "id, time_of_day, schedule_type, frequency_per_day, reminder_enabled, is_active, medications!inner(id, name)"
                )
            ) {
                filter {
                    eq("health_profile_id", profileId)
                    eq("is_active", true)
                }
            }.decodeList<ScheduleWithMedDto>()

            val mapped = rows.mapNotNull { row ->
                val med = row.medications ?: return@mapNotNull null
                MedicationWithSchedule(
                    medicationId = med.id,
                    medicationName = med.name,
                    scheduleId = row.id,
                    scheduleType = row.scheduleType,
                    timeOfDay = row.timeOfDay,
                    frequencyPerDay = row.frequencyPerDay,
                    reminderEnabled = row.reminderEnabled,
                    isActive = row.isActive,
                )
            }.sortedWith(
                compareBy<MedicationWithSchedule> { it.medicationName.lowercase() }
                    .thenBy { it.timeOfDay }
            )

            Log.d(TAG, "Fetched ${mapped.size} schedules for family profile=$profileId")
            Result.success(mapped)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to list medications for profile=$profileId", e)
            Result.failure(e)
        }
    }

    override suspend fun updateScheduleTime(
        scheduleId: String,
        timeOfDay: String
    ): Result<Unit> = runCatching {
        supabaseClient.from("medication_schedules").update(
            buildJsonObject { put("time_of_day", timeOfDay) }
        ) {
            filter { eq("id", scheduleId) }
        }
        Unit
    }.onFailure { Log.e(TAG, "Failed to update schedule time for $scheduleId", it) }

    override suspend fun setReminderEnabled(
        scheduleId: String,
        enabled: Boolean
    ): Result<Unit> = runCatching {
        supabaseClient.from("medication_schedules").update(
            buildJsonObject { put("reminder_enabled", enabled) }
        ) {
            filter { eq("id", scheduleId) }
        }
        Unit
    }.onFailure { Log.e(TAG, "Failed to toggle reminder_enabled for $scheduleId", it) }
}
