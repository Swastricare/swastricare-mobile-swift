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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.swastricare.health.ui.components.TrackScreen

private data class GoogleDataType(
    val label: String,
    val description: String,
    val icon: ImageVector,
    val permissions: Set<String>
)

private val googleDataTypes = listOf(
    GoogleDataType("Steps & Activity", "Step count and activity minutes", Icons.Default.DirectionsWalk,
        setOf(HealthPermission.getReadPermission(StepsRecord::class), HealthPermission.getReadPermission(ExerciseSessionRecord::class))),
    GoogleDataType("Heart Rate", "Heart rate from Pixel Watch or Wear OS", Icons.Default.Favorite,
        setOf(HealthPermission.getReadPermission(HeartRateRecord::class))),
    GoogleDataType("Calories", "Calories burned estimated by Android", Icons.Default.LocalFireDepartment,
        setOf(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class), HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))),
    GoogleDataType("Sleep", "Sleep data from Pixel or Wear OS", Icons.Default.Bedtime,
        setOf(HealthPermission.getReadPermission(SleepSessionRecord::class))),
    GoogleDataType("Distance", "Distance from walks and runs", Icons.Default.Map,
        setOf(HealthPermission.getReadPermission(DistanceRecord::class)))
)

data class GoogleHealthUiState(
    val isAvailable: Boolean = false,
    val isLoading: Boolean = true,
    val grantedPermissions: Set<String> = emptySet(),
    val syncEnabled: Boolean = true
)

@HiltViewModel
class GoogleHealthSettingsViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService
) : ViewModel() {
    private val _uiState = MutableStateFlow(GoogleHealthUiState())
    val uiState: StateFlow<GoogleHealthUiState> = _uiState.asStateFlow()

    init { loadStatus() }

    fun loadStatus() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val available = healthConnectService.checkAvailability()
            val granted = if (available) { try { healthConnectService.getGrantedPermissions() } catch (_: Exception) { emptySet() } } else emptySet()
            _uiState.update { it.copy(isAvailable = available, grantedPermissions = granted, isLoading = false) }
        }
    }

    fun onPermissionsResult(granted: Set<String>) { _uiState.update { it.copy(grantedPermissions = granted) } }
    fun toggleSync(enabled: Boolean) { _uiState.update { it.copy(syncEnabled = enabled) } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoogleHealthSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToHealthConnect: () -> Unit,
    viewModel: GoogleHealthSettingsViewModel = hiltViewModel()
) {
    TrackScreen("GoogleHealthSettings")
    val uiState by viewModel.uiState.collectAsState()
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = PermissionController.createRequestPermissionResultContract()
    ) { viewModel.onPermissionsResult(it) }
    val googlePermissions = googleDataTypes.flatMap { it.permissions }.toSet()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Google Health Data", fontWeight = FontWeight.SemiBold) },
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
                        Box(Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(Brush.linearGradient(listOf(Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFEA4335), Color(0xFFFBBC04)))), contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.MonitorHeart, null, tint = Color.White, modifier = Modifier.size(24.dp))
                        }
                        Column(Modifier.weight(1f)) {
                            Text("Google Health Data", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.onBackground)
                            Text("Google Fit & Pixel health data", fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.5f))
                        }
                        if (uiState.isLoading) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color(0xFF22C55E))
                        } else {
                            StatusPill(if (uiState.isAvailable) "Ready" else "Unavailable", if (uiState.isAvailable) Color(0xFF34C759) else Color(0xFFFF3B30))
                        }
                    }
                    SettingsCleanDivider()
                    SettingsCleanToggle("Sync Google Health Data", Icons.Default.Sync, uiState.syncEnabled) { viewModel.toggleSync(it) }
                }
            }

            // How it works
            item { SettingsSectionHeader("How It Works") }
            item {
                SettingsSectionCard {
                    Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Google Health data is routed through Health Connect. Make sure Health Connect permissions are granted.", fontSize = 13.sp, color = AppColors.onBackground.copy(alpha = 0.6f))
                        Row(modifier = Modifier.clickable { onNavigateToHealthConnect() }, verticalAlignment = Alignment.CenterVertically) {
                            Text("Manage Health Connect →", fontSize = 13.sp, color = Color(0xFF22C55E), fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }

            if (!uiState.isLoading) {
                // Data types
                item { SettingsSectionHeader("Data Types") }
                item {
                    SettingsSectionCard {
                        googleDataTypes.forEachIndexed { index, dt ->
                            if (index > 0) SettingsCleanDivider()
                            val granted = dt.permissions.all { it in uiState.grantedPermissions }
                            Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(dt.icon, null, Modifier.size(20.dp), tint = if (granted) Color(0xFF34C759) else AppColors.onBackground.copy(alpha = 0.4f))
                                Column(Modifier.weight(1f)) {
                                    Text(dt.label, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
                                    Text(dt.description, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.4f))
                                }
                                if (granted) {
                                    Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF34C759), modifier = Modifier.size(20.dp))
                                } else {
                                    TextButton(onClick = { permissionLauncher.launch(dt.permissions) }, contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)) {
                                        Text("Allow", fontSize = 13.sp, color = Color(0xFF22C55E), fontWeight = FontWeight.SemiBold)
                                    }
                                }
                            }
                        }
                    }
                }

                if (uiState.isAvailable && !googleDataTypes.all { dt -> dt.permissions.all { it in uiState.grantedPermissions } }) {
                    item {
                        Button(
                            onClick = { permissionLauncher.launch(googlePermissions) },
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Lock, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Grant All Permissions", fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StatusPill(label: String, color: Color) {
    Row(
        modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(color.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(Modifier.size(5.dp).clip(CircleShape).background(color))
        Text(label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = color)
    }
}
