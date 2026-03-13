package com.swastricare.health.domain.model

import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Domain model for a medication.
 * Pure business entity without framework dependencies.
 */
data class Medication(
    val id: String,
    val healthProfileId: String,
    val name: String,
    val dosage: String?,
    val dosageUnit: String?,
    val form: MedicationForm,
    val startDate: LocalDate?,
    val endDate: LocalDate?,
    val isOngoing: Boolean,
    val notes: String?,
    val status: MedicationStatus,
    val createdAt: LocalDateTime?
) {
    val displayDosage: String
        get() = buildString {
            dosage?.let { append(it) }
            dosageUnit?.let {
                if (isNotEmpty()) append(" ")
                append(it)
            }
        }
}

/**
 * Domain model for a medication schedule.
 * Represents when and how often a medication should be taken.
 */
data class MedicationSchedule(
    val id: String,
    val medicationId: String,
    val healthProfileId: String,
    val scheduleType: ScheduleType,
    val timeOfDay: String,
    val frequencyPerDay: Int,
    val dosageAmount: Double,
    val reminderEnabled: Boolean,
    val isActive: Boolean,
    val daysOfWeek: List<Int>?
) {
    init {
        require(dosageAmount > 0) { "Dosage amount must be positive" }
        require(frequencyPerDay > 0) { "Frequency per day must be positive" }
    }
}

/**
 * Domain model for a medication reminder.
 * Represents a notification for taking medication.
 */
data class MedicationReminder(
    val scheduleId: String,
    val medicationName: String,
    val dosage: String,
    val timeHour: Int,
    val timeMinute: Int,
    val enabled: Boolean
) {
    init {
        require(timeHour in 0..23) { "Hour must be between 0 and 23" }
        require(timeMinute in 0..59) { "Minute must be between 0 and 59" }
    }
}

/**
 * Domain model for a medication log entry.
 * Records adherence events (taken, skipped, missed).
 */
data class MedicationLog(
    val id: String,
    val medicationId: String,
    val scheduleId: String?,
    val healthProfileId: String,
    val scheduledTime: LocalDateTime,
    val takenTime: LocalDateTime?,
    val status: AdherenceStatus,
    val skipReason: String?,
    val notes: String?
)

/**
 * Domain model for a scheduled dose.
 * Combines schedule and log information for UI display.
 */
data class MedicationDose(
    val logId: String?,
    val scheduleId: String,
    val medicationId: String,
    val medicationName: String,
    val dosage: String,
    val medicationType: MedicationForm,
    val scheduledTime: LocalDateTime,
    val status: AdherenceStatus,
    val takenAt: LocalDateTime? = null,
    val skipReason: String? = null
) {
    val isOverdue: Boolean
        get() = status == AdherenceStatus.PENDING && scheduledTime.isBefore(LocalDateTime.now())

    val timePeriod: TimePeriod
        get() = TimePeriod.fromHour(scheduledTime.hour)
}

/**
 * Domain model combining medication with its doses.
 * Provides aggregated view for UI display.
 */
data class MedicationWithDoses(
    val medication: Medication,
    val schedules: List<MedicationSchedule>,
    val todayDoses: List<MedicationDose>
) {
    val takenCount: Int
        get() = todayDoses.count { it.status == AdherenceStatus.TAKEN }

    val totalDoses: Int
        get() = todayDoses.size

    val adherencePercentage: Float
        get() = if (totalDoses > 0) takenCount.toFloat() / totalDoses else 0f

    val hasOverdue: Boolean
        get() = todayDoses.any { it.isOverdue }

    val nextPending: MedicationDose?
        get() = todayDoses.firstOrNull { it.status == AdherenceStatus.PENDING }

    val displayDosage: String
        get() = medication.displayDosage
}

/**
 * Domain model for adherence statistics.
 */
data class AdherenceStatistics(
    val totalDoses: Int,
    val takenDoses: Int,
    val missedDoses: Int,
    val pendingDoses: Int,
    val adherenceRate: Float
) {
    companion object {
        val Empty = AdherenceStatistics(0, 0, 0, 0, 0f)
    }
}

// ─────────────────────────────────────
// MARK: - Enums
// ─────────────────────────────────────

enum class MedicationForm(val emoji: String, val displayName: String) {
    PILL("💊", "Pill"),
    LIQUID("🥛", "Liquid"),
    INJECTION("💉", "Injection"),
    INHALER("🌬️", "Inhaler"),
    DROPS("💧", "Drops"),
    CREAM("🧴", "Cream"),
    OTHER("🔵", "Other")
}

enum class MedicationStatus {
    ACTIVE,
    DISCONTINUED,
    COMPLETED
}

enum class AdherenceStatus {
    PENDING,
    TAKEN,
    MISSED,
    SKIPPED,
    LATE,
    EARLY
}

enum class ScheduleType(val displayName: String, val dosesPerDay: Int) {
    ONCE_DAILY("Once Daily", 1),
    TWICE_DAILY("Twice Daily", 2),
    THRICE_DAILY("Thrice Daily", 3),
    CUSTOM("Custom", 0)
}

enum class TimePeriod(val label: String, val startHour: Int, val endHour: Int) {
    MORNING("Morning", 5, 12),
    AFTERNOON("Afternoon", 12, 17),
    EVENING("Evening", 17, 21),
    NIGHT("Night", 21, 5);

    fun contains(hour: Int): Boolean = when (this) {
        MORNING -> hour in startHour until endHour
        AFTERNOON -> hour in startHour until endHour
        EVENING -> hour in startHour until endHour
        NIGHT -> hour >= startHour || hour < endHour
    }

    companion object {
        fun fromHour(hour: Int): TimePeriod = entries.first { it.contains(hour) }
    }
}
