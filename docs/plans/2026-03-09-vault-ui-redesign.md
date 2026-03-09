# Vault UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Android Vault screen with shimmer loading, improved document detail sheet with hero image, working MoreVert menu, appointment date with notifications, edit mode, and inline Ask AI analysis.

**Architecture:** Modify existing vault UI components in-place. Leverage existing `AppointmentAlarmScheduler` and `AIService` infrastructure. Add shimmer composable utility. Expand `DocumentDetailSheet` with view/edit toggle and AI analysis. Wire up MoreVert dropdown menu with real actions.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, existing Supabase AI service, existing AlarmManager notification system.

---

### Task 1: Add Shimmer Effect Composable

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/ShimmerEffect.kt`

**Step 1: Create shimmer utility and skeleton composables**

```kotlin
package com.swasthicare.mobile.ui.screens.vault

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun shimmerBrush(): Brush {
    val shimmerColors = listOf(
        Color(0xFFE0E0E0),
        Color(0xFFF5F5F5),
        Color(0xFFE0E0E0)
    )
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim = transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmer_translate"
    )
    return Brush.linearGradient(
        colors = shimmerColors,
        start = Offset(translateAnim.value - 200f, 0f),
        end = Offset(translateAnim.value, 0f)
    )
}

@Composable
fun ShimmerDocumentCard() {
    val brush = shimmerBrush()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Icon placeholder
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(brush)
        )
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            // Title
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.7f)
                    .height(16.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(brush)
            )
            Spacer(modifier = Modifier.height(8.dp))
            // Category + date
            Row {
                Box(
                    modifier = Modifier
                        .width(80.dp)
                        .height(12.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(brush)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Box(
                    modifier = Modifier
                        .width(60.dp)
                        .height(12.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(brush)
                )
            }
            Spacer(modifier = Modifier.height(6.dp))
            // Doctor name
            Box(
                modifier = Modifier
                    .width(100.dp)
                    .height(10.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(brush)
            )
        }
        // MoreVert placeholder
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(brush)
        )
    }
}

@Composable
fun ShimmerDocumentList(count: Int = 4) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        repeat(count) {
            ShimmerDocumentCard()
        }
    }
}
```

**Step 2: Integrate shimmer into VaultScreen.kt**

In `VaultScreen.kt`, replace line 354-355:
```kotlin
// OLD:
if (uiState.isLoading && uiState.documents.isEmpty()) {
    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
}
```
With:
```kotlin
// NEW:
if (uiState.isLoading && uiState.documents.isEmpty()) {
    ShimmerDocumentList()
}
```

**Step 3: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/ShimmerEffect.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt
git commit -m "feat(android/vault): add shimmer skeleton loading"
```

---

### Task 2: Fix MoreVert Dropdown Menu

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultComponents.kt` (lines 68-174)
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt` (lines 631-653, 360-371, 710-718)

**Step 1: Update DocumentCard to include a working DropdownMenu**

Change `DocumentCard` signature — replace `onMoreClick: () -> Unit` with three specific callbacks:
```kotlin
@Composable
fun DocumentCard(
    document: MedicalDocument,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onTap: () -> Unit,
    onViewClick: (MedicalDocument) -> Unit,
    onEditClick: (MedicalDocument) -> Unit,
    onDeleteClick: (MedicalDocument) -> Unit
)
```

Inside `DocumentCard`, replace the `IconButton(onClick = onMoreClick)` block (lines 163-171) with:
```kotlin
if (!isSelectionMode) {
    var showMenu by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { showMenu = true }) {
            Icon(
                imageVector = Icons.Default.MoreVert,
                contentDescription = "More",
                tint = AppColors.onSurfaceVariant
            )
        }
        DropdownMenu(
            expanded = showMenu,
            onDismissRequest = { showMenu = false }
        ) {
            DropdownMenuItem(
                text = { Text("View") },
                onClick = { showMenu = false; onViewClick(document) },
                leadingIcon = { Icon(Icons.Default.Visibility, contentDescription = null, modifier = Modifier.size(20.dp)) }
            )
            DropdownMenuItem(
                text = { Text("Edit") },
                onClick = { showMenu = false; onEditClick(document) },
                leadingIcon = { Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(20.dp)) }
            )
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text("Delete", color = AppColors.error) },
                onClick = { showMenu = false; onDeleteClick(document) },
                leadingIcon = { Icon(Icons.Default.Delete, contentDescription = null, tint = AppColors.error, modifier = Modifier.size(20.dp)) }
            )
        }
    }
}
```

Add `import androidx.compose.runtime.*` and `import androidx.compose.material3.DropdownMenu` and `import androidx.compose.material3.DropdownMenuItem` if not already present.

**Step 2: Update all DocumentCard call sites in VaultScreen.kt**

In `DocumentListView` (line 631-653), update signature and usage:
```kotlin
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
```

Update the call site in VaultScreen (line 360-372):
```kotlin
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
```

Also update `TimelineView` and `FolderDetailView` DocumentCard usages similarly. For timeline/folder, pass the same callbacks.

**Step 3: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultComponents.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt
git commit -m "fix(android/vault): wire MoreVert dropdown with View, Edit, Delete actions"
```

---

### Task 3: Add AI Analysis and Appointment State to VaultViewModel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt`

**Step 1: Add new state fields to VaultUiState**

Add these fields to `VaultUiState` (after line 33):
```kotlin
val aiAnalysisResult: String? = null,
val isAnalyzingAI: Boolean = false,
val isEditMode: Boolean = false
```

**Step 2: Add AI analysis function to VaultViewModel**

Add `AIService` dependency and analysis function:
```kotlin
// Add import
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.AppointmentAlarmScheduler
import android.util.Base64

// Add to constructor parameters:
private val aiService: AIService = AppContainer.aiService,
private val appointmentScheduler: AppointmentAlarmScheduler = AppContainer.appointmentAlarmScheduler

// Add these functions:

fun analyzeDocumentWithAI(document: MedicalDocument) {
    viewModelScope.launch {
        _uiState.update { it.copy(isAnalyzingAI = true, aiAnalysisResult = null) }
        try {
            val signedUrl = repository.getSignedUrl(document.fileUrl)
            // Download image bytes and encode to base64
            val imageBytes = java.net.URL(signedUrl).readBytes()
            val base64 = Base64.encodeToString(imageBytes, Base64.NO_WRAP)
            val prompt = "Analyze this medical document. Provide a brief summary of what this document contains, key findings, and any important dates or values mentioned. Keep it concise (3-4 sentences)."
            val request = com.swasthicare.mobile.data.models.ChatRequest(
                message = prompt,
                conversationHistory = emptyList(),
                imageData = base64
            )
            val response = aiService.sendChatMessage(prompt, emptyList())
            _uiState.update { it.copy(isAnalyzingAI = false, aiAnalysisResult = response) }
        } catch (e: Exception) {
            _uiState.update { it.copy(isAnalyzingAI = false, aiAnalysisResult = "Unable to analyze document: ${e.message}") }
        }
    }
}

fun clearAIAnalysis() {
    _uiState.update { it.copy(aiAnalysisResult = null, isAnalyzingAI = false) }
}

fun setEditMode(editing: Boolean) {
    _uiState.update { it.copy(isEditMode = editing) }
}
```

**Step 3: Expand updateDocumentMetadata to include all editable fields + appointment scheduling**

Replace the existing `updateDocumentMetadata` function (lines 231-246):
```kotlin
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
            _uiState.update { it.copy(errorMessage = "Failed to update document: ${e.message}") }
        }
    }
}
```

**Step 4: Override selectDocumentForDetail to clear AI state**

Replace existing (line 211-213):
```kotlin
fun selectDocumentForDetail(document: MedicalDocument?) {
    _uiState.update { it.copy(selectedDocumentDetail = document, aiAnalysisResult = null, isAnalyzingAI = false, isEditMode = false) }
}
```

**Step 5: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt
git commit -m "feat(android/vault): add AI analysis, appointment scheduling, edit mode to ViewModel"
```

---

### Task 4: Expand Repository updateDocument to Include All Fields

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/VaultRepository.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/SupabaseVaultRepository.kt`

**Step 1: Update VaultRepository interface**

Update the `updateDocument` signature in `VaultRepository.kt`:
```kotlin
suspend fun updateDocument(
    documentId: String,
    title: String,
    category: String,
    notes: String?,
    tags: List<String>,
    doctorName: String? = null,
    location: String? = null,
    appointmentDate: String? = null
): MedicalDocument
```

Also update the mock implementation if present.

**Step 2: Update SupabaseVaultRepository**

In `SupabaseVaultRepository.kt`, update the `updateDocument` function (lines 185-225):
```kotlin
override suspend fun updateDocument(
    documentId: String,
    title: String,
    category: String,
    notes: String?,
    tags: List<String>,
    doctorName: String?,
    location: String?,
    appointmentDate: String?
): MedicalDocument = withContext(Dispatchers.IO) {
    val userId = requireUserId()

    val updatePayload = buildJsonObject {
        put("title", title)
        put("category", category)
        if (notes != null) put("notes", notes) else put("notes", kotlinx.serialization.json.JsonNull)
        putJsonArray("tags") {
            tags.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
        }
        if (doctorName != null) put("doctor_name", doctorName) else put("doctor_name", kotlinx.serialization.json.JsonNull)
        if (location != null) put("location", location) else put("location", kotlinx.serialization.json.JsonNull)
        if (appointmentDate != null) put("appointment_date", appointmentDate) else put("appointment_date", kotlinx.serialization.json.JsonNull)
    }

    try {
        supabaseClient.from(tableName).update(updatePayload) {
            filter {
                eq("id", documentId)
                eq("user_id", userId)
            }
        }
        val updated = supabaseClient.from(tableName).select {
            filter {
                eq("id", documentId)
                eq("user_id", userId)
            }
        }.decodeList<MedicalDocument>().firstOrNull()
            ?: throw Exception("Document not found after update")
        updated
    } catch (e: Exception) {
        Log.e(TAG, "Failed to update document $documentId: ${e.message}")
        throw e
    }
}
```

**Step 3: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/VaultRepository.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/SupabaseVaultRepository.kt
git commit -m "feat(android/vault): expand updateDocument to support all editable fields"
```

---

### Task 5: Redesign DocumentDetailSheet

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/DocumentDetailSheet.kt`

**Step 1: Rewrite DocumentDetailSheet with hero image, view/edit toggle, Ask AI, appointment date**

Full rewrite of `DocumentDetailSheet.kt`. The new sheet has:
- Hero image preview at top (full-width, 200dp, loaded from signed URL via AsyncImage)
- View mode: displays all metadata with action buttons row
- Edit mode: all fields editable including appointment date picker, doctor name, location
- Ask AI section: button triggers analysis, shows inline result with "Continue in AI Chat" link
- Actions: View Full, Ask AI, Edit, Delete

Key changes to the function signature:
```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentDetailSheet(
    document: MedicalDocument,
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
)
```

The layout structure:
1. Hero image (AsyncImage with Coil, or PDF icon placeholder) — 200dp, fillMaxWidth, rounded top
2. Title + category chip row
3. If view mode: metadata rows (doctor, appointment date, location, file size/type as secondary)
4. If edit mode: OutlinedTextFields for title, category dropdown, notes, tags, appointment date picker, doctor name, location
5. AI Analysis section (only shown after "Ask AI" tapped): shimmer while loading, then result card with "Continue in AI Chat"
6. Action buttons row: View Full | Ask AI | Edit | Delete

Important: Add `coil-compose` dependency import: `import coil.compose.AsyncImage`
(Coil should already be a project dependency for image loading elsewhere.)

**Step 2: Update VaultScreen.kt call site for DocumentDetailSheet**

In `VaultScreen.kt`, update the `DocumentDetailSheet` invocation (lines 434-461). Before the sheet, resolve a signed URL for the image preview:

```kotlin
// Add state for signed image URL
var detailImageUrl by remember { mutableStateOf<String?>(null) }

// When selectedDocumentDetail changes, resolve signed URL
LaunchedEffect(uiState.selectedDocumentDetail?.id) {
    uiState.selectedDocumentDetail?.let { doc ->
        try {
            detailImageUrl = viewModel.resolveSignedUrl(doc.fileUrl)
        } catch (_: Exception) {
            detailImageUrl = null
        }
    }
}
```

Add a `resolveSignedUrl` suspend function to VaultViewModel:
```kotlin
suspend fun resolveSignedUrl(path: String): String = repository.getSignedUrl(path)
```

Update the sheet invocation:
```kotlin
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
                viewModel.selectDocumentForDetail(null)
                // Navigate to AI screen — handled by parent navigation callback
            }
        )
    }
}
```

**Step 3: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/DocumentDetailSheet.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt
git commit -m "feat(android/vault): redesign DocumentDetailSheet with hero image, edit mode, Ask AI"
```

---

### Task 6: Polish AddDocumentSheet

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/AddDocumentSheet.kt`

**Step 1: Improve layout**

Changes to `AddDocumentSheet.kt`:
- Move the file info card to be more compact: icon + filename on one line, file size as secondary text below
- Use `formatFileSize()` from `DocumentDetailSheet.kt` instead of raw `fileSize / 1024`
- Add appointment date field with DatePicker (reuse the existing pattern in the file)
- De-emphasize file size/type — show them smaller, at the bottom
- Ensure category chips use `FilterChip` in a `FlowRow` or `LazyRow` instead of `ScrollableTabRow`

Key layout changes:
```kotlin
// File info card — more compact
Card(
    colors = CardDefaults.cardColors(containerColor = AppColors.surfaceVariant.copy(alpha = 0.3f)),
    modifier = Modifier.fillMaxWidth()
) {
    Row(
        modifier = Modifier.padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = getFileIcon(fileName.substringAfterLast('.', "")),
            contentDescription = null,
            tint = AppColors.primary,
            modifier = Modifier.size(32.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = fileName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = formatFileSize(fileSize),
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}
```

Add appointment date field (after the document date field):
```kotlin
// Appointment Date (optional)
var appointmentDate by remember { mutableStateOf<LocalDate?>(null) }
var showAppointmentDatePicker by remember { mutableStateOf(false) }

OutlinedTextField(
    value = appointmentDate?.format(DateTimeFormatter.ISO_LOCAL_DATE) ?: "",
    onValueChange = {},
    label = { Text("Appointment Date (Optional)") },
    readOnly = true,
    placeholder = { Text("Set reminder for appointment") },
    trailingIcon = {
        IconButton(onClick = { showAppointmentDatePicker = true }) {
            Icon(Icons.Default.Notifications, contentDescription = "Set Appointment")
        }
    },
    modifier = Modifier.fillMaxWidth()
)
```

Update the `DocumentMetadata` creation to include `appointmentDate`:
```kotlin
val metadata = DocumentMetadata(
    name = title,
    description = description.takeIf { it.isNotBlank() },
    folderName = folderName.takeIf { it.isNotBlank() },
    documentDate = documentDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
    appointmentDate = appointmentDate?.format(DateTimeFormatter.ISO_LOCAL_DATE),
    doctorName = doctorName.takeIf { it.isNotBlank() },
    location = location.takeIf { it.isNotBlank() },
    tags = tags.split(",").map { it.trim() }.filter { it.isNotBlank() }
)
```

**Step 2: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/AddDocumentSheet.kt
git commit -m "feat(android/vault): polish AddDocumentSheet with appointment date and cleaner layout"
```

---

### Task 7: Build and Verify

**Step 1: Run the build**
```bash
cd android && ./gradlew assembleDebug
```
Expected: BUILD SUCCESSFUL

**Step 2: Fix any compilation errors**

Address any import issues, missing parameters, or type mismatches that arise.

**Step 3: Final commit**
```bash
git add -A
git commit -m "feat(android/vault): complete vault UI redesign - shimmer, MoreVert, detail sheet, Ask AI, appointments"
```
