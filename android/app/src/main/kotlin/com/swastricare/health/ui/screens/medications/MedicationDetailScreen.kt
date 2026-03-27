package com.swastricare.health.ui.screens.medications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Note
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
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationDose
import com.swastricare.health.data.models.MedicationWithDoses
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors

// ─────────────────────────────────────
// MARK: - MedicationDetailScreen
// ─────────────────────────────────────

@Composable
fun MedicationDetailScreen(
    medicationId: String,
    onBack: () -> Unit
) {
    val vm: MedicationsViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    var isEditing by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var skipDialogDose by remember { mutableStateOf<MedicationDose?>(null) }

    val mwd = uiState.medicationsWithDoses.firstOrNull { it.medication.id == medicationId }

    // Edit form state (initialised from medication when it loads)
    var editName by remember { mutableStateOf("") }
    var editDosage by remember { mutableStateOf("") }
    var editNotes by remember { mutableStateOf("") }
    var editIsOngoing by remember { mutableStateOf(true) }

    LaunchedEffect(mwd) {
        mwd?.medication?.let { med ->
            editName = med.name
            editDosage = med.dosage ?: ""
            editNotes = med.notes ?: ""
            editIsOngoing = med.isOngoing
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {

        if (mwd == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = MedBrandBlue)
            }
        } else {
            val med = mwd.medication
            val hasChanges = editName != med.name ||
                             editDosage != (med.dosage ?: "") ||
                             editNotes != (med.notes ?: "") ||
                             editIsOngoing != med.isOngoing

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize(),
                contentPadding = PaddingValues(bottom = 40.dp)
            ) {
                // ── Top Bar ──
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextButton(onClick = {
                            if (isEditing) {
                                // Cancel editing — reset form
                                editName = med.name
                                editDosage = med.dosage ?: ""
                                editNotes = med.notes ?: ""
                                editIsOngoing = med.isOngoing
                                isEditing = false
                            } else {
                                onBack()
                            }
                        }) {
                            Text(
                                if (isEditing) "Cancel" else "Close",
                                fontSize = 16.sp,
                                color = AppColors.onSurface
                            )
                        }
                        Text(
                            if (isEditing) "Edit Medication" else "Medication Details",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f),
                            textAlign = TextAlign.Center
                        )
                        TextButton(onClick = {
                            if (isEditing) {
                                if (hasChanges) {
                                    vm.updateMedication(
                                        medicationId = medicationId,
                                        name = editName,
                                        dosage = editDosage,
                                        notes = editNotes.ifBlank { null },
                                        isOngoing = editIsOngoing
                                    )
                                    isEditing = false
                                }
                            } else {
                                isEditing = true
                            }
                        }) {
                            Text(
                                if (isEditing) "Save" else "Edit",
                                fontSize = 16.sp,
                                color = if (isEditing && !hasChanges)
                                    AppColors.onSurface.copy(alpha = 0.4f)
                                else MedBrandBlue
                            )
                        }
                    }
                }

                // ── Header Card ──
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .glass(cornerRadius = 18.dp)
                            .padding(horizontal = 16.dp, vertical = 20.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(64.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(MedBrandBlue.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = mwd.type.toIcon(),
                                contentDescription = null,
                                tint = MedBrandBlue,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(med.name,
                                fontSize = 22.sp, fontWeight = FontWeight.Bold)
                            if (mwd.displayDosage.isNotBlank()) {
                                Text(mwd.displayDosage, fontSize = 15.sp,
                                    color = AppColors.onSurface.copy(alpha = 0.5f))
                            }
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(Icons.Default.Schedule, null,
                                    tint = AppColors.onSurface.copy(alpha = 0.5f),
                                    modifier = Modifier.size(12.dp))
                                Text(
                                    "${mwd.schedules.size} time(s) daily",
                                    fontSize = 13.sp,
                                    color = AppColors.onSurface.copy(alpha = 0.5f)
                                )
                            }
                        }
                        Spacer(Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(20.dp))
                }

                // ── Today's Doses ──
                item {
                    Text(
                        "Today's Doses",
                        fontSize = 18.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                    Spacer(Modifier.height(12.dp))
                }

                if (mwd.todayDoses.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                                .glass(cornerRadius = 16.dp)
                                .padding(vertical = 32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Icon(
                                    Icons.Default.CalendarToday, null,
                                    tint = AppColors.onSurface.copy(alpha = 0.3f),
                                    modifier = Modifier.size(32.dp)
                                )
                                Text(
                                    "No doses scheduled for today",
                                    fontSize = 15.sp,
                                    color = AppColors.onSurface.copy(alpha = 0.5f)
                                )
                            }
                        }
                    }
                } else {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            mwd.todayDoses.forEach { dose ->
                                DoseCard(
                                    dose = dose,
                                    onMarkTaken = { vm.markAsTaken(dose) },
                                    onMarkSkipped = { skipDialogDose = dose }
                                )
                            }
                        }
                    }
                }

                item { Spacer(Modifier.height(20.dp)) }

                // ── Details or Edit Form ──
                if (isEditing) {
                    item {
                        EditFormSection(
                            name = editName, onNameChange = { editName = it },
                            dosage = editDosage, onDosageChange = { editDosage = it },
                            notes = editNotes, onNotesChange = { editNotes = it },
                            isOngoing = editIsOngoing, onIsOngoingChange = { editIsOngoing = it }
                        )
                        Spacer(Modifier.height(20.dp))
                    }
                } else {
                    item {
                        DetailsSection(mwd = mwd)
                        Spacer(Modifier.height(20.dp))
                    }
                }

                // ── Adherence Section ──
                item {
                    AdherenceSection(doses = mwd.todayDoses)
                    Spacer(Modifier.height(20.dp))
                }

                // ── Delete Button (always visible) ──
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .lightBorder(14.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Color(0xFFFF3B30).copy(alpha = 0.10f))
                            .clickable { showDeleteDialog = true }
                            .padding(vertical = 16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(Icons.Default.Delete, null,
                                tint = Color(0xFFFF3B30), modifier = Modifier.size(16.dp))
                            Text("Delete Medication",
                                fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                                color = Color(0xFFFF3B30))
                        }
                    }
                    Spacer(Modifier.height(20.dp))
                }
            }
        }
    }

    // ── Delete Dialog ──
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Medication") },
            text = {
                Text("Are you sure you want to delete ${mwd?.medication?.name}? This will also cancel all scheduled reminders.")
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteMedication(medicationId)
                    showDeleteDialog = false
                    onBack()
                }) { Text("Delete", color = Color(0xFFFF3B30)) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            }
        )
    }

    // ── Skip Dose Dialog ──
    skipDialogDose?.let { dose ->
        AlertDialog(
            onDismissRequest = { skipDialogDose = null },
            title = { Text("Skip Dose?") },
            text = {
                Text("Skip ${dose.medicationName} at ${
                    dose.scheduledTime.format(java.time.format.DateTimeFormatter.ofPattern("h:mm a"))
                }?")
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.markAsSkipped(dose, null)
                    skipDialogDose = null
                }) { Text("Skip", color = Color(0xFFFF9500)) }
            },
            dismissButton = {
                TextButton(onClick = { skipDialogDose = null }) { Text("Cancel") }
            }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Details Section
// ─────────────────────────────────────

@Composable
private fun DetailsSection(mwd: MedicationWithDoses) {
    val med = mwd.medication
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 18.dp)
            .padding(horizontal = 16.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Details", fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            DetailRow(
                label = "Type",
                value = mwd.type.displayName,
                icon = Icons.Default.Medication
            )
            DetailRow(
                label = "Schedule",
                value = "${mwd.schedules.size} time(s) daily",
                icon = Icons.Default.Schedule
            )
            if (med.isOngoing) {
                DetailRow(
                    label = "Duration",
                    value = "Ongoing",
                    icon = Icons.Default.AllInclusive
                )
            } else if (med.endDate != null) {
                DetailRow(
                    label = "End Date",
                    value = med.endDate,
                    icon = Icons.Default.CalendarToday
                )
            }
        }
        med.notes?.takeIf { it.isNotBlank() }?.let { notes ->
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.AutoMirrored.Filled.Note, null,
                        tint = AppColors.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier.size(14.dp))
                    Text("Notes", fontSize = 14.sp, fontWeight = FontWeight.Medium,
                        color = AppColors.onSurface.copy(alpha = 0.5f))
                }
                Text(notes, fontSize = 15.sp)
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Edit Form Section
// ─────────────────────────────────────

@Composable
private fun EditFormSection(
    name: String, onNameChange: (String) -> Unit,
    dosage: String, onDosageChange: (String) -> Unit,
    notes: String, onNotesChange: (String) -> Unit,
    isOngoing: Boolean, onIsOngoingChange: (Boolean) -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F7)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 18.dp)
            .padding(horizontal = 16.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text("Edit Details", fontSize = 18.sp, fontWeight = FontWeight.SemiBold)

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Name", fontSize = 14.sp, fontWeight = FontWeight.Medium,
                color = AppColors.onSurface.copy(alpha = 0.5f))
            OutlinedTextField(
                value = name, onValueChange = onNameChange,
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MedBrandBlue,
                    unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
                    focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                    unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f)
                ),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth()
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Dosage", fontSize = 14.sp, fontWeight = FontWeight.Medium,
                color = AppColors.onSurface.copy(alpha = 0.5f))
            OutlinedTextField(
                value = dosage, onValueChange = onDosageChange,
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MedBrandBlue,
                    unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
                    focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                    unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f)
                ),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth()
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Notes", fontSize = 14.sp, fontWeight = FontWeight.Medium,
                color = AppColors.onSurface.copy(alpha = 0.5f))
            OutlinedTextField(
                value = notes, onValueChange = onNotesChange,
                minLines = 3, maxLines = 5,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MedBrandBlue,
                    unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.1f),
                    focusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f),
                    unfocusedContainerColor = AppColors.onSurface.copy(alpha = 0.05f)
                ),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth()
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .lightBorder(14.dp)
                .clip(RoundedCornerShape(14.dp))
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
    }
}

// ─────────────────────────────────────
// MARK: - Adherence Section
// ─────────────────────────────────────

@Composable
private fun AdherenceSection(doses: List<MedicationDose>) {
    val taken   = doses.count { it.status == AdherenceStatus.TAKEN }
    val missed  = doses.count { it.status == AdherenceStatus.MISSED }
    val skipped = doses.count { it.status == AdherenceStatus.SKIPPED }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Text("Adherence History", fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 18.dp)
                .padding(horizontal = 16.dp, vertical = 20.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            MedicationStatCard(
                title = "Taken",
                value = "$taken",
                color = Color(0xFF34C759),
                modifier = Modifier.weight(1f)
            )
            MedicationStatCard(
                title = "Missed",
                value = "$missed",
                color = Color(0xFFFF3B30),
                modifier = Modifier.weight(1f)
            )
            MedicationStatCard(
                title = "Skipped",
                value = "$skipped",
                color = Color(0xFFFF9500),
                modifier = Modifier.weight(1f)
            )
        }
    }
}
