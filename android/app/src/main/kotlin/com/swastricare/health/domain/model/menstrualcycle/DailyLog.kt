package com.swastricare.health.domain.model.menstrualcycle

import java.time.LocalDate

/**
 * Domain model for daily menstrual cycle logging.
 * Captures flow level, symptoms, mood, pain, and optional extended
 * wellness signals (energy, sleep, temperature, weight, cervical
 * mucus, sexual activity) for a specific day.
 */
data class DailyLog(
    val id: String,
    val cycleId: String,
    val date: LocalDate,
    val flowLevel: FlowLevel,
    val symptoms: List<Symptom>,
    val mood: Mood?,
    val notes: String?,
    val painLevel: Int, // 0-10 scale
    val energyLevel: Int? = null,
    val sleepQuality: String? = null,
    val temperature: Double? = null,
    val weight: Double? = null,
    val cervicalMucus: String? = null,
    val sexualActivity: Boolean? = null,
    val protectedSex: Boolean? = null
) {
    fun isValidPainLevel(): Boolean = painLevel in 0..10

    val isMenstruationDay: Boolean
        get() = flowLevel != FlowLevel.NONE
}
