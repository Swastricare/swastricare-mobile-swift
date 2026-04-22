package com.swastricare.health.data.services

import android.content.Context
import com.swastricare.health.data.workers.CycleAINudgeWorker
import android.util.Log
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.util.Calendar

class CycleNotificationScheduler @javax.inject.Inject constructor(
    private val context: Context,
    private val notificationService: NotificationService
) {

    companion object {
        private const val TAG = "CycleScheduler"
    }

    fun scheduleFromPredictions(
        predictedPeriodStart: LocalDate?,
        predictedOvulation: LocalDate?,
        reminderDaysBefore: Int = 2,
        ovulationReminderEnabled: Boolean = true
    ) {
        if (!notificationService.cycleEnabled) return

        val days = reminderDaysBefore.coerceIn(1, 7)

        predictedPeriodStart?.let { date ->
            val reminderDate = date.minusDays(days.toLong())
            if (!reminderDate.isBefore(LocalDate.now())) {
                val label = if (days == 1) "day" else "days"
                scheduleCycleAlarm(
                    "period", reminderDate, 9,
                    "Period Coming Soon",
                    "Your period is expected in $days $label. Be prepared!"
                )
            }
        }

        if (ovulationReminderEnabled) {
            predictedOvulation?.let { date ->
                if (!date.isBefore(LocalDate.now())) {
                    scheduleCycleAlarm(
                        "ovulation", date, 9,
                        "Ovulation Day",
                        "Today is your predicted ovulation day. Log your symptoms!"
                    )
                }
            }
        }

        CycleAINudgeWorker.enqueue(context)

        Log.d(TAG, "Cycle notifications scheduled (reminderDaysBefore=$days, ovulation=$ovulationReminderEnabled)")
    }

    private fun scheduleCycleAlarm(
        type: String,
        triggerDate: LocalDate,
        triggerHour: Int,
        title: String,
        body: String
    ) {
        val triggerMs = LocalDateTime.of(triggerDate, LocalTime.of(triggerHour, 0))
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val cal = Calendar.getInstance().apply { timeInMillis = triggerMs }
        notificationService.scheduleCycleReminder(type, cal, title, body)
    }
}
