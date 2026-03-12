package com.swastricare.health.ui.screens.settings

import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.di.AppContainer
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor
import com.swastricare.health.ui.theme.PrimaryColor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ── Data classes ──────────────────────────────────────────────────────────────

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

// ── ViewModel ─────────────────────────────────────────────────────────────────

class HealthConnectSettingsViewModel : ViewModel() {

    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService

    private val _uiState = MutableStateFlow(HealthConnectSettingsUiState())
    val uiState: StateFlow<HealthConnectSettingsUiState> = _uiState.asStateFlow()

    init {
        loadStatus()
    }

    fun loadStatus() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val available = healthConnectService.checkAvailability()
            val granted = if (available) {
                try {
                    healthConnectService.getGrantedPermissions()
                } catch (_: Exception) {
                    emptySet()
                }
            } else emptySet()
            _uiState.update {
                it.copy(
                    isAvailable = available,
                    grantedPermissions = granted,
                    isLoading = false
                )
            }
        }
    }

    fun onPermissionsResult(granted: Set<String>) {
        _uiState.update { it.copy(grantedPermissions = granted) }
        // Clear cached health data so the next refresh fetches with new permissions
        healthConnectService.invalidateCache()
    }

    fun toggleSync(enabled: Boolean) {
        _uiState.update { it.copy(syncEnabled = enabled) }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }
}

// ── Permission groups ─────────────────────────────────────────────────────────

private val permissionGroups = listOf(
    PermissionGroup(
        label = "Steps & Distance",
        description = "Daily step count and distance walked",
        icon = Icons.Default.DirectionsWalk,
        permissions = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(DistanceRecord::class)
        )
    ),
    PermissionGroup(
        label = "Heart Rate",
        description = "Heart rate measurements",
        icon = Icons.Default.Favorite,
        permissions = setOf(
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getWritePermission(HeartRateRecord::class)
        )
    ),
    PermissionGroup(
        label = "Calories",
        description = "Active and total calories burned",
        icon = Icons.Default.LocalFireDepartment,
        permissions = setOf(
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)
        )
    ),
    PermissionGroup(
        label = "Sleep",
        description = "Sleep sessions and duration",
        icon = Icons.Default.Bedtime,
        permissions = setOf(
            HealthPermission.getReadPermission(SleepSessionRecord::class)
        )
    ),
    PermissionGroup(
        label = "Exercise",
        description = "Workout sessions and activities",
        icon = Icons.Default.FitnessCenter,
        permissions = setOf(
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getWritePermission(ExerciseSessionRecord::class)
        )
    ),
    PermissionGroup(
        label = "Body Measurements",
        description = "Weight and height data",
        icon = Icons.Default.MonitorWeight,
        permissions = setOf(
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getReadPermission(HeightRecord::class)
        )
    ),
    PermissionGroup(
        label = "Blood Pressure",
        description = "Systolic and diastolic readings",
        icon = Icons.Default.Bloodtype,
        permissions = setOf(
            HealthPermission.getReadPermission(BloodPressureRecord::class)
        )
    ),
    PermissionGroup(
        label = "Hydration",
        description = "Water intake logging",
        icon = Icons.Default.WaterDrop,
        permissions = setOf(
            HealthPermission.getWritePermission(HydrationRecord::class)
        )
    ),
    PermissionGroup(
        label = "Cardio Fitness",
        description = "VO2 max measurements",
        icon = Icons.Default.FavoriteBorder,
        permissions = setOf(
            HealthPermission.getReadPermission(Vo2MaxRecord::class)
        )
    )
)

// ── Screen ────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthConnectSettingsScreen(
    onNavigateBack: () -> Unit,
    viewModel: HealthConnectSettingsViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        viewModel.onPermissionsResult(granted)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        "Health Connect",
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
                // Header card
                item {
                    HealthConnectHeaderCard(
                        isAvailable = uiState.isAvailable,
                        isLoading = uiState.isLoading,
                        syncEnabled = uiState.syncEnabled,
                        onSyncToggle = viewModel::toggleSync
                    )
                }

                // Permissions section
                if (!uiState.isLoading) {
                    item {
                        HealthConnectPermissionsSection(
                            uiState = uiState,
                            onRequestAll = {
                                permissionLauncher.launch(HealthConnectService.ALL_PERMISSIONS)
                            },
                            onRefresh = viewModel::loadStatus
                        )
                    }

                    // Permission groups
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                                .glass()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(0.dp)
                        ) {
                            Text(
                                "Data Permissions",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = AppColors.onSurface.copy(alpha = 0.7f),
                                modifier = Modifier.padding(bottom = 12.dp)
                            )

                            permissionGroups.forEachIndexed { index, group ->
                                PermissionGroupRow(
                                    group = group,
                                    granted = uiState.isGroupGranted(group),
                                    onRequest = {
                                        permissionLauncher.launch(group.permissions)
                                    }
                                )
                                if (index < permissionGroups.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(vertical = 8.dp),
                                        color = AppColors.onSurface.copy(alpha = 0.08f)
                                    )
                                }
                            }
                        }
                    }

                    // Info card
                    item {
                        HealthConnectInfoCard()
                    }
                }
            }
        }
    }
}

// ── Header Card ───────────────────────────────────────────────────────────────

@Composable
private fun HealthConnectHeaderCard(
    isAvailable: Boolean,
    isLoading: Boolean,
    syncEnabled: Boolean,
    onSyncToggle: (Boolean) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
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
                            colors = listOf(Color(0xFF4285F4), Color(0xFF34A853))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Favorite,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Health Connect",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )
                Text(
                    "Android health data platform",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onBackground.copy(alpha = 0.6f)
                )
            }

            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = PrimaryColor
                )
            } else {
                StatusBadge(isAvailable = isAvailable)
            }
        }

        HorizontalDivider(color = AppColors.onSurface.copy(alpha = 0.1f))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Sync,
                contentDescription = null,
                tint = PrimaryColor,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                "Sync with SwastriCare",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurface,
                modifier = Modifier.weight(1f)
            )
            Switch(
                checked = syncEnabled,
                onCheckedChange = onSyncToggle,
                enabled = isAvailable,
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Color.White,
                    checkedTrackColor = PrimaryColor,
                    uncheckedThumbColor = AppColors.outline,
                    uncheckedTrackColor = AppColors.surfaceVariant,
                    uncheckedBorderColor = Color.Transparent
                )
            )
        }
    }
}

// ── Permissions Section ───────────────────────────────────────────────────────

@Composable
private fun HealthConnectPermissionsSection(
    uiState: HealthConnectSettingsUiState,
    onRequestAll: () -> Unit,
    onRefresh: () -> Unit
) {
    val allGranted = permissionGroups.all { uiState.isGroupGranted(it) }
    val grantedCount = permissionGroups.count { uiState.isGroupGranted(it) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                "Permissions",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface.copy(alpha = 0.7f)
            )
            IconButton(onClick = onRefresh, modifier = Modifier.size(28.dp)) {
                Icon(
                    Icons.Default.Refresh,
                    contentDescription = "Refresh",
                    tint = PrimaryColor,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        if (!uiState.isAvailable) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color(0xFFFF3B30).copy(alpha = 0.1f))
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color(0xFFFF3B30),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    "Health Connect is not available on this device. Update Google Play Services or install Health Connect from the Play Store.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFFF3B30)
                )
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(
                        if (allGranted) Color(0xFF34C759).copy(alpha = 0.1f)
                        else Color(0xFFFF9F0A).copy(alpha = 0.1f)
                    )
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    if (allGranted) Icons.Default.CheckCircle else Icons.Default.Info,
                    contentDescription = null,
                    tint = if (allGranted) Color(0xFF34C759) else Color(0xFFFF9F0A),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    if (allGranted) "All permissions granted"
                    else "$grantedCount of ${permissionGroups.size} permission groups granted",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (allGranted) Color(0xFF34C759) else Color(0xFFFF9F0A)
                )
            }

            if (!allGranted) {
                Button(
                    onClick = onRequestAll,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(
                        Icons.Default.Lock,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Grant All Permissions", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

// ── Permission Group Row ──────────────────────────────────────────────────────

@Composable
private fun PermissionGroupRow(
    group: PermissionGroup,
    granted: Boolean,
    onRequest: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            group.icon,
            contentDescription = null,
            tint = if (granted) Color(0xFF34C759) else AppColors.onSurfaceVariant,
            modifier = Modifier.size(20.dp)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                group.label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
            Text(
                group.description,
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant
            )
        }
        if (granted) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = "Granted",
                tint = Color(0xFF34C759),
                modifier = Modifier.size(20.dp)
            )
        } else {
            TextButton(
                onClick = onRequest,
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    "Allow",
                    style = MaterialTheme.typography.labelSmall,
                    color = PrimaryColor,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

@Composable
private fun StatusBadge(isAvailable: Boolean) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(
                if (isAvailable) Color(0xFF34C759).copy(alpha = 0.15f)
                else Color(0xFFFF3B30).copy(alpha = 0.15f)
            )
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(
                    if (isAvailable) Color(0xFF34C759) else Color(0xFFFF3B30)
                )
        )
        Text(
            if (isAvailable) "Available" else "Unavailable",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = if (isAvailable) Color(0xFF34C759) else Color(0xFFFF3B30)
        )
    }
}

// ── Info Card ─────────────────────────────────────────────────────────────────

@Composable
private fun HealthConnectInfoCard() {
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
            Icon(
                Icons.Default.Info,
                contentDescription = null,
                tint = PrimaryColor,
                modifier = Modifier.size(18.dp)
            )
            Text(
                "About Health Connect",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }
        Text(
            "Health Connect is Android's secure health data platform. SwastriCare uses it to read your fitness and health data from other apps and to write hydration, heart rate, and workout data back.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant,
            lineHeight = MaterialTheme.typography.bodySmall.lineHeight
        )
    }
}
