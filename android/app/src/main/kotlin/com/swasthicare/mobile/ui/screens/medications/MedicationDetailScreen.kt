package com.swasthicare.mobile.ui.screens.medications

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.MedicationWithDoses
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PrimaryColor
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MedicationDetailScreen(
    medicationId: String,
    onBack: () -> Unit
) {
    val vm = remember { AppContainer.medicationsViewModel }
    val uiState by vm.uiState.collectAsState()
    var showDeleteDialog by remember { mutableStateOf(false) }

    val mwd = uiState.medicationsWithDoses.firstOrNull { it.medication.id == medicationId }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        if (mwd == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = PrimaryColor)
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding(),
                contentPadding = PaddingValues(bottom = 120.dp)
            ) {
                // ── Top Bar ──
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                        Text(
                            text = mwd.medication.name,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.weight(1f)
                        )
                        IconButton(onClick = { showDeleteDialog = true }) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = "Delete",
                                tint = Color(0xFFFF3B30)
                            )
                        }
                    }
                }

                // ── Medication Info Card ──
                item {
                    MedicationInfoCard(mwd = mwd)
                    Spacer(modifier = Modifier.height(16.dp))
                }

                // ── 7-day Adherence Chart ──
                item {
                    AdherenceChartCard()
                    Spacer(modifier = Modifier.height(16.dp))
                }

                // ── Today's Log History ──
                item {
                    Text(
                        "Today's Doses",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 20.dp)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }

                if (mwd.todayDoses.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 20.dp)
                                .glass(cornerRadius = 16.dp)
                                .padding(20.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "No doses scheduled for today",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                        }
                    }
                } else {
                    items(mwd.todayDoses) { dose ->
                        DoseLogRow(dose = dose, modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp))
                    }
                }
            }
        }
    }

    // Delete confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Medication?") },
            text = {
                Text("This will discontinue ${mwd?.medication?.name}. All logs will be kept.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        vm.deleteMedication(medicationId)
                        showDeleteDialog = false
                        onBack()
                    }
                ) {
                    Text("Delete", color = Color(0xFFFF3B30))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            }
        )
    }
}

// ─────────────────────────────────────
// MARK: - Medication Info Card
// ─────────────────────────────────────

@Composable
private fun MedicationInfoCard(mwd: MedicationWithDoses) {
    val dateFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")
    val med = mwd.medication
    val schedules = mwd.schedules

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Type + name
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(mwd.type.emoji, style = MaterialTheme.typography.headlineMedium)
                Column {
                    Text(
                        med.name,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    if (mwd.displayDosage.isNotBlank()) {
                        Text(
                            mwd.displayDosage,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))

            // Schedule summary
            if (schedules.isNotEmpty()) {
                InfoRow("Schedule", schedules.joinToString(", ") { s ->
                    val parts = s.timeOfDay.split(":")
                    val h = parts[0].toIntOrNull() ?: 0
                    val m = parts.getOrNull(1)?.toIntOrNull() ?: 0
                    val ampm = if (h < 12) "AM" else "PM"
                    val dh = if (h == 0) 12 else if (h > 12) h - 12 else h
                    String.format("%d:%02d %s", dh, m, ampm)
                })
            }

            // Start/end
            med.startDate?.let { InfoRow("Started", it) }
            if (!med.isOngoing && med.endDate != null) {
                InfoRow("Ends", med.endDate)
            } else if (med.isOngoing) {
                InfoRow("Duration", "Ongoing")
            }

            // Adherence today
            InfoRow("Today", "${mwd.takenCount}/${mwd.totalDoses} doses taken")

            // Notes
            med.notes?.takeIf { it.isNotBlank() }?.let {
                InfoRow("Notes", it)
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium
        )
    }
}

// ─────────────────────────────────────
// MARK: - Adherence Chart Card
// ─────────────────────────────────────

@Composable
private fun AdherenceChartCard() {
    val today = LocalDate.now()
    // Build 7-day labels and placeholder adherence data
    val weekDays = (6 downTo 0).map { daysAgo ->
        val date = today.minusDays(daysAgo.toLong())
        val label = date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(3)
        // In production, fetch real adherence per day; for now show today's as non-zero
        val rate = if (daysAgo == 0) 0.75f else 0f
        label to rate
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Column {
            Text(
                "7-Day Adherence",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.height(12.dp))
            AdherenceBarChart(weekDays = weekDays)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Dose Log Row
// ─────────────────────────────────────

@Composable
private fun DoseLogRow(dose: MedicationDose, modifier: Modifier = Modifier) {
    val timeFormatter = DateTimeFormatter.ofPattern("h:mm a")
    Box(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 14.dp)
            .padding(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                dose.scheduledTime.format(timeFormatter),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.width(64.dp)
            )
            StatusBadge(status = dose.status, isOverdue = dose.isOverdue)
            Spacer(modifier = Modifier.weight(1f))
            dose.takenAt?.let { taken ->
                Text(
                    "at ${taken.format(timeFormatter)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
            }
        }
    }
}
