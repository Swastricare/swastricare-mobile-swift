package com.swastricare.health.ui.screens.diet

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.FoodCategory
import com.swastricare.health.data.models.FoodItem
import com.swastricare.health.data.models.MealType
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.delay

// ─────────────────────────────────────
// MARK: - FoodSearchScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodSearchScreen(
    mealTypeDb: String,
    onFoodSelected: (FoodItem) -> Unit,
    onDismiss: () -> Unit
) {
    val vm: DietViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()

    var searchText by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf<FoodCategory?>(null) }
    var selectedFoodForQuantity by remember { mutableStateOf<FoodItem?>(null) }
    val mealType = remember { MealType.fromDb(mealTypeDb) }

    // Debounce: wait 250ms after the last keystroke before re-running the
    // (potentially expensive) fuzzy-scoring search across the food cache.
    // The TextField stays responsive because `searchText` updates immediately;
    // only `debouncedQuery` (which the search reads) lags.
    var debouncedQuery by remember { mutableStateOf("") }
    LaunchedEffect(searchText) {
        delay(250)
        debouncedQuery = searchText
    }

    val filteredFoods = remember(debouncedQuery, selectedCategory, uiState.foodItemsCache) {
        var foods = if (debouncedQuery.isNotBlank()) vm.searchFoods(debouncedQuery) else uiState.foodItemsCache
        selectedCategory?.let { cat -> foods = foods.filter { it.category == cat.dbValue } }
        foods
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
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                windowInsets = WindowInsets(0, 0, 0, 0)
            )
        },
        containerColor = AppColors.surface
    ) { innerPadding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(innerPadding)
        ) {
            // Category filter chips
            CategoryFilterRow(
                selectedCategory = selectedCategory,
                onCategorySelected = { selectedCategory = it }
            )

            Divider(color = AppColors.onSurface.copy(alpha = 0.06f))

            // Food list or empty state
            if (filteredFoods.isEmpty()) {
                FoodSearchEmptyState(hasSearch = searchText.isNotBlank())
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 40.dp)
                ) {
                    items(filteredFoods) { food ->
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
            }
        }
    }

    // Quantity sheet
    selectedFoodForQuantity?.let { food ->
        FoodQuantitySheet(
            food = food,
            mealType = mealType,
            isFavorite = vm.isFavorite(food.id),
            onToggleFavorite = { vm.toggleFavorite(food.id) },
            onLog = { quantity ->
                vm.logFood(food, quantity * food.servingSize, mealType)
                selectedFoodForQuantity = null
                onDismiss()
            },
            onDismiss = { selectedFoodForQuantity = null }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Category Filter Row
// ─────────────────────────────────────

@Composable
private fun CategoryFilterRow(
    selectedCategory: FoodCategory?,
    onCategorySelected: (FoodCategory?) -> Unit
) {
    val isDark = isSystemInDarkTheme()

    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.surface),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // "All" chip
        item {
            FilterChipItem(
                label = "All",
                icon = null,
                isSelected = selectedCategory == null,
                onClick = { onCategorySelected(null) }
            )
        }
        items(FoodCategory.values()) { category ->
            FilterChipItem(
                label = category.displayName,
                icon = category.icon,
                isSelected = selectedCategory == category,
                onClick = { onCategorySelected(category) }
            )
        }
    }
}

@Composable
private fun FilterChipItem(
    label: String,
    icon: String?,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val bg = if (isSelected) DietGreen.copy(alpha = 0.15f)
             else if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)
    val textColor = if (isSelected) DietGreen else AppColors.onSurface

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onClick() }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        if (icon != null) {
            Text(icon, fontSize = 12.sp)
        }
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = textColor
        )
    }
}

// ─────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────

@Composable
private fun FoodSearchEmptyState(hasSearch: Boolean) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.Search, null,
            tint = AppColors.onSurface.copy(alpha = 0.25f),
            modifier = Modifier.size(60.dp)
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "No foods found",
            style = MaterialTheme.typography.titleMedium,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
        if (hasSearch) {
            Spacer(Modifier.height(8.dp))
            Text(
                "Try a different search term",
                fontSize = 14.sp,
                color = AppColors.onSurface.copy(alpha = 0.4f)
            )
        }
    }
}
