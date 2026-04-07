package com.swastricare.health.ui.lock

import android.content.SharedPreferences
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModel
import com.swastricare.health.data.services.BiometricService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

/**
 * Holds the app-lock state. The UI is the system [BiometricPrompt] itself — there is
 * no custom Compose lock screen. See [MainActivity] for how this is wired.
 */
@HiltViewModel
class LockScreenViewModel @Inject constructor(
    private val biometricService: BiometricService,
    private val prefs: SharedPreferences
) : ViewModel() {

    // Initialise synchronously so the very first frame is already locked when biometric is on.
    // This prevents app content from flashing for one frame before LaunchedEffect runs.
    private val _isLocked = MutableStateFlow(
        prefs.getBoolean("biometric_enabled", false) && biometricService.canAuthenticate()
    )
    val isLocked: StateFlow<Boolean> = _isLocked.asStateFlow()

    val isBiometricEnabled: Boolean
        get() = prefs.getBoolean("biometric_enabled", false)

    val canUseBiometric: Boolean
        get() = biometricService.canAuthenticate()

    /**
     * Called when the app genuinely goes to background (ON_STOP after the activity
     * has truly left the foreground, not due to a configuration change or a transient
     * system overlay). Locks the screen if biometric is enabled.
     */
    fun onAppBackgrounded() {
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

    /**
     * Trigger the native system biometric / device-credential prompt.
     *
     * @param onCancel invoked if the user dismisses the prompt or a non-recoverable
     *        error occurs. The caller typically calls [FragmentActivity.finish] here
     *        so the app closes rather than leaving the user stranded on a blank screen.
     */
    fun authenticate(
        activity: FragmentActivity,
        onCancel: () -> Unit = {}
    ) {
        biometricService.authenticate(activity) { result ->
            when (result) {
                is BiometricService.BiometricResult.Success -> {
                    _isLocked.value = false
                }
                is BiometricService.BiometricResult.Cancelled,
                is BiometricService.BiometricResult.Error -> {
                    onCancel()
                }
            }
        }
    }

    /** Unlock without biometric (for cases where biometric is not available). */
    fun unlock() {
        _isLocked.value = false
    }
}
