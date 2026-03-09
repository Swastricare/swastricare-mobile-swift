package com.swasthicare.mobile.ui.screens.vault

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
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
import com.swasthicare.mobile.data.model.DocumentMetadata
import com.swasthicare.mobile.data.model.VaultCategory
import com.swasthicare.mobile.ui.theme.AppColors
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
    
    // Date pickers logic (simplified for brevity, using text or simple dialogs in real app)
    // For "production grade", we should use DatePickerDialog
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
                        documentDate = java.time.Instant.ofEpochMilli(millis).atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                    }
                    showDatePicker = false
                }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = dateState)
        }
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
        ) {
            DatePicker(state = appointmentDateState)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Add Document Details",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(24.dp))
        
        // File Info
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
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // Form Fields
        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            label = { Text("Document Title") },
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Category Dropdown (Simplified as a Row of Chips or similar, or specific UI)
        Text("Category", style = MaterialTheme.typography.labelLarge)
        Spacer(modifier = Modifier.height(8.dp))
        
        // Simple Category Selection
        ScrollableTabRow(
            selectedTabIndex = VaultCategory.values().indexOf(selectedCategory),
            edgePadding = 0.dp,
            containerColor = Color.Transparent,
            contentColor = AppColors.primary,
            indicator = {},
            divider = {}
        ) {
            VaultCategory.values().forEach { category ->
                FilterChip(
                    selected = category == selectedCategory,
                    onClick = { selectedCategory = category },
                    label = { Text(category.title) },
                    modifier = Modifier.padding(end = 8.dp)
                )
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        OutlinedTextField(
            value = description,
            onValueChange = { description = it },
            label = { Text("Description (Optional)") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3
        )
        
        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = folderName,
            onValueChange = { folderName = it },
            label = { Text("Folder Name (Optional)") },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("e.g. Annual Checkup") }
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Date Selection
        OutlinedTextField(
            value = documentDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
            onValueChange = {},
            label = { Text("Document Date") },
            readOnly = true,
            trailingIcon = {
                IconButton(onClick = { showDatePicker = true }) {
                    Icon(Icons.Default.CalendarToday, contentDescription = "Select Date")
                }
            },
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = appointmentDate?.format(DateTimeFormatter.ISO_LOCAL_DATE) ?: "",
            onValueChange = {},
            label = { Text("Appointment Date (Optional)") },
            readOnly = true,
            placeholder = { Text("Set reminder for follow-up") },
            trailingIcon = {
                Row {
                    if (appointmentDate != null) {
                        IconButton(onClick = { appointmentDate = null }) {
                            Icon(Icons.Default.Close, contentDescription = "Clear", modifier = Modifier.size(20.dp))
                        }
                    }
                    IconButton(onClick = { showAppointmentDatePicker = true }) {
                        Icon(Icons.Default.Notifications, contentDescription = "Set Appointment")
                    }
                }
            },
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(16.dp))

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            OutlinedTextField(
                value = doctorName,
                onValueChange = { doctorName = it },
                label = { Text("Doctor Name") },
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = location,
                onValueChange = { location = it },
                label = { Text("Location") },
                modifier = Modifier.weight(1f)
            )
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        OutlinedTextField(
            value = tags,
            onValueChange = { tags = it },
            label = { Text("Tags (comma separated)") },
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        Button(
            onClick = {
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
                onUpload(title, selectedCategory, metadata)
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Upload Document")
        }
        
        Spacer(modifier = Modifier.height(24.dp))
    }
}
