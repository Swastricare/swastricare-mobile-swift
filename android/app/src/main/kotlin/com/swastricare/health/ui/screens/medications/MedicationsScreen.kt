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
    onNavigateToAllMedications: () -> Unit = {},
    onNavigateToNotifications: () -> Unit = {},
    onNavigateToCalendar: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {}
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
    val showFullScreenError = uiState.error != null && uiState.medicationsWithDoses.isEmpty()
    LaunchedEffect(uiState.error, showFullScreenError) {
        val msg = uiState.error
        if (msg != null && !showFullScreenError) {
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            vm.clearError()
        }
    }

    Scaffold(
        containerColor = Color.White,
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        if (uiState.isLoading && uiState.medicationsWithDoses.isEmpty() && uiState.error == null) {
            Box(Modifier.padding(innerPadding)) {
                MedicationScreenSkeleton()
            }
        } else if (showFullScreenError) {
            MedicationLoadErrorView(
                message = uiState.error ?: "Something went wrong.",
                isRetrying = uiState.isLoading,
                onRetry = { vm.loadMedications() },
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
                        onCalendar = onNavigateToCalendar,
                        onAnalytics = onNavigateToAnalytics
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
                        enabled = uiState.remindersEnabled,
                        onToggle = { vm.setRemindersEnabled(it) },
                        onNavigateToNotifications = onNavigateToNotifications,
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

// ─────────────────────────────────────
// MARK: - Load Error View
// ─────────────────────────────────────

@Composable
private fun MedicationLoadErrorView(
    message: String,
    isRetrying: Boolean,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isOffline = message.contains("internet", ignoreCase = true) ||
        message.contains("network", ignoreCase = true) ||
        message.contains("connection", ignoreCase = true)
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = if (isOffline) Icons.Default.CloudOff else Icons.Default.ErrorOutline,
            contentDescription = null,
            tint = Color(0xFFFF6B6B),
            modifier = Modifier.size(56.dp)
        )
        Spacer(Modifier.height(16.dp))
        Text(
            if (isOffline) "You're offline" else "Couldn't load medications",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF1A1A2E),
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        Text(
            message,
            fontSize = 14.sp,
            color = Color(0xFF666666),
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onRetry,
            enabled = !isRetrying,
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            shape = RoundedCornerShape(24.dp),
            contentPadding = PaddingValues(horizontal = 28.dp, vertical = 12.dp)
        ) {
            if (isRetrying) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text("Retrying...", fontWeight = FontWeight.SemiBold)
            } else {
                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Retry", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
