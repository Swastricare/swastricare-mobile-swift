package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyInvitation
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Generate an invitation code for a family group.
 * Encapsulates business logic for creating family invitations.
 */
class InviteMemberUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Generate a new invite code for the family group.
     *
     * @param groupId Group ID
     * @param requestingUserId User ID making the request (must be owner/admin)
     * @return Result with FamilyInvitation
     */
    suspend operator fun invoke(
        groupId: String,
        requestingUserId: String
    ): ResultWrapper<FamilyInvitation> {
        // Validation
        if (groupId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Group ID is required")
            )
        }

        if (requestingUserId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("User ID is required")
            )
        }

        // Verify requesting user is a member with permission
        when (val membersResult = repository.getMembers(groupId)) {
            is ResultWrapper.Success -> {
                val requestingMember = membersResult.data.firstOrNull {
                    it.userId == requestingUserId
                }

                if (requestingMember == null) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom(
                            "You are not a member of this family group"
                        )
                    )
                }

                if (!requestingMember.canGenerateInvites) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom(
                            "Only owners and admins can generate invite codes"
                        )
                    )
                }
            }
            is ResultWrapper.Error -> return membersResult
            is ResultWrapper.Loading -> {
                // Should not happen
            }
        }

        // Generate the invite code
        return repository.generateInviteCode(groupId)
    }
}
