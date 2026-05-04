package com.swastricare.health.ui.screens.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ContactSupport
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.automirrored.outlined.VolumeUp
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Fingerprint
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.Straighten
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Canvas
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.launch
import com.swastricare.health.data.model.AppUser
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SecondaryColor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

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
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

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

    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {
        ProfileScreenContent(
            uiState = uiState,
            daysActive = remember(uiState.user?.createdAt) { computeDaysActive(uiState.user?.createdAt) },
            appVersion = viewModel.appVersion,
            onEditProfile = {
                viewModel.initEditForm()
                onNavigateToEditProfile()
            },
            onNotificationsClick = onNavigateToNotificationSettings,
            onBiometricToggle = viewModel::toggleBiometric,
            onNavigateToFamily = onNavigateToFamily,
            onNavigateToHealthConnect = onNavigateToHealthConnect,
            onSignOutClick = { viewModel.setShowSignOutConfirmation(true) },
            onPlaceholder = { label ->
                scope.launch {
                    snackbarHostState.showSnackbar("$label — coming soon")
                }
            }
        )

        // Sign Out Dialog
        if (uiState.showSignOutConfirmation) {
            AlertDialog(
                onDismissRequest = { viewModel.setShowSignOutConfirmation(false) },
                containerColor = AppColors.surface,
                titleContentColor = AppColors.onBackground,
                textContentColor = AppColors.onBackground,
                title = { Text("Sign Out", fontWeight = FontWeight.Bold) },
                text = { Text("Are you sure you want to sign out?") },
                confirmButton = {
                    Button(
                        onClick = { viewModel.signOut() },
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.error)
                    ) { Text("Sign Out") }
                },
                dismissButton = {
                    TextButton(onClick = { viewModel.setShowSignOutConfirmation(false) }) {
                        Text("Cancel", color = AppColors.onBackground.copy(alpha = 0.6f))
                    }
                }
            )
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
        )
    }
}

@Composable
private fun ProfileScreenContent(
    uiState: ProfileUiState,
    daysActive: Int,
    appVersion: String,
    onEditProfile: () -> Unit,
    onNotificationsClick: () -> Unit,
    onBiometricToggle: (Boolean) -> Unit,
    onNavigateToFamily: () -> Unit,
    onNavigateToHealthConnect: () -> Unit,
    onSignOutClick: () -> Unit,
    onPlaceholder: (String) -> Unit
) {
    var soundsOn by remember { mutableStateOf(true) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
    ) {
        item {
            Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) {
                Text(
                    "Settings",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "Manage your profile and preferences",
                    fontSize = 13.sp,
                    color = AppColors.onBackground.copy(alpha = 0.5f)
                )
            }
        }

        item {
            ProfileBannerCard(
                user = uiState.user,
                daysActive = daysActive,
                onClick = onEditProfile
            )
        }

        // ── Account ──
        item { SectionLabel("Account") }
        item {
            SettingsCard {
                SettingsRow(
                    icon = Icons.Outlined.PersonOutline,
                    label = "Personal Information",
                    subtitle = "Update your personal details",
                    onClick = onEditProfile
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.People,
                    label = "Family",
                    subtitle = "Manage your family group",
                    onClick = onNavigateToFamily
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.FavoriteBorder,
                    label = "Health Connect",
                    subtitle = "Sync with Google Health Connect",
                    onClick = onNavigateToHealthConnect
                )
            }
        }

        // ── Preferences ──
        item { SectionLabel("Preferences") }
        item {
            SettingsCard {
                SettingsRow(
                    icon = Icons.Outlined.Notifications,
                    label = "Notifications",
                    subtitle = "Customize your notification settings",
                    onClick = onNotificationsClick
                )
                RowDivider()
                SettingsToggleRow(
                    icon = Icons.Outlined.DarkMode,
                    label = "Dark Mode",
                    checked = false,
                    enabled = false,
                    onToggle = { /* theme switching temporarily disabled */ }
                )
                RowDivider()
                SettingsToggleRow(
                    icon = Icons.Outlined.Fingerprint,
                    label = "Biometric Lock",
                    checked = uiState.biometricEnabled,
                    onToggle = onBiometricToggle
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.Straighten,
                    label = "Units",
                    valueText = "Metric (km, kg)",
                    onClick = { onPlaceholder("Units") }
                )
                RowDivider()
                SettingsToggleRow(
                    icon = Icons.AutoMirrored.Outlined.VolumeUp,
                    label = "Sounds",
                    checked = soundsOn,
                    onToggle = { soundsOn = it }
                )
            }
        }

        // ── Support ──
        item { SectionLabel("Support") }
        item {
            SettingsCard {
                SettingsRow(
                    icon = Icons.AutoMirrored.Outlined.HelpOutline,
                    label = "Help & FAQs",
                    subtitle = "Find answers to common questions",
                    onClick = { onPlaceholder("Help & FAQs") }
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.AutoMirrored.Outlined.ContactSupport,
                    label = "Contact Us",
                    subtitle = "Get in touch with our support team",
                    onClick = { onPlaceholder("Contact Us") }
                )
                RowDivider()
                SettingsRow(
                    icon = Icons.Outlined.Info,
                    label = "About",
                    subtitle = "Version $appVersion",
                    onClick = { onPlaceholder("About") }
                )
            }
        }

        // ── Log Out ──
        item {
            Spacer(Modifier.height(20.dp))
            SettingsCard {
                LogOutRow(
                    isLoading = uiState.isLoading,
                    onClick = onSignOutClick
                )
            }
        }
    }
}

// ── Profile Banner ──────────────────────────────────────────────

@Composable
private fun ProfileBannerCard(
    user: AppUser?,
    daysActive: Int,
    onClick: () -> Unit
) {
    val gradient = Brush.linearGradient(
        colors = listOf(Color(0xFFD9F0E4), Color(0xFFC2E0EE)),
        start = Offset(0f, 0f),
        end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY)
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(gradient)
            .clickable { onClick() }
            .height(96.dp)
    ) {
        // Decorative mountains on the right
        MountainsBackdrop(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .fillMaxHeight()
                .width(140.dp)
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BannerAvatar(user)
            Spacer(Modifier.width(12.dp))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    user?.fullName?.takeIf { it.isNotBlank() } ?: "Set up your profile",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF0F2027),
                    maxLines = 1
                )
                Text(
                    user?.email ?: "",
                    fontSize = 12.sp,
                    color = Color(0xFF0F2027).copy(alpha = 0.6f),
                    maxLines = 1
                )
                Spacer(Modifier.height(2.dp))
                ActiveBadge(daysActive)
            }
            Icon(
                Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = Color(0xFF0F2027).copy(alpha = 0.5f),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
private fun BannerAvatar(user: AppUser?) {
    val ringColor = Color.White.copy(alpha = 0.85f)
    Box(
        modifier = Modifier
            .size(56.dp)
            .clip(CircleShape)
            .background(ringColor)
            .padding(2.dp)
    ) {
        if (user?.avatarUrl != null) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(user.avatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "Profile picture",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize().clip(CircleShape)
            )
        } else {
            DefaultAvatar(name = user?.fullName ?: "U", size = 52.dp)
        }
    }
}

@Composable
private fun ActiveBadge(daysActive: Int) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(SecondaryColor)
        )
        Text(
            if (daysActive <= 0) "Active today" else "Active for $daysActive days",
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF0F2027).copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun MountainsBackdrop(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height

        // Sun
        drawCircle(
            color = Color(0xFFFFE6A8),
            radius = h * 0.11f,
            center = Offset(w * 0.55f, h * 0.32f)
        )

        // Back mountain
        val back = Path().apply {
            moveTo(w * 0.20f, h)
            lineTo(w * 0.55f, h * 0.30f)
            lineTo(w * 0.85f, h)
            close()
        }
        drawPath(back, color = Color.White.copy(alpha = 0.55f))

        // Front mountain (overlapping)
        val front = Path().apply {
            moveTo(w * 0.45f, h)
            lineTo(w * 0.78f, h * 0.42f)
            lineTo(w, h)
            close()
        }
        drawPath(front, color = Color.White.copy(alpha = 0.85f))

        // Snow cap on front mountain
        val cap = Path().apply {
            moveTo(w * 0.74f, h * 0.50f)
            lineTo(w * 0.78f, h * 0.42f)
            lineTo(w * 0.82f, h * 0.50f)
            // soft zig-zag
            lineTo(w * 0.80f, h * 0.55f)
            lineTo(w * 0.77f, h * 0.52f)
            close()
        }
        drawPath(cap, color = Color(0xFFE9F5FA))

        // Subtle horizon line
        drawLine(
            color = Color.White.copy(alpha = 0.4f),
            start = Offset(0f, h * 0.78f),
            end = Offset(w, h * 0.78f),
            strokeWidth = 1f
        )
    }
}

// ── Sections / Rows ─────────────────────────────────────────────

@Composable
private fun SectionLabel(text: String) {
    Text(
        text.uppercase(),
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.8.sp,
        color = AppColors.onBackground.copy(alpha = 0.4f),
        modifier = Modifier.padding(start = 24.dp, top = 24.dp, bottom = 8.dp)
    )
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface),
        content = content
    )
}

@Composable
private fun RowDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 64.dp),
        thickness = 0.5.dp,
        color = AppColors.onBackground.copy(alpha = 0.06f)
    )
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    label: String,
    subtitle: String? = null,
    valueText: String? = null,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconBadge(icon = icon)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                label,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onBackground
            )
            if (subtitle != null) {
                Spacer(Modifier.height(2.dp))
                Text(
                    subtitle,
                    fontSize = 12.sp,
                    color = AppColors.onBackground.copy(alpha = 0.5f)
                )
            }
        }
        if (valueText != null) {
            Text(
                valueText,
                fontSize = 13.sp,
                color = AppColors.onBackground.copy(alpha = 0.5f)
            )
            Spacer(Modifier.width(4.dp))
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = AppColors.onBackground.copy(alpha = 0.3f),
            modifier = Modifier.size(20.dp)
        )
    }
}

@Composable
private fun SettingsToggleRow(
    icon: ImageVector,
    label: String,
    checked: Boolean,
    enabled: Boolean = true,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconBadge(icon = icon)
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onBackground.copy(alpha = if (enabled) 1f else 0.6f),
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = checked,
            onCheckedChange = onToggle,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedTrackColor = SecondaryColor,
                checkedThumbColor = Color.White,
                checkedBorderColor = Color.Transparent,
                uncheckedTrackColor = AppColors.surfaceVariant,
                uncheckedThumbColor = Color.White,
                uncheckedBorderColor = Color.Transparent,
                disabledCheckedTrackColor = AppColors.surfaceVariant,
                disabledUncheckedTrackColor = AppColors.surfaceVariant,
                disabledUncheckedThumbColor = Color.White,
                disabledUncheckedBorderColor = Color.Transparent
            )
        )
    }
}

@Composable
private fun LogOutRow(isLoading: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isLoading) { onClick() }
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconBadge(
            icon = Icons.AutoMirrored.Outlined.Logout,
            background = AppColors.error.copy(alpha = 0.10f),
            tint = AppColors.error
        )
        Spacer(Modifier.width(12.dp))
        Text(
            "Log Out",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.error,
            modifier = Modifier.weight(1f)
        )
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                strokeWidth = 2.dp,
                color = AppColors.error
            )
        }
    }
}

@Composable
private fun IconBadge(
    icon: ImageVector,
    background: Color = AppColors.onBackground.copy(alpha = 0.06f),
    tint: Color = AppColors.onBackground.copy(alpha = 0.75f)
) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(background),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ── Avatar fallback ─────────────────────────────────────────────

@Composable
fun DefaultAvatar(name: String, size: Dp = 100.dp) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(Color(0xFF2E3192), Color(0xFF4A90E2))
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = name.firstOrNull()?.uppercase() ?: "U",
            fontSize = (size.value * 0.4f).sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

// ── Helpers ─────────────────────────────────────────────────────

private fun computeDaysActive(createdAt: String?): Int {
    if (createdAt.isNullOrBlank()) return 0
    return try {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        val date: Date = format.parse(createdAt.take(19)) ?: return 0
        val diff = System.currentTimeMillis() - date.time
        TimeUnit.MILLISECONDS.toDays(diff).toInt().coerceAtLeast(0)
    } catch (e: Exception) {
        0
    }
}

@Preview
@Composable
fun ProfileScreenPreview() {
    ProfileScreen()
}
