package com.swastricare.health.domain.repository

import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationDoseSummary
import com.swastricare.health.domain.model.MedicationLog
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.model.MedicationWithSchedule
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Domain repository interface for medication operations.
 * Defines business operations without implementation details.
 */
interface MedicationRepository {
    /**
     * Fetches all active medications for a health profile.
     */
    suspend fun getMedications(profileId: String): Result<List<Medication>>

    /**
     * Fetches all active schedules for a health profile.
     */
    suspend fun getSchedules(profileId: String): Result<List<MedicationSchedule>>

    /**
     * Fetches medication logs for a specific date.
     */
    suspend fun getLogsForDate(
        profileId: String,
        date: LocalDate = LocalDate.now()
    ): Result<List<MedicationLog>>

    /**
     * Fetches medication logs for a date range.
     */
    suspend fun getLogsForRange(
        profileId: String,
        startDate: LocalDate,
        endDate: LocalDate
    ): Result<List<MedicationLog>>

    /**
     * Adds a new medication.
     */
    suspend fun addMedication(medication: Medication): Result<Medication>

    /**
     * Updates an existing medication.
     */
    suspend fun updateMedication(medication: Medication): Result<Medication>

    /**
     * Deletes (soft-delete) a medication.
     */
    suspend fun deleteMedication(id: String): Result<Unit>

    /**
     * Adds schedules for a medication.
     */
    suspend fun addSchedules(schedules: List<MedicationSchedule>): Result<Unit>

    /**
     * Updates a medication schedule.
     */
    suspend fun updateSchedule(schedule: MedicationSchedule): Result<Unit>

    /**
     * Marks a dose as taken.
     */
    suspend fun markDoseTaken(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String? = null
    ): Result<String>

    /**
     * Marks a dose as skipped.
     */
    suspend fun markDoseSkipped(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        reason: String?,
        logId: String? = null
    ): Result<String>

    /**
     * Gets cached medications for offline access.
     */
    fun getCachedMedications(): List<Medication>

    /**
     * Caches medications for offline access.
     */
    fun cacheMedications(medications: List<Medication>)

    /**
     * Returns a per-dose summary for [date] suitable for the family-member
     * dashboard. Merges existing `medication_logs` rows with expected doses
     * synthesised from active `medication_schedules` (`schedule_type = daily`).
     *
     * Doses without a matching log are emitted with `logId = null` and
     * `status = "pending"`. The list is sorted ascending by `scheduledAt`.
     */
    suspend fun getDosesForDay(
        profileId: String,
        date: LocalDate
    ): Result<List<MedicationDoseSummary>>

    /**
     * Lists every active `medication_schedules` row for [profileId] joined
     * with its parent medication name. One row per schedule (a medication
     * with multiple daily doses produces multiple rows). Used by the
     * Family Member Reminders screen (Batch J).
     */
    suspend fun listMedicationsForProfile(
        profileId: String
    ): Result<List<MedicationWithSchedule>>

    /**
     * Updates `medication_schedules.time_of_day` for a single schedule.
     * Caller must pass a `HH:mm:00` formatted string. Requires `can_edit`
     * on the underlying health profile (enforced by RLS).
     */
    suspend fun updateScheduleTime(
        scheduleId: String,
        timeOfDay: String
    ): Result<Unit>

    /**
     * Toggles `medication_schedules.reminder_enabled` for a single schedule.
     */
    suspend fun setReminderEnabled(
        scheduleId: String,
        enabled: Boolean
    ): Result<Unit>
}
