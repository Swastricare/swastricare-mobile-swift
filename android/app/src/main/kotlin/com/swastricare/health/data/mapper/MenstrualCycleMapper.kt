package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualCycleDto
import com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualDailyLogDto
import com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualSettingsDto
import com.swastricare.health.domain.model.menstrualcycle.CycleRecord
import com.swastricare.health.domain.model.menstrualcycle.CycleSettings
import com.swastricare.health.domain.model.menstrualcycle.DailyLog
import com.swastricare.health.domain.model.menstrualcycle.FlowLevel
import com.swastricare.health.domain.model.menstrualcycle.Mood
import com.swastricare.health.domain.model.menstrualcycle.Symptom
import java.time.LocalDate
import java.util.UUID

/**
 * Mapper functions for converting between DTOs and domain models.
 */

// ── Cycle Record Mappers ──

fun MenstrualCycleDto.toDomain(): CycleRecord = CycleRecord(
    id = id,
    userId = healthProfileId,
    startDate = LocalDate.parse(startDate),
    endDate = endDate?.let { LocalDate.parse(it) },
    cycleLength = cycleLength,
    periodLength = periodLength,
    notes = notes,
    isPredicted = isPredicted
)

fun CycleRecord.toDto(healthProfileId: String): MenstrualCycleDto = MenstrualCycleDto(
    id = id,
    healthProfileId = healthProfileId,
    startDate = startDate.toString(),
    endDate = endDate?.toString(),
    cycleLength = cycleLength,
    periodLength = effectivePeriodLength,
    isPredicted = isPredicted,
    notes = notes
)

// ── Daily Log Mappers ──

fun MenstrualDailyLogDto.toDomain(): DailyLog = DailyLog(
    id = id,
    cycleId = cycleId,
    date = LocalDate.parse(date),
    flowLevel = flowLevel.toFlowLevel(),
    symptoms = symptoms.toSymptomList(),
    mood = mood?.toMood(),
    notes = notes,
    painLevel = painLevel,
    energyLevel = energyLevel,
    sleepQuality = sleepQuality,
    temperature = temperature,
    weight = weight,
    cervicalMucus = cervicalMucus,
    sexualActivity = sexualActivity,
    protectedSex = protectedSex
)

fun DailyLog.toDto(healthProfileId: String): MenstrualDailyLogDto = MenstrualDailyLogDto(
    id = id,
    cycleId = cycleId,
    healthProfileId = healthProfileId,
    date = date.toString(),
    flowLevel = flowLevel.toDbValue(),
    symptoms = symptoms.toDbValue(),
    mood = mood?.toDbValue(),
    notes = notes,
    painLevel = painLevel,
    energyLevel = energyLevel,
    sleepQuality = sleepQuality,
    temperature = temperature,
    weight = weight,
    cervicalMucus = cervicalMucus,
    sexualActivity = sexualActivity,
    protectedSex = protectedSex
)

// ── Settings Mappers ──

fun MenstrualSettingsDto.toDomain(): CycleSettings = CycleSettings(
    averageCycleLength = averageCycleLength,
    averagePeriodLength = averagePeriodLength,
    reminderEnabled = reminderEnabled,
    reminderTime = reminderTime.take(5), // Extract HH:mm from HH:mm:ss
    reminderDaysBefore = reminderDaysBefore,
    fertileReminderEnabled = fertileReminderEnabled,
    pmsReminderEnabled = pmsReminderEnabled,
    ovulationReminderEnabled = ovulationReminderEnabled,
    lutealPhaseLength = lutealPhaseLength
)

fun CycleSettings.toDto(healthProfileId: String): MenstrualSettingsDto = MenstrualSettingsDto(
    id = UUID.randomUUID().toString(),
    healthProfileId = healthProfileId,
    averageCycleLength = averageCycleLength,
    averagePeriodLength = averagePeriodLength,
    reminderEnabled = reminderEnabled,
    reminderTime = if (reminderTime.length == 5) "$reminderTime:00" else reminderTime,
    reminderDaysBefore = reminderDaysBefore,
    fertileReminderEnabled = fertileReminderEnabled,
    pmsReminderEnabled = pmsReminderEnabled,
    ovulationReminderEnabled = ovulationReminderEnabled,
    lutealPhaseLength = lutealPhaseLength
)

// ── Enum Conversion Helpers ──

private fun String.toFlowLevel(): FlowLevel = when (this.lowercase()) {
    "none" -> FlowLevel.NONE
    "light" -> FlowLevel.LIGHT
    "medium" -> FlowLevel.MEDIUM
    "heavy" -> FlowLevel.HEAVY
    "very_heavy" -> FlowLevel.VERY_HEAVY
    else -> FlowLevel.NONE
}

private fun FlowLevel.toDbValue(): String = when (this) {
    FlowLevel.NONE -> "none"
    FlowLevel.LIGHT -> "light"
    FlowLevel.MEDIUM -> "medium"
    FlowLevel.HEAVY -> "heavy"
    FlowLevel.VERY_HEAVY -> "very_heavy"
}

private fun String.toSymptomList(): List<Symptom> {
    if (this.isBlank()) return emptyList()
    return this.split(",")
        .map { it.trim() }
        .mapNotNull { it.toSymptomOrNull() }
}

private fun String.toSymptomOrNull(): Symptom? = when (this.lowercase()) {
    "cramps" -> Symptom.CRAMPS
    "bloating" -> Symptom.BLOATING
    "fatigue" -> Symptom.FATIGUE
    "mood_swings" -> Symptom.MOOD_SWINGS
    "headache" -> Symptom.HEADACHE
    "backache" -> Symptom.BACKACHE
    "nausea" -> Symptom.NAUSEA
    "acne" -> Symptom.ACNE
    "insomnia" -> Symptom.INSOMNIA
    "cravings" -> Symptom.CRAVINGS
    "breast_tenderness" -> Symptom.BREAST_TENDERNESS
    "spotting" -> Symptom.SPOTTING
    "anxiety" -> Symptom.ANXIETY
    "irritability" -> Symptom.IRRITABILITY
    else -> null
}

private fun List<Symptom>.toDbValue(): String = joinToString(",") { it.toDbValue() }

private fun Symptom.toDbValue(): String = when (this) {
    Symptom.CRAMPS -> "cramps"
    Symptom.BLOATING -> "bloating"
    Symptom.FATIGUE -> "fatigue"
    Symptom.MOOD_SWINGS -> "mood_swings"
    Symptom.HEADACHE -> "headache"
    Symptom.BACKACHE -> "backache"
    Symptom.NAUSEA -> "nausea"
    Symptom.ACNE -> "acne"
    Symptom.INSOMNIA -> "insomnia"
    Symptom.CRAVINGS -> "cravings"
    Symptom.BREAST_TENDERNESS -> "breast_tenderness"
    Symptom.SPOTTING -> "spotting"
    Symptom.ANXIETY -> "anxiety"
    Symptom.IRRITABILITY -> "irritability"
}

private fun String.toMood(): Mood? = when (this.lowercase()) {
    "happy" -> Mood.HAPPY
    "calm" -> Mood.CALM
    "energetic" -> Mood.ENERGETIC
    "anxious" -> Mood.ANXIOUS
    "sad" -> Mood.SAD
    "irritable" -> Mood.IRRITABLE
    "tired" -> Mood.TIRED
    "neutral" -> Mood.NEUTRAL
    else -> null
}

private fun Mood.toDbValue(): String = when (this) {
    Mood.HAPPY -> "happy"
    Mood.CALM -> "calm"
    Mood.ENERGETIC -> "energetic"
    Mood.ANXIOUS -> "anxious"
    Mood.SAD -> "sad"
    Mood.IRRITABLE -> "irritable"
    Mood.TIRED -> "tired"
    Mood.NEUTRAL -> "neutral"
}
