package com.swastricare.health.ui.screens.family.member

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.data.repository.FamilyAlertPreferences
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors

private val GraceMinutesOptions = listOf(15, 30, 45, 60)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FamilyAlertPreferencesScreen(
    healthProfileId: String,
    onNavigateBack: () -> Unit,
    viewModel: FamilyAlertPreferencesViewModel = hiltViewModel(),
) {
    TrackScreen("FamilyAlertPreferences")
    val state by viewModel.state.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(healthProfileId) {
        viewModel.load(healthProfileId)
    }

    LaunchedEffect(state.saveMessage) {
        val msg = state.saveMessage
        if (msg != null) {
            snackbarHostState.showSnackbar(msg)
            viewModel.clearSaveMessage()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.White)) {
        Column(modifier = Modifier.fillMaxSize()) {
            AppTopBar(title = "Alert preferences", onBack = onNavigateBack)

            when {
                state.isLoading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = AITeal)
                    }
                }
                state.error != null && state.prefs == null -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(
                            text = state.error ?: "Failed to load",
                            color = AppColors.onBackground.copy(alpha = 0.6f),
                            modifier = Modifier.padding(24.dp),
                        )
                    }
                }
                state.prefs != null -> {
                    val prefs = state.prefs!!
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                            .padding(bottom = 16.dp),
                    ) {
                        AlertsSection(
                            prefs = prefs,
                            onToggleMissedMed = { v -> viewModel.update { it.copy(missedMedicationAlerts = v) } },
                            onToggleLowHydration = { v -> viewModel.update { it.copy(lowHydrationAlerts = v) } },
                            onToggleMissedVitals = { v -> viewModel.update { it.copy(missedVitalsAlerts = v) } },
                            onToggleCustomNudge = { v -> viewModel.update { it.copy(customNudgeAlerts = v) } },
                        )

                        QuietHoursSection(
                            startTime = prefs.quietHoursStart,
                            endTime = prefs.quietHoursEnd,
                            onPickStart = { hhmmss -> viewModel.update { it.copy(quietHoursStart = hhmmss) } },
                            onPickEnd = { hhmmss -> viewModel.update { it.copy(quietHoursEnd = hhmmss) } },
                            onClear = {
                                viewModel.update { it.copy(quietHoursStart = null, quietHoursEnd = null) }
                            },
                        )

                        GracePeriodSection(
                            selectedMinutes = prefs.missedMedGraceMinutes,
                            onSelect = { mins -> viewModel.update { it.copy(missedMedGraceMinutes = mins) } },
                        )

                        Spacer(Modifier.height(96.dp))
                    }

                    // Sticky save bar
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.White),
                    ) {
                        HorizontalDivider(
                            color = AppColors.onBackground.copy(alpha = 0.06f),
                            thickness = 0.5.dp,
                        )
                        Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                            Button(
                                onClick = { viewModel.save() },
                                enabled = !state.isSaving,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(52.dp),
                                shape = RoundedCornerShape(14.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = AITeal,
                                    contentColor = Color.White,
                                    disabledContainerColor = AITeal.copy(alpha = 0.5f),
                                    disabledContentColor = Color.White.copy(alpha = 0.8f),
                                ),
                            ) {
                                if (state.isSaving) {
                                    CircularProgressIndicator(
                                        color = Color.White,
                                        strokeWidth = 2.dp,
                                        modifier = Modifier.size(20.dp),
                                    )
                                } else {
                                    Text(
                                        "Save changes",
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 88.dp),
        ) { data ->
            Snackbar(
                snackbarData = data,
                containerColor = AppColors.onBackground,
                contentColor = Color.White,
            )
        }
    }
}

// ── Sections ────────────────────────────────────────────────────────────────

@Composable
private fun AlertsSection(
    prefs: FamilyAlertPreferences,
    onToggleMissedMed: (Boolean) -> Unit,
    onToggleLowHydration: (Boolean) -> Unit,
    onToggleMissedVitals: (Boolean) -> Unit,
    onToggleCustomNudge: (Boolean) -> Unit,
) {
    SectionLabel("Alerts I want to receive")
    SectionCard {
        ToggleListItem(
            title = "Missed medication",
            subtitle = "Get notified when a dose is missed",
            checked = prefs.missedMedicationAlerts,
            onToggle = onToggleMissedMed,
        )
        RowDivider()
        ToggleListItem(
            title = "Low hydration",
            subtitle = "Get notified if hydration is low today",
            checked = prefs.lowHydrationAlerts,
            onToggle = onToggleLowHydration,
        )
        RowDivider()
        ToggleListItem(
            title = "Missed vitals",
            subtitle = "Get notified if vitals haven't been logged today",
            checked = prefs.missedVitalsAlerts,
            onToggle = onToggleMissedVitals,
        )
        RowDivider()
        ToggleListItem(
            title = "Custom nudges",
            subtitle = "Get notified for direct nudges from family",
            checked = prefs.customNudgeAlerts,
            onToggle = onToggleCustomNudge,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuietHoursSection(
    startTime: String?,
    endTime: String?,
    onPickStart: (String) -> Unit,
    onPickEnd: (String) -> Unit,
    onClear: () -> Unit,
) {
    SectionLabel("Quiet hours")
    Text(
        text = "Don't send non-critical alerts during this window. Critical alerts (missed medication) still come through.",
        fontSize = 12.sp,
        color = AppColors.onBackground.copy(alpha = 0.55f),
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
    )

    var showStartPicker by remember { mutableStateOf(false) }
    var showEndPicker by remember { mutableStateOf(false) }

    SectionCard {
        TimeListItem(
            label = "From",
            value = formatDisplayTime(startTime),
            onClick = { showStartPicker = true },
        )
        RowDivider()
        TimeListItem(
            label = "To",
            value = formatDisplayTime(endTime),
            onClick = { showEndPicker = true },
        )
        if (startTime != null || endTime != null) {
            RowDivider()
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onClear() }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Clear quiet hours",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.error,
                )
            }
        }
    }

    if (showStartPicker) {
        val (initH, initM) = parseHourMinute(startTime) ?: (22 to 0)
        TimePickerSheet(
            title = "Quiet hours — From",
            initialHour = initH,
            initialMinute = initM,
            onConfirm = { h, m ->
                onPickStart(formatHHmmss(h, m))
                showStartPicker = false
            },
            onDismiss = { showStartPicker = false },
        )
    }
    if (showEndPicker) {
        val (initH, initM) = parseHourMinute(endTime) ?: (7 to 0)
        TimePickerSheet(
            title = "Quiet hours — To",
            initialHour = initH,
            initialMinute = initM,
            onConfirm = { h, m ->
                onPickEnd(formatHHmmss(h, m))
                showEndPicker = false
            },
            onDismiss = { showEndPicker = false },
        )
    }
}

@Composable
private fun GracePeriodSection(
    selectedMinutes: Int,
    onSelect: (Int) -> Unit,
) {
    SectionLabel("Missed medication grace period")
    Text(
        text = "How long after a scheduled dose before it counts as missed.",
        fontSize = 12.sp,
        color = AppColors.onBackground.copy(alpha = 0.55f),
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        GraceMinutesOptions.forEach { mins ->
            val selected = mins == selectedMinutes
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (selected) AITeal else Color.White)
                    .border(
                        width = 1.dp,
                        color = if (selected) AITeal else AppColors.onBackground.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(12.dp),
                    )
                    .clickable { onSelect(mins) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "$mins min",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (selected) Color.White else AppColors.onBackground.copy(alpha = 0.75f),
                )
            }
        }
    }
}

// ── Reusable bits ───────────────────────────────────────────────────────────

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text.uppercase(),
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.8.sp,
        color = AppColors.onBackground.copy(alpha = 0.4f),
        modifier = Modifier.padding(start = 24.dp, top = 24.dp, bottom = 8.dp),
    )
}

@Composable
private fun SectionCard(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(
                width = 1.dp,
                color = Color(0xFFE6E8EB),
                shape = RoundedCornerShape(16.dp),
            ),
    ) {
        content()
    }
}

@Composable
private fun RowDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 16.dp),
        thickness = 0.5.dp,
        color = AppColors.onBackground.copy(alpha = 0.06f),
    )
}

@Composable
private fun ToggleListItem(
    title: String,
    subtitle: String,
    checked: Boolean,
    onToggle: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onBackground,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                subtitle,
                fontSize = 12.sp,
                color = AppColors.onBackground.copy(alpha = 0.5f),
            )
        }
        Spacer(Modifier.width(12.dp))
        Switch(
            checked = checked,
            onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(
                checkedTrackColor = AITeal,
                checkedThumbColor = Color.White,
                checkedBorderColor = Color.Transparent,
                uncheckedTrackColor = AppColors.onBackground.copy(alpha = 0.15f),
                uncheckedThumbColor = Color.White,
                uncheckedBorderColor = Color.Transparent,
            ),
        )
    }
}

@Composable
private fun TimeListItem(
    label: String,
    value: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground,
            modifier = Modifier.weight(1f),
        )
        Text(
            value,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = AITeal,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimePickerSheet(
    title: String,
    initialHour: Int,
    initialMinute: Int,
    onConfirm: (Int, Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val tpState = rememberTimePickerState(
        initialHour = initialHour,
        initialMinute = initialMinute,
        is24Hour = false,
    )
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color.White,
        title = { Text(title, fontWeight = FontWeight.SemiBold) },
        text = {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TimePicker(state = tpState)
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(tpState.hour, tpState.minute) }) {
                Text("Set", color = AITeal, fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f))
            }
        },
    )
}

// ── Helpers ─────────────────────────────────────────────────────────────────

private fun formatHHmmss(hour: Int, minute: Int): String =
    "%02d:%02d:00".format(hour, minute)

/** Returns Pair(hour, minute) or null if string is null/unparseable. */
private fun parseHourMinute(time: String?): Pair<Int, Int>? {
    if (time.isNullOrBlank()) return null
    val parts = time.split(":")
    if (parts.size < 2) return null
    val h = parts[0].toIntOrNull() ?: return null
    val m = parts[1].toIntOrNull() ?: return null
    if (h !in 0..23 || m !in 0..59) return null
    return h to m
}

private fun formatDisplayTime(time: String?): String {
    val (h, m) = parseHourMinute(time) ?: return "Not set"
    val period = if (h < 12) "AM" else "PM"
    val displayHour = when {
        h == 0 -> 12
        h > 12 -> h - 12
        else -> h
    }
    return "%d:%02d %s".format(displayHour, m, period)
}
