package com.swastricare.health.ui.screens.vault

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.model.DocumentMetadata
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddDocumentSheet(
    fileName: String,
    fileSize: Long,
    onUpload: (String, VaultCategory, DocumentMetadata) -> Unit,
    onDismiss: () -> Unit
) {
    var title by remember { mutableStateOf(fileName.substringBeforeLast('.')) }
    var selectedCategory by remember { mutableStateOf(VaultCategory.LAB_REPORTS) }
    var description by remember { mutableStateOf("") }
    var doctorName by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var tags by remember { mutableStateOf("") }
    var folderName by remember { mutableStateOf("") }

    var documentDate by remember { mutableStateOf(LocalDate.now()) }
    var showDatePicker by remember { mutableStateOf(false) }

    var appointmentDate by remember { mutableStateOf<LocalDate?>(null) }
    var showAppointmentDatePicker by remember { mutableStateOf(false) }

    val dateState = rememberDatePickerState()
    val appointmentDateState = rememberDatePickerState()

    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    dateState.selectedDateMillis?.let { millis ->
                        documentDate = java.time.Instant.ofEpochMilli(millis)
                            .atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                    }
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            }
        ) { DatePicker(state = dateState) }
    }

    if (showAppointmentDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showAppointmentDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    appointmentDateState.selectedDateMillis?.let { millis ->
                        appointmentDate = java.time.Instant.ofEpochMilli(millis)
                            .atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                    }
                    showAppointmentDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showAppointmentDatePicker = false }) { Text("Cancel") }
            }
        ) { DatePicker(state = appointmentDateState) }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 4.dp, bottom = 28.dp)
    ) {
        // ---- Header ----
        Text(
            text = "Add Document",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = "Save to your medical vault",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )

        Spacer(Modifier.height(20.dp))

        // ---- File info ----
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(AppColors.surfaceVariant)
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = getFileIcon(fileName.substringAfterLast('.', "")),
                contentDescription = null,
                tint = AppColors.onSurface,
                modifier = Modifier.size(24.dp)
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    text = fileName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = AppColors.onSurface
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = formatFileSize(fileSize),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        Spacer(Modifier.height(24.dp))

        // ---- Section: Document info ----
        SectionHeader("Document Info")
        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = title,
            onValueChange = { title = it },
            label = "Document Title",
            leadingIcon = Icons.Default.Title
        )

        Spacer(Modifier.height(16.dp))

        Text(
            text = "Category",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurfaceVariant,
            modifier = Modifier.padding(start = 4.dp)
        )
        Spacer(Modifier.height(8.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            VaultCategory.entries.forEach { category ->
                CategoryChip(
                    category = category,
                    selected = category == selectedCategory,
                    onClick = { selectedCategory = category }
                )
            }
        }

        Spacer(Modifier.height(24.dp))

        // ---- Section: Dates ----
        SectionHeader("Dates")
        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = documentDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
            onValueChange = {},
            label = "Document Date",
            leadingIcon = Icons.Default.Event,
            readOnly = true,
            trailingIcon = {
                IconButton(onClick = { showDatePicker = true }) {
                    Icon(
                        Icons.Default.CalendarToday,
                        contentDescription = "Select Date",
                        tint = AppColors.onSurface
                    )
                }
            }
        )

        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = appointmentDate?.format(DateTimeFormatter.ISO_LOCAL_DATE) ?: "",
            onValueChange = {},
            label = "Appointment Date (Optional)",
            leadingIcon = Icons.Default.NotificationsActive,
            placeholder = "Set reminder for follow-up",
            readOnly = true,
            trailingIcon = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (appointmentDate != null) {
                        IconButton(onClick = { appointmentDate = null }) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = "Clear",
                                tint = AppColors.onSurfaceVariant,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                    IconButton(onClick = { showAppointmentDatePicker = true }) {
                        Icon(
                            Icons.Default.CalendarToday,
                            contentDescription = "Set Appointment",
                            tint = AppColors.onSurface
                        )
                    }
                }
            }
        )

        Spacer(Modifier.height(24.dp))

        // ---- Section: Doctor & Location ----
        SectionHeader("Doctor & Location")
        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = doctorName,
            onValueChange = { doctorName = it },
            label = "Doctor Name",
            leadingIcon = Icons.Default.Person
        )

        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = location,
            onValueChange = { location = it },
            label = "Location",
            leadingIcon = Icons.Default.LocationOn
        )

        Spacer(Modifier.height(24.dp))

        // ---- Section: Additional ----
        SectionHeader("Additional Details")
        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = description,
            onValueChange = { description = it },
            label = "Description (Optional)",
            leadingIcon = Icons.AutoMirrored.Filled.Notes,
            singleLine = false,
            minLines = 3
        )

        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = folderName,
            onValueChange = { folderName = it },
            label = "Folder Name (Optional)",
            leadingIcon = Icons.Default.Folder,
            placeholder = "e.g. Annual Checkup"
        )

        Spacer(Modifier.height(12.dp))

        FlatTextField(
            value = tags,
            onValueChange = { tags = it },
            label = "Tags (comma separated)",
            leadingIcon = Icons.Default.LocalOffer,
            placeholder = "e.g. diabetes, followup"
        )

        Spacer(Modifier.height(28.dp))

        // ---- Upload CTA ----
        val titleTrimmed = title.trim()
        val canUpload = titleTrimmed.isNotEmpty()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(
                    if (canUpload) AppColors.primary
                    else AppColors.surfaceVariant
                )
                .clickable(enabled = canUpload) {
                    val metadata = DocumentMetadata(
                        name = titleTrimmed,
                        description = description.takeIf { it.isNotBlank() },
                        folderName = folderName.takeIf { it.isNotBlank() },
                        documentDate = documentDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
                        appointmentDate = appointmentDate?.format(DateTimeFormatter.ISO_LOCAL_DATE),
                        doctorName = doctorName.takeIf { it.isNotBlank() },
                        location = location.takeIf { it.isNotBlank() },
                        tags = tags.split(",").map { it.trim() }.filter { it.isNotBlank() }
                    )
                    onUpload(titleTrimmed, selectedCategory, metadata)
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Upload Document",
                color = if (canUpload) Color.White else AppColors.onSurfaceVariant,
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp
            )
        }
    }
}

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
private fun CategoryChip(
    category: VaultCategory,
    selected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(
                if (selected) AppColors.primary
                else AppColors.surfaceVariant
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = category.title,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) Color.White else AppColors.onSurfaceVariant
        )
    }
}
