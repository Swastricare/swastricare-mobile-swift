package com.swasthicare.mobile.ui.screens.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.model.AppUser
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

class ProfileViewModel : ViewModel() {
    private val authRepository = AppContainer.authRepository
    private val profileRepository = AppContainer.profileRepository
    
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
                        gender = com.swasthicare.mobile.data.model.Gender.Male,
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
                // Navigate to Auth screen logic would be here (usually via a higher level state)
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.message, isLoading = false) }
            }
        }
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
    
    val appVersion: String = "1.0.0 (1)"
}
