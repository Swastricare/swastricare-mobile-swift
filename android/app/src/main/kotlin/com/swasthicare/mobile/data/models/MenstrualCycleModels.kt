package com.swasthicare.mobile.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.UUID

// ------------------------------------
// MARK: - Enums
// ------------------------------------

enum class FlowLevel(val dbValue: String, val displayName: String, val emoji: String) {
    NONE("none", "None", ""),
    LIGHT("light", "Light", ""),
    MEDIUM("medium", "Medium", ""),
    HEAVY("heavy", "Heavy", ""),
    VERY_HEAVY("very_heavy", "Very Heavy", "");

    companion object {
        fun fromDb(value: String): FlowLevel =
            entries.firstOrNull { it.dbValue == value } ?: NONE
    }
}

enum class CyclePhase(val displayName: String, val emoji: String, val description: String) {
    MENSTRUAL("Menstrual", "🩸", "Your period phase. Rest and take care of yourself."),
    FOLLICULAR("Follicular", "🌱", "Your body is preparing for ovulation. Energy levels are rising."),
    OVULATION("Ovulation", "🌸", "Peak fertility window. You may feel more energetic and social."),
    LUTEAL("Luteal", "🍂", "Post-ovulation phase. You may experience PMS symptoms."),
    UNKNOWN("Unknown", "❓", "Log your period to get phase predictions.");

    companion object {
        fun fromDb(value: String): CyclePhase =
            entries.firstOrNull { it.name.lowercase() == value.lowercase() } ?: UNKNOWN
    }
}

enum class MenstrualSymptom(val dbValue: String, val displayName: String, val emoji: String) {
    CRAMPS("cramps", "Cramps", "😣"),
    BLOATING("bloating", "Bloating", "🫄"),
    FATIGUE("fatigue", "Fatigue", "😴"),
    MOOD_SWINGS("mood_swings", "Mood Swings", "🎭"),
    HEADACHE("headache", "Headache", "🤕"),
    BACKACHE("backache", "Backache", "🔙"),
    NAUSEA("nausea", "Nausea", "🤢"),
    ACNE("acne", "Acne", "😖"),
    INSOMNIA("insomnia", "Insomnia", "😵"),
    CRAVINGS("cravings", "Cravings", "🍫"),
    BREAST_TENDERNESS("breast_tenderness", "Breast Tenderness", "⚡"),
    SPOTTING("spotting", "Spotting", "🔴");

    companion object {
        fun fromDb(value: String): MenstrualSymptom =
            entries.firstOrNull { it.dbValue == value } ?: CRAMPS
    }
}

enum class MenstrualMood(val dbValue: String, val displayName: String, val emoji: String) {
    HAPPY("happy", "Happy", "😊"),
    CALM("calm", "Calm", "😌"),
    ENERGETIC("energetic", "Energetic", "⚡"),
    ANXIOUS("anxious", "Anxious", "😰"),
    SAD("sad", "Sad", "😢"),
    IRRITABLE("irritable", "Irritable", "😤"),
    TIRED("tired", "Tired", "😴"),
    NEUTRAL("neutral", "Neutral", "😐");

    companion object {
        fun fromDb(value: String): MenstrualMood =
            entries.firstOrNull { it.dbValue == value } ?: NEUTRAL
    }
}

// ------------------------------------
// MARK: - DB-mapped Serializable Models
// ------------------------------------

@Serializable
data class MenstrualCycleDto(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("health_profile_id") val healthProfileId: String = "",
    @SerialName("start_date") val startDate: String = "", // yyyy-MM-dd
    @SerialName("end_date") val endDate: String? = null,
    @SerialName("cycle_length") val cycleLength: Int? = null,
    @SerialName("period_length") val periodLength: Int? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class MenstrualDailyLogDto(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("cycle_id") val cycleId: String = "",
    @SerialName("health_profile_id") val healthProfileId: String = "",
    val date: String = "", // yyyy-MM-dd
    @SerialName("flow_level") val flowLevel: String = "none",
    val symptoms: String = "", // comma-separated
    val mood: String? = null,
    val notes: String? = null,
    @SerialName("pain_level") val painLevel: Int = 0,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class MenstrualSettingsDto(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("health_profile_id") val healthProfileId: String = "",
    @SerialName("average_cycle_length") val averageCycleLength: Int = 28,
    @SerialName("average_period_length") val averagePeriodLength: Int = 5,
    @SerialName("reminder_enabled") val reminderEnabled: Boolean = true,
    @SerialName("reminder_time") val reminderTime: String = "09:00:00"
) {
    /**
     * Returns a validated cycle length constrained to medical normal range (21-45 days).
     * Use this for predictions to prevent invalid calculations.
     */
    val validatedCycleLength: Int
        get() = averageCycleLength.coerceIn(21, 45)
}

// ------------------------------------
// MARK: - UI Domain Models
// ------------------------------------

data class MenstrualCycle(
    val id: String = UUID.randomUUID().toString(),
    val userId: String = "",
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val cycleLength: Int? = null,
    val periodLength: Int? = null,
    val notes: String? = null,
    val synced: Boolean = false
) {
    val isActive: Boolean get() = endDate == null

    val calculatedPeriodLength: Int? get() {
        return if (endDate != null) {
            ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1
        } else null
    }
}

data class MenstrualDailyLog(
    val id: String = UUID.randomUUID().toString(),
    val cycleId: String = "",
    val date: LocalDate,
    val flowLevel: FlowLevel = FlowLevel.NONE,
    val symptoms: List<MenstrualSymptom> = emptyList(),
    val mood: MenstrualMood? = null,
    val notes: String? = null,
    val painLevel: Int = 0, // 1-10
    val synced: Boolean = false
)

data class MenstrualSettings(
    val averageCycleLength: Int = 28,
    val averagePeriodLength: Int = 5,
    val reminderEnabled: Boolean = true,
    val reminderTime: String = "09:00"
) {
    /**
     * Returns a validated cycle length constrained to medical normal range (21-45 days).
     * Use this for predictions to prevent invalid calculations.
     */
    val validatedCycleLength: Int
        get() = averageCycleLength.coerceIn(21, 45)
}

data class CyclePrediction(
    val nextPeriodDate: LocalDate,
    val ovulationDate: LocalDate,
    val fertileWindowStart: LocalDate,
    val fertileWindowEnd: LocalDate
)

data class CycleStatistics(
    val averageCycleLength: Double = 0.0,
    val averagePeriodLength: Double = 0.0,
    val longestCycle: Int = 0,
    val shortestCycle: Int = 0,
    val totalCyclesTracked: Int = 0
)

data class CalendarDayData(
    val date: LocalDate,
    val phase: CyclePhase = CyclePhase.UNKNOWN,
    val isCurrentPeriod: Boolean = false,
    val isPredicted: Boolean = false,
    val flowLevel: FlowLevel? = null,
    val hasLog: Boolean = false
)

// ------------------------------------
// MARK: - Conversion helpers
// ------------------------------------

fun MenstrualCycle.toDto(profileId: String): MenstrualCycleDto = MenstrualCycleDto(
    id = id,
    healthProfileId = profileId,
    startDate = startDate.toString(),
    endDate = endDate?.toString(),
    cycleLength = cycleLength,
    periodLength = periodLength ?: calculatedPeriodLength,
    notes = notes
)

fun MenstrualCycleDto.toDomain(): MenstrualCycle = MenstrualCycle(
    id = id,
    userId = healthProfileId,
    startDate = LocalDate.parse(startDate),
    endDate = endDate?.let { LocalDate.parse(it) },
    cycleLength = cycleLength,
    periodLength = periodLength,
    notes = notes,
    synced = true
)

fun MenstrualDailyLog.toDto(profileId: String): MenstrualDailyLogDto = MenstrualDailyLogDto(
    id = id,
    cycleId = cycleId,
    healthProfileId = profileId,
    date = date.toString(),
    flowLevel = flowLevel.dbValue,
    symptoms = symptoms.joinToString(",") { it.dbValue },
    mood = mood?.dbValue,
    notes = notes,
    painLevel = painLevel
)

fun MenstrualDailyLogDto.toDomain(): MenstrualDailyLog = MenstrualDailyLog(
    id = id,
    cycleId = cycleId,
    date = LocalDate.parse(date),
    flowLevel = FlowLevel.fromDb(flowLevel),
    symptoms = if (symptoms.isBlank()) emptyList() else symptoms.split(",").map { MenstrualSymptom.fromDb(it.trim()) },
    mood = mood?.let { MenstrualMood.fromDb(it) },
    notes = notes,
    painLevel = painLevel,
    synced = true
)
