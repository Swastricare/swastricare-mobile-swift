package com.swasthicare.mobile.ui.screens.notifications

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.ui.screens.profile.SectionContainer
import com.swasthicare.mobile.ui.theme.PrimaryColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(
    viewModel: NotificationSettingsViewModel = viewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Notification Settings", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // ── Hydration ──
            SectionContainer(title = "Hydration Reminders") {
                ToggleRow(
                    icon = Icons.Default.WaterDrop,
                    label = "Enable Hydration Reminders",
                    checked = uiState.hydrationEnabled,
                    onCheckedChange = { viewModel.setHydrationEnabled(it) }
                )

                if (uiState.hydrationEnabled) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    FrequencySelector(
                        label = "Reminder Frequency",
                        selectedMinutes = uiState.hydrationIntervalMinutes,
                        options = listOf(30, 60, 120, 180),
                        optionLabels = listOf("30 min", "1 hour", "2 hours", "3 hours"),
                        onSelected = { viewModel.setHydrationInterval(it) }
                    )
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    TimeRow(
                        label = "Quiet Hours Start",
                        hour = uiState.quietStart,
                        onHourChange = { viewModel.setQuietStart(it) }
                    )
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    TimeRow(
                        label = "Quiet Hours End",
                        hour = uiState.quietEnd,
                        onHourChange = { viewModel.setQuietEnd(it) }
                    )
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    TestButton(onClick = { viewModel.testHydration() })
                }
            }

            // ── Medication ──
            SectionContainer(title = "Medication Reminders") {
                ToggleRow(
                    icon = Icons.Default.Medication,
                    label = "Enable Medication Reminders",
                    checked = uiState.medicationEnabled,
                    onCheckedChange = { viewModel.setMedicationEnabled(it) }
                )
                if (uiState.medicationEnabled) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    TestButton(onClick = { viewModel.testMedication() })
                }
            }

            // ── Diet ──
            SectionContainer(title = "Diet Reminders") {
                ToggleRow(
                    icon = Icons.Default.Restaurant,
                    label = "Enable Diet Reminders",
                    checked = uiState.dietEnabled,
                    onCheckedChange = { viewModel.setDietEnabled(it) }
                )

                if (uiState.dietEnabled) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    MealTimeRow("Breakfast", uiState.breakfastHour, uiState.breakfastMinute) { h, m ->
                        viewModel.setBreakfastTime(h, m)
                    }
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    MealTimeRow("Lunch", uiState.lunchHour, uiState.lunchMinute) { h, m ->
                        viewModel.setLunchTime(h, m)
                    }
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    MealTimeRow("Dinner", uiState.dinnerHour, uiState.dinnerMinute) { h, m ->
                        viewModel.setDinnerTime(h, m)
                    }
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    TestButton(onClick = { viewModel.testDiet() })
                }
            }

            // ── Cycle ──
            SectionContainer(title = "Cycle Reminders") {
                ToggleRow(
                    icon = Icons.Default.Favorite,
                    label = "Enable Cycle Reminders",
                    checked = uiState.cycleEnabled,
                    onCheckedChange = { viewModel.setCycleEnabled(it) }
                )
                if (uiState.cycleEnabled) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    TestButton(onClick = { viewModel.testCycle() })
                }
            }

            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

// ── Composable helpers ──

@Composable
private fun ToggleRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
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
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = androidx.compose.ui.graphics.Color.White,
                checkedTrackColor = PrimaryColor
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

@Composable
private fun MealTimeRow(
    mealName: String,
    hour: Int,
    minute: Int,
    onTimeChange: (Int, Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(mealName, style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.weight(1f))
        Text(
            String.format("%02d:%02d", hour, minute),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = PrimaryColor
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
