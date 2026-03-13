package com.swastricare.health.presentation.feature.profile

import com.swastricare.health.domain.model.profile.Gender
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.model.profile.UserProfile
import com.swastricare.health.domain.model.profile.UserSettings

/**
 * UI state for Profile screen.
 */
data class ProfileUiState(
    val userProfile: UserProfile? = null,
    val healthProfile: HealthProfile? = null,
    val settings: UserSettings = UserSettings.Default,
    val isLoading: Boolean = false,
    val isLoadingHealthProfile: Boolean = false,
    val errorMessage: String? = null,
    val showSignOutConfirmation: Boolean = false,
    val showDeleteAccountConfirmation: Boolean = false
) {
    /**
     * Get computed member since date.
     */
    fun getMemberSince(): String = userProfile?.getMemberSince() ?: "Unknown"

    /**
     * Get computed age.
     */
    fun getAge(): String = healthProfile?.let { "${it.calculateAge()} years" } ?: "Not set"

    /**
     * Get computed BMI.
     */
    fun getBmi(): String = healthProfile?.let { "%.1f".format(it.calculateBmi()) } ?: "Not set"

    /**
     * Get BMI category.
     */
    fun getBmiCategory(): String = healthProfile?.getBmiCategory()?.displayName ?: ""

    /**
     * Check if both profiles are loaded.
     */
    fun isProfileComplete(): Boolean = userProfile != null && healthProfile != null
}

/**
 * UI state for Edit Profile screen.
 */
data class EditProfileFormState(
    val name: String = "",
    val phone: String = "",
    val bio: String = "",
    val gender: Gender = Gender.PREFER_NOT_TO_SAY,
    val dateOfBirth: String = "1999-01-01", // yyyy-MM-dd
    val heightCm: Double = 170.0,
    val weightKg: Double = 70.0,
    val bloodType: String = "",
    val city: String = "",
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val saveError: String? = null
) {
    /**
     * Check if form is valid.
     */
    fun isValid(): Boolean = name.isNotBlank()

    /**
     * Get computed BMI preview.
     */
    fun getBmiPreview(): Double {
        val heightM = heightCm / 100.0
        return if (heightM > 0) weightKg / (heightM * heightM) else 0.0
    }

    /**
     * Get BMI category preview.
     */
    fun getBmiCategoryPreview(): String = when {
        getBmiPreview() < 18.5 -> "Underweight"
        getBmiPreview() < 25.0 -> "Normal"
        getBmiPreview() < 30.0 -> "Overweight"
        else -> "Obese"
    }
}

/**
 * UI events for Profile screen.
 */
sealed class ProfileUiEvent {
    data object LoadProfile : ProfileUiEvent()
    data object RefreshHealthProfile : ProfileUiEvent()
    data class ToggleNotifications(val enabled: Boolean) : ProfileUiEvent()
    data class ToggleBiometric(val enabled: Boolean) : ProfileUiEvent()
    data class ToggleHealthSync(val enabled: Boolean) : ProfileUiEvent()
    data object ShowSignOutConfirmation : ProfileUiEvent()
    data object HideSignOutConfirmation : ProfileUiEvent()
    data object ShowDeleteAccountConfirmation : ProfileUiEvent()
    data object HideDeleteAccountConfirmation : ProfileUiEvent()
    data object SignOut : ProfileUiEvent()
    data object DeleteAccount : ProfileUiEvent()
    data object ClearError : ProfileUiEvent()
}

/**
 * UI events for Edit Profile screen.
 */
sealed class EditProfileUiEvent {
    data object InitForm : EditProfileUiEvent()
    data class UpdateName(val value: String) : EditProfileUiEvent()
    data class UpdatePhone(val value: String) : EditProfileUiEvent()
    data class UpdateBio(val value: String) : EditProfileUiEvent()
    data class UpdateGender(val value: Gender) : EditProfileUiEvent()
    data class UpdateDateOfBirth(val value: String) : EditProfileUiEvent()
    data class UpdateHeightCm(val value: Double) : EditProfileUiEvent()
    data class UpdateWeightKg(val value: Double) : EditProfileUiEvent()
    data class UpdateBloodType(val value: String) : EditProfileUiEvent()
    data class UpdateCity(val value: String) : EditProfileUiEvent()
    data object SaveProfile : EditProfileUiEvent()
    data object ClearSaveResult : EditProfileUiEvent()
}
