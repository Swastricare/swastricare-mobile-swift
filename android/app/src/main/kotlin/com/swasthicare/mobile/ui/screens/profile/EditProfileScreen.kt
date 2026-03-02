package com.swasthicare.mobile.ui.screens.profile

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swasthicare.mobile.data.model.Gender
import com.swasthicare.mobile.ui.theme.PrimaryColor
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileScreen(
    viewModel: ProfileViewModel,
    onNavigateBack: () -> Unit
) {
    val editState by viewModel.editState.collectAsState()
    val isSaving by viewModel.isSaving.collectAsState()
    val saveError by viewModel.saveError.collectAsState()

    // Photo picker launchers
    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { viewModel.onAvatarSelected(it) }
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        bitmap?.let { viewModel.onAvatarCaptured(it) }
    }

    var showPhotoOptions by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }

    // Date picker state
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = editState.dateOfBirthMillis
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                        val dateStr = sdf.format(millis)
                        viewModel.updateEditField { copy(dateOfBirth = dateStr, dateOfBirthMillis = millis) }
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

    // Photo options bottom sheet
    if (showPhotoOptions) {
        AlertDialog(
            onDismissRequest = { showPhotoOptions = false },
            title = { Text("Change Photo") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = {
                        showPhotoOptions = false
                        cameraLauncher.launch(null)
                    }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.CameraAlt, contentDescription = null)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text("Take Photo")
                        }
                    }
                    TextButton(onClick = {
                        showPhotoOptions = false
                        galleryLauncher.launch("image/*")
                    }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.PhotoLibrary, contentDescription = null)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text("Choose from Gallery")
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showPhotoOptions = false }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Edit Profile") },
                navigationIcon = {
                    IconButton(onClick = {
                        viewModel.cancelEdit()
                        onNavigateBack()
                    }) {
                        Icon(Icons.Default.Close, contentDescription = "Cancel")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            viewModel.saveProfile {
                                onNavigateBack()
                            }
                        },
                        enabled = !isSaving && editState.isValid
                    ) {
                        if (isSaving) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            Text("Save", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Error
            if (saveError != null) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Error,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onErrorContainer
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                saveError ?: "",
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                }
            }

            // Avatar Section
            item {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(contentAlignment = Alignment.BottomEnd) {
                        if (editState.avatarUrl != null || editState.selectedAvatarUri != null) {
                            AsyncImage(
                                model = ImageRequest.Builder(LocalContext.current)
                                    .data(editState.selectedAvatarUri ?: editState.avatarUrl)
                                    .crossfade(true)
                                    .build(),
                                contentDescription = "Profile Photo",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(120.dp)
                                    .clip(CircleShape)
                            )
                        } else {
                            // Initials avatar
                            Box(
                                modifier = Modifier
                                    .size(120.dp)
                                    .clip(CircleShape)
                                    .background(
                                        brush = Brush.linearGradient(
                                            colors = listOf(Color(0xFF2E3192), Color(0xFF4A90E2))
                                        )
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = editState.fullName.take(1).uppercase(),
                                    style = MaterialTheme.typography.displayMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                            }
                        }

                        // Camera badge
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(PrimaryColor)
                                .clickable { showPhotoOptions = true },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.CameraAlt,
                                contentDescription = "Change Photo",
                                tint = Color.White,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    TextButton(onClick = { showPhotoOptions = true }) {
                        Text("Change Photo")
                    }
                }
            }

            // Personal Info Section
            item {
                EditSectionHeader(title = "Personal Info")
            }

            item {
                OutlinedTextField(
                    value = editState.fullName,
                    onValueChange = { viewModel.updateEditField { copy(fullName = it) } },
                    label = { Text("Full Name *") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    isError = editState.fullName.isBlank(),
                    supportingText = if (editState.fullName.isBlank()) {
                        { Text("Name is required") }
                    } else null
                )
            }

            item {
                OutlinedTextField(
                    value = editState.phoneNumber,
                    onValueChange = { viewModel.updateEditField { copy(phoneNumber = it) } },
                    label = { Text("Phone Number") },
                    prefix = { Text("+91 ") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    isError = editState.phoneNumber.isNotEmpty() && !editState.isPhoneValid,
                    supportingText = if (editState.phoneNumber.isNotEmpty() && !editState.isPhoneValid) {
                        { Text("Enter a valid 10-digit phone number") }
                    } else null
                )
            }

            item {
                OutlinedTextField(
                    value = editState.bio,
                    onValueChange = { viewModel.updateEditField { copy(bio = it) } },
                    label = { Text("Bio (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 4
                )
            }

            // Health Info Section
            item {
                EditSectionHeader(title = "Health Info")
            }

            // Gender
            item {
                Text(
                    "Gender",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    val genders = Gender.entries
                    items(genders.size) { index ->
                        val gender = genders[index]
                        FilterChip(
                            selected = editState.gender == gender,
                            onClick = { viewModel.updateEditField { copy(gender = gender) } },
                            label = { Text(gender.displayName) }
                        )
                    }
                }
            }

            // Date of Birth
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showDatePicker = true }
                ) {
                    OutlinedTextField(
                        value = editState.dateOfBirth,
                        onValueChange = {},
                        label = { Text("Date of Birth") },
                        modifier = Modifier.fillMaxWidth(),
                        readOnly = true,
                        enabled = false,
                        trailingIcon = {
                            Icon(Icons.Default.CalendarToday, contentDescription = "Pick date")
                        },
                        colors = OutlinedTextFieldDefaults.colors(
                            disabledTextColor = MaterialTheme.colorScheme.onSurface,
                            disabledBorderColor = MaterialTheme.colorScheme.outline,
                            disabledLabelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            disabledTrailingIconColor = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    )
                }
            }

            // Height
            item {
                OutlinedTextField(
                    value = editState.heightCm,
                    onValueChange = { viewModel.updateEditField { copy(heightCm = it) } },
                    label = { Text("Height (cm)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    suffix = { Text("cm") },
                    isError = editState.heightCm.isNotEmpty() &&
                            (editState.heightCm.toDoubleOrNull() ?: 0.0) <= 0,
                    supportingText = if (editState.heightCm.isNotEmpty() &&
                        (editState.heightCm.toDoubleOrNull() ?: 0.0) <= 0
                    ) {
                        { Text("Enter a valid height") }
                    } else null
                )
            }

            // Weight
            item {
                OutlinedTextField(
                    value = editState.weightKg,
                    onValueChange = { viewModel.updateEditField { copy(weightKg = it) } },
                    label = { Text("Weight (kg)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    suffix = { Text("kg") },
                    isError = editState.weightKg.isNotEmpty() &&
                            (editState.weightKg.toDoubleOrNull() ?: 0.0) <= 0,
                    supportingText = if (editState.weightKg.isNotEmpty() &&
                        (editState.weightKg.toDoubleOrNull() ?: 0.0) <= 0
                    ) {
                        { Text("Enter a valid weight") }
                    } else null
                )
            }

            // BMI auto-calculated display
            item {
                val bmi = editState.calculatedBMI
                AnimatedVisibility(visible = bmi != null) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = PrimaryColor.copy(alpha = 0.1f)
                        ),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Accessibility,
                                contentDescription = null,
                                tint = PrimaryColor
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    "BMI",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    String.format(Locale.US, "%.1f", bmi ?: 0.0),
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                    color = PrimaryColor
                                )
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            Text(
                                editState.bmiCategory,
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            // Blood Type
            item {
                Text(
                    "Blood Type",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                val bloodTypes = listOf("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
                // Display in a flow/grid using LazyRow with wrapping
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    bloodTypes.chunked(4).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { bt ->
                                FilterChip(
                                    selected = editState.bloodType == bt,
                                    onClick = {
                                        viewModel.updateEditField {
                                            copy(bloodType = if (bloodType == bt) "" else bt)
                                        }
                                    },
                                    label = { Text(bt) },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            // Fill remaining spots if row is shorter
                            repeat(4 - row.size) {
                                Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // City
            item {
                OutlinedTextField(
                    value = editState.city,
                    onValueChange = { viewModel.updateEditField { copy(city = it) } },
                    label = { Text("City (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }

            // Activity Level
            item {
                Text(
                    "Activity Level",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                val levels = listOf("Sedentary", "Lightly Active", "Moderately Active", "Very Active", "Extra Active")
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    levels.chunked(2).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { level ->
                                FilterChip(
                                    selected = editState.activityLevel == level,
                                    onClick = { viewModel.updateEditField { copy(activityLevel = level) } },
                                    label = {
                                        Text(
                                            level,
                                            style = MaterialTheme.typography.labelSmall,
                                            textAlign = TextAlign.Center
                                        )
                                    },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            repeat(2 - row.size) {
                                Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }
}

@Composable
fun EditSectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = PrimaryColor,
        modifier = Modifier.padding(vertical = 4.dp)
    )
    HorizontalDivider()
}
