package com.swastricare.health.ui.screens.settings

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Straighten
import androidx.compose.material.icons.outlined.Sync
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.swastricare.health.data.model.AppUser
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor
import com.swastricare.health.ui.theme.SecondaryColor
import com.swastricare.health.ui.components.TrackScreen
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToEditProfile: () -> Unit = {},
    onNavigateToFamily: () -> Unit = {},
    onNavigateToNotificationSettings: () -> Unit = {},
    onNavigateToHydrationSettings: () -> Unit = {},
    onNavigateToHealthDataSync: () -> Unit = {},
    onNavigateToThemeSettings: () -> Unit = {},
    onNavigateToActivityGoals: () -> Unit = {},
    onSignOut: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel()
) {
    TrackScreen("Settings")
    val uiState by viewModel.uiState.collectAsState()
    val signOutEvent by viewModel.signOutEvent.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    LaunchedEffect(signOutEvent) {
        if (signOutEvent) {
            onSignOut()
            viewModel.onSignOutHandled()
        }
    }

    val daysActive = remember(uiState.user?.createdAt) {
        computeDaysActive(uiState.user?.createdAt)
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.White)) {
        if (uiState.isLoading && uiState.user == null) {
            SettingsLoadingState(modifier = Modifier.fillMaxSize())
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
            ) {
                // ── Title ──
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

                // ── Profile banner ──
                item {
                    ProfileBannerCard(
                        user = uiState.user,
                        daysActive = daysActive,
                        onClick = onNavigateToEditProfile
                    )
                }

                // ── Account ──
                item { NewSectionLabel("Account") }
                item {
                    NewSettingsCard {
                        NewSettingsRow(
                            icon = Icons.Outlined.PersonOutline,
                            label = "Personal Information",
                            subtitle = "Update your personal details",
                            iconTint = SettingsIconColor.Brand,
                            onClick = onNavigateToEditProfile
                        )
                        NewRowDivider()
                        NewSettingsRow(
                            icon = Icons.Outlined.People,
                            label = "Family",
                            subtitle = "Manage your family group",
                            valueText = "Coming soon",
                            iconTint = SettingsIconColor.Brand,
                            onClick = {
                                scope.launch { snackbarHostState.showSnackbar("Family — coming soon") }
                            }
                        )
                        NewRowDivider()
                        NewSettingsRow(
                            icon = Icons.Outlined.FavoriteBorder,
                            label = "Health Data Sync",
                            subtitle = "Health Connect, Samsung Health & more",
                            iconTint = SettingsIconColor.Brand,
                            onClick = onNavigateToHealthDataSync
                        )
                    }
                }

                // ── Preferences ──
                item { NewSectionLabel("Preferences") }
                item {
                    NewSettingsCard {
                        NewSettingsRow(
                            icon = Icons.Outlined.Notifications,
                            label = "Notifications",
                            subtitle = "Customize your notification settings",
                            iconTint = SettingsIconColor.Brand,
                            onClick = onNavigateToNotificationSettings
                        )
                        NewRowDivider()
                        NewSettingsRow(
                            icon = Icons.Outlined.Flag,
                            label = "Activity Goals",
                            subtitle = "Set daily steps, distance & calorie goals",
                            iconTint = SettingsIconColor.Brand,
                            onClick = onNavigateToActivityGoals
                        )
                        NewRowDivider()
                        NewSettingsToggleRow(
                            icon = Icons.Outlined.Fingerprint,
                            label = "Biometric Lock",
                            checked = uiState.biometricEnabled,
                            iconTint = SettingsIconColor.Brand,
                            onToggle = viewModel::toggleBiometric
                        )
                    }
                }

                // ── Support ──
                item { NewSectionLabel("Support") }
                item {
                    NewSettingsCard {
                        NewSettingsRow(
                            icon = Icons.AutoMirrored.Outlined.ContactSupport,
                            label = "Contact Us",
                            subtitle = "Get in touch with our support team",
                            iconTint = SettingsIconColor.Brand,
                            onClick = {
                                runCatching {
                                    context.startActivity(
                                        Intent(Intent.ACTION_VIEW, Uri.parse("https://swastricare.com"))
                                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    )
                                }.onFailure {
                                    scope.launch {
                                        snackbarHostState.showSnackbar("Couldn't open swastricare.com")
                                    }
                                }
                            }
                        )
                        NewRowDivider()
                        NewSettingsRow(
                            icon = Icons.Outlined.Info,
                            label = "About",
                            subtitle = "Version ${viewModel.appVersion}",
                            iconTint = SettingsIconColor.Brand,
                            onClick = {
                                scope.launch { snackbarHostState.showSnackbar("About — coming soon") }
                            }
                        )
                    }
                }

                // ── Log Out ──
                item {
                    Spacer(Modifier.height(20.dp))
                    NewSettingsCard {
                        NewLogOutRow(
                            isLoading = uiState.isLoading,
                            onClick = { viewModel.setShowSignOutConfirmation(true) }
                        )
                    }
                }

                // ── Footer ──
                item { SettingsFooterLinks(version = viewModel.appVersion) }
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

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
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
// Redesigned Settings building blocks (private)
// ═══════════════════════════════════════════════════════

private object SettingsIconColor {
    val Brand = Color(0xFF22C5A6) // AITeal
}

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
        MountainsBackdrop(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .fillMaxHeight()
                .width(140.dp)
        )

        Row(
            modifier = Modifier.fillMaxSize().padding(horizontal = 14.dp),
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
    Box(
        modifier = Modifier
            .size(56.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.85f))
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
            BannerInitialAvatar(name = user?.fullName ?: "U", size = 52.dp)
        }
    }
}

@Composable
private fun BannerInitialAvatar(name: String, size: Dp) {
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

@Composable
private fun ActiveBadge(daysActive: Int) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier.size(6.dp).clip(CircleShape).background(SecondaryColor)
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

        // Front mountain
        val front = Path().apply {
            moveTo(w * 0.45f, h)
            lineTo(w * 0.78f, h * 0.42f)
            lineTo(w, h)
            close()
        }
        drawPath(front, color = Color.White.copy(alpha = 0.85f))

        // Snow cap
        val cap = Path().apply {
            moveTo(w * 0.74f, h * 0.50f)
            lineTo(w * 0.78f, h * 0.42f)
            lineTo(w * 0.82f, h * 0.50f)
            lineTo(w * 0.80f, h * 0.55f)
            lineTo(w * 0.77f, h * 0.52f)
            close()
        }
        drawPath(cap, color = Color(0xFFE9F5FA))

        drawLine(
            color = Color.White.copy(alpha = 0.4f),
            start = Offset(0f, h * 0.78f),
            end = Offset(w, h * 0.78f),
            strokeWidth = 1f
        )
    }
}

@Composable
private fun NewSectionLabel(text: String) {
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
private fun NewSettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .border(
                width = 1.dp,
                color = Color(0xFFE6E8EB),
                shape = RoundedCornerShape(16.dp)
            ),
        content = content
    )
}

@Composable
private fun NewRowDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 64.dp),
        thickness = 0.5.dp,
        color = AppColors.onBackground.copy(alpha = 0.06f)
    )
}

@Composable
private fun NewSettingsRow(
    icon: ImageVector,
    label: String,
    subtitle: String? = null,
    valueText: String? = null,
    iconTint: Color? = null,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (iconTint != null) {
            NewIconBadge(icon = icon, background = Color.Transparent, tint = iconTint)
        } else {
            NewIconBadge(icon = icon)
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(label, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
            if (subtitle != null) {
                Spacer(Modifier.height(2.dp))
                Text(subtitle, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
            }
        }
        if (valueText != null) {
            Text(valueText, fontSize = 13.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
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
private fun NewSettingsToggleRow(
    icon: ImageVector,
    label: String,
    checked: Boolean,
    enabled: Boolean = true,
    iconTint: Color? = null,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (iconTint != null) {
            NewIconBadge(icon = icon, background = Color.Transparent, tint = iconTint)
        } else {
            NewIconBadge(icon = icon)
        }
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
private fun NewLogOutRow(isLoading: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isLoading) { onClick() }
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        NewIconBadge(
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
private fun NewIconBadge(
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
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
    }
}

private fun computeDaysActive(createdAt: String?): Int {
    if (createdAt.isNullOrBlank()) return 0
    return try {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        val date = format.parse(createdAt.take(19)) ?: return 0
        val diff = System.currentTimeMillis() - date.time
        TimeUnit.MILLISECONDS.toDays(diff).toInt().coerceAtLeast(0)
    } catch (e: Exception) {
        0
    }
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
            .clip(RoundedCornerShape(20.dp))
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

