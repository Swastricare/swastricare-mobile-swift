package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Remove a member from the family group.
 * Encapsulates business logic for removing family members.
 */
class RemoveMemberUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Remove a member from the family group.
     *
     * @param memberId Member ID to remove
     * @param requestingUserId User ID making the request (must be owner/admin)
     * @return Result
     */
    suspend operator fun invoke(
        memberId: String,
        requestingUserId: String
    ): ResultWrapper<Unit> {
        // Validation
        if (memberId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Member ID is required")
            )
        }

        if (requestingUserId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("User ID is required")
            )
        }

        // Check if user is trying to remove themselves
        if (memberId == requestingUserId) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom(
                    "Use 'Leave Group' to remove yourself from the family"
                )
            )
        }

        // Remove the member (permission check will be done in repository)
        return repository.removeMember(memberId, requestingUserId)
    }
}
