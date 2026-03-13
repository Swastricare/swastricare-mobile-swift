package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.HydrationRepository
import javax.inject.Inject

/**
 * Use case: Delete a hydration entry.
 */
class DeleteHydrationEntryUseCase @Inject constructor(
    private val repository: HydrationRepository
) {
    /**
     * Delete a hydration entry by ID.
     *
     * @param entryId The ID of the entry to delete
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(entryId: String): ResultWrapper<Unit> {
        // Validation
        if (entryId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Entry ID cannot be empty")
            )
        }

        // Delete from local storage
        return repository.deleteLocalEntry(entryId)
    }

    /**
     * Delete a hydration entry and also remove from cloud.
     *
     * @param entryId The ID of the entry to delete
     * @return Result indicating success or failure
     */
    suspend fun deleteFromBoth(entryId: String): ResultWrapper<Unit> {
        if (entryId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Entry ID cannot be empty")
            )
        }

        // Delete from local first
        when (val localResult = repository.deleteLocalEntry(entryId)) {
            is ResultWrapper.Error -> return localResult
            else -> {}
        }

        // Then delete from cloud (best effort)
        repository.deleteCloudEntry(entryId)

        return ResultWrapper.Success(Unit)
    }
}
