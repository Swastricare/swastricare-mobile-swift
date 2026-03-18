package com.swastricare.health.ui.screens.settings

import androidx.compose.animation.core.*
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor
import com.swastricare.health.ui.theme.PrimaryColor

@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToEditProfile: () -> Unit = {},
    onNavigateToFamily: () -> Unit = {},
    onNavigateToNotificationSettings: () -> Unit = {},
    onNavigateToHydrationSettings: () -> Unit = {},
    onNavigateToHealthDataSync: () -> Unit = {},
    onSignOut: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel()
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

        Column(modifier = Modifier.fillMaxSize()) {
            if (uiState.isLoading && uiState.user == null) {
                SettingsLoadingState(modifier = Modifier.fillMaxSize())
            } else {
                // Hero profile header — only rendered once user data is available
                val user = uiState.user
                val avatarUrl = user?.avatarUrl
                val userName = user?.fullName ?: ""
                val userEmail = user?.email ?: ""

                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 88.dp)
                ) {
                    // Profile Header
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 28.dp, bottom = 16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            if (avatarUrl != null) {
                                AsyncImage(
                                    model = ImageRequest.Builder(LocalContext.current)
                                        .data(avatarUrl)
                                        .crossfade(true)
                                        .build(),
                                    contentDescription = "Profile Picture",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .size(90.dp)
                                        .clip(CircleShape)
                                )
                            } else {
                                Box(
                                    modifier = Modifier
                                        .size(90.dp)
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
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = userName.ifEmpty { "User" },
                                style = MaterialTheme.typography.headlineMedium,
                                fontWeight = FontWeight.Bold,
                                color = AppColors.onBackground,
                                textAlign = TextAlign.Center
                            )
                            if (userEmail.isNotEmpty()) {
                                Text(
                                    text = userEmail,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = AppColors.onBackground.copy(alpha = 0.6f),
                                    textAlign = TextAlign.Center
                                )
                            }
                            Text(
                                text = "Member since ${viewModel.memberSince}",
                                style = MaterialTheme.typography.bodySmall,
                                color = AppColors.onBackground.copy(alpha = 0.4f),
                                textAlign = TextAlign.Center
                            )
                        }
                    }

                    // Account Section
                    item {
                        GlassSectionContainer(title = "Account") {
                            SettingsNavigationRow(
                                icon = Icons.Default.AccountCircle,
                                iconTint = PrimaryColor,
                                label = "Account Data",
                                subtitle = "Edit profile, body stats, location",
                                onClick = onNavigateToEditProfile
                            )
                        }
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

                    // Health Data Sync Section
                    item {
                        GlassSectionContainer(title = "Health Data") {
                            SettingsNavigationRow(
                                icon = Icons.Default.Sync,
                                iconTint = PrimaryColor,
                                label = "Health Data Sync",
                                subtitle = "Connect Health Connect, Google Health & more",
                                onClick = onNavigateToHealthDataSync
                            )
                        }
                    }

                    // Security Section
                    item {
                        SettingsSecuritySection(
                            biometricEnabled = uiState.biometricEnabled,
                            onBiometricToggle = { viewModel.toggleBiometric(it) }
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
        SettingsSignOutDialog(
            show = uiState.showSignOutConfirmation,
            onDismiss = { viewModel.setShowSignOutConfirmation(false) },
            onConfirm = { viewModel.signOut() }
        )

        SettingsDeleteAccountDialog(
            show = uiState.showDeleteAccountConfirmation,
            onDismiss = { viewModel.setShowDeleteAccountConfirmation(false) },
            onConfirm = { viewModel.deleteAccount() }
        )

        SettingsErrorDialog(
            errorMessage = uiState.errorMessage,
            onDismiss = { viewModel.clearError() }
        )
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
            "Loading profile...",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onBackground
        )

        Spacer(modifier = Modifier.height(24.dp))

        LinearProgressIndicator(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = PrimaryColor,
            trackColor = AppColors.surfaceVariant.copy(alpha = 0.3f)
        )
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
                    color = AppColors.onSurface.copy(alpha = 0.7f)
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
            color = AppColors.onSurface
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant,
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
            color = AppColors.onSurface
        )
        Spacer(modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = PrimaryColor,
                uncheckedThumbColor = AppColors.outline,
                uncheckedTrackColor = AppColors.surfaceVariant,
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
                color = AppColors.onSurface
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
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
        title = "Quick Stats",
        headerAction = {
            IconButton(onClick = onRefresh, modifier = Modifier.size(24.dp)) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Refresh",
                    tint = PrimaryColor,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    ) {
        if (uiState.isLoadingHealthProfile) {
            repeat(3) {
                SettingsShimmerRow()
                if (it < 2) Spacer(modifier = Modifier.height(12.dp))
            }
        } else if (uiState.healthProfile != null) {
            // 3 stat tiles
            Row(
                modifier = Modifier.fillMaxWidth().height(96.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                QuickStatTile(
                    icon = Icons.Default.Straighten,
                    value = "${uiState.healthProfile.heightCm} cm",
                    label = "Height",
                    color = Color(0xFF30D158),
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                QuickStatTile(
                    icon = Icons.Default.MonitorWeight,
                    value = "${uiState.healthProfile.weightKg} kg",
                    label = "Weight",
                    color = Color(0xFF64D2FF),
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                QuickStatTile(
                    icon = Icons.Default.Accessibility,
                    value = profileBMI,
                    label = "BMI",
                    color = Color(0xFFBF5AF2),
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
            }

            // Info row: gender, age, blood type
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.Default.People, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(16.dp))
                    Text(uiState.healthProfile.gender.displayName, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface)
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.Default.CalendarToday, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(16.dp))
                    Text(profileAge, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface)
                }
                if (uiState.healthProfile.bloodType != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Default.WaterDrop, contentDescription = null, tint = Color(0xFFFF3B30), modifier = Modifier.size(16.dp))
                        Text(uiState.healthProfile.bloodType, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface)
                    }
                }
            }
        } else {
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
                        color = AppColors.onSurface
                    )
                    Text(
                        "Complete your health profile during onboarding",
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
        }
    }
}

// MARK: - Quick Stat Tile

@Composable
private fun QuickStatTile(
    icon: ImageVector,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(color.copy(alpha = 0.12f))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )
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
                    color = AppColors.onSurface
                )
                Text(
                    "Manage family members' health",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
            }
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = AppColors.onSurfaceVariant,
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
            color = AppColors.onSurface.copy(alpha = 0.1f)
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
            icon = Icons.AutoMirrored.Filled.DirectionsRun,
            label = "Activity Level",
            value = "Moderate"
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = AppColors.onSurface.copy(alpha = 0.1f)
        )

        SettingsInfoRow(
            icon = Icons.Default.WaterDrop,
            iconTint = Color(0xFF00C7BE),
            label = "Daily Goal",
            value = "2000 ml"
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = AppColors.onSurface.copy(alpha = 0.1f)
        )

        SettingsNavigationRow(
            icon = Icons.Default.Settings,
            iconTint = AppColors.onSurface,
            label = "Hydration Preferences",
            onClick = onNavigateToHydrationSettings
        )
    }
}

// MARK: - Health Data Sync Section

@Composable
private fun SettingsHealthDataSyncSection(onNavigate: () -> Unit) {
    GlassSectionContainer(title = "Connected Health Apps") {
        SettingsNavigationRow(
            icon = Icons.Default.Sync,
            iconTint = PrimaryColor,
            label = "Health Data Sync",
            subtitle = "Health Connect, Samsung Health, Garmin & more",
            onClick = onNavigate
        )
    }
}

// MARK: - Security & Sync Section

@Composable
private fun SettingsSecuritySection(
    biometricEnabled: Boolean,
    onBiometricToggle: (Boolean) -> Unit
) {
    GlassSectionContainer(title = "Security") {
        SettingsToggleRow(
            icon = Icons.Default.Fingerprint,
            label = "Biometric Lock",
            checked = biometricEnabled,
            onCheckedChange = onBiometricToggle
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
                color = AppColors.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                version,
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
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
            .semantics { contentDescription = "Sign Out" }
            .clickable(enabled = !isLoading) { onClick() }
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = AppColors.error
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ExitToApp,
                    contentDescription = null,
                    tint = AppColors.error,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    "Sign Out",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.error
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
                .semantics { contentDescription = "Delete Account" }
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
            color = AppColors.onBackground.copy(alpha = 0.6f),
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
            color = AppColors.onBackground.copy(alpha = 0.5f)
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
                color = AppColors.onBackground.copy(alpha = 0.5f)
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

    val baseColor = AppColors.surfaceVariant.copy(alpha = 0.3f)
    val highlightColor = AppColors.surfaceVariant.copy(alpha = 0.6f)

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

// MARK: - Dialog Composables

@Composable
private fun SettingsSignOutDialog(
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    if (!show) return
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Sign Out") },
        text = { Text("Are you sure you want to sign out?") },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = AppColors.error
                )
            ) {
                Text("Sign Out")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
        containerColor = AppColors.surface,
        titleContentColor = AppColors.onSurface,
        textContentColor = AppColors.onSurfaceVariant
    )
}

@Composable
private fun SettingsDeleteAccountDialog(
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    if (!show) return
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Delete Account") },
        text = { Text("This action cannot be undone. All your data will be permanently deleted.") },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = AppColors.error
                )
            ) {
                Text("Delete")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
        containerColor = AppColors.surface,
        titleContentColor = AppColors.onSurface,
        textContentColor = AppColors.onSurfaceVariant
    )
}

@Composable
private fun SettingsErrorDialog(
    errorMessage: String?,
    onDismiss: () -> Unit
) {
    if (errorMessage == null) return
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Error") },
        text = { Text(errorMessage) },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("OK")
            }
        },
        containerColor = AppColors.surface,
        titleContentColor = AppColors.onSurface,
        textContentColor = AppColors.onSurfaceVariant
    )
}

