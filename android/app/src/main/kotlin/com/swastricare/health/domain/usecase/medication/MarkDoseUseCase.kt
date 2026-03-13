package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.domain.repository.MedicationRepository
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * Use case for marking a medication dose as taken or skipped.
 * Handles adherence logging with proper validation.
 */
class MarkDoseUseCase @Inject constructor(
    private val repository: MedicationRepository
) {
    /**
     * Marks a dose as taken.
     *
     * @param medicationId The medication ID
     * @param scheduleId The schedule ID
     * @param profileId The health profile ID
     * @param scheduledTime The scheduled time for the dose
     * @param logId Optional existing log ID (for updates)
     * @return Result containing the log ID or error
     */
    suspend fun markTaken(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String? = null
    ): Result<String> {
        // Validate inputs
        if (medicationId.isBlank() || scheduleId.isBlank() || profileId.isBlank()) {
            return Result.failure(IllegalArgumentException("Required IDs cannot be empty"))
        }

        // Mark as taken in repository
        return repository.markDoseTaken(
            medicationId = medicationId,
            scheduleId = scheduleId,
            profileId = profileId,
            scheduledTime = scheduledTime,
            logId = logId
        )
    }

    /**
     * Marks a dose as skipped.
     *
     * @param medicationId The medication ID
     * @param scheduleId The schedule ID
     * @param profileId The health profile ID
     * @param scheduledTime The scheduled time for the dose
     * @param reason Optional reason for skipping
     * @param logId Optional existing log ID (for updates)
     * @return Result containing the log ID or error
     */
    suspend fun markSkipped(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        reason: String? = null,
        logId: String? = null
    ): Result<String> {
        // Validate inputs
        if (medicationId.isBlank() || scheduleId.isBlank() || profileId.isBlank()) {
            return Result.failure(IllegalArgumentException("Required IDs cannot be empty"))
        }

        // Mark as skipped in repository
        return repository.markDoseSkipped(
            medicationId = medicationId,
            scheduleId = scheduleId,
            profileId = profileId,
            scheduledTime = scheduledTime,
            reason = reason,
            logId = logId
        )
    }
}
