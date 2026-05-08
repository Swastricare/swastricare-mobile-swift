package com.swastricare.health.ui.screens.medications

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.swastricare.health.data.models.AdherenceStatus
import com.swastricare.health.data.models.MedicationDose
import com.swastricare.health.data.models.MedicationWithDoses
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - MedicationDetailScreen
// ─────────────────────────────────────

@Composable
fun MedicationDetailScreen(
    medicationId: String,
    onBack: () -> Unit
) {
    TrackScreen("MedicationDetail")
    val vm: MedicationsViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()

    var showDeleteDialog by remember { mutableStateOf(false) }
    var showEditDialog by remember { mutableStateOf(false) }
    var showMoreMenu by remember { mutableStateOf(false) }
    var showCalendarDialog by remember { mutableStateOf(false) }
    var showStatusDialog by remember { mutableStateOf(false) }
    var skipDialogDose by remember { mutableStateOf<MedicationDose?>(null) }

    var editName by remember { mutableStateOf("") }
    var editDosage by remember { mutableStateOf("") }
    var editNotes by remember { mutableStateOf("") }
    var editIsOngoing by remember { mutableStateOf(true) }

    val mwd = uiState.medicationsWithDoses.firstOrNull { it.medication.id == medicationId }

    LaunchedEffect(mwd) {
        mwd?.medication?.let { med ->
            editName = med.name
            editDosage = med.dosage ?: ""
            editNotes = med.notes ?: ""
            editIsOngoing = med.isOngoing
        }
    }

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
            }
        }
    }

    if (mwd == null) {
        Box(Modifier.fillMaxSize().background(Color.White), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = AITeal)
        }
        return
    }

    val med = mwd.medication
    val hasChanges = editName != med.name || editDosage != (med.dosage ?: "") ||
                     editNotes != (med.notes ?: "") || editIsOngoing != med.isOngoing

    Scaffold(
        containerColor = Color.White
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // ── Nav Bar ──
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color(0xFF1C1C1E))
                    }
                    Text(
                        "Medication Details",
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF1C1C1E)
                    )
                    Box {
                        IconButton(onClick = { showMoreMenu = true }) {
                            Icon(Icons.Default.MoreVert, null, tint = Color(0xFF1C1C1E))
                        }
                        DropdownMenu(
                            expanded = showMoreMenu,
                            onDismissRequest = { showMoreMenu = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text("Edit", fontSize = 15.sp) },
                                leadingIcon = { Icon(Icons.Default.Edit, null, tint = Color(0xFF007AFF)) },
                                onClick = { showMoreMenu = false; showEditDialog = true }
                            )
                            DropdownMenuItem(
                                text = { Text("Change Status", fontSize = 15.sp) },
                                leadingIcon = { Icon(Icons.Default.Tune, null, tint = AITeal) },
                                onClick = { showMoreMenu = false; showStatusDialog = true }
                            )
                            DropdownMenuItem(
                                text = { Text("Delete", fontSize = 15.sp, color = Color(0xFFFF3B30)) },
                                leadingIcon = { Icon(Icons.Default.Delete, null, tint = Color(0xFFFF3B30)) },
                                onClick = { showMoreMenu = false; showDeleteDialog = true }
                            )
                        }
                    }
                }
            }

            // ── Hero Card ──
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    shape = RoundedCornerShape(20.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White)
                ) {
                    Box(modifier = Modifier.fillMaxWidth()) {
                        // Banner background fills the card
                        AsyncImage(
                            model = "file:///android_asset/images/medication%20details%20screen%20banner.png",
                            contentDescription = null,
                            contentScale = ContentScale.FillWidth,
                            modifier = Modifier.fillMaxWidth()
                        )
                        // Content row overlaid on the banner
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .align(Alignment.CenterStart)
                                .padding(horizontal = 16.dp, vertical = 20.dp),
                            verticalAlignment = Alignment.Top,
                            horizontalArrangement = Arrangement.spacedBy(14.dp)
                        ) {
                            // Pill icon circle (overlays the banner's pill area)
                            Box(
                                modifier = Modifier
                                    .size(64.dp)
                                    .clip(CircleShape)
                                    .background(Color.White),
                                contentAlignment = Alignment.Center
                            ) {
                                AsyncImage(
                                    model = "file:///android_asset/icons/medicine%20icon.png",
                                    contentDescription = null,
                                    contentScale = ContentScale.Fit,
                                    modifier = Modifier.size(40.dp)
                                )
                            }
                            // Text content
                            Column(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Text(
                                    med.name,
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF1C1C1E)
                                )
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(7.dp)
                                            .clip(CircleShape)
                                            .background(Color(0xFF34C759))
                                    )
                                    Text(
                                        "Active",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Color(0xFF34C759)
                                    )
                                }
                                Spacer(Modifier.height(2.dp))
                                if (mwd.displayDosage.isNotBlank()) {
                                    Text(
                                        "${mwd.displayDosage} · ${mwd.type.displayName}",
                                        fontSize = 13.sp,
                                        color = Color(0xFF3C3C43).copy(alpha = 0.6f)
                                    )
                                }
                                med.notes?.takeIf { it.isNotBlank() }?.let {
                                    Text(
                                        it,
                                        fontSize = 12.sp,
                                        color = Color(0xFF3C3C43).copy(alpha = 0.5f),
                                        maxLines = 2,
                                        lineHeight = 17.sp
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ── Overview ──
            item {
                Spacer(Modifier.height(20.dp))
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Text("Overview", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
                    Spacer(Modifier.height(12.dp))
                    val firstTime = mwd.schedules.firstOrNull()?.let { sched ->
                        try {
                            java.time.LocalTime.parse(
                                sched.timeOfDay.take(8).padEnd(8, '0'),
                                DateTimeFormatter.ofPattern("HH:mm:ss")
                            ).format(DateTimeFormatter.ofPattern("h:mm a"))
                        } catch (_: Exception) { "" }
                    } ?: ""

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(Color.White)
                            .border(1.dp, Color(0xFFE5E5EA), RoundedCornerShape(14.dp))
                    ) {
                        OverviewCell(
                            icon = Icons.Default.DateRange,
                            iconTint = AITeal,
                            label = "Schedule",
                            value = if (mwd.schedules.size <= 1) "Every day" else "${mwd.schedules.size}× daily",
                            subValue = firstTime,
                            modifier = Modifier.weight(1f)
                        )
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(72.dp)
                                .align(Alignment.CenterVertically)
                                .background(Color(0xFFE5E5EA))
                        )
                        OverviewCell(
                            icon = Icons.Default.Medication,
                            iconTint = Color(0xFFFF9500),
                            label = "Dosage",
                            value = mwd.displayDosage.ifBlank { "—" },
                            subValue = mwd.type.displayName,
                            modifier = Modifier.weight(1f)
                        )
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(72.dp)
                                .align(Alignment.CenterVertically)
                                .background(Color(0xFFE5E5EA))
                        )
                        OverviewCell(
                            icon = Icons.Default.AccessTime,
                            iconTint = AITeal,
                            label = "Duration",
                            value = if (med.isOngoing) "Ongoing" else (med.endDate ?: "—"),
                            subValue = if (med.isOngoing) "(No end data)" else "",
                            modifier = Modifier.weight(1f)
                        )
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(72.dp)
                                .align(Alignment.CenterVertically)
                                .background(Color(0xFFE5E5EA))
                        )
                        OverviewCell(
                            icon = Icons.Default.NotificationsActive,
                            iconTint = Color(0xFF5856D6),
                            label = "Reminder",
                            value = if (mwd.schedules.any { it.reminderEnabled }) "On" else "Off",
                            subValue = "",
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // ── Today's Dose ──
            item {
                Spacer(Modifier.height(20.dp))
                TodayDoseSection(
                    mwd = mwd,
                    onTaken = { vm.markAsTaken(it) },
                    onSkip = { skipDialogDose = it }
                )
            }

            // ── Schedule ──
            item {
                Spacer(Modifier.height(20.dp))
                ScheduleSection(mwd = mwd, onViewCalendar = { showCalendarDialog = true })
            }

            // ── About ──
            med.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                item {
                    Spacer(Modifier.height(20.dp))
                    AboutSection(medName = med.name, notes = notes)
                }
            }
        }
    }

    // ── Edit Dialog ──
    if (showEditDialog) {
        AlertDialog(
            onDismissRequest = { showEditDialog = false },
            shape = RoundedCornerShape(20.dp),
            title = { Text("Edit Medication", fontWeight = FontWeight.SemiBold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = editName, onValueChange = { editName = it },
                        label = { Text("Name") }, singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AITeal),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = editDosage, onValueChange = { editDosage = it },
                        label = { Text("Dosage") }, singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AITeal),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = editNotes, onValueChange = { editNotes = it },
                        label = { Text("Notes") }, minLines = 2,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AITeal),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    if (hasChanges) {
                        vm.updateMedication(medicationId, editName, editDosage, editNotes.ifBlank { null }, editIsOngoing)
                    }
                    showEditDialog = false
                }) { Text("Save", color = AITeal, fontWeight = FontWeight.SemiBold) }
            },
            dismissButton = {
                TextButton(onClick = { showEditDialog = false }) { Text("Cancel", color = Color(0xFF8E8E93)) }
            }
        )
    }

    // ── Delete Dialog ──
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            shape = RoundedCornerShape(20.dp),
            title = { Text("Delete Medication", fontWeight = FontWeight.SemiBold) },
            text = { Text("Delete ${med.name}? This will also cancel all scheduled reminders.") },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteMedication(medicationId)
                    showDeleteDialog = false
                    onBack()
                }) { Text("Delete", color = Color(0xFFFF3B30), fontWeight = FontWeight.SemiBold) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel", color = Color(0xFF8E8E93)) }
            }
        )
    }

    // ── Skip Dose Dialog ──
    skipDialogDose?.let { dose ->
        var reason by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { skipDialogDose = null },
            shape = RoundedCornerShape(20.dp),
            title = { Text("Skip Dose?", fontWeight = FontWeight.SemiBold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        "Skip ${dose.medicationName} at ${
                            dose.scheduledTime.format(DateTimeFormatter.ofPattern("h:mm a"))
                        }?",
                        fontSize = 15.sp,
                        color = Color(0xFF3C3C43)
                    )
                    OutlinedTextField(
                        value = reason,
                        onValueChange = { reason = it },
                        label = { Text("Reason (optional)") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AITeal),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.markAsSkipped(dose, reason.ifBlank { null })
                    skipDialogDose = null
                }) { Text("Skip", color = Color(0xFFFF9500), fontWeight = FontWeight.SemiBold) }
            },
            dismissButton = {
                TextButton(onClick = { skipDialogDose = null }) { Text("Cancel", color = Color(0xFF8E8E93)) }
            }
        )
    }

    // ── Calendar Dialog ──
    if (showCalendarDialog) {
        AlertDialog(
            onDismissRequest = { showCalendarDialog = false },
            shape = RoundedCornerShape(20.dp),
            title = { Text("Medication Schedule", fontWeight = FontWeight.SemiBold) },
            text = {
                val today = LocalDate.now()
                val timeFmt = DateTimeFormatter.ofPattern("h:mm a")
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    mwd.schedules.forEach { sched ->
                        val timeStr = try {
                            java.time.LocalTime.parse(
                                sched.timeOfDay.take(8).padEnd(8, '0'),
                                DateTimeFormatter.ofPattern("HH:mm:ss")
                            ).format(timeFmt)
                        } catch (_: Exception) { sched.timeOfDay }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(AITeal.copy(alpha = 0.08f))
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Schedule, null, tint = AITeal, modifier = Modifier.size(18.dp))
                            Text(timeStr, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
                            Spacer(Modifier.weight(1f))
                            val dayLabel = sched.daysOfWeek?.let { days ->
                                if (days.size == 7) "Every day" else "Selected days"
                            } ?: "Every day"
                            Text(dayLabel, fontSize = 13.sp, color = Color(0xFF8E8E93))
                        }
                    }
                    if (mwd.medication.startDate != null) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "Started: ${mwd.medication.startDate}",
                            fontSize = 13.sp,
                            color = Color(0xFF8E8E93)
                        )
                    }
                    if (!mwd.medication.isOngoing && mwd.medication.endDate != null) {
                        Text(
                            "Ends: ${mwd.medication.endDate}",
                            fontSize = 13.sp,
                            color = Color(0xFF8E8E93)
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showCalendarDialog = false }) {
                    Text("Done", color = AITeal, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {}
        )
    }
}

// ─────────────────────────────────────
// MARK: - Overview Cell
// ─────────────────────────────────────

@Composable
private fun OverviewCell(
    icon: ImageVector,
    iconTint: Color,
    label: String,
    value: String,
    subValue: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(horizontal = 10.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, null, tint = iconTint, modifier = Modifier.size(22.dp))
        Spacer(Modifier.height(2.dp))
        Text(label, fontSize = 11.sp, color = Color(0xFF8E8E93))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E), textAlign = TextAlign.Center)
        if (subValue.isNotBlank()) {
            Text(subValue, fontSize = 11.sp, color = Color(0xFF8E8E93), textAlign = TextAlign.Center, maxLines = 1)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Today's Dose Section
// ─────────────────────────────────────

@Composable
private fun TodayDoseSection(
    mwd: MedicationWithDoses,
    onTaken: (MedicationDose) -> Unit,
    onSkip: (MedicationDose) -> Unit
) {
    val timeFmt = DateTimeFormatter.ofPattern("h:mm a")
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Text("Today's Dose", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
        Spacer(Modifier.height(12.dp))

        if (mwd.todayDoses.isEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color(0xFFF2F2F7))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(Icons.Default.Medication, null, tint = Color(0xFFCCCCCC), modifier = Modifier.size(30.dp))
                Text("No doses scheduled today", fontSize = 14.sp, color = Color(0xFF8E8E93))
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                mwd.todayDoses.forEach { dose ->
                    val isTaken = dose.status == AdherenceStatus.TAKEN
                    val isMissed = dose.status == AdherenceStatus.MISSED
                    val isSkipped = dose.status == AdherenceStatus.SKIPPED
                    val isPending = dose.status == AdherenceStatus.PENDING

                    val bgColor = when {
                        isTaken -> Color(0xFFEAFBF4)
                        isMissed -> Color(0xFFFFF0EF)
                        isSkipped -> Color(0xFFFFF8EE)
                        dose.isOverdue -> Color(0xFFFFF0EF)
                        else -> Color(0xFFF2F2F7)
                    }
                    val iconColor = when {
                        isTaken -> Color(0xFF34C759)
                        isMissed -> Color(0xFFFF3B30)
                        isSkipped -> Color(0xFFFF9500)
                        dose.isOverdue -> Color(0xFFFF3B30)
                        else -> Color(0xFFAAAAAA)
                    }
                    val title = when {
                        isTaken -> "Taken at ${dose.takenAt?.format(timeFmt) ?: dose.scheduledTime.format(timeFmt)}"
                        isMissed -> "Missed · ${dose.scheduledTime.format(timeFmt)}"
                        isSkipped -> "Skipped · ${dose.scheduledTime.format(timeFmt)}"
                        dose.isOverdue -> "Overdue · ${dose.scheduledTime.format(timeFmt)}"
                        else -> "Scheduled at ${dose.scheduledTime.format(timeFmt)}"
                    }
                    val subtitle = when {
                        isTaken -> "Good job! You've taken your medication."
                        isMissed -> "You missed this dose."
                        isSkipped -> dose.skipReason?.let { "Skipped: $it" } ?: "You skipped this dose."
                        else -> "${mwd.displayDosage} · ${mwd.type.displayName}"
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(bgColor)
                            .clickable {}
                            .padding(horizontal = 14.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Icon(
                            if (isTaken) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                            null,
                            tint = iconColor,
                            modifier = Modifier.size(34.dp)
                        )
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
                            Text(subtitle, fontSize = 13.sp, color = Color(0xFF8E8E93))
                        }
                        if (isPending) {
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                IconButton(onClick = { onTaken(dose) }, modifier = Modifier.size(36.dp)) {
                                    Icon(Icons.Default.CheckCircle, null, tint = AITeal, modifier = Modifier.size(28.dp))
                                }
                                IconButton(onClick = { onSkip(dose) }, modifier = Modifier.size(36.dp)) {
                                    Icon(Icons.Default.Cancel, null, tint = Color(0xFFFF9500), modifier = Modifier.size(24.dp))
                                }
                            }
                        } else {
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color(0xFFCCCCCC), modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Schedule Section
// ─────────────────────────────────────

@Composable
private fun ScheduleSection(mwd: MedicationWithDoses, onViewCalendar: () -> Unit = {}) {
    val today = LocalDate.now()
    val timeFmt = DateTimeFormatter.ofPattern("h:mm a")
    // MONDAY=1..SUNDAY=7 → map to Sun=0..Sat=6
    val todayIdx = today.dayOfWeek.value % 7
    val dayLetters = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Schedule", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
            Text("View calendar", fontSize = 14.sp, color = AITeal, modifier = Modifier.clickable { onViewCalendar() })
        }
        Spacer(Modifier.height(14.dp))

        // 7-day strip
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            dayLetters.forEachIndexed { idx, label ->
                val isToday = idx == todayIdx
                val hasDose = mwd.schedules.any { it.daysOfWeek?.contains(idx) ?: true }
                val isTakenToday = isToday && mwd.todayDoses.any { it.status == AdherenceStatus.TAKEN }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Text(
                        label,
                        fontSize = 11.sp,
                        color = if (isToday) AITeal else Color(0xFF8E8E93),
                        fontWeight = if (isToday) FontWeight.SemiBold else FontWeight.Normal
                    )
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(
                                when {
                                    isTakenToday -> AITeal
                                    isToday -> AITeal.copy(alpha = 0.12f)
                                    hasDose -> Color(0xFFF2F2F7)
                                    else -> Color.Transparent
                                }
                            )
                            .then(
                                if (isToday && !isTakenToday)
                                    Modifier.border(1.5.dp, AITeal, CircleShape)
                                else Modifier
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (isTakenToday) {
                            Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(14.dp))
        HorizontalDivider(color = Color(0xFFF2F2F7))
        Spacer(Modifier.height(14.dp))

        // Per-schedule rows
        mwd.schedules.forEach { sched ->
            val schedTime = try {
                java.time.LocalTime.parse(
                    sched.timeOfDay.take(8).padEnd(8, '0'),
                    DateTimeFormatter.ofPattern("HH:mm:ss")
                )
            } catch (_: Exception) { null }

            val timeStr = schedTime?.format(timeFmt) ?: sched.timeOfDay
            val schedHour = schedTime?.hour ?: -1

            val dose = mwd.todayDoses.firstOrNull { it.scheduledTime.hour == schedHour }
            val status = dose?.status ?: AdherenceStatus.PENDING

            val badgeText = when (status) {
                AdherenceStatus.TAKEN -> "✓ Taken"
                AdherenceStatus.MISSED -> "Missed"
                AdherenceStatus.SKIPPED -> "Skipped"
                else -> "Pending"
            }
            val badgeColor = when (status) {
                AdherenceStatus.TAKEN -> Color(0xFF34C759)
                AdherenceStatus.MISSED -> Color(0xFFFF3B30)
                AdherenceStatus.SKIPPED -> Color(0xFFFF9500)
                else -> Color(0xFF8E8E93)
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AITeal.copy(alpha = 0.1f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Schedule, null, tint = AITeal, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(timeStr, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
                    Text(
                        "${mwd.type.displayName} · ${mwd.displayDosage}".ifBlank { mwd.type.displayName },
                        fontSize = 12.sp,
                        color = Color(0xFF8E8E93)
                    )
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(badgeColor.copy(alpha = 0.12f))
                        .padding(horizontal = 10.dp, vertical = 5.dp)
                ) {
                    Text(badgeText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = badgeColor)
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - About Section
// ─────────────────────────────────────

@Composable
private fun AboutSection(medName: String, notes: String) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Text("About this medication", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Color(0xFFF2F2F7))
                .clickable {}
                .padding(16.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                "$medName $notes",
                modifier = Modifier.weight(1f),
                fontSize = 14.sp,
                color = Color(0xFF3C3C43),
                lineHeight = 20.sp,
                maxLines = 4
            )
            Spacer(Modifier.width(8.dp))
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                null,
                tint = Color(0xFFCCCCCC),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

