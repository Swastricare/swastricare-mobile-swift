package com.swastricare.health.data.workers

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.swastricare.health.data.services.NotificationService
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.util.concurrent.TimeUnit

@HiltWorker
class ActivityReminderWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val notificationService: NotificationService,
    private val sharedPreferences: SharedPreferences,
    private val supabaseClient: SupabaseClient
) : CoroutineWorker(context, params) {

    @Serializable
    private data class StepsRow(val steps: Int = 0)

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            if (!notificationService.activityEnabled) return@withContext Result.success()

            val hour = java.time.LocalTime.now().hour
            if (hour < 18 || hour > 21) return@withContext Result.success()

            val profileId = sharedPreferences.getString("current_profile_id", null)
                ?: return@withContext Result.success()

            val today = LocalDate.now().toString()
            val steps = try {
                supabaseClient.from("daily_health_metrics")
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

            val goal = notificationService.activityGoalSteps
            when {
                steps < goal / 2 -> notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_ACTIVITY,
                    notificationId = NotificationService.NOTIF_ACTIVITY_DAILY,
                    title = "Time to Move!",
                    body = "$steps steps so far — ${goal - steps} more to hit your goal today!"
                )
                steps in ((goal * 8 / 10) until goal) -> notificationService.showNotification(
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
