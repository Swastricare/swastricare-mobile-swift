package com.swastricare.health

import android.app.Application
import android.util.Log
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.NotificationService
import com.swastricare.health.data.services.SessionManager
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Application class for SwastriCare.
 * Initializes Firebase and app-wide services.
 *
 * IMPORTANT: Firebase requires a valid google-services.json file in the app/ directory.
 * To set up:
 *   1. Go to https://console.firebase.google.com
 *   2. Create a project or select existing "SwastriCare"
 *   3. Add an Android app with package name: com.swastricare.health
 *   4. Download google-services.json and place it in android/app/
 *   5. Rebuild the project
 *
 * Without google-services.json, Firebase features (Analytics, Crashlytics, Performance)
 * will be gracefully disabled — the app will continue to function normally.
 */
@HiltAndroidApp
class SwastriCareApplication : Application(), Configuration.Provider {

    @Inject lateinit var notificationService: NotificationService
    @Inject lateinit var appAnalyticsService: AppAnalyticsService
    @Inject lateinit var sessionManager: SessionManager
    @Inject lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()

        // Install global uncaught exception handler for crash reporting
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            Log.e(TAG, "Uncaught exception on thread ${thread.name}", throwable)
            try {
                com.google.firebase.crashlytics.FirebaseCrashlytics.getInstance()
                    .recordException(throwable)
            } catch (_: Exception) { /* Crashlytics not available */ }
            defaultHandler?.uncaughtException(thread, throwable)
        }

        // Notification channels must be created synchronously (fast, required for immediate notifications)
        notificationService.createNotificationChannels()

        // Defer heavy work to background to keep app startup fast
        CoroutineScope(Dispatchers.Default).launch {
            // Schedule notifications based on saved preferences (I/O-heavy)
            notificationService.scheduleAllNotifications()

            // Enqueue WorkManager periodic jobs
            com.swastricare.health.data.workers.AiNudgeWorker.enqueue(this@SwastriCareApplication)
            com.swastricare.health.data.workers.ActivityReminderWorker.enqueue(this@SwastriCareApplication)

            // Start custom Supabase analytics service (triggers Supabase client initialization)
            try {
                appAnalyticsService.start()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to start AppAnalyticsService: ${e.message}")
            }
        }

        // Eagerly touch sessionManager so its coroutine observer starts immediately
        sessionManager.toString()

        // Initialize Firebase (kept on main thread because Crashlytics
        // collection should be enabled early for crash reporting)
        initializeFirebase()
    }

    private fun initializeFirebase() {
        try {
            val app = com.google.firebase.FirebaseApp.getInstance()
            // Firebase auto-initialized by google-services plugin
            val crashlytics = com.google.firebase.crashlytics.FirebaseCrashlytics.getInstance()
            crashlytics.setCrashlyticsCollectionEnabled(true)
            Log.d(TAG, "Firebase initialized, Crashlytics enabled")
        } catch (e: Exception) {
            Log.w(TAG, "Firebase not available: ${e.message}")
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        // Persist analytics events when system is low on memory
        // (onTerminate is never called on real devices)
        if (level >= TRIM_MEMORY_MODERATE) {
            try {
                appAnalyticsService.stop()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to stop AppAnalyticsService: ${e.message}")
            }
        }
    }

    companion object {
        private const val TAG = "SwastriCareApp"
    }
}
