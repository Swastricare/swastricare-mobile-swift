package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyPermissions
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Update permissions for a family member.
 * Encapsulates business logic for managing family member permissions.
 */
class UpdatePermissionsUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Update permissions for a family member.
     *
     * @param permissions Updated permissions
     * @param requestingUserId User ID making the request (must be owner/admin)
     * @return Result
     */
    suspend operator fun invoke(
        permissions: FamilyPermissions,
        requestingUserId: String
    ): ResultWrapper<Unit> {
        // Validation
        if (permissions.memberId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Member ID is required")
            )
        }

        if (requestingUserId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("User ID is required")
            )
        }

        // Verify requesting user has permission to update permissions
        // This will be checked in the repository implementation based on role

        // Update permissions
        return repository.updateMemberPermissions(permissions, requestingUserId)
    }
}
