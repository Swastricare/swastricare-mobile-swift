package com.swastricare.health.ui.screens.profile

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.data.model.AppUser
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor
import com.swastricare.health.ui.theme.ThemeMode
import com.swastricare.health.ui.theme.ThemePreferenceManager
import com.swastricare.health.ui.components.TrackScreen

@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel = hiltViewModel(),
    onSignOut: () -> Unit = {},
    onNavigateToNotificationSettings: () -> Unit = {},
    onNavigateToEditProfile: () -> Unit = {},
    onNavigateToFamily: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToHealthConnect: () -> Unit = {}
) {
    TrackScreen("Profile")
    val uiState by viewModel.uiState.collectAsState()
    val signOutEvent by viewModel.signOutEvent.collectAsState()
    val themePreferenceManager = viewModel.themePreferenceManager

    val snackbarHostState = remember { SnackbarHostState() }

    // Handle sign out navigation
    LaunchedEffect(signOutEvent) {
        if (signOutEvent) {
            onSignOut()
            viewModel.onSignOutHandled()
        }
    }

    LaunchedEffect(uiState.errorMessage) {
        uiState.errorMessage?.let { msg ->
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            viewModel.clearError()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        ProfileScreenContent(
            uiState = uiState,
            themePreferenceManager = themePreferenceManager,
            memberSince = viewModel.memberSince,
            profileAge = viewModel.profileAge,
            profileBMI = viewModel.profileBMI,
            appVersion = viewModel.appVersion,
            onRefreshHealthProfile = viewModel::refreshHealthProfile,
            onEditProfile = {
                viewModel.initEditForm()
                onNavigateToEditProfile()
            },
            onNotificationToggle = onNavigateToNotificationSettings,
            onBiometricToggle = viewModel::toggleBiometric,
            onSyncToggle = viewModel::toggleHealthSync,
            onSignOutClick = { viewModel.setShowSignOutConfirmation(true) },
            onDeleteAccountClick = { viewModel.setShowDeleteAccountConfirmation(true) },
            onConfirmSignOut = viewModel::signOut,
            onConfirmDeleteAccount = viewModel::deleteAccount,
            onDismissSignOutDialog = { viewModel.setShowSignOutConfirmation(false) },
            onDismissDeleteAccountDialog = { viewModel.setShowDeleteAccountConfirmation(false) },
            onNavigateToFamily = onNavigateToFamily,
            onNavigateToSettings = onNavigateToSettings,
            onNavigateToHealthConnect = onNavigateToHealthConnect
        )

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 96.dp)
        )
    }
}

@Composable
fun ProfileScreenContent(
    uiState: ProfileUiState,
    themePreferenceManager: ThemePreferenceManager,
    memberSince: String,
    profileAge: String,
    profileBMI: String,
    appVersion: String,
    onRefreshHealthProfile: () -> Unit,
    onEditProfile: () -> Unit = {},
    onNotificationToggle: () -> Unit,
    onBiometricToggle: (Boolean) -> Unit,
    onSyncToggle: (Boolean) -> Unit,
    onSignOutClick: () -> Unit,
    onDeleteAccountClick: () -> Unit,
    onConfirmSignOut: () -> Unit,
    onConfirmDeleteAccount: () -> Unit,
    onDismissSignOutDialog: () -> Unit,
    onDismissDeleteAccountDialog: () -> Unit,
    onNavigateToFamily: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToHealthConnect: () -> Unit = {}
) {
    var showThemeDialog by remember { mutableStateOf(false) }
    val currentTheme by themePreferenceManager.themeMode.collectAsState()

    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // ── Avatar Header ──
            item {
                ProfileHeader(
                    user = uiState.user,
                    memberSince = memberSince,
                    userName = uiState.user?.fullName ?: "User",
                    userEmail = uiState.user?.email ?: "",
                    onEditProfile = onEditProfile
                )
            }

            // ── Account ──
            item { ProfileSectionHeader("Account") }
            item {
                ProfileSectionCard {
                    ProfileNavRow("Edit Profile", Icons.Outlined.Person, onClick = onEditProfile)
                    ProfileDivider()
                    ProfileNavRow("Family", Icons.Outlined.People, onClick = onNavigateToFamily)
                }
            }

            // ── Health Data ──
            item { ProfileSectionHeader("Health Data") }
            item {
                ProfileSectionCard {
                    ProfileNavRow("Health Connect", Icons.Outlined.FavoriteBorder, onClick = onNavigateToHealthConnect)
                }
            }

            // ── Preferences ──
            item { ProfileSectionHeader("Preferences") }
            item {
                ProfileSectionCard {
                    ProfileNavRow("Theme", Icons.Outlined.Palette, value = currentTheme.displayName, onClick = { showThemeDialog = true })
                    ProfileDivider()
                    ProfileNavRow("Notifications", Icons.Outlined.Notifications, onClick = onNotificationToggle)
                    ProfileDivider()
                    ProfileToggleRow("Biometric Lock", Icons.Outlined.Fingerprint, checked = uiState.biometricEnabled, onToggle = onBiometricToggle)
                }
            }

            // ── More ──
            item { ProfileSectionHeader("More") }
            item {
                ProfileSectionCard {
                    ProfileNavRow("All Settings", Icons.Outlined.Settings, onClick = onNavigateToSettings)
                }
            }

            // ── About ──
            item { ProfileSectionHeader("About") }
            item {
                ProfileSectionCard {
                    ProfileInfoRow("App Version", appVersion)
                }
            }

            // ── Sign Out ──
            item {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(AppColors.error.copy(alpha = 0.06f))
                        .clickable(enabled = !uiState.isLoading) { onSignOutClick() }
                        .padding(vertical = 14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (uiState.isLoading) {
                        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Text("Sign Out", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.error)
                    }
                }
            }
        }

        // Sign Out Dialog
        if (uiState.showSignOutConfirmation) {
            AlertDialog(
                onDismissRequest = onDismissSignOutDialog,
                containerColor = AppColors.surfaceVariant.copy(alpha = 0.97f),
                titleContentColor = AppColors.onBackground,
                textContentColor = AppColors.onBackground,
                title = { Text("Sign Out", fontWeight = FontWeight.Bold) },
                text = { Text("Are you sure you want to sign out?") },
                confirmButton = {
                    Button(onClick = onConfirmSignOut, colors = ButtonDefaults.buttonColors(containerColor = AppColors.error)) { Text("Sign Out") }
                },
                dismissButton = {
                    TextButton(onClick = onDismissSignOutDialog) { Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f)) }
                }
            )
        }

        // Theme Dialog
        if (showThemeDialog) {
            AlertDialog(
                onDismissRequest = { showThemeDialog = false },
                containerColor = AppColors.surfaceVariant.copy(alpha = 0.97f),
                titleContentColor = AppColors.onBackground,
                title = { Text("Choose Theme", fontWeight = FontWeight.Bold) },
                text = {
                    Column {
                        ThemeMode.entries.forEach { mode ->
                            Row(
                                modifier = Modifier.fillMaxWidth().clickable { themePreferenceManager.setTheme(mode); showThemeDialog = false }.padding(vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                RadioButton(selected = mode == currentTheme, onClick = { themePreferenceManager.setTheme(mode); showThemeDialog = false }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF22C55E)))
                                Spacer(Modifier.width(8.dp))
                                Column {
                                    Text(mode.displayName, fontSize = 15.sp, color = AppColors.onBackground)
                                    Text(mode.description, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                                }
                            }
                        }
                    }
                },
                confirmButton = {},
                dismissButton = { TextButton(onClick = { showThemeDialog = false }) { Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f)) } }
            )
        }
    }
}

// ── Profile screen building blocks (matching Edit Profile style) ──

@Composable
fun ProfileSectionHeader(title: String) {
    Text(
        title.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = AppColors.onBackground.copy(alpha = 0.35f), letterSpacing = 0.8.sp,
        modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 6.dp)
    )
}

@Composable
fun ProfileSectionCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.surfaceVariant.copy(alpha = 0.45f))
            .padding(horizontal = 16.dp, vertical = 4.dp),
        content = content
    )
}

@Composable
fun ProfileDivider() {
    HorizontalDivider(color = AppColors.onBackground.copy(alpha = 0.06f), thickness = 0.5.dp)
}

@Composable
fun ProfileNavRow(label: String, icon: ImageVector, value: String? = null, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, Modifier.size(20.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
        Spacer(Modifier.width(12.dp))
        Text(label, fontSize = 15.sp, color = AppColors.onBackground, modifier = Modifier.weight(1f))
        if (value != null) {
            Text(value, fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.45f))
            Spacer(Modifier.width(4.dp))
        }
        Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.25f))
    }
}

@Composable
fun ProfileToggleRow(label: String, icon: ImageVector, checked: Boolean, onToggle: (Boolean) -> Unit) {
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
fun ProfileInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontSize = 14.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
        Text(value, fontSize = 14.sp, color = AppColors.onBackground)
    }
}

@Composable
fun ConfirmationDialog(
    title: String,
    text: String,
    confirmText: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(text) },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
            ) {
                Text(confirmText)
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
fun ProfileHeader(
    user: AppUser?,
    memberSince: String,
    userName: String,
    userEmail: String,
    onEditProfile: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Avatar
        Box(contentAlignment = Alignment.BottomEnd) {
            if (user?.avatarUrl != null) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(user.avatarUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = "Profile Picture",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(100.dp)
                        .clip(CircleShape)
                )
            } else {
                DefaultAvatar(name = userName)
            }

            // Edit badge
            IconButton(
                onClick = onEditProfile,
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(PrimaryColor)
            ) {
                Icon(
                    Icons.Default.Edit,
                    contentDescription = "Edit Profile",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        // Info
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = userName,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onBackground
            )
            Text(
                text = userEmail,
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onBackground.copy(alpha = 0.7f)
            )
            Text(
                text = "Member since $memberSince",
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onBackground.copy(alpha = 0.5f)
            )
        }
    }
}

@Composable
fun DefaultAvatar(name: String) {
    Box(
        modifier = Modifier
            .size(100.dp)
            .clip(CircleShape)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(Color(0xFF2E3192), Color(0xFF4A90E2))
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = name.take(1).uppercase(),
            style = MaterialTheme.typography.displayMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

@Composable
fun SectionContainer(
    title: String? = null,
    headerAction: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
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

@Composable
fun HealthProfileSection(
    uiState: ProfileUiState,
    profileAge: String,
    profileBMI: String,
    onRefresh: () -> Unit
) {
    SectionContainer(
        title = "Health Profile",
        headerAction = {
            if (uiState.healthProfile != null && !uiState.isLoadingHealthProfile) {
                IconButton(onClick = onRefresh, modifier = Modifier.size(24.dp)) {
                    Icon(
                        imageVector = Icons.Outlined.Refresh,
                        contentDescription = "Refresh",
                        tint = AppColors.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
        }
    ) {
        if (uiState.isLoadingHealthProfile) {
            repeat(5) {
                ShimmerRow()
                if (it < 4) Spacer(modifier = Modifier.height(12.dp))
            }
        } else if (uiState.healthProfile != null) {
            HealthProfileRow(icon = Icons.Outlined.Person, label = "Name", value = uiState.healthProfile.fullName)
            HorizontalDivider(Modifier.padding(vertical = 8.dp))

            HealthProfileRow(icon = Icons.Outlined.People, label = "Gender", value = uiState.healthProfile.gender.displayName)
            HorizontalDivider(Modifier.padding(vertical = 8.dp))

            HealthProfileRow(icon = Icons.Outlined.CalendarToday, label = "Age", value = profileAge)
            HorizontalDivider(Modifier.padding(vertical = 8.dp))

            HealthProfileRow(icon = Icons.Outlined.Straighten, label = "Height", value = "${uiState.healthProfile.heightCm} cm")
            HorizontalDivider(Modifier.padding(vertical = 8.dp))

            HealthProfileRow(icon = Icons.Outlined.MonitorWeight, label = "Weight", value = "${uiState.healthProfile.weightKg} kg")
            HorizontalDivider(Modifier.padding(vertical = 8.dp))

            HealthProfileRow(icon = Icons.Outlined.Accessibility, label = "BMI", value = profileBMI)

            if (uiState.healthProfile.bloodType != null) {
                HorizontalDivider(Modifier.padding(vertical = 8.dp))
                HealthProfileRow(icon = Icons.Outlined.WaterDrop, label = "Blood Type", value = uiState.healthProfile.bloodType)
            }
        } else {
             Box(
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
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

@Composable
fun HealthProfileRow(
    icon: ImageVector,
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
            tint = AppColors.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
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
fun HydrationSection() {
    SectionContainer(title = "Hydration") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Outlined.DirectionsRun, contentDescription = null, tint = AppColors.onSurface.copy(alpha = 0.6f), modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text("Activity Level", style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Text("Moderate", color = AppColors.onSurfaceVariant)
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))

        Row(
             modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Outlined.WaterDrop, contentDescription = null, tint = AppColors.onSurface.copy(alpha = 0.6f), modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text("Daily Goal", style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Text("2000 ml", color = AppColors.onSurfaceVariant)
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))

        // Hydration Settings Link
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
             Icon(Icons.Outlined.Settings, contentDescription = null, tint = AppColors.onSurface.copy(alpha = 0.6f), modifier = Modifier.size(20.dp))
             Spacer(modifier = Modifier.width(12.dp))
             Text("Hydration Preferences", style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
             Spacer(modifier = Modifier.weight(1f))
             Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun SettingsSection(
    themePreferenceManager: ThemePreferenceManager,
    notificationsEnabled: Boolean,
    biometricEnabled: Boolean,
    healthSyncEnabled: Boolean,
    onNotificationToggle: () -> Unit,
    onBiometricToggle: (Boolean) -> Unit,
    onSyncToggle: (Boolean) -> Unit
) {
    var showThemeDialog by remember { mutableStateOf(false) }
    val currentTheme by themePreferenceManager.themeMode.collectAsState()

    SectionContainer(title = "Settings") {
        // Theme row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showThemeDialog = true },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Outlined.Palette,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = AppColors.onSurface.copy(alpha = 0.6f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "Theme",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = currentTheme.displayName,
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = AppColors.onSurfaceVariant
            )
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))

        // Notification Settings row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onNotificationToggle() },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(imageVector = Icons.Outlined.Notifications, contentDescription = null, modifier = Modifier.size(20.dp), tint = AppColors.onSurface.copy(alpha = 0.6f))
            Spacer(modifier = Modifier.width(12.dp))
            Text(text = "Notification Settings", style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = AppColors.onSurfaceVariant
            )
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))

        SettingToggleRow(
            icon = Icons.Outlined.Fingerprint,
            label = "Biometric Login",
            checked = biometricEnabled,
            onCheckedChange = onBiometricToggle
        )
    }

    // Theme selection dialog
    if (showThemeDialog) {
        AlertDialog(
            onDismissRequest = { showThemeDialog = false },
            title = { Text("Choose Theme") },
            text = {
                Column {
                    ThemeMode.entries.forEach { mode ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    themePreferenceManager.setTheme(mode)
                                    showThemeDialog = false
                                }
                                .padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = mode == currentTheme,
                                onClick = {
                                    themePreferenceManager.setTheme(mode)
                                    showThemeDialog = false
                                },
                                colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF22C55E))
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = mode.displayName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = AppColors.onSurface
                                )
                                Text(
                                    text = mode.description,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = AppColors.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showThemeDialog = false }) {
                    Text("Cancel")
                }
            },
            containerColor = AppColors.surface,
            titleContentColor = AppColors.onSurface
        )
    }
}

@Composable
fun HealthConnectSection(
    isConnected: Boolean,
    onOpenHealthConnect: () -> Unit
) {
    SectionContainer(title = "Health Data") {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onOpenHealthConnect() },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Outlined.FavoriteBorder,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = Color(0xFFDE3730)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Health Connect",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface
                )
                Text(
                    text = "Manage connected health data",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
            }
            Icon(
                imageVector = Icons.Outlined.OpenInNew,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = AppColors.onSurfaceVariant
            )
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (isConnected) Icons.Default.CheckCircle else Icons.Default.Cancel,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = if (isConnected) Color(0xFF4CAF50) else AppColors.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "Sync Status",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = if (isConnected) "Connected" else "Not Connected",
                style = MaterialTheme.typography.bodySmall,
                color = if (isConnected) Color(0xFF4CAF50) else AppColors.onSurfaceVariant
            )
        }

        Text(
            text = "SwasthiCare reads steps, heart rate, sleep, calories, and exercise from Health Connect.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp)
        )
    }
}

@Composable
fun SettingToggleRow(
    icon: ImageVector,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(20.dp), tint = AppColors.onSurface.copy(alpha = 0.6f))
        Spacer(modifier = Modifier.width(12.dp))
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
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
fun AboutSection(version: String) {
    SectionContainer(title = "About") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Outlined.Info, contentDescription = null, modifier = Modifier.size(20.dp), tint = AppColors.onSurface.copy(alpha = 0.6f))
            Spacer(modifier = Modifier.width(12.dp))
            Text("Version", style = MaterialTheme.typography.bodyMedium, color = AppColors.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Text(version, color = AppColors.onSurfaceVariant)
        }
    }

    // Medical Disclaimer — always accessible
    MedicalDisclaimerSection()
}

@Composable
fun MedicalDisclaimerSection() {
    var expanded by remember { mutableStateOf(false) }

    SectionContainer(title = "Medical Disclaimer") {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "SwastriCare provides general health information and wellness tracking tools only. It is NOT a medical device and should NOT be used for medical diagnosis or treatment.",
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant
            )
            Text(
                text = "Always consult a qualified healthcare professional for medical advice, diagnosis, or treatment. Never disregard professional medical advice or delay seeking it because of information provided by this app.",
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant,
                fontWeight = FontWeight.Medium
            )

            if (expanded) {
                Text(
                    text = "AI-generated health insights are for informational purposes only and may not always be accurate. Do not make medical decisions based solely on AI suggestions.",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
                Text(
                    text = "Heart rate measurements, calorie estimates, and other health metrics are approximations and should not replace clinical-grade medical devices.",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurfaceVariant
                )
                Text(
                    text = "If you think you may have a medical emergency, call your doctor or emergency services (108 in India) immediately.",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.error
                )
            }

            TextButton(
                onClick = { expanded = !expanded },
                contentPadding = PaddingValues(0.dp)
            ) {
                Text(
                    text = if (expanded) "Show less" else "Read more",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color(0xFF22C55E)
                )
            }
        }
    }
}

@Composable
fun SignOutSection(
    isLoading: Boolean,
    onDeleteAccount: () -> Unit = {},
    onSignOut: () -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        SectionContainer {
             TextButton(
                onClick = onSignOut,
                modifier = Modifier.fillMaxWidth(),
                enabled = !isLoading,
                colors = ButtonDefaults.textButtonColors(contentColor = AppColors.error)
            ) {
                 if (isLoading) {
                     CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                 } else {
                     Text("Sign Out")
                 }
            }
        }
    }
}

@Composable
fun FamilySection(onNavigateToFamily: () -> Unit) {
    SectionContainer(title = "Family") {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .clickable { onNavigateToFamily() }
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Outlined.People,
                contentDescription = null,
                tint = AppColors.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Family Group",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface
                )
                Text(
                    "View or join a family health group",
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

@Composable
fun ShimmerRow() {
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

    // Adjust shimmer colors for dark mode
    val baseColor = AppColors.surfaceVariant.copy(alpha = 0.3f)
    val highlightColor = AppColors.surfaceVariant.copy(alpha = 0.6f)

    val brush = Brush.linearGradient(
        colors = listOf(
            baseColor,
            highlightColor,
            baseColor
        ),
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

@Preview
@Composable
fun ProfileScreenPreview() {
    ProfileScreen()
}
