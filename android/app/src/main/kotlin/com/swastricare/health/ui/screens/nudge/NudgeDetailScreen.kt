package com.swastricare.health.ui.screens.nudge

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.LocalDrink
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material.icons.outlined.Monitor
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.theme.AITeal

private val PageBg = Color.White
private val OnSurface = Color(0xFF111827)
private val SubtitleColor = Color(0xFF6B7280)
private val DividerColor = Color(0xFFEFF1F4)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NudgeDetailScreen(
    nudgeId: String,
    onNavigateBack: () -> Unit,
) {
    val vm: NudgeDetailViewModel = hiltViewModel()
    val state by vm.state.collectAsState()

    LaunchedEffect(nudgeId) { vm.load(nudgeId) }

    Scaffold(
        containerColor = PageBg,
        topBar = {
            TopAppBar(
                title = {
                    Text("Nudge", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = OnSurface)
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = OnSurface)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PageBg),
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(PageBg)
                .padding(padding),
        ) {
            when {
                state.isLoading -> Loading()
                state.error != null -> ErrorState(state.error!!, onNavigateBack)
                state.nudge != null -> Content(
                    nudge = state.nudge!!,
                    isActing = state.isActing,
                    onMarkActedOn = { vm.markActedOn(onDone = onNavigateBack) },
                    onDismiss = { vm.dismiss(onDone = onNavigateBack) },
                )
            }
        }
    }
}

@Composable
private fun Loading() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = AITeal)
    }
}

@Composable
private fun ErrorState(message: String, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Couldn't open nudge", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = OnSurface)
        Spacer(Modifier.height(6.dp))
        Text(message, fontSize = 13.sp, color = SubtitleColor)
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal, contentColor = Color.White),
            shape = RoundedCornerShape(12.dp),
        ) { Text("Go back", fontWeight = FontWeight.SemiBold) }
    }
}

@Composable
private fun Content(
    nudge: com.swastricare.health.data.repository.NudgeDetail,
    isActing: Boolean,
    onMarkActedOn: () -> Unit,
    onDismiss: () -> Unit,
) {
    val (icon, accent) = iconAndAccentFor(nudge.nudgeType)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Hero circle with category icon
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(accent.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(30.dp))
            }
            Spacer(Modifier.size(14.dp))
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    nudge.title.ifBlank { friendlyTypeLabel(nudge.nudgeType) },
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = OnSurface,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    "From your family • ${formatRelative(nudge.createdAt)}",
                    fontSize = 12.sp,
                    color = SubtitleColor,
                )
            }
        }

        // Critical banner
        if (nudge.isCritical) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFFFEE2E2))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Outlined.Notifications,
                        contentDescription = null,
                        tint = Color(0xFFB91C1C),
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.size(8.dp))
                    Text(
                        "Important — needs your attention",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color(0xFFB91C1C),
                    )
                }
            }
        }

        // Message card
        if (nudge.message.isNotBlank()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color(0xFFF7F8FA))
                    .padding(16.dp),
            ) {
                Text(
                    nudge.message,
                    fontSize = 15.sp,
                    color = OnSurface,
                )
            }
        }

        // Meta row
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            MetaRow(label = "Type", value = friendlyTypeLabel(nudge.nudgeType))
            if (!nudge.priority.isNullOrBlank()) {
                MetaRow(label = "Priority", value = nudge.priority.replaceFirstChar { it.uppercase() })
            }
            MetaRow(label = "Received", value = formatAbsolute(nudge.createdAt))
            if (nudge.isActedOn) MetaRow(label = "Status", value = "Acknowledged")
            else if (nudge.isDismissed) MetaRow(label = "Status", value = "Dismissed")
        }

        Spacer(Modifier.height(8.dp))

        // Actions
        if (!nudge.isActedOn && !nudge.isDismissed) {
            Button(
                onClick = onMarkActedOn,
                enabled = !isActing,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AITeal,
                    contentColor = Color.White,
                    disabledContainerColor = AITeal.copy(alpha = 0.4f),
                ),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(actionLabel(nudge.nudgeType), fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
            OutlinedButton(
                onClick = onDismiss,
                enabled = !isActing,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("Dismiss", color = SubtitleColor, fontWeight = FontWeight.Medium)
            }
        } else {
            OutlinedButton(
                onClick = onMarkActedOn,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("Close", color = SubtitleColor, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun MetaRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontSize = 12.sp, color = SubtitleColor, modifier = Modifier.size(width = 90.dp, height = 18.dp))
        Spacer(Modifier.size(8.dp))
        Text(value, fontSize = 13.sp, color = OnSurface, fontWeight = FontWeight.Medium)
    }
}

private fun iconAndAccentFor(type: String): Pair<ImageVector, Color> = when (type.uppercase()) {
    "MEDICATION", "MEDICATION_MISSED" -> Icons.Outlined.MedicalServices to Color(0xFF4F46E5)
    "HYDRATION" -> Icons.Outlined.LocalDrink to Color(0xFF0EA5E9)
    "VITALS" -> Icons.Outlined.Monitor to Color(0xFFEF4444)
    "APPOINTMENT" -> Icons.Outlined.CalendarMonth to Color(0xFFF59E0B)
    "CHECKIN" -> Icons.Outlined.Favorite to Color(0xFFEC4899)
    else -> Icons.Outlined.Notifications to AITeal
}

private fun friendlyTypeLabel(type: String): String = when (type.uppercase()) {
    "MEDICATION" -> "Medication reminder"
    "MEDICATION_MISSED" -> "Missed medication"
    "HYDRATION" -> "Hydration nudge"
    "VITALS" -> "Vitals reminder"
    "APPOINTMENT" -> "Appointment"
    "CHECKIN" -> "Family check-in"
    else -> type.replace('_', ' ').lowercase().replaceFirstChar { it.uppercase() }
}

private fun actionLabel(type: String): String = when (type.uppercase()) {
    "MEDICATION", "MEDICATION_MISSED" -> "I took my medication"
    "HYDRATION" -> "I'm drinking water"
    "VITALS" -> "I'll log it now"
    "APPOINTMENT" -> "Got it"
    "CHECKIN" -> "Thanks for checking in"
    else -> "Got it"
}

/** Format an ISO-8601 timestamp as a short absolute time, e.g. "May 12, 4:32 PM". */
private fun formatAbsolute(iso: String): String = runCatching {
    val dt = java.time.OffsetDateTime.parse(iso).toLocalDateTime()
    val fmt = java.time.format.DateTimeFormatter.ofPattern("MMM d, h:mm a")
    dt.format(fmt)
}.getOrDefault(iso.take(16))

/** Compact relative time ("just now", "5m ago", "2h ago", "yesterday"). */
private fun formatRelative(iso: String): String = runCatching {
    val then = java.time.OffsetDateTime.parse(iso).toInstant()
    val now = java.time.Instant.now()
    val secs = java.time.Duration.between(then, now).seconds
    when {
        secs < 60 -> "just now"
        secs < 3600 -> "${secs / 60}m ago"
        secs < 86400 -> "${secs / 3600}h ago"
        secs < 172800 -> "yesterday"
        else -> "${secs / 86400}d ago"
    }
}.getOrDefault("recently")
