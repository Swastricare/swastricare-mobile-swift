package com.swasthicare.mobile.ui.screens.profile

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swasthicare.mobile.data.model.Gender
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PremiumColor
import com.swasthicare.mobile.ui.theme.AppColors
import java.util.Locale

// ─────────────────────────────────────────────────────────────────────
//  EditProfileScreen  (Android equivalent of iOS AccountView)
// ─────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileScreen(
    viewModel: ProfileViewModel = viewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.editFormState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    // Initialise form from current profile data when screen appears
    LaunchedEffect(uiState.user, uiState.healthProfile) {
        viewModel.initEditForm()
    }

    // React to save success / error with snackbar
    LaunchedEffect(formState.saveSuccess, formState.saveError) {
        if (formState.saveSuccess) {
            snackbarHostState.showSnackbar(
                message = "Profile updated successfully!",
                duration = SnackbarDuration.Short
            )
            viewModel.clearSaveResult()
        }
        formState.saveError?.let { error ->
            snackbarHostState.showSnackbar(
                message = error,
                duration = SnackbarDuration.Long
            )
            viewModel.clearSaveResult()
        }
    }

    val hasChanges = viewModel.hasEditChanges
    val isValid = viewModel.isEditFormValid

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text("Edit Profile") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = AppColors.onBackground,
                    navigationIconContentColor = AppColors.onBackground
                ),
                windowInsets = WindowInsets(0, 0, 0, 0)
            )
        },
        containerColor = Color.Transparent
    ) { paddingValues ->

        Box(modifier = Modifier.fillMaxSize()) {
            PremiumBackground()

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp, bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp)
            ) {
                // ── Avatar ──────────────────────────────────────────
                AvatarSection(
                    avatarUrl = uiState.user?.avatarUrl,
                    name = formState.name,
                    email = uiState.user?.email ?: ""
                )

                // ── Phone Missing Banner ────────────────────────────
                if (formState.phone.isBlank()) {
                    PhoneMissingBanner()
                }

                // ── Personal Information ────────────────────────────
                EditSection(title = "PERSONAL INFORMATION") {
                    // Full Name
                    EditTextField(
                        title = "Full Name",
                        icon = Icons.Default.Person,
                        iconColor = Color(0xFF4A90E2),
                        value = formState.name,
                        onValueChange = viewModel::updateEditName
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Phone Number
                    EditTextField(
                        title = "Phone Number",
                        icon = Icons.Default.Phone,
                        iconColor = Color(0xFF34C759),
                        value = formState.phone,
                        onValueChange = viewModel::updateEditPhone,
                        placeholder = "Add phone number",
                        keyboardType = KeyboardType.Phone
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Bio / Description (multiline)
                    BioField(
                        value = formState.bio,
                        onValueChange = viewModel::updateEditBio
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Gender dropdown
                    GenderSelector(
                        selected = formState.gender,
                        onSelected = viewModel::updateEditGender
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Date of Birth
                    DateOfBirthField(
                        value = formState.dateOfBirth,
                        onValueChange = viewModel::updateEditDateOfBirth
                    )
                }

                // ── Body Stats ──────────────────────────────────────
                EditSection(title = "BODY STATS") {
                    // Height slider
                    SliderField(
                        label = "Height",
                        value = formState.heightCm.toFloat(),
                        valueLabel = "${formState.heightCm.toInt()} cm",
                        range = 100f..250f,
                        steps = 150,
                        icon = Icons.Default.Straighten,
                        iconColor = Color(0xFF34C759),
                        onValueChange = { viewModel.updateEditHeightCm(it.toDouble()) }
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Weight slider
                    SliderField(
                        label = "Weight",
                        value = formState.weightKg.toFloat(),
                        valueLabel = String.format(Locale.US, "%.1f kg", formState.weightKg),
                        range = 20f..250f,
                        steps = 460,
                        icon = Icons.Default.MonitorWeight,
                        iconColor = Color(0xFF64D2FF),
                        onValueChange = { viewModel.updateEditWeightKg(it.toDouble()) }
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // BMI (computed, read-only)
                    val bmi = viewModel.computeBmi(formState.heightCm, formState.weightKg)
                    val bmiCat = viewModel.bmiCategory(bmi)
                    BmiRow(bmi = bmi, category = bmiCat)

                    Spacer(modifier = Modifier.height(16.dp))

                    // Blood Type dropdown
                    BloodTypeSelector(
                        selected = formState.bloodType,
                        onSelected = viewModel::updateEditBloodType
                    )
                }

                // ── Location ────────────────────────────────────────
                EditSection(title = "LOCATION") {
                    EditTextField(
                        title = "City",
                        icon = Icons.Default.LocationOn,
                        iconColor = Color(0xFF30D5C8),
                        value = formState.city,
                        onValueChange = viewModel::updateEditCity,
                        placeholder = "Your city"
                    )
                }

                // ── Account Details (Read-Only) ─────────────────────
                EditSection(title = "ACCOUNT DETAILS") {
                    ReadOnlyRow(
                        icon = Icons.Default.Email,
                        iconColor = Color(0xFF4F46E5),
                        label = "Email",
                        value = uiState.user?.email ?: "Not available"
                    )

                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp, top = 8.dp, bottom = 8.dp),
                        color = AppColors.onSurface.copy(alpha = 0.08f)
                    )

                    ReadOnlyRow(
                        icon = Icons.Default.CalendarMonth,
                        iconColor = Color(0xFFFF9F0A),
                        label = "Member Since",
                        value = viewModel.memberSince
                    )
                }

                // ── Save Button ─────────────────────────────────────
                SaveButton(
                    enabled = hasChanges && isValid && !formState.isSaving,
                    isSaving = formState.isSaving,
                    onClick = { viewModel.saveEditProfile() }
                )

                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }
}

// =====================================================================
//  Composable building blocks
// =====================================================================

// ── Avatar ───────────────────────────────────────────────────────────

@Composable
private fun AvatarSection(
    avatarUrl: String?,
    name: String,
    email: String
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (avatarUrl != null) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(avatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "Profile picture",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(88.dp)
                    .clip(CircleShape)
            )
        } else {
            // Gradient placeholder
            Box(
                modifier = Modifier
                    .size(88.dp)
                    .shadow(10.dp, CircleShape, ambientColor = Color(0xFF2E3192).copy(alpha = 0.25f))
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(Color(0xFF2E3192), Color(0xFF4A90E2))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = name.take(1).uppercase(),
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }

        Text(
            text = email,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onBackground.copy(alpha = 0.6f)
        )
    }
}

// ── Phone Missing Banner ─────────────────────────────────────────────

@Composable
private fun PhoneMissingBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFFFF8E53).copy(alpha = 0.08f))
            .border(
                width = 1.dp,
                color = Color(0xFFFF8E53).copy(alpha = 0.2f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.PhoneAndroid,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = Color(0xFFFF6B6B)
        )

        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Add your phone number",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onBackground
            )
            Text(
                text = "For family emergency alerts and account recovery",
                fontSize = 13.sp,
                color = AppColors.onBackground.copy(alpha = 0.6f)
            )
        }
    }
}

// ── Section Container ────────────────────────────────────────────────

@Composable
private fun EditSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onBackground.copy(alpha = 0.5f),
            letterSpacing = 0.8.sp,
            modifier = Modifier.padding(start = 4.dp)
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 20.dp)
                .padding(20.dp),
            content = content
        )
    }
}

// ── Editable Text Field ──────────────────────────────────────────────

@Composable
private fun EditTextField(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = title,
    keyboardType: KeyboardType = KeyboardType.Text
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground.copy(alpha = 0.5f)
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AppColors.onBackground.copy(alpha = 0.04f))
                .border(
                    1.dp,
                    AppColors.onBackground.copy(alpha = 0.08f),
                    RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 14.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(24.dp)
            )

            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = {
                    Text(
                        placeholder,
                        color = AppColors.onBackground.copy(alpha = 0.3f)
                    )
                },
                singleLine = true,
                modifier = Modifier
                    .weight(1f),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent,
                    cursorColor = PremiumColor.RoyalBlueStart
                ),
                keyboardOptions = KeyboardOptions(keyboardType = keyboardType)
            )
        }
    }
}

// ── Bio / Description (multiline) ────────────────────────────────────

@Composable
private fun BioField(
    value: String,
    onValueChange: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Bio",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground.copy(alpha = 0.5f)
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AppColors.onBackground.copy(alpha = 0.04f))
                .border(
                    1.dp,
                    AppColors.onBackground.copy(alpha = 0.08f),
                    RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 14.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.FormatQuote,
                contentDescription = null,
                tint = Color(0xFF9C27B0),
                modifier = Modifier
                    .size(24.dp)
                    .padding(top = 12.dp)
            )

            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = {
                    Text(
                        "Write something about yourself...",
                        color = AppColors.onBackground.copy(alpha = 0.3f)
                    )
                },
                minLines = 3,
                maxLines = 5,
                modifier = Modifier.weight(1f),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent,
                    cursorColor = PremiumColor.RoyalBlueStart
                )
            )
        }
    }
}

// ── Gender Selector ──────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GenderSelector(
    selected: Gender,
    onSelected: (Gender) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Gender",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground.copy(alpha = 0.5f)
        )

        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(AppColors.onBackground.copy(alpha = 0.04f))
                    .border(
                        1.dp,
                        AppColors.onBackground.copy(alpha = 0.08f),
                        RoundedCornerShape(16.dp)
                    )
                    .menuAnchor()
                    .clickable { expanded = true }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.People,
                    contentDescription = null,
                    tint = Color(0xFF4F46E5),
                    modifier = Modifier.size(24.dp)
                )
                Text(
                    text = selected.displayName,
                    fontSize = 16.sp,
                    color = AppColors.onBackground,
                    modifier = Modifier.weight(1f)
                )
                ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
            }

            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                Gender.entries.forEach { gender ->
                    DropdownMenuItem(
                        text = { Text(gender.displayName) },
                        onClick = {
                            onSelected(gender)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

// ── Date of Birth ────────────────────────────────────────────────────

@Composable
private fun DateOfBirthField(
    value: String, // yyyy-MM-dd
    onValueChange: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Date of Birth",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground.copy(alpha = 0.5f)
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AppColors.onBackground.copy(alpha = 0.04f))
                .border(
                    1.dp,
                    AppColors.onBackground.copy(alpha = 0.08f),
                    RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 14.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.CalendarToday,
                contentDescription = null,
                tint = Color(0xFFFF9F0A),
                modifier = Modifier.size(24.dp)
            )

            OutlinedTextField(
                value = value,
                onValueChange = { newValue ->
                    // Simple validation: allow only digits and dashes in yyyy-MM-dd format
                    if (newValue.matches(Regex("^[0-9-]*$")) && newValue.length <= 10) {
                        onValueChange(newValue)
                    }
                },
                placeholder = {
                    Text(
                        "yyyy-MM-dd",
                        color = AppColors.onBackground.copy(alpha = 0.3f)
                    )
                },
                singleLine = true,
                modifier = Modifier.weight(1f),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent,
                    cursorColor = PremiumColor.RoyalBlueStart
                ),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
            )
        }
    }
}

// ── Slider Field (Height / Weight) ───────────────────────────────────

@Composable
private fun SliderField(
    label: String,
    value: Float,
    valueLabel: String,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    icon: ImageVector,
    iconColor: Color,
    onValueChange: (Float) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = label,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onBackground.copy(alpha = 0.5f)
            )
            Text(
                text = valueLabel,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = PremiumColor.RoyalBlueStart
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(AppColors.onBackground.copy(alpha = 0.04f))
                .border(
                    1.dp,
                    AppColors.onBackground.copy(alpha = 0.08f),
                    RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(24.dp)
            )

            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = range,
                steps = steps,
                modifier = Modifier.weight(1f),
                colors = SliderDefaults.colors(
                    thumbColor = PremiumColor.RoyalBlueStart,
                    activeTrackColor = PremiumColor.RoyalBlueStart,
                    inactiveTrackColor = AppColors.onBackground.copy(alpha = 0.1f)
                )
            )
        }
    }
}

// ── BMI Row (read-only computed) ─────────────────────────────────────

@Composable
private fun BmiRow(bmi: Double, category: String) {
    val bmiColor = when {
        bmi < 18.5 -> Color(0xFFFF9F0A)
        bmi < 25.0 -> Color(0xFF34C759)
        bmi < 30.0 -> Color(0xFFFF9F0A)
        else -> Color(0xFFFF3B30)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.onBackground.copy(alpha = 0.04f))
            .border(
                1.dp,
                AppColors.onBackground.copy(alpha = 0.08f),
                RoundedCornerShape(16.dp)
            )
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Accessibility,
            contentDescription = null,
            tint = Color(0xFF4F46E5),
            modifier = Modifier.size(24.dp)
        )

        Text(
            text = "BMI",
            fontSize = 16.sp,
            color = AppColors.onBackground
        )

        Spacer(modifier = Modifier.weight(1f))

        Text(
            text = String.format(Locale.US, "%.1f", bmi),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = bmiColor
        )

        Text(
            text = category,
            fontSize = 13.sp,
            color = AppColors.onBackground.copy(alpha = 0.5f)
        )
    }
}

// ── Blood Type Selector ──────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BloodTypeSelector(
    selected: String,
    onSelected: (String) -> Unit
) {
    val bloodTypes = listOf("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
    var expanded by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Blood Type",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground.copy(alpha = 0.5f)
        )

        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(AppColors.onBackground.copy(alpha = 0.04f))
                    .border(
                        1.dp,
                        AppColors.onBackground.copy(alpha = 0.08f),
                        RoundedCornerShape(16.dp)
                    )
                    .menuAnchor()
                    .clickable { expanded = true }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.WaterDrop,
                    contentDescription = null,
                    tint = Color(0xFFFF3B30),
                    modifier = Modifier.size(24.dp)
                )
                Text(
                    text = selected.ifBlank { "Not set" },
                    fontSize = 16.sp,
                    color = if (selected.isBlank())
                        AppColors.onBackground.copy(alpha = 0.3f)
                    else
                        AppColors.onBackground,
                    modifier = Modifier.weight(1f)
                )
                ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
            }

            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("Not set") },
                    onClick = {
                        onSelected("")
                        expanded = false
                    }
                )
                bloodTypes.forEach { type ->
                    DropdownMenuItem(
                        text = { Text(type) },
                        onClick = {
                            onSelected(type)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

// ── Read-Only Row ────────────────────────────────────────────────────

@Composable
private fun ReadOnlyRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    value: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(24.dp)
        )

        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = label,
                fontSize = 13.sp,
                color = AppColors.onBackground.copy(alpha = 0.5f)
            )
            Text(
                text = value.ifBlank { "Not available" },
                fontSize = 16.sp,
                color = AppColors.onBackground
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        Icon(
            imageVector = Icons.Default.Lock,
            contentDescription = null,
            tint = AppColors.onBackground.copy(alpha = 0.25f),
            modifier = Modifier.size(14.dp)
        )
    }
}

// ── Save Button ──────────────────────────────────────────────────────

@Composable
private fun SaveButton(
    enabled: Boolean,
    isSaving: Boolean,
    onClick: () -> Unit
) {
    val backgroundColor by animateColorAsState(
        targetValue = if (enabled) Color(0xFF2E3192) else Color.Gray.copy(alpha = 0.3f),
        label = "saveBtnColor"
    )

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .then(
                if (enabled) Modifier.shadow(
                    elevation = 12.dp,
                    shape = RoundedCornerShape(16.dp),
                    ambientColor = Color(0xFF2E3192).copy(alpha = 0.3f),
                    spotColor = Color(0xFF2E3192).copy(alpha = 0.3f)
                ) else Modifier
            ),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            disabledContainerColor = Color.Gray.copy(alpha = 0.3f),
            contentColor = Color.White,
            disabledContentColor = Color.White.copy(alpha = 0.5f)
        )
    ) {
        if (isSaving) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                color = Color.White,
                strokeWidth = 2.dp
            )
        } else {
            Icon(
                imageVector = Icons.Default.CheckCircle,
                contentDescription = null,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Save Changes",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp
            )
        }
    }
}
