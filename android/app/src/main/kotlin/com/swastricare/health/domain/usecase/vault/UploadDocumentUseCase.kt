package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for uploading a medical document.
 * Encapsulates business logic and validation for document upload.
 *
 * Single Responsibility: Handle document upload flow
 */
class UploadDocumentUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Execute document upload.
     * @param fileData Binary file data
     * @param fileName Original file name
     * @param category Document category
     * @param metadata Additional document metadata
     * @return Uploaded MedicalDocument wrapped in ResultWrapper
     */
    suspend operator fun invoke(
        fileData: ByteArray,
        fileName: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): ResultWrapper<MedicalDocument> {
        // Business validation
        if (fileData.isEmpty()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("File data cannot be empty"))
        }

        if (fileName.isBlank()) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("File name cannot be blank"))
        }

        // Validate file size (max 50MB)
        val maxSize = 50 * 1024 * 1024 // 50MB
        if (fileData.size > maxSize) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("File size exceeds maximum allowed size of 50MB"))
        }

        return vaultRepository.uploadDocument(
            fileData = fileData,
            fileName = fileName,
            category = category,
            metadata = metadata
        )
    }
}
