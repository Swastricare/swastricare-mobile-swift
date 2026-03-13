package com.swastricare.health.data.remote.dto.medication

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.EncodeDefault.Mode.ALWAYS
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Data Transfer Object for Medication.
 * Maps to the `medications` table in Supabase.
 */
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

/**
 * Data Transfer Object for Medication Schedule.
 * Maps to the `medication_schedules` table in Supabase.
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class MedicationScheduleDto(
    @EncodeDefault(ALWAYS) val id: String = UUID.randomUUID().toString(),
    @EncodeDefault(ALWAYS) @SerialName("medication_id") val medicationId: String = "",
    @EncodeDefault(ALWAYS) @SerialName("health_profile_id") val healthProfileId: String = "",
    @EncodeDefault(ALWAYS) @SerialName("schedule_type") val scheduleType: String = "daily",
    @EncodeDefault(ALWAYS) @SerialName("time_of_day") val timeOfDay: String = "08:00:00",
    @EncodeDefault(ALWAYS) @SerialName("frequency_per_day") val frequencyPerDay: Int = 1,
    @EncodeDefault(ALWAYS) @SerialName("dosage_amount") val dosageAmount: Double = 1.0,
    @EncodeDefault(ALWAYS) @SerialName("reminder_enabled") val reminderEnabled: Boolean = true,
    @EncodeDefault(ALWAYS) @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("days_of_week") val daysOfWeek: List<Int>? = null
) {
    init {
        require(dosageAmount > 0) { "Dosage must be positive" }
    }
}

/**
 * Data Transfer Object for Medication Log.
 * Maps to the `medication_logs` table in Supabase.
 */
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
