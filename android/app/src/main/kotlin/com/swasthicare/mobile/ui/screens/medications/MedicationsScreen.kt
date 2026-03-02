package com.swasthicare.mobile.ui.screens.medications

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.data.models.MedicationDose
import com.swasthicare.mobile.data.models.TimePeriod
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PrimaryColor
import java.time.LocalDate

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MedicationsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAddMedication: () -> Unit,
    onNavigateToDetail: (String) -> Unit,
    onNavigateToAI: () -> Unit
) {
    val vm = remember { AppContainer.medicationsViewModel }
    val uiState by vm.uiState.collectAsState()
    var skipDialogDose by remember { mutableStateOf<MedicationDose?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack,
                        contentDescription = "Back",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    text = "Medications",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onNavigateToAI) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        contentDescription = "Ask AI",
                        tint = PrimaryColor
                    )
                }
                IconButton(onClick = onNavigateToAddMedication) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .glass(cornerRadius = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = "Add Medication",
                            tint = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }

            // ── Date Strip ──
            DateStrip(
                selectedDate = uiState.selectedDate,
                onDateSelected = { vm.selectDate(it) }
            )

            Spacer(modifier = Modifier.height(16.dp))

            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = PrimaryColor)
                }
            } else if (uiState.medicationsWithDoses.isEmpty()) {
                EmptyMedicationsState(onAdd = onNavigateToAddMedication)
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(bottom = 120.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    // ── Progress Section ──
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 20.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            PillBottleProgress(
                                adherencePercentage = uiState.statistics.adherenceRate,
                                takenCount = uiState.statistics.takenDoses,
                                totalCount = uiState.statistics.totalDoses
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        StatPillsRow(
                            taken = uiState.statistics.takenDoses,
                            remaining = uiState.statistics.pendingDoses,
                            adherenceRate = uiState.statistics.adherenceRate
                        )
                        Spacer(modifier = Modifier.height(20.dp))
                    }

                    // ── Timeline by period ──
                    val periodOrder = listOf(
                        TimePeriod.MORNING,
                        TimePeriod.AFTERNOON,
                        TimePeriod.EVENING,
                        TimePeriod.NIGHT
                    )
                    val dosesByPeriod = uiState.dosesByPeriod
                    periodOrder.forEach { period ->
                        val doses = dosesByPeriod[period]
                        if (!doses.isNullOrEmpty()) {
                            item(key = period.name) {
                                TimelineGroup(
                                    label = period.label,
                                    doses = doses,
                                    onMarkTaken = { dose -> vm.markAsTaken(dose) },
                                    onMarkSkipped = { dose -> skipDialogDose = dose },
                                    onDoseClick = { dose -> onNavigateToDetail(dose.medicationId) }
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                            }
                        }
                    }
                }
            }
        }

        // Error snackbar
        uiState.error?.let { errorMsg ->
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp),
                action = {
                    TextButton(onClick = { vm.clearError() }) {
                        Text("Dismiss")
                    }
                }
            ) {
                Text(errorMsg)
            }
        }
    }

    // ── Skip Reason Dialog ──
    skipDialogDose?.let { dose ->
        SkipReasonDialog(
            medicationName = dose.medicationName,
            onConfirm = { reason ->
                vm.markAsSkipped(dose, reason)
                skipDialogDose = null
            },
            onDismiss = { skipDialogDose = null }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────

@Composable
private fun EmptyMedicationsState(onAdd: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("💊", style = MaterialTheme.typography.displayLarge)
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "No medications yet",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Add your first medication to start tracking your adherence",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            onClick = onAdd,
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor),
            shape = RoundedCornerShape(14.dp)
        ) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Add Medication")
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skip Reason Dialog
// ─────────────────────────────────────

@Composable
private fun SkipReasonDialog(
    medicationName: String,
    onConfirm: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    var reason by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Skip $medicationName?") },
        text = {
            OutlinedTextField(
                value = reason,
                onValueChange = { reason = it },
                label = { Text("Reason (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(reason.ifBlank { null }) }) {
                Text("Skip")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
