package com.swasthicare.mobile.data.services

import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.crashlytics.ktx.crashlytics
import com.google.firebase.ktx.Firebase

/**
 * Firebase Crashlytics wrapper service.
 * Matches iOS CrashlyticsService pattern.
 * Gracefully handles cases where Firebase is not configured.
 */
class CrashlyticsService {

    private val crashlytics: FirebaseCrashlytics? = try {
        Firebase.crashlytics
    } catch (e: Exception) {
        Log.w(TAG, "Firebase Crashlytics not available: ${e.message}")
        null
    }

    fun setUserId(userId: String) {
        crashlytics?.setUserId(userId)
    }

    fun setCustomKey(key: String, value: String) {
        crashlytics?.setCustomKey(key, value)
    }

    fun recordException(throwable: Throwable) {
        crashlytics?.recordException(throwable)
    }

    fun log(message: String) {
        crashlytics?.log(message)
    }

    companion object {
        private const val TAG = "CrashlyticsService"
    }
}
