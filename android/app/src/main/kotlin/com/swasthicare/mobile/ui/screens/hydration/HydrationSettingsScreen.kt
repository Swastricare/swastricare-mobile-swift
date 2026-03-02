package com.swasthicare.mobile.ui.screens.hydration

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.ActivityLevel
import com.swasthicare.mobile.data.models.HydrationCalculator
import com.swasthicare.mobile.data.models.HydrationPreferences
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass

private val HydrationCyan = Color(0xFF00BCD4)

@Composable
fun HydrationSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToNotifications: () -> Unit
) {
    val vm = remember { AppContainer.hydrationViewModel }
    val uiState by vm.uiState.collectAsState()
    val prefs = uiState.preferences

    // Local editable state initialized from current preferences
    var weightText by remember(prefs) { mutableStateOf(prefs.weightKg?.toString() ?: "") }
    var selectedActivity by remember(prefs) { mutableStateOf(prefs.activityLevelEnum) }
    var customGoalText by remember(prefs) { mutableStateOf(prefs.customGoalMl?.toString() ?: "") }
    var useCustomGoal by remember(prefs) { mutableStateOf(prefs.customGoalMl != null) }
    var useWeatherAdjustment by remember { mutableStateOf(uiState.weatherAdjustmentFactor > 1.0 || uiState.weatherData != null) }
    var showAboutCalculation by remember { mutableStateOf(false) }
    var hasChanges by remember { mutableStateOf(false) }
    var showSavedSnackbar by remember { mutableStateOf(false) }

    // Calculate preview goal based on current form state
    val previewGoal = remember(weightText, selectedActivity, customGoalText, useCustomGoal) {
        val tempPrefs = HydrationPreferences(
            activityLevel = selectedActivity.dbValue,
            weightKg = weightText.toDoubleOrNull(),
            customGoalMl = if (useCustomGoal) customGoalText.toIntOrNull() else null
        )
        HydrationCalculator.calculateGoal(tempPrefs)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.Default.ArrowBack, "Back", tint = MaterialTheme.colorScheme.onSurface)
                }
                Text(
                    "Hydration Settings",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                // Save button
                TextButton(
                    onClick = {
                        val newPrefs = HydrationPreferences(
                            activityLevel = selectedActivity.dbValue,
                            weightKg = weightText.toDoubleOrNull(),
                            customGoalMl = if (useCustomGoal) customGoalText.toIntOrNull() else null
                        )
                        vm.updatePreferences(newPrefs)
                        hasChanges = false
                        showSavedSnackbar = true
                    },
                    enabled = hasChanges
                ) {
                    Text(
                        "Save",
                        fontWeight = FontWeight.Bold,
                        color = if (hasChanges) HydrationCyan else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                    )
                }
            }

            // ── Content ──
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Goal Preview Card
                item {
                    GoalPreviewCard(goalMl = previewGoal.dailyGoalMl, breakdown = previewGoal.breakdown)
                }

                // Body Stats Section
                item {
                    SettingsSection(title = "Body Stats", icon = Icons.Default.MonitorWeight) {
                        // Weight
                        SettingsTextField(
                            label = "Weight",
                            value = weightText,
                            onValueChange = { weightText = it; hasChanges = true },
                            suffix = "kg",
                            keyboardType = KeyboardType.Decimal,
                            placeholder = "e.g. 70"
                        )
                    }
                }

                // Activity Level Section
                item {
                    SettingsSection(title = "Activity Level", icon = Icons.Default.DirectionsRun) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            ActivityLevel.entries.forEach { level ->
                                ActivityLevelOption(
                                    level = level,
                                    isSelected = selectedActivity == level,
                                    onSelect = { selectedActivity = level; hasChanges = true }
                                )
                            }
                        }
                    }
                }

                // Custom Goal Section
                item {
                    SettingsSection(title = "Daily Goal", icon = Icons.Default.Flag) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    "Use custom goal",
                                    style = MaterialTheme.typography.bodyLarge
                                )
                                Switch(
                                    checked = useCustomGoal,
                                    onCheckedChange = { useCustomGoal = it; hasChanges = true },
                                    colors = SwitchDefaults.colors(checkedTrackColor = HydrationCyan)
                                )
                            }
                            AnimatedVisibility(
                                visible = useCustomGoal,
                                enter = expandVertically(),
                                exit = shrinkVertically()
                            ) {
                                SettingsTextField(
                                    label = "Custom Goal",
                                    value = customGoalText,
                                    onValueChange = { customGoalText = it; hasChanges = true },
                                    suffix = "ml",
                                    keyboardType = KeyboardType.Number,
                                    placeholder = "e.g. 3000"
                                )
                            }
                            if (!useCustomGoal) {
                                Text(
                                    "Auto-calculated: ${previewGoal.dailyGoalMl}ml (${previewGoal.breakdown.description})",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                                )
                            }
                        }
                    }
                }

                // Weather Adjustment Section
                item {
                    SettingsSection(title = "Weather Adjustment", icon = Icons.Default.WbSunny) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text("Adjust for hot weather", style = MaterialTheme.typography.bodyLarge)
                                    Text(
                                        "Increases goal when temperature exceeds 30°C",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                                    )
                                }
                                Switch(
                                    checked = useWeatherAdjustment,
                                    onCheckedChange = { useWeatherAdjustment = it },
                                    colors = SwitchDefaults.colors(checkedTrackColor = HydrationCyan)
                                )
                            }
                            if (uiState.weatherData != null) {
                                val weather = uiState.weatherData!!
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(HydrationCyan.copy(alpha = 0.08f))
                                        .padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Text("🌡️", fontSize = 18.sp)
                                    Column {
                                        Text(
                                            "${weather.city}: ${weather.temperatureCelsius.toInt()}°C",
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Medium
                                        )
                                        if (uiState.isWeatherAdjusted) {
                                            Text(
                                                "Goal increased by ${((uiState.weatherAdjustmentFactor - 1.0) * 100).toInt()}%",
                                                fontSize = 12.sp,
                                                color = Color(0xFFFF9500)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Notifications Section
                item {
                    SettingsSection(title = "Notifications", icon = Icons.Default.Notifications) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .clickable { onNavigateToNotifications() }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Hydration Reminder Settings", style = MaterialTheme.typography.bodyLarge)
                            Icon(
                                Icons.Default.ChevronRight, null,
                                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                            )
                        }
                    }
                }

                // About Calculation Section
                item {
                    SettingsSection(
                        title = "About the Calculation",
                        icon = Icons.Default.Info,
                        collapsible = true,
                        isExpanded = showAboutCalculation,
                        onToggle = { showAboutCalculation = !showAboutCalculation }
                    ) {
                        AnimatedVisibility(
                            visible = showAboutCalculation,
                            enter = expandVertically(),
                            exit = shrinkVertically()
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                AboutItem("Base formula", "33ml × body weight (kg)")
                                AboutItem("Activity multiplier", "Sedentary (0.9×) → High (1.15×) → Outdoor (1.2×)")
                                AboutItem("Weather adjustment", "+20% when temperature exceeds 30°C")
                                AboutItem("Custom goal", "Overrides all calculations when set")
                            }
                        }
                    }
                }

                // Bottom spacing
                item { Spacer(Modifier.height(100.dp)) }
            }
        }

        // Saved snackbar
        if (showSavedSnackbar) {
            LaunchedEffect(Unit) {
                kotlinx.coroutines.delay(2000)
                showSavedSnackbar = false
            }
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp),
                containerColor = HydrationCyan,
                contentColor = Color.White
            ) {
                Text("Settings saved")
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Goal Preview Card
// ─────────────────────────────────────

@Composable
private fun GoalPreviewCard(goalMl: Int, breakdown: com.swasthicare.mobile.data.models.HydrationGoal.GoalBreakdown) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp, opacity = 0.6f)
            .padding(20.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Daily Goal", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            Text(
                "${goalMl}ml",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = HydrationCyan
            )
            Text(
                breakdown.description,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Settings Section Card
// ─────────────────────────────────────

@Composable
private fun SettingsSection(
    title: String,
    icon: ImageVector,
    collapsible: Boolean = false,
    isExpanded: Boolean = true,
    onToggle: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val sectionBg = if (isSystemInDarkTheme()) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(sectionBg)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(if (collapsible) Modifier.clickable { onToggle?.invoke() } else Modifier),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(icon, null, tint = HydrationCyan, modifier = Modifier.size(20.dp))
            Text(
                title,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            if (collapsible) {
                Icon(
                    if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    "Toggle",
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        content()
    }
}

// ─────────────────────────────────────
// MARK: - Settings Text Field
// ─────────────────────────────────────

@Composable
private fun SettingsTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    suffix: String,
    keyboardType: KeyboardType = KeyboardType.Number,
    placeholder: String = ""
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.width(80.dp))
        OutlinedTextField(
            value = value,
            onValueChange = { newVal ->
                onValueChange(newVal.filter { it.isDigit() || it == '.' })
            },
            placeholder = { Text(placeholder, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)) },
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            singleLine = true,
            modifier = Modifier.weight(1f),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = HydrationCyan,
                cursorColor = HydrationCyan
            )
        )
        Text(suffix, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
    }
}

// ─────────────────────────────────────
// MARK: - Activity Level Option
// ─────────────────────────────────────

@Composable
private fun ActivityLevelOption(
    level: ActivityLevel,
    isSelected: Boolean,
    onSelect: () -> Unit
) {
    val bgColor = if (isSelected) HydrationCyan.copy(alpha = 0.15f) else Color.Transparent
    val borderColor = if (isSelected) HydrationCyan else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .clickable { onSelect() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(level.icon, fontSize = 24.sp)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                level.displayName,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) HydrationCyan else MaterialTheme.colorScheme.onSurface
            )
            Text(
                level.description,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
        if (isSelected) {
            Icon(Icons.Default.CheckCircle, null, tint = HydrationCyan, modifier = Modifier.size(20.dp))
        }
        Text(
            "${(level.multiplier * 100).toInt() - 100}%".let { if (!it.startsWith("-")) "+$it" else it },
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - About Calculation Item
// ─────────────────────────────────────

@Composable
private fun AboutItem(title: String, description: String) {
    Column {
        Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        Text(description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
    }
}
