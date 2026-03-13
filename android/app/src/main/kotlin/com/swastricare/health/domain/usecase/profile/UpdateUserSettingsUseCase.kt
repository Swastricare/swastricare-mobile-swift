package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.UserSettings
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Update user settings.
 */
class UpdateUserSettingsUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Save user settings to local storage.
     *
     * @param settings The settings to save
     * @return ResultWrapper indicating success or failure
     */
    suspend operator fun invoke(settings: UserSettings): ResultWrapper<Unit> {
        return repository.saveUserSettings(settings)
    }
}
