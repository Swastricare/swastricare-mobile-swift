package com.swastricare.health.ui.screens.settings

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import com.swastricare.health.BuildConfig
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.model.AppUser
import com.swastricare.health.data.model.HealthProfile
import com.swastricare.health.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

data class SettingsUiState(
    val user: AppUser? = null,
    val healthProfile: HealthProfile? = null,
    val isLoading: Boolean = false,
    val isLoadingHealthProfile: Boolean = false,
    val errorMessage: String? = null,
    val notificationsEnabled: Boolean = true,
    val biometricEnabled: Boolean = false,
    val showSignOutConfirmation: Boolean = false,
    val showDeleteAccountConfirmation: Boolean = false,
    val hasUpdate: Boolean = false
)

class SettingsViewModel : ViewModel() {
    private val authRepository = AppContainer.authRepository
    private val profileRepository = AppContainer.profileRepository
    private val prefs: SharedPreferences = AppContainer.sharedPreferences

    private val _uiState = MutableStateFlow(
        SettingsUiState(biometricEnabled = AppContainer.sharedPreferences.getBoolean("biometric_enabled", false))
    )
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    // Sign out event for navigation
    private val _signOutEvent = MutableStateFlow(false)
    val signOutEvent: StateFlow<Boolean> = _signOutEvent.asStateFlow()

    init {
        loadUser()
    }

    private fun loadUser() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val user = authRepository.currentUser
                if (user != null) {
                    _uiState.update { it.copy(user = user, isLoading = false) }
                    // If auth metadata didn't carry full_name (email sign-ups),
                    // fetch it from the profiles table directly.
                    if (user.fullName.isNullOrBlank()) {
                        val profileRow = profileRepository.getUserProfileRow(user.id)
                        if (profileRow != null) {
                            _uiState.update { state ->
                                state.copy(
                                    user = state.user?.copy(
                                        fullName = profileRow.fullName,
                                        avatarUrl = profileRow.avatarUrl ?: state.user.avatarUrl
                                    )
                                )
                            }
                        }
                    }
                    loadHealthProfile(user.id)
                } else {
                    _uiState.update { it.copy(isLoading = false) }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.message, isLoading = false) }
            }
        }
    }

    private fun loadHealthProfile(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingHealthProfile = true) }
            try {
                val profile = profileRepository.getHealthProfile(userId)
                if (profile != null) {
                    _uiState.update { state ->
                        // Auth metadata may not carry fullName for email sign-ups;
                        // fall back to the health profile's fullName.
                        val enrichedUser = if (state.user?.fullName.isNullOrBlank()) {
                            state.user?.copy(fullName = profile.fullName)
                        } else {
                            state.user
                        }
                        state.copy(
                            user = enrichedUser,
                            healthProfile = profile,
                            isLoadingHealthProfile = false
                        )
                    }
                } else {
                    _uiState.update { it.copy(isLoadingHealthProfile = false) }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoadingHealthProfile = false) }
            }
        }
    }

    fun refreshHealthProfile() {
        val userId = uiState.value.user?.id ?: return
        loadHealthProfile(userId)
    }

    fun toggleNotifications(enabled: Boolean) {
        _uiState.update { it.copy(notificationsEnabled = enabled) }
    }

    fun toggleBiometric(enabled: Boolean) {
        prefs.edit().putBoolean("biometric_enabled", enabled).apply()
        _uiState.update { it.copy(biometricEnabled = enabled) }
    }

    fun setShowSignOutConfirmation(show: Boolean) {
        _uiState.update { it.copy(showSignOutConfirmation = show) }
    }

    fun setShowDeleteAccountConfirmation(show: Boolean) {
        _uiState.update { it.copy(showDeleteAccountConfirmation = show) }
    }

    fun signOut() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                authRepository.signOut()
                _uiState.update {
                    it.copy(
                        user = null,
                        healthProfile = null,
                        isLoading = false,
                        showSignOutConfirmation = false
                    )
                }
                _signOutEvent.value = true
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.message, isLoading = false) }
            }
        }
    }

    fun onSignOutHandled() {
        _signOutEvent.value = false
    }

    fun deleteAccount() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                authRepository.deleteAccount()
                _uiState.update {
                    it.copy(
                        user = null,
                        healthProfile = null,
                        isLoading = false,
                        showDeleteAccountConfirmation = false
                    )
                }
                _signOutEvent.value = true
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        errorMessage = "Account deletion not fully implemented on backend yet.",
                        isLoading = false,
                        showDeleteAccountConfirmation = false
                    )
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    // Computed helpers

    val memberSince: String
        get() {
            val dateStr = uiState.value.user?.createdAt ?: return "Unknown"
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                val date = inputFormat.parse(dateStr.take(19))
                val outputFormat = SimpleDateFormat("MMM d, yyyy", Locale.US)
                outputFormat.format(date ?: Date())
            } catch (e: Exception) {
                "Recent"
            }
        }

    val profileAge: String
        get() {
            val dobStr = uiState.value.healthProfile?.dateOfBirth ?: return "Not set"
            return try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val dob = sdf.parse(dobStr) ?: return "Not set"
                val today = Calendar.getInstance()
                val dobCal = Calendar.getInstance()
                dobCal.time = dob
                var age = today.get(Calendar.YEAR) - dobCal.get(Calendar.YEAR)
                if (today.get(Calendar.DAY_OF_YEAR) < dobCal.get(Calendar.DAY_OF_YEAR)) {
                    age--
                }
                "$age years"
            } catch (e: Exception) {
                "Not set"
            }
        }

    val profileBMI: String
        get() {
            val profile = uiState.value.healthProfile ?: return "Not set"
            val heightM = profile.heightCm / 100.0
            val bmi = profile.weightKg / (heightM * heightM)
            return String.format(Locale.US, "%.1f", bmi)
        }

    val appVersion: String = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
}
