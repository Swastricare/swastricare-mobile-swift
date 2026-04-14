package com.swastricare.health.ui.screens.settings

import androidx.compose.animation.core.*
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.*
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
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor
import com.swastricare.health.ui.components.TrackScreen

@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToEditProfile: () -> Unit = {},
    onNavigateToFamily: () -> Unit = {},
    onNavigateToNotificationSettings: () -> Unit = {},
    onNavigateToHydrationSettings: () -> Unit = {},
    onNavigateToHealthDataSync: () -> Unit = {},
    onNavigateToThemeSettings: () -> Unit = {},
    onSignOut: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel()
) {
    TrackScreen("Settings")
    val uiState by viewModel.uiState.collectAsState()
    val signOutEvent by viewModel.signOutEvent.collectAsState()

    // Handle sign out navigation
    LaunchedEffect(signOutEvent) {
        if (signOutEvent) {
            onSignOut()
            viewModel.onSignOutHandled()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {

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
                    // ── Avatar Header ──
                    item {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(top = 24.dp, bottom = 8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            if (avatarUrl != null) {
                                AsyncImage(
                                    model = ImageRequest.Builder(LocalContext.current).data(avatarUrl).crossfade(true).build(),
                                    contentDescription = "Profile Picture",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.size(80.dp).clip(CircleShape)
                                )
                            } else {
                                Box(
                                    modifier = Modifier.size(80.dp).clip(CircleShape)
                                        .background(Brush.linearGradient(listOf(Color(0xFF2E3192), Color(0xFF4A90E2)))),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(userName.take(1).uppercase(), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Color.White)
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                            Text(userName.ifEmpty { "User" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = AppColors.onBackground)
                            Text(userEmail, style = MaterialTheme.typography.bodyMedium, color = AppColors.onBackground.copy(alpha = 0.5f))
                            Text("Member since ${viewModel.memberSince}", style = MaterialTheme.typography.bodySmall, color = AppColors.onBackground.copy(alpha = 0.35f))
                        }
                    }

                    // ── Account ──
                    item { SettingsSectionHeader("Account") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanRow("Edit Profile", Icons.Outlined.Person, onClick = onNavigateToEditProfile)
                            // Temporarily removed family section
                            // SettingsCleanDivider()
                            // SettingsCleanRow("Family", Icons.Outlined.People, onClick = onNavigateToFamily)
                        }
                    }

                    // ── Notifications ──
                    item { SettingsSectionHeader("Notifications") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanToggle("Notifications", Icons.Outlined.Notifications, uiState.notificationsEnabled) { viewModel.toggleNotifications(it) }
                            SettingsCleanDivider()
                            SettingsCleanRow("Reminders & Notifications", Icons.Outlined.NotificationsActive, subtitle = "Hydration, medication, diet, cycle, AI", onClick = onNavigateToNotificationSettings)
                        }
                    }

                    // ── Hydration ──
                    item { SettingsSectionHeader("Hydration") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanRow("Hydration Preferences", Icons.Outlined.WaterDrop, onClick = onNavigateToHydrationSettings)
                        }
                    }

                    // ── Health Data ──
                    item { SettingsSectionHeader("Health Data") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanRow("Health Data Sync", Icons.Outlined.Sync, subtitle = "Connect Health Connect, Google Health & more", onClick = onNavigateToHealthDataSync)
                        }
                    }

                    // ── Appearance ──
                    item { SettingsSectionHeader("Appearance") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanRow("Theme", Icons.Outlined.Palette, value = viewModel.themeDisplayName, onClick = onNavigateToThemeSettings)
                        }
                    }

                    // ── Security ──
                    item { SettingsSectionHeader("Security") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanToggle("Biometric Lock", Icons.Outlined.Fingerprint, uiState.biometricEnabled) { viewModel.toggleBiometric(it) }
                        }
                    }

                    // ── About ──
                    item { SettingsSectionHeader("About") }
                    item {
                        SettingsSectionCard {
                            SettingsCleanInfoRow("App Version", viewModel.appVersion)
                        }
                    }

                    // ── Sign Out ──
                    item {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 20.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(Color(0xFFEF4444).copy(alpha = 0.06f))
                                .clickable(enabled = !uiState.isLoading) { viewModel.setShowSignOutConfirmation(true) }
                                .padding(vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            if (uiState.isLoading) {
                                CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                            } else {
                                Text("Sign Out", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = Color(0xFFEF4444))
                            }
                        }
                    }

                    // ── Footer ──
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
                Icons.Outlined.Settings,
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
            color = Color(0xFF22C55E),
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
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surfaceVariant.copy(alpha = 0.5f))
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
    iconTint: Color = AppColors.onSurface.copy(alpha = 0.6f),
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
    iconTint: Color = AppColors.onSurface.copy(alpha = 0.6f),
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
                checkedTrackColor = Color(0xFF22C55E),
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
    iconTint: Color = AppColors.onSurface.copy(alpha = 0.6f),
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
            Icons.Outlined.ChevronRight,
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
                    imageVector = Icons.Outlined.Refresh,
                    contentDescription = "Refresh",
                    tint = AppColors.onSurface.copy(alpha = 0.6f),
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
                    icon = Icons.Outlined.Straighten,
                    value = "${uiState.healthProfile.heightCm} cm",
                    label = "Height",
                    color = AppColors.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                QuickStatTile(
                    icon = Icons.Outlined.MonitorWeight,
                    value = "${uiState.healthProfile.weightKg} kg",
                    label = "Weight",
                    color = AppColors.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                QuickStatTile(
                    icon = Icons.Outlined.Accessibility,
                    value = profileBMI,
                    label = "BMI",
                    color = AppColors.onSurface.copy(alpha = 0.6f),
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
                    Icon(Icons.Outlined.People, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(16.dp))
                    Text(uiState.healthProfile.gender.displayName, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface)
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.Outlined.CalendarToday, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(16.dp))
                    Text(profileAge, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurface)
                }
                if (uiState.healthProfile.bloodType != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Outlined.WaterDrop, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(16.dp))
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
                        imageVector = Icons.Outlined.AccountCircle,
                        contentDescription = null,
                        modifier = Modifier.size(44.dp),
                        tint = AppColors.onSurface.copy(alpha = 0.6f)
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
                    .background(AppColors.onSurface.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Outlined.People,
                    contentDescription = null,
                    tint = AppColors.onSurface.copy(alpha = 0.6f),
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
                Icons.Outlined.ChevronRight,
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
            icon = Icons.Outlined.Notifications,
            label = "Notifications",
            checked = notificationsEnabled,
            onCheckedChange = onNotificationToggle
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = AppColors.onSurface.copy(alpha = 0.1f)
        )

        SettingsNavigationRow(
            icon = Icons.Outlined.NotificationsActive,
            label = "Reminders & Notifications",
            subtitle = "Hydration, medication, diet, cycle, AI",
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
            icon = Icons.AutoMirrored.Outlined.DirectionsRun,
            label = "Activity Level",
            value = "Moderate"
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = AppColors.onSurface.copy(alpha = 0.1f)
        )

        SettingsInfoRow(
            icon = Icons.Outlined.WaterDrop,
            label = "Daily Goal",
            value = "2000 ml"
        )

        HorizontalDivider(
            Modifier.padding(vertical = 8.dp),
            color = AppColors.onSurface.copy(alpha = 0.1f)
        )

        SettingsNavigationRow(
            icon = Icons.Outlined.Settings,
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
            icon = Icons.Outlined.Sync,
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
            icon = Icons.Outlined.Fingerprint,
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
                imageVector = if (hasUpdate) Icons.Outlined.SystemUpdate else Icons.Outlined.Info,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = AppColors.onSurface.copy(alpha = 0.6f)
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
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surfaceVariant.copy(alpha = 0.5f))
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
                .clip(RoundedCornerShape(16.dp))
                .background(AppColors.surfaceVariant.copy(alpha = 0.5f))
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
                    Icons.Outlined.Delete,
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsFooterLinks(version: String) {
    var showTermsSheet by remember { mutableStateOf(false) }
    var showPrivacySheet by remember { mutableStateOf(false) }

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
                color = Color(0xFF22C55E),
                modifier = Modifier.clickable { showTermsSheet = true }
            )
            Text(
                text = "\u2022",
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onBackground.copy(alpha = 0.5f)
            )
            Text(
                text = "Privacy Policy",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF22C55E),
                modifier = Modifier.clickable { showPrivacySheet = true }
            )
        }
    }

    if (showTermsSheet) {
        ModalBottomSheet(
            onDismissRequest = { showTermsSheet = false },
            containerColor = AppColors.surface
        ) {
            SettingsLegalContent(
                title = "Terms of Service",
                content = TERMS_TEXT,
                onDismiss = { showTermsSheet = false }
            )
        }
    }

    if (showPrivacySheet) {
        ModalBottomSheet(
            onDismissRequest = { showPrivacySheet = false },
            containerColor = AppColors.surface
        ) {
            SettingsLegalContent(
                title = "Privacy Policy",
                content = PRIVACY_TEXT,
                onDismiss = { showPrivacySheet = false }
            )
        }
    }
}

@Composable
private fun SettingsLegalContent(title: String, content: String, onDismiss: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp)
    ) {
        Text(
            title,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        Column(
            modifier = Modifier
                .weight(1f, fill = false)
                .heightIn(max = 400.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                content,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = AppColors.onSurface.copy(alpha = 0.8f)
            )
        }
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4F46E5))
        ) {
            Text("Close")
        }
    }
}

private const val TERMS_TEXT = """SwastriCare Terms of Service

Last updated: March 2026

1. ACCEPTANCE OF TERMS
By downloading, installing, or using SwastriCare, you agree to these Terms of Service.

2. USE OF SERVICE
SwastriCare is a personal health tracking app. You must be at least 13 years old to use this app. You are responsible for maintaining the confidentiality of your account.

3. HEALTH DISCLAIMER
SwastriCare provides general health information and tracking tools only. It is NOT a medical device and should NOT be used for medical diagnosis or treatment. Always consult a qualified healthcare professional for medical advice.

4. AI FEATURES
Swastri AI provides health insights using AI models. These are for informational purposes only and may not always be accurate. Never make medical decisions based solely on AI suggestions.

5. USER DATA
You retain ownership of all health data you enter. We process your data as described in our Privacy Policy.

6. TERMINATION
We may suspend or terminate your account for violation of these terms. You may delete your account at any time from Profile settings."""

private const val PRIVACY_TEXT = """SwastriCare Privacy Policy

Last updated: March 2026

DATA WE COLLECT
• Health data: steps, heart rate, calories, medication logs, diet entries, menstrual cycle data
• Profile data: name, date of birth, gender, height, weight, blood type
• Documents: medical records you upload to your Vault
• Usage data: app interactions for improving the experience

HOW WE USE YOUR DATA
• To display your health dashboard and trends
• To power Swastri AI health insights (processed by Google Gemini/MedGemma)
• To sync data across your devices via Supabase

DATA STORAGE
• All data is stored on Supabase servers (AWS ap-south-1 region, India)
• We comply with India's Digital Personal Data Protection Act (DPDPA) 2023
• Data is encrypted in transit and at rest

YOUR RIGHTS
• Access: View all your data in the app
• Delete: Delete your account and all data from Profile settings
• Export: Contact support for a data export
• Correction: Update your profile data at any time

THIRD PARTIES
• Google Gemini/MedGemma: processes AI queries (no data stored)
• Firebase: analytics and crash reporting
• Health Connect: syncs with Android health data (with your permission)

CONTACT
For privacy concerns, contact: privacy@swastricare.com"""

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

// ═══════════════════════════════════════════════════════
// Clean building blocks (matching Edit Profile design)
// ═══════════════════════════════════════════════════════

@Composable
fun SettingsSectionHeader(title: String) {
    Text(
        title.uppercase(),
        fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = AppColors.onBackground.copy(alpha = 0.35f),
        letterSpacing = 0.8.sp,
        modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 6.dp)
    )
}

@Composable
fun SettingsSectionCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.surface)
            .padding(horizontal = 16.dp, vertical = 4.dp),
        content = content
    )
}

@Composable
fun SettingsCleanDivider() {
    HorizontalDivider(color = AppColors.onBackground.copy(alpha = 0.06f), thickness = 0.5.dp)
}

@Composable
fun SettingsCleanRow(
    label: String,
    icon: ImageVector,
    subtitle: String? = null,
    value: String? = null,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, Modifier.size(20.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(label, fontSize = 15.sp, color = AppColors.onBackground)
            if (subtitle != null) {
                Text(subtitle, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.4f))
            }
        }
        if (value != null) {
            Text(value, fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.45f))
            Spacer(Modifier.width(4.dp))
        }
        Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.25f))
    }
}

@Composable
fun SettingsCleanToggle(
    label: String,
    icon: ImageVector,
    checked: Boolean,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, Modifier.size(20.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
        Spacer(Modifier.width(12.dp))
        Text(label, fontSize = 15.sp, color = AppColors.onBackground, modifier = Modifier.weight(1f))
        Switch(
            checked = checked, onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(checkedTrackColor = Color(0xFF22C55E), checkedThumbColor = Color.White)
        )
    }
}

@Composable
fun SettingsCleanInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
        Text(value, fontSize = 14.sp, color = AppColors.onBackground)
    }
}

