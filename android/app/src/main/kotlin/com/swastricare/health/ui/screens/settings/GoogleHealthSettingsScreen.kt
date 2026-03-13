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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.hilt.navigation.compose.hiltViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ── Data ──────────────────────────────────────────────────────────────────────

private data class GoogleDataType(
    val label: String,
    val description: String,
    val icon: ImageVector,
    val iconTint: Color,
    val permissions: Set<String>
)

private val googleDataTypes = listOf(
    GoogleDataType(
        label = "Steps & Activity",
        description = "Step count and activity minutes from your Android device",
        icon = Icons.Default.DirectionsWalk,
        iconTint = Color(0xFF34A853),
        permissions = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        )
    ),
    GoogleDataType(
        label = "Heart Rate",
        description = "Heart rate data from Pixel Watch or Wear OS devices",
        icon = Icons.Default.Favorite,
        iconTint = Color(0xFFEA4335),
        permissions = setOf(
            HealthPermission.getReadPermission(HeartRateRecord::class)
        )
    ),
    GoogleDataType(
        label = "Calories",
        description = "Calories burned estimated by Android",
        icon = Icons.Default.LocalFireDepartment,
        iconTint = Color(0xFFFF9F0A),
        permissions = setOf(
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)
        )
    ),
    GoogleDataType(
        label = "Sleep",
        description = "Sleep data tracked by Pixel or Wear OS devices",
        icon = Icons.Default.Bedtime,
        iconTint = Color(0xFF4285F4),
        permissions = setOf(
            HealthPermission.getReadPermission(SleepSessionRecord::class)
        )
    ),
    GoogleDataType(
        label = "Distance",
        description = "Distance tracked from walks and runs",
        icon = Icons.Default.Map,
        iconTint = Color(0xFF34A853),
        permissions = setOf(
            HealthPermission.getReadPermission(DistanceRecord::class)
        )
    )
)

data class GoogleHealthUiState(
    val isAvailable: Boolean = false,
    val isLoading: Boolean = true,
    val grantedPermissions: Set<String> = emptySet(),
    val syncEnabled: Boolean = true
)

// ── ViewModel ─────────────────────────────────────────────────────────────────

@HiltViewModel
class GoogleHealthSettingsViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService
) : ViewModel() {

    private val _uiState = MutableStateFlow(GoogleHealthUiState())
    val uiState: StateFlow<GoogleHealthUiState> = _uiState.asStateFlow()

    init {
        loadStatus()
    }

    fun loadStatus() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val available = healthConnectService.checkAvailability()
            val granted = if (available) {
                try { healthConnectService.getGrantedPermissions() } catch (_: Exception) { emptySet() }
            } else emptySet()
            _uiState.update {
                it.copy(isAvailable = available, grantedPermissions = granted, isLoading = false)
            }
        }
    }

    fun onPermissionsResult(granted: Set<String>) {
        _uiState.update { it.copy(grantedPermissions = granted) }
    }

    fun toggleSync(enabled: Boolean) {
        _uiState.update { it.copy(syncEnabled = enabled) }
    }
}

// ── Screen ────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoogleHealthSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToHealthConnect: () -> Unit,
    viewModel: GoogleHealthSettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        viewModel.onPermissionsResult(granted)
    }

    val googlePermissions = googleDataTypes.flatMap { it.permissions }.toSet()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        "Google Health Data",
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
                    GoogleHealthHeaderCard(
                        isAvailable = uiState.isAvailable,
                        isLoading = uiState.isLoading,
                        syncEnabled = uiState.syncEnabled,
                        onSyncToggle = viewModel::toggleSync
                    )
                }

                // How it works
                item {
                    GoogleHealthFlowCard(onNavigateToHealthConnect = onNavigateToHealthConnect)
                }

                if (!uiState.isLoading) {
                    // Data types
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                                .glass()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(0.dp)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    "Google Data Types",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AppColors.onSurface.copy(alpha = 0.7f)
                                )
                                IconButton(onClick = viewModel::loadStatus, modifier = Modifier.size(28.dp)) {
                                    Icon(
                                        Icons.Default.Refresh,
                                        contentDescription = "Refresh",
                                        tint = PrimaryColor,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }

                            googleDataTypes.forEachIndexed { index, dataType ->
                                val isGranted = dataType.permissions.all { it in uiState.grantedPermissions }
                                GoogleDataTypeRow(
                                    dataType = dataType,
                                    granted = isGranted,
                                    onRequest = { permissionLauncher.launch(dataType.permissions) }
                                )
                                if (index < googleDataTypes.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(vertical = 8.dp),
                                        color = AppColors.onSurface.copy(alpha = 0.08f)
                                    )
                                }
                            }

                            if (!uiState.isAvailable) {
                                Spacer(modifier = Modifier.height(12.dp))
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
                                        modifier = Modifier.size(18.dp)
                                    )
                                    Text(
                                        "Health Connect is required to sync Google Health data.",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color(0xFFFF3B30)
                                    )
                                }
                            } else {
                                val grantedCount = googleDataTypes.count { dt ->
                                    dt.permissions.all { it in uiState.grantedPermissions }
                                }
                                val allGranted = grantedCount == googleDataTypes.size
                                if (!allGranted) {
                                    Spacer(modifier = Modifier.height(12.dp))
                                    Button(
                                        onClick = { permissionLauncher.launch(googlePermissions) },
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = Color(0xFF4285F4)
                                        ),
                                        shape = RoundedCornerShape(10.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.Lock,
                                            contentDescription = null,
                                            modifier = Modifier.size(18.dp)
                                        )
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            "Grant Google Health Permissions",
                                            fontWeight = FontWeight.SemiBold
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ── Header Card ───────────────────────────────────────────────────────────────

@Composable
private fun GoogleHealthHeaderCard(
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
                            colors = listOf(
                                Color(0xFF4285F4),
                                Color(0xFF34A853),
                                Color(0xFFEA4335),
                                Color(0xFFFBBC04)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.MonitorHeart,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Google Health Data",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )
                Text(
                    "Google Fit & Pixel health data",
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onBackground.copy(alpha = 0.6f)
                )
            }

            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Color(0xFF4285F4)
                )
            } else {
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
                            .background(if (isAvailable) Color(0xFF34C759) else Color(0xFFFF3B30))
                    )
                    Text(
                        if (isAvailable) "Ready" else "Unavailable",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = if (isAvailable) Color(0xFF34C759) else Color(0xFFFF3B30)
                    )
                }
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
                tint = Color(0xFF4285F4),
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                "Sync Google Health Data",
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
                    checkedTrackColor = Color(0xFF4285F4),
                    uncheckedThumbColor = AppColors.outline,
                    uncheckedTrackColor = AppColors.surfaceVariant,
                    uncheckedBorderColor = Color.Transparent
                )
            )
        }
    }
}

// ── Flow Card ─────────────────────────────────────────────────────────────────

@Composable
private fun GoogleHealthFlowCard(onNavigateToHealthConnect: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "How it works",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        // Flow: Google apps → Health Connect → SwastriCare
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FlowStep(
                icon = Icons.Default.PhoneAndroid,
                label = "Google apps\n& Pixel",
                color = Color(0xFF4285F4),
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Default.ArrowForward,
                contentDescription = null,
                tint = AppColors.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
            FlowStep(
                icon = Icons.Default.Favorite,
                label = "Health\nConnect",
                color = Color(0xFF34A853),
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Default.ArrowForward,
                contentDescription = null,
                tint = AppColors.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
            FlowStep(
                icon = Icons.Default.HealthAndSafety,
                label = "SwastriCare",
                color = PrimaryColor,
                modifier = Modifier.weight(1f)
            )
        }

        Text(
            "Google Health data is routed through Health Connect. Make sure Health Connect permissions are granted.",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant
        )

        TextButton(
            onClick = onNavigateToHealthConnect,
            contentPadding = PaddingValues(0.dp)
        ) {
            Text(
                "Manage Health Connect permissions →",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF4285F4),
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun FlowStep(
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
                .size(36.dp)
                .clip(CircleShape)
                .background(color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        }
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

// ── Data Type Row ─────────────────────────────────────────────────────────────

@Composable
private fun GoogleDataTypeRow(
    dataType: GoogleDataType,
    granted: Boolean,
    onRequest: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(dataType.iconTint.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                dataType.icon,
                contentDescription = null,
                tint = dataType.iconTint,
                modifier = Modifier.size(16.dp)
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                dataType.label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
            Text(
                dataType.description,
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
                    color = Color(0xFF4285F4),
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}
