package com.swasthicare.mobile.ui.screens.vault

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.model.DocumentMetadata
import com.swasthicare.mobile.data.model.MedicalDocument
import com.swasthicare.mobile.data.model.VaultCategory
import com.swasthicare.mobile.data.repository.MockVaultRepository
// import com.swasthicare.mobile.data.repository.SupabaseVaultRepository
import com.swasthicare.mobile.data.repository.VaultRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

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
    val showAddSheet: Boolean = false
)

enum class VaultViewMode {
    List, Folders, Timeline
}

class VaultViewModel(
    // In a real app with Hilt, this would be injected.
    // For now defaulting to Mock implementation for UI-only mode.
    private val repository: VaultRepository = MockVaultRepository() 
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
                // Fallback to mock if Supabase fails (e.g. auth issue during dev)
                // In production, handle specific errors
                if (e.message?.contains("User not authenticated") == true) {
                     // Using mock for demo if not logged in
                     try {
                         val mockRepo = MockVaultRepository()
                         val docs = mockRepo.getDocuments()
                         _uiState.update { it.copy(documents = docs, isLoading = false, errorMessage = "Demo Mode: ${e.message}") }
                     } catch (ex: Exception) {
                         _uiState.update { it.copy(isLoading = false, errorMessage = e.message) }
                     }
                } else {
                    _uiState.update { it.copy(isLoading = false, errorMessage = e.message) }
                }
            }
        }
    }

    fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: VaultCategory,
        metadata: DocumentMetadata
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isUploading = true, uploadProgress = 0.1f) }
            try {
                // Simulate progress
                _uiState.update { it.copy(uploadProgress = 0.5f) }
                
                val categoryString = category.title
                
                repository.uploadDocument(
                    fileData = fileData,
                    fileName = fileName,
                    category = categoryString,
                    metadata = metadata
                )
                
                _uiState.update { it.copy(uploadProgress = 1.0f) }
                
                // Refresh list
                loadDocuments()
                
                _uiState.update { it.copy(isUploading = false, showAddSheet = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isUploading = false, errorMessage = "Upload failed: ${e.message}") }
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
                 _uiState.value.selectedDocuments.forEach { id ->
                     repository.deleteDocument(id)
                 }
                 loadDocuments()
                 _uiState.update { 
                     it.copy(
                         selectedDocuments = emptySet(),
                         isSelectionMode = false
                     ) 
                 }
             } catch (e: Exception) {
                 _uiState.update { it.copy(isLoading = false, errorMessage = "Failed to delete documents") }
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
