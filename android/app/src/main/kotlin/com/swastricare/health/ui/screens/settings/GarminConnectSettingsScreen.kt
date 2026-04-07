package com.swastricare.health.ui.screens.settings

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.hilt.navigation.compose.hiltViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.swastricare.health.ui.components.TrackScreen

private const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
private const val GARMIN_PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=$GARMIN_CONNECT_PACKAGE"

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
            val hcGranted = if (hcAvailable) { try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false } } else false
            _uiState.update { it.copy(isAppInstalled = installed, isHealthConnectAvailable = hcAvailable, healthConnectGranted = hcGranted, isLoading = false) }
        }
    }

    private fun isPackageInstalled(context: Context, packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES); true
    } catch (_: PackageManager.NameNotFoundException) { false }
}

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
    LaunchedEffect(Unit) { viewModel.loadStatus(context) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Garmin Connect", fontWeight = FontWeight.SemiBold) },
                navigationIcon = { IconButton(onClick = onNavigateBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = AppColors.onBackground, navigationIconContentColor = AppColors.onBackground),
                windowInsets = WindowInsets(0, 0, 0, 0)
            )
        },
        containerColor = Color.Transparent
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            // Header
            item {
                SettingsSectionCard {
                    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(Brush.linearGradient(listOf(Color(0xFF007DC3), Color(0xFF005A8E)))), contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.DirectionsRun, null, tint = Color.White, modifier = Modifier.size(24.dp))
                        }
                        Column(Modifier.weight(1f)) {
                            Text("Garmin Connect", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.onBackground)
                            Text("Garmin wearables & GPS devices", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                        }
                        if (uiState.isLoading) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color(0xFF22C55E))
                        } else {
                            val (label, color) = when {
                                !uiState.isAppInstalled -> "Not Installed" to Color(0xFFFF9F0A)
                                uiState.isHealthConnectAvailable && uiState.healthConnectGranted -> "Ready" to Color(0xFF34C759)
                                else -> "Setup Needed" to Color(0xFFFF9F0A)
                            }
                            StatusPill(label, color)
                        }
                    }
                }
            }

            if (!uiState.isLoading) {
                if (uiState.isAppInstalled) {
                    // Setup steps
                    item { SettingsSectionHeader("Setup Steps") }
                    item {
                        SettingsSectionCard {
                            CleanSetupStep(1, "Open Garmin Connect", "Profile icon → Settings → Health Snapshot & Connections", "Open App") { openApp(context, GARMIN_CONNECT_PACKAGE) }
                            SettingsCleanDivider()
                            CleanSetupStep(2, "Enable Health Connect", "Scroll to \"Connected Apps\" and enable Health Connect", null, null)
                            SettingsCleanDivider()
                            CleanSetupStep(3, "Grant permissions in SwastriCare", "Allow SwastriCare to read synced data", if (!uiState.healthConnectGranted) "Manage Permissions" else null, if (!uiState.healthConnectGranted) onNavigateToHealthConnect else null)
                        }
                    }

                    if (!uiState.isHealthConnectAvailable) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFFFF9F0A).copy(alpha = 0.08f)).padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Icon(Icons.Default.Warning, null, tint = Color(0xFFFF9F0A), modifier = Modifier.size(18.dp))
                                Text("Health Connect not available. Install or update it.", fontSize = 13.sp, color = Color(0xFFFF9F0A))
                            }
                        }
                    } else if (uiState.healthConnectGranted) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFF34C759).copy(alpha = 0.08f)).padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF34C759), modifier = Modifier.size(18.dp))
                                Text("All permissions granted. Garmin data will sync automatically.", fontSize = 13.sp, color = Color(0xFF34C759))
                            }
                        }
                    }
                } else {
                    // Not installed
                    item {
                        SettingsSectionCard {
                            Column(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.DirectionsRun, null, tint = AppColors.onBackground.copy(alpha = 0.3f), modifier = Modifier.size(40.dp))
                                Spacer(Modifier.height(8.dp))
                                Text("Garmin Connect not installed", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onBackground)
                                Text("Install Garmin Connect to bring routes, workouts, and heart rate data into SwastriCare.", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f), textAlign = TextAlign.Center)
                                Spacer(Modifier.height(12.dp))
                                Button(
                                    onClick = { openUrl(context, GARMIN_PLAY_STORE_URL) },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Icon(Icons.Default.Download, null, Modifier.size(18.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Install Garmin Connect", fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }

                // Data types
                item { SettingsSectionHeader("Available Data Types") }
                item {
                    SettingsSectionCard {
                        garminDataTypes.forEachIndexed { index, type ->
                            if (index > 0) SettingsCleanDivider()
                            Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(type.icon, null, Modifier.size(20.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
                                Text(type.label, fontSize = 15.sp, color = AppColors.onBackground, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }

                // Supported devices
                item { SettingsSectionHeader("Supported Devices") }
                item {
                    SettingsSectionCard {
                        Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("Fenix · Forerunner · Venu · Vivoactive · Vivosmart · Instinct · Lily · epix · Descent", fontSize = 13.sp, color = AppColors.onBackground.copy(alpha = 0.6f))
                            Text("Any Garmin device that syncs to Garmin Connect will work.", fontSize = 11.sp, color = AppColors.onBackground.copy(alpha = 0.4f))
                        }
                    }
                }

                // Info
                item { SettingsSectionHeader("How It Works") }
                item {
                    SettingsSectionCard {
                        Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Icon(Icons.Default.Info, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
                            Text(
                                "Your Garmin device syncs to Garmin Connect on your phone. When you enable Health Connect integration in Garmin Connect, that data becomes available to SwastriCare automatically.",
                                fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.45f)
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun openApp(context: Context, packageName: String) {
    context.packageManager.getLaunchIntentForPackage(packageName)?.let { context.startActivity(it) }
}

private fun openUrl(context: Context, url: String) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
}
