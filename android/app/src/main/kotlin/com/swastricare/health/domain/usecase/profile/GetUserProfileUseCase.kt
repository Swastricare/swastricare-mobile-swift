package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.UserProfile
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Get user profile.
 */
class GetUserProfileUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Get user profile by user ID.
     *
     * @param userId The user ID to fetch profile for
     * @return ResultWrapper containing the user profile or null if not found
     */
    suspend operator fun invoke(userId: String): ResultWrapper<UserProfile?> {
        return repository.getUserProfile(userId)
    }
}
