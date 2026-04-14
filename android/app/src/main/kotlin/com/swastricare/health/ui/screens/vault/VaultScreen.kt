package com.swastricare.health.ui.screens.vault

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.List
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import coil.compose.rememberAsyncImagePainter
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.coroutines.launch
import com.swastricare.health.data.model.MedicalDocument
import com.swastricare.health.data.model.DocumentMetadata
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.components.TrackScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VaultScreen(
    viewModel: VaultViewModel = hiltViewModel(),
    onNavigateToViewer: ((MedicalDocument) -> Unit)? = null,
    onNavigateToAIChat: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null
) {
    TrackScreen("Vault")
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current

    // Lock to portrait to prevent session header repositioning on rotation
    val activity = LocalContext.current as? android.app.Activity
    DisposableEffect(Unit) {
        val originalOrientation = activity?.requestedOrientation
        activity?.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        onDispose {
            activity?.requestedOrientation = originalOrientation ?: android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    val allowedMimeTypes = arrayOf(
        "application/pdf",
        "image/jpeg",
        "image/png",
        "image/webp"
    )
    val maxFileSizeBytes = 20L * 1024 * 1024 // 20 MB

    // Upload State
    var pendingFileUri by remember { mutableStateOf<Uri?>(null) }
    var pendingFileName by remember { mutableStateOf("") }
    var pendingFileSize by remember { mutableStateOf(0L) }
    var pendingFileData by remember { mutableStateOf<ByteArray?>(null) }

    // Single file picker
    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let {
            val contentResolver = context.contentResolver
            var name = "unknown"
            var size = 0L
            contentResolver.query(it, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (cursor.moveToFirst()) {
                    name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "unknown" else "unknown"
                    size = if (sizeIndex >= 0) cursor.getLong(sizeIndex) else 0L
                }
            }
            val fileSize = if (size > 0) size else {
                contentResolver.openFileDescriptor(it, "r")?.use { fd -> fd.statSize } ?: 0L
            }
            if (fileSize > maxFileSizeBytes) {
                coroutineScope.launch {
                    snackbarHostState.showSnackbar(
                        message = "File too large. Maximum size is 20 MB.",
                        duration = SnackbarDuration.Long
                    )
                }
                return@let
            }
            pendingFileName = name
            pendingFileSize = fileSize
            contentResolver.openInputStream(it)?.use { stream ->
                pendingFileData = stream.readBytes()
            }
            pendingFileUri = it
            viewModel.setShowAddSheet(true)
        }
    }

    // Multi-file picker for batch upload
    val batchFilePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenMultipleDocuments()
    ) { uris ->
        if (uris.size == 1) {
            val uri = uris.first()
            val contentResolver = context.contentResolver
            var name = "unknown"
            var size = 0L
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (cursor.moveToFirst()) {
                    name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "unknown" else "unknown"
                    size = if (sizeIndex >= 0) cursor.getLong(sizeIndex) else 0L
                }
            }
            val fileSize = if (size > 0) size else {
                contentResolver.openFileDescriptor(uri, "r")?.use { fd -> fd.statSize } ?: 0L
            }
            if (fileSize > maxFileSizeBytes) {
                coroutineScope.launch {
                    snackbarHostState.showSnackbar(
                        message = "File too large. Maximum size is 20 MB.",
                        duration = SnackbarDuration.Long
                    )
                }
                return@rememberLauncherForActivityResult
            }
            pendingFileName = name
            pendingFileSize = fileSize
            contentResolver.openInputStream(uri)?.use { stream ->
                pendingFileData = stream.readBytes()
            }
            pendingFileUri = uri
            viewModel.setShowAddSheet(true)
        } else if (uris.size > 1) {
            var skippedCount = 0
            val batchItems = uris.mapNotNull { uri ->
                try {
                    val contentResolver = context.contentResolver
                    var name = "unknown"
                    var size = 0L
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (cursor.moveToFirst()) {
                            name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "unknown" else "unknown"
                            size = if (sizeIndex >= 0) cursor.getLong(sizeIndex) else 0L
                        }
                    }
                    val fileSize = if (size > 0) size else {
                        contentResolver.openFileDescriptor(uri, "r")?.use { fd -> fd.statSize } ?: 0L
                    }
                    if (fileSize > maxFileSizeBytes) {
                        skippedCount++
                        return@mapNotNull null
                    }
                    val data = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    data?.let {
                        BatchUploadItem(
                            fileName = name,
                            fileSize = fileSize,
                            fileData = it,
                            category = VaultCategory.OTHER
                        )
                    }
                } catch (e: Exception) {
                    null
                }
            }
            if (skippedCount > 0) {
                coroutineScope.launch {
                    val fileWord = if (skippedCount == 1) "file was" else "files were"
                    snackbarHostState.showSnackbar(
                        message = "$skippedCount $fileWord skipped (exceeds 20 MB limit).",
                        duration = SnackbarDuration.Long
                    )
                }
            }
            if (batchItems.isNotEmpty()) {
                viewModel.setBatchUploadItems(batchItems)
            }
        }
    }

    // Internal document viewer state
    var viewingDocument by remember { mutableStateOf<MedicalDocument?>(null) }

    if (viewingDocument != null && onNavigateToViewer == null) {
        DocumentViewerScreen(
            document = viewingDocument!!,
            onBack = { viewingDocument = null }
        )
        return
    }

    Box(modifier = Modifier
        .fillMaxSize()
        .background(AppColors.background)) {

        // Folder Detail Overlay
        if (uiState.openFolderName != null) {
            FolderDetailView(
                folderName = uiState.openFolderName!!,
                documents = viewModel.folderDocuments,
                onBack = viewModel::closeFolder,
                onDocumentTap = { doc ->
                    viewModel.selectDocumentForDetail(doc)
                }
            )
        } else {
            // Main Vault Content — LazyColumn like Settings
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 160.dp)
            ) {
                // ── Header ──
                item {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(top = 24.dp, bottom = 8.dp)
                    ) {
                        // Title and count - centered
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                "Medical Vault",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = AppColors.onBackground
                            )
                            Text(
                                "${uiState.documents.size} documents",
                                style = MaterialTheme.typography.bodyMedium,
                                color = AppColors.onBackground.copy(alpha = 0.5f)
                            )
                        }

                        // View mode + selection mode controls - start aligned
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = 16.dp, top = 16.dp, end = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            FilterChip(
                                selected = false,
                                onClick = {
                                    val newMode = when (uiState.viewMode) {
                                        VaultViewMode.List -> VaultViewMode.Folders
                                        VaultViewMode.Folders -> VaultViewMode.Timeline
                                        VaultViewMode.Timeline -> VaultViewMode.List
                                    }
                                    viewModel.setViewMode(newMode)
                                },
                                label = {
                                    Text(
                                        when (uiState.viewMode) {
                                            VaultViewMode.List -> "List"
                                            VaultViewMode.Folders -> "Folders"
                                            VaultViewMode.Timeline -> "Timeline"
                                        },
                                        fontSize = 13.sp
                                    )
                                },
                                leadingIcon = {
                                    Icon(
                                        imageVector = when (uiState.viewMode) {
                                            VaultViewMode.List -> Icons.AutoMirrored.Outlined.List
                                            VaultViewMode.Folders -> Icons.Outlined.Folder
                                            VaultViewMode.Timeline -> Icons.Outlined.CalendarToday
                                        },
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                },
                                border = FilterChipDefaults.filterChipBorder(
                                    enabled = true,
                                    selected = false,
                                    borderColor = androidx.compose.ui.graphics.Color.Transparent,
                                    selectedBorderColor = androidx.compose.ui.graphics.Color.Transparent
                                )
                            )
                            FilterChip(
                                selected = uiState.isSelectionMode,
                                onClick = viewModel::toggleSelectionMode,
                                label = { Text("Select", fontSize = 13.sp) },
                                leadingIcon = {
                                    Icon(
                                        imageVector = if (uiState.isSelectionMode) Icons.Default.Close else Icons.Outlined.CheckCircle,
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                },
                                border = FilterChipDefaults.filterChipBorder(
                                    enabled = true,
                                    selected = uiState.isSelectionMode,
                                    borderColor = androidx.compose.ui.graphics.Color.Transparent,
                                    selectedBorderColor = androidx.compose.ui.graphics.Color.Transparent
                                )
                            )
                        }
                    }
                }

                // ── Search ──
                item { VaultSectionHeader("Search") }
                item {
                    VaultSectionCard {
                        TextField(
                            value = uiState.searchQuery,
                            onValueChange = viewModel::setSearchQuery,
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("Search documents...") },
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            keyboardActions = KeyboardActions(
                                onSearch = { focusManager.clearFocus() }
                            ),
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                disabledContainerColor = Color.Transparent,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent,
                                disabledIndicatorColor = Color.Transparent,
                                focusedTextColor = AppColors.onSurface,
                                unfocusedTextColor = AppColors.onSurface,
                                focusedLeadingIconColor = AppColors.onSurfaceVariant,
                                unfocusedLeadingIconColor = AppColors.onSurfaceVariant,
                                focusedPlaceholderColor = AppColors.onSurfaceVariant,
                                unfocusedPlaceholderColor = AppColors.onSurfaceVariant
                            )
                        )
                    }
                }

                // ── Categories ──
                item { VaultSectionHeader("Categories") }
                item {
                    VaultSectionCard {
                        LazyRow(
                            modifier = Modifier.fillMaxWidth(),
                            contentPadding = PaddingValues(vertical = 8.dp)
                        ) {
                            item {
                                FilterPill(
                                    title = "All",
                                    count = uiState.documents.size,
                                    isSelected = uiState.selectedCategory == null,
                                    colorHex = 0xFF2E3192,
                                    onClick = { viewModel.setCategory(null) }
                                )
                            }
                            items(VaultCategory.values()) { category ->
                                val count = uiState.documents.count { it.category.equals(category.title, ignoreCase = true) }
                                FilterPill(
                                    title = category.title,
                                    count = count,
                                    isSelected = uiState.selectedCategory == category,
                                    colorHex = category.colorHex,
                                    onClick = { viewModel.setCategory(category) }
                                )
                            }
                        }
                    }
                }

                // ── Selection Bar ──
                if (uiState.isSelectionMode) {
                    item {
                        SelectionBar(
                            selectedCount = uiState.selectedDocuments.size,
                            onSelectAll = viewModel::selectAllDocuments,
                            onDelete = viewModel::deleteSelectedDocuments
                        )
                    }
                }

                // ── Upload Progress ──
                if (uiState.isUploading) {
                    item {
                        LinearProgressIndicator(
                            progress = { uiState.uploadProgress },
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                        )
                    }
                }

                // ── Error Message ──
                uiState.errorMessage?.let { error ->
                    item {
                        Text(
                            text = error,
                            color = AppColors.error,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
                        )
                    }
                }

                // ── Documents ──
                if (uiState.isLoading && uiState.documents.isEmpty()) {
                    item {
                        Box(modifier = Modifier.fillParentMaxHeight(0.5f)) {
                            ShimmerDocumentList()
                        }
                    }
                } else if (viewModel.filteredDocuments.isEmpty()) {
                    item {
                        EmptyState()
                    }
                } else {
                    when (uiState.viewMode) {
                        VaultViewMode.List -> {
                            item { VaultSectionHeader("Documents") }
                            item {
                                VaultSectionCard {
                                    val docs = viewModel.filteredDocuments
                                    docs.forEachIndexed { index, document ->
                                        DocumentRow(
                                            document = document,
                                            isSelectionMode = uiState.isSelectionMode,
                                            isSelected = uiState.selectedDocuments.contains(document.id),
                                            onTap = {
                                                if (uiState.isSelectionMode) {
                                                    viewModel.toggleDocumentSelection(document.id ?: "")
                                                } else {
                                                    viewModel.selectDocumentForDetail(document)
                                                }
                                            },
                                            onViewClick = { doc ->
                                                viewModel.openDocumentViewer(doc) { resolvedDoc ->
                                                    if (onNavigateToViewer != null) onNavigateToViewer(resolvedDoc)
                                                    else viewingDocument = resolvedDoc
                                                }
                                            },
                                            onEditClick = { viewModel.selectDocumentForDetail(it) },
                                            onDeleteClick = { it.id?.let { id -> viewModel.deleteDocument(id) } }
                                        )
                                        if (index < docs.size - 1) {
                                            VaultCleanDivider()
                                        }
                                    }
                                }
                            }
                        }
                        VaultViewMode.Folders -> {
                            item { VaultSectionHeader("Folders") }
                            item {
                                VaultSectionCard {
                                    val folders = viewModel.groupedDocuments.keys.toList()
                                    folders.forEachIndexed { index, folderName ->
                                        val docs = viewModel.groupedDocuments[folderName] ?: emptyList()
                                        FolderRow(
                                            folderName = folderName,
                                            count = docs.size,
                                            onClick = { viewModel.openFolder(folderName) }
                                        )
                                        if (index < folders.size - 1) {
                                            VaultCleanDivider()
                                        }
                                    }
                                }
                            }
                        }
                        VaultViewMode.Timeline -> {
                            val grouped = viewModel.filteredDocuments.groupBy {
                                it.documentDate?.substringBefore("T") ?: "Unknown Date"
                            }
                            grouped.forEach { (date, docs) ->
                                item { VaultSectionHeader(date) }
                                item {
                                    VaultSectionCard {
                                        docs.forEachIndexed { index, document ->
                                            DocumentRow(
                                                document = document,
                                                isSelectionMode = false,
                                                isSelected = false,
                                                onTap = { viewModel.selectDocumentForDetail(document) },
                                                onViewClick = { viewModel.selectDocumentForDetail(it) },
                                                onEditClick = { viewModel.selectDocumentForDetail(it) },
                                                onDeleteClick = { }
                                            )
                                            if (index < docs.size - 1) {
                                                VaultCleanDivider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Floating Action Button
            if (!uiState.isSelectionMode) {
                FloatingActionButton(
                    onClick = {
                        batchFilePickerLauncher.launch(allowedMimeTypes)
                    },
                    containerColor = AppColors.primary,
                    contentColor = Color.White,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .windowInsetsPadding(WindowInsets.navigationBars)
                        .padding(end = 24.dp, bottom = 100.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Add", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Add Document Sheet (single file)
        AddDocumentBottomSheet(
            show = uiState.showAddSheet && pendingFileData != null,
            fileName = pendingFileName,
            fileSize = pendingFileSize,
            onUpload = { name, category, metadata ->
                pendingFileData?.let { data ->
                    viewModel.uploadDocument(
                        fileData = data,
                        fileName = pendingFileName,
                        category = category,
                        metadata = metadata
                    )
                }
            },
            onDismiss = { viewModel.setShowAddSheet(false) }
        )

        // Document Detail Sheet
        var detailImageUrl by remember { mutableStateOf<String?>(null) }

        LaunchedEffect(uiState.selectedDocumentDetail?.id) {
            detailImageUrl = null
            uiState.selectedDocumentDetail?.let { doc ->
                try {
                    detailImageUrl = viewModel.resolveSignedUrl(doc.fileUrl)
                } catch (_: Exception) {
                    detailImageUrl = null
                }
            }
        }

        DocumentDetailBottomSheet(
            document = uiState.selectedDocumentDetail,
            signedImageUrl = detailImageUrl,
            isEditMode = uiState.isEditMode,
            aiAnalysisResult = uiState.aiAnalysisResult,
            isAnalyzingAI = uiState.isAnalyzingAI,
            onDismiss = { viewModel.selectDocumentForDetail(null) },
            onViewDocument = { doc ->
                viewModel.selectDocumentForDetail(null)
                viewModel.openDocumentViewer(doc) { resolvedDoc ->
                    if (onNavigateToViewer != null) onNavigateToViewer(resolvedDoc)
                    else viewingDocument = resolvedDoc
                }
            },
            onToggleEditMode = { viewModel.setEditMode(it) },
            onSaveChanges = { id, title, category, notes, tags, doctorName, location, appointmentDate ->
                viewModel.updateDocumentMetadata(id, title, category, notes, tags, doctorName, location, appointmentDate)
            },
            onDeleteDocument = { doc ->
                doc.id?.let { viewModel.deleteDocument(it) }
            },
            onAskAI = { viewModel.analyzeDocumentWithAI(it) },
            onContinueInAIChat = { doc, analysis ->
                val isImage = doc.fileType.lowercase() in listOf("jpg", "jpeg", "png", "webp")
                com.swastricare.health.ui.screens.ai.PendingAIContext.set(
                    title = doc.title,
                    analysis = analysis,
                    imageUri = if (isImage) detailImageUrl else null
                )
                viewModel.selectDocumentForDetail(null)
                onNavigateToAIChat?.invoke()
            }
        )

        // Snackbar Host
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(bottom = 184.dp)
        )

        // Batch Upload Preview Sheet
        BatchUploadBottomSheet(
            show = uiState.showBatchUploadPreview,
            items = uiState.batchUploadItems,
            isUploading = uiState.isUploading,
            uploadProgress = uiState.uploadProgress,
            onCategoryChange = { index, category ->
                viewModel.updateBatchItemCategory(index, category)
            },
            onRemoveItem = { index -> viewModel.removeBatchItem(index) },
            onUploadAll = { viewModel.batchUploadDocuments() },
            onDismiss = { viewModel.dismissBatchUpload() }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Bottom Sheet Wrappers
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddDocumentBottomSheet(
    show: Boolean,
    fileName: String,
    fileSize: Long,
    onUpload: (String, VaultCategory, DocumentMetadata) -> Unit,
    onDismiss: () -> Unit
) {
    if (!show) return
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        AddDocumentSheet(
            fileName = fileName,
            fileSize = fileSize,
            onUpload = onUpload,
            onDismiss = onDismiss
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DocumentDetailBottomSheet(
    document: MedicalDocument?,
    signedImageUrl: String?,
    isEditMode: Boolean,
    aiAnalysisResult: String?,
    isAnalyzingAI: Boolean,
    onDismiss: () -> Unit,
    onViewDocument: (MedicalDocument) -> Unit,
    onToggleEditMode: (Boolean) -> Unit,
    onSaveChanges: (
        documentId: String,
        title: String,
        category: String,
        notes: String?,
        tags: List<String>,
        doctorName: String?,
        location: String?,
        appointmentDate: String?
    ) -> Unit,
    onDeleteDocument: (MedicalDocument) -> Unit,
    onAskAI: (MedicalDocument) -> Unit,
    onContinueInAIChat: (MedicalDocument, String) -> Unit
) {
    if (document == null) return
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        DocumentDetailSheet(
            document = document,
            signedImageUrl = signedImageUrl,
            isEditMode = isEditMode,
            aiAnalysisResult = aiAnalysisResult,
            isAnalyzingAI = isAnalyzingAI,
            onDismiss = onDismiss,
            onViewDocument = onViewDocument,
            onToggleEditMode = onToggleEditMode,
            onSaveChanges = onSaveChanges,
            onDeleteDocument = onDeleteDocument,
            onAskAI = onAskAI,
            onContinueInAIChat = onContinueInAIChat
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BatchUploadBottomSheet(
    show: Boolean,
    items: List<BatchUploadItem>,
    isUploading: Boolean,
    uploadProgress: Float,
    onCategoryChange: (Int, VaultCategory) -> Unit,
    onRemoveItem: (Int) -> Unit,
    onUploadAll: () -> Unit,
    onDismiss: () -> Unit
) {
    if (!show) return
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        BatchUploadPreviewSheet(
            items = items,
            isUploading = isUploading,
            uploadProgress = uploadProgress,
            onCategoryChange = onCategoryChange,
            onRemoveItem = onRemoveItem,
            onUploadAll = onUploadAll,
            onDismiss = onDismiss
        )
    }
}

// ─────────────────────────────────────
// MARK: - Selection Bar
// ─────────────────────────────────────

@Composable
fun SelectionBar(
    selectedCount: Int,
    onSelectAll: () -> Unit,
    onDelete: () -> Unit
) {
    Column(modifier = Modifier.padding(top = 8.dp)) {
        VaultSectionCard {
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "$selectedCount selected",
                    fontSize = 15.sp,
                    color = AppColors.onBackground
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    TextButton(onClick = onSelectAll) {
                        Text("Select All", fontSize = 13.sp)
                    }
                    TextButton(
                        onClick = onDelete,
                        colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
                    ) {
                        Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Delete", fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - View Composables (kept for backward compat)
// ─────────────────────────────────────

@Composable
fun DocumentListView(
    documents: List<MedicalDocument>,
    isSelectionMode: Boolean,
    selectedDocuments: Set<String>,
    onDocumentTap: (MedicalDocument) -> Unit,
    onViewClick: (MedicalDocument) -> Unit,
    onEditClick: (MedicalDocument) -> Unit,
    onDeleteClick: (MedicalDocument) -> Unit
) {
    VaultSectionCard {
        documents.forEachIndexed { index, document ->
            DocumentRow(
                document = document,
                isSelectionMode = isSelectionMode,
                isSelected = selectedDocuments.contains(document.id),
                onTap = { onDocumentTap(document) },
                onViewClick = onViewClick,
                onEditClick = onEditClick,
                onDeleteClick = onDeleteClick
            )
            if (index < documents.size - 1) {
                VaultCleanDivider()
            }
        }
    }
}

@Composable
fun FoldersGridView(
    groupedDocuments: Map<String, List<MedicalDocument>>,
    onFolderClick: (String) -> Unit
) {
    VaultSectionCard {
        val folders = groupedDocuments.keys.toList()
        folders.forEachIndexed { index, folderName ->
            val docs = groupedDocuments[folderName] ?: emptyList()
            FolderRow(
                folderName = folderName,
                count = docs.size,
                onClick = { onFolderClick(folderName) }
            )
            if (index < folders.size - 1) {
                VaultCleanDivider()
            }
        }
    }
}

@Composable
fun TimelineView(
    documents: List<MedicalDocument>,
    onDocumentTap: (MedicalDocument) -> Unit
) {
    val grouped = documents.groupBy { it.documentDate?.substringBefore("T") ?: "Unknown Date" }
    Column {
        grouped.forEach { (date, docs) ->
            VaultSectionHeader(date)
            VaultSectionCard {
                docs.forEachIndexed { index, document ->
                    DocumentRow(
                        document = document,
                        isSelectionMode = false,
                        isSelected = false,
                        onTap = { onDocumentTap(document) },
                        onViewClick = { onDocumentTap(it) },
                        onEditClick = { onDocumentTap(it) },
                        onDeleteClick = { }
                    )
                    if (index < docs.size - 1) {
                        VaultCleanDivider()
                    }
                }
            }
        }
    }
}

@Composable
fun FolderDetailView(
    folderName: String,
    documents: List<MedicalDocument>,
    onBack: () -> Unit,
    onDocumentTap: (MedicalDocument) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 88.dp)
    ) {
        // Header
        item {
            Column(
                modifier = Modifier.fillMaxWidth().padding(top = 24.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                    Spacer(modifier = Modifier.weight(1f))
                }
                Text(
                    folderName,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )
                Text(
                    "${documents.size} documents",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onBackground.copy(alpha = 0.5f)
                )
            }
        }

        if (documents.isEmpty()) {
            item {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "This folder is empty",
                        style = MaterialTheme.typography.bodyLarge,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
        } else {
            item { VaultSectionHeader("Documents") }
            item {
                VaultSectionCard {
                    documents.forEachIndexed { index, document ->
                        DocumentRow(
                            document = document,
                            isSelectionMode = false,
                            isSelected = false,
                            onTap = { onDocumentTap(document) },
                            onViewClick = { onDocumentTap(it) },
                            onEditClick = { onDocumentTap(it) },
                            onDeleteClick = { }
                        )
                        if (index < documents.size - 1) {
                            VaultCleanDivider()
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BatchUploadPreviewSheet(
    items: List<BatchUploadItem>,
    isUploading: Boolean,
    uploadProgress: Float,
    onCategoryChange: (Int, VaultCategory) -> Unit,
    onRemoveItem: (Int) -> Unit,
    onUploadAll: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Batch Upload",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "${items.size} files",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
        }

        if (isUploading) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                LinearProgressIndicator(
                    progress = { uploadProgress },
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "Uploading... ${(uploadProgress * 100).toInt()}%",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        // File list inside a section card
        VaultSectionCard {
            items.forEachIndexed { index, item ->
                BatchUploadItemRow(
                    item = item,
                    index = index,
                    onCategoryChange = { category -> onCategoryChange(index, category) },
                    onRemove = { onRemoveItem(index) },
                    enabled = !isUploading
                )
                if (index < items.size - 1) {
                    VaultCleanDivider()
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = onDismiss,
                modifier = Modifier.weight(1f),
                enabled = !isUploading,
                shape = RoundedCornerShape(14.dp)
            ) {
                Text("Cancel")
            }
            Button(
                onClick = onUploadAll,
                modifier = Modifier.weight(1f),
                enabled = items.isNotEmpty() && !isUploading,
                shape = RoundedCornerShape(14.dp)
            ) {
                Icon(Icons.Default.CloudUpload, contentDescription = null, modifier = Modifier.size(20.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Upload All", fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BatchUploadItemRow(
    item: BatchUploadItem,
    index: Int,
    onCategoryChange: (VaultCategory) -> Unit,
    onRemove: () -> Unit,
    enabled: Boolean
) {
    var showCategoryDropdown by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = getFileIcon(item.fileName.substringAfterLast('.', "")),
                    contentDescription = null,
                    tint = AppColors.onBackground.copy(alpha = 0.5f),
                    modifier = Modifier.size(20.dp)
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = item.fileName,
                        fontSize = 15.sp,
                        color = AppColors.onBackground,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = formatFileSize(item.fileSize),
                        fontSize = 12.sp,
                        color = AppColors.onBackground.copy(alpha = 0.4f)
                    )
                }
            }
            if (enabled) {
                IconButton(onClick = onRemove, modifier = Modifier.size(32.dp)) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Remove",
                        modifier = Modifier.size(18.dp),
                        tint = AppColors.error
                    )
                }
            }
        }

        Box {
            FilterChip(
                selected = true,
                onClick = { if (enabled) showCategoryDropdown = true },
                label = { Text(item.category.title, style = MaterialTheme.typography.bodySmall) },
                trailingIcon = {
                    Icon(
                        Icons.Default.ArrowDropDown,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                },
                border = FilterChipDefaults.filterChipBorder(
                    enabled = true,
                    selected = true,
                    borderColor = androidx.compose.ui.graphics.Color.Transparent,
                    selectedBorderColor = androidx.compose.ui.graphics.Color.Transparent
                )
            )
            DropdownMenu(
                expanded = showCategoryDropdown,
                onDismissRequest = { showCategoryDropdown = false }
            ) {
                VaultCategory.values().forEach { category ->
                    DropdownMenuItem(
                        text = { Text(category.title) },
                        onClick = {
                            onCategoryChange(category)
                            showCategoryDropdown = false
                        },
                        leadingIcon = {
                            if (item.category == category) {
                                Icon(
                                    Icons.Default.Check,
                                    contentDescription = null,
                                    tint = AppColors.primary,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun EmptyState() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Image(
            painter = rememberAsyncImagePainter("file:///android_asset/images/hand-drawn-no-data-concept.png"),
            contentDescription = null,
            modifier = Modifier.size(width = 160.dp, height = 140.dp),
            contentScale = androidx.compose.ui.layout.ContentScale.FillWidth,
            alignment = Alignment.TopCenter
        )
        Text(
            text = "Your vault is empty for now!",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Upload your medical records, prescriptions and lab reports to keep them organized.",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}
