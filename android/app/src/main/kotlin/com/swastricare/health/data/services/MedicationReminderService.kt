package com.swastricare.health.data.services

import android.content.Context
import com.swastricare.health.notifications.MedicationReminderScheduler
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Injectable wrapper for MedicationReminderScheduler.
 * Provides Hilt-compatible interface for medication reminder scheduling.
 */
@Singleton
class MedicationReminderService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /**
     * Schedules a medication reminder.
     *
     * @param scheduleId The schedule ID
     * @param medicationName The medication name
     * @param dosage The medication dosage
     * @param timeHour The hour of the day (0-23)
     * @param timeMinute The minute of the hour (0-59)
     */
    fun schedule(
        scheduleId: String,
        medicationName: String,
        dosage: String,
        timeHour: Int,
        timeMinute: Int
    ) {
        // Use a derived medication ID for backwards compatibility
        // In the future, we should store the medication ID in the schedule
        val medId = scheduleId.substringBefore("_")

        MedicationReminderScheduler.schedule(
            context = context,
            medId = medId,
            scheduleId = scheduleId,
            medName = medicationName,
            timeHour = timeHour,
            timeMinute = timeMinute
        )
    }

    /**
     * Cancels a medication reminder.
     *
     * @param scheduleId The schedule ID
     */
    fun cancel(scheduleId: String) {
        MedicationReminderScheduler.cancel(context, scheduleId)
    }
}
