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
import com.swastricare.health.ui.screens.auth.components.PremiumColors
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.components.TrackScreen
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer

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
        .background(Color.White)) {

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
                contentPadding = PaddingValues(bottom = 24.dp)
            ) {
                // ── Top Bar ──
                item {
                    com.swastricare.health.ui.components.AppTopBar(
                        title = "Medical Vault",
                        actions = {
                            var menuExpanded by remember { mutableStateOf(false) }
                            Box {
                                MaterialTheme(
                                    colorScheme = MaterialTheme.colorScheme,
                                    typography = MaterialTheme.typography,
                                    shapes = MaterialTheme.shapes.copy(
                                        extraSmall = RoundedCornerShape(18.dp)
                                    )
                                ) {
                                DropdownMenu(
                                    expanded = menuExpanded,
                                    onDismissRequest = { menuExpanded = false },
                                    offset = androidx.compose.ui.unit.DpOffset(x = (-8).dp, y = 4.dp),
                                    modifier = Modifier
                                        .widthIn(min = 220.dp)
                                        .background(AppColors.surface, RoundedCornerShape(18.dp))
                                ) {
                                    DropdownMenuItem(
                                        text = {
                                            Text(
                                                "Add document",
                                                fontSize = 14.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = AppColors.primary
                                            )
                                        },
                                        leadingIcon = {
                                            Box(
                                                modifier = Modifier
                                                    .size(32.dp)
                                                    .clip(RoundedCornerShape(10.dp))
                                                    .background(AppColors.primary.copy(alpha = 0.12f)),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Icon(
                                                    Icons.Default.Add,
                                                    contentDescription = null,
                                                    tint = AppColors.primary,
                                                    modifier = Modifier.size(18.dp)
                                                )
                                            }
                                        },
                                        onClick = {
                                            menuExpanded = false
                                            batchFilePickerLauncher.launch(allowedMimeTypes)
                                        }
                                    )

                                    HorizontalDivider(
                                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                                        color = AppColors.onSurface.copy(alpha = 0.08f)
                                    )

                                    Text(
                                        text = "View as",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = AppColors.onSurface.copy(alpha = 0.5f),
                                        modifier = Modifier.padding(start = 16.dp, top = 8.dp, bottom = 4.dp)
                                    )

                                    val viewOptions = listOf(
                                        Triple(VaultViewMode.List, "List", Icons.AutoMirrored.Outlined.List),
                                        Triple(VaultViewMode.Folders, "Folders", Icons.Outlined.Folder),
                                        Triple(VaultViewMode.Timeline, "Timeline", Icons.Outlined.CalendarToday)
                                    )
                                    for ((mode, label, icon) in viewOptions) {
                                        val selected = uiState.viewMode == mode
                                        DropdownMenuItem(
                                            text = {
                                                Text(
                                                    label,
                                                    fontSize = 14.sp,
                                                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                                                    color = if (selected) AppColors.primary else AppColors.onSurface
                                                )
                                            },
                                            leadingIcon = {
                                                Icon(
                                                    icon,
                                                    contentDescription = null,
                                                    tint = if (selected) AppColors.primary else AppColors.onSurface.copy(alpha = 0.7f),
                                                    modifier = Modifier.size(20.dp)
                                                )
                                            },
                                            trailingIcon = if (selected) {
                                                {
                                                    Icon(
                                                        Icons.Default.Check,
                                                        contentDescription = null,
                                                        tint = AppColors.primary,
                                                        modifier = Modifier.size(18.dp)
                                                    )
                                                }
                                            } else null,
                                            onClick = {
                                                menuExpanded = false
                                                viewModel.setViewMode(mode)
                                            }
                                        )
                                    }
                                }
                                }
                            }
                        }
                    )
                }

                // Search and category chips removed — vault uses two distinct
                // states (empty / with files) without filtering UI.

                // ── Storage card + category tiles (only when there are files) ──
                if (uiState.documents.isNotEmpty()) {
                    item {
                        Spacer(Modifier.height(4.dp))
                        StorageCard(
                            usedBytes = uiState.documents.sumOf { it.fileSize },
                            totalBytes = 1L * 1024 * 1024 * 1024,
                            onAddFiles = { filePickerLauncher.launch(arrayOf("*/*")) },
                            modifier = Modifier.padding(horizontal = 16.dp)
                        )
                    }
                    item {
                        Spacer(Modifier.height(12.dp))
                        VaultCategoryTilesRow(
                            allCount = uiState.documents.size,
                            reportsCount = uiState.documents.count {
                                it.category.equals(VaultCategory.LAB_REPORTS.title, ignoreCase = true)
                            },
                            prescriptionsCount = uiState.documents.count {
                                it.category.equals(VaultCategory.PRESCRIPTIONS.title, ignoreCase = true)
                            },
                            scansCount = uiState.documents.count {
                                it.category.equals(VaultCategory.IMAGING.title, ignoreCase = true)
                            },
                            selected = uiState.selectedCategory,
                            onSelectAll = { viewModel.setCategory(null) },
                            onSelectReports = { viewModel.setCategory(VaultCategory.LAB_REPORTS) },
                            onSelectPrescriptions = { viewModel.setCategory(VaultCategory.PRESCRIPTIONS) },
                            onSelectScans = { viewModel.setCategory(VaultCategory.IMAGING) },
                            modifier = Modifier.padding(horizontal = 16.dp)
                        )
                    }
                    item {
                        Spacer(Modifier.height(18.dp))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 20.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                when (uiState.selectedCategory) {
                                    null -> "All Files"
                                    VaultCategory.LAB_REPORTS -> "Reports"
                                    VaultCategory.PRESCRIPTIONS -> "Prescriptions"
                                    VaultCategory.IMAGING -> "Scans"
                                    else -> uiState.selectedCategory!!.title
                                },
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = AppColors.onSurface
                            )
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Text(
                                    "Sort by: Newest",
                                    fontSize = 12.sp,
                                    color = AppColors.onSurface.copy(alpha = 0.6f)
                                )
                                Box(
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(RoundedCornerShape(14.dp))
                                        .background(PremiumColors.Teal.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
                                        .clickable { filePickerLauncher.launch(arrayOf("*/*")) },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        Icons.Default.Add,
                                        contentDescription = "Add Files",
                                        tint = PremiumColors.Teal,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
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

                // ── Error / Offline Banner ──
                uiState.errorMessage?.let { error ->
                    item {
                        Spacer(Modifier.height(12.dp))
                        VaultErrorCard(
                            message = error,
                            onRetry = { viewModel.loadDocuments() },
                            modifier = Modifier.padding(horizontal = 16.dp)
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
                } else if (viewModel.filteredDocuments.isEmpty() && uiState.documents.isEmpty()) {
                    // Vault is completely empty — handled by EmptyState overlay outside the LazyColumn
                } else if (viewModel.filteredDocuments.isEmpty()) {
                    // Has documents but none match the selected category — handled by overlay below
                } else {
                    // Count / context caption
                    item {
                        Text(
                            text = "${viewModel.filteredDocuments.size} ${if (viewModel.filteredDocuments.size == 1) "document" else "documents"}",
                            fontSize = 12.sp,
                            color = AppColors.onBackground.copy(alpha = 0.5f),
                            modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 6.dp)
                        )
                    }

                    when (uiState.viewMode) {
                        VaultViewMode.List -> {
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
                                item {
                                    Text(
                                        text = formatTimelineDate(date),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = AppColors.onBackground.copy(alpha = 0.55f),
                                        modifier = Modifier.padding(start = 20.dp, top = 18.dp, bottom = 6.dp)
                                    )
                                }
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

            // Empty state — full-screen only when the vault is completely empty
            if (!uiState.isLoading && uiState.documents.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 88.dp),
                    contentAlignment = Alignment.TopCenter
                ) {
                    if (uiState.errorMessage != null) {
                        VaultOfflineState(
                            message = uiState.errorMessage!!,
                            onRetry = { viewModel.loadDocuments() }
                        )
                    } else {
                        EmptyState(
                            onAddFiles = { filePickerLauncher.launch(arrayOf("*/*")) }
                        )
                    }
                }
            }

            // Category empty — centered in the lower half of the screen
            if (!uiState.isLoading && uiState.documents.isNotEmpty() && viewModel.filteredDocuments.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(0.5f)
                            .align(Alignment.BottomCenter),
                        contentAlignment = Alignment.Center
                    ) {
                        CategoryEmptyState()
                    }
                }
            }


        }

        // Add Document Sheet (single file)
        AddDocumentBottomSheet(
            show = uiState.showAddSheet && pendingFileData != null,
            fileName = pendingFileName,
            fileSize = pendingFileSize,
            isUploading = uiState.isUploading,
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
                .padding(bottom = 24.dp)
        )

        // Batch Upload Preview Sheet
        BatchUploadBottomSheet(
            show = uiState.showBatchUploadPreview,
            items = uiState.batchUploadItems,
            folderName = uiState.batchFolderName,
            onFolderNameChange = viewModel::setBatchFolderName,
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
    isUploading: Boolean,
    onUpload: (String, VaultCategory, DocumentMetadata) -> Unit,
    onDismiss: () -> Unit
) {
    if (!show) return
    ModalBottomSheet(
        onDismissRequest = { if (!isUploading) onDismiss() },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.White,
        contentColor = Color(0xFF0F172A),
        tonalElevation = 0.dp,
        dragHandle = {}
    ) {
        AddDocumentSheet(
            fileName = fileName,
            fileSize = fileSize,
            onUpload = onUpload,
            onDismiss = onDismiss,
            isUploading = isUploading
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
    folderName: String,
    onFolderNameChange: (String) -> Unit,
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
            folderName = folderName,
            onFolderNameChange = onFolderNameChange,
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

@Composable
fun FolderDetailView(
    folderName: String,
    documents: List<MedicalDocument>,
    onBack: () -> Unit,
    onDocumentTap: (MedicalDocument) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp)
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
            item { Spacer(modifier = Modifier.height(12.dp)) }
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
    folderName: String,
    onFolderNameChange: (String) -> Unit,
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
                text = "Upload to folder",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "${items.size} files",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
        }

        // Folder name input — empty = files saved without a folder
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            color = AppColors.surfaceVariant,
            tonalElevation = 0.dp
        ) {
            TextField(
                value = folderName,
                onValueChange = onFolderNameChange,
                modifier = Modifier.fillMaxWidth(),
                enabled = !isUploading,
                placeholder = { Text("Folder name (optional)", fontSize = 14.sp) },
                leadingIcon = {
                    Icon(
                        Icons.Outlined.Folder,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                },
                trailingIcon = {
                    if (folderName.isNotEmpty()) {
                        IconButton(onClick = { onFolderNameChange("") }) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = "Clear",
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                },
                singleLine = true,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent,
                    focusedTextColor = AppColors.onSurface,
                    unfocusedTextColor = AppColors.onSurface
                )
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
private fun VaultErrorCard(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    val accent = Color(0xFFD97706) // amber-600 — matches the global offline banner tone
    val bg = Color(0xFFFFF7ED)
    val border = Color(0xFFFCD9A0)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(bg, RoundedCornerShape(14.dp))
            .border(1.dp, border, RoundedCornerShape(14.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.14f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.WifiOff,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "You're offline",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFF0F172A)
            )
            Spacer(Modifier.height(2.dp))
            Text(
                message,
                fontSize = 12.sp,
                color = Color(0xFF6B7280),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(accent, RoundedCornerShape(20.dp))
                .clickable(onClick = onRetry)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "Retry",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

@Composable
private fun VaultOfflineState(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    val accent = PremiumColors.Teal
    val mutedText = Color(0xFF6B7280)
    val darkText = Color(0xFF0F172A)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(108.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.10f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.WifiOff,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(48.dp)
            )
        }
        Spacer(Modifier.height(20.dp))
        Text(
            "You're offline",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = darkText,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(6.dp))
        Text(
            message,
            fontSize = 13.sp,
            lineHeight = 18.sp,
            color = mutedText,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp)
        )
        Spacer(Modifier.height(22.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(accent)
                .clickable(onClick = onRetry),
            contentAlignment = Alignment.Center
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Refresh,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "Try Again",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun CategoryEmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            "No files yet",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFF0F172A)
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "Add your health documents to\nkeep them safe and organized.",
            fontSize = 12.sp,
            color = Color(0xFF6B7280),
            textAlign = TextAlign.Center,
            lineHeight = 16.sp
        )
    }
}

@Composable
private fun StorageCard(
    usedBytes: Long,
    totalBytes: Long,
    onAddFiles: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val vaultBitmap = remember {
        runCatching {
            context.assets.open("icons/vault empty illustration.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    val percent = if (totalBytes > 0) (usedBytes.toFloat() / totalBytes).coerceIn(0f, 1f) else 0f
    val percentLabel = (percent * 100).toInt()
    val usedLabel = when {
        usedBytes >= 1_073_741_824L -> String.format("%.1f GB", usedBytes / 1_073_741_824.0)
        usedBytes >= 1_048_576L -> String.format("%.1f MB", usedBytes / 1_048_576.0)
        usedBytes > 0 -> String.format("%d KB", (usedBytes / 1024).coerceAtLeast(1))
        else -> "0 MB"
    }
    val totalLabel = when {
        totalBytes >= 1_073_741_824L -> "${(totalBytes / 1_073_741_824L).toInt()} GB"
        else -> "${(totalBytes / 1_048_576L).toInt()} MB"
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color(0xFFEFFAF6), RoundedCornerShape(18.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "Storage Used",
                fontSize = 12.sp,
                color = Color(0xFF6B7280),
                fontWeight = FontWeight.Medium
            )
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    usedLabel,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A)
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    "/ $totalLabel",
                    fontSize = 13.sp,
                    color = Color(0xFF6B7280),
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
            Spacer(Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(5.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(Color(0xFFD9EFE7))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(percent)
                        .clip(RoundedCornerShape(3.dp))
                        .background(PremiumColors.Teal)
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                "$percentLabel% used",
                fontSize = 11.sp,
                color = PremiumColors.Teal,
                fontWeight = FontWeight.SemiBold
            )
        }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (vaultBitmap != null) {
                Image(
                    bitmap = vaultBitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.size(96.dp)
                )
            }
        }
    }
}

@Composable
private fun VaultCategoryTilesRow(
    allCount: Int,
    reportsCount: Int,
    prescriptionsCount: Int,
    scansCount: Int,
    selected: VaultCategory?,
    onSelectAll: () -> Unit,
    onSelectReports: () -> Unit,
    onSelectPrescriptions: () -> Unit,
    onSelectScans: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        VaultCategoryTile(
            icon = Icons.Default.Folder,
            label = "All Files",
            count = allCount,
            tint = Color(0xFF38BDF8),
            background = Color(0xFFEFF8FE),
            selected = selected == null,
            modifier = Modifier.weight(1f),
            onClick = onSelectAll
        )
        VaultCategoryTile(
            icon = Icons.Default.Description,
            label = "Reports",
            count = reportsCount,
            tint = Color(0xFFF59E0B),
            background = Color(0xFFFEF8E1),
            selected = selected == VaultCategory.LAB_REPORTS,
            modifier = Modifier.weight(1f),
            onClick = onSelectReports
        )
        VaultCategoryTile(
            icon = Icons.Default.MedicalServices,
            label = "Prescriptions",
            count = prescriptionsCount,
            tint = Color(0xFFA855F7),
            background = Color(0xFFF3E8FF),
            selected = selected == VaultCategory.PRESCRIPTIONS,
            modifier = Modifier.weight(1f),
            onClick = onSelectPrescriptions
        )
        VaultCategoryTile(
            icon = Icons.Default.Image,
            label = "Scans",
            count = scansCount,
            tint = PremiumColors.Teal,
            background = Color(0xFFE6F8F3),
            selected = selected == VaultCategory.IMAGING,
            modifier = Modifier.weight(1f),
            onClick = onSelectScans
        )
    }
}

@Composable
private fun VaultCategoryTile(
    icon: ImageVector,
    label: String,
    count: Int,
    tint: Color,
    background: Color,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(background, RoundedCornerShape(14.dp))
            .border(
                width = if (selected) 1.5.dp else 0.dp,
                color = if (selected) tint else Color.Transparent,
                shape = RoundedCornerShape(14.dp)
            )
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(22.dp))
        Text(
            label,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF0F172A),
            maxLines = 1,
            softWrap = false
        )
        Text(
            count.toString(),
            fontSize = 11.sp,
            color = Color(0xFF6B7280)
        )
    }
}

@Composable
fun EmptyState(
    onAddFiles: () -> Unit = {},
    onLearnMore: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val uriHandler = androidx.compose.ui.platform.LocalUriHandler.current
    val handleLearnMore: () -> Unit = onLearnMore ?: {
        runCatching { uriHandler.openUri("https://swastricare.com/health-locker") }
    }
    val vaultBitmap = remember {
        runCatching {
            context.assets.open("icons/vault icon.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    val mutedText = Color(0xFF6B7280)
    val darkText = Color(0xFF0F172A)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.Top,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (vaultBitmap != null) {
            Image(
                bitmap = vaultBitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .size(180.dp)
                    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                    .drawWithContent {
                        drawContent()
                        val fadeX = size.width * 0.18f
                        val fadeY = size.height * 0.18f
                        drawRect(
                            brush = Brush.horizontalGradient(
                                0f to Color.Transparent,
                                (fadeX / size.width) to Color.Black,
                                1f - (fadeX / size.width) to Color.Black,
                                1f to Color.Transparent
                            ),
                            blendMode = BlendMode.DstIn
                        )
                        drawRect(
                            brush = Brush.verticalGradient(
                                0f to Color.Transparent,
                                (fadeY / size.height) to Color.Black,
                                1f - (fadeY / size.height) to Color.Black,
                                1f to Color.Transparent
                            ),
                            blendMode = BlendMode.DstIn
                        )
                    }
            )
        }

        Spacer(Modifier.height(8.dp))

        Text(
            "Your vault is empty",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = darkText,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(6.dp))

        Text(
            "Store your important health documents, reports and prescriptions securely.",
            fontSize = 13.sp,
            lineHeight = 18.sp,
            color = mutedText,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp)
        )

        Spacer(Modifier.height(20.dp))

        VaultFeatureRow(
            icon = Icons.Default.Lock,
            title = "Secure Storage",
            description = "Your files are encrypted and protected"
        )
        Spacer(Modifier.height(14.dp))
        VaultFeatureRow(
            icon = Icons.Default.Description,
            title = "Private Access",
            description = "Only you can access your files"
        )
        Spacer(Modifier.height(14.dp))
        VaultFeatureRow(
            icon = Icons.Default.Share,
            title = "Easy Sharing",
            description = "Share files with doctors when needed"
        )

        Spacer(Modifier.height(22.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(PremiumColors.Teal)
                .clickable(onClick = onAddFiles),
            contentAlignment = Alignment.Center
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Add,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "Add Files",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .clip(RoundedCornerShape(24.dp))
                .border(1.dp, PremiumColors.Teal.copy(alpha = 0.5f), RoundedCornerShape(24.dp))
                .clickable(onClick = handleLearnMore),
            contentAlignment = Alignment.Center
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Info,
                    contentDescription = null,
                    tint = PremiumColors.Teal,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "Learn more about Vault",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = PremiumColors.Teal
                )
            }
        }

        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun VaultFeatureRow(
    icon: ImageVector,
    title: String,
    description: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(PremiumColors.Teal.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = PremiumColors.Teal,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFF0F172A)
            )
            Spacer(Modifier.height(2.dp))
            Text(
                description,
                fontSize = 12.sp,
                color = Color(0xFF6B7280)
            )
        }
    }
}
