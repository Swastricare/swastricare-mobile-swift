package com.swastricare.health.ui.screens.vault

import android.util.Base64
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.UserFriendlyError
import com.swastricare.health.data.model.DocumentMetadata
import com.swastricare.health.data.model.MedicalDocument
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.data.repository.SupabaseVaultRepository
import com.swastricare.health.data.repository.VaultRepository
import com.swastricare.health.data.services.AIService
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.AppointmentAlarmScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class VaultUiState(
    val documents: List<MedicalDocument> = emptyList(),
    val isLoading: Boolean = false,
    val isUploading: Boolean = false,
    val uploadProgress: Float = 0f, // 0 to 1
    val errorMessage: String? = null,
    val selectedCategory: VaultCategory? = null,
    val searchQuery: String = "",
    val viewMode: VaultViewMode = VaultViewMode.List,
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
)

data class BatchUploadItem(
    val fileName: String,
    val fileSize: Long,
    val fileData: ByteArray,
    val category: VaultCategory = VaultCategory.OTHER
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

enum class VaultViewMode {
    List, Folders, Timeline
}

@HiltViewModel
class VaultViewModel @Inject constructor(
    private val repository: SupabaseVaultRepository,
    private val analyticsService: AnalyticsService,
    private val appAnalyticsService: AppAnalyticsService,
    private val aiService: AIService,
    private val appointmentScheduler: AppointmentAlarmScheduler
) : ViewModel() {

    private val _uiState = MutableStateFlow(VaultUiState())
    val uiState: StateFlow<VaultUiState> = _uiState.asStateFlow()

    init {
        loadDocuments()
    }

    fun loadDocuments() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val documents = repository.getDocuments()
                _uiState.update { it.copy(documents = documents, isLoading = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, errorMessage = UserFriendlyError.from(e)) }
            }
        }
    }

    fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: VaultCategory,
        metadata: DocumentMetadata
    ) {
        // Prevent duplicate uploads from re-entrant calls or multiple taps
        if (_uiState.value.isUploading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isUploading = true, uploadProgress = 0.1f) }
            try {
                _uiState.update { it.copy(uploadProgress = 0.5f) }

                val categoryString = category.title

                repository.uploadDocument(
                    fileData = fileData,
                    fileName = fileName,
                    category = categoryString,
                    metadata = metadata
                )

                _uiState.update { it.copy(uploadProgress = 1.0f) }

                // Log vault upload to analytics
                analyticsService.logVaultUpload(categoryString)
                appAnalyticsService.trackVaultUpload(categoryString)

                // Refresh list inline (not via loadDocuments which launches a separate coroutine)
                try {
                    val documents = repository.getDocuments()
                    _uiState.update { it.copy(documents = documents, isUploading = false, showAddSheet = false) }
                } catch (e: Exception) {
                    _uiState.update { it.copy(isUploading = false, showAddSheet = false, errorMessage = "Unable to upload document. Please try again.") }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isUploading = false, errorMessage = "Unable to upload document. Please try again.") }
            }
        }
    }

    fun setCategory(category: VaultCategory?) {
        _uiState.update { it.copy(selectedCategory = category) }
    }

    fun setSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }

    fun setViewMode(mode: VaultViewMode) {
        _uiState.update { it.copy(viewMode = mode) }
    }

    fun toggleSelectionMode() {
        _uiState.update { state ->
            val newSelectionMode = !state.isSelectionMode
            state.copy(
                isSelectionMode = newSelectionMode,
                selectedDocuments = if (!newSelectionMode) emptySet() else state.selectedDocuments
            )
        }
    }

    fun toggleDocumentSelection(documentId: String) {
        _uiState.update { state ->
            val newSelection = state.selectedDocuments.toMutableSet()
            if (newSelection.contains(documentId)) {
                newSelection.remove(documentId)
            } else {
                newSelection.add(documentId)
            }
            state.copy(selectedDocuments = newSelection)
        }
    }

    fun selectAllDocuments() {
        _uiState.update { state ->
            state.copy(selectedDocuments = state.documents.mapNotNull { it.id }.toSet())
        }
    }

    fun clearSelection() {
        _uiState.update { it.copy(selectedDocuments = emptySet()) }
    }

    fun deleteSelectedDocuments() {
        viewModelScope.launch {
             _uiState.update { it.copy(isLoading = true) }
             try {
                 val failedIds = mutableListOf<String>()
                 _uiState.value.selectedDocuments.forEach { id ->
                     try {
                         repository.deleteDocument(id)
                     } catch (e: Exception) {
                         failedIds.add(id)
                     }
                 }
                 val documents = repository.getDocuments()
                 _uiState.update {
                     it.copy(
                         documents = documents,
                         isLoading = false,
                         selectedDocuments = emptySet(),
                         isSelectionMode = false,
                         errorMessage = if (failedIds.isNotEmpty()) "Failed to delete ${failedIds.size} document(s)" else null
                     )
                 }
             } catch (e: Exception) {
                 _uiState.update { it.copy(isLoading = false, errorMessage = "Unable to delete documents. Please try again.") }
             }
        }
    }

    fun deleteDocument(document: MedicalDocument) {
        viewModelScope.launch {
            try {
                document.id?.let { repository.deleteDocument(it) }
                loadDocuments()
            } catch (e: Exception) {
                 _uiState.update { it.copy(errorMessage = "Failed to delete document") }
            }
        }
    }

    fun setShowAddSheet(show: Boolean) {
        _uiState.update { it.copy(showAddSheet = show) }
    }

    fun selectDocumentForDetail(document: MedicalDocument?) {
        _uiState.update { it.copy(selectedDocumentDetail = document, aiAnalysisResult = null, isAnalyzingAI = false, isEditMode = false) }
    }

    /**
     * Resolves a signed URL for the document before opening the viewer.
     * The stored fileUrl is a raw storage path — we need a signed URL to actually load it.
     */
    fun openDocumentViewer(doc: MedicalDocument, onResolved: (MedicalDocument) -> Unit) {
        viewModelScope.launch {
            val resolvedDoc = try {
                val signedUrl = repository.getSignedUrl(doc.fileUrl)
                doc.copy(fileUrl = signedUrl)
            } catch (e: Exception) {
                doc // fall back to original if signing fails
            }
            onResolved(resolvedDoc)
        }
    }

    fun updateDocumentMetadata(
        documentId: String,
        title: String,
        category: String,
        notes: String?,
        tags: List<String>,
        doctorName: String? = null,
        location: String? = null,
        appointmentDate: String? = null
    ) {
        viewModelScope.launch {
            try {
                repository.updateDocument(documentId, title, category, notes, tags, doctorName, location, appointmentDate)

                // Schedule or cancel appointment notifications
                if (appointmentDate != null) {
                    val apptInfo = AppointmentAlarmScheduler.AppointmentInfo(
                        id = documentId,
                        scheduledAtIso = appointmentDate,
                        doctorName = doctorName ?: "Doctor",
                        location = location ?: ""
                    )
                    appointmentScheduler.schedule(apptInfo)
                } else {
                    appointmentScheduler.cancel(documentId)
                }

                _uiState.update { it.copy(isEditMode = false) }
                loadDocuments()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = "Unable to update document. Please try again.") }
            }
        }
    }

    fun analyzeDocumentWithAI(document: MedicalDocument) {
        viewModelScope.launch {
            _uiState.update { it.copy(isAnalyzingAI = true, aiAnalysisResult = null) }
            try {
                val signedUrl = repository.getSignedUrl(document.fileUrl)
                val imageBytes = withContext(kotlinx.coroutines.Dispatchers.IO) {
                    java.net.URL(signedUrl).readBytes()
                }
                val base64 = Base64.encodeToString(imageBytes, Base64.NO_WRAP)
                val prompt = "Analyze this medical document. Provide a brief summary of what this document contains, key findings, and any important dates or values mentioned. Keep it concise (3-4 sentences)."
                val response = aiService.sendImageMessage(prompt, base64)
                _uiState.update { it.copy(isAnalyzingAI = false, aiAnalysisResult = response) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isAnalyzingAI = false, aiAnalysisResult = "Unable to analyze document. Please try again.") }
            }
        }
    }

    fun clearAIAnalysis() {
        _uiState.update { it.copy(aiAnalysisResult = null, isAnalyzingAI = false) }
    }

    fun setEditMode(editing: Boolean) {
        _uiState.update { it.copy(isEditMode = editing) }
    }

    suspend fun resolveSignedUrl(path: String): String = repository.getSignedUrl(path)

    fun deleteDocument(documentId: String) {
        viewModelScope.launch {
            try {
                repository.deleteDocument(documentId)
                _uiState.update { it.copy(selectedDocumentDetail = null) }
                loadDocuments()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = "Failed to delete document") }
            }
        }
    }

    fun setBatchUploadItems(items: List<BatchUploadItem>) {
        _uiState.update { it.copy(batchUploadItems = items, showBatchUploadPreview = items.isNotEmpty()) }
    }

    fun updateBatchItemCategory(index: Int, category: VaultCategory) {
        _uiState.update { state ->
            val updatedItems = state.batchUploadItems.toMutableList()
            if (index in updatedItems.indices) {
                updatedItems[index] = updatedItems[index].copy(category = category)
            }
            state.copy(batchUploadItems = updatedItems)
        }
    }

    fun removeBatchItem(index: Int) {
        _uiState.update { state ->
            val updatedItems = state.batchUploadItems.toMutableList()
            if (index in updatedItems.indices) {
                updatedItems.removeAt(index)
            }
            state.copy(
                batchUploadItems = updatedItems,
                showBatchUploadPreview = updatedItems.isNotEmpty()
            )
        }
    }

    fun batchUploadDocuments() {
        // Prevent duplicate batch uploads from re-entrant calls or multiple taps
        if (_uiState.value.isUploading) return

        viewModelScope.launch {
            val items = _uiState.value.batchUploadItems
            if (items.isEmpty()) return@launch

            _uiState.update { it.copy(isUploading = true, uploadProgress = 0f) }
            try {
                items.forEachIndexed { index, item ->
                    _uiState.update { it.copy(uploadProgress = (index.toFloat() + 0.5f) / items.size) }
                    val metadata = DocumentMetadata(name = item.fileName.substringBeforeLast('.'))
                    repository.uploadDocument(
                        fileData = item.fileData,
                        fileName = item.fileName,
                        category = item.category.title,
                        metadata = metadata
                    )
                    _uiState.update { it.copy(uploadProgress = (index + 1).toFloat() / items.size) }
                }

                loadDocuments()
                _uiState.update {
                    it.copy(
                        isUploading = false,
                        showBatchUploadPreview = false,
                        batchUploadItems = emptyList()
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isUploading = false,
                        errorMessage = "Unable to upload document. Please try again."
                    )
                }
            }
        }
    }

    fun dismissBatchUpload() {
        _uiState.update { it.copy(showBatchUploadPreview = false, batchUploadItems = emptyList()) }
    }

    fun openFolder(folderName: String) {
        _uiState.update { it.copy(openFolderName = folderName) }
    }

    fun closeFolder() {
        _uiState.update { it.copy(openFolderName = null) }
    }

    val folderDocuments: List<MedicalDocument>
        get() {
            val folderName = uiState.value.openFolderName ?: return emptyList()
            return groupedDocuments[folderName] ?: emptyList()
        }

    val filteredDocuments: List<MedicalDocument>
        get() {
            val state = uiState.value
            return state.documents.filter { doc ->
                val matchesCategory = state.selectedCategory == null ||
                    doc.category.equals(state.selectedCategory.title, ignoreCase = true)

                val matchesSearch = state.searchQuery.isEmpty() ||
                    doc.title.contains(state.searchQuery, ignoreCase = true) ||
                    (doc.doctorName?.contains(state.searchQuery, ignoreCase = true) == true) ||
                    (doc.description?.contains(state.searchQuery, ignoreCase = true) == true)

                matchesCategory && matchesSearch
            }
        }

    val groupedDocuments: Map<String, List<MedicalDocument>>
        get() = filteredDocuments.groupBy { it.folderName ?: it.documentDate?.substringBefore("T") ?: "Other" }
}
