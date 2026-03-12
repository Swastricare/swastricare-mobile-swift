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

private const val SAMSUNG_HEALTH_PACKAGE = "com.sec.android.app.shealth"
private const val PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=$SAMSUNG_HEALTH_PACKAGE"

// ── UiState & ViewModel ───────────────────────────────────────────────────────

data class SamsungHealthUiState(
    val isAppInstalled: Boolean = false,
    val isHealthConnectAvailable: Boolean = false,
    val isLoading: Boolean = true,
    val healthConnectGranted: Boolean = false
)

class SamsungHealthSettingsViewModel : ViewModel() {

    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService

    private val _uiState = MutableStateFlow(SamsungHealthUiState())
    val uiState: StateFlow<SamsungHealthUiState> = _uiState.asStateFlow()

    fun loadStatus(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val installed = isPackageInstalled(context, SAMSUNG_HEALTH_PACKAGE)
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
fun SamsungHealthSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToHealthConnect: () -> Unit,
    viewModel: SamsungHealthSettingsViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.loadStatus(context)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        "Samsung Health",
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
                    SamsungHealthHeaderCard(uiState = uiState, isLoading = uiState.isLoading)
                }

                if (!uiState.isLoading) {
                    // Status / Action card
                    item {
                        if (uiState.isAppInstalled) {
                            SamsungHealthInstalledCard(
                                hcAvailable = uiState.isHealthConnectAvailable,
                                hcGranted = uiState.healthConnectGranted,
                                onOpenSamsungHealth = { openApp(context, SAMSUNG_HEALTH_PACKAGE) },
                                onNavigateToHealthConnect = onNavigateToHealthConnect
                            )
                        } else {
                            SamsungHealthNotInstalledCard(
                                onInstall = { openUrl(context, PLAY_STORE_URL) }
                            )
                        }
                    }

                    // Sync data types
                    item {
                        SamsungDataTypesCard()
                    }

                    // How it works
                    item {
                        SamsungHowItWorksCard()
                    }
                }
            }
        }
    }
}

// ── Header Card ───────────────────────────────────────────────────────────────

@Composable
private fun SamsungHealthHeaderCard(
    uiState: SamsungHealthUiState,
    isLoading: Boolean
) {
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
                            colors = listOf(Color(0xFF1428A0), Color(0xFF0F5EBA))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Watch,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Samsung Health",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )
                Text(
                    "Galaxy Watch & Samsung devices",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onBackground.copy(alpha = 0.6f)
                )
            }

            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Color(0xFF1428A0)
                )
            } else {
                ConnectedBadge(
                    connected = uiState.isAppInstalled && uiState.isHealthConnectAvailable,
                    label = when {
                        !uiState.isAppInstalled -> "Not Installed"
                        uiState.isHealthConnectAvailable -> "Ready"
                        else -> "Setup Needed"
                    }
                )
            }
        }
    }
}

// ── Installed Card ────────────────────────────────────────────────────────────

@Composable
private fun SamsungHealthInstalledCard(
    hcAvailable: Boolean,
    hcGranted: Boolean,
    onOpenSamsungHealth: () -> Unit,
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
                "Samsung Health is installed",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }

        Text(
            "To sync Samsung Health data with SwastriCare, follow these steps:",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )

        SetupStep(
            number = "1",
            title = "Open Samsung Health",
            description = "Go to Settings → Connected services → Health Connect",
            actionLabel = "Open App",
            onAction = onOpenSamsungHealth
        )

        SetupStep(
            number = "2",
            title = "Enable Health Connect sync",
            description = "Toggle on \"Sync with Health Connect\" in Samsung Health settings",
            actionLabel = null,
            onAction = null
        )

        SetupStep(
            number = "3",
            title = "Grant Health Connect permissions",
            description = "Allow SwastriCare to read the synced data from Health Connect",
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
                    "Health Connect is not available. Please install or update it to enable syncing.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFFF9F0A)
                )
            }
        }
    }
}

// ── Not Installed Card ────────────────────────────────────────────────────────

@Composable
private fun SamsungHealthNotInstalledCard(onInstall: () -> Unit) {
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
            Icons.Default.Watch,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(44.dp)
        )
        Text(
            "Samsung Health not installed",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )
        Text(
            "Install Samsung Health to sync Galaxy Watch and Samsung device data with SwastriCare via Health Connect.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        Button(
            onClick = onInstall,
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1428A0)),
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Install Samsung Health", fontWeight = FontWeight.SemiBold)
        }
    }
}

// ── Data Types Card ───────────────────────────────────────────────────────────

private data class SamsungDataType(val label: String, val icon: ImageVector)

private val samsungDataTypes = listOf(
    SamsungDataType("Steps & Walking", Icons.Default.DirectionsWalk),
    SamsungDataType("Heart Rate", Icons.Default.Favorite),
    SamsungDataType("Sleep Tracking", Icons.Default.Bedtime),
    SamsungDataType("Blood Oxygen (SpO2)", Icons.Default.Bloodtype),
    SamsungDataType("Stress Score", Icons.Default.SelfImprovement),
    SamsungDataType("Body Composition", Icons.Default.MonitorWeight),
    SamsungDataType("Workout Sessions", Icons.Default.FitnessCenter)
)

@Composable
private fun SamsungDataTypesCard() {
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
        samsungDataTypes.forEachIndexed { index, type ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    type.icon,
                    contentDescription = null,
                    tint = Color(0xFF1428A0),
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    type.label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurface,
                    modifier = Modifier.weight(1f)
                )
            }
            if (index < samsungDataTypes.lastIndex) {
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
private fun SamsungHowItWorksCard() {
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
            "Samsung Health data is synced to Android Health Connect. SwastriCare reads this data from Health Connect, keeping your Galaxy Watch and Samsung device metrics in sync with your health profile.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )
    }
}

// ── Setup Step ────────────────────────────────────────────────────────────────

@Composable
private fun SetupStep(
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
                .background(Color(0xFF1428A0)),
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
                        color = Color(0xFF1428A0),
                        fontWeight = FontWeight.SemiBold
                    )
                    Icon(
                        Icons.Default.OpenInNew,
                        contentDescription = null,
                        modifier = Modifier.size(12.dp).padding(start = 2.dp),
                        tint = Color(0xFF1428A0)
                    )
                }
            }
        }
    }
}

// ── Shared Badge ──────────────────────────────────────────────────────────────

@Composable
private fun ConnectedBadge(connected: Boolean, label: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(
                if (connected) Color(0xFF34C759).copy(alpha = 0.15f)
                else Color(0xFFFF9F0A).copy(alpha = 0.15f)
            )
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(if (connected) Color(0xFF34C759) else Color(0xFFFF9F0A))
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = if (connected) Color(0xFF34C759) else Color(0xFFFF9F0A)
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun openApp(context: Context, packageName: String) {
    val intent = context.packageManager.getLaunchIntentForPackage(packageName)
    if (intent != null) {
        context.startActivity(intent)
    }
}

private fun openUrl(context: Context, url: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    context.startActivity(intent)
}
