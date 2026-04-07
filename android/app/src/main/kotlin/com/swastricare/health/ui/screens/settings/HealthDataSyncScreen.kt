package com.swastricare.health.ui.screens.settings

import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import coil.request.ImageRequest
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

// ── Model ──

enum class HealthAppId { HEALTH_CONNECT, GOOGLE_HEALTH, SAMSUNG_HEALTH, GARMIN_CONNECT }

data class HealthAppEntry(
    val id: HealthAppId,
    val label: String,
    val subtitle: String,
    val icon: ImageVector,
    val iconGradient: List<Color>,
    val packageName: String? = null
)

private val healthApps = listOf(
    HealthAppEntry(HealthAppId.HEALTH_CONNECT, "Health Connect", "Android health data platform", Icons.Default.Favorite, listOf(Color(0xFF4285F4), Color(0xFF34A853)))
)

// ── UiState ──

data class HealthDataSyncUiState(
    val isHealthConnectAvailable: Boolean = false,
    val hasAllPermissions: Boolean = false,
    val installedPackages: Set<String> = emptySet(),
    val isLoading: Boolean = true
)

// ── ViewModel ──

@HiltViewModel
class HealthDataSyncViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService
) : ViewModel() {
    private val _uiState = MutableStateFlow(HealthDataSyncUiState())
    val uiState: StateFlow<HealthDataSyncUiState> = _uiState.asStateFlow()

    fun load(context: Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val hcAvailable = healthConnectService.checkAvailability()
            val allPerms = if (hcAvailable) { try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false } } else false
            val installed = healthApps.mapNotNull { it.packageName }.filter { pkg -> isInstalled(context, pkg) }.toSet()
            _uiState.update { it.copy(isHealthConnectAvailable = hcAvailable, hasAllPermissions = allPerms, installedPackages = installed, isLoading = false) }
        }
    }

    private fun isInstalled(context: Context, pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES); true
    } catch (_: PackageManager.NameNotFoundException) { false }
}

// ── Screen ──

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthDataSyncScreen(
    onNavigateBack: () -> Unit,
    onNavigateTo: (HealthAppId) -> Unit,
    viewModel: HealthDataSyncViewModel = hiltViewModel()
) {
    TrackScreen("HealthDataSync")
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    LaunchedEffect(Unit) { viewModel.load(context) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Health Data Sync", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = AppColors.onBackground,
                    navigationIconContentColor = AppColors.onBackground
                ),
                windowInsets = WindowInsets(0, 0, 0, 0)
            )
        },
        containerColor = Color.Transparent
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // Status banner
            item {
                val (bgColor, icon, message, textColor) = statusBannerInfo(uiState)
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
                        .clip(RoundedCornerShape(14.dp)).background(bgColor).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(icon, null, tint = textColor, modifier = Modifier.size(20.dp))
                    Text(message, fontSize = 13.sp, color = textColor)
                }
            }

            // Apps
            item { SettingsSectionHeader("Connected Apps") }
            item {
                SettingsSectionCard {
                    healthApps.forEachIndexed { index, app ->
                        if (index > 0) SettingsCleanDivider()
                        Row(
                            modifier = Modifier.fillMaxWidth().clickable { onNavigateTo(app.id) }.padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            // Icon
                            if (app.id == HealthAppId.HEALTH_CONNECT) {
                                AsyncImage(
                                    model = ImageRequest.Builder(LocalContext.current)
                                        .data("file:///android_asset/images/health connect.png")
                                        .crossfade(true).build(),
                                    contentDescription = null,
                                    modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp))
                                )
                            } else {
                                Box(
                                    modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp))
                                        .background(Brush.linearGradient(app.iconGradient)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(app.icon, null, tint = Color.White, modifier = Modifier.size(20.dp))
                                }
                            }
                            // Labels
                            Column(modifier = Modifier.weight(1f)) {
                                Text(app.label, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
                                Text(app.subtitle, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.4f))
                            }
                            Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = AppColors.onBackground.copy(alpha = 0.25f))
                        }
                    }
                }
            }

            item {
                Text(
                    "Tap any app to manage its connection and permissions.",
                    fontSize = 12.sp,
                    color = AppColors.onBackground.copy(alpha = 0.4f),
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)
                )
            }
        }
    }
}

// ── Helpers ──

private data class BannerInfo(val bg: Color, val icon: ImageVector, val message: String, val textColor: Color)

private fun statusBannerInfo(uiState: HealthDataSyncUiState): BannerInfo = when {
    uiState.isLoading -> BannerInfo(Color(0xFF8E8E93).copy(alpha = 0.1f), Icons.Default.HourglassEmpty, "Checking status...", Color(0xFF8E8E93))
    !uiState.isHealthConnectAvailable -> BannerInfo(Color(0xFFFF3B30).copy(alpha = 0.1f), Icons.Default.Warning, "Health Connect unavailable — install or update it to enable syncing", Color(0xFFFF3B30))
    !uiState.hasAllPermissions -> BannerInfo(Color(0xFFFF9F0A).copy(alpha = 0.1f), Icons.Default.Info, "Some permissions are missing — tap Health Connect to grant them", Color(0xFFFF9F0A))
    else -> BannerInfo(Color(0xFF34C759).copy(alpha = 0.1f), Icons.Default.CheckCircle, "Health Connect is set up and all permissions are granted", Color(0xFF34C759))
}

private fun appStatusInfo(app: HealthAppEntry, uiState: HealthDataSyncUiState): Pair<String, Color> {
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
        HealthAppId.SAMSUNG_HEALTH, HealthAppId.GARMIN_CONNECT -> "Removed" to Color(0xFF8E8E93)
    }
}
