package com.swastricare.health.ui.screens.family.member

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.Bedtime
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.LocalDrink
import androidx.compose.material.icons.outlined.Medication
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.NotificationsActive
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyRole
import com.swastricare.health.domain.model.MedicationDoseSummary
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal

// ─── Local palette (matches FamilyScreen for visual consistency) ───
private val PageBg = Color.White
private val CardBorder = Color(0xFFE5E7EB)
private val CardBg = Color.White
private val SubtitleColor = Color(0xFF6B7280)
private val OnSurface = Color(0xFF111827)
private val DangerColor = Color(0xFFEF4444)
private val WarningColor = Color(0xFFF59E0B)
private val SuccessColor = Color(0xFF22C55E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FamilyMemberDashboardScreen(
    targetHealthProfileId: String,
    onNavigateBack: () -> Unit,
    onNavigateToNudge: (String) -> Unit,
    onNavigateToAskAI: (String) -> Unit,
    onNavigateToReminders: (String) -> Unit,
    onNavigateToAlertPrefs: (String) -> Unit,
) {
    TrackScreen("FamilyMemberDashboard")
    val vm: FamilyMemberDashboardViewModel = hiltViewModel()
    val state by vm.state.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(targetHealthProfileId) {
        vm.load(targetHealthProfileId)
    }

    Box(modifier = Modifier.fillMaxSize().background(PageBg)) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    val firstName = state.member?.fullName?.trim()?.split(" ")?.firstOrNull()
                    Text(
                        firstName ?: "Member",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = OnSurface,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = OnSurface,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = PageBg,
                    titleContentColor = OnSurface,
                ),
            )

            when {
                state.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(color = AITeal, strokeWidth = 3.dp)
                    }
                }
                state.error != null -> {
                    ErrorCard(
                        message = state.error ?: "Something went wrong",
                        onRetry = { vm.load(targetHealthProfileId) },
                    )
                }
                else -> {
                    DashboardContent(
                        state = state,
                        onNudge = { onNavigateToNudge(targetHealthProfileId) },
                        onAskAI = { onNavigateToAskAI(targetHealthProfileId) },
                        onReminders = { onNavigateToReminders(targetHealthProfileId) },
                        onAlertPrefs = { onNavigateToAlertPrefs(targetHealthProfileId) },
                        onOpenVaultDoc = { doc ->
                            android.util.Log.d("VaultDocOpen", "click doc=${doc.id} name=${doc.name} fileUrl=${doc.fileUrl}")
                            val path = doc.fileUrl
                            if (path.isNullOrBlank()) {
                                android.util.Log.w("VaultDocOpen", "skip: blank fileUrl")
                                android.widget.Toast.makeText(context, "Cannot open: file path missing", android.widget.Toast.LENGTH_SHORT).show()
                                return@DashboardContent
                            }
                            vm.resolveVaultDocUrl(
                                path = path,
                                onResolved = { url ->
                                    android.util.Log.d("VaultDocOpen", "signed url ok len=${url.length}")
                                    val mime = when (path.substringAfterLast('.', "").lowercase()) {
                                        "pdf" -> "application/pdf"
                                        "jpg", "jpeg" -> "image/jpeg"
                                        "png" -> "image/png"
                                        "webp" -> "image/webp"
                                        "heic" -> "image/heic"
                                        "doc", "docx" -> "application/msword"
                                        "xls", "xlsx" -> "application/vnd.ms-excel"
                                        "txt" -> "text/plain"
                                        else -> "*/*"
                                    }
                                    val uri = android.net.Uri.parse(url)
                                    val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, mime)
                                        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                        addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    val resolved = intent.resolveActivity(context.packageManager) != null
                                    android.util.Log.d("VaultDocOpen", "intent mime=$mime resolved=$resolved")
                                    runCatching {
                                        if (resolved) context.startActivity(intent)
                                        else context.startActivity(
                                            android.content.Intent.createChooser(
                                                android.content.Intent(android.content.Intent.ACTION_VIEW, uri).apply {
                                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                                },
                                                "Open document",
                                            ).apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) },
                                        )
                                    }.onFailure {
                                        android.util.Log.e("VaultDocOpen", "startActivity failed", it)
                                        android.widget.Toast.makeText(context, "No app to open this file", android.widget.Toast.LENGTH_SHORT).show()
                                    }
                                },
                                onError = { msg ->
                                    android.util.Log.w("VaultDocOpen", "getSignedUrl error: $msg")
                                    android.widget.Toast.makeText(context, "Cannot open: $msg", android.widget.Toast.LENGTH_SHORT).show()
                                },
                            )
                        },
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Dashboard content
// ─────────────────────────────────────

@Composable
private fun DashboardContent(
    state: FamilyMemberDashboardState,
    onNudge: () -> Unit,
    onAskAI: () -> Unit,
    onReminders: () -> Unit,
    onAlertPrefs: () -> Unit,
    onOpenVaultDoc: (com.swastricare.health.domain.model.VaultDocSummary) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(top = 8.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        state.member?.let { MemberHeaderCard(member = it) }
        VitalsCard(
            bpm = state.latestHeartRateBpm,
            measuredAt = state.heartRateMeasuredAt,
            sleepHours = state.sleepHours,
        )
        MedicationCard(
            doses = state.doses,
            adherencePercent = state.adherencePercent,
        )
        HydrationCard(
            current = state.hydrationMl,
            goal = state.hydrationGoalMl,
        )
        DietCard(calories = state.caloriesToday)
        VaultCard(
            docs = state.vaultDocs,
            onOpen = onOpenVaultDoc,
        )
        ActionRow(
            canEdit = state.canEdit,
            onNudge = onNudge,
            onAskAI = onAskAI,
            onReminders = onReminders,
            onAlertPrefs = onAlertPrefs,
        )
    }
}

// ─────────────────────────────────────
// MARK: - Cards
// ─────────────────────────────────────

@Composable
private fun MemberHeaderCard(member: FamilyMember) {
    val displayName = member.fullName?.takeIf { it.isNotBlank() } ?: "Member"
    val roleLabel = when (member.role) {
        FamilyRole.OWNER -> "Owner"
        FamilyRole.ADMIN -> "Caregiver"
        FamilyRole.MEMBER -> "Member"
    }
    val isOwner = member.role == FamilyRole.OWNER

    Card {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.padding(16.dp),
        ) {
            val avatar = member.avatarUrl?.takeIf { it.isNotBlank() }
            if (avatar != null) {
                AsyncImage(
                    model = avatar,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(AITeal.copy(alpha = 0.15f)),
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(AITeal.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = displayName.take(2).uppercase(),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = AITeal,
                    )
                }
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    displayName,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = OnSurface,
                )
                Spacer(Modifier.height(6.dp))
                RoleBadge(label = roleLabel, isPrimary = isOwner)
            }
        }
    }
}

@Composable
private fun RoleBadge(label: String, isPrimary: Boolean) {
    val bg = if (isPrimary) AITeal else Color(0xFFF3F4F6)
    val fg = if (isPrimary) Color.White else SubtitleColor
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(
            label,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = fg,
        )
    }
}

@Composable
private fun VitalsCard(bpm: Int?, measuredAt: String?, sleepHours: Double?) {
    Card {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionTitle("Vitals")
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                VitalCell(
                    icon = Icons.Filled.Favorite,
                    tint = DangerColor,
                    label = "Heart rate",
                    value = bpm?.let { "$it bpm" } ?: "—",
                    sub = measuredAt?.let { formatTimeOnly(it) } ?: "No data",
                    modifier = Modifier.weight(1f),
                )
                VitalCell(
                    icon = Icons.Outlined.Bedtime,
                    tint = Color(0xFF6366F1),
                    label = "Sleep",
                    value = sleepHours?.let { String.format("%.1f h", it) } ?: "—",
                    sub = if (sleepHours == null) "No data" else "Last night",
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun VitalCell(
    icon: ImageVector,
    tint: Color,
    label: String,
    value: String,
    sub: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFFFAFAFB))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(label, fontSize = 11.sp, color = SubtitleColor, fontWeight = FontWeight.Medium)
        }
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = OnSurface)
        Text(sub, fontSize = 10.sp, color = SubtitleColor)
    }
}

@Composable
private fun MedicationCard(doses: List<MedicationDoseSummary>, adherencePercent: Int) {
    Card {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.Medication, contentDescription = null, tint = AITeal)
                Spacer(Modifier.width(8.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Today's medications",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = OnSurface,
                    )
                    Text(
                        "Adherence: $adherencePercent%",
                        fontSize = 12.sp,
                        color = SubtitleColor,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            if (doses.isEmpty()) {
                Text(
                    "No doses scheduled for today.",
                    fontSize = 13.sp,
                    color = SubtitleColor,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    doses.forEach { dose -> DoseRow(dose) }
                }
            }
        }
    }
}

@Composable
private fun DoseRow(dose: MedicationDoseSummary) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xFFFAFAFB))
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Icon(
            Icons.Outlined.Schedule,
            contentDescription = null,
            tint = SubtitleColor,
            modifier = Modifier.size(16.dp),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            formatTimeOnly(dose.scheduledAt),
            fontSize = 12.sp,
            color = SubtitleColor,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.width(64.dp),
        )
        Text(
            dose.medicationName,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = OnSurface,
            modifier = Modifier.weight(1f),
        )
        StatusPill(status = dose.status)
    }
}

@Composable
private fun StatusPill(status: String) {
    val (label, bg, fg) = when (status.lowercase()) {
        "taken" -> Triple("Taken", SuccessColor.copy(alpha = 0.15f), SuccessColor)
        "missed" -> Triple("Missed", DangerColor.copy(alpha = 0.15f), DangerColor)
        "skipped" -> Triple("Skipped", WarningColor.copy(alpha = 0.15f), WarningColor)
        "late" -> Triple("Late", WarningColor.copy(alpha = 0.15f), WarningColor)
        "early" -> Triple("Early", AITeal.copy(alpha = 0.15f), AITeal)
        else -> Triple("Pending", Color(0xFFE5E7EB), SubtitleColor)
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = fg)
    }
}

@Composable
private fun HydrationCard(current: Int, goal: Int) {
    val progress = if (goal <= 0) 0f else (current.toFloat() / goal.toFloat()).coerceIn(0f, 1f)
    Card {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.LocalDrink, contentDescription = null, tint = Color(0xFF0EA5E9))
                Spacer(Modifier.width(8.dp))
                Text(
                    "Hydration",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = OnSurface,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "$current / $goal ml",
                    fontSize = 12.sp,
                    color = SubtitleColor,
                    fontWeight = FontWeight.Medium,
                )
            }
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .clip(RoundedCornerShape(4.dp)),
                color = AITeal,
                trackColor = Color(0xFFE5E7EB),
            )
        }
    }
}

@Composable
private fun DietCard(calories: Int) {
    Card {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(16.dp),
        ) {
            Icon(Icons.Outlined.Restaurant, contentDescription = null, tint = Color(0xFFF59E0B))
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Calories today",
                    fontSize = 12.sp,
                    color = SubtitleColor,
                )
                Text(
                    "$calories kcal",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = OnSurface,
                )
            }
        }
    }
}

@Composable
private fun VaultCard(
    docs: List<com.swastricare.health.domain.model.VaultDocSummary>,
    onOpen: (com.swastricare.health.domain.model.VaultDocSummary) -> Unit,
) {
    Card {
        Column(modifier = Modifier.padding(vertical = 12.dp, horizontal = 16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.Description, contentDescription = null, tint = AITeal)
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text("Vault", fontSize = 12.sp, color = SubtitleColor)
                    Text(
                        if (docs.isEmpty()) "No documents shared yet"
                        else "${docs.size} document${if (docs.size == 1) "" else "s"}",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = OnSurface,
                    )
                }
            }
            if (docs.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                docs.take(10).forEach { doc -> VaultDocRow(doc, onClick = { onOpen(doc) }) }
                if (docs.size > 10) {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "+ ${docs.size - 10} more",
                        fontSize = 12.sp,
                        color = SubtitleColor,
                    )
                }
            }
        }
    }
}

@Composable
private fun VaultDocRow(
    doc: com.swastricare.health.domain.model.VaultDocSummary,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
    ) {
        // Thumbnail or icon
        if (!doc.thumbnailUrl.isNullOrBlank()) {
            coil.compose.AsyncImage(
                model = doc.thumbnailUrl,
                contentDescription = null,
                contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                modifier = Modifier
                    .size(56.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp)),
            )
        } else {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .background(AITeal.copy(alpha = 0.10f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Outlined.Description,
                    contentDescription = null,
                    tint = AITeal,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                doc.name.ifBlank { "Untitled document" },
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = OnSurface,
                maxLines = 2,
            )
            // Document type + uploaded date
            val metaLine = listOfNotNull(
                doc.docType?.replace('_', ' ')?.replaceFirstChar { it.uppercase() }?.takeIf { it.isNotBlank() },
                doc.uploadedAt.take(10).takeIf { it.isNotBlank() },
            ).joinToString(" • ")
            if (metaLine.isNotBlank()) {
                Text(metaLine, fontSize = 11.sp, color = SubtitleColor)
            }
            // File name + size
            val fileMeta = listOfNotNull(
                doc.fileName?.takeIf { it.isNotBlank() },
                doc.fileSizeBytes?.let { formatFileSize(it) },
            ).joinToString(" • ")
            if (fileMeta.isNotBlank()) {
                Text(fileMeta, fontSize = 11.sp, color = SubtitleColor)
            }
            // Description
            val description = doc.description?.takeIf { it.isNotBlank() }
            if (description != null) {
                Spacer(Modifier.height(2.dp))
                Text(
                    description,
                    fontSize = 12.sp,
                    color = OnSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                )
            }
        }
        Icon(
            Icons.Outlined.OpenInNew,
            contentDescription = "Open",
            tint = AITeal,
            modifier = Modifier
                .padding(top = 2.dp)
                .size(20.dp),
        )
    }
}

private fun formatFileSize(bytes: Long): String {
    if (bytes <= 0) return ""
    val kb = bytes / 1024.0
    return when {
        kb < 1 -> "$bytes B"
        kb < 1024 -> "%.0f KB".format(kb)
        else -> "%.1f MB".format(kb / 1024.0)
    }
}

// ─────────────────────────────────────
// MARK: - Action row
// ─────────────────────────────────────

@Composable
private fun ActionRow(
    canEdit: Boolean,
    onNudge: () -> Unit,
    onAskAI: () -> Unit,
    onReminders: () -> Unit,
    onAlertPrefs: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            ActionButton(
                icon = Icons.Outlined.NotificationsActive,
                label = "Nudge",
                onClick = onNudge,
                modifier = Modifier.weight(1f),
            )
            ActionButton(
                icon = Icons.Outlined.Psychology,
                label = "Ask AI",
                onClick = onAskAI,
                modifier = Modifier.weight(1f),
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (canEdit) {
                ActionButton(
                    icon = Icons.Outlined.Schedule,
                    label = "Reminders",
                    onClick = onReminders,
                    modifier = Modifier.weight(1f),
                )
            }
            ActionButton(
                icon = Icons.Outlined.Notifications,
                label = "Alert prefs",
                onClick = onAlertPrefs,
                modifier = if (canEdit) Modifier.weight(1f) else Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun ActionButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(52.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AITeal,
            contentColor = Color.White,
        ),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

// ─────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────

@Composable
private fun Card(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, CardBorder, RoundedCornerShape(16.dp))
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg),
    ) {
        content()
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text,
        fontSize = 15.sp,
        fontWeight = FontWeight.SemiBold,
        color = OnSurface,
    )
}

@Composable
private fun ErrorCard(message: String, onRetry: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, CardBorder, RoundedCornerShape(16.dp))
                .clip(RoundedCornerShape(16.dp))
                .background(CardBg)
                .padding(20.dp),
        ) {
            Text(
                "Couldn't load dashboard",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = OnSurface,
            )
            Text(
                message,
                fontSize = 13.sp,
                color = SubtitleColor,
            )
            Button(
                onClick = onRetry,
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(46.dp),
            ) {
                Text("Retry", fontWeight = FontWeight.SemiBold, color = Color.White)
            }
        }
    }
}

/**
 * Best-effort time formatting for an ISO-8601 timestamp. Falls back to the
 * original string if the input doesn't look parseable — keeps the dashboard
 * safe against backend format drift.
 */
private fun formatTimeOnly(iso: String): String {
    if (iso.isBlank()) return "—"
    return try {
        // Match "HH:mm" inside an ISO-8601 string like "2025-11-12T08:30:00Z".
        val tIdx = iso.indexOf('T')
        if (tIdx >= 0 && iso.length >= tIdx + 6) {
            iso.substring(tIdx + 1, tIdx + 6)
        } else iso
    } catch (_: Throwable) {
        iso
    }
}
