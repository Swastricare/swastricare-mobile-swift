package com.swastricare.health.data.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AppointmentAlarmScheduler @Inject constructor(
    @ApplicationContext private val context: Context
) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    companion object {
        private const val TAG = "ApptAlarmScheduler"
        const val ACTION_APPOINTMENT_REMINDER = "APPOINTMENT_REMINDER"
        const val EXTRA_APPOINTMENT_ID = "appointment_id"
        const val EXTRA_DOCTOR_NAME = "doctor_name"
        const val EXTRA_LOCATION = "location"
        const val EXTRA_IS_DAY_BEFORE = "is_day_before"
        private const val APPT_DAY_BASE = 5000
        private const val APPT_HOUR_BASE = 5500
    }

    data class AppointmentInfo(
        val id: String,
        val scheduledAtIso: String,
        val doctorName: String,
        val location: String = ""
    )

    fun scheduleAll(appointments: List<AppointmentInfo>) {
        appointments.forEach { schedule(it) }
        Log.d(TAG, "Scheduled reminders for ${appointments.size} appointments")
    }

    fun schedule(appt: AppointmentInfo) {
        val apptTime = parseAppointmentTime(appt.scheduledAtIso) ?: run {
            Log.w(TAG, "Invalid appointment time: ${appt.scheduledAtIso}")
            return
        }
        // Cancel any previously-scheduled alarms for this appointment before (re)scheduling
        cancel(appt.id)
        val now = ZonedDateTime.now()
        val dayBefore = apptTime.minusHours(24)
        val hourBefore = apptTime.minusHours(1)
        var scheduled = 0
        if (dayBefore.isAfter(now)) {
            setAlarm(appt, dayBefore.toInstant().toEpochMilli(), true)
            scheduled++
        }
        if (hourBefore.isAfter(now)) {
            setAlarm(appt, hourBefore.toInstant().toEpochMilli(), false)
            scheduled++
        }
        Log.d(TAG, "Scheduled $scheduled reminder(s) for appt ${appt.id} at $apptTime")
    }

    /**
     * Parses the scheduled-at string. Accepts:
     *  - Full ISO 8601 with zone: "2025-04-15T09:00:00+05:30"
     *  - Local date-time: "2025-04-15T09:00:00" (assumes system default zone)
     *  - Date-only: "2025-04-15" (defaults to 09:00 in system default zone)
     */
    private fun parseAppointmentTime(iso: String): ZonedDateTime? {
        if (iso.isBlank()) return null
        // Try full zoned ISO first
        try {
            return ZonedDateTime.parse(iso)
        } catch (_: Exception) {
        }
        // Try local date-time (no zone) -> system default zone
        try {
            return java.time.LocalDateTime.parse(iso).atZone(ZoneId.systemDefault())
        } catch (_: Exception) {
        }
        // Try date-only -> default to 09:00 system default zone
        try {
            return LocalDate.parse(iso).atTime(LocalTime.of(9, 0)).atZone(ZoneId.systemDefault())
        } catch (_: Exception) {
        }
        return null
    }

    fun cancel(appointmentId: String) {
        cancelAlarm(appointmentId, true)
        cancelAlarm(appointmentId, false)
    }

    private fun setAlarm(appt: AppointmentInfo, triggerMs: Long, isDayBefore: Boolean) {
        val requestCode = (if (isDayBefore) APPT_DAY_BASE else APPT_HOUR_BASE) + (appt.id.hashCode() and 0x7FFFFFFF)
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_APPOINTMENT_REMINDER
            putExtra(EXTRA_APPOINTMENT_ID, appt.id)
            putExtra(EXTRA_DOCTOR_NAME, appt.doctorName)
            putExtra(EXTRA_LOCATION, appt.location)
            putExtra(EXTRA_IS_DAY_BEFORE, isDayBefore)
        }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        }
    }

    private fun cancelAlarm(appointmentId: String, isDayBefore: Boolean) {
        val requestCode = (if (isDayBefore) APPT_DAY_BASE else APPT_HOUR_BASE) + (appointmentId.hashCode() and 0x7FFFFFFF)
        val intent = Intent(context, NotificationReceiver::class.java).apply { action = ACTION_APPOINTMENT_REMINDER }
        val pi = PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.cancel(pi)
    }
}
