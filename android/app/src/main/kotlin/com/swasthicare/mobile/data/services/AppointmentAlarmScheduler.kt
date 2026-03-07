package com.swasthicare.mobile.data.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.time.ZonedDateTime

class AppointmentAlarmScheduler(private val context: Context) {

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
        val apptTime = try { ZonedDateTime.parse(appt.scheduledAtIso) } catch (e: Exception) {
            Log.w(TAG, "Invalid appointment time: ${appt.scheduledAtIso}")
            return
        }
        val now = ZonedDateTime.now()
        val dayBefore = apptTime.minusHours(24)
        val hourBefore = apptTime.minusHours(1)
        if (dayBefore.isAfter(now)) setAlarm(appt, dayBefore.toInstant().toEpochMilli(), true)
        if (hourBefore.isAfter(now)) setAlarm(appt, hourBefore.toInstant().toEpochMilli(), false)
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
