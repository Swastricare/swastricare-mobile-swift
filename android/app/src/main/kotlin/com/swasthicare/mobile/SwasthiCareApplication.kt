package com.swasthicare.mobile

import android.app.Application
import com.swasthicare.mobile.di.AppContainer

class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Initialize AppContainer early so services have context
        AppContainer.initialize(this)

        // Initialize Analytics Service (Feature 17)
        // Starts session, loads persisted events, begins periodic flush,
        // and registers ProcessLifecycleOwner observer for background flush.
        try {
            AppContainer.analyticsService.initialize()
        } catch (e: Exception) {
            // Analytics initialization failure should not crash the app
            android.util.Log.w("SwasthiCareApp", "Analytics init failed: ${e.message}")
        }
    }
}
