package com.swastricare.health.data.services

import android.content.Context
import com.swastricare.health.data.workers.CycleAINudgeWorker
import android.util.Log
import com.swastricare.health.di.AppContainer
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.util.Calendar

class CycleNotificationScheduler(private val context: Context) {

    companion object {
        private const val TAG = "CycleScheduler"
    }

    fun scheduleFromPredictions(
        predictedPeriodStart: LocalDate?,
        predictedOvulation: LocalDate?
    ) {
        val notifService = AppContainer.notificationService
        if (!notifService.cycleEnabled) return

        predictedPeriodStart?.let { date ->
            val reminderDate = date.minusDays(2)
            if (!reminderDate.isBefore(LocalDate.now())) {
                scheduleCycleAlarm(notifService, "period", reminderDate, 9,
                    "Period Coming Soon", "Your period is expected in 2 days. Be prepared!")
            }
        }

        predictedOvulation?.let { date ->
            if (!date.isBefore(LocalDate.now())) {
                scheduleCycleAlarm(notifService, "ovulation", date, 9,
                    "Ovulation Day", "Today is your predicted ovulation day. Log your symptoms!")
            }
        }

        // Enqueue daily AI-generated phase tip
        CycleAINudgeWorker.enqueue(context)

        Log.d(TAG, "Cycle notifications scheduled")
    }

    private fun scheduleCycleAlarm(
        notifService: NotificationService,
        type: String,
        triggerDate: LocalDate,
        triggerHour: Int,
        title: String,
        body: String
    ) {
        val triggerMs = LocalDateTime.of(triggerDate, LocalTime.of(triggerHour, 0))
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val cal = Calendar.getInstance().apply { timeInMillis = triggerMs }
        notifService.scheduleCycleReminder(type, cal, title, body)
    }
}
