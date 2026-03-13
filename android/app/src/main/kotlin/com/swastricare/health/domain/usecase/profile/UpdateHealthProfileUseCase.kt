package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Update health profile.
 */
class UpdateHealthProfileUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Update an existing health profile.
     *
     * @param profile The health profile to update
     * @return ResultWrapper containing the updated profile
     */
    suspend operator fun invoke(profile: HealthProfile): ResultWrapper<HealthProfile> {
        // Business validation: ensure profile is complete
        if (!profile.isComplete()) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "Profile is incomplete. Name, height, and weight are required."
                )
            )
        }

        // Business validation: ensure valid measurements
        if (profile.heightCm < 50 || profile.heightCm > 300) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "Height must be between 50 and 300 cm."
                )
            )
        }

        if (profile.weightKg < 20 || profile.weightKg > 500) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "Weight must be between 20 and 500 kg."
                )
            )
        }

        return repository.updateHealthProfile(profile)
    }
}
