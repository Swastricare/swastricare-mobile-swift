package com.swastricare.health.data.services

import android.content.Context
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * Wrapper around AndroidX BiometricPrompt.
 *
 * Usage:
 *   1. Check [canAuthenticate] to see if biometrics are available.
 *   2. Call [authenticate] from an Activity to trigger the prompt.
 */
class BiometricService(private val context: Context) {

    companion object {
        private const val TAG = "BiometricService"
    }

    sealed class BiometricResult {
        object Success : BiometricResult()
        data class Error(val code: Int, val message: String) : BiometricResult()
        object Cancelled : BiometricResult()
    }

    /** Returns true when the device has biometric hardware and the user has enrolled biometrics. */
    fun canAuthenticate(): Boolean {
        val manager = BiometricManager.from(context)
        return manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL) ==
                BiometricManager.BIOMETRIC_SUCCESS
    }

    /** Returns a human-readable reason why biometrics are unavailable, or null if available. */
    fun unavailableReason(): String? {
        val manager = BiometricManager.from(context)
        return when (manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)) {
            BiometricManager.BIOMETRIC_SUCCESS -> null
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "No biometric hardware"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "Biometric hardware unavailable"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "No biometrics enrolled"
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "Security update required"
            else -> "Biometric authentication not available"
        }
    }

    /**
     * Show the system biometric prompt.
     * Must be called from a [FragmentActivity].
     */
    fun authenticate(
        activity: FragmentActivity,
        onResult: (BiometricResult) -> Unit
    ) {
        val executor = ContextCompat.getMainExecutor(context)

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                Log.d(TAG, "Authentication succeeded")
                onResult(BiometricResult.Success)
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                Log.w(TAG, "Authentication error $errorCode: $errString")
                if (errorCode == BiometricPrompt.ERROR_USER_CANCELED || errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON) {
                    onResult(BiometricResult.Cancelled)
                } else {
                    onResult(BiometricResult.Error(errorCode, errString.toString()))
                }
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                // This is called on individual failed attempts; the system keeps retrying.
                Log.d(TAG, "Authentication attempt failed")
            }
        }

        val prompt = BiometricPrompt(activity, executor, callback)

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock SwastriCare")
            .setSubtitle("Use fingerprint or face to unlock")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        prompt.authenticate(promptInfo)
    }
}
