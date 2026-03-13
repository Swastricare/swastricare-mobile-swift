package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Get health profile for a user.
 */
class GetHealthProfileUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Get health profile by user ID.
     *
     * @param userId The user ID to fetch profile for
     * @return ResultWrapper containing the health profile or null if not found
     */
    suspend operator fun invoke(userId: String): ResultWrapper<HealthProfile?> {
        return repository.getHealthProfile(userId)
    }
}
