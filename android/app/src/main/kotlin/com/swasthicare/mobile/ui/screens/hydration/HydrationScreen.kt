package com.swasthicare.mobile.ui.screens.hydration

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.DrinkType
import com.swasthicare.mobile.data.models.QuickAddPreset
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass

// ─────────────────────────────────────
// MARK: - HydrationScreen
// ─────────────────────────────────────

@Composable
fun HydrationScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAI: () -> Unit
) {
    val vm = remember { AppContainer.hydrationViewModel }
    val uiState by vm.uiState.collectAsState()

    val isDark = isSystemInDarkTheme()
    val secondaryBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    // Local state for custom drink input
    var selectedDrinkType by remember { mutableStateOf(DrinkType.WATER) }
    var customAmountText by remember { mutableStateOf("") }
    var showUrineGuide by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack, "Back",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    "Hydration",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                IconButton(onClick = onNavigateToAI) {
                    Icon(Icons.Default.AutoAwesome, "Ask AI", tint = HydrationCyan)
                }
            }

            // ── Content ──
            when {
                uiState.isLoading -> HydrationSkeletonContent()
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        // Calendar Strip
                        item {
                            Spacer(Modifier.height(4.dp))
                            HydrationCalendarStrip(
                                selectedDate = uiState.selectedDate,
                                onDateSelected = { vm.selectDate(it) }
                            )
                            Spacer(Modifier.height(16.dp))
                        }

                        // Weather Adjustment Banner
                        if (uiState.isWeatherAdjusted && uiState.weatherData != null) {
                            item {
                                WeatherAdjustmentBanner(
                                    temperature = uiState.weatherData!!.temperatureCelsius,
                                    city = uiState.weatherData!!.city,
                                    baseGoal = uiState.baseGoalMl,
                                    adjustedGoal = uiState.effectiveGoalMl,
                                    modifier = Modifier.padding(horizontal = 20.dp)
                                )
                                Spacer(Modifier.height(16.dp))
                            }
                        }

                        // Progress Section: Glass + Stats
                        item {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(secondaryBg)
                                    .padding(20.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(16.dp)
                            ) {
                                Text(
                                    if (uiState.isWeatherAdjusted)
                                        "Goal: ${uiState.effectiveGoalMl}ml (adjusted from ${uiState.baseGoalMl}ml)"
                                    else
                                        "Goal: ${uiState.effectiveGoalMl}ml",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                                )

                                // Water Glass
                                WaterGlassView(
                                    progress = uiState.progress,
                                    modifier = Modifier.size(180.dp)
                                )

                                // Stat Pills
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    HydrationStatPill(
                                        icon = Icons.Default.WaterDrop,
                                        iconColor = HydrationCyan,
                                        value = "${uiState.effectiveIntake}",
                                        label = "of ${uiState.effectiveGoalMl}ml",
                                        modifier = Modifier.weight(1f)
                                    )
                                    HydrationStatPill(
                                        icon = Icons.Default.ArrowUpward,
                                        iconColor = Color(0xFFFF9500),
                                        value = "${uiState.remainingMl}",
                                        label = "remaining",
                                        modifier = Modifier.weight(1f)
                                    )
                                    HydrationStatPill(
                                        icon = Icons.Default.LocalDrink,
                                        iconColor = Color(0xFF34C759),
                                        value = "${uiState.todaysEntries.size}",
                                        label = "drinks",
                                        modifier = Modifier.weight(1f)
                                    )
                                }
                            }
                            Spacer(Modifier.height(16.dp))
                        }

                        // Quick Add Section
                        item {
                            Text(
                                "Quick Add",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            LazyRow(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                contentPadding = PaddingValues(horizontal = 20.dp)
                            ) {
                                items(QuickAddPreset.defaults) { preset ->
                                    QuickAddButton(
                                        preset = preset,
                                        onClick = { vm.addDrink(selectedDrinkType, preset.amountMl) }
                                    )
                                }
                            }
                            Spacer(Modifier.height(20.dp))
                        }

                        // Drink Type Picker
                        item {
                            Text(
                                "Drink Type",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            DrinkTypePicker(
                                selectedType = selectedDrinkType,
                                onTypeSelected = { selectedDrinkType = it }
                            )
                            Spacer(Modifier.height(12.dp))
                        }

                        // Custom Amount Input
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                OutlinedTextField(
                                    value = customAmountText,
                                    onValueChange = { value ->
                                        customAmountText = value.filter { it.isDigit() }
                                    },
                                    label = { Text("Custom amount (ml)") },
                                    keyboardOptions = KeyboardOptions(
                                        keyboardType = KeyboardType.Number,
                                        imeAction = ImeAction.Done
                                    ),
                                    keyboardActions = KeyboardActions(
                                        onDone = { focusManager.clearFocus() }
                                    ),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true,
                                    shape = RoundedCornerShape(12.dp),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = HydrationCyan,
                                        cursorColor = HydrationCyan
                                    )
                                )
                                Button(
                                    onClick = {
                                        val amount = customAmountText.toIntOrNull()
                                        if (amount != null && amount > 0) {
                                            vm.addDrink(selectedDrinkType, amount)
                                            customAmountText = ""
                                            focusManager.clearFocus()
                                        }
                                    },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = HydrationCyan
                                    ),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.height(56.dp)
                                ) {
                                    Icon(Icons.Default.Add, "Add")
                                }
                            }
                            Spacer(Modifier.height(20.dp))
                        }

                        // Insights Card
                        uiState.insights?.let { insights ->
                            item {
                                HydrationInsightsCard(
                                    insights = insights,
                                    modifier = Modifier.padding(horizontal = 20.dp)
                                )
                                Spacer(Modifier.height(16.dp))
                            }
                        }

                        // Today's Entries
                        if (uiState.todaysEntries.isNotEmpty()) {
                            item {
                                Text(
                                    "Today's Drinks",
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.padding(horizontal = 20.dp)
                                )
                                Spacer(Modifier.height(8.dp))
                            }

                            item {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 20.dp)
                                        .clip(RoundedCornerShape(16.dp))
                                        .background(secondaryBg)
                                ) {
                                    uiState.todaysEntries.forEachIndexed { index, entry ->
                                        HydrationEntryCard(
                                            entry = entry,
                                            onDelete = { vm.deleteDrink(entry.id) }
                                        )
                                        if (index < uiState.todaysEntries.lastIndex) {
                                            HorizontalDivider(
                                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                                                modifier = Modifier.padding(start = 60.dp)
                                            )
                                        }
                                    }
                                }
                                Spacer(Modifier.height(16.dp))
                            }
                        } else {
                            // Empty state
                            item {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 20.dp, vertical = 24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Text("💧", fontSize = 48.sp)
                                    Text(
                                        "No drinks logged yet",
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                    Text(
                                        "Tap a Quick Add button or enter a custom amount to start tracking",
                                        fontSize = 13.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                                        textAlign = TextAlign.Center
                                    )
                                }
                                Spacer(Modifier.height(16.dp))
                            }
                        }

                        // Urine Color Guide Button
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(HydrationCyan.copy(alpha = 0.08f))
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null
                                    ) { showUrineGuide = true }
                                    .padding(vertical = 14.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Icon(
                                        Icons.Default.Colorize, null,
                                        tint = HydrationCyan,
                                        modifier = Modifier.size(18.dp)
                                    )
                                    Text(
                                        "Urine Color Guide",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = HydrationCyan
                                    )
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                        }

                        // Ask AI button
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(HydrationCyan.copy(alpha = 0.08f))
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null
                                    ) { onNavigateToAI() }
                                    .padding(vertical = 12.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Icon(
                                        Icons.Default.AutoAwesome, null,
                                        tint = HydrationCyan,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        "Ask AI about my hydration",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = HydrationCyan
                                    )
                                }
                            }
                            Spacer(Modifier.height(24.dp))
                        }
                    }
                }
            }
        }

        // Error snackbar
        uiState.error?.let { errorMsg ->
            Snackbar(
                modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                action = { TextButton(onClick = { vm.clearError() }) { Text("Dismiss") } }
            ) { Text(errorMsg) }
        }

        // Urine Color Guide Bottom Sheet
        if (showUrineGuide) {
            UrineColorGuideSheet(onDismiss = { showUrineGuide = false })
        }
    }
}
