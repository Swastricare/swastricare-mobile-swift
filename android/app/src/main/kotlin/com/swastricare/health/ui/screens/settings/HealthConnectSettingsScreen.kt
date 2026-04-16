package com.swastricare.health.ui.screens.settings

import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.hilt.navigation.compose.hiltViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.components.AppTopBar
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.swastricare.health.ui.components.TrackScreen

// ── Data classes ──

data class PermissionGroup(
    val label: String,
    val description: String,
    val icon: ImageVector,
    val permissions: Set<String>
)

data class HealthConnectSettingsUiState(
    val isAvailable: Boolean = false,
    val isLoading: Boolean = true,
    val grantedPermissions: Set<String> = emptySet(),
    val syncEnabled: Boolean = true,
    val errorMessage: String? = null
) {
    fun isGroupGranted(group: PermissionGroup): Boolean =
        group.permissions.all { it in grantedPermissions }
}

// ── ViewModel ──

@HiltViewModel
class HealthConnectSettingsViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService,
    private val analyticsService: AppAnalyticsService
) : ViewModel() {
    private val _uiState = MutableStateFlow(HealthConnectSettingsUiState())
    val uiState: StateFlow<HealthConnectSettingsUiState> = _uiState.asStateFlow()

    init { loadStatus() }

    fun loadStatus() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val available = healthConnectService.checkAvailability()
            val granted = if (available) { try { healthConnectService.getGrantedPermissions() } catch (_: Exception) { emptySet() } } else emptySet()
            _uiState.update { it.copy(isAvailable = available, grantedPermissions = granted, isLoading = false) }
        }
    }

    fun onPermissionsResult(granted: Set<String>) {
        _uiState.update { it.copy(grantedPermissions = granted) }
        healthConnectService.invalidateCache()
    }

    fun toggleSync(enabled: Boolean) {
        _uiState.update { it.copy(syncEnabled = enabled) }
        analyticsService.trackHealthConnectToggled(enabled)
    }

    fun clearError() { _uiState.update { it.copy(errorMessage = null) } }
}

// ── Permission groups ──

private val permissionGroups = listOf(
    PermissionGroup("Steps & Distance", "Daily step count and distance walked", Icons.Default.DirectionsWalk,
        setOf(HealthPermission.getReadPermission(StepsRecord::class), HealthPermission.getReadPermission(DistanceRecord::class))),
    PermissionGroup("Heart Rate", "Heart rate measurements", Icons.Default.Favorite,
        setOf(HealthPermission.getReadPermission(HeartRateRecord::class), HealthPermission.getWritePermission(HeartRateRecord::class))),
    PermissionGroup("Calories", "Active and total calories burned", Icons.Default.LocalFireDepartment,
        setOf(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class), HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))),
    PermissionGroup("Sleep", "Sleep sessions and duration", Icons.Default.Bedtime,
        setOf(HealthPermission.getReadPermission(SleepSessionRecord::class))),
    PermissionGroup("Exercise", "Workout sessions and activities", Icons.Default.FitnessCenter,
        setOf(HealthPermission.getReadPermission(ExerciseSessionRecord::class), HealthPermission.getWritePermission(ExerciseSessionRecord::class))),
    PermissionGroup("Body Measurements", "Weight data", Icons.Default.MonitorWeight,
        setOf(HealthPermission.getReadPermission(WeightRecord::class))),
    PermissionGroup("Hydration", "Water intake logging", Icons.Default.WaterDrop,
        setOf(HealthPermission.getWritePermission(HydrationRecord::class)))
)

// ── Screen ──

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthConnectSettingsScreen(
    onNavigateBack: () -> Unit,
    viewModel: HealthConnectSettingsViewModel = hiltViewModel()
) {
    TrackScreen("HealthConnectSettings")
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.errorMessage) {
        uiState.errorMessage?.let { snackbarHostState.showSnackbar(it, duration = SnackbarDuration.Short); viewModel.clearError() }
    }

    val context = LocalContext.current
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = PermissionController.createRequestPermissionResultContract()
    ) { viewModel.onPermissionsResult(it) }

    // Opens Android's Health Connect settings page where the user can revoke permissions
    val openHealthConnectSettings: () -> Unit = {
        try {
            val intent = android.content.Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
            intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        } catch (_: Exception) {
            // Fallback: open Health Connect manage permissions for our app
            try {
                val intent = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = android.net.Uri.fromParts("package", context.packageName, null)
                intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            } catch (_: Exception) {}
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            AppTopBar(title = "Health Connect", onBack = onNavigateBack)
        },
        containerColor = Color.Transparent
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            // ── Header card ──
            item {
                SettingsSectionCard {
                    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        AsyncImage(
                            model = ImageRequest.Builder(LocalContext.current)
                                .data("file:///android_asset/images/health connect.png")
                                .crossfade(true).build(),
                            contentDescription = null,
                            modifier = Modifier.size(48.dp).clip(RoundedCornerShape(12.dp))
                        )
                        Column(Modifier.weight(1f)) {
                            Text("Health Connect", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.onBackground)
                            Text("Android health data platform", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                        }
                        if (uiState.isLoading) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color(0xFF22C55E))
                        } else {
                            val available = uiState.isAvailable
                            val color = if (available) Color(0xFF34C759) else Color(0xFFFF3B30)
                            Row(Modifier.clip(RoundedCornerShape(20.dp)).background(color.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 3.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Box(Modifier.size(5.dp).clip(CircleShape).background(color))
                                Text(if (available) "Available" else "Unavailable", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = color)
                            }
                        }
                    }
                    SettingsCleanDivider()
                    SettingsCleanToggle("Sync with SwastriCare", Icons.Default.Sync, uiState.syncEnabled) { viewModel.toggleSync(it) }
                }
            }

            if (!uiState.isLoading) {
                // ── Status banner ──
                item {
                    val allGranted = permissionGroups.all { uiState.isGroupGranted(it) }
                    val grantedCount = permissionGroups.count { uiState.isGroupGranted(it) }
                    val (bannerColor, bannerIcon, bannerMsg) = when {
                        !uiState.isAvailable -> Triple(Color(0xFFFF3B30), Icons.Default.Warning, "Health Connect is not available. Install or update it from the Play Store.")
                        allGranted -> Triple(Color(0xFF34C759), Icons.Default.CheckCircle, "All permissions granted")
                        else -> Triple(Color(0xFFFF9F0A), Icons.Default.Info, "$grantedCount of ${permissionGroups.size} permission groups granted")
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 16.dp)
                            .clip(RoundedCornerShape(14.dp)).background(bannerColor.copy(alpha = 0.08f)).padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(bannerIcon, null, tint = bannerColor, modifier = Modifier.size(18.dp))
                        Text(bannerMsg, fontSize = 13.sp, color = bannerColor)
                    }
                }

                // ── Action buttons ──
                if (uiState.isAvailable) {
                    val anyMissing = !permissionGroups.all { uiState.isGroupGranted(it) }
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            if (anyMissing) {
                                Button(
                                    onClick = { permissionLauncher.launch(HealthConnectService.ALL_PERMISSIONS) },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Icon(Icons.Default.Lock, null, Modifier.size(18.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Grant All", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                                }
                            }
                            OutlinedButton(
                                onClick = openHealthConnectSettings,
                                modifier = Modifier.weight(1f),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.onBackground),
                                border = androidx.compose.foundation.BorderStroke(1.dp, AppColors.onBackground.copy(alpha = 0.15f))
                            ) {
                                Icon(Icons.Default.Settings, null, Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Manage in Settings", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                            }
                        }
                    }
                }

                // ── Permission groups ──
                item { SettingsSectionHeader("Data Permissions") }
                item {
                    SettingsSectionCard {
                        permissionGroups.forEachIndexed { index, group ->
                            if (index > 0) SettingsCleanDivider()
                            val granted = uiState.isGroupGranted(group)
                            Row(
                                Modifier.fillMaxWidth().clickable {
                                    if (granted) openHealthConnectSettings()
                                    else permissionLauncher.launch(group.permissions)
                                }.padding(vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(group.icon, null, Modifier.size(20.dp), tint = if (granted) Color(0xFF34C759) else AppColors.onBackground.copy(alpha = 0.4f))
                                Column(Modifier.weight(1f)) {
                                    Text(group.label, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
                                    Text(
                                        if (granted) "Tap to revoke in settings" else group.description,
                                        fontSize = 12.sp,
                                        color = AppColors.onBackground.copy(alpha = 0.4f)
                                    )
                                }
                                if (granted) {
                                    Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF34C759), modifier = Modifier.size(20.dp))
                                } else {
                                    Text("Allow", fontSize = 13.sp, color = Color(0xFF22C55E), fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }

                // ── Info ──
                item { SettingsSectionHeader("About") }
                item {
                    SettingsSectionCard {
                        Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Icon(Icons.Default.Info, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.5f))
                            Text(
                                "Health Connect is Android's secure health data platform. SwastriCare uses it to read fitness data from other apps and write hydration, heart rate, and workout data back.",
                                fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.45f)
                            )
                        }
                    }
                }
            }
        }
    }
}
