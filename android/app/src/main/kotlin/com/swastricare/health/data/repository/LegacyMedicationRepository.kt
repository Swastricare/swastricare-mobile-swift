package com.swastricare.health.data.repository

import com.swastricare.health.data.models.*
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Legacy interface for MedicationRepository (data layer).
 *
 * DEPRECATED: This interface is kept for backward compatibility with:
 * - NotificationReceiver
 * - WidgetActionReceiver
 *
 * New code should use domain.repository.MedicationRepository instead.
 *
 * TODO: Migrate NotificationReceiver and WidgetActionReceiver to use Hilt and domain repositories,
 * then delete this file.
 */
@Deprecated(
    message = "Use domain.repository.MedicationRepository instead",
    replaceWith = ReplaceWith(
        "com.swastricare.health.domain.repository.MedicationRepository",
        "com.swastricare.health.domain.repository.MedicationRepository"
    )
)
interface MedicationRepository {
    suspend fun fetchMedications(profileId: String): List<MedicationDto>
    suspend fun fetchSchedules(profileId: String): List<MedicationScheduleDto>
    suspend fun fetchTodayLogs(profileId: String, date: LocalDate = LocalDate.now()): List<MedicationLogDto>
    suspend fun fetchWeekLogs(profileId: String, weekStart: LocalDate): List<MedicationLogDto>
    suspend fun upsertMedication(medication: MedicationDto): Result<MedicationDto>
    suspend fun upsertSchedules(schedules: List<MedicationScheduleDto>): Result<Unit>
    suspend fun markAsTaken(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String?
    ): Result<String>
    suspend fun markAsSkipped(
        medicationId: String,
        scheduleId: String,
        profileId: String,
        scheduledTime: LocalDateTime,
        logId: String?,
        reason: String?
    ): Result<String>
    suspend fun deleteMedication(id: String): Result<Unit>
    fun getCachedMedications(): List<MedicationDto>
    fun cacheMedications(medications: List<MedicationDto>)
}
