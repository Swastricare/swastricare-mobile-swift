package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Leave a family group.
 * Encapsulates business logic for leaving family groups.
 */
class LeaveFamilyGroupUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Leave the current family group.
     *
     * @param memberId Member ID to remove
     * @param groupId Group ID to verify ownership
     * @return Result
     */
    suspend operator fun invoke(
        memberId: String,
        groupId: String
    ): ResultWrapper<Unit> {
        // Validation
        if (memberId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Member ID is required")
            )
        }

        if (groupId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Group ID is required")
            )
        }

        // Get group members to check if user is the owner
        when (val membersResult = repository.getMembers(groupId)) {
            is ResultWrapper.Success -> {
                val members = membersResult.data
                val leavingMember = members.firstOrNull { it.id == memberId }

                if (leavingMember == null) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom(
                            "You are not a member of this family group"
                        )
                    )
                }

                // If owner is leaving and there are other members, prevent leaving
                if (leavingMember.isOwner && members.size > 1) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom(
                            "Transfer ownership to another member before leaving the group"
                        )
                    )
                }
            }
            is ResultWrapper.Error -> return membersResult
            is ResultWrapper.Loading -> {
                // Should not happen
            }
        }

        // Leave the group
        return repository.leaveGroup(memberId)
    }
}
