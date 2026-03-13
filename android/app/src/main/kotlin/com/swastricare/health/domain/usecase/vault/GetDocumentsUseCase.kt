package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.vault.MedicalDocument
import com.swastricare.health.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Use case for retrieving all medical documents.
 * Encapsulates the business logic for fetching documents.
 *
 * Single Responsibility: Handle document retrieval
 */
class GetDocumentsUseCase @Inject constructor(
    private val vaultRepository: VaultRepository
) {
    /**
     * Execute retrieval of all documents.
     * @return List of MedicalDocument wrapped in ResultWrapper
     */
    suspend operator fun invoke(): ResultWrapper<List<MedicalDocument>> {
        return vaultRepository.getDocuments()
    }
}
