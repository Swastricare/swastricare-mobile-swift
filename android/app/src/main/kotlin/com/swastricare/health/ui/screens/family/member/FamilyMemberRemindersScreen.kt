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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import com.swastricare.health.domain.model.MedicationWithSchedule
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors

/**
 * Family Member Reminders screen — Batch J.
 *
 * Authorised caregivers can edit two fields per schedule:
 *   • `time_of_day` (only for `schedule_type == 'daily'`)
 *   • `reminder_enabled`
 *
 * Other schedule types render read-only with a "Not editable from family
 * view" hint. Permission failures surface as a full-screen empty state.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FamilyMemberRemindersScreen(
    healthProfileId: String,
    onNavigateBack: () -> Unit,
    viewModel: FamilyMemberRemindersViewModel = hiltViewModel(),
) {
    TrackScreen("FamilyMemberReminders")
    val state by viewModel.state.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(healthProfileId) {
        viewModel.load(healthProfileId)
    }

    LaunchedEffect(state.message) {
        val msg = state.message
        if (msg != null) {
            snackbarHostState.showSnackbar(msg)
            viewModel.clearMessage()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.White)) {
        Column(modifier = Modifier.fillMaxSize()) {
            AppTopBar(title = "Reminders", onBack = onNavigateBack)

            when {
                state.isLoading -> LoadingState()
                state.permissionDenied -> PermissionDeniedState(onBack = onNavigateBack)
                state.error != null && state.schedules.isEmpty() -> ErrorState(
                    message = state.error ?: "Failed to load",
                )
                state.schedules.isEmpty() -> EmptyState()
                else -> ScheduleList(
                    schedules = state.schedules,
                    savingScheduleId = state.savingScheduleId,
                    onPickTime = { scheduleId, newTime ->
                        viewModel.updateTime(scheduleId, newTime, healthProfileId)
                    },
                    onToggleReminder = { scheduleId, enabled ->
                        viewModel.setReminderEnabled(scheduleId, enabled, healthProfileId)
                    },
                )
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

// ── States ─────────────────────────────────────────────────────────────────

@Composable
private fun LoadingState() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = AITeal)
    }
}

@Composable
private fun ErrorState(message: String) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = message,
            color = AppColors.onBackground.copy(alpha = 0.6f),
            modifier = Modifier.padding(24.dp),
        )
    }
}

@Composable
private fun EmptyState() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(32.dp),
        ) {
            Text(
                text = "No reminders to edit",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onBackground,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = "This member has no active medication schedules.",
                fontSize = 14.sp,
                color = AppColors.onBackground.copy(alpha = 0.55f),
            )
        }
    }
}

@Composable
private fun PermissionDeniedState(onBack: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(32.dp),
        ) {
            Text(
                text = "Not allowed",
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onBackground,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "You don't have edit permission for this member's reminders.",
                fontSize = 14.sp,
                color = AppColors.onBackground.copy(alpha = 0.6f),
            )
            Spacer(Modifier.height(20.dp))
            Button(
                onClick = onBack,
                colors = ButtonDefaults.buttonColors(
                    containerColor = AITeal,
                    contentColor = Color.White,
                ),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text("Go back", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

// ── List ───────────────────────────────────────────────────────────────────

@Composable
private fun ScheduleList(
    schedules: List<MedicationWithSchedule>,
    savingScheduleId: String?,
    onPickTime: (scheduleId: String, hhmmss: String) -> Unit,
    onToggleReminder: (scheduleId: String, enabled: Boolean) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            InfoBanner()
        }
        items(schedules, key = { it.scheduleId }) { schedule ->
            ScheduleCard(
                schedule = schedule,
                isSaving = savingScheduleId == schedule.scheduleId,
                onPickTime = { newTime -> onPickTime(schedule.scheduleId, newTime) },
                onToggleReminder = { enabled -> onToggleReminder(schedule.scheduleId, enabled) },
            )
        }
    }
}

@Composable
private fun InfoBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AITeal.copy(alpha = 0.08f))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Editing reminders for your family member. Changes apply on their device.",
            fontSize = 12.sp,
            color = AppColors.onBackground.copy(alpha = 0.75f),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScheduleCard(
    schedule: MedicationWithSchedule,
    isSaving: Boolean,
    onPickTime: (hhmmss: String) -> Unit,
    onToggleReminder: (Boolean) -> Unit,
) {
    val isDaily = schedule.scheduleType.equals("daily", ignoreCase = true)
    var showPicker by remember { mutableStateOf(false) }

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
            )
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = schedule.medicationName,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground,
                )
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ScheduleTypeBadge(scheduleType = schedule.scheduleType)
                    if (schedule.frequencyPerDay > 1 && isDaily) {
                        Spacer(Modifier.width(6.dp))
                        Text(
                            text = "${schedule.frequencyPerDay}x/day",
                            fontSize = 11.sp,
                            color = AppColors.onBackground.copy(alpha = 0.55f),
                        )
                    }
                }
            }
            if (isSaving) {
                CircularProgressIndicator(
                    color = AITeal,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        HorizontalDivider(
            color = AppColors.onBackground.copy(alpha = 0.06f),
            thickness = 0.5.dp,
        )
        Spacer(Modifier.height(10.dp))

        // Time row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (isDaily && !isSaving) Modifier.clickable { showPicker = true }
                    else Modifier
                )
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Dose time",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onBackground,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = formatDisplayTime(schedule.timeOfDay),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (isDaily) AITeal else AppColors.onBackground.copy(alpha = 0.4f),
            )
        }

        if (!isDaily) {
            Spacer(Modifier.height(2.dp))
            Text(
                text = "Not editable from family view",
                fontSize = 11.sp,
                color = AppColors.onBackground.copy(alpha = 0.5f),
            )
        }

        Spacer(Modifier.height(4.dp))
        HorizontalDivider(
            color = AppColors.onBackground.copy(alpha = 0.06f),
            thickness = 0.5.dp,
        )
        Spacer(Modifier.height(6.dp))

        // Reminder toggle
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Reminder",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.onBackground,
                )
                Text(
                    text = if (schedule.reminderEnabled) "On" else "Off",
                    fontSize = 12.sp,
                    color = AppColors.onBackground.copy(alpha = 0.55f),
                )
            }
            Switch(
                checked = schedule.reminderEnabled,
                onCheckedChange = { enabled -> onToggleReminder(enabled) },
                enabled = !isSaving,
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

    if (showPicker) {
        val (initH, initM) = parseHourMinutePair(schedule.timeOfDay) ?: (8 to 0)
        RemindersTimePickerSheet(
            title = "${schedule.medicationName} — dose time",
            initialHour = initH,
            initialMinute = initM,
            onConfirm = { h, m ->
                onPickTime(formatHHmmss(h, m))
                showPicker = false
            },
            onDismiss = { showPicker = false },
        )
    }
}

@Composable
private fun ScheduleTypeBadge(scheduleType: String) {
    val label = when (scheduleType.lowercase()) {
        "daily" -> "Daily"
        "weekly" -> "Weekly"
        "monthly" -> "Monthly"
        "as_needed" -> "As needed"
        "custom" -> "Custom"
        else -> scheduleType
    }
    val tint = if (scheduleType.equals("daily", ignoreCase = true)) AITeal
    else AppColors.onBackground.copy(alpha = 0.45f)
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .border(
                BorderStroke(1.dp, tint.copy(alpha = 0.4f)),
                RoundedCornerShape(6.dp),
            )
            .padding(horizontal = 8.dp, vertical = 2.dp),
    ) {
        Text(
            text = label,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            color = tint,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RemindersTimePickerSheet(
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

// ── Helpers ────────────────────────────────────────────────────────────────

private fun formatHHmmss(hour: Int, minute: Int): String =
    "%02d:%02d:00".format(hour, minute)

private fun parseHourMinutePair(time: String?): Pair<Int, Int>? {
    if (time.isNullOrBlank()) return null
    val parts = time.split(":")
    if (parts.size < 2) return null
    val h = parts[0].toIntOrNull() ?: return null
    val m = parts[1].toIntOrNull() ?: return null
    if (h !in 0..23 || m !in 0..59) return null
    return h to m
}

private fun formatDisplayTime(time: String?): String {
    val (h, m) = parseHourMinutePair(time) ?: return "—"
    val period = if (h < 12) "AM" else "PM"
    val displayHour = when {
        h == 0 -> 12
        h > 12 -> h - 12
        else -> h
    }
    return "%d:%02d %s".format(displayHour, m, period)
}
