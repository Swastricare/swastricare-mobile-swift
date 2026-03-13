package com.swastricare.health.domain.repository

import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationLog
import com.swastricare.health.domain.model.MedicationSchedule
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
}
