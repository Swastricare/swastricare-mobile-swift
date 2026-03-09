package com.swasthicare.mobile.ui.screens.diet

import android.Manifest
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.swasthicare.mobile.data.models.FoodItem
import com.swasthicare.mobile.data.models.MealType
import com.swasthicare.mobile.data.models.ServingUnit
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.theme.AppColors
import java.io.File

// ─────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────

private val SnapGreen = Color(0xFF4CAF50)

private fun saveBitmapToCache(context: Context, bitmap: Bitmap): Uri {
    val file = File(context.cacheDir, "snap_food_${System.currentTimeMillis()}.jpg")
    file.outputStream().use { out ->
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
    }
    return Uri.fromFile(file)
}

// ─────────────────────────────────────
// MARK: - FoodSnapScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodSnapScreen(
    mealTypeDb: String,
    onDismiss: () -> Unit,
    onNavigateToAddFood: (String) -> Unit
) {
    val vm = remember { AppContainer.dietViewModel }
    val uiState by vm.uiState.collectAsState()
    val context = LocalContext.current

    // Auto-detect meal type from time of day
    val autoMealType = remember {
        val hour = java.time.LocalTime.now().hour
        when {
            hour < 10 -> MealType.BREAKFAST
            hour < 14 -> MealType.LUNCH
            hour < 17 -> MealType.EVENING_SNACK
            else -> MealType.DINNER
        }
    }

    // Track whether the picker sheet should be shown (set to true initially)
    var showPickerSheet by remember { mutableStateOf(true) }

    // Gallery launcher
    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri != null) {
            showPickerSheet = false
            vm.analyzeFood(context, uri)
        }
    }

    // Camera launcher (preview — no FileProvider needed)
    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap: Bitmap? ->
        if (bitmap != null) {
            showPickerSheet = false
            val uri = saveBitmapToCache(context, bitmap)
            vm.analyzeFood(context, uri)
        }
    }

    // Camera permission launcher
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            cameraLauncher.launch(null)
        }
    }

    // Clear snap state when leaving the screen
    DisposableEffect(Unit) {
        onDispose {
            vm.clearSnapState()
        }
    }

    val snapState = uiState.snapState

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        when (snapState) {
            is SnapAnalysisState.Idle -> {
                // Show back/cancel top bar while idle (picker sheet is shown below)
                Column(modifier = Modifier.fillMaxSize()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = onDismiss) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = "Close",
                                tint = AppColors.onSurface
                            )
                        }
                        Text(
                            "Food Snap",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.weight(1f).padding(start = 4.dp)
                        )
                    }
                    // Placeholder content behind the sheet
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(
                            "Select an image to analyze",
                            color = AppColors.onSurface.copy(alpha = 0.4f),
                            fontSize = 15.sp
                        )
                    }
                }
            }

            is SnapAnalysisState.Analyzing -> {
                AnalyzingContent(imageUri = uiState.snapImageUri)
            }

            is SnapAnalysisState.Result -> {
                ReviewForm(
                    food = snapState.food.toFoodItem(),
                    imageUri = uiState.snapImageUri,
                    autoMealType = autoMealType,
                    dailyCalorieGoal = uiState.dietGoals.dailyCalories.takeIf { it > 0 } ?: 2000,
                    onRetake = {
                        vm.clearSnapState()
                        showPickerSheet = true
                    },
                    onLogMeal = { item, quantity, mealType ->
                        vm.logFood(item, quantity, mealType)
                        vm.clearSnapState()
                        onDismiss()
                    },
                    onDismiss = onDismiss
                )
            }

            is SnapAnalysisState.Error -> {
                ErrorContent(
                    message = snapState.message,
                    onTryAgain = {
                        vm.clearSnapState()
                        showPickerSheet = true
                    },
                    onEnterManually = {
                        vm.clearSnapState()
                        onNavigateToAddFood(mealTypeDb)
                    }
                )
            }
        }
    }

    // Image picker bottom sheet (shown on Idle state or after retry)
    if (showPickerSheet && snapState is SnapAnalysisState.Idle) {
        ModalBottomSheet(
            onDismissRequest = {
                showPickerSheet = false
                onDismiss()
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = AppColors.surface
        ) {
            PickerSheetContent(
                onTakePhoto = {
                    cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                },
                onChooseFromGallery = {
                    galleryLauncher.launch("image/*")
                },
                onDismiss = {
                    showPickerSheet = false
                    onDismiss()
                }
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Picker Sheet Content
// ─────────────────────────────────────

@Composable
private fun PickerSheetContent(
    onTakePhoto: () -> Unit,
    onChooseFromGallery: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Add Food Photo",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
        Text(
            "Take or choose a photo of your meal. Our AI will identify the food and estimate nutrition.",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(4.dp))

        // Camera option
        Button(
            onClick = onTakePhoto,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            colors = ButtonDefaults.buttonColors(containerColor = SnapGreen),
            shape = RoundedCornerShape(14.dp)
        ) {
            Icon(Icons.Default.CameraAlt, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(10.dp))
            Text("Take Photo", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }

        // Gallery option
        OutlinedButton(
            onClick = onChooseFromGallery,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = SnapGreen),
            border = BorderStroke(1.5.dp, SnapGreen)
        ) {
            Icon(Icons.Default.PhotoLibrary, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(10.dp))
            Text("Choose from Gallery", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }

        TextButton(
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Cancel", color = AppColors.onSurface.copy(alpha = 0.5f), fontSize = 15.sp)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Hero Photo Header
// ─────────────────────────────────────

@Composable
private fun HeroPhotoHeader(
    imageUri: String?,
    foodName: String,
    onFoodNameChange: (String) -> Unit,
    onBack: () -> Unit,
    onRetake: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        // Full-bleed photo
        if (imageUri != null) {
            AsyncImage(
                model = imageUri,
                contentDescription = "Food photo",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF1C1C1E))
            )
        }

        // Bottom gradient overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.25f),
                            Color.Black.copy(alpha = 0.75f)
                        ),
                        startY = 0f
                    )
                )
        )

        // Top bar (back + retake)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    tint = Color.White
                )
            }
            IconButton(onClick = onRetake) {
                Icon(
                    Icons.Default.CameraAlt,
                    contentDescription = "Retake",
                    tint = Color.White
                )
            }
        }

        // Food name + AI badge at bottom of hero
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // AI detected badge
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = Color.White.copy(alpha = 0.18f),
                tonalElevation = 0.dp
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        Icons.Default.Star,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(13.dp)
                    )
                    Text(
                        "AI detected",
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // Editable food name
            BasicTextField(
                value = foodName,
                onValueChange = onFoodNameChange,
                textStyle = TextStyle(
                    color = Color.White,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold
                ),
                cursorBrush = SolidColor(Color.White),
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Calorie Summary
// ─────────────────────────────────────

@Composable
private fun CalorieSummarySection(
    calories: String,
    onCaloriesChange: (String) -> Unit,
    progress: Float,
    dailyGoal: Int
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Inline-editable calorie number
            BasicTextField(
                value = calories,
                onValueChange = { if (it.length <= 5) onCaloriesChange(it) },
                textStyle = TextStyle(
                    fontSize = 52.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface,
                    textAlign = TextAlign.End
                ),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                cursorBrush = SolidColor(SnapGreen),
                singleLine = true,
                modifier = Modifier.widthIn(min = 60.dp, max = 160.dp)
            )
            Text(
                text = "kcal",
                fontSize = 16.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = SnapGreen,
                trackColor = AppColors.onSurface.copy(alpha = 0.1f)
            )
            Text(
                text = "${(progress * 100).toInt()}% of daily goal ($dailyGoal kcal)",
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.45f),
                modifier = Modifier.align(Alignment.End)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Macro Pills
// ─────────────────────────────────────

private val MacroProteinColor = Color(0xFF4CAF50)
private val MacroCarbsColor   = Color(0xFFFF9800)
private val MacroFatColor     = Color(0xFFFFD600)

@Composable
private fun MacroPillsRow(
    proteinG: String,
    onProteinChange: (String) -> Unit,
    carbsG: String,
    onCarbsChange: (String) -> Unit,
    fatG: String,
    onFatChange: (String) -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        MacroPill(
            label = "Protein",
            value = proteinG,
            onValueChange = onProteinChange,
            accentColor = MacroProteinColor,
            cardBg = cardBg,
            modifier = Modifier.weight(1f)
        )
        MacroPill(
            label = "Carbs",
            value = carbsG,
            onValueChange = onCarbsChange,
            accentColor = MacroCarbsColor,
            cardBg = cardBg,
            modifier = Modifier.weight(1f)
        )
        MacroPill(
            label = "Fat",
            value = fatG,
            onValueChange = onFatChange,
            accentColor = MacroFatColor,
            cardBg = cardBg,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun MacroPill(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    accentColor: Color,
    cardBg: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = cardBg),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column {
            // Colored top accent line
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .background(
                        accentColor,
                        shape = RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp)
                    )
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    BasicTextField(
                        value = value,
                        onValueChange = { if (it.length <= 4) onValueChange(it) },
                        textStyle = TextStyle(
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.onSurface,
                            textAlign = TextAlign.End
                        ),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        cursorBrush = SolidColor(accentColor),
                        singleLine = true,
                        modifier = Modifier.widthIn(min = 28.dp, max = 52.dp)
                    )
                    Text(
                        text = "g",
                        fontSize = 13.sp,
                        color = AppColors.onSurface.copy(alpha = 0.45f),
                        modifier = Modifier.padding(bottom = 1.dp)
                    )
                }
                Text(
                    text = label,
                    fontSize = 11.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Serving Row
// ─────────────────────────────────────

@Composable
private fun ServingRow(
    servingSize: Double,
    selectedUnit: ServingUnit,
    onServingChange: (Double) -> Unit,
    onUnitChange: (ServingUnit) -> Unit
) {
    var showUnitDropdown by remember { mutableStateOf(false) }
    val isDark = isSystemInDarkTheme()
    val chipBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            "Serving",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onSurface
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Stepper
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier
                    .background(chipBg, RoundedCornerShape(12.dp))
                    .padding(horizontal = 4.dp, vertical = 2.dp)
            ) {
                IconButton(
                    onClick = { onServingChange((servingSize - 0.5).coerceAtLeast(0.5)) },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Remove,
                        contentDescription = "Decrease",
                        tint = AppColors.onSurface,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    text = if (servingSize % 1.0 == 0.0) servingSize.toInt().toString()
                           else servingSize.toString(),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface,
                    modifier = Modifier.widthIn(min = 32.dp),
                    textAlign = TextAlign.Center
                )
                IconButton(
                    onClick = { onServingChange(servingSize + 0.5) },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = "Increase",
                        tint = AppColors.onSurface,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Unit chip
            Box {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = chipBg,
                    modifier = Modifier.clickableNoRipple { showUnitDropdown = true }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            selectedUnit.displayName,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = AppColors.onSurface
                        )
                        Icon(
                            Icons.Default.ArrowDropDown,
                            contentDescription = null,
                            tint = AppColors.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
                DropdownMenu(
                    expanded = showUnitDropdown,
                    onDismissRequest = { showUnitDropdown = false }
                ) {
                    ServingUnit.values().forEach { unit ->
                        DropdownMenuItem(
                            text = { Text(unit.displayName) },
                            onClick = {
                                onUnitChange(unit)
                                showUnitDropdown = false
                            }
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Meal Type Chips
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MealTypeChips(
    selected: MealType,
    onSelect: (MealType) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "Meal",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(MealType.values()) { mealType ->
                val isSelected = mealType == selected
                FilterChip(
                    selected = isSelected,
                    onClick = { onSelect(mealType) },
                    label = {
                        Text(
                            mealType.displayName,
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                        )
                    },
                    leadingIcon = {
                        Icon(
                            mealType.iconVector(),
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                    },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = SnapGreen,
                        selectedLabelColor = Color.White,
                        selectedLeadingIconColor = Color.White,
                        iconColor = mealType.accentColor()
                    ),
                    border = FilterChipDefaults.filterChipBorder(
                        enabled = true,
                        selected = isSelected,
                        borderColor = AppColors.onSurface.copy(alpha = 0.15f),
                        selectedBorderColor = Color.Transparent
                    )
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Analyzing State
// ─────────────────────────────────────

@Composable
private fun AnalyzingContent(imageUri: String?) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Photo thumbnail
        if (imageUri != null) {
            Box(
                modifier = Modifier
                    .size(180.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(cardBg)
            ) {
                AsyncImage(
                    model = imageUri,
                    contentDescription = "Food photo",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }
            Spacer(Modifier.height(32.dp))
        }

        CircularProgressIndicator(
            color = SnapGreen,
            modifier = Modifier.size(48.dp),
            strokeWidth = 4.dp
        )
        Spacer(Modifier.height(20.dp))
        Text(
            "Analyzing your meal...",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Our AI is identifying the food and estimating nutrition values.",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface.copy(alpha = 0.5f),
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - Error State
// ─────────────────────────────────────

@Composable
private fun ErrorContent(
    message: String,
    onTryAgain: () -> Unit,
    onEnterManually: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = cardBg)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color(0xFFFF453A),
                    modifier = Modifier.size(48.dp)
                )
                Text(
                    "Analysis Failed",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Text(
                    message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center
                )

                Spacer(Modifier.height(4.dp))

                Button(
                    onClick = onTryAgain,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SnapGreen),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Try Again", fontWeight = FontWeight.SemiBold)
                }

                OutlinedButton(
                    onClick = onEnterManually,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.onSurface),
                    border = BorderStroke(1.dp, AppColors.onSurface.copy(alpha = 0.3f))
                ) {
                    Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Enter Manually", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Review Form
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReviewForm(
    food: FoodItem,
    imageUri: String?,
    autoMealType: MealType,
    dailyCalorieGoal: Int,
    onRetake: () -> Unit,
    onLogMeal: (FoodItem, Double, MealType) -> Unit,
    onDismiss: () -> Unit
) {
    // Editable state — pre-filled from AI result
    var foodName by remember { mutableStateOf(food.name) }
    var calories by remember { mutableStateOf(food.calories.toInt().toString()) }
    var proteinG by remember { mutableStateOf(food.proteinG.toInt().toString()) }
    var carbsG by remember { mutableStateOf(food.carbsG.toInt().toString()) }
    var fatG by remember { mutableStateOf(food.fatG.toInt().toString()) }
    var servingSize by remember { mutableStateOf(food.servingSize) }
    var selectedUnit by remember { mutableStateOf(food.servingUnitEnum) }
    var selectedMealType by remember { mutableStateOf(autoMealType) }
    var isLogging by remember { mutableStateOf(false) }

    val isValid = foodName.isNotBlank() && calories.toDoubleOrNull() != null

    val calorieProgress = remember(calories, dailyCalorieGoal) {
        (calories.toFloatOrNull() ?: 0f) / dailyCalorieGoal.coerceAtLeast(1)
    }.coerceIn(0f, 1f)

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Hero photo section (45% of screen height)
            HeroPhotoHeader(
                imageUri = imageUri,
                foodName = foodName,
                onFoodNameChange = { foodName = it },
                onBack = onDismiss,
                onRetake = onRetake,
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.45f)
            )

            // Data sheet
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        color = MaterialTheme.colorScheme.surface,
                        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
                    )
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 24.dp, bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                CalorieSummarySection(
                    calories = calories,
                    onCaloriesChange = { calories = it },
                    progress = calorieProgress,
                    dailyGoal = dailyCalorieGoal
                )

                MacroPillsRow(
                    proteinG = proteinG,
                    onProteinChange = { proteinG = it },
                    carbsG = carbsG,
                    onCarbsChange = { carbsG = it },
                    fatG = fatG,
                    onFatChange = { fatG = it }
                )

                ServingRow(
                    servingSize = servingSize,
                    selectedUnit = selectedUnit,
                    onServingChange = { servingSize = it },
                    onUnitChange = { selectedUnit = it }
                )

                MealTypeChips(
                    selected = selectedMealType,
                    onSelect = { selectedMealType = it }
                )

                // Log Meal button
                Button(
                    onClick = {
                        if (!isValid || isLogging) return@Button
                        isLogging = true
                        val logged = FoodItem(
                            name = foodName.trim(),
                            servingSize = servingSize,
                            servingUnit = selectedUnit.dbValue,
                            calories = calories.toDoubleOrNull() ?: food.calories,
                            proteinG = proteinG.toDoubleOrNull() ?: food.proteinG,
                            carbsG = carbsG.toDoubleOrNull() ?: food.carbsG,
                            fatG = fatG.toDoubleOrNull() ?: food.fatG,
                            fiberG = food.fiberG,
                            category = food.category
                        )
                        onLogMeal(logged, servingSize, selectedMealType)
                    },
                    enabled = isValid && !isLogging,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SnapGreen),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    if (isLogging) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(22.dp),
                            strokeWidth = 2.5.dp
                        )
                    } else {
                        Text(
                            "Log Meal",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }

    }
}

// ─────────────────────────────────────
// MARK: - Util: clickable without ripple overlay
// ─────────────────────────────────────

@Composable
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier {
    val interactionSource = remember { MutableInteractionSource() }
    return this.clickable(
        interactionSource = interactionSource,
        indication = null,
        onClick = onClick
    )
}
