package com.swasthicare.mobile.ui.screens.medications

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.MedicationType
import com.swasthicare.mobile.data.models.ScheduleType
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import com.swasthicare.mobile.ui.theme.AppColors

// Default scheduled times per schedule type
private fun defaultScheduleTimes(type: ScheduleType): List<Pair<String, String>> = when (type) {
    ScheduleType.ONCE_DAILY   -> listOf("Morning" to "8:00 AM")
    ScheduleType.TWICE_DAILY  -> listOf("Morning" to "8:00 AM", "Evening" to "8:00 PM")
    ScheduleType.THRICE_DAILY -> listOf("Morning" to "8:00 AM", "Afternoon" to "2:00 PM", "Evening" to "8:00 PM")
    ScheduleType.CUSTOM       -> emptyList()
}

private fun scheduleTimeStrings(type: ScheduleType): List<String> = when (type) {
    ScheduleType.ONCE_DAILY   -> listOf("08:00:00")
    ScheduleType.TWICE_DAILY  -> listOf("08:00:00", "20:00:00")
    ScheduleType.THRICE_DAILY -> listOf("08:00:00", "14:00:00", "20:00:00")
    ScheduleType.CUSTOM       -> listOf("08:00:00")
}

// ─────────────────────────────────────
// MARK: - AddMedicationScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddMedicationScreen(onDismiss: () -> Unit) {
    val vm = remember { AppContainer.medicationsViewModel }

    // Form state
    var currentStep by remember { mutableIntStateOf(1) }
    var name by remember { mutableStateOf("") }
    var dosage by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf(MedicationType.PILL) }
    var selectedSchedule by remember { mutableStateOf(ScheduleType.ONCE_DAILY) }
    var startDate by remember { mutableStateOf(LocalDate.now()) }
    var endDate by remember { mutableStateOf(LocalDate.now().plusMonths(1)) }
    var isOngoing by remember { mutableStateOf(true) }
    var notes by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var showStartDatePicker by remember { mutableStateOf(false) }
    var showEndDatePicker by remember { mutableStateOf(false) }

    val dateFormatter = remember { DateTimeFormatter.ofPattern("MMM d, yyyy") }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
        ) {
            // ── Top Bar (matches MedicationsScreen / MedicationDetailScreen) ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = onDismiss) {
                    Text("Cancel", fontSize = 16.sp,
                        color = AppColors.onSurface)
                }
                Text(
                    "Add Medication",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.width(72.dp))
            }

            // ── Progress Bar (3 segments, iOS-style) ──
            MedProgressBar(currentStep = currentStep)

            // ── Step Content ──
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(top = 24.dp, bottom = 100.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                when (currentStep) {
                    1 -> Step1Content(
                        name = name, onNameChange = { name = it },
                        dosage = dosage, onDosageChange = { dosage = it },
                        selectedType = selectedType, onTypeSelected = { selectedType = it }
                    )
                    2 -> Step2Content(
                        selectedSchedule = selectedSchedule,
                        onScheduleSelected = { selectedSchedule = it }
                    )
                    3 -> Step3Content(
                        startDate = startDate,
                        endDate = endDate,
                        isOngoing = isOngoing,
                        notes = notes,
                        onNotesChange = { notes = it },
                        onIsOngoingChange = { isOngoing = it },
                        onShowStartDatePicker = { showStartDatePicker = true },
                        onShowEndDatePicker = { showEndDatePicker = true },
                        dateFormatter = dateFormatter
                    )
                }
            }

            // ── Navigation Buttons (sticky bottom) ──
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shadowElevation = 8.dp,
                color = AppColors.surface
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    if (currentStep > 1) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(16.dp))
                                .background(AppColors.onSurface.copy(alpha = 0.08f))
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null
                                ) { currentStep-- }
                                .padding(vertical = 16.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(Icons.Default.ChevronLeft, null,
                                    tint = AppColors.onSurface,
                                    modifier = Modifier.size(18.dp))
                                Text("Back", fontSize = 16.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AppColors.onSurface)
                            }
                        }
                    }

                    val canProceed = currentStep != 1 || name.isNotBlank()
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(16.dp))
                            .background(
                                if (canProceed) MedBrandBlue
                                else Color.Gray.copy(alpha = 0.2f)
                            )
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                enabled = canProceed && !isLoading
                            ) {
                                if (currentStep < 3) {
                                    currentStep++
                                } else {
                                    isLoading = true
                                    vm.addMedication(
                                        name = name,
                                        dosage = dosage,
                                        dosageUnit = "",
                                        type = selectedType,
                                        scheduleType = selectedSchedule,
                                        scheduleTimes = scheduleTimeStrings(selectedSchedule),
                                        startDate = startDate,
                                        endDate = if (isOngoing) null else endDate,
                                        isOngoing = isOngoing,
                                        notes = notes.ifBlank { null }
                                    )
                                    onDismiss()
                                }
                            }
                            .padding(vertical = 16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        if (isLoading) {
                            CircularProgressIndicator(
                                color = Color.White,
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text(
                                    if (currentStep == 3) "Save" else "Next",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (canProceed) Color.White
                                            else AppColors.onSurface.copy(alpha = 0.4f)
                                )
                                if (currentStep < 3) {
                                    Icon(Icons.Default.ChevronRight, null,
                                        tint = if (canProceed) Color.White
                                               else AppColors.onSurface.copy(alpha = 0.4f),
                                        modifier = Modifier.size(18.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Start Date Picker ──
    if (showStartDatePicker) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = startDate.toEpochDay() * 86_400_000L
        )
        DatePickerDialog(
            onDismissRequest = { showStartDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { millis ->
                        startDate = Instant.ofEpochMilli(millis)
                            .atZone(ZoneId.of("UTC")).toLocalDate()
                    }
                    showStartDatePicker = false
                }) { Text("OK", color = MedBrandBlue) }
            },
            dismissButton = {
                TextButton(onClick = { showStartDatePicker = false }) { Text("Cancel") }
            }
        ) { DatePicker(state = state) }
    }

    // ── End Date Picker ──
    if (showEndDatePicker) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = endDate.toEpochDay() * 86_400_000L
        )
        DatePickerDialog(
            onDismissRequest = { showEndDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { millis ->
                        endDate = Instant.ofEpochMilli(millis)
                            .atZone(ZoneId.of("UTC")).toLocalDate()
                    }
                    showEndDatePicker = false
                }) { Text("OK", color = MedBrandBlue) }
            },
            dismissButton = {
                TextButton(onClick = { showEndDatePicker = false }) { Text("Cancel") }
            }
        ) { DatePicker(state = state) }
    }
}

// ─────────────────────────────────────
// MARK: - Progress Bar (3 segments)
// ─────────────────────────────────────

@Composable
private fun MedProgressBar(currentStep: Int) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            for (step in 1..3) {
                val filled = step <= currentStep
                val segColor by animateColorAsState(
                    targetValue = if (filled) MedBrandBlue
                                  else AppColors.onSurface.copy(alpha = 0.15f),
                    animationSpec = tween(durationMillis = 300),
                    label = "seg$step"
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(segColor)
                )
            }
        }
        Text(
            "Step $currentStep of 3",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Step 1: Basic Information
// ─────────────────────────────────────

@Composable
private fun Step1Content(
    name: String, onNameChange: (String) -> Unit,
    dosage: String, onDosageChange: (String) -> Unit,
    selectedType: MedicationType, onTypeSelected: (MedicationType) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Step 1: Basic Information",
                fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text("Enter the medication details",
                fontSize = 15.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f))
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Medication Name", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            MedTextField(name, onNameChange, "e.g., Aspirin, Metformin")
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Dosage (Optional)", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            MedTextField(dosage, onDosageChange, "e.g., 500mg, 1 tablet")
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Type", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.heightIn(max = 400.dp)
            ) {
                items(MedicationType.values()) { type ->
                    MedicationTypeCard(
                        type = type,
                        isSelected = selectedType == type,
                        onClick = { onTypeSelected(type) }
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 2: Schedule
// ─────────────────────────────────────

@Composable
private fun Step2Content(
    selectedSchedule: ScheduleType,
    onScheduleSelected: (ScheduleType) -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Step 2: Schedule",
                fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text("Choose how often you take this medication",
                fontSize = 15.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f))
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ScheduleTemplateCard(
                title = "Once Daily",
                description = "One dose per day",
                isSelected = selectedSchedule == ScheduleType.ONCE_DAILY,
                onClick = { onScheduleSelected(ScheduleType.ONCE_DAILY) }
            )
            ScheduleTemplateCard(
                title = "Twice Daily",
                description = "Two doses per day",
                isSelected = selectedSchedule == ScheduleType.TWICE_DAILY,
                onClick = { onScheduleSelected(ScheduleType.TWICE_DAILY) }
            )
            ScheduleTemplateCard(
                title = "Thrice Daily",
                description = "Three doses per day",
                isSelected = selectedSchedule == ScheduleType.THRICE_DAILY,
                onClick = { onScheduleSelected(ScheduleType.THRICE_DAILY) }
            )
        }

        val times = defaultScheduleTimes(selectedSchedule)
        if (times.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Scheduled Times", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                times.forEach { (label, time) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(cardBg)
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(label, fontSize = 15.sp)
                        Text(time, fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MedBrandBlue)
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 3: Duration & Notes
// ─────────────────────────────────────

@Composable
private fun Step3Content(
    startDate: LocalDate,
    endDate: LocalDate,
    isOngoing: Boolean,
    notes: String,
    onNotesChange: (String) -> Unit,
    onIsOngoingChange: (Boolean) -> Unit,
    onShowStartDatePicker: () -> Unit,
    onShowEndDatePicker: () -> Unit,
    dateFormatter: DateTimeFormatter
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Step 3: Duration",
                fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text("Set the medication duration",
                fontSize = 15.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f))
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Start Date", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            DateSelectRow(
                dateText = startDate.format(dateFormatter),
                cardBg = cardBg,
                onClick = onShowStartDatePicker
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Duration", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(cardBg)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Ongoing medication", fontSize = 15.sp)
                    Text("No end date", fontSize = 13.sp,
                        color = AppColors.onSurface.copy(alpha = 0.5f))
                }
                Switch(
                    checked = isOngoing,
                    onCheckedChange = onIsOngoingChange,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = MedBrandBlue
                    )
                )
            }
            if (!isOngoing) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("End Date", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    DateSelectRow(
                        dateText = endDate.format(dateFormatter),
                        cardBg = cardBg,
                        onClick = onShowEndDatePicker
                    )
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Notes (Optional)", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = notes,
                onValueChange = onNotesChange,
                placeholder = {
                    Text("Any special instructions…",
                        color = AppColors.onSurface.copy(alpha = 0.4f))
                },
                minLines = 4,
                maxLines = 6,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MedBrandBlue,
                    unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
                    focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                    unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f)
                ),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Shared UI Helpers
// ─────────────────────────────────────

/** Premium text field — matches iOS PremiumTextFieldStyle */
@Composable
private fun MedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(placeholder,
                color = AppColors.onSurface.copy(alpha = 0.4f))
        },
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MedBrandBlue,
            unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
            focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
            unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth()
    )
}

/** Tappable date row with calendar icon */
@Composable
private fun DateSelectRow(
    dateText: String,
    cardBg: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardBg)
            .border(
                1.dp,
                AppColors.onSurface.copy(alpha = 0.08f),
                RoundedCornerShape(16.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(dateText, fontSize = 16.sp)
        Icon(Icons.Default.CalendarToday, null,
            tint = MedBrandBlue, modifier = Modifier.size(18.dp))
    }
}
