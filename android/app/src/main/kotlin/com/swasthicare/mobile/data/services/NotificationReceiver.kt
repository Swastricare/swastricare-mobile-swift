package com.swasthicare.mobile.data.services

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.swasthicare.mobile.MainActivity
import com.swasthicare.mobile.data.models.HydrationEntry
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDateTime

class NotificationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NotificationReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        AppContainer.initialize(context)
        val prefs = AppContainer.sharedPreferences
        val notificationService = NotificationService(context, prefs)

        when (intent.action) {

            "HYDRATION_REMINDER" -> {
                Log.d(TAG, "Hydration reminder triggered")
                val logWaterIntent = Intent(context, NotificationReceiver::class.java).apply {
                    action = NotificationService.ACTION_LOG_WATER
                    putExtra("amount_ml", 250)
                }
                val logWaterPI = PendingIntent.getBroadcast(
                    context, 5001, logWaterIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val tapPI = buildTapIntent(context, "swastricare://hydration", 5010)

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_HYDRATION,
                    notificationId = NotificationService.NOTIF_HYDRATION_BASE,
                    title = "Stay Hydrated!",
                    body = "Time to drink some water. Tap to log 250ml.",
                    actionLabel = "Log 250ml",
                    actionIntent = logWaterPI,
                    contentIntent = tapPI
                )
                notificationService.scheduleHydrationReminders()
            }

            "DIET_REMINDER" -> {
                val notifId = intent.getIntExtra("notif_id", 0)
                val title = intent.getStringExtra("title") ?: "Meal Reminder"
                val body = intent.getStringExtra("body") ?: "Time to log your meal"

                val logMealIntent = Intent(context, NotificationReceiver::class.java).apply {
                    action = NotificationService.ACTION_LOG_MEAL
                }
                val logMealPI = PendingIntent.getBroadcast(
                    context, 5002, logMealIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val tapPI = buildTapIntent(context, "swastricare://diet", 5011)

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_DIET,
                    notificationId = notifId,
                    title = title,
                    body = body,
                    actionLabel = "Log Meal",
                    actionIntent = logMealPI,
                    contentIntent = tapPI
                )
                notificationService.scheduleDietReminders()
            }

            "CYCLE_REMINDER" -> {
                val notifId = intent.getIntExtra("notif_id", 0)
                val title = intent.getStringExtra("title") ?: "Cycle Reminder"
                val body = intent.getStringExtra("body") ?: "Cycle tracking reminder"
                val tapPI = buildTapIntent(context, "swastricare://cycle", notifId + 100)

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_CYCLE,
                    notificationId = notifId,
                    title = title,
                    body = body,
                    contentIntent = tapPI
                )
            }

            MedicationAlarmScheduler.ACTION_MEDICATION_REMINDER -> {
                val scheduleId = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_SCHEDULE_ID) ?: return
                val medicationId = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_MEDICATION_ID) ?: ""
                val medName = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_MEDICATION_NAME) ?: "Medication"
                val dosage = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_DOSAGE) ?: ""
                Log.d(TAG, "Medication reminder: $medName")

                val markTakenIntent = Intent(context, NotificationReceiver::class.java).apply {
                    action = NotificationService.ACTION_MARK_MED_TAKEN
                    putExtra("medication_id", medicationId)
                    putExtra("schedule_id", scheduleId)
                }
                val markTakenPI = PendingIntent.getBroadcast(
                    context, (scheduleId.hashCode() and 0x7FFFFFFF),
                    markTakenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val tapPI = buildTapIntent(context, "swastricare://medications", (scheduleId.hashCode() and 0x7FFFFFFF) + 1)

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_MEDICATION,
                    notificationId = NotificationService.NOTIF_HYDRATION_BASE + (scheduleId.hashCode() and 0x7FFFFFFF),
                    title = "Time for $medName",
                    body = if (dosage.isNotBlank()) "Take $dosage now" else "It's time to take your medication",
                    actionLabel = "Mark Taken",
                    actionIntent = markTakenPI,
                    contentIntent = tapPI
                )
            }

            AppointmentAlarmScheduler.ACTION_APPOINTMENT_REMINDER -> {
                val apptId = intent.getStringExtra(AppointmentAlarmScheduler.EXTRA_APPOINTMENT_ID) ?: return
                val doctorName = intent.getStringExtra(AppointmentAlarmScheduler.EXTRA_DOCTOR_NAME) ?: "Doctor"
                val location = intent.getStringExtra(AppointmentAlarmScheduler.EXTRA_LOCATION) ?: ""
                val isDayBefore = intent.getBooleanExtra(AppointmentAlarmScheduler.EXTRA_IS_DAY_BEFORE, false)

                val tapPI = buildTapIntent(context, "swastricare://vault", apptId.hashCode() and 0x7FFFFFFF)
                val title = if (isDayBefore) "Appointment Tomorrow" else "Appointment in 1 Hour"
                val body = buildString {
                    append("Dr. $doctorName")
                    if (location.isNotBlank()) append(" \u2022 $location")
                }
                val notifId = (if (isDayBefore) NotificationService.NOTIF_APPOINTMENT_DAY_BASE
                               else NotificationService.NOTIF_APPOINTMENT_HOUR_BASE) + (apptId.hashCode() and 0x7FFFFFFF)

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_APPOINTMENT,
                    notificationId = notifId,
                    title = title,
                    body = body,
                    contentIntent = tapPI
                )
            }

            NotificationService.ACTION_LOG_WATER -> {
                val amountMl = intent.getIntExtra("amount_ml", 250)
                Log.d(TAG, "Quick action: log $amountMl ml water")
                try {
                    val entriesJson = prefs.getString("hydration_entries", "[]") ?: "[]"
                    val existing: List<HydrationEntry> = try {
                        Json.decodeFromString(entriesJson)
                    } catch (_: Exception) { emptyList() }

                    val newEntry = HydrationEntry(
                        id = "notif_${System.currentTimeMillis()}",
                        drinkType = "water",
                        amountMl = amountMl,
                        effectiveMl = amountMl,
                        consumedAt = LocalDateTime.now().toString(),
                        synced = false
                    )
                    val updated = existing + newEntry
                    prefs.edit().putString("hydration_entries", Json.encodeToString(updated)).apply()
                    Log.d(TAG, "Logged $amountMl ml via quick action")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to log water: ${e.message}")
                }
            }

            NotificationService.ACTION_MARK_MED_TAKEN -> {
                val medicationId = intent.getStringExtra("medication_id") ?: return
                val scheduleId = intent.getStringExtra("schedule_id") ?: return
                Log.d(TAG, "Quick action: mark medication $medicationId taken")
                val profileId = prefs.getString("current_profile_id", "") ?: ""
                val pendingResult = goAsync()
                CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                    try {
                        AppContainer.medicationRepository.markAsTaken(
                            medicationId = medicationId,
                            scheduleId = scheduleId,
                            profileId = profileId,
                            scheduledTime = LocalDateTime.now(),
                            logId = null
                        )
                        Log.d(TAG, "Medication $medicationId marked as taken")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to mark med taken: ${e.message}")
                    } finally {
                        pendingResult.finish()
                    }
                }
            }

            NotificationService.ACTION_LOG_MEAL -> {
                Log.d(TAG, "Quick action: log meal — opening app")
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("swastricare://diet")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                context.startActivity(openIntent)
            }

            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "Device boot/time changed: re-scheduling notifications")
                notificationService.scheduleAllNotifications()
            }
        }
    }

    private fun buildTapIntent(context: Context, deeplink: String, requestCode: Int): PendingIntent {
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse(deeplink)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context, requestCode, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
