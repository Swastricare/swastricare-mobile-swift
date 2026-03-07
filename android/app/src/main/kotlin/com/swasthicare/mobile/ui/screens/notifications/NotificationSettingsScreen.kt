package com.swasthicare.mobile.ui.screens.notifications

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.AppColors
import com.swasthicare.mobile.ui.theme.PrimaryColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(
    viewModel: NotificationSettingsViewModel = viewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            topBar = {
                CenterAlignedTopAppBar(
                    title = {
                        Text(
                            "Notification Settings",
                            fontWeight = FontWeight.Bold,
                            color = AppColors.onBackground
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                tint = AppColors.onBackground
                            )
                        }
                    },
                    colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                        containerColor = Color.Transparent
                    ),
                    windowInsets = WindowInsets(0, 0, 0, 0)
                )
            }
        ) { padding ->
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(bottom = 32.dp)
            ) {
                // ── Hydration ──
                item {
                    NotifSectionContainer(title = "Hydration Reminders") {
                        NotifToggleRow(
                            icon = Icons.Default.WaterDrop,
                            label = "Enable Hydration Reminders",
                            checked = uiState.hydrationEnabled,
                            onCheckedChange = { viewModel.setHydrationEnabled(it) }
                        )
                        if (uiState.hydrationEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            FrequencySelector(
                                label = "Reminder Frequency",
                                selectedMinutes = uiState.hydrationIntervalMinutes,
                                options = listOf(30, 60, 120, 180),
                                optionLabels = listOf("30 min", "1 hour", "2 hours", "3 hours"),
                                onSelected = { viewModel.setHydrationInterval(it) }
                            )
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TimeRow(
                                label = "Quiet Hours Start",
                                hour = uiState.quietStart,
                                onHourChange = { viewModel.setQuietStart(it) }
                            )
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TimeRow(
                                label = "Quiet Hours End",
                                hour = uiState.quietEnd,
                                onHourChange = { viewModel.setQuietEnd(it) }
                            )
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testHydration() })
                        }
                    }
                }

                // ── Medication ──
                item {
                    NotifSectionContainer(title = "Medication Reminders") {
                        NotifToggleRow(
                            icon = Icons.Default.Medication,
                            label = "Enable Medication Reminders",
                            checked = uiState.medicationEnabled,
                            onCheckedChange = { viewModel.setMedicationEnabled(it) }
                        )
                        if (uiState.medicationEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testMedication() })
                        }
                    }
                }

                // ── Diet ──
                item {
                    NotifSectionContainer(title = "Diet Reminders") {
                        NotifToggleRow(
                            icon = Icons.Default.Restaurant,
                            label = "Enable Diet Reminders",
                            checked = uiState.dietEnabled,
                            onCheckedChange = { viewModel.setDietEnabled(it) }
                        )
                        if (uiState.dietEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            MealTimeRow("Breakfast", uiState.breakfastHour, uiState.breakfastMinute) { h, m ->
                                viewModel.setBreakfastTime(h, m)
                            }
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            MealTimeRow("Lunch", uiState.lunchHour, uiState.lunchMinute) { h, m ->
                                viewModel.setLunchTime(h, m)
                            }
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            MealTimeRow("Dinner", uiState.dinnerHour, uiState.dinnerMinute) { h, m ->
                                viewModel.setDinnerTime(h, m)
                            }
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testDiet() })
                        }
                    }
                }

                // ── Cycle ──
                item {
                    NotifSectionContainer(title = "Cycle Reminders") {
                        NotifToggleRow(
                            icon = Icons.Default.Favorite,
                            label = "Enable Cycle Reminders",
                            checked = uiState.cycleEnabled,
                            onCheckedChange = { viewModel.setCycleEnabled(it) }
                        )
                        if (uiState.cycleEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testCycle() })
                        }
                    }
                }

                // ── Appointments ──
                item {
                    NotifSectionContainer(title = "Appointment Reminders") {
                        NotifToggleRow(
                            icon = Icons.Default.CalendarMonth,
                            label = "Enable Appointment Reminders",
                            checked = uiState.appointmentEnabled,
                            onCheckedChange = { viewModel.setAppointmentEnabled(it) }
                        )
                        if (uiState.appointmentEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            Text(
                                "Reminders 24 hours and 1 hour before each appointment.",
                                style = MaterialTheme.typography.bodySmall,
                                color = AppColors.onSurfaceVariant
                            )
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testAppointment() })
                        }
                    }
                }

                // ── Activity ──
                item {
                    NotifSectionContainer(title = "Activity Reminders") {
                        NotifToggleRow(
                            icon = Icons.AutoMirrored.Filled.DirectionsRun,
                            label = "Enable Activity Reminders",
                            checked = uiState.activityEnabled,
                            onCheckedChange = { viewModel.setActivityEnabled(it) }
                        )
                        if (uiState.activityEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            Text(
                                "Checked daily at 6pm if you're behind on your step goal.",
                                style = MaterialTheme.typography.bodySmall,
                                color = AppColors.onSurfaceVariant
                            )
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testActivity() })
                        }
                    }
                }

                // ── AI Health Coach ──
                item {
                    NotifSectionContainer(title = "AI Health Coach") {
                        NotifToggleRow(
                            icon = Icons.Default.AutoAwesome,
                            label = "Enable AI Nudges",
                            checked = uiState.aiNudgeEnabled,
                            onCheckedChange = { viewModel.setAiNudgeEnabled(it) }
                        )
                        if (uiState.aiNudgeEnabled) {
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            Text(
                                "Personalized AI messages based on your health patterns.",
                                style = MaterialTheme.typography.bodySmall,
                                color = AppColors.onSurfaceVariant
                            )
                            HorizontalDivider(
                                Modifier.padding(vertical = 8.dp),
                                color = AppColors.onSurface.copy(alpha = 0.1f)
                            )
                            TestButton(onClick = { viewModel.testAiNudge() })
                        }
                    }
                }
            }
        }
    }
}

// ── Section container matching SettingsScreen's GlassSectionContainer ──

@Composable
private fun NotifSectionContainer(
    title: String? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .glass()
            .padding(16.dp)
    ) {
        if (title != null) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface.copy(alpha = 0.7f),
                modifier = Modifier.padding(bottom = 12.dp)
            )
        }
        content()
    }
}

// ── Composable helpers ──

@Composable
private fun NotifToggleRow(
    icon: ImageVector,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = PrimaryColor, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface,
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = PrimaryColor,
                uncheckedThumbColor = AppColors.outline,
                uncheckedTrackColor = AppColors.surfaceVariant,
                uncheckedBorderColor = Color.Transparent
            )
        )
    }
}

@Composable
private fun FrequencySelector(
    label: String,
    selectedMinutes: Int,
    options: List<Int>,
    optionLabels: List<String>,
    onSelected: (Int) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            options.forEachIndexed { index, minutes ->
                FilterChip(
                    selected = selectedMinutes == minutes,
                    onClick = { onSelected(minutes) },
                    label = { Text(optionLabels[index], style = MaterialTheme.typography.labelSmall) }
                )
            }
        }
    }
}

@Composable
private fun TimeRow(
    label: String,
    hour: Int,
    onHourChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.weight(1f))
        Text(
            formatHour(hour),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = PrimaryColor
        )
        // Simple increment/decrement
        IconButton(onClick = { onHourChange((hour - 1 + 24) % 24) }, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.Remove, contentDescription = "Decrease", modifier = Modifier.size(16.dp))
        }
        IconButton(onClick = { onHourChange((hour + 1) % 24) }, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.Add, contentDescription = "Increase", modifier = Modifier.size(16.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MealTimeRow(
    mealName: String,
    hour: Int,
    minute: Int,
    onTimeChange: (Int, Int) -> Unit
) {
    var showPicker by remember { mutableStateOf(false) }
    val timePickerState = rememberTimePickerState(initialHour = hour, initialMinute = minute, is24Hour = false)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { showPicker = true },
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(mealName, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Text(
            String.format("%02d:%02d", hour, minute),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = PrimaryColor
        )
        Spacer(Modifier.width(4.dp))
        Icon(Icons.Default.Edit, contentDescription = "Edit time", modifier = Modifier.size(16.dp), tint = PrimaryColor)
    }

    if (showPicker) {
        AlertDialog(
            onDismissRequest = { showPicker = false },
            title = { Text("$mealName Time") },
            text = { TimePicker(state = timePickerState) },
            confirmButton = {
                TextButton(onClick = {
                    onTimeChange(timePickerState.hour, timePickerState.minute)
                    showPicker = false
                }) { Text("Set") }
            },
            dismissButton = {
                TextButton(onClick = { showPicker = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun TestButton(onClick: () -> Unit) {
    TextButton(onClick = onClick) {
        Icon(Icons.Default.Notifications, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(modifier = Modifier.width(4.dp))
        Text("Send Test Notification")
    }
}

private fun formatHour(hour: Int): String {
    val period = if (hour < 12) "AM" else "PM"
    val displayHour = when {
        hour == 0 -> 12
        hour > 12 -> hour - 12
        else -> hour
    }
    return "$displayHour:00 $period"
}
