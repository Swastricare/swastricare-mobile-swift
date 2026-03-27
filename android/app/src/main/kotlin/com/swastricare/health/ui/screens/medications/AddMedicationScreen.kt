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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.MedicationType
import com.swastricare.health.data.models.ScheduleType
import com.swastricare.health.data.repository.DrugSearchResult
import androidx.hilt.navigation.compose.hiltViewModel
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
    val vm: MedicationsViewModel = hiltViewModel()

    // Drug search state
    val drugSuggestions by vm.drugSuggestions.collectAsState()
    val drugDetails = vm.drugDetails.collectAsState().value
    val isSearching by vm.isSearching.collectAsState()

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
    val canSave = name.isNotBlank()

    // Derive isOngoing and effective endDate for save
    val isOngoing = durationMode == DurationMode.ONGOING
    val effectiveEndDate = when (durationMode) {
        DurationMode.ONGOING -> null
        else -> endDate
    }

    Box(modifier = Modifier.fillMaxSize()) {

        Column(modifier = Modifier.fillMaxSize()) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = {
                    vm.clearDrugSearch()
                    onDismiss()
                }) {
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
                // ── Section 1: Name & Dosage (with Drug Search) ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    SectionLabel("Medication Details")

                    // Name field with search
                    Column {
                        MedTextField(
                            value = name,
                            onValueChange = {
                                name = it
                                if (suppressSearch) {
                                    suppressSearch = false
                                } else {
                                    vm.searchDrug(it)
                                }
                            },
                            placeholder = "Search or type medication name",
                            leadingIcon = Icons.Default.Search,
                            trailingContent = if (isSearching) {
                                {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(18.dp),
                                        strokeWidth = 2.dp,
                                        color = MedBrandBlue
                                    )
                                }
                            } else if (name.isNotBlank()) {
                                {
                                    Icon(
                                        Icons.Default.Close, "Clear",
                                        tint = AppColors.onSurface.copy(alpha = 0.4f),
                                        modifier = Modifier
                                            .size(18.dp)
                                            .clickable {
                                                name = ""
                                                vm.clearDrugSearch()
                                            }
                                    )
                                }
                            } else null
                        )

                        // Drug suggestions dropdown
                        AnimatedVisibility(
                            visible = drugSuggestions.isNotEmpty(),
                            enter = fadeIn() + expandVertically(),
                            exit = fadeOut() + shrinkVertically()
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 4.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(AppColors.surface)
                                    .border(
                                        1.dp,
                                        AppColors.onSurface.copy(alpha = 0.1f),
                                        RoundedCornerShape(12.dp)
                                    )
                            ) {
                                drugSuggestions.forEachIndexed { index, drug ->
                                    DrugSuggestionItem(
                                        drug = drug,
                                        onClick = {
                                            suppressSearch = true
                                            vm.clearDrugSearch()
                                            name = drug.displayName
                                            dosage = drug.dosage ?: ""
                                            dosageUnit = drug.dosageUnit ?: ""
                                            vm.selectDrug(drug)
                                        }
                                    )
                                    if (index < drugSuggestions.lastIndex) {
                                        HorizontalDivider(
                                            color = AppColors.onSurface.copy(alpha = 0.06f)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
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

                // ── Drug Info Card (from FDA) ──
                AnimatedVisibility(
                    visible = drugDetails != null,
                    enter = fadeIn() + expandVertically(),
                    exit = fadeOut() + shrinkVertically()
                ) {
                    drugDetails?.let { details ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .glass(cornerRadius = 16.dp)
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            SectionLabel("Drug Information (FDA)")

                            details.description?.let { desc ->
                                DrugInfoRow(
                                    icon = Icons.Default.Info,
                                    label = "Indications",
                                    text = desc,
                                    color = MedBrandBlue
                                )
                            }
                            details.warnings?.let { warn ->
                                DrugInfoRow(
                                    icon = Icons.Default.Warning,
                                    label = "Warnings",
                                    text = warn,
                                    color = Color(0xFFEF4444)
                                )
                            }
                        }
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

                    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        items(MedicationType.entries.toList()) { type ->
                            TypeChip(
                                type = type,
                                isSelected = selectedType == type,
                                onClick = { selectedType = type }
                            )
                        }
                    }
                }

                // ── Section 3: Schedule & Time Customization ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SectionLabel("Schedule")

                    // Frequency chips
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        FrequencyChip("1x", "Once", selectedSchedule == ScheduleType.ONCE_DAILY,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.ONCE_DAILY }
                        FrequencyChip("2x", "Twice", selectedSchedule == ScheduleType.TWICE_DAILY,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.TWICE_DAILY }
                        FrequencyChip("3x", "Thrice", selectedSchedule == ScheduleType.THRICE_DAILY,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.THRICE_DAILY }
                        FrequencyChip("⚙", "Custom", selectedSchedule == ScheduleType.CUSTOM,
                            Modifier.weight(1f)) { selectedSchedule = ScheduleType.CUSTOM }
                    }

                    // Editable time slots
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        scheduleTimes.forEachIndexed { index, (label, time) ->
                            EditableTimeRow(
                                label = label,
                                time = time,
                                onClick = { showTimePickerForIndex = index },
                                onRemove = if (selectedSchedule == ScheduleType.CUSTOM && scheduleTimes.size > 1) {
                                    { scheduleTimes = scheduleTimes.toMutableList().apply { removeAt(index) } }
                                } else null
                            )
                        }
                    }

                    // Add time slot button (custom only)
                    if (selectedSchedule == ScheduleType.CUSTOM) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .border(
                                    1.dp,
                                    MedBrandBlue.copy(alpha = 0.2f),
                                    RoundedCornerShape(10.dp)
                                )
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null
                                ) {
                                    val nextIndex = scheduleTimes.size
                                    val nextTime = LocalTime.of(
                                        ((scheduleTimes.lastOrNull()?.second?.hour ?: 7) + 4).coerceAtMost(23),
                                        0
                                    )
                                    scheduleTimes = scheduleTimes + (labelForIndex(nextIndex) to nextTime)
                                }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Add, null,
                                tint = MedBrandBlue,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                "Add Time Slot",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MedBrandBlue
                            )
                        }
                    }
                }

                // ── Section 4: Duration (Full Customization) ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .glass(cornerRadius = 16.dp)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SectionLabel("Duration")

                    // Start date (always visible)
                    DateRow(
                        label = "Start Date",
                        dateText = startDate.format(dateFormatter),
                        onClick = { showStartDatePicker = true }
                    )

                    // Duration mode selector — 2x2 grid
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DurationModeChip(
                                label = "Ongoing",
                                icon = Icons.Default.AllInclusive,
                                isSelected = durationMode == DurationMode.ONGOING,
                                modifier = Modifier.weight(1f),
                                onClick = { durationMode = DurationMode.ONGOING }
                            )
                            DurationModeChip(
                                label = "Preset",
                                icon = Icons.Default.Timer,
                                isSelected = durationMode == DurationMode.PRESET,
                                modifier = Modifier.weight(1f),
                                onClick = { durationMode = DurationMode.PRESET }
                            )
                        }
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            DurationModeChip(
                                label = "End Date",
                                icon = Icons.Default.CalendarToday,
                                isSelected = durationMode == DurationMode.MANUAL,
                                modifier = Modifier.weight(1f),
                                onClick = { durationMode = DurationMode.MANUAL }
                            )
                            DurationModeChip(
                                label = "Quantity",
                                icon = Icons.Default.Calculate,
                                isSelected = durationMode == DurationMode.QUANTITY,
                                modifier = Modifier.weight(1f),
                                onClick = { durationMode = DurationMode.QUANTITY }
                            )
                        }
                    }

                    // ── Preset Durations ──
                    AnimatedVisibility(
                        visible = durationMode == DurationMode.PRESET,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                items(durationPresets) { preset ->
                                    PresetChip(
                                        preset = preset,
                                        isSelected = selectedPreset == preset,
                                        onClick = { selectedPreset = preset }
                                    )
                                }
                            }

                            // Show computed end date
                            selectedPreset?.let { preset ->
                                val presetEndDate = startDate.plusDays(preset.days)
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
                                        Icons.Default.EventAvailable, null,
                                        tint = MedTealGreen,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Text(
                                        "Ends ${presetEndDate.format(dateFormatter)}",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MedTealGreen
                                    )
                                }
                            }
                        }
                    }

                    // ── Manual End Date ──
                    AnimatedVisibility(
                        visible = durationMode == DurationMode.MANUAL,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()
                    ) {
                        DateRow(
                            label = "End Date",
                            dateText = endDate.format(dateFormatter),
                            onClick = { showEndDatePicker = true }
                        )
                    }

                    // ── Quantity Calculation ──
                    AnimatedVisibility(
                        visible = durationMode == DurationMode.QUANTITY,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
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
                                            "$totalTablets tablets  x  $perIntake per dose  x  ${dosesPerDay}x/day",
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
                                scheduleTimes = scheduleTimes.map { (_, time) -> timeToDbString(time) },
                                startDate = startDate,
                                endDate = effectiveEndDate,
                                isOngoing = isOngoing,
                                notes = notes.ifBlank { null }
                            )
                            vm.clearDrugSearch()
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
            unfocusedContainerColor = Color.Transparent
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
