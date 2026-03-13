package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Create a new health profile.
 */
class CreateHealthProfileUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Create a new health profile.
     *
     * @param profile The health profile to create
     * @return ResultWrapper containing the created profile
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

        return repository.createHealthProfile(profile)
    }
}
