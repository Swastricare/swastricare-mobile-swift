package com.swasthicare.mobile.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import com.swasthicare.mobile.MainActivity

class MedicationReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val medName = intent.getStringExtra("med_name") ?: "Medication"
        val medId = intent.getStringExtra("med_id") ?: return
        val scheduleId = intent.getStringExtra("schedule_id") ?: return

        val channelId = "medication_reminders"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Medication Reminders", NotificationManager.IMPORTANCE_HIGH)
            )
        }

        val openIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val largeIcon = BitmapFactory.decodeResource(context.resources, com.swastricare.health.R.mipmap.ic_launcher)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(com.swastricare.health.R.drawable.ic_notification)
            .setLargeIcon(largeIcon)
            .setContentTitle("Time for your medication")
            .setContentText("$medName is due now")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openIntent)
            .build()

        manager.notify("${medId}_${scheduleId}".hashCode(), notification)

        // Reschedule for tomorrow (needed since we use one-shot exact alarms)
        val cal = java.util.Calendar.getInstance().apply {
            add(java.util.Calendar.DAY_OF_MONTH, 1)
            set(java.util.Calendar.SECOND, 0)
        }
        val rescheduleIntent = Intent(context, MedicationReminderReceiver::class.java).apply {
            putExtra("med_id", medId)
            putExtra("schedule_id", scheduleId)
            putExtra("med_name", medName)
        }
        val requestCode = "${medId}_${scheduleId}".hashCode() and Int.MAX_VALUE
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, rescheduleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        try {
            alarmManager.setAndAllowWhileIdle(
                android.app.AlarmManager.RTC_WAKEUP,
                cal.timeInMillis,
                pendingIntent
            )
        } catch (_: SecurityException) { /* permission revoked */ }
    }
}
