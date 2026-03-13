package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.UserSettings
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Get user settings.
 */
class GetUserSettingsUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Get user settings from local storage.
     *
     * @return ResultWrapper containing user settings or default if not found
     */
    suspend operator fun invoke(): ResultWrapper<UserSettings> {
        return repository.getUserSettings()
    }
}
