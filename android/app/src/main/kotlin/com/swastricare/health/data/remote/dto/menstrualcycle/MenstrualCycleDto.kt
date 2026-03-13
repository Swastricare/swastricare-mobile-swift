package com.swastricare.health.data.remote.dto.menstrualcycle

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for menstrual cycle data from Supabase.
 * Maps to the menstrual_cycles table.
 */
@Serializable
data class MenstrualCycleDto(
    val id: String,
    @SerialName("health_profile_id")
    val healthProfileId: String,
    @SerialName("start_date")
    val startDate: String, // yyyy-MM-dd
    @SerialName("end_date")
    val endDate: String? = null, // yyyy-MM-dd
    @SerialName("cycle_length")
    val cycleLength: Int? = null,
    @SerialName("period_length")
    val periodLength: Int? = null,
    val notes: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)

/**
 * DTO for daily menstrual logs from Supabase.
 * Maps to the menstrual_daily_logs table.
 */
@Serializable
data class MenstrualDailyLogDto(
    val id: String,
    @SerialName("cycle_id")
    val cycleId: String,
    @SerialName("health_profile_id")
    val healthProfileId: String,
    val date: String, // yyyy-MM-dd
    @SerialName("flow_level")
    val flowLevel: String,
    val symptoms: String, // comma-separated
    val mood: String? = null,
    val notes: String? = null,
    @SerialName("pain_level")
    val painLevel: Int = 0,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)

/**
 * DTO for menstrual cycle settings from Supabase.
 * Maps to the menstrual_settings table.
 */
@Serializable
data class MenstrualSettingsDto(
    val id: String,
    @SerialName("health_profile_id")
    val healthProfileId: String,
    @SerialName("average_cycle_length")
    val averageCycleLength: Int = 28,
    @SerialName("average_period_length")
    val averagePeriodLength: Int = 5,
    @SerialName("reminder_enabled")
    val reminderEnabled: Boolean = true,
    @SerialName("reminder_time")
    val reminderTime: String = "09:00:00",
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)
