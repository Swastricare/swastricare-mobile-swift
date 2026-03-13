package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for updating a medical document's metadata.
 * Encapsulates business logic for document updates.
 *
 * Single Responsibility: Handle document metadata updates
 */
class UpdateDocumentUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Execute document metadata update.
     * @param documentId ID of the document to update
     * @param title New document title
     * @param category New document category
     * @param metadata Updated metadata
     * @return Updated MedicalDocument wrapped in ResultWrapper
     */
    suspend operator fun invoke(
        documentId: String,
        title: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): ResultWrapper<MedicalDocument> {
        if (documentId.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Document ID cannot be blank"))
        }

        if (title.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Title cannot be blank"))
        }

        return vaultRepository.updateDocument(
            documentId = documentId,
            title = title,
            category = category,
            metadata = metadata
        )
    }
}
