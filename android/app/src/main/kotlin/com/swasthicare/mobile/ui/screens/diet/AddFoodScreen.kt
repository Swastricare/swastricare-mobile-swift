package com.swasthicare.mobile.ui.screens.diet

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.FoodCategory
import com.swasthicare.mobile.data.models.FoodItem
import com.swasthicare.mobile.data.models.MealType
import com.swasthicare.mobile.data.models.ServingUnit
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.theme.AppColors

// ─────────────────────────────────────
// MARK: - AddFoodScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddFoodScreen(
    initialMealTypeDb: String,
    onDismiss: () -> Unit,
    onNavigateToFoodSearch: (String) -> Unit  // mealType.dbValue
) {
    val vm = remember { AppContainer.dietViewModel }
    val uiState by vm.uiState.collectAsState()

    var searchText by remember { mutableStateOf("") }
    var currentMealType by remember { mutableStateOf(MealType.fromDb(initialMealTypeDb)) }
    var selectedFoodForQuantity by remember { mutableStateOf<FoodItem?>(null) }

    val searchResults = remember(searchText, uiState.foodItemsCache) {
        if (searchText.isBlank()) emptyList()
        else vm.searchFoods(searchText)
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = {
                    TextField(
                        value = searchText,
                        onValueChange = { searchText = it },
                        placeholder = { Text("Search foods...", color = AppColors.onSurface.copy(alpha = 0.4f)) },
                        singleLine = true,
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                },
                navigationIcon = {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = AppColors.onSurface)
                    }
                },
                actions = {
                    // Meal type pill
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(currentMealType.accentColor().copy(alpha = 0.15f))
                            .padding(horizontal = 10.dp, vertical = 5.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                currentMealType.iconVector(), null,
                                tint = currentMealType.accentColor(),
                                modifier = Modifier.size(13.dp)
                            )
                            Text(
                                currentMealType.displayName,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = currentMealType.accentColor()
                            )
                        }
                    }
                    Spacer(Modifier.width(8.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                windowInsets = WindowInsets(0, 0, 0, 0)
            )
        },
        containerColor = AppColors.surface
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = PaddingValues(bottom = 40.dp)
        ) {
            if (searchText.isNotEmpty()) {
                // Search results
                if (searchResults.isEmpty()) {
                    item {
                        SearchEmptyState()
                    }
                } else {
                    item {
                        Text(
                            "${searchResults.size} results",
                            fontSize = 13.sp,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                        )
                    }
                    items(searchResults) { food ->
                        FoodItemRow(
                            food = food,
                            onSelect = { selectedFoodForQuantity = food },
                            isFavorite = vm.isFavorite(food.id),
                            onToggleFavorite = { vm.toggleFavorite(food.id) }
                        )
                        Divider(
                            color = AppColors.onSurface.copy(alpha = 0.05f),
                            modifier = Modifier.padding(start = 78.dp)
                        )
                    }
                }
            } else {
                // Recent Foods
                val recent = vm.recentFoods
                if (recent.isNotEmpty()) {
                    item {
                        RecentFoodsSection(
                            foods = recent,
                            onSelect = { selectedFoodForQuantity = it }
                        )
                    }
                }

                // Favorites
                val favorites = vm.favoriteFoods
                if (favorites.isNotEmpty()) {
                    item {
                        FavoriteFoodsSection(
                            foods = favorites,
                            onSelect = { selectedFoodForQuantity = it }
                        )
                    }
                }

                // Category Grid
                item {
                    CategoryGridSection(
                        onCategorySelect = { onNavigateToFoodSearch(currentMealType.dbValue) }
                    )
                }

                // Custom Food Button
                item {
                    CustomFoodButton(
                        mealType = currentMealType,
                        onLogCustom = { name, qty, unit, cal, p, c, f ->
                            vm.logCustomFood(
                                name = name,
                                mealType = currentMealType,
                                quantity = qty,
                                servingUnit = unit,
                                calories = cal,
                                proteinG = p,
                                carbsG = c,
                                fatG = f
                            )
                            onDismiss()
                        }
                    )
                }
            }
        }
    }

    // Food Quantity Sheet
    selectedFoodForQuantity?.let { food ->
        FoodQuantitySheet(
            food = food,
            mealType = currentMealType,
            isFavorite = vm.isFavorite(food.id),
            onToggleFavorite = { vm.toggleFavorite(food.id) },
            onLog = { quantity ->
                vm.logFood(food, quantity * food.servingSize, currentMealType)
                selectedFoodForQuantity = null
                onDismiss()
            },
            onDismiss = { selectedFoodForQuantity = null }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Recent Foods
// ─────────────────────────────────────

@Composable
private fun RecentFoodsSection(foods: List<FoodItem>, onSelect: (FoodItem) -> Unit) {
    val isDark = isSystemInDarkTheme()
    val chipBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Column(
        modifier = Modifier.padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Default.History, null, tint = AppColors.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(15.dp))
            Text("Recent", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onSurface.copy(alpha = 0.5f))
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(horizontal = 16.dp)
        ) {
            items(foods) { food ->
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(chipBg)
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onSelect(food) }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(food.categoryEnum.icon, fontSize = 14.sp)
                    Text(food.name, fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 1)
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Favorites
// ─────────────────────────────────────

@Composable
private fun FavoriteFoodsSection(foods: List<FoodItem>, onSelect: (FoodItem) -> Unit) {
    Column(
        modifier = Modifier.padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Default.Favorite, null, tint = Color(0xFFFF2D55), modifier = Modifier.size(14.dp))
            Text("Favorites", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onSurface.copy(alpha = 0.5f))
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(horizontal = 16.dp)
        ) {
            items(foods) { food ->
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color(0xFFFF2D55).copy(alpha = 0.08f))
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onSelect(food) }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(food.categoryEnum.icon, fontSize = 14.sp)
                    Text(food.name, fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 1)
                    Icon(Icons.Default.Favorite, null, tint = Color(0xFFFF2D55), modifier = Modifier.size(10.dp))
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Category Grid
// ─────────────────────────────────────

@Composable
private fun CategoryGridSection(onCategorySelect: (FoodCategory) -> Unit) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Column(
        modifier = Modifier.padding(top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Browse by Category",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.padding(horizontal = 16.dp)
        )
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .heightIn(max = 400.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            userScrollEnabled = false
        ) {
            items(FoodCategory.values()) { category ->
                Column(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(cardBg)
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onCategorySelect(category) }
                        .padding(vertical = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(category.icon, fontSize = 32.sp)
                    Text(
                        category.displayName,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.onSurface,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Custom Food Button
// ─────────────────────────────────────

@Composable
private fun CustomFoodButton(
    mealType: MealType,
    onLogCustom: (name: String, qty: Double, unit: ServingUnit, cal: Double, p: Double, c: Double, f: Double) -> Unit
) {
    var showDialog by remember { mutableStateOf(false) }
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(cardBg)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { showDialog = true }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Default.AddCircle, null, tint = DietGreen, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Text("Add Custom Food", fontSize = 16.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Icon(Icons.Default.ChevronRight, null, tint = AppColors.onSurface.copy(alpha = 0.3f), modifier = Modifier.size(18.dp))
    }

    if (showDialog) {
        CustomFoodDialog(
            onSave = { n, q, u, c, p, carb, f ->
                onLogCustom(n, q, u, c, p, carb, f)
                showDialog = false
            },
            onDismiss = { showDialog = false }
        )
    }
}

@Composable
private fun CustomFoodDialog(
    onSave: (String, Double, ServingUnit, Double, Double, Double, Double) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    var quantity by remember { mutableStateOf("1") }
    var selectedUnit by remember { mutableStateOf(ServingUnit.G) }
    var calories by remember { mutableStateOf("") }
    var protein by remember { mutableStateOf("0") }
    var carbs by remember { mutableStateOf("0") }
    var fat by remember { mutableStateOf("0") }

    val isValid = name.isNotBlank() && calories.toDoubleOrNull() != null && quantity.toDoubleOrNull() != null

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Custom Food") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Food name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = quantity, onValueChange = { quantity = it }, label = { Text("Qty") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                    var showUnitPicker by remember { mutableStateOf(false) }
                    Box {
                        OutlinedButton(onClick = { showUnitPicker = true }, modifier = Modifier.height(56.dp)) {
                            Text(selectedUnit.displayName)
                        }
                        DropdownMenu(expanded = showUnitPicker, onDismissRequest = { showUnitPicker = false }) {
                            ServingUnit.values().forEach { unit ->
                                DropdownMenuItem(text = { Text(unit.displayName) }, onClick = { selectedUnit = unit; showUnitPicker = false })
                            }
                        }
                    }
                }
                OutlinedTextField(value = calories, onValueChange = { calories = it }, label = { Text("Calories") }, suffix = { Text("cal") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = protein, onValueChange = { protein = it }, label = { Text("Protein") }, suffix = { Text("g") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                    OutlinedTextField(value = carbs, onValueChange = { carbs = it }, label = { Text("Carbs") }, suffix = { Text("g") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                    OutlinedTextField(value = fat, onValueChange = { fat = it }, label = { Text("Fat") }, suffix = { Text("g") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    onSave(
                        name,
                        quantity.toDoubleOrNull() ?: 1.0,
                        selectedUnit,
                        calories.toDoubleOrNull() ?: 0.0,
                        protein.toDoubleOrNull() ?: 0.0,
                        carbs.toDoubleOrNull() ?: 0.0,
                        fat.toDoubleOrNull() ?: 0.0
                    )
                },
                enabled = isValid
            ) { Text("Save", color = if (isValid) DietGreen else Color.Gray) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

// ─────────────────────────────────────
// MARK: - Search Empty State
// ─────────────────────────────────────

@Composable
private fun SearchEmptyState() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 80.dp, bottom = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(Icons.Default.Search, null, tint = AppColors.onSurface.copy(alpha = 0.3f), modifier = Modifier.size(48.dp))
        Text("No foods found", fontSize = 16.sp, fontWeight = FontWeight.Medium, color = AppColors.onSurface.copy(alpha = 0.5f))
        Text("Try a different search term", fontSize = 14.sp, color = AppColors.onSurface.copy(alpha = 0.4f))
    }
}

// ─────────────────────────────────────
// MARK: - FoodQuantitySheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodQuantitySheet(
    food: FoodItem,
    mealType: MealType,
    isFavorite: Boolean,
    onToggleFavorite: () -> Unit,
    onLog: (Double) -> Unit,
    onDismiss: () -> Unit
) {
    var quantity by remember { mutableStateOf(1.0) }
    var isLogging by remember { mutableStateOf(false) }

    val adjustedCalories = (food.calories * quantity).toInt()
    val adjustedProtein = (food.proteinG * quantity).toInt()
    val adjustedCarbs = (food.carbsG * quantity).toInt()
    val adjustedFat = (food.fatG * quantity).toInt()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = AppColors.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Title
            Text(
                "Adjust Quantity",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center
            )

            // Food header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Box(
                    modifier = Modifier.size(60.dp).clip(RoundedCornerShape(14.dp)).background(DietGreen.copy(alpha = 0.1f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(food.categoryEnum.icon, fontSize = 36.sp)
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(food.name, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
                    Text("${food.displayServingSize} per serving", fontSize = 14.sp, color = AppColors.onSurface.copy(alpha = 0.5f))
                }
                IconButton(onClick = onToggleFavorite) {
                    Icon(
                        if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                        "Favorite",
                        tint = if (isFavorite) Color(0xFFFF2D55) else AppColors.onSurface.copy(alpha = 0.4f),
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            // Quantity Stepper
            Column(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(
                    if (isSystemInDarkTheme()) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)
                ).padding(vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("Servings", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.onSurface.copy(alpha = 0.5f))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    IconButton(
                        onClick = { if (quantity > 0.5) quantity -= 0.5 },
                        enabled = quantity > 0.5
                    ) {
                        Icon(
                            Icons.Default.RemoveCircle, "Decrease",
                            tint = if (quantity > 0.5) DietGreen else AppColors.onSurface.copy(alpha = 0.3f),
                            modifier = Modifier.size(40.dp)
                        )
                    }
                    Text(
                        text = if (quantity % 1.0 == 0.0) "${quantity.toInt()}" else String.format("%.1f", quantity),
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.defaultMinSize(minWidth = 60.dp),
                        textAlign = TextAlign.Center
                    )
                    IconButton(
                        onClick = { if (quantity < 10.0) quantity += 0.5 },
                        enabled = quantity < 10.0
                    ) {
                        Icon(
                            Icons.Default.AddCircle, "Increase",
                            tint = if (quantity < 10.0) DietGreen else AppColors.onSurface.copy(alpha = 0.3f),
                            modifier = Modifier.size(40.dp)
                        )
                    }
                }
            }

            // Nutrition Preview
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                NutritionPill("Cal", "$adjustedCalories", Color(0xFFFF9500), Modifier.weight(1f))
                NutritionPill("Protein", "${adjustedProtein}g", Color(0xFFFF6B6B), Modifier.weight(1f))
                NutritionPill("Carbs", "${adjustedCarbs}g", Color(0xFF4ECDC4), Modifier.weight(1f))
                NutritionPill("Fat", "${adjustedFat}g", Color(0xFFFFD93D), Modifier.weight(1f))
            }

            // Log Button
            Button(
                onClick = {
                    isLogging = true
                    onLog(quantity)
                },
                modifier = Modifier.fillMaxWidth().height(54.dp),
                colors = ButtonDefaults.buttonColors(containerColor = DietGreen),
                shape = RoundedCornerShape(14.dp),
                enabled = !isLogging
            ) {
                if (isLogging) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp))
                } else {
                    Icon(Icons.Default.AddCircle, null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Log Food", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun NutritionPill(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.clip(RoundedCornerShape(12.dp)).background(color.copy(alpha = 0.1f)).padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(value, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = color)
        Text(label, fontSize = 11.sp, color = AppColors.onSurface.copy(alpha = 0.5f))
    }
}
