package com.swasthicare.mobile

import android.app.Application
import com.swasthicare.mobile.di.AppContainer

class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Initialize AppContainer early so services can access context
        AppContainer.initialize(this)

        // Create all notification channels
        AppContainer.notificationService.createNotificationChannels()

        // Schedule notifications based on saved preferences
        AppContainer.notificationService.scheduleAllNotifications()
    }
}
