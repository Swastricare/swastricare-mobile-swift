package com.swastricare.health.core.logger

/**
 * Crash reporting interface (Firebase Crashlytics).
 */
interface CrashReporter {
    fun log(message: String)
    fun recordException(throwable: Throwable)
    fun setUserId(userId: String)
    fun setCustomKey(key: String, value: String)
}
