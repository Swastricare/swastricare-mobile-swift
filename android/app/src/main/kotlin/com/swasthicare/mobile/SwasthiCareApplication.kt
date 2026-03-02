package com.swasthicare.mobile

import android.app.Application
import com.google.firebase.FirebaseApp

class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize Firebase (Crashlytics, Analytics)
        FirebaseApp.initializeApp(this)
        // Initialize app-wide services here
        // Example: Supabase, Analytics, etc.
    }
}
