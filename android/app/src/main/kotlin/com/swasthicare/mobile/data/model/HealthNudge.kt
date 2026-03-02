package com.swasthicare.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class NudgeType(val displayName: String) {
    @SerialName("hydration")
    HYDRATION("Hydration"),

    @SerialName("inactivity")
    INACTIVITY("Inactivity"),

    @SerialName("medication_missed")
    MEDICATION_MISSED("Medication Missed"),

    @SerialName("sleep_deficit")
    SLEEP_DEFICIT("Sleep Deficit"),

    @SerialName("step_goal_close")
    STEP_GOAL_CLOSE("Step Goal Close"),

    @SerialName("heart_rate_elevated")
    HEART_RATE_ELEVATED("Heart Rate Elevated"),

    @SerialName("streak_at_risk")
    STREAK_AT_RISK("Streak at Risk"),

    @SerialName("weekly_insight")
    WEEKLY_INSIGHT("Weekly Insight")
}

@Serializable
enum class NudgePriority {
    @SerialName("low")
    LOW,

    @SerialName("medium")
    MEDIUM,

    @SerialName("high")
    HIGH
}

@Serializable
data class HealthNudge(
    val id: String,

    @SerialName("health_profile_id")
    val healthProfileId: String,

    val type: NudgeType,

    val title: String,

    val message: String,

    val priority: NudgePriority = NudgePriority.LOW,

    @SerialName("action_url")
    val actionUrl: String? = null,

    val dismissed: Boolean = false,

    @SerialName("acted_on")
    val actedOn: Boolean = false,

    @SerialName("created_at")
    val createdAt: String? = null
)
