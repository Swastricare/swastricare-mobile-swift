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

private const val SAMSUNG_HEALTH_PACKAGE = "com.sec.android.app.shealth"
private const val PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=$SAMSUNG_HEALTH_PACKAGE"

data class SamsungHealthUiState(
    val isAppInstalled: Boolean = false,
    val isHealthConnectAvailable: Boolean = false,
    val isLoading: Boolean = true,
    val healthConnectGranted: Boolean = false
)

@HiltViewModel
class SamsungHealthSettingsViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService
) : ViewModel() {
    private val _uiState = MutableStateFlow(SamsungHealthUiState())
    val uiState: StateFlow<SamsungHealthUiState> = _uiState.asStateFlow()

    fun loadStatus(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val installed = isPackageInstalled(context, SAMSUNG_HEALTH_PACKAGE)
            val hcAvailable = healthConnectService.checkAvailability()
            val hcGranted = if (hcAvailable) { try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false } } else false
            _uiState.update { it.copy(isAppInstalled = installed, isHealthConnectAvailable = hcAvailable, healthConnectGranted = hcGranted, isLoading = false) }
        }
    }

    private fun isPackageInstalled(context: Context, packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES); true
    } catch (_: PackageManager.NameNotFoundException) { false }
}

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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SamsungHealthSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToHealthConnect: () -> Unit,
    viewModel: SamsungHealthSettingsViewModel = hiltViewModel()
) {
    TrackScreen("SamsungHealthSettings")
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    LaunchedEffect(Unit) { viewModel.loadStatus(context) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Samsung Health", fontWeight = FontWeight.SemiBold) },
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
                        Box(Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(Brush.linearGradient(listOf(Color(0xFF1428A0), Color(0xFF0F5EBA)))), contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.Watch, null, tint = Color.White, modifier = Modifier.size(24.dp))
                        }
                        Column(Modifier.weight(1f)) {
                            Text("Samsung Health", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.onBackground)
                            Text("Galaxy Watch & Samsung devices", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                        }
                        if (uiState.isLoading) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color(0xFF22C55E))
                        } else {
                            val (label, color) = when {
                                !uiState.isAppInstalled -> "Not Installed" to Color(0xFFFF9F0A)
                                uiState.isHealthConnectAvailable -> "Ready" to Color(0xFF34C759)
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
                            CleanSetupStep(1, "Open Samsung Health", "Settings → Connected services → Health Connect", "Open App") { openApp(context, SAMSUNG_HEALTH_PACKAGE) }
                            SettingsCleanDivider()
                            CleanSetupStep(2, "Enable Health Connect sync", "Toggle on \"Sync with Health Connect\" in Samsung Health settings", null, null)
                            SettingsCleanDivider()
                            CleanSetupStep(3, "Grant Health Connect permissions", "Allow SwastriCare to read synced data", if (!uiState.healthConnectGranted) "Manage Permissions" else null, if (!uiState.healthConnectGranted) onNavigateToHealthConnect else null)
                        }
                    }

                    if (!uiState.isHealthConnectAvailable) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFFFF9F0A).copy(alpha = 0.08f)).padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Icon(Icons.Default.Warning, null, tint = Color(0xFFFF9F0A), modifier = Modifier.size(18.dp))
                                Text("Health Connect is not available. Please install or update it.", fontSize = 13.sp, color = Color(0xFFFF9F0A))
                            }
                        }
                    }
                } else {
                    // Not installed
                    item {
                        SettingsSectionCard {
                            Column(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.Watch, null, tint = AppColors.onBackground.copy(alpha = 0.3f), modifier = Modifier.size(40.dp))
                                Spacer(Modifier.height(8.dp))
                                Text("Samsung Health not installed", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onBackground)
                                Text("Install Samsung Health to sync Galaxy device data via Health Connect.", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                                Spacer(Modifier.height(12.dp))
                                Button(
                                    onClick = { openUrl(context, PLAY_STORE_URL) },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Icon(Icons.Default.Download, null, Modifier.size(18.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Install Samsung Health", fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }

                // Data types
                item { SettingsSectionHeader("Available Data Types") }
                item {
                    SettingsSectionCard {
                        samsungDataTypes.forEachIndexed { index, type ->
                            if (index > 0) SettingsCleanDivider()
                            Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(type.icon, null, Modifier.size(20.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
                                Text(type.label, fontSize = 15.sp, color = AppColors.onBackground, modifier = Modifier.weight(1f))
                            }
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
                                "Samsung Health data syncs to Health Connect, then SwastriCare reads it from there. This keeps your Galaxy Watch and Samsung device metrics in sync with your health profile.",
                                fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.45f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CleanSetupStep(number: Int, title: String, description: String, actionLabel: String?, onAction: (() -> Unit)?) {
    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(24.dp).clip(CircleShape).background(Color(0xFF22C55E)), contentAlignment = Alignment.Center) {
            Text("$number", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White)
        }
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
            Text(description, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
            if (actionLabel != null && onAction != null) {
                TextButton(onClick = onAction, contentPadding = PaddingValues(0.dp)) {
                    Text(actionLabel, fontSize = 12.sp, color = Color(0xFF22C55E), fontWeight = FontWeight.SemiBold)
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
