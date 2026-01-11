package com.swasthicare.mobile.ui.screens.profile

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swasthicare.mobile.data.model.AppUser
import com.swasthicare.mobile.ui.theme.PrimaryColor

@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    ProfileScreenContent(
        uiState = uiState,
        memberSince = viewModel.memberSince,
        profileAge = viewModel.profileAge,
        profileBMI = viewModel.profileBMI,
        appVersion = viewModel.appVersion,
        onRefreshHealthProfile = viewModel::refreshHealthProfile,
        onNotificationToggle = viewModel::toggleNotifications,
        onBiometricToggle = viewModel::toggleBiometric,
        onSyncToggle = viewModel::toggleHealthSync,
        onSignOutClick = { viewModel.setShowSignOutConfirmation(true) },
        onDeleteAccountClick = { viewModel.setShowDeleteAccountConfirmation(true) },
        onConfirmSignOut = viewModel::signOut,
        onConfirmDeleteAccount = viewModel::deleteAccount,
        onDismissSignOutDialog = { viewModel.setShowSignOutConfirmation(false) },
        onDismissDeleteAccountDialog = { viewModel.setShowDeleteAccountConfirmation(false) }
    )
}

@Composable
fun ProfileScreenContent(
    uiState: ProfileUiState,
    memberSince: String,
    profileAge: String,
    profileBMI: String,
    appVersion: String,
    onRefreshHealthProfile: () -> Unit,
    onNotificationToggle: (Boolean) -> Unit,
    onBiometricToggle: (Boolean) -> Unit,
    onSyncToggle: (Boolean) -> Unit,
    onSignOutClick: () -> Unit,
    onDeleteAccountClick: () -> Unit,
    onConfirmSignOut: () -> Unit,
    onConfirmDeleteAccount: () -> Unit,
    onDismissSignOutDialog: () -> Unit,
    onDismissDeleteAccountDialog: () -> Unit
) {
    // Background - solid color based on theme
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // Profile Header
            item {
                ProfileHeader(
                    user = uiState.user,
                    memberSince = memberSince,
                    userName = uiState.user?.fullName ?: "User",
                    userEmail = uiState.user?.email ?: ""
                )
            }

            // Health Profile Section
            item {
                HealthProfileSection(
                    uiState = uiState,
                    profileAge = profileAge,
                    profileBMI = profileBMI,
                    onRefresh = onRefreshHealthProfile
                )
            }

            // Hydration Section
            item {
                HydrationSection()
            }

            // Settings Section
            item {
                SettingsSection(
                    notificationsEnabled = uiState.notificationsEnabled,
                    biometricEnabled = uiState.biometricEnabled,
                    healthSyncEnabled = uiState.healthSyncEnabled,
                    onNotificationToggle = onNotificationToggle,
                    onBiometricToggle = onBiometricToggle,
                    onSyncToggle = onSyncToggle
                )
            }

            // About Section
            item {
                AboutSection(version = appVersion)
            }

            // Sign Out Section
            item {
                SignOutSection(
                    isLoading = uiState.isLoading,
                    onDeleteAccount = onDeleteAccountClick,
                    onSignOut = onSignOutClick
                )
            }
        }

        // Dialogs
        if (uiState.showSignOutConfirmation) {
            ConfirmationDialog(
                title = "Sign Out",
                text = "Are you sure you want to sign out?",
                confirmText = "Sign Out",
                onConfirm = onConfirmSignOut,
                onDismiss = onDismissSignOutDialog
            )
        }

        if (uiState.showDeleteAccountConfirmation) {
            ConfirmationDialog(
                title = "Delete Account",
                text = "This action cannot be undone. All your data will be permanently deleted.",
                confirmText = "Delete",
                onConfirm = onConfirmDeleteAccount,
                onDismiss = onDismissDeleteAccountDialog
            )
        }
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
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
            ) {
                Text(confirmText)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
        containerColor = MaterialTheme.colorScheme.surface,
        titleContentColor = MaterialTheme.colorScheme.onSurface,
        textContentColor = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
fun ProfileHeader(
    user: AppUser?,
    memberSince: String,
    userName: String,
    userEmail: String
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Avatar
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

        // Info
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp)
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
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 2.dp
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
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
                        imageVector = Icons.Default.Refresh,
                        contentDescription = "Refresh",
                        tint = PrimaryColor
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
            HealthProfileRow(icon = Icons.Default.Person, label = "Name", value = uiState.healthProfile.fullName)
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            
            HealthProfileRow(icon = Icons.Default.People, label = "Gender", value = uiState.healthProfile.gender.displayName)
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            
            HealthProfileRow(icon = Icons.Default.CalendarToday, label = "Age", value = profileAge)
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            
            HealthProfileRow(icon = Icons.Default.Straighten, label = "Height", value = "${uiState.healthProfile.heightCm} cm")
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            
            HealthProfileRow(icon = Icons.Default.MonitorWeight, label = "Weight", value = "${uiState.healthProfile.weightKg} kg")
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            
            HealthProfileRow(icon = Icons.Default.Accessibility, label = "BMI", value = profileBMI)
            
            if (uiState.healthProfile.bloodType != null) {
                HorizontalDivider(Modifier.padding(vertical = 8.dp))
                HealthProfileRow(icon = Icons.Default.WaterDrop, label = "Blood Type", value = uiState.healthProfile.bloodType)
            }
        } else {
             Box(
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
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
            tint = PrimaryColor,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
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
fun HydrationSection() {
    SectionContainer(title = "Hydration") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.DirectionsRun, contentDescription = null, tint = PrimaryColor, modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text("Activity Level", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Text("Moderate", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        
        Row(
             modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.WaterDrop, contentDescription = null, tint = PrimaryColor, modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text("Daily Goal", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Text("2000 ml", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        
        // Hydration Settings Link
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
             Icon(Icons.Default.Settings, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface, modifier = Modifier.size(20.dp))
             Spacer(modifier = Modifier.width(12.dp))
             Text("Hydration Preferences", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
             Spacer(modifier = Modifier.weight(1f))
             Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun SettingsSection(
    notificationsEnabled: Boolean,
    biometricEnabled: Boolean,
    healthSyncEnabled: Boolean,
    onNotificationToggle: (Boolean) -> Unit,
    onBiometricToggle: (Boolean) -> Unit,
    onSyncToggle: (Boolean) -> Unit
) {
    SectionContainer(title = "Settings") {
        SettingToggleRow(
            icon = Icons.Default.Notifications,
            label = "Notifications",
            checked = notificationsEnabled,
            onCheckedChange = onNotificationToggle
        )
        
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        
        SettingToggleRow(
            icon = Icons.Default.Fingerprint,
            label = "Biometric Login",
            checked = biometricEnabled,
            onCheckedChange = onBiometricToggle
        )
        
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        
        SettingToggleRow(
            icon = Icons.Default.Sync,
            label = "Auto Sync Health",
            checked = healthSyncEnabled,
            onCheckedChange = onSyncToggle
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
        Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(20.dp), tint = PrimaryColor)
        Spacer(modifier = Modifier.width(12.dp))
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
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
fun AboutSection(version: String) {
    SectionContainer(title = "About") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Outlined.Info, contentDescription = null, modifier = Modifier.size(20.dp), tint = PrimaryColor)
            Spacer(modifier = Modifier.width(12.dp))
            Text("Version", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Spacer(modifier = Modifier.weight(1f))
            Text(version, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun SignOutSection(
    isLoading: Boolean,
    onDeleteAccount: () -> Unit,
    onSignOut: () -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        SectionContainer {
            TextButton(
                onClick = onDeleteAccount,
                modifier = Modifier.fillMaxWidth(),
                enabled = !isLoading,
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
            ) {
                 Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Delete Account")
                }
            }
        }
        
        Text(
            text = "Permanently delete your account and all associated data.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        SectionContainer {
             TextButton(
                onClick = onSignOut,
                modifier = Modifier.fillMaxWidth(),
                enabled = !isLoading,
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
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
    val baseColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
    val highlightColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
    
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
