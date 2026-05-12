package com.swastricare.health.notifications

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.swastricare.health.MainActivity
import com.swastricare.health.R
import com.swastricare.health.data.repository.DeviceTokenRepository
import com.swastricare.health.data.services.NotificationService
import dagger.hilt.android.AndroidEntryPoint
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Receives FCM token rotations and incoming push messages.
 *
 * Registered in AndroidManifest under the application tag with the
 * `com.google.firebase.MESSAGING_EVENT` intent filter. Lifecycle is managed
 * by the FCM SDK — the service is started on demand for each token refresh
 * or incoming data message.
 *
 * Messages are expected to carry a `data` payload (so they're delivered to
 * `onMessageReceived` even when the app is backgrounded) with these keys:
 *   - category   : MEDICATION | MEDICATION_MISSED | HYDRATION | APPOINTMENT |
 *                  VITALS | CHECKIN | (anything else → general)
 *   - nudge_id   : optional stable id; used as the notification id so a single
 *                  nudge updates rather than spawning a new one
 *   - deep_link  : optional URI to open on tap (default: swastricareapp://home)
 *
 * The `notification` block (title/body) is still respected when present.
 */
@AndroidEntryPoint
class SwastricareMessagingService : FirebaseMessagingService() {

    @Inject lateinit var deviceTokenRepository: DeviceTokenRepository
    @Inject lateinit var supabaseClient: SupabaseClient

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onDestroy() {
        scope.coroutineContext[kotlinx.coroutines.Job]?.cancel()
        super.onDestroy()
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "FCM token refreshed")

        val userId = supabaseClient.auth.currentUserOrNull()?.id
        if (userId == null) {
            // No user signed in — token will be re-registered after next sign-in via
            // SessionManager's authenticated-state hook.
            Log.d(TAG, "No authenticated user; skipping token upsert")
            return
        }

        val versionName = try {
            packageManager.getPackageInfo(packageName, 0).versionName
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
        val deviceModel = Build.MODEL

        scope.launch {
            deviceTokenRepository.upsertToken(
                userId = userId,
                token = token,
                appVersion = versionName,
                deviceModel = deviceModel
            )
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val category = data["category"]
        val nudgeId = data["nudge_id"]
        val deepLink = data["deep_link"] ?: DEFAULT_DEEP_LINK

        val title = message.notification?.title ?: "Swastricare"
        val body = message.notification?.body ?: ""

        val channelId = categoryToChannel(category)
        val priority = if (category == "MEDICATION_MISSED") {
            NotificationCompat.PRIORITY_HIGH
        } else {
            NotificationCompat.PRIORITY_DEFAULT
        }

        val tapIntent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
            setClass(this@SwastricareMessagingService, MainActivity::class.java)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            (nudgeId ?: deepLink).hashCode(),
            tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(priority)
            .setContentIntent(pendingIntent)
            .build()

        val notifId = nudgeId?.hashCode() ?: System.currentTimeMillis().toInt()
        val manager = NotificationManagerCompat.from(this)
        if (!manager.areNotificationsEnabled()) {
            Log.d(TAG, "Notifications disabled; dropping push notifId=$notifId")
            return
        }
        try {
            manager.notify(notifId, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot post notification: ${e.message}")
        }
    }

    private fun categoryToChannel(category: String?): String = when (category) {
        "MEDICATION", "MEDICATION_MISSED" -> NotificationService.CHANNEL_MEDICATION
        "HYDRATION" -> NotificationService.CHANNEL_HYDRATION
        "APPOINTMENT" -> NotificationService.CHANNEL_APPOINTMENT
        "VITALS" -> NotificationService.CHANNEL_GENERAL
        "CHECKIN" -> NotificationService.CHANNEL_AI_NUDGE
        else -> NotificationService.CHANNEL_GENERAL
    }

    companion object {
        private const val TAG = "FCM"
        private const val DEFAULT_DEEP_LINK = "swastricareapp://home"
    }
}
