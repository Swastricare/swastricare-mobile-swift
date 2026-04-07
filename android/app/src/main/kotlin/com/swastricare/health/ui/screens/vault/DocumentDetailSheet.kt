package com.swastricare.health.ui.screens.vault

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.data.model.MedicalDocument
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

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
) {
    val haptic = LocalHapticFeedback.current

    // Edit state
    var editedTitle by remember(document.id) { mutableStateOf(document.title) }
    var editedCategory by remember(document.id) {
        mutableStateOf(VaultCategory.fromValue(document.category))
    }
    var editedNotes by remember(document.id) { mutableStateOf(document.notes ?: "") }
    var editedDoctorName by remember(document.id) { mutableStateOf(document.doctorName ?: "") }
    var editedLocation by remember(document.id) { mutableStateOf(document.location ?: "") }
    var editedAppointmentDate by remember(document.id) {
        mutableStateOf(document.appointmentDate?.substringBefore("T") ?: "")
    }
    var editedTagsRaw by remember(document.id) {
        mutableStateOf(document.tags?.joinToString(", ") ?: "")
    }

    // Dialog state
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showCategoryPicker by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }

    val isImageFile = document.fileType.lowercase() in listOf("jpg", "jpeg", "png")

    // ---------- Delete confirmation ----------
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            icon = {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = AppColors.error
                )
            },
            title = { Text("Delete Document") },
            text = {
                Text("Are you sure you want to delete \"${document.title}\"? This action cannot be undone.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        onDeleteDocument(document)
                        onDismiss()
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
                ) { Text("Delete", fontWeight = FontWeight.Bold) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            }
        )
    }

    // ---------- Date picker ----------
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState()
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        val cal = java.util.Calendar.getInstance().apply {
                            timeInMillis = millis
                        }
                        val formatted = "%04d-%02d-%02d".format(
                            cal.get(java.util.Calendar.YEAR),
                            cal.get(java.util.Calendar.MONTH) + 1,
                            cal.get(java.util.Calendar.DAY_OF_MONTH)
                        )
                        editedAppointmentDate = formatted
                    }
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    // ---------- Root column — hero is edge-to-edge, rest is padded ----------
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
    ) {
        // ---- A. Hero image preview ----
        HeroImageSection(
            isImageFile = isImageFile,
            fileType = document.fileType,
            signedImageUrl = signedImageUrl
        )

        // ---- Padded content below hero ----
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Spacer(modifier = Modifier.height(4.dp))

            // ---- B. Title + Category row ----
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = document.title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.width(8.dp))
                Surface(
                    shape = RoundedCornerShape(50),
                    color = getCategoryColor(document.category)
                ) {
                    Text(
                        text = document.category,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }

            // ---- C/D. View / Edit mode content ----
            if (!isEditMode) {
                ViewModeContent(document = document)
            } else {
                EditModeContent(
                    editedTitle = editedTitle,
                    onTitleChange = { editedTitle = it },
                    editedCategory = editedCategory,
                    showCategoryPicker = showCategoryPicker,
                    onShowCategoryPicker = { showCategoryPicker = it },
                    onCategoryChange = { editedCategory = it },
                    editedDoctorName = editedDoctorName,
                    onDoctorNameChange = { editedDoctorName = it },
                    editedAppointmentDate = editedAppointmentDate,
                    onShowDatePicker = { showDatePicker = true },
                    editedLocation = editedLocation,
                    onLocationChange = { editedLocation = it },
                    editedNotes = editedNotes,
                    onNotesChange = { editedNotes = it },
                    editedTagsRaw = editedTagsRaw,
                    onTagsChange = { editedTagsRaw = it }
                )

                // Save / Cancel row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = { onToggleEditMode(false) },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Cancel")
                    }
                    Button(
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            document.id?.let { id ->
                                val tags = editedTagsRaw
                                    .split(",")
                                    .map { it.trim() }
                                    .filter { it.isNotBlank() }
                                onSaveChanges(
                                    id,
                                    editedTitle,
                                    editedCategory.title,
                                    editedNotes.takeIf { it.isNotBlank() },
                                    tags,
                                    editedDoctorName.takeIf { it.isNotBlank() },
                                    editedLocation.takeIf { it.isNotBlank() },
                                    editedAppointmentDate.takeIf { it.isNotBlank() }
                                )
                            }
                        },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
                    ) {
                        Icon(
                            Icons.Default.Save,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Save", fontWeight = FontWeight.Bold)
                    }
                }
            }

            // ---- E. AI Analysis section ----
            if (isAnalyzingAI || aiAnalysisResult != null) {
                AIAnalysisSection(
                    isAnalyzingAI = isAnalyzingAI,
                    aiAnalysisResult = aiAnalysisResult,
                    onContinueInAIChat = { onContinueInAIChat(document, aiAnalysisResult ?: "") }
                )
            }

            // ---- F. Action buttons row ----
            ActionButtonsRow(
                isEditMode = isEditMode,
                onViewDocument = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); onViewDocument(document) },
                onAskAI = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); onAskAI(document) },
                onToggleEditMode = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); onToggleEditMode(!isEditMode) },
                onDelete = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); showDeleteDialog = true }
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Hero image section
// ---------------------------------------------------------------------------

@Composable
private fun HeroImageSection(
    isImageFile: Boolean,
    fileType: String,
    signedImageUrl: String?
) {
    val shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)

    if (isImageFile && signedImageUrl != null) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(signedImageUrl)
                .crossfade(true)
                .build(),
            contentDescription = "Document preview",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(shape)
        )
    } else {
        // Placeholder card — PDF or unknown type
        val icon = if (fileType.lowercase() == "pdf") {
            Icons.Default.Description
        } else {
            Icons.AutoMirrored.Filled.InsertDriveFile
        }
        val label = if (fileType.lowercase() == "pdf") "PDF Document" else fileType.uppercase()

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(shape)
                .background(AppColors.surfaceVariant),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = AppColors.onSurfaceVariant,
                    modifier = Modifier.size(64.dp)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// View mode content
// ---------------------------------------------------------------------------

@Composable
private fun ViewModeContent(document: MedicalDocument) {
    // Primary metadata
    val hasPrimaryMeta = document.doctorName != null ||
        document.appointmentDate != null ||
        document.location != null

    if (hasPrimaryMeta) {
        DetailSectionContainer(title = "Details") {
            var isFirst = true

            if (document.doctorName != null) {
                if (!isFirst) HorizontalDivider(
                    modifier = Modifier.padding(vertical = 4.dp),
                    color = AppColors.onSurface.copy(alpha = 0.08f)
                )
                DetailInfoRow(
                    icon = Icons.Default.Person,
                    label = "Doctor",
                    value = document.doctorName
                )
                isFirst = false
            }

            if (document.appointmentDate != null) {
                if (!isFirst) HorizontalDivider(
                    modifier = Modifier.padding(vertical = 4.dp),
                    color = AppColors.onSurface.copy(alpha = 0.08f)
                )
                DetailInfoRow(
                    icon = Icons.Default.Event,
                    label = "Appointment",
                    value = document.appointmentDate.substringBefore("T")
                )
                isFirst = false
            }

            if (document.location != null) {
                if (!isFirst) HorizontalDivider(
                    modifier = Modifier.padding(vertical = 4.dp),
                    color = AppColors.onSurface.copy(alpha = 0.08f)
                )
                DetailInfoRow(
                    icon = Icons.Default.LocationOn,
                    label = "Location",
                    value = document.location
                )
                isFirst = false
            }

            if (document.documentDate != null) {
                if (!isFirst) HorizontalDivider(
                    modifier = Modifier.padding(vertical = 4.dp),
                    color = AppColors.onSurface.copy(alpha = 0.08f)
                )
                DetailInfoRow(
                    icon = Icons.Default.CalendarToday,
                    label = "Document date",
                    value = document.documentDate.substringBefore("T")
                )
            }
        }
    }

    // De-emphasised file info row
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.InsertDriveFile,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = "${document.fileType.uppercase()} · ${formatFileSize(document.fileSize)}" +
                (document.createdAt?.substringBefore("T")?.let { " · $it" } ?: ""),
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )
    }

    // Notes
    if (!document.notes.isNullOrBlank()) {
        var expanded by remember { mutableStateOf(false) }
        DetailSectionContainer(title = "Notes") {
            Text(
                text = document.notes,
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurface,
                maxLines = if (expanded) Int.MAX_VALUE else 3,
                overflow = if (expanded) TextOverflow.Visible else TextOverflow.Ellipsis
            )
            if (document.notes.length > 120) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = if (expanded) "Show less" else "Show more",
                    style = MaterialTheme.typography.labelMedium,
                    color = PrimaryColor,
                    modifier = Modifier.clickable { expanded = !expanded }
                )
            }
        }
    }

    // Tags
    if (!document.tags.isNullOrEmpty()) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = "Tags",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface.copy(alpha = 0.7f)
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                document.tags.take(6).forEach { tag ->
                    Surface(
                        shape = RoundedCornerShape(50),
                        color = PrimaryColor.copy(alpha = 0.12f)
                    ) {
                        Text(
                            text = tag,
                            style = MaterialTheme.typography.labelSmall,
                            color = PrimaryColor,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Edit mode content
// ---------------------------------------------------------------------------

@Composable
private fun EditModeContent(
    editedTitle: String,
    onTitleChange: (String) -> Unit,
    editedCategory: VaultCategory,
    showCategoryPicker: Boolean,
    onShowCategoryPicker: (Boolean) -> Unit,
    onCategoryChange: (VaultCategory) -> Unit,
    editedDoctorName: String,
    onDoctorNameChange: (String) -> Unit,
    editedAppointmentDate: String,
    onShowDatePicker: () -> Unit,
    editedLocation: String,
    onLocationChange: (String) -> Unit,
    editedNotes: String,
    onNotesChange: (String) -> Unit,
    editedTagsRaw: String,
    onTagsChange: (String) -> Unit
) {
    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = PrimaryColor,
        unfocusedBorderColor = AppColors.outline.copy(alpha = 0.4f),
        focusedTextColor = AppColors.onBackground,
        unfocusedTextColor = AppColors.onBackground
    )
    val fieldShape = RoundedCornerShape(10.dp)

    // Title
    OutlinedTextField(
        value = editedTitle,
        onValueChange = onTitleChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Title") },
        shape = fieldShape,
        colors = fieldColors
    )

    // Category dropdown
    Box {
        OutlinedTextField(
            value = editedCategory.title,
            onValueChange = {},
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onShowCategoryPicker(true) },
            readOnly = true,
            label = { Text("Category") },
            trailingIcon = {
                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
            },
            shape = fieldShape,
            colors = fieldColors
        )
        DropdownMenu(
            expanded = showCategoryPicker,
            onDismissRequest = { onShowCategoryPicker(false) }
        ) {
            VaultCategory.values().forEach { cat ->
                DropdownMenuItem(
                    text = { Text(cat.title) },
                    onClick = { onCategoryChange(cat); onShowCategoryPicker(false) },
                    leadingIcon = {
                        if (editedCategory == cat) {
                            Icon(
                                Icons.Default.Check,
                                contentDescription = null,
                                tint = PrimaryColor,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                )
            }
        }
    }

    // Doctor name
    OutlinedTextField(
        value = editedDoctorName,
        onValueChange = onDoctorNameChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Doctor name") },
        leadingIcon = {
            Icon(Icons.Default.Person, contentDescription = null, modifier = Modifier.size(20.dp))
        },
        shape = fieldShape,
        colors = fieldColors
    )

    // Appointment date — opens DatePickerDialog
    OutlinedTextField(
        value = editedAppointmentDate,
        onValueChange = {},
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onShowDatePicker() },
        readOnly = true,
        label = { Text("Appointment date") },
        placeholder = { Text("YYYY-MM-DD") },
        trailingIcon = {
            IconButton(onClick = { onShowDatePicker() }) {
                Icon(Icons.Default.CalendarToday, contentDescription = "Pick date")
            }
        },
        shape = fieldShape,
        colors = fieldColors
    )

    // Location
    OutlinedTextField(
        value = editedLocation,
        onValueChange = onLocationChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Location") },
        leadingIcon = {
            Icon(Icons.Default.LocationOn, contentDescription = null, modifier = Modifier.size(20.dp))
        },
        shape = fieldShape,
        colors = fieldColors
    )

    // Notes
    OutlinedTextField(
        value = editedNotes,
        onValueChange = onNotesChange,
        modifier = Modifier.fillMaxWidth(),
        minLines = 3,
        maxLines = 6,
        label = { Text("Notes") },
        placeholder = { Text("Add notes...") },
        shape = fieldShape,
        colors = fieldColors
    )

    // Tags (comma-separated)
    OutlinedTextField(
        value = editedTagsRaw,
        onValueChange = onTagsChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Tags (comma-separated)") },
        placeholder = { Text("e.g. blood test, cardiology") },
        shape = fieldShape,
        colors = fieldColors
    )
}

// ---------------------------------------------------------------------------
// AI Analysis section
// ---------------------------------------------------------------------------

@Composable
private fun AIAnalysisSection(
    isAnalyzingAI: Boolean,
    aiAnalysisResult: String?,
    onContinueInAIChat: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = PrimaryColor,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = "AI Analysis",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = PrimaryColor
            )
        }

        if (isAnalyzingAI) {
            // Shimmer loading card
            val brush = shimmerBrush()
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(brush)
            )
        }

        if (aiAnalysisResult != null) {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                color = PrimaryColor.copy(alpha = 0.06f)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = aiAnalysisResult,
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppColors.onSurface
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Continue in AI Chat",
                        style = MaterialTheme.typography.labelMedium,
                        color = PrimaryColor,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable { onContinueInAIChat() }
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Action buttons row
// ---------------------------------------------------------------------------

@Composable
private fun ActionButtonsRow(
    isEditMode: Boolean,
    onViewDocument: () -> Unit,
    onAskAI: () -> Unit,
    onToggleEditMode: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        // View
        FilledTonalButton(
            onClick = onViewDocument,
            modifier = Modifier.weight(1f),
            shape = RoundedCornerShape(10.dp),
            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp)
        ) {
            Icon(Icons.Default.Visibility, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("View", style = MaterialTheme.typography.labelMedium)
        }

        // Ask AI
        FilledTonalButton(
            onClick = onAskAI,
            modifier = Modifier.weight(1f),
            shape = RoundedCornerShape(10.dp),
            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp),
            colors = ButtonDefaults.filledTonalButtonColors(
                containerColor = PrimaryColor.copy(alpha = 0.12f),
                contentColor = PrimaryColor
            )
        ) {
            Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("Ask AI", style = MaterialTheme.typography.labelMedium)
        }

        // Edit / Cancel Edit
        OutlinedButton(
            onClick = onToggleEditMode,
            modifier = Modifier.weight(1f),
            shape = RoundedCornerShape(10.dp),
            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp)
        ) {
            Icon(
                imageVector = if (isEditMode) Icons.Default.Close else Icons.Default.Edit,
                contentDescription = null,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = if (isEditMode) "Cancel" else "Edit",
                style = MaterialTheme.typography.labelMedium
            )
        }

        // Delete
        FilledTonalButton(
            onClick = onDelete,
            modifier = Modifier.weight(1f),
            shape = RoundedCornerShape(10.dp),
            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp),
            colors = ButtonDefaults.filledTonalButtonColors(
                containerColor = AppColors.error.copy(alpha = 0.12f),
                contentColor = AppColors.error
            )
        ) {
            Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("Delete", style = MaterialTheme.typography.labelMedium)
        }
    }
}

// ---------------------------------------------------------------------------
// Helper composables (kept from original)
// ---------------------------------------------------------------------------

@Composable
internal fun DetailSectionContainer(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass()
            .padding(16.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface.copy(alpha = 0.7f),
            modifier = Modifier.padding(bottom = 12.dp)
        )
        content()
    }
}

@Composable
internal fun DetailInfoRow(
    icon: ImageVector,
    label: String,
    value: String,
    valueColor: Color = AppColors.onSurfaceVariant,
    trailingIcon: ImageVector? = null,
    onClick: (() -> Unit)? = null
) {
    val rowModifier = if (onClick != null) {
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(vertical = 6.dp)
    } else {
        Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
    }

    Row(modifier = rowModifier, verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = PrimaryColor,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = valueColor,
            textAlign = TextAlign.End,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        if (trailingIcon != null) {
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                imageVector = trailingIcon,
                contentDescription = null,
                tint = AppColors.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

fun formatFileSize(bytes: Long): String {
    return when {
        bytes >= 1_048_576 -> "%.1f MB".format(bytes / 1_048_576.0)
        bytes >= 1024 -> "%.0f KB".format(bytes / 1024.0)
        else -> "$bytes B"
    }
}
