package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.vault.DocumentCategory
import javax.inject.Inject

/**
 * Use case for getting available document categories.
 * Encapsulates business logic for category retrieval.
 *
 * Single Responsibility: Handle category enumeration
 */
class GetCategoriesUseCase @Inject constructor() {
    /**
     * Get all available document categories.
     * @return List of DocumentCategory wrapped in ResultWrapper
     */
    operator fun invoke(): ResultWrapper<List<DocumentCategory>> {
        return ResultWrapper.Success(DocumentCategory.entries.toList())
    }
}
