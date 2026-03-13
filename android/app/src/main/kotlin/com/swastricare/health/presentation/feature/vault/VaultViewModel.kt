package com.swastricare.health.presentation.feature.vault

import android.util.Base64
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.services.AIService
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.AppointmentAlarmScheduler
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument
import com.swastricare.health.domain.usecase.vault.DeleteDocumentUseCase
import com.swastricare.health.domain.usecase.vault.GetDocumentsUseCase
import com.swastricare.health.domain.usecase.vault.GetSignedUrlUseCase
import com.swastricare.health.domain.usecase.vault.UpdateDocumentUseCase
import com.swastricare.health.domain.usecase.vault.UploadDocumentUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * ViewModel for Vault feature.
 * Manages medical document state and business logic using Clean Architecture.
 *
 * Uses Hilt for dependency injection.
 */
@HiltViewModel
class VaultViewModel @Inject constructor(
    private val getDocumentsUseCase: GetDocumentsUseCase,
    private val uploadDocumentUseCase: UploadDocumentUseCase,
    private val updateDocumentUseCase: UpdateDocumentUseCase,
    private val deleteDocumentUseCase: DeleteDocumentUseCase,
    private val getSignedUrlUseCase: GetSignedUrlUseCase,
    private val analyticsService: AnalyticsService,
    private val appAnalyticsService: AppAnalyticsService,
    private val aiService: AIService,
    private val appointmentScheduler: AppointmentAlarmScheduler,
    private val logger: Logger
) : ViewModel() {

    companion object {
        private const val TAG = "VaultViewModel"
    }

    private val _uiState = MutableStateFlow(VaultUiState())
    val uiState: StateFlow<VaultUiState> = _uiState.asStateFlow()

    init {
        loadDocuments()
    }

    // ── Document Loading ──

    /**
     * Load all documents from repository.
     */
    fun loadDocuments() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }

            when (val result = getDocumentsUseCase()) {
                is ResultWrapper.Success -> {
                    logger.d(TAG, "Loaded ${result.data.size} documents")
                    _uiState.update {
                        it.copy(
                            documents = result.data,
                            isLoading = false
                        )
                    }
                }
                is ResultWrapper.Error -> {
                    logger.e(TAG, "Failed to load documents: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = result.exception.message
                        )
                    }
                }
                else -> {}
            }
        }
    }

    // ── Document Upload ──

    /**
     * Upload a single document.
     */
    fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isUploading = true, uploadProgress = 0.1f) }

            try {
                _uiState.update { it.copy(uploadProgress = 0.3f) }

                when (val result = uploadDocumentUseCase(fileData, fileName, category, metadata)) {
                    is ResultWrapper.Success -> {
                        logger.d(TAG, "Document uploaded successfully")
                        _uiState.update { it.copy(uploadProgress = 1.0f) }

                        // Track analytics
                        analyticsService.logVaultUpload(category.displayName)
                        appAnalyticsService.trackVaultUpload(category.displayName)

                        // Refresh list
                        loadDocuments()
                        _uiState.update {
                            it.copy(
                                isUploading = false,
                                showAddSheet = false,
                                uploadProgress = 0f
                            )
                        }
                    }
                    is ResultWrapper.Error -> {
                        logger.e(TAG, "Upload failed: ${result.exception.message}")
                        _uiState.update {
                            it.copy(
                                isUploading = false,
                                uploadProgress = 0f,
                                errorMessage = "Upload failed: ${result.exception.message}"
                            )
                        }
                    }
                    else -> {}
                }
            } catch (e: Exception) {
                logger.e(TAG, "Unexpected upload error", e)
                _uiState.update {
                    it.copy(
                        isUploading = false,
                        uploadProgress = 0f,
                        errorMessage = "Upload failed: ${e.message}"
                    )
                }
            }
        }
    }

    /**
     * Upload multiple documents in batch.
     */
    fun batchUploadDocuments() {
        viewModelScope.launch {
            val items = _uiState.value.batchUploadItems
            if (items.isEmpty()) return@launch

            _uiState.update { it.copy(isUploading = true, uploadProgress = 0f) }

            try {
                items.forEachIndexed { index, item ->
                    _uiState.update {
                        it.copy(uploadProgress = (index.toFloat() + 0.5f) / items.size)
                    }

                    val metadata = DocumentMetadata(
                        description = item.fileName.substringBeforeLast('.')
                    )

                    when (uploadDocumentUseCase(
                        fileData = item.fileData,
                        fileName = item.fileName,
                        category = item.category,
                        metadata = metadata
                    )) {
                        is ResultWrapper.Success -> {
                            logger.d(TAG, "Batch item uploaded: ${item.fileName}")
                        }
                        is ResultWrapper.Error -> {
                            logger.e(TAG, "Batch item failed: ${item.fileName}")
                        }
                        else -> {}
                    }

                    _uiState.update {
                        it.copy(uploadProgress = (index + 1).toFloat() / items.size)
                    }
                }

                loadDocuments()
                _uiState.update {
                    it.copy(
                        isUploading = false,
                        showBatchUploadPreview = false,
                        batchUploadItems = emptyList(),
                        uploadProgress = 0f
                    )
                }
            } catch (e: Exception) {
                logger.e(TAG, "Batch upload error", e)
                _uiState.update {
                    it.copy(
                        isUploading = false,
                        uploadProgress = 0f,
                        errorMessage = "Batch upload failed: ${e.message}"
                    )
                }
            }
        }
    }

    // ── Document Update ──

    /**
     * Update document metadata.
     */
    fun updateDocumentMetadata(
        documentId: String,
        title: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ) {
        viewModelScope.launch {
            when (val result = updateDocumentUseCase(documentId, title, category, metadata)) {
                is ResultWrapper.Success -> {
                    logger.d(TAG, "Document updated successfully")

                    // Schedule or cancel appointment notifications
                    if (metadata.appointmentDate != null) {
                        val apptInfo = AppointmentAlarmScheduler.AppointmentInfo(
                            id = documentId,
                            scheduledAtIso = metadata.appointmentDate.toString(),
                            doctorName = metadata.doctorName ?: "Doctor",
                            location = metadata.location ?: ""
                        )
                        appointmentScheduler.schedule(apptInfo)
                    } else {
                        appointmentScheduler.cancel(documentId)
                    }

                    _uiState.update { it.copy(isEditMode = false) }
                    loadDocuments()
                }
                is ResultWrapper.Error -> {
                    logger.e(TAG, "Update failed: ${result.exception.message}")
                    _uiState.update {
                        it.copy(errorMessage = "Failed to update document: ${result.exception.message}")
                    }
                }
                else -> {}
            }
        }
    }

    // ── Document Deletion ──

    /**
     * Delete a single document.
     */
    fun deleteDocument(documentId: String) {
        viewModelScope.launch {
            when (deleteDocumentUseCase(documentId)) {
                is ResultWrapper.Success -> {
                    logger.d(TAG, "Document deleted successfully")
                    _uiState.update { it.copy(selectedDocumentDetail = null) }
                    loadDocuments()
                }
                is ResultWrapper.Error -> {
                    logger.e(TAG, "Delete failed")
                    _uiState.update { it.copy(errorMessage = "Failed to delete document") }
                }
                else -> {}
            }
        }
    }

    /**
     * Delete selected documents.
     */
    fun deleteSelectedDocuments() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            val selectedIds = _uiState.value.selectedDocuments.toList()
            when (deleteDocumentUseCase(selectedIds)) {
                is ResultWrapper.Success -> {
                    logger.d(TAG, "Selected documents deleted successfully")
                    _uiState.update {
                        it.copy(
                            selectedDocuments = emptySet(),
                            isSelectionMode = false
                        )
                    }
                    loadDocuments()
                }
                is ResultWrapper.Error -> {
                    logger.e(TAG, "Batch delete failed")
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = "Failed to delete selected documents"
                        )
                    }
                }
                else -> {}
            }
        }
    }

    // ── Document Viewing ──

    /**
     * Resolve signed URL and open document viewer.
     */
    fun openDocumentViewer(doc: MedicalDocument, onResolved: (MedicalDocument) -> Unit) {
        viewModelScope.launch {
            when (val result = getSignedUrlUseCase(doc.fileUrl)) {
                is ResultWrapper.Success -> {
                    val resolvedDoc = doc.copy(fileUrl = result.data)
                    onResolved(resolvedDoc)
                }
                is ResultWrapper.Error -> {
                    logger.w(TAG, "Failed to get signed URL, using original")
                    onResolved(doc)
                }
                else -> onResolved(doc)
            }
        }
    }

    /**
     * Get signed URL for a document path.
     */
    suspend fun resolveSignedUrl(path: String): String? {
        return when (val result = getSignedUrlUseCase(path)) {
            is ResultWrapper.Success -> result.data
            is ResultWrapper.Error -> {
                logger.e(TAG, "Failed to resolve signed URL")
                null
            }
            else -> null
        }
    }

    // ── AI Analysis ──

    /**
     * Analyze document with AI.
     */
    fun analyzeDocumentWithAI(document: MedicalDocument) {
        viewModelScope.launch {
            _uiState.update { it.copy(isAnalyzingAI = true, aiAnalysisResult = null) }

            try {
                when (val urlResult = getSignedUrlUseCase(document.fileUrl)) {
                    is ResultWrapper.Success -> {
                        val signedUrl = urlResult.data
                        val imageBytes = withContext(Dispatchers.IO) {
                            java.net.URL(signedUrl).readBytes()
                        }
                        val base64 = Base64.encodeToString(imageBytes, Base64.NO_WRAP)
                        val prompt = "Analyze this medical document. Provide a brief summary of what this document contains, key findings, and any important dates or values mentioned. Keep it concise (3-4 sentences)."
                        val response = aiService.sendImageMessage(prompt, base64)
                        _uiState.update {
                            it.copy(
                                isAnalyzingAI = false,
                                aiAnalysisResult = response
                            )
                        }
                    }
                    is ResultWrapper.Error -> {
                        _uiState.update {
                            it.copy(
                                isAnalyzingAI = false,
                                aiAnalysisResult = "Unable to access document: ${urlResult.exception.message}"
                            )
                        }
                    }
                    else -> {
                        _uiState.update { it.copy(isAnalyzingAI = false) }
                    }
                }
            } catch (e: Exception) {
                logger.e(TAG, "AI analysis failed", e)
                _uiState.update {
                    it.copy(
                        isAnalyzingAI = false,
                        aiAnalysisResult = "Unable to analyze document: ${e.message}"
                    )
                }
            }
        }
    }

    fun clearAIAnalysis() {
        _uiState.update { it.copy(aiAnalysisResult = null, isAnalyzingAI = false) }
    }

    // ── UI State Management ──

    fun setCategory(category: DocumentCategory?) {
        _uiState.update { it.copy(selectedCategory = category) }
    }

    fun setSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }

    fun setViewMode(mode: VaultViewMode) {
        _uiState.update { it.copy(viewMode = mode) }
    }

    fun setShowAddSheet(show: Boolean) {
        _uiState.update { it.copy(showAddSheet = show) }
    }

    fun selectDocumentForDetail(document: MedicalDocument?) {
        _uiState.update {
            it.copy(
                selectedDocumentDetail = document,
                aiAnalysisResult = null,
                isAnalyzingAI = false,
                isEditMode = false
            )
        }
    }

    fun setEditMode(editing: Boolean) {
        _uiState.update { it.copy(isEditMode = editing) }
    }

    // ── Selection Mode ──

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
            state.copy(selectedDocuments = state.documents.map { it.id }.toSet())
        }
    }

    fun clearSelection() {
        _uiState.update { it.copy(selectedDocuments = emptySet()) }
    }

    // ── Batch Upload ──

    fun setBatchUploadItems(items: List<BatchUploadItem>) {
        _uiState.update {
            it.copy(
                batchUploadItems = items,
                showBatchUploadPreview = items.isNotEmpty()
            )
        }
    }

    fun updateBatchItemCategory(index: Int, category: DocumentCategory) {
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

    fun dismissBatchUpload() {
        _uiState.update {
            it.copy(
                showBatchUploadPreview = false,
                batchUploadItems = emptyList()
            )
        }
    }

    // ── Folder Navigation ──

    fun openFolder(folderName: String) {
        _uiState.update { it.copy(openFolderName = folderName) }
    }

    fun closeFolder() {
        _uiState.update { it.copy(openFolderName = null) }
    }
}
