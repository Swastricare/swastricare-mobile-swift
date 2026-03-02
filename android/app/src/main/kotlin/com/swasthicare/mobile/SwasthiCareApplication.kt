package com.swasthicare.mobile

import android.app.Application
import android.util.Log
import com.swasthicare.mobile.di.AppContainer

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

        // Create all notification channels
        AppContainer.notificationService.createNotificationChannels()

        // Schedule notifications based on saved preferences
        AppContainer.notificationService.scheduleAllNotifications()

        // Initialize Firebase
        initializeFirebase()

        // Start custom Supabase analytics service
        try {
            AppContainer.appAnalyticsService.start()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start AppAnalyticsService: ${e.message}")
        }
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

    override fun onTerminate() {
        super.onTerminate()
        // Stop custom analytics service to persist unsent events
        try {
            AppContainer.appAnalyticsService.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop AppAnalyticsService: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "SwasthiCareApp"
    }
}
