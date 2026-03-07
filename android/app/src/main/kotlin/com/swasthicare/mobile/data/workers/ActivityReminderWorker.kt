package com.swasthicare.mobile.data.workers

import android.content.Context
import android.util.Log
import androidx.work.*
import com.swasthicare.mobile.data.services.NotificationService
import com.swasthicare.mobile.di.AppContainer
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.util.concurrent.TimeUnit

class ActivityReminderWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    @Serializable
    private data class StepsRow(val steps: Int = 0)

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            AppContainer.initialize(applicationContext)
            val notifService = AppContainer.notificationService
            if (!notifService.activityEnabled) return@withContext Result.success()

            val hour = java.time.LocalTime.now().hour
            if (hour < 18 || hour > 21) return@withContext Result.success()

            val profileId = AppContainer.sharedPreferences.getString("current_profile_id", null)
                ?: return@withContext Result.success()

            val today = LocalDate.now().toString()
            val steps = try {
                AppContainer.supabaseClient.from("daily_health_metrics")
                    .select {
                        filter {
                            eq("health_profile_id", profileId)
                            eq("date", today)
                        }
                        limit(1)
                    }
                    .decodeList<StepsRow>()
                    .firstOrNull()?.steps ?: 0
            } catch (e: Exception) {
                Log.w(TAG, "Could not fetch steps: ${e.message}")
                return@withContext Result.success()
            }

            val goal = notifService.activityGoalSteps
            when {
                steps < goal / 2 -> notifService.showNotification(
                    channelId = NotificationService.CHANNEL_ACTIVITY,
                    notificationId = NotificationService.NOTIF_ACTIVITY_DAILY,
                    title = "Time to Move!",
                    body = "$steps steps so far — ${goal - steps} more to hit your goal today!"
                )
                steps in ((goal * 8 / 10) until goal) -> notifService.showNotification(
                    channelId = NotificationService.CHANNEL_ACTIVITY,
                    notificationId = NotificationService.NOTIF_ACTIVITY_DAILY,
                    title = "Almost There!",
                    body = "$steps steps — just ${goal - steps} more to reach your goal!"
                )
            }
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "ActivityReminderWorker failed: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "ActivityReminderWorker"
        const val WORK_NAME = "activity_reminder"

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<ActivityReminderWorker>(1, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request
            )
        }
    }
}
