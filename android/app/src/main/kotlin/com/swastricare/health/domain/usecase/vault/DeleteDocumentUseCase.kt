package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for deleting a medical document.
 * Encapsulates the business logic for document deletion.
 *
 * Single Responsibility: Handle document deletion
 */
class DeleteDocumentUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Execute document deletion.
     * @param documentId ID of the document to delete
     * @return Unit wrapped in ResultWrapper
     */
    suspend operator fun invoke(documentId: String): ResultWrapper<Unit> {
        if (documentId.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Document ID cannot be blank"))
        }

        return vaultRepository.deleteDocument(documentId)
    }

    /**
     * Execute multiple document deletions.
     * @param documentIds List of document IDs to delete
     * @return Unit wrapped in ResultWrapper
     */
    suspend operator fun invoke(documentIds: List<String>): ResultWrapper<Unit> {
        if (documentIds.isEmpty()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("No documents selected for deletion"))
        }

        if (documentIds.any { it.isBlank() }) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Invalid document ID in selection"))
        }

        return vaultRepository.deleteDocuments(documentIds)
    }
}
