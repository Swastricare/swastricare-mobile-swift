package com.swasthicare.mobile.ui.screens.medications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.IntrinsicSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.AdherenceStatus
import com.swasthicare.mobile.data.models.MedicationDose
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - Timeline Slot Model
// ─────────────────────────────────────

private data class TimelineSlot(
    val key: String,                 // "HH:mm" sort key
    val doses: List<MedicationDose>
) {
    val allTaken: Boolean get() = doses.all {
        it.status == AdherenceStatus.TAKEN ||
        it.status == AdherenceStatus.LATE ||
        it.status == AdherenceStatus.EARLY
    }
    val hasOverdue: Boolean get() = doses.any { it.isOverdue }
    val dotColor: Color get() = when {
        allTaken   -> Color(0xFF34C759)
        hasOverdue -> Color(0xFFFF3B30)
        else       -> Color(0xFF8E8E93).copy(alpha = 0.4f)
    }
    val formattedTime: String get() {
        val parts = key.split(":")
        val h = parts[0].toIntOrNull() ?: 0
        val m = parts.getOrNull(1)?.toIntOrNull() ?: 0
        val ampm = if (h < 12) "AM" else "PM"
        val dh = if (h == 0) 12 else if (h > 12) h - 12 else h
        return String.format("%d:%02d %s", dh, m, ampm)
    }
}

// ─────────────────────────────────────
// MARK: - MedicationsScreen
// ─────────────────────────────────────

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

    val isDark = isSystemInDarkTheme()
    val secondaryBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    val slotFormatter = remember { DateTimeFormatter.ofPattern("HH:mm") }
    val timelineSlots = remember(uiState.allDosesToday) {
        uiState.allDosesToday
            .groupBy { it.scheduledTime.format(slotFormatter) }
            .entries
            .sortedBy { it.key }
            .map { (key, doses) -> TimelineSlot(key, doses) }
    }

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
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.Default.ArrowBack, "Back",
                        tint = MaterialTheme.colorScheme.onSurface)
                }
                Text(
                    "Medications",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 4.dp)
                )
                IconButton(onClick = onNavigateToAI) {
                    Icon(Icons.Default.AutoAwesome, "Ask AI", tint = MedBrandBlue)
                }
                IconButton(onClick = onNavigateToAddMedication) {
                    Icon(
                        Icons.Default.Add, "Add Medication",
                        tint = MedBrandBlue,
                        modifier = Modifier.size(26.dp)
                    )
                }
            }

            // ── Content ──
            when {
                uiState.isLoading -> {
                    MedicationsSkeletonContent()
                }
                uiState.medicationsWithDoses.isEmpty() -> {
                    MedicationsEmptyContent(onAdd = onNavigateToAddMedication)
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        // ── Calendar Strip ──
                        item {
                            Spacer(Modifier.height(8.dp))
                            CalendarStrip(
                                selectedDate = uiState.selectedDate,
                                onDateSelected = { vm.selectDate(it) }
                            )
                            Spacer(Modifier.height(16.dp))
                        }

                        // ── Progress Card (opaque secondarySystemBackground) ──
                        item {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(secondaryBg)
                                    .padding(20.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(16.dp)
                            ) {
                                Text(
                                    "Today's Progress",
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                                )
                                PillBottleView(progress = uiState.statistics.adherenceRate)
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    MedicationStatPill(
                                        icon = Icons.Default.CheckCircle,
                                        iconColor = MedTealGreen,
                                        value = "${uiState.statistics.takenDoses}",
                                        label = "taken",
                                        modifier = Modifier.weight(1f)
                                    )
                                    MedicationStatPill(
                                        icon = Icons.Default.Schedule,
                                        iconColor = Color(0xFFFF9500),
                                        value = "${uiState.statistics.pendingDoses}",
                                        label = "remaining",
                                        modifier = Modifier.weight(1f)
                                    )
                                    MedicationStatPill(
                                        icon = Icons.Default.ShowChart,
                                        iconColor = Color(0xFF34C759),
                                        value = "${(uiState.statistics.adherenceRate * 100).toInt()}%",
                                        label = "adherence",
                                        modifier = Modifier.weight(1f)
                                    )
                                }
                            }
                            Spacer(Modifier.height(20.dp))
                        }

                        // ── Timeline Section ──
                        item {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp, vertical = 8.dp)
                            ) {
                                timelineSlots.forEachIndexed { index, slot ->
                                    TimelineSlotRow(
                                        slot = slot,
                                        isLast = index == timelineSlots.lastIndex,
                                        onTaken = { dose -> vm.markAsTaken(dose) },
                                        onSkip  = { dose -> skipDialogDose = dose },
                                        onTap   = { dose -> onNavigateToDetail(dose.medicationId) }
                                    )
                                }
                            }
                        }

                        // ── Ask AI Button ──
                        item {
                            Spacer(Modifier.height(8.dp))
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(MedBrandBlue.copy(alpha = 0.08f))
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null
                                    ) { onNavigateToAI() }
                                    .padding(vertical = 12.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Icon(
                                        Icons.Default.AutoAwesome, null,
                                        tint = MedBrandBlue,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        "Ask AI about my medications",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MedBrandBlue
                                    )
                                }
                            }
                            Spacer(Modifier.height(24.dp))
                        }
                    }
                }
            }
        }

        // ── Error Snackbar ──
        uiState.error?.let { errorMsg ->
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp),
                action = {
                    TextButton(onClick = { vm.clearError() }) { Text("Dismiss") }
                }
            ) { Text(errorMsg) }
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
// MARK: - Timeline Slot Row
// ─────────────────────────────────────

@Composable
private fun TimelineSlotRow(
    slot: TimelineSlot,
    isLast: Boolean,
    onTaken: (MedicationDose) -> Unit,
    onSkip: (MedicationDose) -> Unit,
    onTap: (MedicationDose) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.Top
    ) {
        // Left column: time + dot + connecting line
        Column(
            modifier = Modifier
                .width(65.dp)
                .fillMaxHeight(),
            horizontalAlignment = Alignment.End
        ) {
            Text(
                text = slot.formattedTime,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.End,
                color = if (slot.hasOverdue) Color(0xFFFF3B30)
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
            Spacer(Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(slot.dotColor, CircleShape)
            )
            // Connecting line (not shown on last slot)
            if (!isLast) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .weight(1f)
                        .background(
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
                        )
                )
            } else {
                Spacer(Modifier.weight(1f))
            }
        }

        // Right column: medication cards
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(bottom = if (!isLast) 16.dp else 0.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            slot.doses.forEach { dose ->
                TimelineMedicationCard(
                    dose = dose,
                    onTaken = { onTaken(dose) },
                    onTap   = { onTap(dose) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skeleton Loading
// ─────────────────────────────────────

@Composable
private fun MedicationsSkeletonContent() {
    val shimmer = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.07f)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 8.dp)
    ) {
        // Calendar row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(7) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(Modifier.fillMaxWidth(0.7f).height(10.dp).clip(RoundedCornerShape(4.dp)).background(shimmer))
                    Box(Modifier.size(36.dp).clip(CircleShape).background(shimmer))
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        // Progress card
        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .height(220.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(shimmer)
        )
        Spacer(Modifier.height(20.dp))
        // Cards
        repeat(4) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 4.dp)
                    .height(72.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(shimmer)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────

@Composable
private fun MedicationsEmptyContent(onAdd: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.Medication, null,
            tint = MedBrandBlue.copy(alpha = 0.3f),
            modifier = Modifier.size(100.dp)
        )
        Spacer(Modifier.height(24.dp))
        Text(
            "No Medications Yet",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "Add your first medication to get started with reminders",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onAdd,
            colors = ButtonDefaults.buttonColors(containerColor = MedBrandBlue),
            shape = RoundedCornerShape(14.dp)
        ) {
            Icon(Icons.Default.Add, null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("Add Medication", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
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
                Text("Skip", color = Color(0xFFFF9500))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
