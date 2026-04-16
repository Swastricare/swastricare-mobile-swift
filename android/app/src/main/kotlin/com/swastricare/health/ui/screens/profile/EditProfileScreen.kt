package com.swastricare.health.ui.screens.profile

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.data.model.Gender
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileScreen(
    viewModel: ProfileViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {}
) {
    TrackScreen("EditProfile")
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.editFormState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.user, uiState.healthProfile) { viewModel.initEditForm() }

    LaunchedEffect(formState.saveSuccess, formState.saveError) {
        if (formState.saveSuccess) {
            snackbarHostState.showSnackbar("Profile updated!", duration = SnackbarDuration.Short)
            viewModel.clearSaveResult()
        }
        formState.saveError?.let {
            snackbarHostState.showSnackbar(it, duration = SnackbarDuration.Long)
            viewModel.clearSaveResult()
        }
    }

    val hasChanges = viewModel.hasEditChanges
    val isValid = viewModel.isEditFormValid

    var showAddContactDialog by remember { mutableStateOf(false) }
    var contactName by remember { mutableStateOf("") }
    var contactRelationship by remember { mutableStateOf("") }
    var contactPhone by remember { mutableStateOf("") }
    var contactPhoneSecondary by remember { mutableStateOf("") }

    LaunchedEffect(uiState.healthProfile?.id) {
        if (uiState.healthProfile?.id != null) viewModel.loadEmergencyContacts()
    }
    LaunchedEffect(uiState.emergencyContactSuccess, uiState.emergencyContactError) {
        val msg = uiState.emergencyContactSuccess ?: uiState.emergencyContactError
        if (!msg.isNullOrBlank()) {
            snackbarHostState.showSnackbar(msg, duration = SnackbarDuration.Short)
            viewModel.clearEmergencyContactMessages()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            AppTopBar(
                title = "Edit Profile",
                onBack = onNavigateBack,
                actions = {
                    TextButton(
                        onClick = { viewModel.saveEditProfile() },
                        enabled = hasChanges && isValid && !formState.isSaving
                    ) {
                        if (formState.isSaving) {
                            CircularProgressIndicator(Modifier.size(18.dp), color = Color(0xFF22C55E), strokeWidth = 2.dp)
                        } else {
                            Text(
                                "Save",
                                color = if (hasChanges && isValid) Color(0xFF22C55E) else AppColors.onBackground.copy(alpha = 0.3f),
                                fontWeight = FontWeight.Bold, fontSize = 15.sp
                            )
                        }
                    }
                }
            )
        },
        containerColor = Color.Transparent
    ) { paddingValues ->

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 32.dp)
        ) {
            // ── Avatar ──
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val avatarUrl = uiState.user?.avatarUrl
                if (avatarUrl != null) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(avatarUrl).crossfade(true).build(),
                        contentDescription = "Profile picture",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(80.dp).clip(CircleShape)
                    )
                } else {
                    Box(
                        modifier = Modifier.size(80.dp).clip(CircleShape)
                            .background(Brush.linearGradient(listOf(Color(0xFF2E3192), Color(0xFF4A90E2)))),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(formState.name.take(1).uppercase(), fontSize = 30.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    }
                }
                Spacer(Modifier.height(6.dp))
                Text(uiState.user?.email ?: "", fontSize = 13.sp, color = AppColors.onBackground.copy(alpha = 0.45f))
            }

            // ── Personal ──
            SectionHeader("Personal")
            ProfileCard {
                UnderlineField("Full Name", formState.name, viewModel::updateEditName)
                FieldDivider()
                UnderlineField("Phone", formState.phone, viewModel::updateEditPhone, "Add phone number", KeyboardType.Phone)
                FieldDivider()
                UnderlineField("Bio", formState.bio, viewModel::updateEditBio, "Write something about you")
                FieldDivider()

                // Gender picker
                var genderExpanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(expanded = genderExpanded, onExpandedChange = { genderExpanded = it }) {
                    Row(
                        modifier = Modifier.fillMaxWidth().menuAnchor().clickable { genderExpanded = true }.padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Gender", fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f), modifier = Modifier.width(90.dp))
                        Text(formState.gender.displayName, fontSize = 15.sp, color = AppColors.onBackground)
                        Icon(Icons.Default.KeyboardArrowDown, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.3f))
                    }
                    ExposedDropdownMenu(expanded = genderExpanded, onDismissRequest = { genderExpanded = false }) {
                        Gender.entries.forEach { g ->
                            DropdownMenuItem(text = { Text(g.displayName) }, onClick = { viewModel.updateEditGender(g); genderExpanded = false })
                        }
                    }
                }
                FieldDivider()

                // Date of Birth — tap to open date picker
                var showDatePicker by remember { mutableStateOf(false) }
                val dobParts = formState.dateOfBirth.split("-")
                val initialMillis = try {
                    java.util.Calendar.getInstance().apply {
                        set(dobParts[0].toInt(), dobParts[1].toInt() - 1, dobParts[2].toInt(), 0, 0, 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                    }.timeInMillis
                } catch (_: Exception) { System.currentTimeMillis() }

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { showDatePicker = true }.padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Date of Birth", fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f), modifier = Modifier.width(90.dp))
                    Text(
                        formState.dateOfBirth.ifBlank { "Select" },
                        fontSize = 15.sp,
                        color = if (formState.dateOfBirth.isBlank()) AppColors.onBackground.copy(alpha = 0.25f) else AppColors.onBackground
                    )
                    Icon(Icons.Default.KeyboardArrowDown, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.3f))
                }

                if (showDatePicker) {
                    val initYear = dobParts.getOrNull(0)?.toIntOrNull() ?: 1999
                    val initMonth = (dobParts.getOrNull(1)?.toIntOrNull() ?: 1) - 1
                    val initDay = dobParts.getOrNull(2)?.toIntOrNull() ?: 1
                    val months = arrayOf("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")

                    var pickedYear by remember { mutableIntStateOf(initYear) }
                    var pickedMonth by remember { mutableIntStateOf(initMonth) }
                    var pickedDay by remember { mutableIntStateOf(initDay) }

                    AlertDialog(
                        onDismissRequest = { showDatePicker = false },
                        containerColor = AppColors.surfaceVariant.copy(alpha = 0.97f),
                        titleContentColor = AppColors.onBackground,
                        textContentColor = AppColors.onBackground,
                        title = { Text("Date of Birth", fontWeight = FontWeight.Bold, fontSize = 18.sp) },
                        text = {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    "${months[pickedMonth]} $pickedDay, $pickedYear",
                                    fontSize = 16.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground,
                                    modifier = Modifier.padding(bottom = 12.dp)
                                )
                                // Native NumberPickers
                                val isDark = isSystemInDarkTheme()
                                AndroidView(
                                    factory = { ctx ->
                                        android.widget.LinearLayout(ctx).apply {
                                            orientation = android.widget.LinearLayout.HORIZONTAL
                                            gravity = android.view.Gravity.CENTER

                                            val lp = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                                            val textColor = if (isDark) android.graphics.Color.WHITE else android.graphics.Color.BLACK
                                            val dividerColor = if (isDark) android.graphics.Color.parseColor("#33FFFFFF") else android.graphics.Color.parseColor("#1A000000")

                                            fun styleNumberPicker(picker: android.widget.NumberPicker) {
                                                try {
                                                    val dividerField = android.widget.NumberPicker::class.java.getDeclaredField("mSelectionDivider")
                                                    dividerField.isAccessible = true
                                                    dividerField.set(picker, android.graphics.drawable.ColorDrawable(dividerColor))
                                                } catch (_: Exception) {}
                                                try {
                                                    picker.textColor = textColor
                                                } catch (_: Exception) {}
                                            }

                                            // Month picker
                                            val monthPicker = android.widget.NumberPicker(ctx).apply {
                                                minValue = 0; maxValue = 11
                                                displayedValues = months
                                                value = initMonth
                                                wrapSelectorWheel = true
                                                setOnValueChangedListener { _, _, new -> pickedMonth = new }
                                            }
                                            styleNumberPicker(monthPicker)
                                            addView(monthPicker, lp)

                                            // Day picker
                                            val dayPicker = android.widget.NumberPicker(ctx).apply {
                                                minValue = 1; maxValue = 31
                                                value = initDay
                                                wrapSelectorWheel = true
                                                setOnValueChangedListener { _, _, new -> pickedDay = new }
                                            }
                                            styleNumberPicker(dayPicker)
                                            addView(dayPicker, lp)

                                            // Year picker
                                            val yearPicker = android.widget.NumberPicker(ctx).apply {
                                                minValue = 1940
                                                maxValue = java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)
                                                value = initYear
                                                wrapSelectorWheel = false
                                                setOnValueChangedListener { _, _, new -> pickedYear = new }
                                            }
                                            styleNumberPicker(yearPicker)
                                            addView(yearPicker, lp)
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth().height(180.dp)
                                )
                            }
                        },
                        confirmButton = {
                            Button(
                                onClick = {
                                    val maxDay = java.util.Calendar.getInstance().apply { set(pickedYear, pickedMonth, 1) }.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
                                    val safeDay = pickedDay.coerceAtMost(maxDay)
                                    viewModel.updateEditDateOfBirth(String.format(Locale.US, "%04d-%02d-%02d", pickedYear, pickedMonth + 1, safeDay))
                                    showDatePicker = false
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E))
                            ) { Text("Done") }
                        },
                        dismissButton = {
                            TextButton(onClick = { showDatePicker = false }) { Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f)) }
                        }
                    )
                }

                FieldDivider()
                UnderlineField("City", formState.city, viewModel::updateEditCity, "Your city")
            }

            // ── Body Stats ──
            SectionHeader("Body Stats")
            ProfileCard {
                // Height
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Height", fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                    Text("${formState.heightCm.toInt()} cm", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onBackground)
                }
                Slider(
                    value = formState.heightCm.toFloat(),
                    onValueChange = { viewModel.updateEditHeightCm(it.toDouble()) },
                    valueRange = 100f..250f,
                    modifier = Modifier.fillMaxWidth().height(32.dp),
                    colors = SliderDefaults.colors(
                        thumbColor = AppColors.onBackground,
                        activeTrackColor = AppColors.onBackground.copy(alpha = 0.5f),
                        inactiveTrackColor = AppColors.onBackground.copy(alpha = 0.08f)
                    )
                )
                FieldDivider()

                // Weight
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Weight", fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                    Text(String.format(Locale.US, "%.1f kg", formState.weightKg), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onBackground)
                }
                Slider(
                    value = formState.weightKg.toFloat(),
                    onValueChange = { viewModel.updateEditWeightKg(it.toDouble()) },
                    valueRange = 20f..250f,
                    modifier = Modifier.fillMaxWidth().height(32.dp),
                    colors = SliderDefaults.colors(
                        thumbColor = AppColors.onBackground,
                        activeTrackColor = AppColors.onBackground.copy(alpha = 0.5f),
                        inactiveTrackColor = AppColors.onBackground.copy(alpha = 0.08f)
                    )
                )
                FieldDivider()

                // BMI
                val bmi = viewModel.computeBmi(formState.heightCm, formState.weightKg)
                val bmiColor = when { bmi < 18.5 -> Color(0xFFFF9F0A); bmi < 25.0 -> Color(0xFF34C759); bmi < 30.0 -> Color(0xFFFF9F0A); else -> Color(0xFFFF3B30) }
                Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("BMI", fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                    Text("${String.format(Locale.US, "%.1f", bmi)} · ${viewModel.bmiCategory(bmi)}", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = bmiColor)
                }
                FieldDivider()

                // Blood Type
                var btExpanded by remember { mutableStateOf(false) }
                val bloodTypes = listOf("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
                ExposedDropdownMenuBox(expanded = btExpanded, onExpandedChange = { btExpanded = it }) {
                    Row(
                        modifier = Modifier.fillMaxWidth().menuAnchor().clickable { btExpanded = true }.padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Blood Type", fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(formState.bloodType.ifBlank { "Not set" }, fontSize = 15.sp, color = if (formState.bloodType.isBlank()) AppColors.onBackground.copy(alpha = 0.3f) else AppColors.onBackground)
                            Icon(Icons.Default.KeyboardArrowDown, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.3f))
                        }
                    }
                    ExposedDropdownMenu(expanded = btExpanded, onDismissRequest = { btExpanded = false }) {
                        DropdownMenuItem(text = { Text("Not set") }, onClick = { viewModel.updateEditBloodType(""); btExpanded = false })
                        bloodTypes.forEach { t ->
                            DropdownMenuItem(text = { Text(t) }, onClick = { viewModel.updateEditBloodType(t); btExpanded = false })
                        }
                    }
                }
            }

            // ── Emergency Contacts ──
            SectionHeader("Emergency Contacts")
            ProfileCard {
                if (uiState.isLoadingEmergencyContacts) {
                    Box(Modifier.fillMaxWidth().padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = Color(0xFF22C55E))
                    }
                } else {
                    uiState.emergencyContacts.forEachIndexed { i, contact ->
                        if (i > 0) FieldDivider()
                        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(contact.name, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
                                Text("${contact.relationship} · ${contact.phonePrimary}", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.45f))
                            }
                            IconButton(onClick = { contact.id?.let { viewModel.deleteEmergencyContact(it) } }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Default.Delete, null, tint = Color(0xFFEF4444).copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                    if (uiState.emergencyContacts.isEmpty()) {
                        Text("No contacts added yet", fontSize = 13.sp, color = AppColors.onBackground.copy(alpha = 0.35f), modifier = Modifier.padding(vertical = 8.dp))
                    }
                    Spacer(Modifier.height(4.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp))
                            .clickable { showAddContactDialog = true }.padding(vertical = 10.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Add, null, Modifier.size(16.dp), tint = Color(0xFF22C55E))
                        Spacer(Modifier.width(6.dp))
                        Text("Add Contact", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF22C55E))
                    }
                }
            }

            // ── Account ──
            SectionHeader("Account")
            ProfileCard {
                InfoRow("Email", uiState.user?.email ?: "—")
                FieldDivider()
                InfoRow("Member Since", viewModel.memberSince)
                FieldDivider()
                InfoRow("Version", viewModel.appVersion)
            }

            Spacer(Modifier.height(12.dp))

            // ── Danger Zone ──
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color(0xFFEF4444).copy(alpha = 0.06f))
                    .padding(horizontal = 16.dp, vertical = 4.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { viewModel.setShowDeleteAccountConfirmation(true) }
                        .padding(vertical = 14.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Delete Account", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFFEF4444))
                }
            }

            // Delete confirmation dialog
            if (uiState.showDeleteAccountConfirmation) {
                AlertDialog(
                    onDismissRequest = { viewModel.setShowDeleteAccountConfirmation(false) },
                    containerColor = AppColors.surfaceVariant.copy(alpha = 0.97f),
                    titleContentColor = AppColors.onBackground,
                    textContentColor = AppColors.onBackground,
                    title = { Text("Delete Account", fontWeight = FontWeight.Bold) },
                    text = { Text("This will permanently delete your account and all associated data. This action cannot be undone.") },
                    confirmButton = {
                        Button(
                            onClick = { viewModel.deleteAccount() },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEF4444))
                        ) { Text("Delete") }
                    },
                    dismissButton = {
                        TextButton(onClick = { viewModel.setShowDeleteAccountConfirmation(false) }) { Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f)) }
                    }
                )
            }

            Spacer(Modifier.height(16.dp))
        }
    }

    // ── Add Contact Dialog ──
    if (showAddContactDialog) {
        AlertDialog(
            onDismissRequest = { showAddContactDialog = false; contactName = ""; contactRelationship = ""; contactPhone = ""; contactPhoneSecondary = "" },
            containerColor = AppColors.surface,
            titleContentColor = AppColors.onBackground,
            textContentColor = AppColors.onBackground,
            title = { Text("Add Emergency Contact", fontWeight = FontWeight.Bold, fontSize = 18.sp) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(value = contactName, onValueChange = { contactName = it }, label = { Text("Name *") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(value = contactRelationship, onValueChange = { contactRelationship = it }, label = { Text("Relationship") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(value = contactPhone, onValueChange = { contactPhone = it }, label = { Text("Phone *") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(value = contactPhoneSecondary, onValueChange = { contactPhoneSecondary = it }, label = { Text("Alternate Phone") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth())
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.addEmergencyContact(contactName, contactRelationship, contactPhone, contactPhoneSecondary.ifBlank { null })
                        showAddContactDialog = false; contactName = ""; contactRelationship = ""; contactPhone = ""; contactPhoneSecondary = ""
                    },
                    enabled = contactName.isNotBlank() && contactPhone.length >= 10,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E))
                ) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { showAddContactDialog = false; contactName = ""; contactRelationship = ""; contactPhone = ""; contactPhoneSecondary = "" }) { Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f)) }
            }
        )
    }
}

// ═══════════════════════════════════════════════════════
//  Building blocks — borderless, clean design
// ═══════════════════════════════════════════════════════

@Composable
private fun SectionHeader(title: String) {
    Text(
        title.uppercase(),
        fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = AppColors.onBackground.copy(alpha = 0.35f),
        letterSpacing = 0.8.sp,
        modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 6.dp)
    )
}

@Composable
private fun ProfileCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(AppColors.surface)
            .padding(horizontal = 16.dp, vertical = 4.dp),
        content = content
    )
}

@Composable
private fun FieldDivider() {
    HorizontalDivider(
        color = AppColors.onBackground.copy(alpha = 0.06f),
        thickness = 0.5.dp
    )
}

@Composable
private fun UnderlineField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = label,
    keyboardType: KeyboardType = KeyboardType.Text
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            fontSize = 14.sp,
            color = AppColors.onBackground.copy(alpha = 0.5f),
            modifier = Modifier.width(90.dp)
        )
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = TextStyle(
                fontSize = 15.sp,
                color = AppColors.onBackground,
                fontWeight = FontWeight.Normal
            ),
            cursorBrush = SolidColor(Color(0xFF22C55E)),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            modifier = Modifier.weight(1f),
            decorationBox = { innerTextField ->
                Box {
                    if (value.isEmpty()) {
                        Text(placeholder, fontSize = 15.sp, color = AppColors.onBackground.copy(alpha = 0.25f))
                    }
                    innerTextField()
                }
            }
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
        Text(value.ifBlank { "—" }, fontSize = 14.sp, color = AppColors.onBackground)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun WheelPicker(
    items: List<String>,
    selectedIndex: Int,
    onSelected: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val itemHeightDp = 44.dp
    val visibleItems = 5
    val halfVisible = visibleItems / 2
    // Start with selected item scrolled to center
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = selectedIndex.coerceAtLeast(0))
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    var lastSnappedIndex by remember { mutableIntStateOf(selectedIndex) }

    // Center the selected item on first composition
    LaunchedEffect(Unit) {
        listState.scrollToItem(selectedIndex.coerceAtLeast(0))
    }

    // Snap to nearest item when scrolling stops + haptic
    LaunchedEffect(listState.isScrollInProgress) {
        if (!listState.isScrollInProgress) {
            val targetIndex = (listState.firstVisibleItemIndex +
                if (listState.firstVisibleItemScrollOffset > itemHeightDp.value * 0.5f) 1 else 0)
                .coerceIn(0, (items.size - 1).coerceAtLeast(0))
            listState.animateScrollToItem(targetIndex)
            if (targetIndex != lastSnappedIndex) {
                lastSnappedIndex = targetIndex
                haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                onSelected(targetIndex)
            }
        }
    }

    Box(
        modifier = modifier.height(itemHeightDp * visibleItems),
        contentAlignment = Alignment.Center
    ) {
        // Selection highlight band in center
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(itemHeightDp)
                .clip(RoundedCornerShape(10.dp))
                .background(Color(0xFF22C55E).copy(alpha = 0.1f))
        )

        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            // Pad top/bottom by halfVisible items so first/last items can reach center
            contentPadding = PaddingValues(vertical = itemHeightDp * halfVisible),
            flingBehavior = androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior(listState)
        ) {
            itemsIndexed(items) { index, item ->
                // The centered item is firstVisibleItemIndex + halfVisible
                val centerIndex = listState.firstVisibleItemIndex + halfVisible
                val distanceFromCenter = kotlin.math.abs(index - centerIndex)
                val alpha by animateFloatAsState(
                    targetValue = when (distanceFromCenter) { 0 -> 1f; 1 -> 0.5f; else -> 0.25f },
                    animationSpec = tween(150), label = "alpha"
                )
                val scale by animateFloatAsState(
                    targetValue = when (distanceFromCenter) { 0 -> 1f; 1 -> 0.9f; else -> 0.8f },
                    animationSpec = tween(150), label = "scale"
                )

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(itemHeightDp)
                        .graphicsLayer { scaleX = scale; scaleY = scale },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = item,
                        fontSize = if (distanceFromCenter == 0) 18.sp else 15.sp,
                        fontWeight = if (distanceFromCenter == 0) FontWeight.Bold else FontWeight.Normal,
                        color = AppColors.onBackground.copy(alpha = alpha),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }

        // Fade overlays
        Box(Modifier.fillMaxWidth().height(itemHeightDp * 1.5f).align(Alignment.TopCenter)
            .background(Brush.verticalGradient(listOf(MaterialTheme.colorScheme.surface.copy(alpha = 0.9f), Color.Transparent))))
        Box(Modifier.fillMaxWidth().height(itemHeightDp * 1.5f).align(Alignment.BottomCenter)
            .background(Brush.verticalGradient(listOf(Color.Transparent, MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)))))
    }
}
