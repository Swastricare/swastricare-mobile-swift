package com.swastricare.health.ui.screens.family

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyRole
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.presentation.feature.family.FamilyUiState
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

// -----------------------------------------------
// MARK: - FamilyScreen
// -----------------------------------------------

@Composable
fun FamilyScreen(
    onNavigateBack: () -> Unit,
    initialJoinCode: String? = null
) {
    val vm: FamilyViewModel = hiltViewModel()
    val uiState by vm.uiState.collectAsState()
    val clipboardManager = LocalClipboardManager.current

    // Handle initial join code from deep link
    LaunchedEffect(initialJoinCode) {
        if (!initialJoinCode.isNullOrBlank()) {
            vm.joinWithCode(initialJoinCode)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
        ) {
            // Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack, "Back",
                        tint = AppColors.onSurface
                    )
                }
                Text(
                    "Family",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
            }

            when {
                uiState.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = PrimaryColor)
                    }
                }
                uiState.familyGroup != null -> {
                    // In a group - show group details
                    FamilyGroupContent(
                        uiState = uiState,
                        onGenerateCode = { vm.generateInviteCode() },
                        onCopyInviteLink = {
                            val link = "swastricare://family/join?code=${uiState.inviteCode}"
                            clipboardManager.setText(AnnotatedString(link))
                        },
                        onLeaveGroup = { vm.showLeaveConfirmation() }
                    )
                }
                else -> {
                    // Not in a group - show join UI
                    JoinGroupContent(
                        joinCode = uiState.joinCode,
                        isJoining = uiState.isJoining,
                        onJoinCodeChanged = { vm.updateJoinCode(it) },
                        onJoinClick = { vm.joinWithCode() }
                    )
                }
            }
        }

        // Error snackbar
        uiState.error?.let { errorMsg ->
            Snackbar(
                modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                action = { TextButton(onClick = { vm.clearError() }) { Text("Dismiss") } }
            ) { Text(errorMsg) }
        }

        // Success snackbar
        uiState.successMessage?.let { msg ->
            Snackbar(
                modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
                action = { TextButton(onClick = { vm.clearSuccess() }) { Text("OK") } }
            ) { Text(msg) }
        }

        // Leave confirmation dialog
        if (uiState.showLeaveConfirmation) {
            AlertDialog(
                onDismissRequest = { vm.dismissLeaveConfirmation() },
                title = { Text("Leave Family Group") },
                text = { Text("Are you sure you want to leave this family group? You can rejoin later with an invite code.") },
                confirmButton = {
                    TextButton(
                        onClick = { vm.leaveGroup() },
                        colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
                    ) { Text("Leave") }
                },
                dismissButton = {
                    TextButton(onClick = { vm.dismissLeaveConfirmation() }) { Text("Cancel") }
                }
            )
        }
    }
}

// -----------------------------------------------
// MARK: - Join Group Content
// -----------------------------------------------

@Composable
private fun JoinGroupContent(
    joinCode: String,
    isJoining: Boolean,
    onJoinCodeChanged: (String) -> Unit,
    onJoinClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Icon
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(PrimaryColor.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.People,
                contentDescription = null,
                tint = PrimaryColor,
                modifier = Modifier.size(40.dp)
            )
        }

        Spacer(Modifier.height(24.dp))

        Text(
            "Join a Family Group",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(8.dp))

        Text(
            "Enter an invite code to join your family's health group. You'll be able to view and share health data with your family members.",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        Spacer(Modifier.height(32.dp))

        // Invite Code Input
        OutlinedTextField(
            value = joinCode,
            onValueChange = onJoinCodeChanged,
            label = { Text("Invite Code") },
            placeholder = { Text("e.g. ABC123") },
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth(),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PrimaryColor,
                cursorColor = PrimaryColor
            )
        )

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = onJoinClick,
            enabled = joinCode.isNotBlank() && !isJoining,
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            if (isJoining) {
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

// -----------------------------------------------
// MARK: - Family Group Content
// -----------------------------------------------

@Composable
private fun FamilyGroupContent(
    uiState: FamilyUiState,
    onGenerateCode: () -> Unit,
    onCopyInviteLink: () -> Unit,
    onLeaveGroup: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 120.dp)
    ) {
        // Group Header
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .background(
                            brush = Brush.linearGradient(
                                colors = listOf(PrimaryColor, PrimaryColor.copy(alpha = 0.7f))
                            ),
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Groups,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(32.dp)
                    )
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    uiState.familyGroup?.name ?: "Family Group",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    "${uiState.members.size} members",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface.copy(alpha = 0.6f)
                )
            }
        }

        // Members List
        item {
            Text(
                "Members",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }

        items(uiState.members) { member ->
            FamilyMemberRow(member = member)
        }

        // Invite Section
        item {
            Spacer(Modifier.height(24.dp))
            Text(
                "Invite",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(cardBg)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (uiState.inviteCode.isNotBlank()) {
                    Text(
                        "Invite Code",
                        style = MaterialTheme.typography.labelMedium,
                        color = AppColors.onSurface.copy(alpha = 0.5f)
                    )
                    Text(
                        uiState.inviteCode,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 4.sp,
                        color = PrimaryColor
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedButton(
                        onClick = onCopyInviteLink,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.ContentCopy, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Copy Link", fontSize = 13.sp)
                    }
                    OutlinedButton(
                        onClick = onGenerateCode,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.Refresh, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("New Code", fontSize = 13.sp)
                    }
                }
            }
        }

        // Leave Group
        item {
            Spacer(Modifier.height(32.dp))
            TextButton(
                onClick = onLeaveGroup,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
            ) {
                Icon(Icons.Default.ExitToApp, null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Leave Family Group")
            }
        }
    }
}

// -----------------------------------------------
// MARK: - Member Row
// -----------------------------------------------

@Composable
private fun FamilyMemberRow(member: FamilyMember) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(cardBg)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Avatar
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(PrimaryColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = (member.fullName ?: "?").take(1).uppercase(),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = PrimaryColor
            )
        }

        // Name and role
        Column(modifier = Modifier.weight(1f)) {
            Text(
                member.fullName ?: "Unknown",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
        }

        // Role badge
        val roleColor = when (member.role) {
            FamilyRole.OWNER -> Color(0xFFFF9500)
            FamilyRole.ADMIN -> PrimaryColor
            FamilyRole.MEMBER -> AppColors.onSurface.copy(alpha = 0.5f)
        }
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(roleColor.copy(alpha = 0.12f))
                .padding(horizontal = 8.dp, vertical = 4.dp)
        ) {
            Text(
                member.role.displayName,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = roleColor
            )
        }
    }
}
