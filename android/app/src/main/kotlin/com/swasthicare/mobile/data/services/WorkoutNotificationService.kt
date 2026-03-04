package com.swasthicare.mobile.data.services

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.swasthicare.mobile.MainActivity
import com.swasthicare.mobile.R

class WorkoutNotificationService : Service() {

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    companion object {
        const val CHANNEL_ID = "workout_tracking"
        const val NOTIFICATION_ID = 4001
        const val ACTION_STOP = "com.swasthicare.mobile.WORKOUT_STOP"
        private const val EXTRA_TIME = "elapsed_time"
        private const val EXTRA_DISTANCE = "distance"
        private const val EXTRA_PACE = "pace"
        private const val EXTRA_CALORIES = "calories"

        fun start(context: Context) {
            val intent = Intent(context, WorkoutNotificationService::class.java)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WorkoutNotificationService::class.java))
        }

        fun update(context: Context, time: String, distance: String, pace: String, calories: Int) {
            val intent = Intent(context, WorkoutNotificationService::class.java).apply {
                putExtra(EXTRA_TIME, time)
                putExtra(EXTRA_DISTANCE, distance)
                putExtra(EXTRA_PACE, pace)
                putExtra(EXTRA_CALORIES, calories)
            }
            context.startForegroundService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, IntentFilter(ACTION_STOP), RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopReceiver, IntentFilter(ACTION_STOP))
        }
    }

    override fun onDestroy() {
        unregisterReceiver(stopReceiver)
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val time = intent?.getStringExtra(EXTRA_TIME) ?: "00:00"
        val distance = intent?.getStringExtra(EXTRA_DISTANCE) ?: "0.00 km"
        val pace = intent?.getStringExtra(EXTRA_PACE) ?: "--:--"
        val calories = intent?.getIntExtra(EXTRA_CALORIES, 0) ?: 0

        val notification = buildNotification(time, distance, pace, calories)
        startForeground(NOTIFICATION_ID, notification)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Workout Tracking", NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows live workout stats"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(time: String, distance: String, pace: String, calories: Int): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = android.net.Uri.parse("swastricare://activeworkout")
        }
        val pendingTap = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = PendingIntent.getBroadcast(
            this, 1,
            Intent(ACTION_STOP).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("Workout in Progress")
            .setContentText("$time  •  $distance  •  $pace /km")
            .setSubText("$calories cal")
            .setOngoing(true)
            .setContentIntent(pendingTap)
            .addAction(R.drawable.ic_launcher_foreground, "Stop", stopIntent)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
    }
}
