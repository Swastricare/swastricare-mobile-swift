package com.swasthicare.mobile

import android.app.Application
import android.util.Log
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Application class for SwasthiCare.
 * Initializes Firebase and app-wide services.
 *
 * IMPORTANT: Firebase requires a valid google-services.json file in the app/ directory.
 * To set up:
 *   1. Go to https://console.firebase.google.com
 *   2. Create a project or select existing "SwasthiCare"
 *   3. Add an Android app with package name: com.swasthicare.mobile
 *   4. Download google-services.json and place it in android/app/
 *   5. Rebuild the project
 *
 * Without google-services.json, Firebase features (Analytics, Crashlytics, Performance)
 * will be gracefully disabled — the app will continue to function normally.
 */
class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Initialize AppContainer early so services can access context
        AppContainer.initialize(this)

        // Notification channels must be created synchronously (fast, required for immediate notifications)
        AppContainer.notificationService.createNotificationChannels()

        // Defer heavy work to background to keep app startup fast
        CoroutineScope(Dispatchers.Default).launch {
            // Schedule notifications based on saved preferences (I/O-heavy)
            AppContainer.notificationService.scheduleAllNotifications()

            // Start custom Supabase analytics service (triggers Supabase client initialization)
            try {
                AppContainer.appAnalyticsService.start()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to start AppAnalyticsService: ${e.message}")
            }
        }

        // Initialize Firebase (uses reflection to check availability; kept on main thread
        // because Crashlytics collection should be enabled early for crash reporting)
        initializeFirebase()
    }

    private fun initializeFirebase() {
        try {
            // FirebaseApp.initializeApp(this) is called automatically by the
            // google-services plugin if google-services.json is present.
            // We just verify it initialized correctly.
            val firebaseAvailable = try {
                Class.forName("com.google.firebase.FirebaseApp")
                val method = Class.forName("com.google.firebase.FirebaseApp")
                    .getMethod("initializeApp", android.content.Context::class.java)
                method.invoke(null, this)
                true
            } catch (e: Exception) {
                false
            }

            if (firebaseAvailable) {
                Log.i(TAG, "Firebase initialized successfully")

                // Enable Crashlytics collection
                try {
                    val crashlytics = com.google.firebase.crashlytics.FirebaseCrashlytics.getInstance()
                    crashlytics.setCrashlyticsCollectionEnabled(true)
                } catch (e: Exception) {
                    Log.w(TAG, "Crashlytics not available: ${e.message}")
                }
            } else {
                Log.w(TAG, "Firebase not available - google-services.json may be missing")
            }
        } catch (e: Exception) {
            // Firebase not configured — this is OK during development
            Log.w(TAG, "Firebase initialization skipped: ${e.message}")
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        // Persist analytics events when system is low on memory
        // (onTerminate is never called on real devices)
        if (level >= TRIM_MEMORY_MODERATE) {
            try {
                AppContainer.appAnalyticsService.stop()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to stop AppAnalyticsService: ${e.message}")
            }
        }
    }

    companion object {
        private const val TAG = "SwasthiCareApp"
    }
}
