package com.swasthicare.mobile.ui.screens.vault

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.data.model.MedicalDocument
import com.swasthicare.mobile.data.model.VaultCategory
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.AppColors
import com.swasthicare.mobile.ui.theme.PrimaryColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentDetailSheet(
    document: MedicalDocument,
    onDismiss: () -> Unit,
    onViewDocument: (MedicalDocument) -> Unit,
    onSaveChanges: (
        documentId: String,
        title: String,
        category: String,
        notes: String?,
        tags: List<String>
    ) -> Unit,
    onDeleteDocument: (MedicalDocument) -> Unit
) {
    var editedTitle by remember(document.id) { mutableStateOf(document.title) }
    var editedCategory by remember(document.id) {
        mutableStateOf(VaultCategory.fromValue(document.category))
    }
    var editedNotes by remember(document.id) { mutableStateOf(document.notes ?: "") }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showCategoryPicker by remember { mutableStateOf(false) }

    val hasChanges by remember(editedTitle, editedCategory, editedNotes) {
        derivedStateOf {
            editedTitle != document.title ||
                editedCategory.title != document.category ||
                editedNotes != (document.notes ?: "")
        }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            icon = { Icon(Icons.Default.Warning, contentDescription = null, tint = AppColors.error) },
            title = { Text("Delete Document") },
            text = { Text("Are you sure you want to delete \"${document.title}\"? This action cannot be undone.") },
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

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 32.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Document Details",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = onDismiss) {
                Icon(Icons.Default.Close, contentDescription = "Close")
            }
        }

        // Document section: editable name + category + file info
        DetailSectionContainer(title = "Document") {
            OutlinedTextField(
                value = editedTitle,
                onValueChange = { editedTitle = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Name") },
                shape = RoundedCornerShape(10.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = PrimaryColor,
                    unfocusedBorderColor = AppColors.outline.copy(alpha = 0.4f)
                )
            )

            HorizontalDivider(
                modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                color = AppColors.onSurface.copy(alpha = 0.08f)
            )

            Box {
                DetailInfoRow(
                    icon = Icons.Default.Label,
                    label = "Category",
                    value = editedCategory.title,
                    valueColor = Color(editedCategory.colorHex),
                    trailingIcon = Icons.Default.ChevronRight,
                    onClick = { showCategoryPicker = true }
                )
                DropdownMenu(
                    expanded = showCategoryPicker,
                    onDismissRequest = { showCategoryPicker = false }
                ) {
                    VaultCategory.values().forEach { cat ->
                        DropdownMenuItem(
                            text = { Text(cat.title) },
                            onClick = { editedCategory = cat; showCategoryPicker = false },
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

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 4.dp),
                color = AppColors.onSurface.copy(alpha = 0.08f)
            )

            DetailInfoRow(
                icon = Icons.Default.CalendarToday,
                label = "Date",
                value = document.createdAt?.substringBefore("T") ?: "Unknown"
            )

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 4.dp),
                color = AppColors.onSurface.copy(alpha = 0.08f)
            )

            DetailInfoRow(
                icon = Icons.Default.Storage,
                label = "Size",
                value = formatFileSize(document.fileSize)
            )

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 4.dp),
                color = AppColors.onSurface.copy(alpha = 0.08f)
            )

            DetailInfoRow(
                icon = Icons.AutoMirrored.Filled.InsertDriveFile,
                label = "Type",
                value = document.fileType.uppercase()
            )

            if (document.doctorName != null) {
                HorizontalDivider(
                    modifier = Modifier.padding(vertical = 4.dp),
                    color = AppColors.onSurface.copy(alpha = 0.08f)
                )
                DetailInfoRow(
                    icon = Icons.Default.Person,
                    label = "Doctor",
                    value = document.doctorName
                )
            }
        }

        // Notes section
        DetailSectionContainer(title = "Notes") {
            OutlinedTextField(
                value = editedNotes,
                onValueChange = { editedNotes = it },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
                maxLines = 5,
                placeholder = {
                    Text(
                        "Add notes...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppColors.onSurfaceVariant
                    )
                },
                shape = RoundedCornerShape(10.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = PrimaryColor,
                    unfocusedBorderColor = AppColors.outline.copy(alpha = 0.4f)
                )
            )
        }

        Spacer(modifier = Modifier.height(4.dp))

        // View Document action
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .glass()
                .clip(RoundedCornerShape(16.dp))
                .clickable { onViewDocument(document) }
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.Visibility, contentDescription = null, tint = PrimaryColor, modifier = Modifier.size(20.dp))
                Text(
                    "View Document",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = PrimaryColor
                )
            }
        }

        // Save Changes action (animated — only appears when edits exist)
        AnimatedVisibility(visible = hasChanges, enter = expandVertically(), exit = shrinkVertically()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .glass()
                    .clip(RoundedCornerShape(16.dp))
                    .clickable {
                        document.id?.let { id ->
                            onSaveChanges(
                                id,
                                editedTitle,
                                editedCategory.title,
                                editedNotes.takeIf { it.isNotBlank() },
                                document.tags ?: emptyList()
                            )
                        }
                        onDismiss()
                    }
                    .padding(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(Icons.Default.Save, contentDescription = null, tint = Color(0xFF34C759), modifier = Modifier.size(20.dp))
                    Text(
                        "Save Changes",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF34C759)
                    )
                }
            }
        }

        // Delete action
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .glass()
                .clip(RoundedCornerShape(16.dp))
                .clickable { showDeleteDialog = true }
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.Delete, contentDescription = null, tint = AppColors.error, modifier = Modifier.size(20.dp))
                Text(
                    "Delete Document",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.error
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

@Composable
private fun DetailSectionContainer(
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
private fun DetailInfoRow(
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
        Icon(imageVector = icon, contentDescription = null, tint = PrimaryColor, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(12.dp))
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
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

fun formatFileSize(bytes: Long): String {
    return when {
        bytes >= 1_048_576 -> "%.1f MB".format(bytes / 1_048_576.0)
        bytes >= 1024 -> "%.0f KB".format(bytes / 1024.0)
        else -> "$bytes B"
    }
}
