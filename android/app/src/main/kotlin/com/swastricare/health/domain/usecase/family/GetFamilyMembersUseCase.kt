package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Get all members of a family group.
 * Encapsulates business logic for retrieving family members.
 */
class GetFamilyMembersUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Get all members of a family group.
     *
     * @param groupId Group ID
     * @param requestingUserId User ID making the request
     * @return Result with list of FamilyMembers
     */
    suspend operator fun invoke(
        groupId: String,
        requestingUserId: String
    ): ResultWrapper<List<FamilyMember>> {
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

        // Get members
        when (val result = repository.getMembers(groupId)) {
            is ResultWrapper.Success -> {
                val members = result.data

                // Verify requesting user is a member of the group
                val isMember = members.any { it.userId == requestingUserId }
                if (!isMember) {
                    return ResultWrapper.Error(
                        AppException.ValidationException.Custom(
                            "You are not a member of this family group"
                        )
                    )
                }

                // Sort members: Owner first, then Admins, then Members
                val sortedMembers = members.sortedWith(
                    compareBy(
                        { it.role.ordinal },
                        { it.joinedAt }
                    )
                )

                return ResultWrapper.Success(sortedMembers)
            }
            is ResultWrapper.Error -> return result
            is ResultWrapper.Loading -> return ResultWrapper.Loading
        }
    }
}
