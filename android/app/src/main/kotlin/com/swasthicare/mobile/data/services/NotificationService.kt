package com.swasthicare.mobile.data.services

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/**
 * Centralized notification manager handling all categories:
 * - Hydration reminders (configurable frequency, quiet hours)
 * - Medication reminders (existing, kept as-is)
 * - Diet reminders (breakfast, lunch, dinner)
 * - Cycle reminders (period, ovulation, daily log)
 * - General notifications
 */
class NotificationService(
    private val context: Context,
    private val prefs: SharedPreferences
) {
    companion object {
        private const val TAG = "NotificationService"

        // Channel IDs
        const val CHANNEL_HYDRATION = "hydration_reminders"
        const val CHANNEL_MEDICATION = "medication_reminders"
        const val CHANNEL_DIET = "diet_reminders"
        const val CHANNEL_CYCLE = "cycle_reminders"
        const val CHANNEL_GENERAL = "general"

        // Notification IDs (base values — individual notifications offset from these)
        const val NOTIF_HYDRATION_BASE = 1000
        const val NOTIF_DIET_BREAKFAST = 2001
        const val NOTIF_DIET_LUNCH = 2002
        const val NOTIF_DIET_DINNER = 2003
        const val NOTIF_CYCLE_PERIOD = 3001
        const val NOTIF_CYCLE_OVULATION = 3002
        const val NOTIF_CYCLE_LOG = 3003

        // Actions
        const val ACTION_LOG_WATER = "com.swasthicare.ACTION_LOG_WATER"
        const val ACTION_MARK_MED_TAKEN = "com.swasthicare.ACTION_MARK_MED_TAKEN"
        const val ACTION_LOG_MEAL = "com.swasthicare.ACTION_LOG_MEAL"

        // Preference keys
        const val PREF_HYDRATION_ENABLED = "notif_hydration_enabled"
        const val PREF_MEDICATION_ENABLED = "notif_medication_enabled"
        const val PREF_DIET_ENABLED = "notif_diet_enabled"
        const val PREF_CYCLE_ENABLED = "notif_cycle_enabled"
        const val PREF_HYDRATION_INTERVAL_MINUTES = "notif_hydration_interval_min"
        const val PREF_QUIET_HOURS_START = "notif_quiet_start" // hour (0-23)
        const val PREF_QUIET_HOURS_END = "notif_quiet_end"     // hour (0-23)
        const val PREF_BREAKFAST_HOUR = "notif_breakfast_hour"
        const val PREF_BREAKFAST_MINUTE = "notif_breakfast_min"
        const val PREF_LUNCH_HOUR = "notif_lunch_hour"
        const val PREF_LUNCH_MINUTE = "notif_lunch_min"
        const val PREF_DINNER_HOUR = "notif_dinner_hour"
        const val PREF_DINNER_MINUTE = "notif_dinner_min"
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notificationManager = NotificationManagerCompat.from(context)

    // ── Channel Creation ──

    fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channels = listOf(
                NotificationChannel(
                    CHANNEL_HYDRATION,
                    "Hydration Reminders",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Reminders to drink water throughout the day" },

                NotificationChannel(
                    CHANNEL_MEDICATION,
                    "Medication Reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Reminders to take your medications on time" },

                NotificationChannel(
                    CHANNEL_DIET,
                    "Diet Reminders",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Meal time reminders to log your food intake" },

                NotificationChannel(
                    CHANNEL_CYCLE,
                    "Cycle Reminders",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Menstrual cycle tracking reminders" },

                NotificationChannel(
                    CHANNEL_GENERAL,
                    "General",
                    NotificationManager.IMPORTANCE_LOW
                ).apply { description = "General app notifications" }
            )
            channels.forEach { nm.createNotificationChannel(it) }
        }
    }

    // ── Settings ──

    var hydrationEnabled: Boolean
        get() = prefs.getBoolean(PREF_HYDRATION_ENABLED, true)
        set(value) { prefs.edit().putBoolean(PREF_HYDRATION_ENABLED, value).apply() }

    var medicationEnabled: Boolean
        get() = prefs.getBoolean(PREF_MEDICATION_ENABLED, true)
        set(value) { prefs.edit().putBoolean(PREF_MEDICATION_ENABLED, value).apply() }

    var dietEnabled: Boolean
        get() = prefs.getBoolean(PREF_DIET_ENABLED, true)
        set(value) { prefs.edit().putBoolean(PREF_DIET_ENABLED, value).apply() }

    var cycleEnabled: Boolean
        get() = prefs.getBoolean(PREF_CYCLE_ENABLED, false)
        set(value) { prefs.edit().putBoolean(PREF_CYCLE_ENABLED, value).apply() }

    var hydrationIntervalMinutes: Int
        get() = prefs.getInt(PREF_HYDRATION_INTERVAL_MINUTES, 60)
        set(value) { prefs.edit().putInt(PREF_HYDRATION_INTERVAL_MINUTES, value).apply() }

    var quietHoursStart: Int
        get() = prefs.getInt(PREF_QUIET_HOURS_START, 22)
        set(value) { prefs.edit().putInt(PREF_QUIET_HOURS_START, value).apply() }

    var quietHoursEnd: Int
        get() = prefs.getInt(PREF_QUIET_HOURS_END, 7)
        set(value) { prefs.edit().putInt(PREF_QUIET_HOURS_END, value).apply() }

    var breakfastHour: Int
        get() = prefs.getInt(PREF_BREAKFAST_HOUR, 8)
        set(value) { prefs.edit().putInt(PREF_BREAKFAST_HOUR, value).apply() }
    var breakfastMinute: Int
        get() = prefs.getInt(PREF_BREAKFAST_MINUTE, 0)
        set(value) { prefs.edit().putInt(PREF_BREAKFAST_MINUTE, value).apply() }

    var lunchHour: Int
        get() = prefs.getInt(PREF_LUNCH_HOUR, 12)
        set(value) { prefs.edit().putInt(PREF_LUNCH_HOUR, value).apply() }
    var lunchMinute: Int
        get() = prefs.getInt(PREF_LUNCH_MINUTE, 30)
        set(value) { prefs.edit().putInt(PREF_LUNCH_MINUTE, value).apply() }

    var dinnerHour: Int
        get() = prefs.getInt(PREF_DINNER_HOUR, 19)
        set(value) { prefs.edit().putInt(PREF_DINNER_HOUR, value).apply() }
    var dinnerMinute: Int
        get() = prefs.getInt(PREF_DINNER_MINUTE, 30)
        set(value) { prefs.edit().putInt(PREF_DINNER_MINUTE, value).apply() }

    // ── Schedule All ──

    fun scheduleAllNotifications() {
        if (hydrationEnabled) scheduleHydrationReminders() else cancelHydrationReminders()
        if (dietEnabled) scheduleDietReminders() else cancelDietReminders()
        // Medication is handled by MedicationRepository's existing AlarmManager logic
        // Cycle reminders would be scheduled when cycle data is available
    }

    // ── Hydration Reminders ──

    fun scheduleHydrationReminders() {
        cancelHydrationReminders()
        if (!hydrationEnabled) return

        val interval = hydrationIntervalMinutes
        val quietStart = quietHoursStart
        val quietEnd = quietHoursEnd

        val now = Calendar.getInstance()
        val currentHour = now.get(Calendar.HOUR_OF_DAY)

        // Schedule reminders for today's remaining waking hours
        val nextTrigger = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.MINUTE, interval)
        }

        // Ensure not in quiet hours
        val triggerHour = nextTrigger.get(Calendar.HOUR_OF_DAY)
        if (isInQuietHours(triggerHour, quietStart, quietEnd)) {
            // Schedule for end of quiet hours
            nextTrigger.set(Calendar.HOUR_OF_DAY, quietEnd)
            nextTrigger.set(Calendar.MINUTE, 0)
            if (nextTrigger.before(Calendar.getInstance())) {
                nextTrigger.add(Calendar.DAY_OF_MONTH, 1)
            }
        }

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = "HYDRATION_REMINDER"
            putExtra("interval_minutes", interval)
            putExtra("quiet_start", quietStart)
            putExtra("quiet_end", quietEnd)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIF_HYDRATION_BASE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextTrigger.timeInMillis,
                pendingIntent
            )
            Log.d(TAG, "Hydration reminder scheduled for ${nextTrigger.time}")
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot set exact alarm: ${e.message}")
            // Fallback to inexact
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextTrigger.timeInMillis,
                pendingIntent
            )
        }
    }

    fun cancelHydrationReminders() {
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = "HYDRATION_REMINDER"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, NOTIF_HYDRATION_BASE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    // ── Diet Reminders ──

    fun scheduleDietReminders() {
        cancelDietReminders()
        if (!dietEnabled) return

        scheduleDietAlarm(NOTIF_DIET_BREAKFAST, breakfastHour, breakfastMinute, "Time for Breakfast!", "Log your breakfast to stay on track.")
        scheduleDietAlarm(NOTIF_DIET_LUNCH, lunchHour, lunchMinute, "Lunch Time!", "Don't forget to log your lunch.")
        scheduleDietAlarm(NOTIF_DIET_DINNER, dinnerHour, dinnerMinute, "Dinner Time!", "Log your dinner to complete today's nutrition.")
    }

    private fun scheduleDietAlarm(id: Int, hour: Int, minute: Int, title: String, body: String) {
        val trigger = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(Calendar.getInstance())) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = "DIET_REMINDER"
            putExtra("notif_id", id)
            putExtra("title", title)
            putExtra("body", body)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                trigger.timeInMillis,
                pendingIntent
            )
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                trigger.timeInMillis,
                pendingIntent
            )
        }
    }

    fun cancelDietReminders() {
        listOf(NOTIF_DIET_BREAKFAST, NOTIF_DIET_LUNCH, NOTIF_DIET_DINNER).forEach { id ->
            val intent = Intent(context, NotificationReceiver::class.java).apply {
                action = "DIET_REMINDER"
            }
            val pi = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarmManager.cancel(pi)
        }
    }

    // ── Cycle Reminders ──

    fun scheduleCycleReminder(type: String, triggerTime: Calendar, title: String, body: String) {
        if (!cycleEnabled) return

        val id = when (type) {
            "period" -> NOTIF_CYCLE_PERIOD
            "ovulation" -> NOTIF_CYCLE_OVULATION
            "log" -> NOTIF_CYCLE_LOG
            else -> return
        }

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = "CYCLE_REMINDER"
            putExtra("notif_id", id)
            putExtra("title", title)
            putExtra("body", body)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime.timeInMillis,
                pendingIntent
            )
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime.timeInMillis,
                pendingIntent
            )
        }
    }

    // ── Show Notification (used by receiver) ──

    fun showNotification(
        channelId: String,
        notificationId: Int,
        title: String,
        body: String,
        actionLabel: String? = null,
        actionIntent: PendingIntent? = null
    ) {
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info) // TODO: Use app icon
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(
                if (channelId == CHANNEL_MEDICATION) NotificationCompat.PRIORITY_HIGH
                else NotificationCompat.PRIORITY_DEFAULT
            )

        if (actionLabel != null && actionIntent != null) {
            builder.addAction(0, actionLabel, actionIntent)
        }

        try {
            notificationManager.notify(notificationId, builder.build())
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot show notification: ${e.message}")
        }
    }

    /** Show a test notification for a given channel. */
    fun showTestNotification(channelId: String) {
        val (title, body) = when (channelId) {
            CHANNEL_HYDRATION -> "Test: Hydration" to "Time to drink water! This is a test notification."
            CHANNEL_MEDICATION -> "Test: Medication" to "Don't forget your medication! This is a test."
            CHANNEL_DIET -> "Test: Diet" to "Time to log your meal! This is a test notification."
            CHANNEL_CYCLE -> "Test: Cycle" to "Cycle reminder test notification."
            else -> "Test" to "This is a test notification."
        }
        showNotification(channelId, 9999, title, body)
    }

    // ── Helpers ──

    private fun isInQuietHours(hour: Int, start: Int, end: Int): Boolean {
        return if (start <= end) {
            // e.g., 22..7 wraps around midnight handled below
            hour in start..end
        } else {
            // Wraps around midnight: quiet from 22 to 7 means 22,23,0,1,2,3,4,5,6,7
            hour >= start || hour <= end
        }
    }
}
