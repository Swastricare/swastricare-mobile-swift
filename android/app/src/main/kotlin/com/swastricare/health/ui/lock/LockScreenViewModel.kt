package com.swastricare.health.ui.lock

import android.content.SharedPreferences
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModel
import com.swastricare.health.data.services.BiometricService
import com.swastricare.health.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class LockScreenViewModel : ViewModel() {

    private val biometricService: BiometricService = AppContainer.biometricService
    private val prefs: SharedPreferences = AppContainer.sharedPreferences

    // Initialise synchronously so the very first frame is already locked when biometric is on.
    // This prevents app content from flashing for one frame before LaunchedEffect runs.
    private val _isLocked = MutableStateFlow(
        prefs.getBoolean("biometric_enabled", false) && biometricService.canAuthenticate()
    )
    val isLocked: StateFlow<Boolean> = _isLocked.asStateFlow()

    private val _authError = MutableStateFlow<String?>(null)
    val authError: StateFlow<String?> = _authError.asStateFlow()

    val isBiometricEnabled: Boolean
        get() = prefs.getBoolean("biometric_enabled", false)

    val canUseBiometric: Boolean
        get() = biometricService.canAuthenticate()

    /** Called when app returns from background. Locks if biometric setting is on. */
    fun onAppResumed() {
        if (isBiometricEnabled && canUseBiometric) {
            _isLocked.value = true
        }
    }

    /** Called when user first opens the app. Locks if biometric setting is on. */
    fun checkInitialLock() {
        if (isBiometricEnabled && canUseBiometric) {
            _isLocked.value = true
        }
    }

    /** Trigger biometric authentication. */
    fun authenticate(activity: FragmentActivity) {
        _authError.value = null
        biometricService.authenticate(activity) { result ->
            when (result) {
                is BiometricService.BiometricResult.Success -> {
                    _isLocked.value = false
                    _authError.value = null
                }
                is BiometricService.BiometricResult.Error -> {
                    _authError.value = result.message
                }
                is BiometricService.BiometricResult.Cancelled -> {
                    _authError.value = null
                    // Stay locked
                }
            }
        }
    }

    /** Unlock without biometric (for cases where biometric is not available). */
    fun unlock() {
        _isLocked.value = false
    }

    fun clearError() {
        _authError.value = null
    }
}
