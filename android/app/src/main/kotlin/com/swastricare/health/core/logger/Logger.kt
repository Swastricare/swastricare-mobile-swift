package com.swastricare.health.core.logger

import android.util.Log
import com.swastricare.health.BuildConfig

/**
 * Centralized logging interface.
 * Abstracts logging implementation (Timber, Firebase, etc.)
 */
interface Logger {
    fun d(tag: String, message: String)
    fun i(tag: String, message: String)
    fun w(tag: String, message: String, throwable: Throwable? = null)
    fun e(tag: String, message: String, throwable: Throwable? = null)
    fun wtf(tag: String, message: String, throwable: Throwable? = null)

    companion object {
        lateinit var instance: Logger
            private set

        fun initialize(logger: Logger) {
            instance = logger
        }

        fun d(tag: String, message: String) = instance.d(tag, message)
        fun i(tag: String, message: String) = instance.i(tag, message)
        fun w(tag: String, message: String, throwable: Throwable? = null) =
            instance.w(tag, message, throwable)
        fun e(tag: String, message: String, throwable: Throwable? = null) =
            instance.e(tag, message, throwable)
        fun wtf(tag: String, message: String, throwable: Throwable? = null) =
            instance.wtf(tag, message, throwable)
    }
}

/**
 * Implementation using Timber and Firebase Crashlytics.
 */
class LoggerImpl(
    private val crashReporter: CrashReporter
) : Logger {

    override fun d(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(tag, message)
        }
    }

    override fun i(tag: String, message: String) {
        Log.i(tag, message)
    }

    override fun w(tag: String, message: String, throwable: Throwable?) {
        Log.w(tag, message, throwable)
        crashReporter.log("WARNING: $tag - $message")
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        Log.e(tag, message, throwable)
        throwable?.let { crashReporter.recordException(it) }
    }

    override fun wtf(tag: String, message: String, throwable: Throwable?) {
        Log.wtf(tag, message, throwable)
        throwable?.let { crashReporter.recordException(it) }
    }
}
