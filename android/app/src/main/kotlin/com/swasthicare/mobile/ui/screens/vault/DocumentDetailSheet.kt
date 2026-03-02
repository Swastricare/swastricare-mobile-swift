package com.swasthicare.mobile.ui.screens.vault

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.data.model.MedicalDocument
import com.swasthicare.mobile.data.model.VaultCategory
import com.swasthicare.mobile.ui.screens.home.glass

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
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
    var editedTags by remember(document.id) {
        mutableStateOf(document.tags ?: emptyList())
    }
    var newTagText by remember { mutableStateOf("") }
    var showDeleteDialog by remember { mutableStateOf(false) }

    val hasChanges by remember(editedTitle, editedCategory, editedNotes, editedTags) {
        derivedStateOf {
            editedTitle != document.title ||
                editedCategory.title != document.category ||
                editedNotes != (document.notes ?: "") ||
                editedTags != (document.tags ?: emptyList())
        }
    }

    // Delete confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            icon = {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error
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
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Delete", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Document Details",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = onDismiss) {
                Icon(Icons.Default.Close, contentDescription = "Close")
            }
        }

        // Document Name Section
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Document Name",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            OutlinedTextField(
                value = editedTitle,
                onValueChange = { editedTitle = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )
        }

        // Category Section
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "Category",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                VaultCategory.values().forEach { category ->
                    FilterChip(
                        selected = editedCategory == category,
                        onClick = { editedCategory = category },
                        label = { Text(category.title) },
                        leadingIcon = if (editedCategory == category) {
                            {
                                Icon(
                                    Icons.Default.Check,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        } else null,
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Color(category.colorHex).copy(alpha = 0.15f),
                            selectedLabelColor = Color(category.colorHex)
                        )
                    )
                }
            }
        }

        // File Info Section (read-only)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "File Information",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                InfoRow(
                    icon = Icons.Default.CalendarToday,
                    label = "Upload Date",
                    value = document.createdAt?.substringBefore("T") ?: "Unknown"
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                InfoRow(
                    icon = Icons.Default.Storage,
                    label = "File Size",
                    value = formatFileSize(document.fileSize)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                InfoRow(
                    icon = Icons.Default.InsertDriveFile,
                    label = "File Type",
                    value = document.fileType.uppercase()
                )
            }

            if (document.doctorName != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    InfoRow(
                        icon = Icons.Default.Person,
                        label = "Doctor",
                        value = document.doctorName
                    )
                }
            }

            if (document.location != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    InfoRow(
                        icon = Icons.Default.LocationOn,
                        label = "Location",
                        value = document.location
                    )
                }
            }
        }

        // Tags Section
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "Tags",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                editedTags.forEach { tag ->
                    InputChip(
                        selected = false,
                        onClick = { },
                        label = { Text(tag) },
                        trailingIcon = {
                            IconButton(
                                onClick = {
                                    editedTags = editedTags.filter { it != tag }
                                },
                                modifier = Modifier.size(18.dp)
                            ) {
                                Icon(
                                    Icons.Default.Close,
                                    contentDescription = "Remove tag",
                                    modifier = Modifier.size(14.dp)
                                )
                            }
                        }
                    )
                }

                // Add tag input
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = newTagText,
                        onValueChange = { newTagText = it },
                        modifier = Modifier
                            .width(140.dp)
                            .height(48.dp),
                        placeholder = { Text("Add tag...", style = MaterialTheme.typography.bodySmall) },
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodySmall,
                        shape = RoundedCornerShape(12.dp)
                    )
                    IconButton(
                        onClick = {
                            val trimmed = newTagText.trim()
                            if (trimmed.isNotEmpty() && trimmed !in editedTags) {
                                editedTags = editedTags + trimmed
                                newTagText = ""
                            }
                        },
                        enabled = newTagText.isNotBlank()
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = "Add tag",
                            tint = if (newTagText.isNotBlank())
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                        )
                    }
                }
            }
        }

        // Notes Section
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Notes",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            OutlinedTextField(
                value = editedNotes,
                onValueChange = { editedNotes = it },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
                maxLines = 6,
                placeholder = { Text("Add notes about this document...") },
                shape = RoundedCornerShape(12.dp)
            )
        }

        // Action Buttons
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // View Document
            Button(
                onClick = { onViewDocument(document) },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(
                    Icons.Default.Visibility,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("View Document", fontWeight = FontWeight.SemiBold)
            }

            // Save Changes
            AnimatedVisibility(
                visible = hasChanges,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                Button(
                    onClick = {
                        document.id?.let { id ->
                            onSaveChanges(
                                id,
                                editedTitle,
                                editedCategory.title,
                                editedNotes.takeIf { it.isNotBlank() },
                                editedTags
                            )
                        }
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF4CAF50)
                    )
                ) {
                    Icon(
                        Icons.Default.Save,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Save Changes", fontWeight = FontWeight.SemiBold)
                }
            }

            // Delete
            OutlinedButton(
                onClick = { showDeleteDialog = true },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.error
                ),
                border = ButtonDefaults.outlinedButtonBorder.copy(
                    brush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.colorScheme.error.copy(alpha = 0.5f))
                )
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Delete Document", fontWeight = FontWeight.SemiBold)
            }
        }

        // Bottom spacer for safe area
        Spacer(modifier = Modifier.height(16.dp))
    }
}

@Composable
private fun InfoRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
        )
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
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
