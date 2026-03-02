package com.swasthicare.mobile

import android.app.Application

class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize app-wide services here
        // Example: Supabase, Analytics, etc.
    }
}
