package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for downloading a medical document.
 * Encapsulates the business logic for document download.
 *
 * Single Responsibility: Handle document download
 */
class DownloadDocumentUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Execute document download.
     * @param documentId ID of the document to download
     * @return Binary file data wrapped in ResultWrapper
     */
    suspend operator fun invoke(documentId: String): ResultWrapper<ByteArray> {
        if (documentId.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Document ID cannot be blank"))
        }

        return vaultRepository.downloadDocument(documentId)
    }
}
