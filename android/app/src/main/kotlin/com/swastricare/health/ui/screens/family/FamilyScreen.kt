package com.swastricare.health.ui.screens.family

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Group
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyRole
import com.swastricare.health.presentation.feature.family.FamilyUiState
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors

private val PageBg = Color.White
private val CardBorder = Color(0xFFE5E7EB)
private val CardBg = Color.White
private val SubtitleColor = Color(0xFF6B7280)
private val DangerColor = Color(0xFFEF4444)

private const val LEAF_ASSET = "file:///android_asset/icons/background%20leaf%20illustration%20right.png"
private const val BANNER_ASSET = "file:///android_asset/images/family%20screen%20banner.png"

// -----------------------------------------------
// MARK: - FamilyScreen
// -----------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FamilyScreen(
    onNavigateBack: () -> Unit,
    initialJoinCode: String? = null
) {
    TrackScreen("Family")
    val vm: FamilyViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    val clipboardManager = LocalClipboardManager.current

    var editMode by remember { mutableStateOf(false) }
    var showInviteSheet by remember { mutableStateOf(false) }

    LaunchedEffect(initialJoinCode) {
        if (!initialJoinCode.isNullOrBlank()) {
            vm.joinWithCode(initialJoinCode)
        }
    }

    // Reset edit mode when leaving group
    LaunchedEffect(uiState.familyGroup?.id) {
        if (uiState.familyGroup == null) editMode = false
    }

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(uiState.error) {
        uiState.error?.let { msg ->
            snackbarHostState.showSnackbar(msg, duration = SnackbarDuration.Short)
            vm.clearError()
        }
    }
    LaunchedEffect(uiState.successMessage) {
        uiState.successMessage?.let { msg ->
            snackbarHostState.showSnackbar(msg, duration = SnackbarDuration.Short)
            vm.clearSuccess()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(PageBg)) {

        // Background leaf illustration (bottom-end)
        AsyncImage(
            model = LEAF_ASSET,
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .fillMaxHeight(0.55f)
                .fillMaxWidth(1.0f)
                .alpha(0.95f)
        )

        Column(modifier = Modifier.fillMaxSize()) {
            FamilyHeader(
                onBack = onNavigateBack,
                trailingEnabled = uiState.familyGroup != null,
                onTrailingClick = { showInviteSheet = true }
            )

            when {
                uiState.isLoading && uiState.familyGroup == null -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = AITeal)
                    }
                }
                uiState.familyGroup != null -> {
                    InGroupContent(
                        uiState = uiState,
                        editMode = editMode,
                        onToggleEditMode = { editMode = !editMode },
                        onAddMember = { showInviteSheet = true },
                        onRemoveMember = { vm.showRemoveMemberDialog(it) },
                        onMemberViewed = { vm.trackFamilyMemberViewed() }
                    )
                }
                else -> {
                    NoGroupContent(
                        uiState = uiState,
                        onGroupNameChange = vm::updateGroupName,
                        onCreateGroup = vm::createFamilyGroup,
                        onJoinCodeChange = vm::updateJoinCode,
                        onJoin = vm::joinWithCode
                    )
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 24.dp)
        )

        if (showInviteSheet && uiState.familyGroup != null) {
            InviteBottomSheet(
                inviteCode = uiState.inviteCode,
                isGenerating = uiState.isGeneratingCode,
                canLeave = true,
                onCopyLink = {
                    val link = "swastricare://family/join?code=${uiState.inviteCode}"
                    clipboardManager.setText(AnnotatedString(link))
                    vm.trackFamilyInviteSent()
                },
                onGenerateCode = { vm.generateInviteCode() },
                onLeaveGroup = {
                    showInviteSheet = false
                    vm.showLeaveConfirmation()
                },
                onDismiss = { showInviteSheet = false }
            )
        }

        if (uiState.showLeaveConfirmation) {
            AlertDialog(
                onDismissRequest = { vm.dismissLeaveConfirmation() },
                title = { Text("Leave Family Group") },
                text = { Text("Are you sure you want to leave this family group? You can rejoin later with an invite code.") },
                confirmButton = {
                    TextButton(
                        onClick = { vm.leaveGroup() },
                        colors = ButtonDefaults.textButtonColors(contentColor = DangerColor)
                    ) { Text("Leave") }
                },
                dismissButton = {
                    TextButton(onClick = { vm.dismissLeaveConfirmation() }) { Text("Cancel") }
                }
            )
        }

        if (uiState.showRemoveMemberDialog) {
            val name = uiState.memberToRemove?.fullName ?: "this member"
            AlertDialog(
                onDismissRequest = { vm.dismissRemoveMemberDialog() },
                title = { Text("Remove Member") },
                text = { Text("Remove $name from the family group? They will lose access to shared health data.") },
                confirmButton = {
                    TextButton(
                        onClick = { vm.removeMember() },
                        colors = ButtonDefaults.textButtonColors(contentColor = DangerColor)
                    ) { Text("Remove") }
                },
                dismissButton = {
                    TextButton(onClick = { vm.dismissRemoveMemberDialog() }) { Text("Cancel") }
                }
            )
        }
    }
}

// -----------------------------------------------
// MARK: - Header
// -----------------------------------------------

@Composable
private fun FamilyHeader(
    onBack: () -> Unit,
    trailingEnabled: Boolean,
    onTrailingClick: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = AppColors.onSurface
                )
            }
            Spacer(Modifier.weight(1f))
            if (trailingEnabled) {
                Box(
                    modifier = Modifier
                        .padding(end = 12.dp)
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(AITeal.copy(alpha = 0.12f))
                        .clickable { onTrailingClick() },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Outlined.PersonAdd,
                        contentDescription = "Invite member",
                        tint = AITeal,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
        Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)) {
            Text(
                "Family",
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onBackground
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "Manage your family members and their medications in one place.",
                fontSize = 13.sp,
                color = SubtitleColor,
                lineHeight = 18.sp
            )
        }
        Spacer(Modifier.height(16.dp))
    }
}

// -----------------------------------------------
// MARK: - Better Together Banner
// -----------------------------------------------

@Composable
private fun BetterTogetherBanner() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(AITeal.copy(alpha = 0.08f))
    ) {
        // Full-bleed banner illustration
        AsyncImage(
            model = BANNER_ASSET,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .matchParentSize()
        )
        // Text overlay on the left, sized to leave room for the family on the right
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(0.55f),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(AITeal.copy(alpha = 0.18f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Outlined.Group,
                        contentDescription = null,
                        tint = AITeal,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    "Better together",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground
                )
                Text(
                    "Add your loved ones and help them stay on track with their medications.",
                    fontSize = 12.sp,
                    color = SubtitleColor,
                    lineHeight = 16.sp
                )
            }
        }
    }
}

// -----------------------------------------------
// MARK: - In-Group Content
// -----------------------------------------------

@Composable
private fun InGroupContent(
    uiState: FamilyUiState,
    editMode: Boolean,
    onToggleEditMode: () -> Unit,
    onAddMember: () -> Unit,
    onRemoveMember: (FamilyMember) -> Unit,
    onMemberViewed: () -> Unit
) {
    val currentUserId = uiState.currentMember?.userId
    val showEdit = uiState.canManageMembers

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 32.dp)
    ) {
        item { BetterTogetherBanner() }
        item { Spacer(Modifier.height(20.dp)) }

        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "Your Family",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground,
                    modifier = Modifier.weight(1f)
                )
                if (showEdit) {
                    Text(
                        text = if (editMode) "Done" else "Edit",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AITeal,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .clickable { onToggleEditMode() }
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        items(uiState.members, key = { it.id }) { member ->
            val isCurrent = member.userId == currentUserId
            // Disallow removing self or owner via edit mode
            val canRemove = editMode && !isCurrent && member.role != FamilyRole.OWNER
            FamilyMemberRow(
                member = member,
                isCurrent = isCurrent,
                editMode = editMode,
                canRemove = canRemove,
                onClick = { if (!editMode) onMemberViewed() },
                onRemove = { onRemoveMember(member) }
            )
            Spacer(Modifier.height(8.dp))
        }

        item {
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = onAddMember,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
                border = androidx.compose.foundation.BorderStroke(1.5.dp, AITeal),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = AITeal)
            ) {
                Icon(
                    Icons.Outlined.Add,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "Add Family Member",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                "Invite and manage family members",
                fontSize = 12.sp,
                color = SubtitleColor,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// -----------------------------------------------
// MARK: - Member Row
// -----------------------------------------------

@Composable
private fun FamilyMemberRow(
    member: FamilyMember,
    isCurrent: Boolean,
    editMode: Boolean,
    canRemove: Boolean,
    onClick: () -> Unit,
    onRemove: () -> Unit
) {
    val displayName = if (isCurrent) "You" else (member.fullName ?: "Member")
    val subtitle = when (member.role) {
        FamilyRole.OWNER -> "Group owner"
        FamilyRole.ADMIN -> "Admin"
        FamilyRole.MEMBER -> "Member"
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .border(1.dp, CardBorder, RoundedCornerShape(16.dp))
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .clickable(enabled = !editMode || canRemove) {
                if (editMode && canRemove) onRemove() else onClick()
            }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Avatar
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(AITeal.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = (if (isCurrent) "ME" else (member.fullName ?: "?").take(2).uppercase()),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = AITeal
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    displayName,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground
                )
                if (isCurrent) {
                    Spacer(Modifier.width(8.dp))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(AITeal.copy(alpha = 0.15f))
                            .padding(horizontal = 8.dp, vertical = 2.dp)
                    ) {
                        Text(
                            "Primary",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AITeal
                        )
                    }
                }
            }
            Spacer(Modifier.height(2.dp))
            Text(
                subtitle,
                fontSize = 12.sp,
                color = SubtitleColor
            )
        }

        when {
            editMode && canRemove -> Icon(
                Icons.Outlined.Delete,
                contentDescription = "Remove member",
                tint = DangerColor,
                modifier = Modifier.size(20.dp)
            )
            editMode && !canRemove -> Spacer(Modifier.size(20.dp))
            else -> Icon(
                Icons.AutoMirrored.Outlined.KeyboardArrowRight,
                contentDescription = null,
                tint = SubtitleColor,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

// -----------------------------------------------
// MARK: - No-Group Content (Create + Join)
// -----------------------------------------------

@Composable
private fun NoGroupContent(
    uiState: FamilyUiState,
    onGroupNameChange: (String) -> Unit,
    onCreateGroup: () -> Unit,
    onJoinCodeChange: (String) -> Unit,
    onJoin: () -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 32.dp)
    ) {
        item { BetterTogetherBanner() }
        item { Spacer(Modifier.height(20.dp)) }

        // Create card
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .border(1.dp, CardBorder, RoundedCornerShape(16.dp))
                    .clip(RoundedCornerShape(16.dp))
                    .background(CardBg)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    "Create your family",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground
                )
                Text(
                    "Start a new family group and invite your loved ones.",
                    fontSize = 12.sp,
                    color = SubtitleColor
                )
                OutlinedTextField(
                    value = uiState.groupName,
                    onValueChange = onGroupNameChange,
                    label = { Text("Group name") },
                    placeholder = { Text("e.g. Sharma Family") },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AITeal,
                        focusedLabelColor = AITeal,
                        cursorColor = AITeal
                    )
                )
                Button(
                    onClick = onCreateGroup,
                    enabled = uiState.groupName.isNotBlank() && !uiState.isLoading,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AITeal)
                ) {
                    if (uiState.isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text("Create Family Group", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }

        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp, vertical = 20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                HorizontalDivider(modifier = Modifier.weight(1f), color = CardBorder)
                Text(
                    "or",
                    fontSize = 12.sp,
                    color = SubtitleColor,
                    modifier = Modifier.padding(horizontal = 12.dp)
                )
                HorizontalDivider(modifier = Modifier.weight(1f), color = CardBorder)
            }
        }

        // Join card
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .border(1.dp, CardBorder, RoundedCornerShape(16.dp))
                    .clip(RoundedCornerShape(16.dp))
                    .background(CardBg)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    "Join with invite code",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onBackground
                )
                Text(
                    "Already have an invite? Enter the code to join your family's health group.",
                    fontSize = 12.sp,
                    color = SubtitleColor
                )
                OutlinedTextField(
                    value = uiState.joinCode,
                    onValueChange = onJoinCodeChange,
                    label = { Text("Invite code") },
                    placeholder = { Text("e.g. ABC123") },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AITeal,
                        focusedLabelColor = AITeal,
                        cursorColor = AITeal
                    )
                )
                Button(
                    onClick = onJoin,
                    enabled = uiState.joinCode.isNotBlank() && !uiState.isJoining,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AITeal)
                ) {
                    if (uiState.isJoining) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text("Join Group", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

// -----------------------------------------------
// MARK: - Invite Bottom Sheet
// -----------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun InviteBottomSheet(
    inviteCode: String,
    isGenerating: Boolean,
    canLeave: Boolean,
    onCopyLink: () -> Unit,
    onGenerateCode: () -> Unit,
    onLeaveGroup: () -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var copied by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Color.White
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "Invite a member",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onBackground
            )
            Text(
                "Share this code with anyone you want to add to your family group.",
                fontSize = 13.sp,
                color = SubtitleColor
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(AITeal.copy(alpha = 0.08f))
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    "Invite Code",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SubtitleColor,
                    letterSpacing = 1.sp
                )
                Text(
                    inviteCode.ifBlank { "------" },
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 6.sp,
                    color = AITeal
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = {
                        onCopyLink()
                        copied = true
                    },
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                    enabled = inviteCode.isNotBlank()
                ) {
                    Icon(
                        if (copied) Icons.Default.Check else Icons.Outlined.ContentCopy,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(if (copied) "Copied" else "Copy Link", fontSize = 13.sp)
                }
                OutlinedButton(
                    onClick = onGenerateCode,
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, AITeal),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AITeal),
                    enabled = !isGenerating
                ) {
                    if (isGenerating) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            color = AITeal,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(
                            Icons.Outlined.Refresh,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text("New Code", fontSize = 13.sp)
                    }
                }
            }

            if (canLeave) {
                Spacer(Modifier.height(4.dp))
                TextButton(
                    onClick = onLeaveGroup,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.textButtonColors(contentColor = DangerColor)
                ) {
                    Text("Leave Family Group", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
