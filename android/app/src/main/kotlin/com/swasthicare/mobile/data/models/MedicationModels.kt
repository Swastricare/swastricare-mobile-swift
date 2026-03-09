package com.swasthicare.mobile.data.models

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.EncodeDefault.Mode.ALWAYS
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

// ─────────────────────────────────────
// MARK: - Enums
// ─────────────────────────────────────

enum class MedicationType(val emoji: String, val displayName: String, val dbForm: String) {
    PILL("💊", "Pill", "tablet"),
    LIQUID("🥛", "Liquid", "syrup"),
    INJECTION("💉", "Injection", "injection"),
    INHALER("🌬️", "Inhaler", "inhaler"),
    DROPS("💧", "Drops", "drops"),
    CREAM("🧴", "Cream", "cream"),
    OTHER("🔵", "Other", "other");

    companion object {
        fun fromDbForm(form: String?): MedicationType = when (form) {
            "tablet", "capsule" -> PILL
            "syrup" -> LIQUID
            "injection" -> INJECTION
            "inhaler" -> INHALER
            "drops" -> DROPS
            "cream", "ointment" -> CREAM
            else -> OTHER
        }
    }
}

enum class AdherenceStatus {
    PENDING, TAKEN, MISSED, SKIPPED, LATE, EARLY;

    companion object {
        fun fromDb(status: String?): AdherenceStatus = when (status) {
            "taken" -> TAKEN
            "skipped" -> SKIPPED
            "missed" -> MISSED
            "late" -> LATE
            "early" -> EARLY
            else -> PENDING
        }
    }
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
}

// ─────────────────────────────────────
// MARK: - DB-mapped Serializable Models
// ─────────────────────────────────────

/** Maps to `medications` table */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class MedicationDto(
    @EncodeDefault(ALWAYS) val id: String = UUID.randomUUID().toString(),
    @EncodeDefault(ALWAYS) @SerialName("health_profile_id") val healthProfileId: String = "",
    @EncodeDefault(ALWAYS) val name: String = "",
    val dosage: String? = null,
    @SerialName("dosage_unit") val dosageUnit: String? = null,
    @EncodeDefault(ALWAYS) val form: String? = "tablet",
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
    @EncodeDefault(ALWAYS) @SerialName("is_ongoing") val isOngoing: Boolean = true,
    val notes: String? = null,
    @EncodeDefault(ALWAYS) val status: String = "active",
    @SerialName("created_at") val createdAt: String? = null
)

/** Maps to `medication_schedules` table */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class MedicationScheduleDto(
    @EncodeDefault(ALWAYS) val id: String = UUID.randomUUID().toString(),
    @EncodeDefault(ALWAYS) @SerialName("medication_id") val medicationId: String = "",
    @EncodeDefault(ALWAYS) @SerialName("health_profile_id") val healthProfileId: String = "",
    @EncodeDefault(ALWAYS) @SerialName("schedule_type") val scheduleType: String = "daily",
    @EncodeDefault(ALWAYS) @SerialName("time_of_day") val timeOfDay: String = "08:00:00",   // HH:mm:ss from DB
    @EncodeDefault(ALWAYS) @SerialName("frequency_per_day") val frequencyPerDay: Int = 1,
    @EncodeDefault(ALWAYS) @SerialName("dosage_amount") val dosageAmount: Double = 1.0,
    @EncodeDefault(ALWAYS) @SerialName("reminder_enabled") val reminderEnabled: Boolean = true,
    @EncodeDefault(ALWAYS) @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("days_of_week") val daysOfWeek: List<Int>? = null
)

/** Maps to `medication_logs` table */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class MedicationLogDto(
    @EncodeDefault(ALWAYS) val id: String = UUID.randomUUID().toString(),
    @EncodeDefault(ALWAYS) @SerialName("medication_id") val medicationId: String = "",
    @SerialName("schedule_id") val scheduleId: String? = null,
    @EncodeDefault(ALWAYS) @SerialName("health_profile_id") val healthProfileId: String = "",
    @SerialName("scheduled_time") val scheduledTime: String? = null,
    @SerialName("taken_time") val takenTime: String? = null,
    @EncodeDefault(ALWAYS) val status: String = "missed",
    @SerialName("skip_reason") val skipReason: String? = null,
    val notes: String? = null
)

// ─────────────────────────────────────
// MARK: - UI Domain Models
// ─────────────────────────────────────

/** Represents a single scheduled dose for display, with optional log info */
data class MedicationDose(
    val logId: String?,                     // null = pending (no DB log yet)
    val scheduleId: String,
    val medicationId: String,
    val medicationName: String,
    val dosage: String,
    val medicationType: MedicationType,
    val scheduledTime: LocalDateTime,
    val status: AdherenceStatus,
    val takenAt: LocalDateTime? = null,
    val skipReason: String? = null
) {
    val isOverdue: Boolean get() =
        status == AdherenceStatus.PENDING && scheduledTime.isBefore(LocalDateTime.now())

    val timePeriod: TimePeriod get() = when {
        TimePeriod.MORNING.contains(scheduledTime.hour) -> TimePeriod.MORNING
        TimePeriod.AFTERNOON.contains(scheduledTime.hour) -> TimePeriod.AFTERNOON
        TimePeriod.EVENING.contains(scheduledTime.hour) -> TimePeriod.EVENING
        else -> TimePeriod.NIGHT
    }
}

/** Full medication with today's doses and weekly stats */
data class MedicationWithDoses(
    val medication: MedicationDto,
    val schedules: List<MedicationScheduleDto>,
    val todayDoses: List<MedicationDose>
) {
    val takenCount: Int get() = todayDoses.count { it.status == AdherenceStatus.TAKEN }
    val totalDoses: Int get() = todayDoses.size
    val adherencePercentage: Float get() =
        if (totalDoses > 0) takenCount.toFloat() / totalDoses else 0f
    val hasOverdue: Boolean get() = todayDoses.any { it.isOverdue }
    val nextPending: MedicationDose? get() =
        todayDoses.firstOrNull { it.status == AdherenceStatus.PENDING }
    val type: MedicationType get() = MedicationType.fromDbForm(medication.form)
    val displayDosage: String get() =
        "${medication.dosage ?: ""} ${medication.dosageUnit ?: ""}".trim()
}

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
// MARK: - Helpers
// ─────────────────────────────────────

private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")
private val isoDateTimeFormatter = DateTimeFormatter.ISO_DATE_TIME

/** Build today's doses from a schedule — used when no log entry exists yet */
fun MedicationScheduleDto.buildDosesForDate(
    medication: MedicationDto,
    date: LocalDate,
    existingLogs: List<MedicationLogDto>
): List<MedicationDose> {
    val times = expandScheduleTimes(timeOfDay, frequencyPerDay)
    return times.map { timeStr ->
        val scheduledDt = parseScheduledDateTime(date, timeStr)
        val log = existingLogs.firstOrNull { log ->
            matchesScheduledTime(log.scheduledTime, scheduledDt)
        }
        MedicationDose(
            logId = log?.id,
            scheduleId = id,
            medicationId = medication.id,
            medicationName = medication.name,
            dosage = "${medication.dosage ?: ""} ${medication.dosageUnit ?: ""}".trim(),
            medicationType = MedicationType.fromDbForm(medication.form),
            scheduledTime = scheduledDt,
            status = if (log != null) AdherenceStatus.fromDb(log.status) else AdherenceStatus.PENDING,
            takenAt = log?.takenTime?.let { parseIsoDateTime(it) },
            skipReason = log?.skipReason
        )
    }
}

private fun expandScheduleTimes(baseTime: String, count: Int): List<String> {
    if (count <= 1) return listOf(baseTime)
    val base = LocalDateTime.of(LocalDate.now(), parseLocalTime(baseTime))
    val intervalHours = 24 / count
    return (0 until count).map { i ->
        base.plusHours((i * intervalHours).toLong())
            .format(DateTimeFormatter.ofPattern("HH:mm:ss"))
    }
}

private fun parseLocalTime(timeStr: String) =
    java.time.LocalTime.parse(timeStr.take(8).padEnd(8, '0'), timeFormatter)

private fun parseScheduledDateTime(date: LocalDate, timeStr: String): LocalDateTime =
    LocalDateTime.of(date, parseLocalTime(timeStr))

private fun matchesScheduledTime(isoStr: String?, target: LocalDateTime): Boolean {
    if (isoStr == null) return false
    return try {
        val parsed = LocalDateTime.parse(isoStr, isoDateTimeFormatter)
        // Match within 30-minute window to handle timezone offsets
        val diff = java.time.Duration.between(parsed, target).abs()
        diff.toMinutes() < 30
    } catch (e: Exception) { false }
}

private fun parseIsoDateTime(isoStr: String): LocalDateTime? = try {
    LocalDateTime.parse(isoStr, isoDateTimeFormatter)
} catch (e: Exception) { null }
