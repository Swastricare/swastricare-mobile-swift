package com.swastricare.health.ui.screens.settings

import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.di.AppContainer
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ── Model ─────────────────────────────────────────────────────────────────────

enum class HealthAppId { HEALTH_CONNECT, GOOGLE_HEALTH, SAMSUNG_HEALTH, GARMIN_CONNECT }

data class HealthAppEntry(
    val id: HealthAppId,
    val label: String,
    val subtitle: String,
    val icon: ImageVector,
    val iconGradient: List<Color>,
    val packageName: String? = null        // null = no app to install check (built-in platform)
)

private val healthApps = listOf(
    HealthAppEntry(
        id = HealthAppId.HEALTH_CONNECT,
        label = "Health Connect",
        subtitle = "Android health data platform",
        icon = Icons.Default.Favorite,
        iconGradient = listOf(Color(0xFF4285F4), Color(0xFF34A853)),
        packageName = null
    ),
    HealthAppEntry(
        id = HealthAppId.GOOGLE_HEALTH,
        label = "Google Health Data",
        subtitle = "Steps, sleep, heart rate & more",
        icon = Icons.Default.MonitorHeart,
        iconGradient = listOf(Color(0xFF34A853), Color(0xFF4285F4)),
        packageName = null
    ),
    HealthAppEntry(
        id = HealthAppId.SAMSUNG_HEALTH,
        label = "Samsung Health",
        subtitle = "Galaxy Watch & Samsung devices",
        icon = Icons.Default.Watch,
        iconGradient = listOf(Color(0xFF1428A0), Color(0xFF0F5EBA)),
        packageName = "com.sec.android.app.shealth"
    ),
    HealthAppEntry(
        id = HealthAppId.GARMIN_CONNECT,
        label = "Garmin Connect",
        subtitle = "Garmin wearables & GPS devices",
        icon = Icons.Default.DirectionsRun,
        iconGradient = listOf(Color(0xFF007DC3), Color(0xFF005A8E)),
        packageName = "com.garmin.android.apps.connectmobile"
    )
)

// ── UiState ───────────────────────────────────────────────────────────────────

data class HealthDataSyncUiState(
    val isHealthConnectAvailable: Boolean = false,
    val hasAllPermissions: Boolean = false,
    val installedPackages: Set<String> = emptySet(),
    val isLoading: Boolean = true
)

// ── ViewModel ─────────────────────────────────────────────────────────────────

class HealthDataSyncViewModel : ViewModel() {

    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService

    private val _uiState = MutableStateFlow(HealthDataSyncUiState())
    val uiState: StateFlow<HealthDataSyncUiState> = _uiState.asStateFlow()

    fun load(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            val hcAvailable = healthConnectService.checkAvailability()
            val allPerms = if (hcAvailable) {
                try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false }
            } else false

            val installed = healthApps
                .mapNotNull { it.packageName }
                .filter { pkg -> isInstalled(context, pkg) }
                .toSet()

            _uiState.update {
                it.copy(
                    isHealthConnectAvailable = hcAvailable,
                    hasAllPermissions = allPerms,
                    installedPackages = installed,
                    isLoading = false
                )
            }
        }
    }

    private fun isInstalled(context: Context, pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES)
        true
    } catch (_: PackageManager.NameNotFoundException) { false }
}

// ── Screen ────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthDataSyncScreen(
    onNavigateBack: () -> Unit,
    onNavigateTo: (HealthAppId) -> Unit,
    viewModel: HealthDataSyncViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.load(context) }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        "Health Data Sync",
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
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp)
            ) {
                // Summary banner
                item {
                    HealthSyncBanner(
                        hcAvailable = uiState.isHealthConnectAvailable,
                        allPerms = uiState.hasAllPermissions,
                        isLoading = uiState.isLoading
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }

                // App list inside a glass card
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .glass()
                            .padding(8.dp)
                    ) {
                        healthApps.forEachIndexed { index, app ->
                            val statusInfo = appStatusInfo(
                                app = app,
                                uiState = uiState
                            )
                            HealthAppRow(
                                app = app,
                                statusLabel = statusInfo.first,
                                statusColor = statusInfo.second,
                                onClick = { onNavigateTo(app.id) }
                            )
                            if (index < healthApps.lastIndex) {
                                HorizontalDivider(
                                    modifier = Modifier.padding(horizontal = 8.dp),
                                    color = AppColors.onSurface.copy(alpha = 0.08f)
                                )
                            }
                        }
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Tap any app to manage its connection and permissions.",
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onBackground.copy(alpha = 0.5f),
                        modifier = Modifier.padding(horizontal = 4.dp)
                    )
                }
            }
        }
    }
}

// ── Banner ────────────────────────────────────────────────────────────────────

@Composable
private fun HealthSyncBanner(
    hcAvailable: Boolean,
    allPerms: Boolean,
    isLoading: Boolean
) {
    val (bgColor, icon, message) = when {
        isLoading -> Triple(AppColors.surfaceVariant.copy(alpha = 0.3f), Icons.Default.HourglassEmpty, "Checking status…")
        !hcAvailable -> Triple(Color(0xFFFF3B30).copy(alpha = 0.1f), Icons.Default.Warning, "Health Connect unavailable — install or update it to enable syncing")
        !allPerms -> Triple(Color(0xFFFF9F0A).copy(alpha = 0.1f), Icons.Default.Info, "Some permissions are missing — tap Health Connect to grant them")
        else -> Triple(Color(0xFF34C759).copy(alpha = 0.1f), Icons.Default.CheckCircle, "Health Connect is set up and all permissions are granted")
    }
    val textColor = when {
        isLoading -> AppColors.onSurfaceVariant
        !hcAvailable -> Color(0xFFFF3B30)
        !allPerms -> Color(0xFFFF9F0A)
        else -> Color(0xFF34C759)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(icon, contentDescription = null, tint = textColor, modifier = Modifier.size(20.dp))
        Text(message, style = MaterialTheme.typography.bodySmall, color = textColor)
    }
}

// ── Row ───────────────────────────────────────────────────────────────────────

@Composable
private fun HealthAppRow(
    app: HealthAppEntry,
    statusLabel: String,
    statusColor: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(horizontal = 8.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Icon with gradient background
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(11.dp))
                .background(Brush.linearGradient(app.iconGradient)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                app.icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(22.dp)
            )
        }

        // Labels
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                app.label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Text(
                app.subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant
            )
        }

        // Status pill + chevron
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(statusColor.copy(alpha = 0.12f))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(5.dp)
                        .clip(CircleShape)
                        .background(statusColor)
                )
                Text(
                    statusLabel,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = statusColor
                )
            }
        }

        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(18.dp)
        )
    }
}

// ── Status helpers ────────────────────────────────────────────────────────────

private fun appStatusInfo(
    app: HealthAppEntry,
    uiState: HealthDataSyncUiState
): Pair<String, Color> {
    if (uiState.isLoading) return "Checking" to Color(0xFF8E8E93)

    return when (app.id) {
        HealthAppId.HEALTH_CONNECT -> when {
            !uiState.isHealthConnectAvailable -> "Unavailable" to Color(0xFFFF3B30)
            uiState.hasAllPermissions -> "Connected" to Color(0xFF34C759)
            else -> "Setup needed" to Color(0xFFFF9F0A)
        }
        HealthAppId.GOOGLE_HEALTH -> when {
            !uiState.isHealthConnectAvailable -> "Unavailable" to Color(0xFFFF3B30)
            uiState.hasAllPermissions -> "Active" to Color(0xFF34C759)
            else -> "Permissions needed" to Color(0xFFFF9F0A)
        }
        HealthAppId.SAMSUNG_HEALTH -> when {
            app.packageName != null && app.packageName !in uiState.installedPackages ->
                "Not installed" to Color(0xFF8E8E93)
            !uiState.isHealthConnectAvailable -> "Setup needed" to Color(0xFFFF9F0A)
            else -> "Ready" to Color(0xFF34C759)
        }
        HealthAppId.GARMIN_CONNECT -> when {
            app.packageName != null && app.packageName !in uiState.installedPackages ->
                "Not installed" to Color(0xFF8E8E93)
            !uiState.isHealthConnectAvailable -> "Setup needed" to Color(0xFFFF9F0A)
            else -> "Ready" to Color(0xFF34C759)
        }
    }
}
