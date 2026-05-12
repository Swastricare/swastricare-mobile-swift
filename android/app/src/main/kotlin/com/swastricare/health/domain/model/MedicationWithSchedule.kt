package com.swastricare.health.domain.model

/**
 * Read-write summary row used by the Family Member Reminders screen
 * (Android Batch J). Joins one `medication_schedules` row with its parent
 * `medications` row so the screen can render the medication name alongside
 * its schedule controls.
 *
 * @property scheduleType One of `daily`, `weekly`, `monthly`, `as_needed`,
 *                        `custom`. Only `daily` is editable in v1.
 * @property timeOfDay `HH:mm:ss` (Postgres TIME). Display as `HH:mm`.
 */
data class MedicationWithSchedule(
    val medicationId: String,
    val medicationName: String,
    val scheduleId: String,
    val scheduleType: String,
    val timeOfDay: String,
    val frequencyPerDay: Int,
    val reminderEnabled: Boolean,
    val isActive: Boolean,
)
