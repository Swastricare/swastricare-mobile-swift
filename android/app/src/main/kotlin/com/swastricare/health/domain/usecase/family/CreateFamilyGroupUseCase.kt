package com.swastricare.health.domain.usecase.family

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.repository.FamilyRepository
import javax.inject.Inject

/**
 * Use case: Create a new family group.
 * Encapsulates business logic for creating family groups.
 */
class CreateFamilyGroupUseCase @Inject constructor(
    private val repository: FamilyRepository
) {
    /**
     * Create a new family group.
     *
     * @param name Group name
     * @param userId Creator user ID
     * @return Result with created FamilyGroup
     */
    suspend operator fun invoke(
        name: String,
        userId: String
    ): ResultWrapper<FamilyGroup> {
        // Validation
        if (name.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Group name cannot be empty")
            )
        }

        if (name.length < 2) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Group name must be at least 2 characters")
            )
        }

        if (name.length > 50) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Group name cannot exceed 50 characters")
            )
        }

        if (userId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("User ID is required")
            )
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

        // Create the family group
        return repository.createFamilyGroup(name.trim(), userId)
    }
}
