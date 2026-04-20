package com.swastricare.health.data.remote.dto.sleep

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for upserting sleep data into `daily_health_metrics`.
 */
@Serializable
data class DailyMetricsSleepDto(
    @SerialName("health_profile_id")
    val healthProfileId: String,

    @SerialName("metric_date")
    val metricDate: String, // YYYY-MM-DD

    @SerialName("sleep_hours")
    val sleepHours: Double? = null,

    @SerialName("sleep_quality")
    val sleepQuality: Int? = null, // 0-100

    @SerialName("bedtime")
    val bedtime: String? = null, // HH:mm

    @SerialName("wake_time")
    val wakeTime: String? = null // HH:mm
)
