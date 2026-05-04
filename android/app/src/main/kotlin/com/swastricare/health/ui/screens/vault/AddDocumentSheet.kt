package com.swastricare.health.ui.screens.vault

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
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
    onDismiss: () -> Unit,
    isUploading: Boolean = false
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

    val teal = com.swastricare.health.ui.screens.auth.components.PremiumColors.Teal
    val darkText = Color(0xFF0F172A)
    val mutedText = Color(0xFF6B7280)
    val borderSoft = Color.Black.copy(alpha = 0.07f)

    var categoryMenuExpanded by remember { mutableStateOf(false) }
    var notes by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = 24.dp)
    ) {
        // ── Header (icon badge + title) ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(teal.copy(alpha = 0.15f), RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Description,
                    contentDescription = null,
                    tint = teal,
                    modifier = Modifier.size(18.dp)
                )
            }
            Spacer(Modifier.width(12.dp))
            Column {
                Text(
                    "Add File",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = darkText
                )
                Text(
                    "Store your health document securely",
                    fontSize = 12.sp,
                    color = mutedText
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // ── Document Name ──
        FieldLabel(text = "Document Name", required = true)
        Spacer(Modifier.height(6.dp))
        ModernTextField(
            value = title,
            onValueChange = { title = it },
            placeholder = "Enter document name",
            leadingIcon = Icons.Default.Description,
            border = borderSoft
        )
        Spacer(Modifier.height(6.dp))
        Text(
            "E.g., Blood Test Report, X-Ray, Prescription",
            fontSize = 11.sp,
            color = mutedText,
            modifier = Modifier.padding(start = 4.dp)
        )

        Spacer(Modifier.height(16.dp))

        // ── Category ──
        FieldLabel(text = "Category", required = true)
        Spacer(Modifier.height(6.dp))
        Box {
            ModernTextField(
                value = selectedCategory.title,
                onValueChange = { },
                placeholder = "Select category",
                leadingIcon = Icons.Default.Folder,
                trailingIcon = {
                    Icon(
                        Icons.Default.ExpandMore,
                        contentDescription = null,
                        tint = mutedText,
                        modifier = Modifier.size(20.dp)
                    )
                },
                readOnly = true,
                border = borderSoft,
                onClick = { categoryMenuExpanded = true }
            )
            DropdownMenu(
                expanded = categoryMenuExpanded,
                onDismissRequest = { categoryMenuExpanded = false }
            ) {
                VaultCategory.entries.forEach { category ->
                    DropdownMenuItem(
                        text = { Text(category.title) },
                        onClick = {
                            selectedCategory = category
                            categoryMenuExpanded = false
                        }
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // ── Date row ──
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                FieldLabel(text = "Date of Document", required = true)
                Spacer(Modifier.height(6.dp))
                ModernTextField(
                    value = documentDate.format(DateTimeFormatter.ofPattern("dd MMM yyyy")),
                    onValueChange = {},
                    placeholder = "Select date",
                    leadingIcon = null,
                    trailingIcon = {
                        Icon(Icons.Default.CalendarToday, null, tint = mutedText, modifier = Modifier.size(18.dp))
                    },
                    readOnly = true,
                    border = borderSoft,
                    onClick = { showDatePicker = true }
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                FieldLabel(text = "Appointment Date", optional = true)
                Spacer(Modifier.height(6.dp))
                ModernTextField(
                    value = appointmentDate?.format(DateTimeFormatter.ofPattern("dd MMM yyyy")) ?: "",
                    onValueChange = {},
                    placeholder = "Select date",
                    leadingIcon = null,
                    trailingIcon = {
                        Icon(Icons.Default.CalendarToday, null, tint = mutedText, modifier = Modifier.size(18.dp))
                    },
                    readOnly = true,
                    border = borderSoft,
                    onClick = { showAppointmentDatePicker = true }
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        // ── Doctor ──
        FieldLabel(text = "Doctor Name")
        Spacer(Modifier.height(6.dp))
        ModernTextField(
            value = doctorName,
            onValueChange = { doctorName = it },
            placeholder = "Enter doctor name",
            leadingIcon = Icons.Default.Person,
            border = borderSoft
        )

        Spacer(Modifier.height(16.dp))

        // ── Hospital / Clinic ──
        FieldLabel(text = "Hospital / Clinic")
        Spacer(Modifier.height(6.dp))
        ModernTextField(
            value = location,
            onValueChange = { location = it },
            placeholder = "Enter hospital or clinic name",
            leadingIcon = Icons.Default.LocalHospital,
            border = borderSoft
        )

        Spacer(Modifier.height(16.dp))

        // ── Additional info ──
        FieldLabel(text = "Additional Information", optional = true)
        Spacer(Modifier.height(6.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White, RoundedCornerShape(12.dp))
                .border(1.dp, borderSoft, RoundedCornerShape(12.dp))
                .padding(12.dp)
        ) {
            BasicInfoArea(
                value = notes,
                onValueChange = { if (it.length <= 500) notes = it },
                placeholder = "Add any additional notes or information..."
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "${notes.length}/500",
                fontSize = 11.sp,
                color = mutedText,
                modifier = Modifier.align(Alignment.End)
            )
        }

        Spacer(Modifier.height(16.dp))

        // ── Upload Document area (shows picked file) ──
        FieldLabel(text = "Upload Document", required = true)
        Spacer(Modifier.height(6.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(teal.copy(alpha = 0.05f), RoundedCornerShape(14.dp))
                .border(
                    1.dp,
                    teal.copy(alpha = 0.4f),
                    RoundedCornerShape(14.dp)
                )
                .padding(vertical = 18.dp, horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                Icons.Default.CloudUpload,
                contentDescription = null,
                tint = teal,
                modifier = Modifier.size(28.dp)
            )
            Spacer(Modifier.height(6.dp))
            if (fileName.isNotBlank()) {
                Text(
                    fileName,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = darkText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    formatFileSize(fileSize),
                    fontSize = 11.sp,
                    color = mutedText
                )
            } else {
                Text(
                    "Tap to upload or drag and drop",
                    fontSize = 12.sp,
                    color = darkText
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    "PDF, JPG, PNG (Max 20MB)",
                    fontSize = 11.sp,
                    color = mutedText
                )
            }
        }

        Spacer(Modifier.height(22.dp))

        // ── Save Document button ──
        val titleTrimmed = title.trim()
        val canUpload = titleTrimmed.isNotEmpty() && !isUploading
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(
                    if (canUpload) teal else teal.copy(alpha = 0.45f),
                    RoundedCornerShape(14.dp)
                )
                .clickable(enabled = canUpload) {
                    val metadata = DocumentMetadata(
                        name = titleTrimmed,
                        description = notes.takeIf { it.isNotBlank() }
                            ?: description.takeIf { it.isNotBlank() },
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
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (isUploading) {
                    CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        "Saving…",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp
                    )
                } else {
                    Icon(
                        Icons.Default.Save,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "Save Document",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp
                    )
                }
            }
        }

        Spacer(Modifier.height(10.dp))

        // ── Cancel ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
                .clip(RoundedCornerShape(14.dp))
                .border(1.dp, borderSoft, RoundedCornerShape(14.dp))
                .clickable(enabled = !isUploading) { onDismiss() }
                .alpha(if (isUploading) 0.5f else 1f),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "Cancel",
                color = darkText,
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp
            )
        }
    }
}

@Composable
private fun FieldLabel(
    text: String,
    required: Boolean = false,
    optional: Boolean = false
) {
    Row {
        Text(
            text,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF0F172A)
        )
        if (required) {
            Spacer(Modifier.width(2.dp))
            Text("*", color = Color(0xFFEF4444), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
        if (optional) {
            Spacer(Modifier.width(4.dp))
            Text(
                "(Optional)",
                fontSize = 11.sp,
                color = com.swastricare.health.ui.screens.auth.components.PremiumColors.Teal,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(top = 1.dp)
            )
        }
    }
}

@Composable
private fun ModernTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    leadingIcon: ImageVector? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    readOnly: Boolean = false,
    border: Color = Color.Black.copy(alpha = 0.07f),
    onClick: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White, RoundedCornerShape(12.dp))
            .border(1.dp, border, RoundedCornerShape(12.dp))
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (leadingIcon != null) {
            Icon(
                leadingIcon,
                contentDescription = null,
                tint = Color(0xFF6B7280),
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(10.dp))
        }
        Box(modifier = Modifier.weight(1f).padding(vertical = 14.dp)) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                readOnly = readOnly,
                singleLine = true,
                textStyle = androidx.compose.ui.text.TextStyle(
                    color = Color(0xFF0F172A),
                    fontSize = 14.sp
                ),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(
                    com.swastricare.health.ui.screens.auth.components.PremiumColors.Teal
                ),
                modifier = Modifier.fillMaxWidth()
            )
            if (value.isEmpty()) {
                Text(
                    placeholder,
                    fontSize = 14.sp,
                    color = Color(0xFF9CA3AF)
                )
            }
        }
        if (trailingIcon != null) {
            Spacer(Modifier.width(8.dp))
            trailingIcon()
        }
    }
}

@Composable
private fun BasicInfoArea(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String
) {
    Box(modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp)) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = Color(0xFF0F172A),
                fontSize = 14.sp
            ),
            cursorBrush = androidx.compose.ui.graphics.SolidColor(
                com.swastricare.health.ui.screens.auth.components.PremiumColors.Teal
            ),
            modifier = Modifier.fillMaxWidth()
        )
        if (value.isEmpty()) {
            Text(
                placeholder,
                fontSize = 14.sp,
                color = Color(0xFF9CA3AF)
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
