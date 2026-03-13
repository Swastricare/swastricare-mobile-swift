package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for getting a signed URL to access a document file.
 * Encapsulates business logic for secure file access.
 *
 * Single Responsibility: Handle signed URL generation
 */
class GetSignedUrlUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Get signed URL for a document file path.
     * @param path Storage path of the document
     * @return Signed URL string wrapped in ResultWrapper
     */
    suspend operator fun invoke(path: String): ResultWrapper<String> {
        if (path.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("File path cannot be blank"))
        }

        return vaultRepository.getSignedUrl(path)
    }
}
