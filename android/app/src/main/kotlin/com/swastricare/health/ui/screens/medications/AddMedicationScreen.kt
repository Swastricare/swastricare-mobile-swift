package com.swastricare.health.ui.screens.medications

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import com.swastricare.health.data.models.MedicationType
import com.swastricare.health.data.models.ScheduleType
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.ceil

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
    val vm: MedicationsViewModel = hiltViewModel()

    // Form state
    var name by remember { mutableStateOf("") }
    var dosage by remember { mutableStateOf("") }
    var dosageUnit by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf(MedicationType.PILL) }
    var selectedSchedule by remember { mutableStateOf(ScheduleType.ONCE_DAILY) }
    var startDate by remember { mutableStateOf(LocalDate.now()) }
    var endDate by remember { mutableStateOf(LocalDate.now().plusMonths(1)) }
    var isOngoing by remember { mutableStateOf(true) }
    var notes by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var showStartDatePicker by remember { mutableStateOf(false) }
    var showEndDatePicker by remember { mutableStateOf(false) }

    // Quantity-based end date calculation
    var totalQuantity by remember { mutableStateOf("") }
    var dosagePerIntake by remember { mutableStateOf("1") }
    var useQuantityCalculation by remember { mutableStateOf(false) }

    // Auto-calculate end date from quantity
    val dosesPerDay = selectedSchedule.dosesPerDay
    val perIntake = dosagePerIntake.toIntOrNull() ?: 1
    val totalTablets = totalQuantity.toIntOrNull()
    val calculatedDays = if (totalTablets != null && totalTablets > 0 && dosesPerDay > 0 && perIntake > 0) {
        ceil(totalTablets.toDouble() / (dosesPerDay * perIntake)).toInt()
    } else null
    val calculatedEndDate = calculatedDays?.let { startDate.plusDays(it.toLong() - 1) }

    // Sync calculated end date
    LaunchedEffect(calculatedEndDate, useQuantityCalculation) {
        if (useQuantityCalculation && calculatedEndDate != null) {
            endDate = calculatedEndDate
        }
    }

    val dateFormatter = remember { DateTimeFormatter.ofPattern("MMM d, yyyy") }
    val canSave = name.isNotBlank()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize()) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back",
                        tint = AppColors.onSurface)
                }
                Text(
                    "Add Medication",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 4.dp)
                )
            }

            // ── Scrollable Form ──
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp, bottom = 120.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                // ── Section 1: Name & Dosage ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    SectionLabel("Medication Details")

                    MedTextField(
                        value = name,
                        onValueChange = { name = it },
                        placeholder = "Medication name",
                        leadingIcon = Icons.Default.Medication
                    )

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        MedTextField(
                            value = dosage,
                            onValueChange = { dosage = it },
                            placeholder = "Dosage",
                            leadingIcon = Icons.Default.Science,
                            modifier = Modifier.weight(1f)
                        )
                        MedTextField(
                            value = dosageUnit,
                            onValueChange = { dosageUnit = it },
                            placeholder = "Unit (mg, ml)",
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // ── Section 2: Medication Type ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SectionLabel("Type")

                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(MedicationType.entries.toList()) { type ->
                            TypeChip(
                                type = type,
                                isSelected = selectedType == type,
                                onClick = { selectedType = type }
                            )
                        }
                    }
                }

                // ── Section 3: Schedule ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SectionLabel("Schedule")

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        FrequencyChip("1x", "Once", selectedSchedule == ScheduleType.ONCE_DAILY,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.ONCE_DAILY }
                        FrequencyChip("2x", "Twice", selectedSchedule == ScheduleType.TWICE_DAILY,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.TWICE_DAILY }
                        FrequencyChip("3x", "Thrice", selectedSchedule == ScheduleType.THRICE_DAILY,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.THRICE_DAILY }
                    }

                    // Scheduled times preview
                    val times = defaultScheduleTimes(selectedSchedule)
                    if (times.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            times.forEach { (label, time) ->
                                TimeRow(label = label, time = time)
                            }
                        }
                    }
                }

                // ── Section 4: Duration ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SectionLabel("Duration")

                    // Start date
                    DateRow(
                        label = "Start Date",
                        dateText = startDate.format(dateFormatter),
                        onClick = { showStartDatePicker = true }
                    )

                    // Ongoing toggle
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .lightBorder(12.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(AppColors.onSurface.copy(alpha = 0.05f))
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Ongoing", fontSize = 15.sp, fontWeight = FontWeight.Medium)
                            Text("No end date", fontSize = 12.sp,
                                color = AppColors.onSurface.copy(alpha = 0.5f))
                        }
                        Switch(
                            checked = isOngoing,
                            onCheckedChange = { isOngoing = it },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Color.White,
                                checkedTrackColor = MedBrandBlue
                            )
                        )
                    }

                    // End date options (shown when not ongoing)
                    AnimatedVisibility(
                        visible = !isOngoing,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            // Toggle: Calculate from quantity vs manual end date
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                DurationModeChip(
                                    label = "Set End Date",
                                    icon = Icons.Default.CalendarToday,
                                    isSelected = !useQuantityCalculation,
                                    modifier = Modifier.weight(1f),
                                    onClick = { useQuantityCalculation = false }
                                )
                                DurationModeChip(
                                    label = "From Quantity",
                                    icon = Icons.Default.Calculate,
                                    isSelected = useQuantityCalculation,
                                    modifier = Modifier.weight(1f),
                                    onClick = { useQuantityCalculation = true }
                                )
                            }

                            if (useQuantityCalculation) {
                                // Quantity inputs
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    MedTextField(
                                        value = totalQuantity,
                                        onValueChange = { totalQuantity = it.filter { c -> c.isDigit() } },
                                        placeholder = "Total tablets",
                                        leadingIcon = Icons.Default.Inventory2,
                                        modifier = Modifier.weight(1f),
                                        keyboardType = KeyboardType.Number
                                    )
                                    MedTextField(
                                        value = dosagePerIntake,
                                        onValueChange = { dosagePerIntake = it.filter { c -> c.isDigit() } },
                                        placeholder = "Per dose",
                                        leadingIcon = Icons.Default.Medication,
                                        modifier = Modifier.weight(1f),
                                        keyboardType = KeyboardType.Number
                                    )
                                }

                                // Calculation preview
                                if (calculatedDays != null && calculatedEndDate != null) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(12.dp))
                                            .background(MedTealGreen.copy(alpha = 0.08f))
                                            .border(
                                                1.dp,
                                                MedTealGreen.copy(alpha = 0.15f),
                                                RoundedCornerShape(12.dp)
                                            )
                                            .padding(horizontal = 14.dp, vertical = 12.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.AutoAwesome, null,
                                            tint = MedTealGreen,
                                            modifier = Modifier.size(16.dp)
                                        )
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                "$totalTablets tablets  ×  $perIntake per dose  ×  ${dosesPerDay}x/day",
                                                fontSize = 12.sp,
                                                color = AppColors.onSurface.copy(alpha = 0.6f)
                                            )
                                            Text(
                                                "$calculatedDays days — ends ${calculatedEndDate.format(dateFormatter)}",
                                                fontSize = 14.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = MedTealGreen
                                            )
                                        }
                                    }
                                }
                            } else {
                                // Manual end date picker
                                DateRow(
                                    label = "End Date",
                                    dateText = endDate.format(dateFormatter),
                                    onClick = { showEndDatePicker = true }
                                )
                            }
                        }
                    }
                }

                // ── Section 5: Notes ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    SectionLabel("Notes (Optional)")

                    OutlinedTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        placeholder = {
                            Text("Special instructions, take with food...",
                                color = AppColors.onSurface.copy(alpha = 0.35f),
                                fontSize = 14.sp)
                        },
                        minLines = 3,
                        maxLines = 5,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = MedBrandBlue,
                            unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            // ── Save Button (sticky bottom) ──
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shadowElevation = 8.dp,
                color = AppColors.surface
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 16.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(if (canSave) MedBrandBlue else Color.Gray.copy(alpha = 0.3f))
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            enabled = canSave && !isLoading
                        ) {
                            isLoading = true
                            vm.addMedication(
                                name = name,
                                dosage = dosage,
                                dosageUnit = dosageUnit,
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
                        .padding(vertical = 16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(22.dp),
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text(
                            "Save Medication",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (canSave) Color.White
                                    else AppColors.onSurface.copy(alpha = 0.4f)
                        )
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
// MARK: - Section Label
// ─────────────────────────────────────

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.onSurface.copy(alpha = 0.5f),
        letterSpacing = 0.5.sp
    )
}

// ─────────────────────────────────────
// MARK: - Text Field
// ─────────────────────────────────────

@Composable
private fun MedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(placeholder,
                color = AppColors.onSurface.copy(alpha = 0.35f),
                fontSize = 14.sp)
        },
        leadingIcon = leadingIcon?.let { icon ->
            {
                Icon(icon, null,
                    tint = AppColors.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.size(20.dp))
            }
        },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MedBrandBlue,
            unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.fillMaxWidth()
    )
}

// ─────────────────────────────────────
// MARK: - Duration Mode Chip
// ─────────────────────────────────────

@Composable
private fun DurationModeChip(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (isSelected) MedBrandBlue
                else AppColors.onSurface.copy(alpha = 0.05f)
            )
            .border(
                width = 1.dp,
                color = if (isSelected) Color.Transparent
                        else AppColors.onSurface.copy(alpha = 0.1f),
                shape = RoundedCornerShape(12.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 12.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isSelected) Color.White else MedBrandBlue,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = label,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (isSelected) Color.White else AppColors.onSurface
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Type Chip (horizontal scroll)
// ─────────────────────────────────────

@Composable
private fun TypeChip(
    type: MedicationType,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (isSelected) MedBrandBlue
                else AppColors.onSurface.copy(alpha = 0.05f)
            )
            .border(
                width = 1.dp,
                color = if (isSelected) Color.Transparent
                        else AppColors.onSurface.copy(alpha = 0.1f),
                shape = RoundedCornerShape(12.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = type.toIcon(),
                contentDescription = null,
                tint = if (isSelected) Color.White else MedBrandBlue,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = type.displayName,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (isSelected) Color.White else AppColors.onSurface
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Frequency Chip
// ─────────────────────────────────────

@Composable
private fun FrequencyChip(
    frequency: String,
    label: String,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (isSelected) MedBrandBlue
                else AppColors.onSurface.copy(alpha = 0.05f)
            )
            .border(
                width = 1.dp,
                color = if (isSelected) Color.Transparent
                        else AppColors.onSurface.copy(alpha = 0.1f),
                shape = RoundedCornerShape(12.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = frequency,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = if (isSelected) Color.White else MedBrandBlue
            )
            Text(
                text = label,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = if (isSelected) Color.White.copy(alpha = 0.8f)
                        else AppColors.onSurface.copy(alpha = 0.5f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Time Row
// ─────────────────────────────────────

@Composable
private fun TimeRow(label: String, time: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .lightBorder(10.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.onSurface.copy(alpha = 0.05f))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.Default.Schedule, null,
                tint = AppColors.onSurface.copy(alpha = 0.4f),
                modifier = Modifier.size(16.dp)
            )
            Text(label, fontSize = 14.sp, color = AppColors.onSurface.copy(alpha = 0.7f))
        }
        Text(
            time, fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = MedBrandBlue
        )
    }
}

// ─────────────────────────────────────
// MARK: - Date Row
// ─────────────────────────────────────

@Composable
private fun DateRow(
    label: String,
    dateText: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.onSurface.copy(alpha = 0.05f))
            .border(
                1.dp,
                AppColors.onSurface.copy(alpha = 0.08f),
                RoundedCornerShape(12.dp)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.Default.CalendarToday, null,
                tint = MedBrandBlue,
                modifier = Modifier.size(18.dp)
            )
            Text(label, fontSize = 14.sp, color = AppColors.onSurface.copy(alpha = 0.6f))
        }
        Text(
            dateText, fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
    }
}
