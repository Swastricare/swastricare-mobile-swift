package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Accept a family invitation and join a group.
 * Encapsulates business logic for joining family groups via invite codes.
 */
class AcceptInvitationUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Accept an invitation and join the family group.
     *
     * @param inviteCode Invitation code
     * @param userId User ID
     * @param fullName User's full name
     * @return Result with joined FamilyGroup
     */
    suspend operator fun invoke(
        inviteCode: String,
        userId: String,
        fullName: String? = null
    ): ResultWrapper<FamilyGroup> {
        // Validation
        if (inviteCode.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Invite code cannot be empty")
            )
        }

        if (inviteCode.length < 6) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Invalid invite code format")
            )
        }

        if (userId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("User ID is required")
            )
        }

        // Validate invite code
        when (val validationResult = repository.validateInviteCode(inviteCode.trim().uppercase())) {
            is ResultWrapper.Success -> {
                val invitation = validationResult.data
                if (invitation.isExpired) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom("This invite code has expired")
                    )
                }
            }
            is ResultWrapper.Error -> return validationResult
            is ResultWrapper.Loading -> {
                // Should not happen
            }
        }

        // Check if user is already in a family group
        when (val existingGroup = repository.getMyFamilyGroup(userId)) {
            is ResultWrapper.Success -> {
                if (existingGroup.data != null) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom(
                            "You are already a member of a family group. Please leave it first."
                        )
                    )
                }
            }
            is ResultWrapper.Error -> {
                // If error checking existing group, continue (might not exist)
            }
            is ResultWrapper.Loading -> {
                // Should not happen
            }
        }

        // Join the group
        return repository.joinGroup(inviteCode.trim().uppercase(), userId, fullName)
    }
}
