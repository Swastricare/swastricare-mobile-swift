package com.swasthicare.mobile.ui.screens.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.BuildConfig
import com.swasthicare.mobile.data.model.AppUser
import com.swasthicare.mobile.data.model.Gender
import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

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
 * Holds the mutable form state for the EditProfileScreen.
 * Mirrors the fields from iOS AccountView.
 */
data class EditProfileFormState(
    val name: String = "",
    val phone: String = "",
    val bio: String = "",
    val gender: Gender = Gender.PreferNotToSay,
    val dateOfBirth: String = "1999-01-01", // yyyy-MM-dd
    val heightCm: Double = 170.0,
    val weightKg: Double = 70.0,
    val bloodType: String = "",
    val city: String = "",
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val saveError: String? = null
)

class ProfileViewModel : ViewModel() {
    private val authRepository = AppContainer.authRepository
    private val profileRepository = AppContainer.profileRepository
    
    // Expose sign out event for navigation
    private val _signOutEvent = MutableStateFlow(false)
    val signOutEvent: StateFlow<Boolean> = _signOutEvent.asStateFlow()
    
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        loadUser()
        // Load settings from SharedPreferences (omitted for brevity, using defaults)
        _uiState.update {
            it.copy(
                notificationsEnabled = true,
                biometricEnabled = false,
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
                    // No authenticated user — show empty state (UI should prompt login)
                    _uiState.update { it.copy(user = null, isLoading = false) }
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
                
                _uiState.update {
                    it.copy(healthProfile = profile, isLoadingHealthProfile = false)
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
                    it.copy(errorMessage = "Account deletion not fully implemented on backend yet.", isLoading = false, showDeleteAccountConfirmation = false) 
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
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
    
    val appVersion: String = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    // ── Edit Profile ────────────────────────────────────────────────

    private val _editFormState = MutableStateFlow(EditProfileFormState())
    val editFormState: StateFlow<EditProfileFormState> = _editFormState.asStateFlow()

    /** Snapshot of the original form values, used for change detection. */
    private var originalFormState = EditProfileFormState()

    /**
     * Populates the edit form from the current user/healthProfile data.
     * Call this in `LaunchedEffect` when the EditProfileScreen appears.
     */
    fun initEditForm() {
        val user = uiState.value.user
        val hp = uiState.value.healthProfile
        val initial = EditProfileFormState(
            name = user?.fullName ?: hp?.fullName ?: "",
            phone = "", // AppUser doesn't have phone yet — will be populated when model is extended
            bio = "",   // Same — placeholder for future backend field
            gender = hp?.gender ?: Gender.PreferNotToSay,
            dateOfBirth = hp?.dateOfBirth ?: "1999-01-01",
            heightCm = hp?.heightCm ?: 170.0,
            weightKg = hp?.weightKg ?: 70.0,
            bloodType = hp?.bloodType ?: "",
            city = "",  // HealthProfile doesn't have city yet — placeholder
            isSaving = false,
            saveSuccess = false,
            saveError = null
        )
        originalFormState = initial
        _editFormState.value = initial
    }

    // ── Individual field updaters ──

    fun updateEditName(value: String) {
        _editFormState.update { it.copy(name = value) }
    }

    fun updateEditPhone(value: String) {
        _editFormState.update { it.copy(phone = value) }
    }

    fun updateEditBio(value: String) {
        _editFormState.update { it.copy(bio = value) }
    }

    fun updateEditGender(value: Gender) {
        _editFormState.update { it.copy(gender = value) }
    }

    fun updateEditDateOfBirth(value: String) {
        _editFormState.update { it.copy(dateOfBirth = value) }
    }

    fun updateEditHeightCm(value: Double) {
        _editFormState.update { it.copy(heightCm = value) }
    }

    fun updateEditWeightKg(value: Double) {
        _editFormState.update { it.copy(weightKg = value) }
    }

    fun updateEditBloodType(value: String) {
        _editFormState.update { it.copy(bloodType = value) }
    }

    fun updateEditCity(value: String) {
        _editFormState.update { it.copy(city = value) }
    }

    /** True when the form has been modified relative to original loaded values. */
    val hasEditChanges: Boolean
        get() {
            val current = _editFormState.value
            return current.name != originalFormState.name
                || current.phone != originalFormState.phone
                || current.bio != originalFormState.bio
                || current.gender != originalFormState.gender
                || current.dateOfBirth != originalFormState.dateOfBirth
                || current.heightCm != originalFormState.heightCm
                || current.weightKg != originalFormState.weightKg
                || current.bloodType != originalFormState.bloodType
                || current.city != originalFormState.city
        }

    /** True when the name is non-blank (minimum valid form). */
    val isEditFormValid: Boolean
        get() = _editFormState.value.name.isNotBlank()

    fun clearSaveResult() {
        _editFormState.update { it.copy(saveSuccess = false, saveError = null) }
    }

    /**
     * Persists the edited profile via the repository.
     * Updates both the user profile (name) and health profile (body stats etc.).
     */
    fun saveEditProfile() {
        viewModelScope.launch {
            _editFormState.update { it.copy(isSaving = true, saveError = null) }

            try {
                val form = _editFormState.value
                val userId = uiState.value.user?.id ?: throw IllegalStateException("No user ID")

                // Build updated health profile
                val existingHp = uiState.value.healthProfile
                val updatedProfile = HealthProfile(
                    id = existingHp?.id,
                    userId = userId,
                    fullName = form.name.trim(),
                    gender = form.gender,
                    dateOfBirth = form.dateOfBirth,
                    heightCm = form.heightCm,
                    weightKg = form.weightKg,
                    bloodType = form.bloodType.ifBlank { null },
                    createdAt = existingHp?.createdAt,
                    updatedAt = null
                )

                val result = if (existingHp != null) {
                    profileRepository.updateHealthProfile(updatedProfile)
                } else {
                    profileRepository.createHealthProfile(updatedProfile)
                }

                result.getOrThrow()

                // Snapshot becomes the new original so hasChanges resets
                originalFormState = form.copy(isSaving = false, saveSuccess = true, saveError = null)
                _editFormState.update { it.copy(isSaving = false, saveSuccess = true) }

                // Refresh the main profile state so ProfileScreen reflects changes
                loadHealthProfile(userId)
            } catch (e: Exception) {
                _editFormState.update {
                    it.copy(
                        isSaving = false,
                        saveError = "Failed to save: ${e.localizedMessage ?: "Unknown error"}"
                    )
                }
            }
        }
    }

    fun computeBmi(heightCm: Double, weightKg: Double): Double {
        val heightM = heightCm / 100.0
        return if (heightM > 0) weightKg / (heightM * heightM) else 0.0
    }

    fun bmiCategory(bmi: Double): String = when {
        bmi < 18.5 -> "Underweight"
        bmi < 25.0 -> "Normal"
        bmi < 30.0 -> "Overweight"
        else -> "Obese"
    }
}
