package com.swastricare.health.data.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.swastricare.health.data.models.MedicationDto
import com.swastricare.health.data.models.MedicationScheduleDto
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

class MedicationAlarmScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    companion object {
        private const val TAG = "MedAlarmScheduler"
        const val ACTION_MEDICATION_REMINDER = "MEDICATION_REMINDER"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_MEDICATION_ID = "medication_id"
        const val EXTRA_MEDICATION_NAME = "medication_name"
        const val EXTRA_DOSAGE = "dosage"
        private const val MED_ALARM_REQUEST_BASE = 10000
    }

    fun scheduleAll(schedules: List<MedicationScheduleDto>, medications: List<MedicationDto>) {
        val medMap = medications.associateBy { it.id }
        schedules.filter { it.isActive && it.reminderEnabled }.forEach { schedule ->
            val med = medMap[schedule.medicationId] ?: return@forEach
            scheduleNext(schedule, med.name, med.dosage ?: "")
        }
        Log.d(TAG, "Scheduled ${schedules.size} medication alarms")
    }

    fun scheduleNext(schedule: MedicationScheduleDto, medName: String, dosage: String) {
        val requestCode = MED_ALARM_REQUEST_BASE + (schedule.id.hashCode() and 0x7FFFFFFF)
        val triggerMs = nextTriggerMs(schedule) ?: return

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_MEDICATION_REMINDER
            putExtra(EXTRA_SCHEDULE_ID, schedule.id)
            putExtra(EXTRA_MEDICATION_ID, schedule.medicationId)
            putExtra(EXTRA_MEDICATION_NAME, medName)
            putExtra(EXTRA_DOSAGE, dosage)
        }

        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            Log.d(TAG, "Medication alarm set for $medName at ${java.util.Date(triggerMs)}")
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        }
    }

    fun cancel(scheduleId: String) {
        val requestCode = MED_ALARM_REQUEST_BASE + (scheduleId.hashCode() and 0x7FFFFFFF)
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_MEDICATION_REMINDER
        }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
    }

    fun cancelAll(schedules: List<MedicationScheduleDto>) {
        schedules.forEach { cancel(it.id) }
    }

    private fun nextTriggerMs(schedule: MedicationScheduleDto): Long? {
        val now = LocalDateTime.now()
        val timeStr = schedule.timeOfDay.take(5) // "HH:mm"
        val timeOfDay = try { LocalTime.parse(timeStr) } catch (e: Exception) {
            Log.w(TAG, "Invalid timeOfDay for schedule ${schedule.id}: ${schedule.timeOfDay}")
            return null
        }

        var candidate = LocalDateTime.of(LocalDate.now(), timeOfDay)
        if (!candidate.isAfter(now)) candidate = candidate.plusDays(1)

        if (schedule.scheduleType == "weekly" && !schedule.daysOfWeek.isNullOrEmpty()) {
            for (i in 0..6) {
                val dow = candidate.dayOfWeek.value % 7
                if (schedule.daysOfWeek.contains(dow)) break
                candidate = candidate.plusDays(1)
            }
        }

        return candidate.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    }
}
