package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for sharing a medical document with a family member.
 * Encapsulates the business logic for document sharing.
 *
 * Single Responsibility: Handle document sharing
 */
class ShareDocumentUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Execute document sharing.
     * @param documentId ID of the document to share
     * @param recipientProfileId Health profile ID of the recipient
     * @return Unit wrapped in ResultWrapper
     */
    suspend operator fun invoke(
        documentId: String,
        recipientProfileId: String
    ): ResultWrapper<Unit> {
        if (documentId.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Document ID cannot be blank"))
        }

        if (recipientProfileId.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Recipient profile ID cannot be blank"))
        }

        return vaultRepository.shareDocument(
            documentId = documentId,
            recipientProfileId = recipientProfileId
        )
    }
}
