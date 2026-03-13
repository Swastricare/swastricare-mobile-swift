package com.swastricare.health.data.services

import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.crashlytics.ktx.crashlytics
import com.google.firebase.ktx.Firebase
import com.swastricare.health.core.logger.CrashReporter
import javax.inject.Inject

/**
 * Firebase Crashlytics wrapper service.
 * Matches iOS CrashlyticsService pattern.
 * Gracefully handles cases where Firebase is not configured.
 */
class CrashlyticsService @Inject constructor() : CrashReporter {

    private val crashlytics: FirebaseCrashlytics? = try {
        Firebase.crashlytics
    } catch (e: Exception) {
        Log.w(TAG, "Firebase Crashlytics not available: ${e.message}")
        null
    }

    override fun setUserId(userId: String) {
        crashlytics?.setUserId(userId)
    }

    override fun setCustomKey(key: String, value: String) {
        crashlytics?.setCustomKey(key, value)
    }

    override fun recordException(throwable: Throwable) {
        crashlytics?.recordException(throwable)
    }

    override fun log(message: String) {
        crashlytics?.log(message)
    }

    companion object {
        private const val TAG = "CrashlyticsService"
    }
}
