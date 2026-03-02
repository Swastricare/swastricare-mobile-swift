package com.swasthicare.mobile.ui.screens.profile

import android.content.SharedPreferences
import android.graphics.Bitmap
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.model.AppUser
import com.swasthicare.mobile.data.model.Gender
import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.data.services.BiometricService
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID

data class ProfileUiState(
    val user: AppUser? = null,
    val healthProfile: HealthProfile? = null,
    val isLoading: Boolean = false,
    val isLoadingHealthProfile: Boolean = false,
    val errorMessage: String? = null,
    val notificationsEnabled: Boolean = false,
    val biometricEnabled: Boolean = false,
    val healthSyncEnabled: Boolean = false,
    val showSignOutConfirmation: Boolean = false,
    val showDeleteAccountConfirmation: Boolean = false
)

/**
 * State for the edit profile form. Separate from display state
 * so edits can be discarded without affecting the main profile.
 */
data class EditProfileState(
    val fullName: String = "",
    val phoneNumber: String = "",
    val bio: String = "",
    val gender: Gender = Gender.Male,
    val dateOfBirth: String = "",
    val dateOfBirthMillis: Long? = null,
    val heightCm: String = "",
    val weightKg: String = "",
    val bloodType: String = "",
    val city: String = "",
    val activityLevel: String = "Moderately Active",
    val avatarUrl: String? = null,
    val selectedAvatarUri: Uri? = null,
    val capturedAvatarBitmap: Bitmap? = null
) {
    val isValid: Boolean
        get() = fullName.isNotBlank() &&
                (heightCm.isEmpty() || (heightCm.toDoubleOrNull() ?: 0.0) > 0) &&
                (weightKg.isEmpty() || (weightKg.toDoubleOrNull() ?: 0.0) > 0) &&
                (phoneNumber.isEmpty() || isPhoneValid)

    val isPhoneValid: Boolean
        get() = phoneNumber.isEmpty() || phoneNumber.matches(Regex("^[0-9]{10}$"))

    val calculatedBMI: Double?
        get() {
            val h = heightCm.toDoubleOrNull() ?: return null
            val w = weightKg.toDoubleOrNull() ?: return null
            if (h <= 0 || w <= 0) return null
            val hm = h / 100.0
            return w / (hm * hm)
        }

    val bmiCategory: String
        get() {
            val bmi = calculatedBMI ?: return ""
            return when {
                bmi < 18.5 -> "Underweight"
                bmi < 25.0 -> "Normal"
                bmi < 30.0 -> "Overweight"
                else -> "Obese"
            }
        }
}

class ProfileViewModel : ViewModel() {
    private val authRepository = AppContainer.authRepository
    private val profileRepository = AppContainer.profileRepository
    private val biometricService: BiometricService = AppContainer.biometricService
    private val prefs: SharedPreferences = AppContainer.sharedPreferences
    private val analyticsService = AppContainer.analyticsService

    // Expose sign out event for navigation
    private val _signOutEvent = MutableStateFlow(false)
    val signOutEvent: StateFlow<Boolean> = _signOutEvent.asStateFlow()

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    // Edit profile state
    private val _editState = MutableStateFlow(EditProfileState())
    val editState: StateFlow<EditProfileState> = _editState.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _saveError = MutableStateFlow<String?>(null)
    val saveError: StateFlow<String?> = _saveError.asStateFlow()

    init {
        loadUser()
        // Load settings from SharedPreferences
        _uiState.update {
            it.copy(
                notificationsEnabled = true,
                biometricEnabled = prefs.getBoolean("biometric_enabled", false),
                healthSyncEnabled = true
            )
        }
    }

    fun loadUser() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            try {
                // Try to get real user
                val user = authRepository.currentUser

                if (user != null) {
                    _uiState.update { it.copy(user = user, isLoading = false) }
                    loadHealthProfile(user.id)
                } else {
                    // Fallback to mock user for UI demonstration if no real user logged in
                    val mockUser = AppUser(
                        id = "mock-user-1",
                        email = "john.doe@example.com",
                        fullName = "John Doe",
                        createdAt = "2024-01-01T12:00:00Z"
                    )
                    _uiState.update { it.copy(user = mockUser, isLoading = false) }
                    loadHealthProfile(mockUser.id)
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.message, isLoading = false) }
            }
        }
    }

    fun loadHealthProfile(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingHealthProfile = true) }

            try {
                // Try fetching real profile
                val profile = profileRepository.getHealthProfile(userId)

                if (profile != null) {
                    _uiState.update {
                        it.copy(healthProfile = profile, isLoadingHealthProfile = false)
                    }
                } else {
                    // Fallback mock profile for demo
                    val mockProfile = HealthProfile(
                        userId = userId,
                        fullName = "John Doe",
                        gender = Gender.Male,
                        dateOfBirth = "1990-01-01",
                        heightCm = 180.0,
                        weightKg = 75.0,
                        bloodType = "O+"
                    )
                    _uiState.update {
                        it.copy(healthProfile = mockProfile, isLoadingHealthProfile = false)
                    }
                }
            } catch (e: Exception) {
                // Don't show error for profile load failure (user might not have one)
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
        if (enabled && !biometricService.canAuthenticate()) {
            // Device doesn't support biometric — don't enable
            return
        }
        prefs.edit().putBoolean("biometric_enabled", enabled).apply()
        _uiState.update { it.copy(biometricEnabled = enabled) }
    }

    fun toggleHealthSync(enabled: Boolean) {
        _uiState.update { it.copy(healthSyncEnabled = enabled) }
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
                analyticsService.logEvent("sign_out")
                _uiState.update {
                    it.copy(
                        user = null,
                        healthProfile = null,
                        isLoading = false,
                        showSignOutConfirmation = false
                    )
                }
                // Trigger sign out event for navigation
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
            } catch (e: Exception) {
                _uiState.update {
                    // Handle unimplemented error gracefully for demo
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

    // ─────────────────────────────────────
    // MARK: - Edit Profile
    // ─────────────────────────────────────

    /** Populate edit state from current profile data */
    fun beginEdit() {
        val user = _uiState.value.user
        val profile = _uiState.value.healthProfile

        _editState.value = EditProfileState(
            fullName = profile?.fullName ?: user?.fullName ?: "",
            phoneNumber = "",
            bio = "",
            gender = profile?.gender ?: Gender.Male,
            dateOfBirth = profile?.dateOfBirth ?: "",
            heightCm = profile?.heightCm?.let { String.format(Locale.US, "%.0f", it) } ?: "",
            weightKg = profile?.weightKg?.let { String.format(Locale.US, "%.0f", it) } ?: "",
            bloodType = profile?.bloodType ?: "",
            city = "",
            activityLevel = "Moderately Active",
            avatarUrl = user?.avatarUrl
        )
        _saveError.value = null
    }

    fun cancelEdit() {
        _editState.value = EditProfileState()
        _saveError.value = null
    }

    fun updateEditField(transform: EditProfileState.() -> EditProfileState) {
        _editState.update { it.transform() }
    }

    fun onAvatarSelected(uri: Uri) {
        _editState.update { it.copy(selectedAvatarUri = uri, capturedAvatarBitmap = null) }
    }

    fun onAvatarCaptured(bitmap: Bitmap) {
        _editState.update { it.copy(capturedAvatarBitmap = bitmap, selectedAvatarUri = null) }
    }

    fun saveProfile(onSuccess: () -> Unit) {
        val state = _editState.value
        if (!state.isValid) {
            _saveError.value = "Please fix validation errors before saving."
            return
        }

        viewModelScope.launch {
            _isSaving.value = true
            _saveError.value = null

            try {
                val userId = _uiState.value.user?.id ?: throw Exception("No user found")

                // Upload avatar if changed
                var newAvatarUrl = state.avatarUrl
                if (state.capturedAvatarBitmap != null) {
                    val bytes = bitmapToBytes(state.capturedAvatarBitmap)
                    newAvatarUrl = profileRepository.uploadAvatar(
                        userId, bytes, "avatar_${UUID.randomUUID()}.jpg"
                    )
                }
                // Note: For gallery URI, the app would need ContentResolver to read bytes.
                // That requires Context, which is typically handled in the Activity/Fragment layer.
                // For now, we handle the camera bitmap case directly.

                // Update health profile
                val existingProfile = _uiState.value.healthProfile
                val updatedProfile = HealthProfile(
                    id = existingProfile?.id,
                    userId = userId,
                    fullName = state.fullName,
                    gender = state.gender,
                    dateOfBirth = state.dateOfBirth.ifBlank { existingProfile?.dateOfBirth ?: "" },
                    heightCm = state.heightCm.toDoubleOrNull() ?: existingProfile?.heightCm ?: 0.0,
                    weightKg = state.weightKg.toDoubleOrNull() ?: existingProfile?.weightKg ?: 0.0,
                    bloodType = state.bloodType.ifBlank { null }
                )

                if (existingProfile != null) {
                    profileRepository.updateHealthProfile(updatedProfile)
                } else {
                    profileRepository.createHealthProfile(updatedProfile)
                }

                // Update user profile (name/phone/bio/avatar)
                profileRepository.updateUserProfile(
                    userId = userId,
                    fullName = state.fullName,
                    phone = state.phoneNumber.ifBlank { null },
                    bio = state.bio.ifBlank { null },
                    avatarUrl = newAvatarUrl
                )

                analyticsService.logEvent("profile_updated")

                // Refresh the display state
                _uiState.update {
                    it.copy(
                        healthProfile = updatedProfile,
                        user = it.user?.copy(
                            fullName = state.fullName,
                            avatarUrl = newAvatarUrl
                        )
                    )
                }

                _isSaving.value = false
                onSuccess()
            } catch (e: Exception) {
                _saveError.value = e.message ?: "Failed to save profile"
                _isSaving.value = false
            }
        }
    }

    private fun bitmapToBytes(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
        return stream.toByteArray()
    }

    // Computed Properties Helpers

    val memberSince: String
        get() {
            val dateStr = uiState.value.user?.createdAt ?: return "Unknown"
            // Handle ISO8601 string
            return try {
                // Simplistic parsing for demo
                val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                val date = inputFormat.parse(dateStr.take(19)) // Strip timezone for simple parsing if needed
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
                // Assuming format "yyyy-MM-dd"
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

    val appVersion: String = "1.0.0 (1)"
}
