package com.swastricare.health.presentation.feature.vault

import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.MedicalDocument

/**
 * UI state for Vault screen.
 * Represents all UI-related state for document management.
 */
data class VaultUiState(
    val documents: List<MedicalDocument> = emptyList(),
    val isLoading: Boolean = false,
    val isUploading: Boolean = false,
    val uploadProgress: Float = 0f, // 0 to 1
    val errorMessage: String? = null,
    val selectedCategory: DocumentCategory? = null,
    val searchQuery: String = "",
    val viewMode: VaultViewMode = VaultViewMode.LIST,
    val selectedDocuments: Set<String> = emptySet(),
    val isSelectionMode: Boolean = false,
    val showAddSheet: Boolean = false,
    val selectedDocumentDetail: MedicalDocument? = null,
    val showBatchUploadPreview: Boolean = false,
    val batchUploadItems: List<BatchUploadItem> = emptyList(),
    val openFolderName: String? = null,
    val aiAnalysisResult: String? = null,
    val isAnalyzingAI: Boolean = false,
    val isEditMode: Boolean = false
) {
    /**
     * Get filtered documents based on search and category.
     */
    fun getFilteredDocuments(): List<MedicalDocument> {
        return documents.filter { doc ->
            val matchesCategory = selectedCategory == null || doc.category == selectedCategory

            val matchesSearch = searchQuery.isEmpty() ||
                doc.title.contains(searchQuery, ignoreCase = true) ||
                doc.metadata?.doctorName?.contains(searchQuery, ignoreCase = true) == true ||
                doc.metadata?.description?.contains(searchQuery, ignoreCase = true) == true

            matchesCategory && matchesSearch
        }
    }

    /**
     * Get documents grouped by folder.
     */
    fun getGroupedDocuments(): Map<String, List<MedicalDocument>> {
        val filtered = getFilteredDocuments()
        return filtered.groupBy {
            it.metadata?.folderName
                ?: it.metadata?.documentDate?.toLocalDate()?.toString()
                ?: "Other"
        }
    }

    /**
     * Get documents in currently open folder.
     */
    fun getFolderDocuments(): List<MedicalDocument> {
        val folderName = openFolderName ?: return emptyList()
        return getGroupedDocuments()[folderName] ?: emptyList()
    }

    /**
     * Check if there are any active filters.
     */
    fun hasActiveFilters(): Boolean = selectedCategory != null || searchQuery.isNotEmpty()

    /**
     * Check if batch upload is in progress.
     */
    fun isBatchUploadActive(): Boolean = showBatchUploadPreview && batchUploadItems.isNotEmpty()
}

/**
 * View mode for displaying documents.
 */
enum class VaultViewMode {
    LIST,
    FOLDERS,
    TIMELINE
}

/**
 * Represents a file queued for batch upload.
 */
data class BatchUploadItem(
    val fileName: String,
    val fileSize: Long,
    val fileData: ByteArray,
    val category: DocumentCategory = DocumentCategory.OTHER
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is BatchUploadItem) return false
        return fileName == other.fileName && fileSize == other.fileSize && category == other.category
    }

    override fun hashCode(): Int {
        var result = fileName.hashCode()
        result = 31 * result + fileSize.hashCode()
        result = 31 * result + category.hashCode()
        return result
    }
}
