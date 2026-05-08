package com.swastricare.health.ui.screens.medications

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationDose
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal

// ─────────────────────────────────────
// MARK: - MedicationsScreen
// ─────────────────────────────────────

@Composable
fun MedicationsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToAddMedication: () -> Unit,
    onNavigateToDetail: (String) -> Unit,
    onNavigateToAI: () -> Unit,
    onNavigateToAllMedications: () -> Unit = {}
) {
    TrackScreen("Medications")
    val vm: MedicationsViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    val isDark = isSystemInDarkTheme()

    var skipDialogDose by remember { mutableStateOf<MedicationDose?>(null) }
    var deleteMedicationId by remember { mutableStateOf<String?>(null) }
    var deleteMedicationName by remember { mutableStateOf("") }

    // Reload when screen resumes
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) vm.loadMedications()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Light status bar
    val view = LocalView.current
    if (!view.isInEditMode) {
        DisposableEffect(Unit) {
            val activity = view.context as? Activity ?: return@DisposableEffect onDispose {}
            val origStatus = activity.window.statusBarColor
            val origNav = activity.window.navigationBarColor
            activity.window.statusBarColor = android.graphics.Color.WHITE
            activity.window.navigationBarColor = android.graphics.Color.WHITE
            val ctrl = WindowCompat.getInsetsController(activity.window, view)
            ctrl.isAppearanceLightStatusBars = true
            ctrl.isAppearanceLightNavigationBars = true
            onDispose {
                activity.window.statusBarColor = origStatus
                activity.window.navigationBarColor = origNav
                WindowCompat.getInsetsController(activity.window, view).apply {
                    isAppearanceLightStatusBars = !isDark
                    isAppearanceLightNavigationBars = !isDark
                }
            }
        }
    }

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(uiState.error) {
        uiState.error?.let { msg ->
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            vm.clearError()
        }
    }

    Scaffold(
        containerColor = Color.White,
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        if (uiState.isLoading && uiState.medicationsWithDoses.isEmpty()) {
            Box(Modifier.padding(innerPadding)) {
                MedicationScreenSkeleton()
            }
        } else if (!uiState.isLoading && uiState.medicationsWithDoses.isEmpty()) {
            MedicationsEmptyContent(
                onAdd = onNavigateToAddMedication,
                modifier = Modifier.padding(innerPadding)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentPadding = PaddingValues(bottom = 32.dp)
            ) {
                // ── Hero ──
                item {
                    MedHeroSection(
                        onBack = onNavigateBack,
                        onAI = onNavigateToAI
                    )
                }

                // ── Stats ──
                item {
                    MedStatsRow(
                        toTake = uiState.statistics.pendingDoses,
                        taken  = uiState.statistics.takenDoses,
                        missed = uiState.statistics.missedDoses,
                        total  = uiState.medicationsWithDoses.size,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp)
                    )
                }

                // ── Today's Schedule ──
                item {
                    TodayScheduleHeader(
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
                    )
                }

                val doses = uiState.allDosesToday
                if (doses.isEmpty() && !uiState.isLoading) {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                Icons.Default.Medication,
                                contentDescription = null,
                                tint = Color(0xFFCCCCCC),
                                modifier = Modifier.size(40.dp)
                            )
                            Text(
                                "No doses scheduled today",
                                fontSize = 14.sp,
                                color = Color(0xFF888888),
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                } else {
                    itemsIndexed(
                        items = doses,
                        key = { _, d -> "${d.medicationId}-${d.scheduleId}-${d.scheduledTime}" }
                    ) { _, dose ->
                        ScheduleMedRow(
                            dose = dose,
                            onTaken = { vm.markAsTaken(dose) },
                            onSkip  = { skipDialogDose = dose },
                            onTap   = { onNavigateToDetail(dose.medicationId) },
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }
                }

                // ── Adherence + Medications ──
                item {
                    HorizontalDivider(
                        color = Color(0xFFF0F0F0),
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)
                    )
                    AdherenceAndMedsSection(
                        adherenceRate = uiState.statistics.adherenceRate,
                        medications   = uiState.medicationsWithDoses,
                        onAdd         = onNavigateToAddMedication,
                        onViewAll     = onNavigateToAllMedications,
                        modifier = Modifier.padding(horizontal = 20.dp)
                    )
                }

                // ── Enable Reminders ──
                item {
                    Spacer(Modifier.height(16.dp))
                    RemindersToggleCard(
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }
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

    // ── Delete Confirmation Dialog ──
    deleteMedicationId?.let { medId ->
        AlertDialog(
            onDismissRequest = { deleteMedicationId = null },
            title = { Text("Delete Medication") },
            text  = {
                Text("Are you sure you want to delete $deleteMedicationName? This will cancel all scheduled reminders.")
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteMedication(medId)
                    deleteMedicationId = null
                }) { Text("Delete", color = Color(0xFFFF3B30)) }
            },
            dismissButton = {
                TextButton(onClick = { deleteMedicationId = null }) { Text("Cancel") }
            }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────

@Composable
private fun MedicationsEmptyContent(onAdd: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        com.swastricare.health.ui.components.EmptyStateView(
            title = "No medications added",
            subtitle = "Tap + to add your first medication and set reminders.",
            illustrationAsset = "illustrations/medication - holding pill bottle .png"
        )
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onAdd,
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            shape = RoundedCornerShape(14.dp)
        ) {
            Icon(Icons.Default.Add, null, modifier = Modifier.size(18.dp), tint = Color.White)
            Spacer(Modifier.width(8.dp))
            Text("Add Medication", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
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
                Text("Skip", color = AITeal)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
