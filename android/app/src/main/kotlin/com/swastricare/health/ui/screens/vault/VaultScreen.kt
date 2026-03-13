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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.runtime.LaunchedEffect
import kotlinx.coroutines.launch
import com.swastricare.health.data.model.MedicalDocument
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VaultScreen(
    viewModel: VaultViewModel = hiltViewModel(),
    onNavigateToViewer: ((MedicalDocument) -> Unit)? = null,
    onNavigateToAIChat: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

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
            // Validate file size (fallback via file descriptor if cursor returned 0)
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
            // Single file: use normal flow
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
            // Validate file size
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
            // Multiple files: batch upload flow with size validation
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
                    // Validate file size
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

    // Internal document viewer state (when no external navigation is provided)
    var viewingDocument by remember { mutableStateOf<MedicalDocument?>(null) }

    // Show full-screen viewer if viewing a document internally
    if (viewingDocument != null && onNavigateToViewer == null) {
        DocumentViewerScreen(
            document = viewingDocument!!,
            onBack = { viewingDocument = null }
        )
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

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
            // Main Vault Content
            Column(
                modifier = Modifier
                    .fillMaxSize()
            ) {
                TopAppBar(
                    title = {
                        Text(
                            text = "Medical Vault",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold
                        )
                    },
                    navigationIcon = {
                        if (onBack != null) {
                            IconButton(onClick = onBack) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                            }
                        }
                    },
                    actions = {
                        IconButton(
                            onClick = {
                                val newMode = when (uiState.viewMode) {
                                    VaultViewMode.List -> VaultViewMode.Folders
                                    VaultViewMode.Folders -> VaultViewMode.Timeline
                                    VaultViewMode.Timeline -> VaultViewMode.List
                                }
                                viewModel.setViewMode(newMode)
                            }
                        ) {
                            Icon(
                                imageVector = when (uiState.viewMode) {
                                    VaultViewMode.List -> Icons.Default.List
                                    VaultViewMode.Folders -> Icons.Default.Folder
                                    VaultViewMode.Timeline -> Icons.Default.CalendarToday
                                },
                                contentDescription = "View Mode"
                            )
                        }
                        IconButton(onClick = viewModel::toggleSelectionMode) {
                            Icon(
                                imageVector = if (uiState.isSelectionMode) Icons.Default.Close else Icons.Default.CheckCircle,
                                contentDescription = "Select"
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent
                    ),
                    windowInsets = WindowInsets(0, 0, 0, 0)
                )

                // Search Bar
                TextField(
                    value = uiState.searchQuery,
                    onValueChange = viewModel::setSearchQuery,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                        .height(56.dp),
                    placeholder = { Text("Search documents...") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    shape = RoundedCornerShape(14.dp),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = AppColors.surfaceVariant,
                        unfocusedContainerColor = AppColors.surfaceVariant,
                        disabledContainerColor = AppColors.surfaceVariant,
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

                // Category Filters
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    modifier = Modifier.fillMaxWidth()
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

                // Selection Bar
                if (uiState.isSelectionMode) {
                    SelectionBar(
                        selectedCount = uiState.selectedDocuments.size,
                        onSelectAll = viewModel::selectAllDocuments,
                        onDelete = viewModel::deleteSelectedDocuments
                    )
                }

                // Upload Progress
                if (uiState.isUploading) {
                    LinearProgressIndicator(
                        progress = { uiState.uploadProgress },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                // Error Message
                uiState.errorMessage?.let { error ->
                    Text(
                        text = error,
                        color = AppColors.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }

                // Content
                Box(modifier = Modifier.weight(1f)) {
                    if (uiState.isLoading && uiState.documents.isEmpty()) {
                        ShimmerDocumentList()
                    } else if (viewModel.filteredDocuments.isEmpty()) {
                        EmptyState()
                    } else {
                        when (uiState.viewMode) {
                            VaultViewMode.List -> DocumentListView(
                                documents = viewModel.filteredDocuments,
                                isSelectionMode = uiState.isSelectionMode,
                                selectedDocuments = uiState.selectedDocuments,
                                onDocumentTap = {
                                    if (uiState.isSelectionMode) {
                                        viewModel.toggleDocumentSelection(it.id ?: "")
                                    } else {
                                        viewModel.selectDocumentForDetail(it)
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
                            VaultViewMode.Folders -> FoldersGridView(
                                groupedDocuments = viewModel.groupedDocuments,
                                onFolderClick = { viewModel.openFolder(it) }
                            )
                            VaultViewMode.Timeline -> TimelineView(
                                documents = viewModel.filteredDocuments,
                                onDocumentTap = { viewModel.selectDocumentForDetail(it) }
                            )
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
                        .padding(24.dp)
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
        if (uiState.showAddSheet && pendingFileData != null) {
            ModalBottomSheet(
                onDismissRequest = { viewModel.setShowAddSheet(false) },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ) {
                AddDocumentSheet(
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
            }
        }

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

        if (uiState.selectedDocumentDetail != null) {
            ModalBottomSheet(
                onDismissRequest = { viewModel.selectDocumentForDetail(null) },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ) {
                DocumentDetailSheet(
                    document = uiState.selectedDocumentDetail!!,
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
                        com.swastricare.health.ui.screens.ai.PendingAIContext.set(
                            title = doc.title,
                            analysis = analysis
                        )
                        viewModel.selectDocumentForDetail(null)
                        onNavigateToAIChat?.invoke()
                    }
                )
            }
        }

        // Snackbar Host (overlays all content)
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 96.dp) // above FAB
        )

        // Batch Upload Preview Sheet
        if (uiState.showBatchUploadPreview) {
            ModalBottomSheet(
                onDismissRequest = { viewModel.dismissBatchUpload() },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ) {
                BatchUploadPreviewSheet(
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
    }
}

@Composable
fun VaultAppBar(
    totalDocuments: Int,
    viewMode: VaultViewMode,
    onViewModeChange: (VaultViewMode) -> Unit,
    isSelectionMode: Boolean,
    onToggleSelectionMode: () -> Unit,
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .glass()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Medical Vault",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "$totalDocuments documents",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                // View Mode Toggle
                IconButton(
                    onClick = {
                        val newMode = when (viewMode) {
                            VaultViewMode.List -> VaultViewMode.Folders
                            VaultViewMode.Folders -> VaultViewMode.Timeline
                            VaultViewMode.Timeline -> VaultViewMode.List
                        }
                        onViewModeChange(newMode)
                    },
                    colors = IconButtonDefaults.iconButtonColors(
                        containerColor = AppColors.surfaceVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Icon(
                        imageVector = when (viewMode) {
                            VaultViewMode.List -> Icons.Default.List
                            VaultViewMode.Folders -> Icons.Default.Folder
                            VaultViewMode.Timeline -> Icons.Default.CalendarToday
                        },
                        contentDescription = "View Mode"
                    )
                }

                // Selection Mode
                IconButton(
                    onClick = onToggleSelectionMode,
                    colors = IconButtonDefaults.iconButtonColors(
                        containerColor = AppColors.surfaceVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Icon(
                        imageVector = if (isSelectionMode) Icons.Default.Close else Icons.Default.CheckCircle,
                        contentDescription = "Select"
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Search Bar
        TextField(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            placeholder = { Text("Search documents...") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            shape = RoundedCornerShape(14.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = AppColors.surfaceVariant,
                unfocusedContainerColor = AppColors.surfaceVariant,
                disabledContainerColor = AppColors.surfaceVariant,
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

@Composable
fun SelectionBar(
    selectedCount: Int,
    onSelectAll: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("$selectedCount selected", style = MaterialTheme.typography.bodyMedium)

        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            TextButton(onClick = onSelectAll) {
                Text("Select All")
            }
            TextButton(
                onClick = onDelete,
                colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
            ) {
                Icon(Icons.Default.Delete, contentDescription = null)
                Spacer(modifier = Modifier.width(4.dp))
                Text("Delete")
            }
        }
    }
}

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
    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(documents) { document ->
            DocumentCard(
                document = document,
                isSelectionMode = isSelectionMode,
                isSelected = selectedDocuments.contains(document.id),
                onTap = { onDocumentTap(document) },
                onViewClick = onViewClick,
                onEditClick = onEditClick,
                onDeleteClick = onDeleteClick
            )
        }
    }
}

@Composable
fun FoldersGridView(
    groupedDocuments: Map<String, List<MedicalDocument>>,
    onFolderClick: (String) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        contentPadding = PaddingValues(20.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        items(groupedDocuments.keys.toList()) { folderName ->
            val docs = groupedDocuments[folderName] ?: emptyList()
            val color = if (folderName.hashCode() % 2 == 0) Color(0xFF2E3192) else Color(0xFF1BBBCE)

            FolderCard(
                folderName = folderName,
                count = docs.size,
                color = color,
                onClick = { onFolderClick(folderName) }
            )
        }
    }
}

@Composable
fun TimelineView(
    documents: List<MedicalDocument>,
    onDocumentTap: (MedicalDocument) -> Unit
) {
    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text(
                "Timeline",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }

        // Group by date
        val grouped = documents.groupBy { it.documentDate?.substringBefore("T") ?: "Unknown Date" }

        grouped.forEach { (date, docs) ->
            item {
                Text(
                    text = date,
                    style = MaterialTheme.typography.labelLarge,
                    color = AppColors.primary,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
            items(docs) { document ->
                DocumentCard(
                    document = document,
                    isSelectionMode = false,
                    isSelected = false,
                    onTap = { onDocumentTap(document) },
                    onViewClick = { onDocumentTap(it) },
                    onEditClick = { onDocumentTap(it) },
                    onDeleteClick = { }
                )
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
    Column(modifier = Modifier.fillMaxSize()) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp, start = 8.dp, end = 20.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Back")
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = folderName,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "${documents.size} documents",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        // Documents in folder
        if (documents.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "This folder is empty",
                    style = MaterialTheme.typography.bodyLarge,
                    color = AppColors.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(documents) { document ->
                    DocumentCard(
                        document = document,
                        isSelectionMode = false,
                        isSelected = false,
                        onTap = { onDocumentTap(document) },
                        onViewClick = { onDocumentTap(it) },
                        onEditClick = { onDocumentTap(it) },
                        onDeleteClick = { }
                    )
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
        // Header
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

        // File list
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 400.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            itemsIndexed(items) { index, item ->
                BatchUploadItemCard(
                    item = item,
                    index = index,
                    onCategoryChange = { category -> onCategoryChange(index, category) },
                    onRemove = { onRemoveItem(index) },
                    enabled = !isUploading
                )
            }
        }

        // Actions
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
private fun BatchUploadItemCard(
    item: BatchUploadItem,
    index: Int,
    onCategoryChange: (VaultCategory) -> Unit,
    onRemove: () -> Unit,
    enabled: Boolean
) {
    var showCategoryDropdown by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 14.dp)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
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
                        tint = AppColors.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = item.fileName,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                        )
                        Text(
                            text = formatFileSize(item.fileSize),
                            style = MaterialTheme.typography.bodySmall,
                            color = AppColors.onSurfaceVariant
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

            // Category selector
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
                    }
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
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.FolderOpen,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = AppColors.primary.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "No Documents Yet",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "Upload your medical records to get started",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant
        )
    }
}
