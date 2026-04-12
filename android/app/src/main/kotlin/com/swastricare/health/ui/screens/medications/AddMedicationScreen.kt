package com.swastricare.health.ui.screens.medications

import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.MedicationType
import com.swastricare.health.data.models.ScheduleType
import com.swastricare.health.data.repository.DrugSearchResult
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.ceil

// ─────────────────────────────────────
// MARK: - Add Medication Steps
// ─────────────────────────────────────

private enum class AddMedicationStep {
    NAME,           // Step 1: Search/enter medication name
    DOSAGE,         // Step 2: Enter dosage and unit
    TYPE,           // Step 3: Select medication type
    SCHEDULE,       // Step 4: Select frequency and times
    DURATION,       // Step 5: Set duration
    REVIEW          // Step 6: Review and save
}

// ─────────────────────────────────────
// MARK: - Duration Presets
// ─────────────────────────────────────

private enum class DurationMode {
    ONGOING, PRESET, MANUAL, QUANTITY
}

private data class DurationPreset(
    val label: String,
    val days: Long
)

private val durationPresets = listOf(
    DurationPreset("7 days", 7),
    DurationPreset("14 days", 14),
    DurationPreset("1 month", 30),
    DurationPreset("3 months", 90),
    DurationPreset("6 months", 180),
)

// ─────────────────────────────────────
// MARK: - Schedule Time Helpers
// ─────────────────────────────────────

private fun defaultScheduleTimes(type: ScheduleType): List<Pair<String, LocalTime>> = when (type) {
    ScheduleType.ONCE_DAILY   -> listOf("Morning" to LocalTime.of(8, 0))
    ScheduleType.TWICE_DAILY  -> listOf("Morning" to LocalTime.of(8, 0), "Evening" to LocalTime.of(20, 0))
    ScheduleType.THRICE_DAILY -> listOf(
        "Morning" to LocalTime.of(8, 0),
        "Afternoon" to LocalTime.of(14, 0),
        "Evening" to LocalTime.of(20, 0)
    )
    ScheduleType.CUSTOM       -> listOf("Dose 1" to LocalTime.of(8, 0))
}

private fun labelForIndex(index: Int): String = when (index) {
    0 -> "Morning"
    1 -> "Afternoon"
    2 -> "Evening"
    3 -> "Night"
    else -> "Dose ${index + 1}"
}

private fun formatTime12h(time: LocalTime): String {
    val formatter = DateTimeFormatter.ofPattern("h:mm a")
    return time.format(formatter)
}

private fun timeToDbString(time: LocalTime): String =
    time.format(DateTimeFormatter.ofPattern("HH:mm:ss"))

// ─────────────────────────────────────
// MARK: - AddMedicationScreen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddMedicationScreen(onDismiss: () -> Unit) {
    TrackScreen("AddMedication")
    val vm: MedicationsViewModel = hiltViewModel()

    // Drug search state
    val drugSuggestions by vm.drugSuggestions.collectAsState()
    val drugDetails = vm.drugDetails.collectAsState().value
    val isSearching by vm.isSearching.collectAsState()

    // Step state
    var currentStep by remember { mutableStateOf(AddMedicationStep.NAME) }

    // Form state
    var name by remember { mutableStateOf("") }
    var dosage by remember { mutableStateOf("") }
    var dosageUnit by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf(MedicationType.PILL) }
    var selectedSchedule by remember { mutableStateOf(ScheduleType.ONCE_DAILY) }
    var startDate by remember { mutableStateOf(LocalDate.now()) }
    var endDate by remember { mutableStateOf(LocalDate.now().plusMonths(1)) }
    var notes by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }

    val view = LocalView.current

    // Observe save result — dismiss only on success, reset loading on failure
    val addResult by vm.addMedicationSuccess.collectAsState()
    LaunchedEffect(addResult) {
        when (addResult) {
            true -> {
                vm.clearAddMedicationResult()
                vm.clearDrugSearch()
                onDismiss()
            }
            false -> {
                isLoading = false
                vm.clearAddMedicationResult()
            }
            null -> { /* no-op */ }
        }
    }
    var showStartDatePicker by remember { mutableStateOf(false) }
    var showEndDatePicker by remember { mutableStateOf(false) }
    var suppressSearch by remember { mutableStateOf(false) }

    // Duration mode
    var durationMode by remember { mutableStateOf(DurationMode.ONGOING) }
    var selectedPreset by remember { mutableStateOf<DurationPreset?>(null) }

    // Quantity-based end date calculation
    var totalQuantity by remember { mutableStateOf("") }
    var dosagePerIntake by remember { mutableStateOf("1") }

    // Custom schedule times — mutable list of (label, time) pairs
    var scheduleTimes by remember {
        mutableStateOf(defaultScheduleTimes(ScheduleType.ONCE_DAILY))
    }
    var showTimePickerForIndex by remember { mutableIntStateOf(-1) }

    // Sync schedule times when schedule type changes
    LaunchedEffect(selectedSchedule) {
        scheduleTimes = defaultScheduleTimes(selectedSchedule)
    }

    // Sync end date from preset
    LaunchedEffect(selectedPreset, startDate) {
        selectedPreset?.let { preset ->
            endDate = startDate.plusDays(preset.days)
        }
    }

    // Auto-calculate end date from quantity
    val dosesPerDay = if (selectedSchedule == ScheduleType.CUSTOM) scheduleTimes.size else selectedSchedule.dosesPerDay
    val perIntake = dosagePerIntake.toIntOrNull() ?: 1
    val totalTablets = totalQuantity.toIntOrNull()
    val calculatedDays = if (totalTablets != null && totalTablets > 0 && dosesPerDay > 0 && perIntake > 0) {
        ceil(totalTablets.toDouble() / (dosesPerDay * perIntake)).toInt()
    } else null
    val calculatedEndDate = calculatedDays?.let { startDate.plusDays(it.toLong() - 1) }

    LaunchedEffect(calculatedEndDate, durationMode) {
        if (durationMode == DurationMode.QUANTITY && calculatedEndDate != null) {
            endDate = calculatedEndDate
        }
    }

    val dateFormatter = remember { DateTimeFormatter.ofPattern("MMM d, yyyy") }

    // Derive isOngoing and effective endDate for save
    val isOngoing = durationMode == DurationMode.ONGOING
    val effectiveEndDate = when (durationMode) {
        DurationMode.ONGOING -> null
        else -> endDate
    }

    // Step validation
    val canProceed = when (currentStep) {
        AddMedicationStep.NAME -> name.isNotBlank()
        AddMedicationStep.DOSAGE -> true // Optional fields
        AddMedicationStep.TYPE -> true // Always has default
        AddMedicationStep.SCHEDULE -> scheduleTimes.isNotEmpty()
        AddMedicationStep.DURATION -> true // Always valid
        AddMedicationStep.REVIEW -> true
    }

    val steps = AddMedicationStep.entries.toList()
    val currentStepIndex = steps.indexOf(currentStep)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.surface)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // ── Top Bar with Progress ──
            Column(
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        if (currentStep == AddMedicationStep.NAME) {
                            vm.clearDrugSearch()
                            onDismiss()
                        } else {
                            // Go back to previous step
                            val prevIndex = (currentStepIndex - 1).coerceAtLeast(0)
                            currentStep = steps[prevIndex]
                        }
                    }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = AppColors.onSurface
                        )
                    }
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 4.dp)
                    ) {
                        Text(
                            "Add Medication",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.onSurface
                        )
                        Text(
                            "Step ${currentStepIndex + 1} of ${steps.size}",
                            style = MaterialTheme.typography.bodySmall,
                            color = AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }

                // Progress indicator
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    steps.forEachIndexed { index, _ ->
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(4.dp)
                                .clip(RoundedCornerShape(2.dp))
                                .background(
                                    if (index <= currentStepIndex) MedBrandBlue
                                    else AppColors.onSurface.copy(alpha = 0.1f)
                                )
                        )
                    }
                }
            }

            // ── Step Content ──
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                when (currentStep) {
                    AddMedicationStep.NAME -> StepMedicationName(
                        name = name,
                        onNameChange = { name = it },
                        drugSuggestions = drugSuggestions,
                        isSearching = isSearching,
                        onDrugSelected = { drug ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            suppressSearch = true
                            vm.clearDrugSearch()
                            name = drug.displayName
                            dosage = drug.dosage ?: ""
                            dosageUnit = drug.dosageUnit ?: ""
                            vm.selectDrug(drug)
                        },
                        onClearName = {
                            name = ""
                            vm.clearDrugSearch()
                        },
                        onSearchDrug = { query ->
                            if (!suppressSearch) vm.searchDrug(query)
                            else suppressSearch = false
                        }
                    )

                    AddMedicationStep.DOSAGE -> StepDosage(
                        dosage = dosage,
                        dosageUnit = dosageUnit,
                        onDosageChange = { dosage = it },
                        onUnitChange = { dosageUnit = it }
                    )

                    AddMedicationStep.TYPE -> StepMedicationType(
                        selectedType = selectedType,
                        onTypeSelected = { type ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            selectedType = type
                        }
                    )

                    AddMedicationStep.SCHEDULE -> StepSchedule(
                        selectedSchedule = selectedSchedule,
                        scheduleTimes = scheduleTimes,
                        onScheduleChange = { schedule ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            selectedSchedule = schedule
                        },
                        onTimeClick = { index -> showTimePickerForIndex = index },
                        onRemoveTime = { index ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            scheduleTimes = scheduleTimes.toMutableList().apply { removeAt(index) }
                        },
                        onAddTime = {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            val nextIndex = scheduleTimes.size
                            val nextTime = LocalTime.of(
                                ((scheduleTimes.lastOrNull()?.second?.hour ?: 7) + 4).coerceAtMost(23),
                                0
                            )
                            scheduleTimes = scheduleTimes + (labelForIndex(nextIndex) to nextTime)
                        }
                    )

                    AddMedicationStep.DURATION -> StepDuration(
                        durationMode = durationMode,
                        startDate = startDate,
                        endDate = endDate,
                        selectedPreset = selectedPreset,
                        totalQuantity = totalQuantity,
                        dosagePerIntake = dosagePerIntake,
                        calculatedDays = calculatedDays,
                        calculatedEndDate = calculatedEndDate,
                        dosesPerDay = dosesPerDay,
                        dateFormatter = dateFormatter,
                        onModeChange = { mode ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            durationMode = mode
                        },
                        onStartDateClick = { showStartDatePicker = true },
                        onEndDateClick = { showEndDatePicker = true },
                        onPresetSelected = { preset ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            selectedPreset = preset
                        },
                        onQuantityChange = { totalQuantity = it },
                        onDosagePerIntakeChange = { dosagePerIntake = it }
                    )

                    AddMedicationStep.REVIEW -> StepReview(
                        name = name,
                        dosage = dosage,
                        dosageUnit = dosageUnit,
                        selectedType = selectedType,
                        selectedSchedule = selectedSchedule,
                        scheduleTimes = scheduleTimes,
                        startDate = startDate,
                        endDate = effectiveEndDate,
                        isOngoing = isOngoing,
                        notes = notes,
                        dateFormatter = dateFormatter,
                        onNotesChange = { notes = it }
                    )
                }
            }

            // ── Navigation Buttons ──
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = AppColors.surface,
                shadowElevation = if (currentStep != AddMedicationStep.NAME) 8.dp else 0.dp
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 24.dp)
                ) {
                    when (currentStep) {
                        AddMedicationStep.REVIEW -> {
                            // Save button on review step
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(56.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(
                                        if (canProceed && !isLoading) MedBrandBlue
                                        else AppColors.onSurface.copy(alpha = 0.2f)
                                    )
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null,
                                        enabled = canProceed && !isLoading
                                    ) {
                                        view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                        isLoading = true
                                        vm.addMedication(
                                            name = name,
                                            dosage = dosage,
                                            dosageUnit = dosageUnit,
                                            type = selectedType,
                                            scheduleType = selectedSchedule,
                                            scheduleTimes = scheduleTimes.map { (_, time) -> timeToDbString(time) },
                                            startDate = startDate,
                                            endDate = effectiveEndDate,
                                            isOngoing = isOngoing,
                                            notes = notes.ifBlank { null }
                                        )
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                if (isLoading) {
                                    CircularProgressIndicator(
                                        color = Color.White,
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 3.dp
                                    )
                                } else {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.CheckCircle,
                                            contentDescription = null,
                                            tint = Color.White,
                                            modifier = Modifier.size(22.dp)
                                        )
                                        Text(
                                            "Save Medication",
                                            fontSize = 17.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White
                                        )
                                    }
                                }
                            }
                        }
                        else -> {
                            // Next button for all other steps
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(56.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(
                                        if (canProceed) MedBrandBlue
                                        else AppColors.onSurface.copy(alpha = 0.2f)
                                    )
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null,
                                        enabled = canProceed
                                    ) {
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        val nextIndex = (currentStepIndex + 1).coerceAtMost(steps.size - 1)
                                        currentStep = steps[nextIndex]
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    Text(
                                        "Next",
                                        fontSize = 17.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (canProceed) Color.White
                                               else AppColors.onSurface.copy(alpha = 0.4f)
                                    )
                                    Icon(
                                        Icons.Default.ArrowForward,
                                        contentDescription = null,
                                        tint = if (canProceed) Color.White
                                              else AppColors.onSurface.copy(alpha = 0.4f),
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Time Picker Dialog ──
    if (showTimePickerForIndex >= 0 && showTimePickerForIndex < scheduleTimes.size) {
        val currentTime = scheduleTimes[showTimePickerForIndex].second
        val timePickerState = rememberTimePickerState(
            initialHour = currentTime.hour,
            initialMinute = currentTime.minute,
            is24Hour = false
        )
        AlertDialog(
            onDismissRequest = { showTimePickerForIndex = -1 },
            confirmButton = {
                TextButton(onClick = {
                    val newTime = LocalTime.of(timePickerState.hour, timePickerState.minute)
                    val idx = showTimePickerForIndex
                    scheduleTimes = scheduleTimes.toMutableList().apply {
                        set(idx, get(idx).first to newTime)
                    }
                    showTimePickerForIndex = -1
                }) { Text("OK", color = MedBrandBlue) }
            },
            dismissButton = {
                TextButton(onClick = { showTimePickerForIndex = -1 }) { Text("Cancel") }
            },
            title = {
                Text(
                    "Set ${scheduleTimes[showTimePickerForIndex].first} Time",
                    fontWeight = FontWeight.SemiBold
                )
            },
            text = {
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    TimePicker(state = timePickerState)
                }
            }
        )
    }

    // ── Start Date Picker (today or earlier — no future dates) ──
    if (showStartDatePicker) {
        val todayMillis = LocalDate.now().toEpochDay() * 86_400_000L
        val state = rememberDatePickerState(
            initialSelectedDateMillis = startDate.toEpochDay() * 86_400_000L,
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                    return utcTimeMillis <= todayMillis
                }
            }
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
// MARK: - Drug Suggestion Item
// ─────────────────────────────────────

@Composable
private fun DrugSuggestionItem(
    drug: DrugSearchResult,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            Icons.Default.Medication, null,
            tint = MedBrandBlue,
            modifier = Modifier.size(20.dp)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                drug.displayName,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
            drug.genericName?.let { generic ->
                Text(
                    generic,
                    fontSize = 12.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        Icon(
            Icons.Default.NorthWest, null,
            tint = AppColors.onSurface.copy(alpha = 0.3f),
            modifier = Modifier.size(14.dp)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Drug Info Row (expandable)
// ─────────────────────────────────────

@Composable
private fun DrugInfoRow(
    icon: ImageVector,
    label: String,
    text: String,
    color: Color
) {
    var expanded by remember { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(color.copy(alpha = 0.06f))
            .border(1.dp, color.copy(alpha = 0.1f), RoundedCornerShape(10.dp))
            .clickable { expanded = !expanded }
            .padding(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(16.dp))
            Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = color)
            Spacer(Modifier.weight(1f))
            Icon(
                if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                null,
                tint = color.copy(alpha = 0.5f),
                modifier = Modifier.size(18.dp)
            )
        }
        AnimatedVisibility(visible = expanded) {
            Text(
                text,
                fontSize = 13.sp,
                color = AppColors.onSurface.copy(alpha = 0.7f),
                lineHeight = 18.sp,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
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
    leadingIcon: ImageVector? = null,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
    trailingContent: (@Composable () -> Unit)? = null
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
        trailingIcon = trailingContent,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MedBrandBlue,
            unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedTextColor = AppColors.onSurface,
            unfocusedTextColor = AppColors.onSurface
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.fillMaxWidth()
    )
}

// ─────────────────────────────────────
// MARK: - Editable Time Row
// ─────────────────────────────────────

@Composable
private fun EditableTimeRow(
    label: String,
    time: LocalTime,
    onClick: () -> Unit,
    onRemove: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .lightBorder(10.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.onSurface.copy(alpha = 0.05f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
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
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                formatTime12h(time), fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = MedBrandBlue
            )
            onRemove?.let {
                Icon(
                    Icons.Default.Close, "Remove",
                    tint = Color(0xFFEF4444).copy(alpha = 0.6f),
                    modifier = Modifier
                        .size(16.dp)
                        .clip(CircleShape)
                        .clickable { it() }
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Preset Duration Chip
// ─────────────────────────────────────

@Composable
private fun PresetChip(
    preset: DurationPreset,
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
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            preset.label,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (isSelected) Color.White else AppColors.onSurface
        )
    }
}

// ─────────────────────────────────────
// MARK: - Duration Mode Chip
// ─────────────────────────────────────

@Composable
private fun DurationModeChip(
    label: String,
    icon: ImageVector,
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

// ─────────────────────────────────────
// MARK: - Step Composables
// ─────────────────────────────────────

// ── Step 1: Medication Name ──
@Composable
private fun StepMedicationName(
    name: String,
    onNameChange: (String) -> Unit,
    drugSuggestions: List<DrugSearchResult>,
    isSearching: Boolean,
    onDrugSelected: (DrugSearchResult) -> Unit,
    onClearName: () -> Unit,
    onSearchDrug: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            "What medication are you taking?",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 36.sp
        )

        Text(
            "Search for your medication or type the name manually",
            fontSize = 16.sp,
            color = AppColors.onSurface.copy(alpha = 0.6f),
            lineHeight = 24.sp
        )

        Spacer(Modifier.height(8.dp))

        OutlinedTextField(
            value = name,
            onValueChange = {
                onNameChange(it)
                onSearchDrug(it)
            },
            placeholder = {
                Text(
                    "Search medication name...",
                    color = AppColors.onSurface.copy(alpha = 0.4f),
                    fontSize = 16.sp
                )
            },
            leadingIcon = {
                Icon(
                    Icons.Default.Search,
                    contentDescription = null,
                    tint = MedBrandBlue,
                    modifier = Modifier.size(24.dp)
                )
            },
            trailingIcon = if (isSearching) {
                {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = MedBrandBlue
                    )
                }
            } else if (name.isNotBlank()) {
                {
                    IconButton(onClick = onClearName, modifier = Modifier.size(24.dp)) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Clear",
                            tint = AppColors.onSurface.copy(alpha = 0.4f),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            } else null,
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                focusedTextColor = AppColors.onSurface,
                unfocusedTextColor = AppColors.onSurface
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 16.sp)
        )

        AnimatedVisibility(
            visible = drugSuggestions.isNotEmpty(),
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(AppColors.onSurface.copy(alpha = 0.04f)),
                verticalArrangement = Arrangement.spacedBy(1.dp)
            ) {
                drugSuggestions.forEach { drug ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onDrugSelected(drug) }
                            .padding(horizontal = 20.dp, vertical = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(MedBrandBlue.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.Medication,
                                contentDescription = null,
                                tint = MedBrandBlue,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                drug.displayName,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = AppColors.onSurface
                            )
                            drug.genericName?.let { generic ->
                                Text(
                                    generic,
                                    fontSize = 14.sp,
                                    color = AppColors.onSurface.copy(alpha = 0.6f),
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                        Icon(
                            Icons.Default.ArrowForward,
                            contentDescription = null,
                            tint = AppColors.onSurface.copy(alpha = 0.3f),
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }
        }
    }
}

// ── Step 2: Dosage ──
@Composable
private fun StepDosage(
    dosage: String,
    dosageUnit: String,
    onDosageChange: (String) -> Unit,
    onUnitChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            "What's the dosage?",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 36.sp
        )

        Text(
            "Enter the amount and unit (optional)",
            fontSize = 16.sp,
            color = AppColors.onSurface.copy(alpha = 0.6f)
        )

        Spacer(Modifier.height(16.dp))

        OutlinedTextField(
            value = dosage,
            onValueChange = onDosageChange,
            placeholder = {
                Text(
                    "e.g., 500",
                    color = AppColors.onSurface.copy(alpha = 0.4f),
                    fontSize = 16.sp
                )
            },
            leadingIcon = {
                Icon(
                    Icons.Default.Science,
                    contentDescription = null,
                    tint = MedBrandBlue,
                    modifier = Modifier.size(24.dp)
                )
            },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                focusedTextColor = AppColors.onSurface,
                unfocusedTextColor = AppColors.onSurface
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        )

        OutlinedTextField(
            value = dosageUnit,
            onValueChange = onUnitChange,
            placeholder = {
                Text(
                    "e.g., mg, ml, tablets",
                    color = AppColors.onSurface.copy(alpha = 0.4f),
                    fontSize = 16.sp
                )
            },
            leadingIcon = {
                Icon(
                    Icons.Default.Label,
                    contentDescription = null,
                    tint = MedBrandBlue,
                    modifier = Modifier.size(24.dp)
                )
            },
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                focusedTextColor = AppColors.onSurface,
                unfocusedTextColor = AppColors.onSurface
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        )

        Text(
            "Common units:",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
        LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            items(listOf("mg", "ml", "tablets", "capsules", "drops")) { unit ->
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(AppColors.onSurface.copy(alpha = 0.05f))
                        .clickable { onUnitChange(unit) }
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                ) {
                    Text(
                        unit,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.onSurface.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}

// ── Step 3: Medication Type ──
@Composable
private fun StepMedicationType(
    selectedType: MedicationType,
    onTypeSelected: (MedicationType) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            "What type of medication?",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 36.sp
        )

        Text(
            "Select the form of your medication",
            fontSize = 16.sp,
            color = AppColors.onSurface.copy(alpha = 0.6f)
        )

        Spacer(Modifier.height(16.dp))

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MedicationType.entries.toList().chunked(2).forEach { rowTypes ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    rowTypes.forEach { type ->
                        TypeCardClean(
                            type = type,
                            isSelected = selectedType == type,
                            onClick = { onTypeSelected(type) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                    if (rowTypes.size == 1) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun TypeCardClean(
    type: MedicationType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val view = LocalView.current
    Box(
        modifier = modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(20.dp))
            .background(
                if (isSelected) MedBrandBlue
                else AppColors.onSurface.copy(alpha = 0.04f)
            )
            .clickable {
                view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                onClick()
            }
            .padding(20.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = type.toIcon(),
                contentDescription = null,
                tint = if (isSelected) Color.White else MedBrandBlue,
                modifier = Modifier.size(36.dp)
            )
            Text(
                text = type.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (isSelected) Color.White else AppColors.onSurface,
                textAlign = TextAlign.Center
            )
        }
    }
}

// Steps 4, 5, 6 will be in next part due to length...

// ── Step 4: Schedule ──
@Composable
private fun StepSchedule(
    selectedSchedule: ScheduleType,
    scheduleTimes: List<Pair<String, LocalTime>>,
    onScheduleChange: (ScheduleType) -> Unit,
    onTimeClick: (Int) -> Unit,
    onRemoveTime: (Int) -> Unit,
    onAddTime: () -> Unit
) {
    val view = LocalView.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            "How often do you take it?",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 36.sp
        )

        Text(
            "Select frequency and set times",
            fontSize = 16.sp,
            color = AppColors.onSurface.copy(alpha = 0.6f)
        )

        Spacer(Modifier.height(8.dp))

        // Frequency options
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ScheduleType.entries.filter { it != ScheduleType.CUSTOM }.forEach { schedule ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            if (selectedSchedule == schedule) MedBrandBlue
                            else AppColors.onSurface.copy(alpha = 0.04f)
                        )
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            onScheduleChange(schedule)
                        }
                        .padding(20.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(
                                    if (selectedSchedule == schedule) Color.White.copy(alpha = 0.2f)
                                    else MedBrandBlue.copy(alpha = 0.1f)
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "${schedule.dosesPerDay}x",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (selectedSchedule == schedule) Color.White else MedBrandBlue
                            )
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                schedule.displayName,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (selectedSchedule == schedule) Color.White else AppColors.onSurface
                            )
                            Text(
                                "${schedule.dosesPerDay} ${if (schedule.dosesPerDay == 1) "dose" else "doses"} per day",
                                fontSize = 14.sp,
                                color = if (selectedSchedule == schedule) Color.White.copy(alpha = 0.8f)
                                       else AppColors.onSurface.copy(alpha = 0.6f)
                            )
                        }
                        if (selectedSchedule == schedule) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    }
                }
            }

            // Custom option
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (selectedSchedule == ScheduleType.CUSTOM) MedBrandBlue
                        else AppColors.onSurface.copy(alpha = 0.04f)
                    )
                    .clickable {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        onScheduleChange(ScheduleType.CUSTOM)
                    }
                    .padding(20.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(
                                if (selectedSchedule == ScheduleType.CUSTOM) Color.White.copy(alpha = 0.2f)
                                else MedBrandBlue.copy(alpha = 0.1f)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = null,
                            tint = if (selectedSchedule == ScheduleType.CUSTOM) Color.White else MedBrandBlue,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Custom",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (selectedSchedule == ScheduleType.CUSTOM) Color.White else AppColors.onSurface
                        )
                        Text(
                            "Set your own schedule",
                            fontSize = 14.sp,
                            color = if (selectedSchedule == ScheduleType.CUSTOM) Color.White.copy(alpha = 0.8f)
                                   else AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    if (selectedSchedule == ScheduleType.CUSTOM) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(8.dp))

        // Time slots
        Text(
            "Set times",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            scheduleTimes.forEachIndexed { index, (label, time) ->
                TimeSlotCard(
                    label = label,
                    time = time,
                    onClick = { onTimeClick(index) },
                    onRemove = if (selectedSchedule == ScheduleType.CUSTOM && scheduleTimes.size > 1) {
                        { onRemoveTime(index) }
                    } else null
                )
            }

            if (selectedSchedule == ScheduleType.CUSTOM) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(MedBrandBlue.copy(alpha = 0.08f))
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            onAddTime()
                        }
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = null,
                            tint = MedBrandBlue,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            "Add time slot",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            color = MedBrandBlue
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TimeSlotCard(
    label: String,
    time: LocalTime,
    onClick: () -> Unit,
    onRemove: (() -> Unit)?
) {
    val view = LocalView.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.onSurface.copy(alpha = 0.04f))
            .clickable {
                view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                onClick()
            }
            .padding(horizontal = 18.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                Icons.Default.Schedule,
                contentDescription = null,
                tint = MedBrandBlue,
                modifier = Modifier.size(22.dp)
            )
            Text(
                label,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface.copy(alpha = 0.7f)
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                formatTime12h(time),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            onRemove?.let {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Remove",
                    tint = Color(0xFFEF4444),
                    modifier = Modifier
                        .size(20.dp)
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            it()
                        }
                )
            }
        }
    }
}

// ── Step 5: Duration ──
@Composable
private fun StepDuration(
    durationMode: DurationMode,
    startDate: LocalDate,
    endDate: LocalDate,
    selectedPreset: DurationPreset?,
    totalQuantity: String,
    dosagePerIntake: String,
    calculatedDays: Int?,
    calculatedEndDate: LocalDate?,
    dosesPerDay: Int,
    dateFormatter: DateTimeFormatter,
    onModeChange: (DurationMode) -> Unit,
    onStartDateClick: () -> Unit,
    onEndDateClick: () -> Unit,
    onPresetSelected: (DurationPreset) -> Unit,
    onQuantityChange: (String) -> Unit,
    onDosagePerIntakeChange: (String) -> Unit
) {
    val view = LocalView.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            "How long will you take it?",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 36.sp
        )

        Text(
            "Set the treatment duration",
            fontSize = 16.sp,
            color = AppColors.onSurface.copy(alpha = 0.6f)
        )

        Spacer(Modifier.height(8.dp))

        // Start date
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(AppColors.onSurface.copy(alpha = 0.04f))
                .clickable {
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    onStartDateClick()
                }
                .padding(18.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(
                        Icons.Default.CalendarToday,
                        contentDescription = null,
                        tint = MedBrandBlue,
                        modifier = Modifier.size(22.dp)
                    )
                    Text(
                        "Start Date",
                        fontSize = 15.sp,
                        color = AppColors.onSurface.copy(alpha = 0.6f)
                    )
                }
                Text(
                    startDate.format(dateFormatter),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
            }
        }

        // Duration modes
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Ongoing
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (durationMode == DurationMode.ONGOING) MedBrandBlue
                        else AppColors.onSurface.copy(alpha = 0.04f)
                    )
                    .clickable {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        onModeChange(DurationMode.ONGOING)
                    }
                    .padding(20.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Icon(
                        Icons.Default.AllInclusive,
                        contentDescription = null,
                        tint = if (durationMode == DurationMode.ONGOING) Color.White else MedBrandBlue,
                        modifier = Modifier.size(28.dp)
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Ongoing",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (durationMode == DurationMode.ONGOING) Color.White else AppColors.onSurface
                        )
                        Text(
                            "No end date",
                            fontSize = 14.sp,
                            color = if (durationMode == DurationMode.ONGOING) Color.White.copy(alpha = 0.8f)
                                   else AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    if (durationMode == DurationMode.ONGOING) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }

            // Preset durations
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (durationMode == DurationMode.PRESET) MedBrandBlue
                        else AppColors.onSurface.copy(alpha = 0.04f)
                    )
                    .clickable {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        onModeChange(DurationMode.PRESET)
                    }
                    .padding(20.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Icon(
                        Icons.Default.Timer,
                        contentDescription = null,
                        tint = if (durationMode == DurationMode.PRESET) Color.White else MedBrandBlue,
                        modifier = Modifier.size(28.dp)
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Preset Duration",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (durationMode == DurationMode.PRESET) Color.White else AppColors.onSurface
                        )
                        Text(
                            "7, 14, 30 days, etc.",
                            fontSize = 14.sp,
                            color = if (durationMode == DurationMode.PRESET) Color.White.copy(alpha = 0.8f)
                                   else AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    if (durationMode == DurationMode.PRESET) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }

            // Manual end date
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (durationMode == DurationMode.MANUAL) MedBrandBlue
                        else AppColors.onSurface.copy(alpha = 0.04f)
                    )
                    .clickable {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        onModeChange(DurationMode.MANUAL)
                    }
                    .padding(20.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Icon(
                        Icons.Default.CalendarToday,
                        contentDescription = null,
                        tint = if (durationMode == DurationMode.MANUAL) Color.White else MedBrandBlue,
                        modifier = Modifier.size(28.dp)
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Set End Date",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (durationMode == DurationMode.MANUAL) Color.White else AppColors.onSurface
                        )
                        Text(
                            "Choose specific date",
                            fontSize = 14.sp,
                            color = if (durationMode == DurationMode.MANUAL) Color.White.copy(alpha = 0.8f)
                                   else AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    if (durationMode == DurationMode.MANUAL) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }

            // Quantity-based
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (durationMode == DurationMode.QUANTITY) MedBrandBlue
                        else AppColors.onSurface.copy(alpha = 0.04f)
                    )
                    .clickable {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        onModeChange(DurationMode.QUANTITY)
                    }
                    .padding(20.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Icon(
                        Icons.Default.Calculate,
                        contentDescription = null,
                        tint = if (durationMode == DurationMode.QUANTITY) Color.White else MedBrandBlue,
                        modifier = Modifier.size(28.dp)
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Based on Quantity",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (durationMode == DurationMode.QUANTITY) Color.White else AppColors.onSurface
                        )
                        Text(
                            "Total tablets/doses",
                            fontSize = 14.sp,
                            color = if (durationMode == DurationMode.QUANTITY) Color.White.copy(alpha = 0.8f)
                                   else AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    if (durationMode == DurationMode.QUANTITY) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }
        }

        // Mode-specific content
        AnimatedVisibility(
            visible = durationMode == DurationMode.PRESET,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(durationPresets) { preset ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(14.dp))
                                .background(
                                    if (selectedPreset == preset) MedBrandBlue
                                    else AppColors.onSurface.copy(alpha = 0.05f)
                                )
                                .clickable {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    onPresetSelected(preset)
                                }
                                .padding(horizontal = 18.dp, vertical = 12.dp)
                        ) {
                            Text(
                                preset.label,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (selectedPreset == preset) Color.White else AppColors.onSurface
                            )
                        }
                    }
                }
                selectedPreset?.let {
                    val presetEndDate = startDate.plusDays(it.days)
                    Text(
                        "Ends ${presetEndDate.format(dateFormatter)}",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                        color = MedTealGreen,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
        }

        AnimatedVisibility(
            visible = durationMode == DurationMode.MANUAL,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(AppColors.onSurface.copy(alpha = 0.04f))
                    .clickable {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        onEndDateClick()
                    }
                    .padding(18.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            Icons.Default.Event,
                            contentDescription = null,
                            tint = MedBrandBlue,
                            modifier = Modifier.size(22.dp)
                        )
                        Text(
                            "End Date",
                            fontSize = 15.sp,
                            color = AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    Text(
                        endDate.format(dateFormatter),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurface
                    )
                }
            }
        }

        AnimatedVisibility(
            visible = durationMode == DurationMode.QUANTITY,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = totalQuantity,
                    onValueChange = { onQuantityChange(it.filter { c -> c.isDigit() }) },
                    placeholder = {
                        Text(
                            "Total tablets",
                            color = AppColors.onSurface.copy(alpha = 0.4f),
                            fontSize = 16.sp
                        )
                    },
                    leadingIcon = {
                        Icon(
                            Icons.Default.Inventory2,
                            contentDescription = null,
                            tint = MedBrandBlue,
                            modifier = Modifier.size(24.dp)
                        )
                    },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color.Transparent,
                        unfocusedBorderColor = Color.Transparent,
                        focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                        unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                        focusedTextColor = AppColors.onSurface,
                        unfocusedTextColor = AppColors.onSurface
                    ),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth(),
                    textStyle = androidx.compose.ui.text.TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                )

                OutlinedTextField(
                    value = dosagePerIntake,
                    onValueChange = { onDosagePerIntakeChange(it.filter { c -> c.isDigit() }) },
                    placeholder = {
                        Text(
                            "Per dose",
                            color = AppColors.onSurface.copy(alpha = 0.4f),
                            fontSize = 16.sp
                        )
                    },
                    leadingIcon = {
                        Icon(
                            Icons.Default.Medication,
                            contentDescription = null,
                            tint = MedBrandBlue,
                            modifier = Modifier.size(24.dp)
                        )
                    },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color.Transparent,
                        unfocusedBorderColor = Color.Transparent,
                        focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                        unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                        focusedTextColor = AppColors.onSurface,
                        unfocusedTextColor = AppColors.onSurface
                    ),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth(),
                    textStyle = androidx.compose.ui.text.TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                )

                if (calculatedDays != null && calculatedEndDate != null) {
                    Text(
                        "$calculatedDays days — ends ${calculatedEndDate.format(dateFormatter)}",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                        color = MedTealGreen,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }
    }
}

// ── Step 6: Review ──
@Composable
private fun StepReview(
    name: String,
    dosage: String,
    dosageUnit: String,
    selectedType: MedicationType,
    selectedSchedule: ScheduleType,
    scheduleTimes: List<Pair<String, LocalTime>>,
    startDate: LocalDate,
    endDate: LocalDate?,
    isOngoing: Boolean,
    notes: String,
    dateFormatter: DateTimeFormatter,
    onNotesChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Text(
            "Review & Save",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 36.sp
        )

        Text(
            "Review your medication details",
            fontSize = 16.sp,
            color = AppColors.onSurface.copy(alpha = 0.6f)
        )

        Spacer(Modifier.height(8.dp))

        // Summary card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(AppColors.onSurface.copy(alpha = 0.04f))
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ReviewItem("Medication", name, Icons.Default.Medication)
            if (dosage.isNotBlank() || dosageUnit.isNotBlank()) {
                ReviewItem(
                    "Dosage",
                    buildString {
                        if (dosage.isNotBlank()) append(dosage)
                        if (dosageUnit.isNotBlank()) {
                            if (dosage.isNotBlank()) append(" ")
                            append(dosageUnit)
                        }
                    },
                    Icons.Default.Science
                )
            }
            ReviewItem("Type", selectedType.displayName, selectedType.toIcon())
            ReviewItem(
                "Schedule",
                "${selectedSchedule.displayName} (${scheduleTimes.size}x daily)",
                Icons.Default.Schedule
            )
            ReviewItem("Start Date", startDate.format(dateFormatter), Icons.Default.CalendarToday)
            if (isOngoing) {
                ReviewItem("Duration", "Ongoing", Icons.Default.AllInclusive)
            } else if (endDate != null) {
                ReviewItem("End Date", endDate.format(dateFormatter), Icons.Default.Event)
            }
        }

        // Time slots
        Text(
            "Times",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            scheduleTimes.forEach { (label, time) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(AppColors.onSurface.copy(alpha = 0.04f))
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        label,
                        fontSize = 15.sp,
                        color = AppColors.onSurface.copy(alpha = 0.7f)
                    )
                    Text(
                        formatTime12h(time),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurface
                    )
                }
            }
        }

        // Notes
        Text(
            "Notes (Optional)",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        OutlinedTextField(
            value = notes,
            onValueChange = onNotesChange,
            placeholder = {
                Text(
                    "Special instructions, take with food...",
                    color = AppColors.onSurface.copy(alpha = 0.4f),
                    fontSize = 15.sp
                )
            },
            minLines = 3,
            maxLines = 5,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                focusedTextColor = AppColors.onSurface,
                unfocusedTextColor = AppColors.onSurface
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun ReviewItem(
    label: String,
    value: String,
    icon: ImageVector
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MedBrandBlue,
            modifier = Modifier.size(20.dp)
        )
        Column {
            Text(
                label,
                fontSize = 13.sp,
                color = AppColors.onSurface.copy(alpha = 0.6f)
            )
            Text(
                value,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }
    }
}
