package com.swastricare.health.presentation.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.BuildConfig
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.usecase.profile.CreateHealthProfileUseCase
import com.swastricare.health.domain.usecase.profile.GetHealthProfileUseCase
import com.swastricare.health.domain.usecase.profile.GetUserProfileUseCase
import com.swastricare.health.domain.usecase.profile.GetUserSettingsUseCase
import com.swastricare.health.domain.usecase.profile.UpdateHealthProfileUseCase
import com.swastricare.health.domain.usecase.profile.UpdateUserSettingsUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

/**
 * ViewModel for Profile screen using Clean Architecture with Hilt DI.
 */
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val getUserProfileUseCase: GetUserProfileUseCase,
    private val getHealthProfileUseCase: GetHealthProfileUseCase,
    private val updateHealthProfileUseCase: UpdateHealthProfileUseCase,
    private val createHealthProfileUseCase: CreateHealthProfileUseCase,
    private val getUserSettingsUseCase: GetUserSettingsUseCase,
    private val updateUserSettingsUseCase: UpdateUserSettingsUseCase
) : ViewModel() {

    // ── State ──

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    private val _editFormState = MutableStateFlow(EditProfileFormState())
    val editFormState: StateFlow<EditProfileFormState> = _editFormState.asStateFlow()

    // Snapshot of the original form values for change detection
    private var originalFormState = EditProfileFormState()

    // Events
    private val _signOutEvent = MutableSharedFlow<Unit>()
    val signOutEvent = _signOutEvent.asSharedFlow()

    // ── Init ──

    init {
        loadProfile()
        loadSettings()
    }

    // ── Public API ──

    fun handleEvent(event: ProfileUiEvent) {
        when (event) {
            ProfileUiEvent.LoadProfile -> loadProfile()
            ProfileUiEvent.RefreshHealthProfile -> refreshHealthProfile()
            is ProfileUiEvent.ToggleNotifications -> toggleNotifications(event.enabled)
            is ProfileUiEvent.ToggleBiometric -> toggleBiometric(event.enabled)
            is ProfileUiEvent.ToggleHealthSync -> toggleHealthSync(event.enabled)
            ProfileUiEvent.ShowSignOutConfirmation -> setShowSignOutConfirmation(true)
            ProfileUiEvent.HideSignOutConfirmation -> setShowSignOutConfirmation(false)
            ProfileUiEvent.ShowDeleteAccountConfirmation -> setShowDeleteAccountConfirmation(true)
            ProfileUiEvent.HideDeleteAccountConfirmation -> setShowDeleteAccountConfirmation(false)
            ProfileUiEvent.SignOut -> signOut()
            ProfileUiEvent.DeleteAccount -> deleteAccount()
            ProfileUiEvent.ClearError -> clearError()
        }
    }

    fun handleEditEvent(event: EditProfileUiEvent) {
        when (event) {
            EditProfileUiEvent.InitForm -> initEditForm()
            is EditProfileUiEvent.UpdateName -> updateEditName(event.value)
            is EditProfileUiEvent.UpdatePhone -> updateEditPhone(event.value)
            is EditProfileUiEvent.UpdateBio -> updateEditBio(event.value)
            is EditProfileUiEvent.UpdateGender -> updateEditGender(event.value)
            is EditProfileUiEvent.UpdateDateOfBirth -> updateEditDateOfBirth(event.value)
            is EditProfileUiEvent.UpdateHeightCm -> updateEditHeightCm(event.value)
            is EditProfileUiEvent.UpdateWeightKg -> updateEditWeightKg(event.value)
            is EditProfileUiEvent.UpdateBloodType -> updateEditBloodType(event.value)
            is EditProfileUiEvent.UpdateCity -> updateEditCity(event.value)
            EditProfileUiEvent.SaveProfile -> saveEditProfile()
            EditProfileUiEvent.ClearSaveResult -> clearSaveResult()
        }
    }

    // ── Computed Properties ──

    val appVersion: String = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    val hasEditChanges: Boolean
        get() {
            val current = _editFormState.value
            return current.name != originalFormState.name ||
                    current.phone != originalFormState.phone ||
                    current.bio != originalFormState.bio ||
                    current.gender != originalFormState.gender ||
                    current.dateOfBirth != originalFormState.dateOfBirth ||
                    current.heightCm != originalFormState.heightCm ||
                    current.weightKg != originalFormState.weightKg ||
                    current.bloodType != originalFormState.bloodType ||
                    current.city != originalFormState.city
        }

    // ── Private Methods ──

    private fun loadProfile() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            try {
                val user = authRepository.getCurrentUser()

                if (user != null) {
                    // Load user profile
                    when (val userProfileResult = getUserProfileUseCase(user.id)) {
                        is ResultWrapper.Success -> {
                            _uiState.update {
                                it.copy(
                                    userProfile = userProfileResult.data,
                                    isLoading = false
                                )
                            }
                            // Load health profile
                            loadHealthProfile(user.id)
                        }
                        is ResultWrapper.Error -> {
                            _uiState.update {
                                it.copy(
                                    errorMessage = userProfileResult.exception.message,
                                    isLoading = false
                                )
                            }
                        }
                        else -> {
                            _uiState.update { it.copy(isLoading = false) }
                        }
                    }
                } else {
                    _uiState.update { it.copy(userProfile = null, isLoading = false) }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.message, isLoading = false) }
            }
        }
    }

    private fun loadHealthProfile(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingHealthProfile = true) }

            when (val result = getHealthProfileUseCase(userId)) {
                is ResultWrapper.Success -> {
                    _uiState.update {
                        it.copy(
                            healthProfile = result.data,
                            isLoadingHealthProfile = false
                        )
                    }
                }
                is ResultWrapper.Error -> {
                    _uiState.update { it.copy(isLoadingHealthProfile = false) }
                }
                else -> {
                    _uiState.update { it.copy(isLoadingHealthProfile = false) }
                }
            }
        }
    }

    private fun refreshHealthProfile() {
        viewModelScope.launch {
            val userId = authRepository.getCurrentUser()?.id ?: return@launch
            loadHealthProfile(userId)
        }
    }

    private fun loadSettings() {
        viewModelScope.launch {
            when (val result = getUserSettingsUseCase()) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(settings = result.data) }
                }
                is ResultWrapper.Error -> {
                    // Use default settings on error
                }
                else -> {}
            }
        }
    }

    private fun toggleNotifications(enabled: Boolean) {
        viewModelScope.launch {
            val newSettings = _uiState.value.settings.copy(notificationsEnabled = enabled)
            _uiState.update { it.copy(settings = newSettings) }
            updateUserSettingsUseCase(newSettings)
        }
    }

    private fun toggleBiometric(enabled: Boolean) {
        viewModelScope.launch {
            val newSettings = _uiState.value.settings.copy(biometricLockEnabled = enabled)
            _uiState.update { it.copy(settings = newSettings) }
            updateUserSettingsUseCase(newSettings)
        }
    }

    private fun toggleHealthSync(enabled: Boolean) {
        viewModelScope.launch {
            val newSettings = _uiState.value.settings.copy(healthSyncEnabled = enabled)
            _uiState.update { it.copy(settings = newSettings) }
            updateUserSettingsUseCase(newSettings)
        }
    }

    private fun setShowSignOutConfirmation(show: Boolean) {
        _uiState.update { it.copy(showSignOutConfirmation = show) }
    }

    private fun setShowDeleteAccountConfirmation(show: Boolean) {
        _uiState.update { it.copy(showDeleteAccountConfirmation = show) }
    }

    private fun signOut() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                authRepository.signOut()
                _uiState.update {
                    it.copy(
                        userProfile = null,
                        healthProfile = null,
                        isLoading = false,
                        showSignOutConfirmation = false
                    )
                }
                _signOutEvent.emit(Unit)
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.message, isLoading = false) }
            }
        }
    }

    private fun deleteAccount() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                authRepository.deleteAccount()
                _uiState.update {
                    it.copy(
                        userProfile = null,
                        healthProfile = null,
                        isLoading = false,
                        showDeleteAccountConfirmation = false
                    )
                }
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

    private fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    // ── Edit Profile ──

    private fun initEditForm() {
        val userProfile = _uiState.value.userProfile
        val healthProfile = _uiState.value.healthProfile
        val initial = EditProfileFormState(
            name = userProfile?.fullName ?: healthProfile?.fullName ?: "",
            phone = userProfile?.phone ?: "",
            bio = userProfile?.bio ?: "",
            gender = healthProfile?.gender ?: com.swastricare.health.domain.model.profile.Gender.PREFER_NOT_TO_SAY,
            dateOfBirth = healthProfile?.getFormattedDateOfBirth() ?: "1999-01-01",
            heightCm = healthProfile?.heightCm ?: 170.0,
            weightKg = healthProfile?.weightKg ?: 70.0,
            bloodType = healthProfile?.bloodType ?: "",
            city = "",
            isSaving = false,
            saveSuccess = false,
            saveError = null
        )
        originalFormState = initial
        _editFormState.value = initial
    }

    private fun updateEditName(value: String) {
        _editFormState.update { it.copy(name = value) }
    }

    private fun updateEditPhone(value: String) {
        _editFormState.update { it.copy(phone = value) }
    }

    private fun updateEditBio(value: String) {
        _editFormState.update { it.copy(bio = value) }
    }

    private fun updateEditGender(value: com.swastricare.health.domain.model.profile.Gender) {
        _editFormState.update { it.copy(gender = value) }
    }

    private fun updateEditDateOfBirth(value: String) {
        _editFormState.update { it.copy(dateOfBirth = value) }
    }

    private fun updateEditHeightCm(value: Double) {
        _editFormState.update { it.copy(heightCm = value) }
    }

    private fun updateEditWeightKg(value: Double) {
        _editFormState.update { it.copy(weightKg = value) }
    }

    private fun updateEditBloodType(value: String) {
        _editFormState.update { it.copy(bloodType = value) }
    }

    private fun updateEditCity(value: String) {
        _editFormState.update { it.copy(city = value) }
    }

    private fun clearSaveResult() {
        _editFormState.update { it.copy(saveSuccess = false, saveError = null) }
    }

    private fun saveEditProfile() {
        viewModelScope.launch {
            _editFormState.update { it.copy(isSaving = true, saveError = null) }

            try {
                val form = _editFormState.value
                val userId = authRepository.getCurrentUser()?.id
                    ?: throw IllegalStateException("No user ID")

                // Parse date of birth
                val dateOfBirth = try {
                    LocalDate.parse(form.dateOfBirth)
                } catch (e: Exception) {
                    LocalDate.now()
                }

                // Build updated health profile
                val existingHp = _uiState.value.healthProfile
                val updatedProfile = HealthProfile(
                    id = existingHp?.id ?: "",
                    userId = userId,
                    fullName = form.name.trim(),
                    gender = form.gender,
                    dateOfBirth = dateOfBirth,
                    heightCm = form.heightCm,
                    weightKg = form.weightKg,
                    bloodType = form.bloodType.ifBlank { null }
                )

                val result = if (existingHp != null) {
                    updateHealthProfileUseCase(updatedProfile)
                } else {
                    createHealthProfileUseCase(updatedProfile)
                }

                when (result) {
                    is ResultWrapper.Success -> {
                        originalFormState = form.copy(isSaving = false, saveSuccess = true, saveError = null)
                        _editFormState.update { it.copy(isSaving = false, saveSuccess = true) }
                        refreshHealthProfile()
                    }
                    is ResultWrapper.Error -> {
                        _editFormState.update {
                            it.copy(
                                isSaving = false,
                                saveError = result.exception.message
                                    ?: "Failed to save profile"
                            )
                        }
                    }
                    else -> {
                        _editFormState.update { it.copy(isSaving = false) }
                    }
                }
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
}
