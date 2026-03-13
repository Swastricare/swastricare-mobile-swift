package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Update user profile information.
 */
class UpdateUserProfileUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Update user profile information.
     *
     * @param userId User ID
     * @param fullName Full name (null to keep existing)
     * @param phone Phone number (null to keep existing)
     * @param bio Bio text (null to keep existing)
     * @param avatarUrl Avatar URL (null to keep existing)
     * @return ResultWrapper indicating success or failure
     */
    suspend operator fun invoke(
        userId: String,
        fullName: String? = null,
        phone: String? = null,
        bio: String? = null,
        avatarUrl: String? = null
    ): ResultWrapper<Unit> {
        // Business validation: at least one field must be provided
        if (fullName == null && phone == null && bio == null && avatarUrl == null) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "At least one field must be provided for update."
                )
            )
        }

        return repository.updateUserProfile(
            userId = userId,
            fullName = fullName,
            phone = phone,
            bio = bio,
            avatarUrl = avatarUrl
        )
    }
}
