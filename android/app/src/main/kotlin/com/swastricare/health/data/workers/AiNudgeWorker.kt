package com.swastricare.health.data.workers

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.swastricare.health.MainActivity
import com.swastricare.health.data.services.NotificationService
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.util.concurrent.TimeUnit

@HiltWorker
class AiNudgeWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val notificationService: NotificationService,
    private val sharedPreferences: SharedPreferences,
    private val supabaseClient: SupabaseClient
) : CoroutineWorker(context, params) {

    @Serializable
    private data class AiNudgeRow(
        val id: String,
        val title: String,
        val message: String,
        val priority: String = "medium",
        val action_deeplink: String? = null,
        val nudge_type: String = "general"
    )

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            if (!notificationService.aiNudgeEnabled) return@withContext Result.success()

            val userId = sharedPreferences.getString("current_user_id", null)
                ?: return@withContext Result.success()

            val nudges = supabaseClient
                .from("ai_nudges")
                .select {
                    filter {
                        eq("user_id", userId)
                        eq("push_sent", false)
                        eq("is_dismissed", false)
                    }
                    order("created_at", Order.DESCENDING)
                    limit(5)
                }
                .decodeList<AiNudgeRow>()

            nudges.forEach { nudge ->
                val notifId = NotificationService.NOTIF_AI_NUDGE_BASE + (nudge.id.hashCode() and 0x7FFFFFFF)

                val tapPI = nudge.action_deeplink?.let { deeplink ->
                    val tapIntent = Intent(applicationContext, MainActivity::class.java).apply {
                        data = Uri.parse(deeplink)
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    android.app.PendingIntent.getActivity(
                        applicationContext, notifId, tapIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                }

                notificationService.showNotification(
                    channelId = NotificationService.CHANNEL_AI_NUDGE,
                    notificationId = notifId,
                    title = nudge.title,
                    body = nudge.message,
                    contentIntent = tapPI
                )

                try {
                    supabaseClient.from("ai_nudges").update({
                        set("push_sent", true)
                    }) { filter { eq("id", nudge.id) } }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to mark nudge push_sent: ${e.message}")
                }
            }

            Log.d(TAG, "Showed ${nudges.size} AI nudges")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "AiNudgeWorker failed: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "AiNudgeWorker"
        const val WORK_NAME = "ai_nudge_poll"

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<AiNudgeWorker>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request
            )
        }
    }
}
