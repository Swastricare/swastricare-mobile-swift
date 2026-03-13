package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.medication.MedicationDto
import com.swastricare.health.data.remote.dto.medication.MedicationLogDto
import com.swastricare.health.data.remote.dto.medication.MedicationScheduleDto
import com.swastricare.health.domain.model.AdherenceStatus
import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationForm
import com.swastricare.health.domain.model.MedicationLog
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.model.MedicationStatus
import com.swastricare.health.domain.model.ScheduleType
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper between Medication DTOs and Domain models.
 */
object MedicationMapper {

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
    private val dateFormatter = DateTimeFormatter.ISO_LOCAL_DATE

    // ─────────────────────────────────────
    // MARK: - Medication Mapping
    // ─────────────────────────────────────

    fun MedicationDto.toDomain(): Medication {
        return Medication(
            id = id,
            healthProfileId = healthProfileId,
            name = name,
            dosage = dosage,
            dosageUnit = dosageUnit,
            form = mapMedicationForm(form),
            startDate = startDate?.let { parseDate(it) },
            endDate = endDate?.let { parseDate(it) },
            isOngoing = isOngoing,
            notes = notes,
            status = mapMedicationStatus(status),
            createdAt = createdAt?.let { parseDateTime(it) }
        )
    }

    fun Medication.toDto(): MedicationDto {
        return MedicationDto(
            id = id,
            healthProfileId = healthProfileId,
            name = name,
            dosage = dosage,
            dosageUnit = dosageUnit,
            form = form.toDbForm(),
            startDate = startDate?.toString(),
            endDate = endDate?.toString(),
            isOngoing = isOngoing,
            notes = notes,
            status = status.toDbStatus(),
            createdAt = createdAt?.format(isoFormatter)
        )
    }

    // ─────────────────────────────────────
    // MARK: - Schedule Mapping
    // ─────────────────────────────────────

    fun MedicationScheduleDto.toDomain(): MedicationSchedule {
        return MedicationSchedule(
            id = id,
            medicationId = medicationId,
            healthProfileId = healthProfileId,
            scheduleType = mapScheduleType(scheduleType),
            timeOfDay = timeOfDay,
            frequencyPerDay = frequencyPerDay,
            dosageAmount = dosageAmount,
            reminderEnabled = reminderEnabled,
            isActive = isActive,
            daysOfWeek = daysOfWeek
        )
    }

    fun MedicationSchedule.toDto(): MedicationScheduleDto {
        return MedicationScheduleDto(
            id = id,
            medicationId = medicationId,
            healthProfileId = healthProfileId,
            scheduleType = scheduleType.toDbType(),
            timeOfDay = timeOfDay,
            frequencyPerDay = frequencyPerDay,
            dosageAmount = dosageAmount,
            reminderEnabled = reminderEnabled,
            isActive = isActive,
            daysOfWeek = daysOfWeek
        )
    }

    // ─────────────────────────────────────
    // MARK: - Log Mapping
    // ─────────────────────────────────────

    fun MedicationLogDto.toDomain(): MedicationLog {
        return MedicationLog(
            id = id,
            medicationId = medicationId,
            scheduleId = scheduleId,
            healthProfileId = healthProfileId,
            scheduledTime = scheduledTime?.let { parseDateTime(it) } ?: LocalDateTime.now(),
            takenTime = takenTime?.let { parseDateTime(it) },
            status = mapAdherenceStatus(status),
            skipReason = skipReason,
            notes = notes
        )
    }

    fun MedicationLog.toDto(): MedicationLogDto {
        return MedicationLogDto(
            id = id,
            medicationId = medicationId,
            scheduleId = scheduleId,
            healthProfileId = healthProfileId,
            scheduledTime = scheduledTime.format(isoFormatter),
            takenTime = takenTime?.format(isoFormatter),
            status = status.toDbStatus(),
            skipReason = skipReason,
            notes = notes
        )
    }

    // ─────────────────────────────────────
    // MARK: - Helper Functions
    // ─────────────────────────────────────

    private fun mapMedicationForm(form: String?): MedicationForm {
        return when (form?.lowercase()) {
            "tablet", "capsule", "pill" -> MedicationForm.PILL
            "syrup", "liquid" -> MedicationForm.LIQUID
            "injection" -> MedicationForm.INJECTION
            "inhaler" -> MedicationForm.INHALER
            "drops" -> MedicationForm.DROPS
            "cream", "ointment" -> MedicationForm.CREAM
            else -> MedicationForm.OTHER
        }
    }

    private fun MedicationForm.toDbForm(): String {
        return when (this) {
            MedicationForm.PILL -> "tablet"
            MedicationForm.LIQUID -> "syrup"
            MedicationForm.INJECTION -> "injection"
            MedicationForm.INHALER -> "inhaler"
            MedicationForm.DROPS -> "drops"
            MedicationForm.CREAM -> "cream"
            MedicationForm.OTHER -> "other"
        }
    }

    private fun mapMedicationStatus(status: String): MedicationStatus {
        return when (status.lowercase()) {
            "active" -> MedicationStatus.ACTIVE
            "discontinued" -> MedicationStatus.DISCONTINUED
            "completed" -> MedicationStatus.COMPLETED
            else -> MedicationStatus.ACTIVE
        }
    }

    private fun MedicationStatus.toDbStatus(): String {
        return when (this) {
            MedicationStatus.ACTIVE -> "active"
            MedicationStatus.DISCONTINUED -> "discontinued"
            MedicationStatus.COMPLETED -> "completed"
        }
    }

    private fun mapAdherenceStatus(status: String): AdherenceStatus {
        return when (status.lowercase()) {
            "taken" -> AdherenceStatus.TAKEN
            "skipped" -> AdherenceStatus.SKIPPED
            "missed" -> AdherenceStatus.MISSED
            "late" -> AdherenceStatus.LATE
            "early" -> AdherenceStatus.EARLY
            else -> AdherenceStatus.PENDING
        }
    }

    private fun AdherenceStatus.toDbStatus(): String {
        return when (this) {
            AdherenceStatus.PENDING -> "pending"
            AdherenceStatus.TAKEN -> "taken"
            AdherenceStatus.MISSED -> "missed"
            AdherenceStatus.SKIPPED -> "skipped"
            AdherenceStatus.LATE -> "late"
            AdherenceStatus.EARLY -> "early"
        }
    }

    private fun mapScheduleType(type: String): ScheduleType {
        return when (type.lowercase()) {
            "once_daily" -> ScheduleType.ONCE_DAILY
            "twice_daily" -> ScheduleType.TWICE_DAILY
            "thrice_daily" -> ScheduleType.THRICE_DAILY
            "custom" -> ScheduleType.CUSTOM
            else -> ScheduleType.ONCE_DAILY
        }
    }

    private fun ScheduleType.toDbType(): String {
        return when (this) {
            ScheduleType.ONCE_DAILY -> "daily"
            ScheduleType.TWICE_DAILY -> "daily"
            ScheduleType.THRICE_DAILY -> "daily"
            ScheduleType.CUSTOM -> "custom"
        }
    }

    private fun parseDateTime(dateTimeStr: String): LocalDateTime? {
        return try {
            LocalDateTime.parse(dateTimeStr, isoFormatter)
        } catch (e: Exception) {
            null
        }
    }

    private fun parseDate(dateStr: String): LocalDate? {
        return try {
            LocalDate.parse(dateStr, dateFormatter)
        } catch (e: Exception) {
            null
        }
    }
}
