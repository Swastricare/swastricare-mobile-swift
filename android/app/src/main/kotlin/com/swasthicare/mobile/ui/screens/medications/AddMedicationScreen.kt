package com.swasthicare.mobile.ui.screens.medications

import android.app.TimePickerDialog
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.data.models.MedicationType
import com.swasthicare.mobile.data.models.ScheduleType
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PrimaryColor
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val medicationTypes = MedicationType.values().toList()
private val scheduleTypes = ScheduleType.values().toList()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddMedicationScreen(
    onDismiss: () -> Unit
) {
    val vm = remember { AppContainer.medicationsViewModel }

    // Step tracking
    var currentStep by remember { mutableIntStateOf(1) }
    val totalSteps = 3

    // Step 1 state
    var medicationName by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf(MedicationType.PILL) }
    var dosage by remember { mutableStateOf("") }
    var dosageUnit by remember { mutableStateOf("mg") }

    // Step 2 state
    var selectedSchedule by remember { mutableStateOf(ScheduleType.ONCE_DAILY) }
    var scheduleTimes by remember { mutableStateOf(listOf("08:00")) }

    // Step 3 state
    var startDate by remember { mutableStateOf(LocalDate.now()) }
    var endDate by remember { mutableStateOf<LocalDate?>(null) }
    var isOngoing by remember { mutableStateOf(true) }
    var notes by remember { mutableStateOf("") }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // ── Header ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
                Text(
                    text = "Add Medication",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = "Step $currentStep of $totalSteps",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
            }

            // ── Progress Bar ──
            LinearProgressIndicator(
                progress = { currentStep.toFloat() / totalSteps },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = PrimaryColor,
                trackColor = PrimaryColor.copy(alpha = 0.2f)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // ── Step Content ──
            Box(modifier = Modifier.weight(1f)) {
                when (currentStep) {
                    1 -> Step1MedicationInfo(
                        name = medicationName,
                        onNameChange = { medicationName = it },
                        selectedType = selectedType,
                        onTypeSelect = { selectedType = it },
                        dosage = dosage,
                        onDosageChange = { dosage = it },
                        dosageUnit = dosageUnit,
                        onUnitChange = { dosageUnit = it }
                    )
                    2 -> Step2Schedule(
                        selectedSchedule = selectedSchedule,
                        onScheduleSelect = { type ->
                            selectedSchedule = type
                            // Reset times to match new frequency
                            val defaults = listOf("08:00", "14:00", "20:00")
                            scheduleTimes = when (type) {
                                ScheduleType.ONCE_DAILY -> listOf("08:00")
                                ScheduleType.TWICE_DAILY -> listOf("08:00", "20:00")
                                ScheduleType.THRICE_DAILY -> defaults
                                ScheduleType.CUSTOM -> scheduleTimes
                            }
                        },
                        scheduleTimes = scheduleTimes,
                        onTimeChange = { index, newTime ->
                            scheduleTimes = scheduleTimes.toMutableList().also { it[index] = newTime }
                        },
                        onAddTime = { scheduleTimes = scheduleTimes + "12:00" },
                        onRemoveTime = { index ->
                            if (scheduleTimes.size > 1) {
                                scheduleTimes = scheduleTimes.filterIndexed { i, _ -> i != index }
                            }
                        }
                    )
                    3 -> Step3Duration(
                        startDate = startDate,
                        onStartDateChange = { startDate = it },
                        endDate = endDate,
                        onEndDateChange = { endDate = it },
                        isOngoing = isOngoing,
                        onOngoingChange = { isOngoing = it },
                        notes = notes,
                        onNotesChange = { notes = it }
                    )
                }
            }

            // ── Navigation Buttons ──
            val isNextEnabled = (currentStep == 1 && medicationName.isNotBlank()) ||
                                 currentStep == 2 ||
                                 currentStep == 3
            if (currentStep > 1) {
                // Back + Next side-by-side
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedButton(
                        onClick = { currentStep-- },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Text("Back")
                    }
                    Button(
                        onClick = {
                            if (currentStep < totalSteps) {
                                currentStep++
                            } else {
                                vm.addMedication(
                                    name = medicationName,
                                    dosage = dosage,
                                    dosageUnit = dosageUnit,
                                    type = selectedType,
                                    scheduleType = selectedSchedule,
                                    scheduleTimes = scheduleTimes.map { "$it:00" },
                                    startDate = startDate,
                                    endDate = if (isOngoing) null else endDate,
                                    isOngoing = isOngoing,
                                    notes = notes.ifBlank { null }
                                )
                                onDismiss()
                            }
                        },
                        enabled = isNextEnabled,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
                    ) {
                        Text(if (currentStep < totalSteps) "Next" else "Save Medication")
                    }
                }
            } else {
                // Step 1: Next fills full width
                Button(
                    onClick = { currentStep++ },
                    enabled = isNextEnabled,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 16.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
                ) {
                    Text("Next")
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 1: Medication Info
// ─────────────────────────────────────

@Composable
private fun Step1MedicationInfo(
    name: String,
    onNameChange: (String) -> Unit,
    selectedType: MedicationType,
    onTypeSelect: (MedicationType) -> Unit,
    dosage: String,
    onDosageChange: (String) -> Unit,
    dosageUnit: String,
    onUnitChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "What medication?",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )

        OutlinedTextField(
            value = name,
            onValueChange = onNameChange,
            label = { Text("Medication Name") },
            placeholder = { Text("e.g. Metformin") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            singleLine = true
        )

        // Type Grid
        Text("Type", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        TypeGrid(selectedType = selectedType, onTypeSelect = onTypeSelect)

        // Dosage row
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            OutlinedTextField(
                value = dosage,
                onValueChange = onDosageChange,
                label = { Text("Dosage Amount") },
                placeholder = { Text("500") },
                modifier = Modifier.weight(0.6f),
                shape = RoundedCornerShape(14.dp),
                singleLine = true
            )
            OutlinedTextField(
                value = dosageUnit,
                onValueChange = onUnitChange,
                label = { Text("Unit") },
                placeholder = { Text("mg") },
                modifier = Modifier.weight(0.4f),
                shape = RoundedCornerShape(14.dp),
                singleLine = true
            )
        }

        Spacer(modifier = Modifier.height(20.dp))
    }
}

@Composable
private fun TypeGrid(selectedType: MedicationType, onTypeSelect: (MedicationType) -> Unit) {
    val chunked = medicationTypes.chunked(4)
    chunked.forEach { row ->
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            row.forEach { type ->
                val isSelected = type == selectedType
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .aspectRatio(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (isSelected) PrimaryColor.copy(alpha = 0.2f)
                            else Color.White.copy(alpha = 0.05f)
                        )
                        .border(
                            1.dp,
                            if (isSelected) PrimaryColor else Color.White.copy(alpha = 0.1f),
                            RoundedCornerShape(12.dp)
                        )
                        .clickable { onTypeSelect(type) },
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(type.emoji, style = MaterialTheme.typography.headlineSmall)
                        Text(
                            type.displayName,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (isSelected) PrimaryColor
                                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }
            }
            // fill empty slots
            repeat(4 - row.size) {
                Spacer(modifier = Modifier.weight(1f))
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 2: Schedule
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Step2Schedule(
    selectedSchedule: ScheduleType,
    onScheduleSelect: (ScheduleType) -> Unit,
    scheduleTimes: List<String>,
    onTimeChange: (Int, String) -> Unit,
    onAddTime: () -> Unit,
    onRemoveTime: (Int) -> Unit
) {
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "How often?",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )

        // Schedule chips
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            scheduleTypes.forEach { type ->
                FilterChip(
                    selected = type == selectedSchedule,
                    onClick = { onScheduleSelect(type) },
                    label = { Text(type.displayName, style = MaterialTheme.typography.labelMedium) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = PrimaryColor.copy(alpha = 0.2f),
                        selectedLabelColor = PrimaryColor
                    )
                )
            }
        }

        // Time pickers
        Text("Times", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        scheduleTimes.forEachIndexed { index, time ->
            TimePickerRow(
                time = time,
                onPickTime = {
                    val parts = time.split(":")
                    val h = parts.getOrNull(0)?.toIntOrNull() ?: 8
                    val m = parts.getOrNull(1)?.toIntOrNull() ?: 0
                    TimePickerDialog(context, { _, hour, minute ->
                        onTimeChange(index, String.format("%02d:%02d", hour, minute))
                    }, h, m, false).show()
                },
                showRemove = scheduleTimes.size > 1 && selectedSchedule == ScheduleType.CUSTOM,
                onRemove = { onRemoveTime(index) }
            )
        }
        if (selectedSchedule == ScheduleType.CUSTOM) {
            TextButton(onClick = onAddTime) {
                Text("+ Add time slot")
            }
        }

        Spacer(modifier = Modifier.height(20.dp))
    }
}

@Composable
private fun TimePickerRow(
    time: String,
    onPickTime: () -> Unit,
    showRemove: Boolean,
    onRemove: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .glass(cornerRadius = 14.dp)
                .clickable { onPickTime() }
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            val parts = time.split(":")
            val h = parts.getOrNull(0)?.toIntOrNull() ?: 8
            val m = parts.getOrNull(1)?.toIntOrNull() ?: 0
            val ampm = if (h < 12) "AM" else "PM"
            val displayH = if (h == 0) 12 else if (h > 12) h - 12 else h
            Text(
                text = String.format("%d:%02d %s", displayH, m, ampm),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
        }
        if (showRemove) {
            IconButton(onClick = onRemove) {
                Icon(Icons.Default.Close, contentDescription = "Remove", modifier = Modifier.size(18.dp))
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 3: Duration & Notes
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Step3Duration(
    startDate: LocalDate,
    onStartDateChange: (LocalDate) -> Unit,
    endDate: LocalDate?,
    onEndDateChange: (LocalDate?) -> Unit,
    isOngoing: Boolean,
    onOngoingChange: (Boolean) -> Unit,
    notes: String,
    onNotesChange: (String) -> Unit
) {
    val dateFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Duration & Notes",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )

        // Start date display (non-interactive for simplicity; DatePicker would need a dialog)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 14.dp)
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    "Start Date",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
                Text(
                    startDate.format(dateFormatter),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        // Ongoing toggle
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 14.dp)
                .padding(horizontal = 16.dp, vertical = 4.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Ongoing medication", style = MaterialTheme.typography.bodyMedium)
                Switch(
                    checked = isOngoing,
                    onCheckedChange = onOngoingChange,
                    colors = SwitchDefaults.colors(checkedThumbColor = PrimaryColor)
                )
            }
        }

        // End date (shown only if not ongoing)
        if (!isOngoing) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .glass(cornerRadius = 14.dp)
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        "End Date",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                    Text(
                        endDate?.format(dateFormatter) ?: "Not set",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = if (endDate == null) MaterialTheme.colorScheme.onSurface.copy(0.4f)
                                else MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        // Notes
        OutlinedTextField(
            value = notes,
            onValueChange = onNotesChange,
            label = { Text("Notes (optional)") },
            placeholder = { Text("e.g. Take with food") },
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp),
            shape = RoundedCornerShape(14.dp),
            maxLines = 4
        )

        Spacer(modifier = Modifier.height(20.dp))
    }
}
