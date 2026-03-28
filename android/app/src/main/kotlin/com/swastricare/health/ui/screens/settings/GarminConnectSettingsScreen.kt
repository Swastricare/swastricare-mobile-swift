package com.swastricare.health.ui.screens.settings

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.hilt.navigation.compose.hiltViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.swastricare.health.ui.components.TrackScreen

private const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
private const val GARMIN_PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=$GARMIN_CONNECT_PACKAGE"

// ── UiState & ViewModel ───────────────────────────────────────────────────────

data class GarminConnectUiState(
    val isAppInstalled: Boolean = false,
    val isHealthConnectAvailable: Boolean = false,
    val isLoading: Boolean = true,
    val healthConnectGranted: Boolean = false
)

@HiltViewModel
class GarminConnectSettingsViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService
) : ViewModel() {

    private val _uiState = MutableStateFlow(GarminConnectUiState())
    val uiState: StateFlow<GarminConnectUiState> = _uiState.asStateFlow()

    fun loadStatus(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val installed = isPackageInstalled(context, GARMIN_CONNECT_PACKAGE)
            val hcAvailable = healthConnectService.checkAvailability()
            val hcGranted = if (hcAvailable) {
                try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false }
            } else false
            _uiState.update {
                it.copy(
                    isAppInstalled = installed,
                    isHealthConnectAvailable = hcAvailable,
                    healthConnectGranted = hcGranted,
                    isLoading = false
                )
            }
        }
    }

    private fun isPackageInstalled(context: Context, packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}

// ── Screen ────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GarminConnectSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToHealthConnect: () -> Unit,
    viewModel: GarminConnectSettingsViewModel = hiltViewModel()
) {
    TrackScreen("GarminConnectSettings")
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.loadStatus(context)
    }

    Box(modifier = Modifier.fillMaxSize()) {

        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        "Garmin Connect",
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onBackground
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = AppColors.onBackground
                        )
                    }
                },
                windowInsets = WindowInsets(0, 0, 0, 0),
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Header
                item {
                    GarminHeaderCard(uiState = uiState)
                }

                if (!uiState.isLoading) {
                    // Status / action card
                    item {
                        if (uiState.isAppInstalled) {
                            GarminInstalledCard(
                                hcAvailable = uiState.isHealthConnectAvailable,
                                hcGranted = uiState.healthConnectGranted,
                                onOpenGarminConnect = { openApp(context, GARMIN_CONNECT_PACKAGE) },
                                onNavigateToHealthConnect = onNavigateToHealthConnect
                            )
                        } else {
                            GarminNotInstalledCard(
                                onInstall = { openUrl(context, GARMIN_PLAY_STORE_URL) }
                            )
                        }
                    }

                    // Data types
                    item {
                        GarminDataTypesCard()
                    }

                    // How it works
                    item {
                        GarminHowItWorksCard()
                    }

                    // Supported devices
                    item {
                        GarminDevicesCard()
                    }
                }
            }
        }
    }
}

// ── Header Card ───────────────────────────────────────────────────────────────

@Composable
private fun GarminHeaderCard(uiState: GarminConnectUiState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        Brush.linearGradient(
                            colors = listOf(Color(0xFF007DC3), Color(0xFF005A8E))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.DirectionsRun,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Garmin Connect",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )
                Text(
                    "Garmin wearables & GPS devices",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onBackground.copy(alpha = 0.6f)
                )
            }

            if (uiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Color(0xFF007DC3)
                )
            } else {
                val (badgeColor, badgeLabel) = when {
                    !uiState.isAppInstalled -> Pair(Color(0xFFFF9F0A), "Not Installed")
                    uiState.isHealthConnectAvailable && uiState.healthConnectGranted -> Pair(Color(0xFF34C759), "Ready")
                    else -> Pair(Color(0xFFFF9F0A), "Setup Needed")
                }
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(badgeColor.copy(alpha = 0.15f))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(badgeColor)
                    )
                    Text(
                        badgeLabel,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = badgeColor
                    )
                }
            }
        }
    }
}

// ── Installed Card ────────────────────────────────────────────────────────────

@Composable
private fun GarminInstalledCard(
    hcAvailable: Boolean,
    hcGranted: Boolean,
    onOpenGarminConnect: () -> Unit,
    onNavigateToHealthConnect: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = null,
                tint = Color(0xFF34C759),
                modifier = Modifier.size(18.dp)
            )
            Text(
                "Garmin Connect is installed",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }

        Text(
            "Enable Health Connect sync in Garmin Connect to share your device data with SwastriCare:",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )

        GarminSetupStep(
            number = "1",
            title = "Open Garmin Connect",
            description = "Tap your profile icon → Settings → Health Snapshot & Connections",
            actionLabel = "Open App",
            onAction = onOpenGarminConnect
        )

        GarminSetupStep(
            number = "2",
            title = "Enable Health Connect",
            description = "Scroll to \"Connected Apps\" and enable Health Connect integration",
            actionLabel = null,
            onAction = null
        )

        GarminSetupStep(
            number = "3",
            title = "Grant permissions in SwastriCare",
            description = "Allow SwastriCare to read the synced activity and health data",
            actionLabel = if (!hcGranted) "Manage Permissions" else null,
            onAction = if (!hcGranted) onNavigateToHealthConnect else null
        )

        if (!hcAvailable) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color(0xFFFF9F0A).copy(alpha = 0.12f))
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color(0xFFFF9F0A),
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    "Health Connect is not available. Install or update it to enable Garmin syncing.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFFF9F0A)
                )
            }
        } else if (hcGranted) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color(0xFF34C759).copy(alpha = 0.1f))
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color(0xFF34C759),
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    "All permissions granted. Garmin data will sync automatically.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF34C759)
                )
            }
        }
    }
}

// ── Not Installed Card ────────────────────────────────────────────────────────

@Composable
private fun GarminNotInstalledCard(onInstall: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            Icons.Default.DirectionsRun,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(44.dp)
        )
        Text(
            "Garmin Connect not installed",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Text(
            "Install Garmin Connect and sync it with Health Connect to bring your Garmin device data — routes, workouts, heart rate, and more — into SwastriCare.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        Button(
            onClick = onInstall,
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF007DC3)),
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Install Garmin Connect", fontWeight = FontWeight.SemiBold)
        }
    }
}

// ── Data Types Card ───────────────────────────────────────────────────────────

private data class GarminDataType(val label: String, val icon: ImageVector)

private val garminDataTypes = listOf(
    GarminDataType("Steps & Daily Activity", Icons.Default.DirectionsWalk),
    GarminDataType("Heart Rate & HRV", Icons.Default.Favorite),
    GarminDataType("Sleep Tracking", Icons.Default.Bedtime),
    GarminDataType("GPS Routes & Distance", Icons.Default.Map),
    GarminDataType("Calories & Intensity", Icons.Default.LocalFireDepartment),
    GarminDataType("Running & Cycling", Icons.Default.DirectionsBike),
    GarminDataType("Body Battery & Stress", Icons.Default.BatteryFull),
    GarminDataType("Blood Oxygen (Pulse Ox)", Icons.Default.Bloodtype)
)

@Composable
private fun GarminDataTypesCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        Text(
            "Available Data Types",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface.copy(alpha = 0.7f),
            modifier = Modifier.padding(bottom = 12.dp)
        )
        garminDataTypes.forEachIndexed { index, type ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    type.icon,
                    contentDescription = null,
                    tint = Color(0xFF007DC3),
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    type.label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface,
                    modifier = Modifier.weight(1f)
                )
            }
            if (index < garminDataTypes.lastIndex) {
                HorizontalDivider(
                    modifier = Modifier.padding(vertical = 8.dp),
                    color = AppColors.onSurface.copy(alpha = 0.08f)
                )
            }
        }
    }
}

// ── How It Works Card ─────────────────────────────────────────────────────────

@Composable
private fun GarminHowItWorksCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Default.Info, contentDescription = null, tint = PrimaryColor, modifier = Modifier.size(18.dp))
            Text(
                "How it works",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }
        Text(
            "Your Garmin device syncs to the Garmin Connect app on your phone. When you enable Health Connect integration in Garmin Connect, that data becomes available to SwastriCare through Health Connect automatically.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )

        // Flow diagram
        Spacer(modifier = Modifier.height(4.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            GarminFlowChip(icon = Icons.Default.Watch, label = "Garmin\nDevice", color = Color(0xFF007DC3), modifier = Modifier.weight(1f))
            Icon(Icons.Default.ArrowForward, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(14.dp))
            GarminFlowChip(icon = Icons.Default.PhoneAndroid, label = "Garmin\nConnect", color = Color(0xFF007DC3), modifier = Modifier.weight(1f))
            Icon(Icons.Default.ArrowForward, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(14.dp))
            GarminFlowChip(icon = Icons.Default.Favorite, label = "Health\nConnect", color = Color(0xFF34A853), modifier = Modifier.weight(1f))
            Icon(Icons.Default.ArrowForward, contentDescription = null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(14.dp))
            GarminFlowChip(icon = Icons.Default.HealthAndSafety, label = "Swasthi\nCare", color = PrimaryColor, modifier = Modifier.weight(1f))
        }
    }
}

// ── Devices Card ──────────────────────────────────────────────────────────────

@Composable
private fun GarminDevicesCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "Supported Devices",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Text(
            "Fenix · Forerunner · Venu · Vivoactive · Vivosmart · Instinct · Lily · epix · Descent",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )
        Text(
            "Any Garmin device that syncs to Garmin Connect will work.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant.copy(alpha = 0.7f)
        )
    }
}

// ── Garmin Flow Chip ──────────────────────────────────────────────────────────

@Composable
private fun GarminFlowChip(
    icon: ImageVector,
    label: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(16.dp))
        }
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

// ── Setup Step ────────────────────────────────────────────────────────────────

@Composable
private fun GarminSetupStep(
    number: String,
    title: String,
    description: String,
    actionLabel: String?,
    onAction: (() -> Unit)?
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(Color(0xFF007DC3)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                number,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant
            )
            if (actionLabel != null && onAction != null) {
                TextButton(
                    onClick = onAction,
                    contentPadding = PaddingValues(0.dp)
                ) {
                    Text(
                        actionLabel,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF007DC3),
                        fontWeight = FontWeight.SemiBold
                    )
                    Icon(
                        Icons.Default.OpenInNew,
                        contentDescription = null,
                        modifier = Modifier
                            .size(12.dp)
                            .padding(start = 2.dp),
                        tint = Color(0xFF007DC3)
                    )
                }
            }
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun openApp(context: Context, packageName: String) {
    context.packageManager.getLaunchIntentForPackage(packageName)
        ?.let { context.startActivity(it) }
}

private fun openUrl(context: Context, url: String) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
}
