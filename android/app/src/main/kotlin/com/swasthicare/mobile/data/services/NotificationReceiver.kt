package com.swasthicare.mobile.data.services

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles notification-related broadcast intents:
 *   - Alarm triggers (hydration, diet, cycle reminders)
 *   - Quick action intents (log water, mark med taken, log meal)
 */
class NotificationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NotificationReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
        val notificationService = NotificationService(context, prefs)

        when (intent.action) {
            // ── Alarm-triggered reminders ──

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

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_HYDRATION,
                    notificationId = NotificationService.NOTIF_HYDRATION_BASE,
                    title = "Stay Hydrated!",
                    body = "Time to drink some water. Tap to log 250ml.",
                    actionLabel = "Log 250ml",
                    actionIntent = logWaterPI
                )

                // Re-schedule the next hydration reminder
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

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_DIET,
                    notificationId = notifId,
                    title = title,
                    body = body,
                    actionLabel = "Log Meal",
                    actionIntent = logMealPI
                )

                // Re-schedule for next day
                notificationService.scheduleDietReminders()
            }

            "CYCLE_REMINDER" -> {
                val notifId = intent.getIntExtra("notif_id", 0)
                val title = intent.getStringExtra("title") ?: "Cycle Reminder"
                val body = intent.getStringExtra("body") ?: "Cycle tracking reminder"

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_CYCLE,
                    notificationId = notifId,
                    title = title,
                    body = body
                )
            }

            // ── Quick Action Intents ──

            NotificationService.ACTION_LOG_WATER -> {
                val amountMl = intent.getIntExtra("amount_ml", 250)
                Log.d(TAG, "Quick action: log $amountMl ml water")
                // Add hydration entry via shared preferences (same as HydrationRepository local storage)
                try {
                    val entriesJson = prefs.getString("hydration_entries", "[]") ?: "[]"
                    // Append a new entry (simplified — full integration uses HydrationRepository)
                    val newEntry = """{"id":"notif_${System.currentTimeMillis()}","amountMl":$amountMl,"timestamp":"${java.time.Instant.now()}","synced":false}"""
                    val updated = if (entriesJson == "[]") "[$newEntry]" else "${entriesJson.dropLast(1)},$newEntry]"
                    prefs.edit().putString("hydration_entries", updated).apply()
                    Log.d(TAG, "Logged $amountMl ml via quick action")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to log water: ${e.message}")
                }
            }

            NotificationService.ACTION_MARK_MED_TAKEN -> {
                val medicationId = intent.getStringExtra("medication_id")
                Log.d(TAG, "Quick action: mark medication $medicationId taken")
                // Mark medication as taken would update SharedPreferences or trigger repository
            }

            NotificationService.ACTION_LOG_MEAL -> {
                Log.d(TAG, "Quick action: log meal — opening app")
                // Open the app's diet screen via deep link or just log the intent
            }

            // ── Boot / Time change — re-schedule all ──
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "Device boot/time changed: re-scheduling notifications")
                notificationService.scheduleAllNotifications()
            }
        }
    }
}
