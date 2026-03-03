package com.swasthicare.mobile.ui.screens.settings

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PremiumColor
import com.swasthicare.mobile.ui.theme.PrimaryColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToEditProfile: () -> Unit = {},
    onNavigateToFamily: () -> Unit = {},
    onNavigateToNotificationSettings: () -> Unit = {},
    onNavigateToHydrationSettings: () -> Unit = {},
    onSignOut: () -> Unit = {},
    viewModel: SettingsViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val signOutEvent by viewModel.signOutEvent.collectAsState()

    // Handle sign out navigation
    LaunchedEffect(signOutEvent) {
        if (signOutEvent) {
            onSignOut()
            viewModel.onSignOutHandled()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            "Settings",
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(
                                Icons.Default.ArrowBack,
                                contentDescription = "Back",
                                tint = MaterialTheme.colorScheme.onBackground
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent
                    )
                )
            }
        ) { padding ->
            if (uiState.isLoading && uiState.user == null) {
                // Loading state with linear progress
                SettingsLoadingState(modifier = Modifier.padding(padding))
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentPadding = PaddingValues(bottom = 32.dp)
                ) {
                    // Profile Header Card
                    item {
                        SettingsProfileHeader(
                            userName = uiState.user?.fullName ?: "User",
                            userEmail = uiState.user?.email ?: "",
                            avatarUrl = uiState.user?.avatarUrl,
                            memberSince = viewModel.memberSince,
                            onEditProfile = onNavigateToEditProfile
                        )
                    }

                    // Health Profile Section
                    item {
                        SettingsHealthProfileSection(
                            uiState = uiState,
                            profileAge = viewModel.profileAge,
                            profileBMI = viewModel.profileBMI,
                            onRefresh = viewModel::refreshHealthProfile
                        )
                    }

                    // Family Section
                    item {
                        SettingsFamilySection(onNavigateToFamily = onNavigateToFamily)
                    }

                    // Notifications Section
                    item {
                        SettingsNotificationsSection(
                            notificationsEnabled = uiState.notificationsEnabled,
                            onNotificationToggle = { viewModel.toggleNotifications(it) },
                            onNavigateToNotificationSettings = onNavigateToNotificationSettings
                        )
                    }

                    // Hydration Reminders Section
                    item {
                        SettingsHydrationSection(
                            onNavigateToHydrationSettings = onNavigateToHydrationSettings
                        )
                    }

                    // Security & Sync Section
                    item {
                        SettingsSecuritySection(
                            biometricEnabled = uiState.biometricEnabled,
                            healthSyncEnabled = uiState.healthSyncEnabled,
                            onBiometricToggle = { viewModel.toggleBiometric(it) },
                            onSyncToggle = { viewModel.toggleHealthSync(it) }
                        )
                    }

                    // App Version Section
                    item {
                        SettingsAppVersionSection(
                            version = viewModel.appVersion,
                            hasUpdate = uiState.hasUpdate
                        )
                    }

                    // Sign Out Button
                    item {
                        SettingsSignOutButton(
                            isLoading = uiState.isLoading,
                            onClick = { viewModel.setShowSignOutConfirmation(true) }
                        )
                    }

                    // Delete Account Button
                    item {
                        SettingsDeleteAccountButton(
                            isLoading = uiState.isLoading,
                            onClick = { viewModel.setShowDeleteAccountConfirmation(true) }
                        )
                    }

                    // Footer Links
                    item {
                        SettingsFooterLinks(version = viewModel.appVersion)
                    }
                }
            }
        }

        // Dialogs
        if (uiState.showSignOutConfirmation) {
            AlertDialog(
                onDismissRequest = { viewModel.setShowSignOutConfirmation(false) },
                title = { Text("Sign Out") },
                text = { Text("Are you sure you want to sign out?") },
                confirmButton = {
                    TextButton(
                        onClick = { viewModel.signOut() },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("Sign Out")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { viewModel.setShowSignOutConfirmation(false) }) {
                        Text("Cancel")
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                titleContentColor = MaterialTheme.colorScheme.onSurface,
                textContentColor = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        if (uiState.showDeleteAccountConfirmation) {
            AlertDialog(
                onDismissRequest = { viewModel.setShowDeleteAccountConfirmation(false) },
                title = { Text("Delete Account") },
                text = { Text("This action cannot be undone. All your data will be permanently deleted.") },
                confirmButton = {
                    TextButton(
                        onClick = { viewModel.deleteAccount() },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("Delete")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { viewModel.setShowDeleteAccountConfirmation(false) }) {
                        Text("Cancel")
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                titleContentColor = MaterialTheme.colorScheme.onSurface,
                textContentColor = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Error dialog
        if (uiState.errorMessage != null) {
            AlertDialog(
                onDismissRequest = { viewModel.clearError() },
                title = { Text("Error") },
                text = { Text(uiState.errorMessage ?: "") },
                confirmButton = {
                    TextButton(onClick = { viewModel.clearError() }) {
                        Text("OK")
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                titleContentColor = MaterialTheme.colorScheme.onSurface,
                textContentColor = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// MARK: - Loading State

@Composable
private fun SettingsLoadingState(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "loading")
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Animated gear icon
        Box(contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                PremiumColor.RoyalBlueStart.copy(alpha = 0.2f),
                                Color(0xFF4A90E2).copy(alpha = 0.2f)
                            )
                        )
                    )
            )
            Icon(
                Icons.Default.Settings,
                contentDescription = null,
                modifier = Modifier
                    .size(50.dp)
                    .graphicsLayer { scaleX = pulse; scaleY = pulse },
                tint = PremiumColor.RoyalBlueStart
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            "Loading settings...",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(24.dp))

        LinearProgressIndicator(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = PrimaryColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
        )
    }
}

// MARK: - Profile Header Card

@Composable
private fun SettingsProfileHeader(
    userName: String,
    userEmail: String,
    avatarUrl: String?,
    memberSince: String,
    onEditProfile: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .glass()
            .clickable { onEditProfile() }
            .padding(20.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Avatar
            Box(contentAlignment = Alignment.BottomEnd) {
                if (avatarUrl != null) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(avatarUrl)
                            .crossfade(true)
                            .build(),
                        contentDescription = "Profile Picture",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                    )
                } else {
                    // Default avatar
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(
                                Brush.linearGradient(
                                    colors = listOf(
                                        PremiumColor.RoyalBlueStart,
                                        Color(0xFF4A90E2)
                                    )
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = userName.take(1).uppercase(),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }

                // Edit badge
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(PrimaryColor),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = "Edit Profile",
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }

            // Info
            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = userName,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                Text(
                    text = userEmail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f)
                )
                Text(
                    text = "Member since $memberSince",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
                )
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

// MARK: - Glass Section Container

@Composable
private fun GlassSectionContainer(
    title: String? = null,
    headerAction: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .glass()
            .padding(16.dp)
    ) {
        if (title != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
                headerAction?.invoke()
            }
        }
        content()
    }
}

// MARK: - Shared Row Components

@Composable
private fun SettingsInfoRow(
    icon: ImageVector,
    iconTint: Color = PrimaryColor,
    label: String,
    value: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.End
        )
    }
}

@Composable
private fun SettingsToggleRow(
    icon: ImageVector,
    iconTint: Color = PrimaryColor,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        Spacer(modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = PrimaryColor,
                uncheckedThumbColor = MaterialTheme.colorScheme.outline,
                uncheckedTrackColor = MaterialTheme.colorScheme.surfaceVariant,
                uncheckedBorderColor = Color.Transparent
            )
        )
    }
}

@Composable
private fun SettingsNavigationRow(
    icon: ImageVector,
    iconTint: Color = PrimaryColor,
    label: String,
    subtitle: String? = null,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(20.dp)
        )
    }
}

// MARK: - Health Profile Section

@Composable
private fun SettingsHealthProfileSection(
    uiState: SettingsUiState,
    profileAge: String,
    profileBMI: String,
    onRefresh: () -> Unit
) {
    GlassSectionContainer(
        title = "Health Profile",
        headerAction = {
            if (uiState.healthProfile != null && !uiState.isLoadingHealthProfile) {
                // Status indicator: green check
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(Color(0xFF34C759))
                    )
                    Text(
                        "Complete",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF34C759)
                    )

                    IconButton(onClick = onRefresh, modifier = Modifier.size(24.dp)) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            tint = PrimaryColor,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            } else if (uiState.healthProfile == null && !uiState.isLoadingHealthProfile) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFFF9F0A))
                    )
                    Text(
                        "Incomplete",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFFF9F0A)
                    )
                }
            }
        }
    ) {
        if (uiState.isLoadingHealthProfile) {
            repeat(5) {
                SettingsShimmerRow()
                if (it < 4) Spacer(modifier = Modifier.height(12.dp))
            }
        } else if (uiState.healthProfile != null) {
            SettingsInfoRow(icon = Icons.Default.Person, label = "Name", value = uiState.healthProfile.fullName)
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))

            SettingsInfoRow(icon = Icons.Default.People, label = "Gender", value = uiState.healthProfile.gender.displayName)
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))

            SettingsInfoRow(icon = Icons.Default.CalendarToday, label = "Age", value = profileAge)
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))

            SettingsInfoRow(icon = Icons.Default.Straighten, label = "Height", value = "${uiState.healthProfile.heightCm} cm")
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))

            SettingsInfoRow(icon = Icons.Default.MonitorWeight, label = "Weight", value = "${uiState.healthProfile.weightKg} kg")
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))

            SettingsInfoRow(icon = Icons.Default.Accessibility, label = "BMI", value = profileBMI)

            if (uiState.healthProfile.bloodType != null) {
                HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))
                SettingsInfoRow(icon = Icons.Default.WaterDrop, iconTint = Color(0xFFFF3B30), label = "Blood Type", value = uiState.healthProfile.bloodType)
            }
        } else {
            // No health profile
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 16.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.AccountCircle,
                        contentDescription = null,
                        modifier = Modifier.size(44.dp),
                        tint = PrimaryColor
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "No health profile found",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        "Complete your health profile during onboarding",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

// MARK: - Family Section

@Composable
private fun SettingsFamilySection(onNavigateToFamily: () -> Unit) {
    GlassSectionContainer(title = "Family") {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .clickable { onNavigateToFamily() }
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Gradient icon background
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                Color(0xFFFF6B6B).copy(alpha = 0.2f),
                                Color(0xFFFF8E53).copy(alpha = 0.2f)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.People,
                    contentDescription = null,
                    tint = Color(0xFFFF6B6B),
                    modifier = Modifier.size(20.dp)
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Family Group",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    "Manage family members' health",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

// MARK: - Notifications Section

@Composable
private fun SettingsNotificationsSection(
    notificationsEnabled: Boolean,
    onNotificationToggle: (Boolean) -> Unit,
    onNavigateToNotificationSettings: () -> Unit
) {
    GlassSectionContainer(title = "Notifications") {
        SettingsToggleRow(
            icon = Icons.Default.Notifications,
            label = "Notifications",
            checked = notificationsEnabled,
            onCheckedChange = onNotificationToggle
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)
        )

        SettingsNavigationRow(
            icon = Icons.Default.NotificationsActive,
            label = "Notification Settings",
            subtitle = "Customize notification preferences",
            onClick = onNavigateToNotificationSettings
        )
    }
}

// MARK: - Hydration Section

@Composable
private fun SettingsHydrationSection(
    onNavigateToHydrationSettings: () -> Unit
) {
    GlassSectionContainer(title = "Hydration Reminders") {
        SettingsInfoRow(
            icon = Icons.Default.DirectionsRun,
            label = "Activity Level",
            value = "Moderate"
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)
        )

        SettingsInfoRow(
            icon = Icons.Default.WaterDrop,
            iconTint = Color(0xFF00C7BE),
            label = "Daily Goal",
            value = "2000 ml"
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)
        )

        SettingsNavigationRow(
            icon = Icons.Default.Settings,
            iconTint = MaterialTheme.colorScheme.onSurface,
            label = "Hydration Preferences",
            onClick = onNavigateToHydrationSettings
        )
    }
}

// MARK: - Security & Sync Section

@Composable
private fun SettingsSecuritySection(
    biometricEnabled: Boolean,
    healthSyncEnabled: Boolean,
    onBiometricToggle: (Boolean) -> Unit,
    onSyncToggle: (Boolean) -> Unit
) {
    GlassSectionContainer(title = "Security & Sync") {
        SettingsToggleRow(
            icon = Icons.Default.Fingerprint,
            label = "Biometric Lock",
            checked = biometricEnabled,
            onCheckedChange = onBiometricToggle
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)
        )

        SettingsToggleRow(
            icon = Icons.Default.Sync,
            label = "Health Sync",
            checked = healthSyncEnabled,
            onCheckedChange = onSyncToggle
        )
    }
}

// MARK: - App Version Section

@Composable
private fun SettingsAppVersionSection(
    version: String,
    hasUpdate: Boolean
) {
    GlassSectionContainer(title = "About") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (hasUpdate) Icons.Default.SystemUpdate else Icons.Outlined.Info,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = if (hasUpdate) PremiumColor.NeonGreenStart else PrimaryColor
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                "App Version",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                version,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (hasUpdate) {
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    "Update",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier
                        .background(
                            brush = Brush.linearGradient(
                                colors = listOf(
                                    PremiumColor.NeonGreenStart,
                                    PremiumColor.NeonGreenEnd
                                )
                            ),
                            shape = RoundedCornerShape(12.dp)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
    }
}

// MARK: - Sign Out Button

@Composable
private fun SettingsSignOutButton(
    isLoading: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .glass()
            .clickable(enabled = !isLoading) { onClick() }
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = MaterialTheme.colorScheme.error
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ExitToApp,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    "Sign Out",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

// MARK: - Delete Account Button

@Composable
private fun SettingsDeleteAccountButton(
    isLoading: Boolean,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 6.dp)
                .glass()
                .clickable(enabled = !isLoading) { onClick() }
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = null,
                    tint = Color(0xFFFF3B30),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    "Delete Account",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFFFF3B30)
                )
            }
        }

        Text(
            text = "Permanently delete your account and all associated data.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
        )
    }
}

// MARK: - Footer Links

@Composable
private fun SettingsFooterLinks(version: String) {
    val uriHandler = LocalUriHandler.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = "Version $version",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Terms of Service",
                style = MaterialTheme.typography.bodySmall,
                color = PrimaryColor,
                modifier = Modifier.clickable {
                    // Open terms URL or navigate to terms screen
                }
            )
            Text(
                text = "\u2022",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
            )
            Text(
                text = "Privacy Policy",
                style = MaterialTheme.typography.bodySmall,
                color = PrimaryColor,
                modifier = Modifier.clickable {
                    // Open privacy URL or navigate to privacy screen
                }
            )
        }
    }
}

// MARK: - Shimmer Row

@Composable
private fun SettingsShimmerRow() {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = 1200,
                easing = FastOutSlowInEasing
            )
        ),
        label = "shimmerAnimation"
    )

    val baseColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
    val highlightColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)

    val brush = Brush.linearGradient(
        colors = listOf(baseColor, highlightColor, baseColor),
        start = Offset.Zero,
        end = Offset(x = translateAnim, y = translateAnim)
    )

    Row(modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .width(120.dp)
                .height(16.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(brush)
        )
        Spacer(modifier = Modifier.weight(1f))
        Box(
            modifier = Modifier
                .width(80.dp)
                .height(16.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(brush)
        )
    }
}

