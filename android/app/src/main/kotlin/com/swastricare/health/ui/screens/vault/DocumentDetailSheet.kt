package com.swastricare.health.ui.screens.vault

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.automirrored.filled.Notes
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
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.data.model.MedicalDocument
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.ui.theme.AppColors

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
                .padding(horizontal = 20.dp)
                .padding(top = 4.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // ---- B. Title + Category chip ----
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = document.title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(AppColors.surfaceVariant)
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = document.category,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurfaceVariant
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
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    FlatButton(
                        text = "Cancel",
                        onClick = { onToggleEditMode(false) },
                        modifier = Modifier.weight(1f),
                        filled = false
                    )
                    FlatButton(
                        text = "Save",
                        leadingIcon = Icons.Default.Save,
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
                        filled = true
                    )
                }
            }

            // ---- E. AI Analysis section ----
            if (isAnalyzingAI || aiAnalysisResult != null) {
                AIAnalysisSection(
                    isAnalyzingAI = isAnalyzingAI,
                    aiAnalysisResult = aiAnalysisResult,
                    onContinueInAIChat = {
                        onContinueInAIChat(document, aiAnalysisResult ?: "")
                    }
                )
            }

            // ---- F. Action buttons row ----
            if (!isEditMode) {
                ActionButtonsRow(
                    onViewDocument = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        onViewDocument(document)
                    },
                    onAskAI = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        onAskAI(document)
                    },
                    onToggleEditMode = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        onToggleEditMode(true)
                    },
                    onDelete = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        showDeleteDialog = true
                    }
                )
            }
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
    val shape = RoundedCornerShape(20.dp)

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
                .padding(horizontal = 20.dp, vertical = 16.dp)
                .height(220.dp)
                .clip(shape)
        )
    } else {
        val icon = if (fileType.lowercase() == "pdf") {
            Icons.Default.Description
        } else {
            Icons.AutoMirrored.Filled.InsertDriveFile
        }
        val label = if (fileType.lowercase() == "pdf") "PDF Document" else fileType.uppercase()

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp)
                .height(220.dp)
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
    val hasPrimaryMeta = document.doctorName != null ||
        document.appointmentDate != null ||
        document.location != null ||
        document.documentDate != null

    if (hasPrimaryMeta) {
        SectionHeader("Details")
        Spacer(Modifier.height(4.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(AppColors.surfaceVariant)
                .padding(horizontal = 14.dp, vertical = 6.dp)
        ) {
            if (document.doctorName != null) {
                DetailInfoRow(
                    icon = Icons.Default.Person,
                    label = "Doctor",
                    value = document.doctorName
                )
            }
            if (document.appointmentDate != null) {
                DetailInfoRow(
                    icon = Icons.Default.Event,
                    label = "Appointment",
                    value = document.appointmentDate.substringBefore("T")
                )
            }
            if (document.location != null) {
                DetailInfoRow(
                    icon = Icons.Default.LocationOn,
                    label = "Location",
                    value = document.location
                )
            }
            if (document.documentDate != null) {
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
        SectionHeader("Notes")
        Spacer(Modifier.height(4.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(AppColors.surfaceVariant)
                .padding(14.dp)
        ) {
            Text(
                text = document.notes,
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurface,
                maxLines = if (expanded) Int.MAX_VALUE else 3,
                overflow = if (expanded) TextOverflow.Visible else TextOverflow.Ellipsis
            )
            if (document.notes.length > 120) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = if (expanded) "Show less" else "Show more",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface,
                    modifier = Modifier.clickable { expanded = !expanded }
                )
            }
        }
    }

    // Tags
    if (!document.tags.isNullOrEmpty()) {
        SectionHeader("Tags")
        Spacer(Modifier.height(4.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            document.tags.forEach { tag ->
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(AppColors.surfaceVariant)
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = tag,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurfaceVariant
                    )
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
    // Title
    FlatTextField(
        value = editedTitle,
        onValueChange = onTitleChange,
        label = "Title",
        leadingIcon = Icons.Default.Title
    )

    // Category (flat chips)
    Text(
        text = "Category",
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp)
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        VaultCategory.entries.forEach { category ->
            val selected = category == editedCategory
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(
                        if (selected) AppColors.primary
                        else AppColors.surfaceVariant
                    )
                    .clickable { onCategoryChange(category) }
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            ) {
                Text(
                    text = category.title,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = if (selected) Color.White else AppColors.onSurfaceVariant
                )
            }
        }
    }

    // Doctor name
    FlatTextField(
        value = editedDoctorName,
        onValueChange = onDoctorNameChange,
        label = "Doctor name",
        leadingIcon = Icons.Default.Person
    )

    // Appointment date — opens DatePickerDialog
    FlatTextField(
        value = editedAppointmentDate,
        onValueChange = {},
        label = "Appointment date",
        leadingIcon = Icons.Default.Event,
        placeholder = "YYYY-MM-DD",
        readOnly = true,
        trailingIcon = {
            IconButton(onClick = onShowDatePicker) {
                Icon(
                    Icons.Default.CalendarToday,
                    contentDescription = "Pick date",
                    tint = AppColors.onSurface
                )
            }
        }
    )

    // Location
    FlatTextField(
        value = editedLocation,
        onValueChange = onLocationChange,
        label = "Location",
        leadingIcon = Icons.Default.LocationOn
    )

    // Notes
    FlatTextField(
        value = editedNotes,
        onValueChange = onNotesChange,
        label = "Notes",
        leadingIcon = Icons.AutoMirrored.Filled.Notes,
        placeholder = "Add notes...",
        singleLine = false,
        minLines = 3
    )

    // Tags
    FlatTextField(
        value = editedTagsRaw,
        onValueChange = onTagsChange,
        label = "Tags (comma-separated)",
        leadingIcon = Icons.Default.LocalOffer,
        placeholder = "e.g. blood test, cardiology"
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
        SectionHeader("AI Analysis")

        if (isAnalyzingAI) {
            val brush = shimmerBrush()
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(brush)
            )
        }

        if (aiAnalysisResult != null) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(AppColors.surfaceVariant)
                    .padding(14.dp)
            ) {
                Text(
                    text = aiAnalysisResult,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .clickable(onClick = onContinueInAIChat)
                        .padding(vertical = 6.dp, horizontal = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = null,
                        tint = AppColors.primary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Continue in AI Chat",
                        style = MaterialTheme.typography.labelLarge,
                        color = AppColors.primary,
                        fontWeight = FontWeight.SemiBold
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
    onViewDocument: () -> Unit,
    onAskAI: () -> Unit,
    onToggleEditMode: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        FlatIconButton(
            icon = Icons.Default.Visibility,
            label = "View",
            onClick = onViewDocument,
            modifier = Modifier.weight(1f)
        )
        FlatIconButton(
            icon = Icons.Default.AutoAwesome,
            label = "Ask AI",
            onClick = onAskAI,
            modifier = Modifier.weight(1f)
        )
        FlatIconButton(
            icon = Icons.Default.Edit,
            label = "Edit",
            onClick = onToggleEditMode,
            modifier = Modifier.weight(1f)
        )
        FlatIconButton(
            icon = Icons.Default.Delete,
            label = "Delete",
            onClick = onDelete,
            modifier = Modifier.weight(1f),
            destructive = true
        )
    }
}

// ---------------------------------------------------------------------------
// Flat building blocks
// ---------------------------------------------------------------------------

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        letterSpacing = 0.8.sp,
        color = AppColors.onSurfaceVariant
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FlatTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    leadingIcon: ImageVector,
    placeholder: String? = null,
    readOnly: Boolean = false,
    singleLine: Boolean = true,
    minLines: Int = 1,
    trailingIcon: (@Composable () -> Unit)? = null
) {
    TextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        leadingIcon = {
            Icon(leadingIcon, contentDescription = null, tint = AppColors.onSurfaceVariant)
        },
        trailingIcon = trailingIcon,
        placeholder = placeholder?.let { { Text(it) } },
        readOnly = readOnly,
        singleLine = singleLine,
        minLines = minLines,
        shape = RoundedCornerShape(14.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = AppColors.surfaceVariant,
            unfocusedContainerColor = AppColors.surfaceVariant,
            disabledContainerColor = AppColors.surfaceVariant,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
            errorIndicatorColor = Color.Transparent
        ),
        modifier = Modifier.fillMaxWidth()
    )
}

@Composable
private fun FlatButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leadingIcon: ImageVector? = null,
    filled: Boolean = true
) {
    Box(
        modifier = modifier
            .height(52.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(if (filled) AppColors.primary else AppColors.surfaceVariant)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (leadingIcon != null) {
                Icon(
                    imageVector = leadingIcon,
                    contentDescription = null,
                    tint = if (filled) Color.White else AppColors.onSurface,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
            }
            Text(
                text = text,
                color = if (filled) Color.White else AppColors.onSurface,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp
            )
        }
    }
}

@Composable
private fun FlatIconButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    destructive: Boolean = false
) {
    val contentColor = if (destructive) AppColors.error else AppColors.onSurface
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.surfaceVariant)
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = contentColor,
            modifier = Modifier.size(20.dp)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = contentColor
        )
    }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

@Composable
internal fun DetailSectionContainer(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.surfaceVariant)
            .padding(16.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurfaceVariant,
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
    valueColor: Color = AppColors.onSurface,
    trailingIcon: ImageVector? = null,
    onClick: (() -> Unit)? = null
) {
    val rowModifier = if (onClick != null) {
        Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 12.dp)
    } else {
        Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
    }

    Row(modifier = rowModifier, verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
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
