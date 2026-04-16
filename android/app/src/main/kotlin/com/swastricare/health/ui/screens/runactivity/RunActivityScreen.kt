package com.swastricare.health.ui.screens.runactivity

import android.Manifest
import android.os.Build
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import android.location.LocationManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.accompanist.permissions.*
import com.swastricare.health.data.models.ActivityType
import com.swastricare.health.data.models.RouteCoordinate
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.data.models.TimeRangeFilter
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.*

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun RunActivityScreen(
    onNavigateToLiveWorkout: (WorkoutType?) -> Unit = {},
    onNavigateToActivityDetail: (String) -> Unit = {},
    onNavigateToCalendar: () -> Unit = {},
    onNavigateBack: (() -> Unit)? = null
) {
    TrackScreen("RunActivity")
    val viewModel: RunActivityViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val lifecycleOwner = LocalLifecycleOwner.current
    val haptic = LocalHapticFeedback.current
    val context = LocalContext.current

    // ── Required permissions ──────────────────────────────────────────────────
    val permissionsToRequest = remember {
        buildList {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(Manifest.permission.ACTIVITY_RECOGNITION)
            }
        }
    }
    val permissionsState = rememberMultiplePermissionsState(permissionsToRequest)
    var showPermissionDialog by remember { mutableStateOf(false) }
    var showSettingsDialog by remember { mutableStateOf(false) }
    var showLocationServicesDialog by remember { mutableStateOf(false) }

    // ── Permission dialog ─────────────────────────────────────────────────────
    if (showPermissionDialog) {
        WorkoutPermissionDialog(
            onAllow = {
                showPermissionDialog = false
                if (permissionsState.shouldShowRationale) {
                    permissionsState.launchMultiplePermissionRequest()
                } else {
                    showSettingsDialog = true
                }
            },
            onDismiss = { showPermissionDialog = false }
        )
    }
    if (showSettingsDialog) {
        WorkoutPermissionSettingsDialog(onDismiss = { showSettingsDialog = false })
    }
    if (showLocationServicesDialog) {
        LocationServicesDialog(onDismiss = { showLocationServicesDialog = false })
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.loadData()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let { msg ->
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            viewModel.clearError()
        }
    }

    // Closure used by HeroSection — checks permissions AND location services before navigating
    val onStartWorkoutSafe: () -> Unit = {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        val locationManager = context.getSystemService(android.content.Context.LOCATION_SERVICE) as LocationManager
        val isGpsOn = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)

        when {
            !permissionsState.allPermissionsGranted -> {
                if (permissionsState.shouldShowRationale) {
                    showPermissionDialog = true
                } else {
                    permissionsState.launchMultiplePermissionRequest()
                }
            }
            !isGpsOn -> showLocationServicesDialog = true
            else -> onNavigateToLiveWorkout(null)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.background)
    ) {
        androidx.compose.foundation.layout.Column(modifier = Modifier.fillMaxSize()) {
            com.swastricare.health.ui.components.AppTopBar(title = "Activity")
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp)
            ) {
                // ── Hero ──────────────────────────────────────────────────────
                item {
                    HeroSection(
                        steps = uiState.todaySteps,
                        isLoading = uiState.isLoading,
                        onStartWorkout = onStartWorkoutSafe,
                        onNavigateToCalendar = onNavigateToCalendar
                    )
                }

            // ── Time Range Selector ───────────────────────────────────────
            item {
                TimeRangeSelector(
                    selected = uiState.timeRangeFilter,
                    onSelect = { viewModel.setTimeRange(it) }
                )
            }

            // ── Metrics Row ───────────────────────────────────────────────
            item {
                MetricsRow(
                    distanceKm = uiState.statistics.totalDistanceKm,
                    calories = uiState.statistics.totalCalories,
                    workouts = uiState.statistics.totalActivities
                )
            }

            // ── Fitness Insights (compact chips) ─────────────────────────
            if (uiState.vo2Max != null) {
                item { FitnessChips(vo2Max = uiState.vo2Max) }
            }

            // ── Recent Activities ────────────────────────────────────────
            item {
                RecentActivitiesHeader(
                    count = uiState.activities.size,
                    onSeeAll = onNavigateToCalendar
                )
            }

                if (uiState.activities.isEmpty()) {
                    item { EmptyActivitiesState() }
                } else {
                    items(uiState.activities, key = { it.id }) { activity ->
                        ActivityCard(
                            activity = activity,
                            onClick = { onNavigateToActivityDetail(activity.id) }
                        )
                    }
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
        )
    }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

@Composable
private fun HeroSection(
    steps: Int,
    isLoading: Boolean,
    onStartWorkout: () -> Unit,
    onNavigateToCalendar: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp)
            .shadow(16.dp, RoundedCornerShape(24.dp), clip = false)
            .clip(RoundedCornerShape(24.dp))
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(Color(0xFF0F172A), Color(0xFF134E2E)),
                    start = Offset(0f, 0f),
                    end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY)
                )
            )
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header row: title + calendar icon
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Activity",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White
                )
                IconButton(
                    onClick = onNavigateToCalendar,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.DateRange,
                        contentDescription = "Calendar",
                        tint = Color.White.copy(alpha = 0.75f),
                        modifier = Modifier.size(22.dp)
                    )
                }
            }

            // Step count
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Today",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.55f),
                    fontWeight = FontWeight.Medium
                )
                if (isLoading) {
                    Box(
                        modifier = Modifier
                            .width(160.dp)
                            .height(56.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color.White.copy(alpha = 0.12f))
                    )
                } else {
                    Row(
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = if (steps > 0) "%,d".format(steps) else "0",
                            style = MaterialTheme.typography.displayLarge,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            fontSize = 52.sp
                        )
                        Text(
                            text = "steps",
                            style = MaterialTheme.typography.titleMedium,
                            color = Color.White.copy(alpha = 0.60f),
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.padding(bottom = 10.dp)
                        )
                    }
                }
            }

            // Start Workout button — green circle play + text + chevron
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.10f))
                    .clickable { onStartWorkout() }
                    .padding(14.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(SecondaryColor),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.PlayArrow,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(
                            text = "Start Workout",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        )
                        Text(
                            text = "Track GPS, distance, and route",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.60f)
                        )
                    }
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = SecondaryColor,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}

// ─── Time Range Selector ──────────────────────────────────────────────────────

private fun TimeRangeFilter.shortLabel(): String = when (this) {
    TimeRangeFilter.TWO_WEEKS -> "2W"
    TimeRangeFilter.ONE_MONTH -> "1M"
    TimeRangeFilter.THREE_MONTHS -> "3M"
}

@Composable
private fun TimeRangeSelector(
    selected: TimeRangeFilter,
    onSelect: (TimeRangeFilter) -> Unit
) {
    val haptic = LocalHapticFeedback.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp)
            .clip(CircleShape)
            .background(AppColors.surfaceVariant)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        TimeRangeFilter.values().forEach { filter ->
            val isSelected = filter == selected
            val bgColor by animateColorAsState(
                targetValue = if (isSelected) AppColors.onBackground else Color.Transparent,
                animationSpec = tween(200),
                label = "tabBg"
            )
            val textColor by animateColorAsState(
                targetValue = if (isSelected) AppColors.background else AppColors.onSurfaceVariant,
                animationSpec = tween(200),
                label = "tabText"
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(CircleShape)
                    .background(bgColor)
                    .clickable {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onSelect(filter)
                    }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = filter.shortLabel(),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    color = textColor
                )
            }
        }
    }
}

// ─── Metrics Row ──────────────────────────────────────────────────────────────

@Composable
private fun MetricsRow(
    distanceKm: Double,
    calories: Int,
    workouts: Int
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .padding(vertical = 20.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        MetricItem(
            value = "%.2f".format(distanceKm),
            unit = "km",
            label = "Distance"
        )
        Box(
            modifier = Modifier
                .width(1.dp)
                .height(44.dp)
                .background(AppColors.outlineVariant)
        )
        MetricItem(
            value = "$calories",
            unit = "kcal",
            label = "Calories"
        )
        Box(
            modifier = Modifier
                .width(1.dp)
                .height(44.dp)
                .background(AppColors.outlineVariant)
        )
        MetricItem(
            value = "$workouts",
            unit = "",
            label = "Workouts"
        )
    }
}

@Composable
private fun MetricItem(value: String, unit: String, label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant
        )
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                fontSize = 26.sp
            )
            if (unit.isNotEmpty()) {
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }
    }
}

// ─── Fitness Chips ────────────────────────────────────────────────────────────

@Composable
private fun FitnessChips(vo2Max: Double?) {
    if (vo2Max == null) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        FitnessChip(icon = Icons.Default.Favorite, value = "%.1f VO₂".format(vo2Max))
    }
}

@Composable
private fun FitnessChip(icon: ImageVector, value: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(AppColors.surfaceVariant)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurface
        )
    }
}

// ─── Recent Activities ────────────────────────────────────────────────────────

@Composable
private fun RecentActivitiesHeader(count: Int, onSeeAll: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 20.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = "Recent Activities",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = AppColors.onBackground
        )
        if (count > 5) {
            TextButton(onClick = onSeeAll, contentPadding = PaddingValues(0.dp)) {
                Text("See All", style = MaterialTheme.typography.labelMedium, color = PrimaryColor)
                Icon(
                    Icons.Default.ArrowForward,
                    contentDescription = null,
                    tint = PrimaryColor,
                    modifier = Modifier.size(14.dp)
                )
            }
        } else if (count > 0) {
            Text(
                "$count activities",
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ActivityCard(activity: RunActivity, onClick: () -> Unit) {
    val typeIcon: ImageVector = when (activity.activityType) {
        ActivityType.RUNNING -> Icons.Default.DirectionsRun
        ActivityType.WALKING -> Icons.Default.DirectionsWalk
        ActivityType.CYCLING -> Icons.Default.DirectionsBike
        ActivityType.HIKING -> Icons.Default.Terrain
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 5.dp)
            .shadow(3.dp, RoundedCornerShape(16.dp), clip = false)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Map thumbnail (or icon fallback when no GPS route recorded)
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFF1A1A2E)),
            contentAlignment = Alignment.Center
        ) {
            if (activity.routeCoordinates.size >= 2) {
                ActivityRouteThumbnail(coordinates = activity.routeCoordinates)
            } else {
                Icon(
                    imageVector = typeIcon,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.size(28.dp)
                )
            }
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(typeIcon, null, tint = AppColors.onSurfaceVariant, modifier = Modifier.size(11.dp))
                Text(
                    text = activity.formattedDate,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
            Text(
                text = activity.activityType.displayName,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (activity.caloriesBurned > 0) {
                    Text(
                        text = "${activity.caloriesBurned} kcal",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                    Text(
                        "·",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
                Text(
                    text = activity.formattedDistance + " km",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun EmptyActivitiesState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = Icons.Default.DirectionsWalk,
            contentDescription = null,
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.3f),
            modifier = Modifier.size(48.dp)
        )
        Text(
            text = "No activities yet",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurfaceVariant
        )
        Text(
            text = "Start a workout to track your activities",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant.copy(alpha = 0.6f),
            textAlign = TextAlign.Center
        )
    }
}

// ─── Activity Route Canvas Thumbnail ─────────────────────────────────────────
// Lightweight, non-interactive canvas — safe to use inside LazyColumn items.

@Composable
private fun ActivityRouteThumbnail(coordinates: List<RouteCoordinate>) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val padding = 8f
        val drawW = size.width - padding * 2
        val drawH = size.height - padding * 2

        val minLat = coordinates.minOf { it.latitude }
        val maxLat = coordinates.maxOf { it.latitude }
        val minLng = coordinates.minOf { it.longitude }
        val maxLng = coordinates.maxOf { it.longitude }

        val latRange = (maxLat - minLat).coerceAtLeast(0.0001)
        val lngRange = (maxLng - minLng).coerceAtLeast(0.0001)
        val scale = minOf(drawW / lngRange, drawH / latRange)

        val offX = padding + (drawW - lngRange * scale).toFloat() / 2f
        val offY = padding + (drawH - latRange * scale).toFloat() / 2f

        fun project(c: RouteCoordinate) = Offset(
            x = ((c.longitude - minLng) * scale).toFloat() + offX,
            y = ((maxLat - c.latitude) * scale).toFloat() + offY
        )

        val pts = coordinates.map { project(it) }
        val startColor = Color(0xFF00E5FF)
        val endColor = Color(0xFF38EF7D)
        val n = (pts.size - 1).coerceAtLeast(1)

        // Glow pass
        for (i in 0 until pts.size - 1) {
            val f = i.toFloat() / n
            val c = lerpColor(startColor, endColor, f)
            drawLine(c.copy(alpha = 0.25f), pts[i], pts[i + 1], 6.dp.toPx(), StrokeCap.Round)
        }
        // Route pass
        for (i in 0 until pts.size - 1) {
            val f = i.toFloat() / n
            drawLine(lerpColor(startColor, endColor, f), pts[i], pts[i + 1], 2.5.dp.toPx(), StrokeCap.Round)
        }

        drawCircle(endColor, 4f, pts.first())
        drawCircle(Color(0xFFFF4757), 4f, pts.last())
    }
}

private fun lerpColor(a: Color, b: Color, f: Float): Color {
    val t = f.coerceIn(0f, 1f)
    return Color(a.red + (b.red - a.red) * t, a.green + (b.green - a.green) * t,
        a.blue + (b.blue - a.blue) * t, 1f)
}

// ─── Permission Dialogs (Samsung-style bottom sheet) ─────────────────────────

@Composable
private fun WorkoutPermissionDialog(onAllow: () -> Unit, onDismiss: () -> Unit) {
    PermissionBottomSheet(
        title = "Permissions required",
        reason = "Allow the app to access Location and Physical Activity to track your workout.",
        body = "You won't be able to start a workout unless you grant the required permissions, " +
               "but it won't affect your use of other features. " +
               "You can always change permissions in Settings.",
        denyLabel = "Deny",
        allowLabel = "Allow",
        onDeny = onDismiss,
        onAllow = onAllow
    )
}

@Composable
private fun LocationServicesDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    PermissionBottomSheet(
        title = "Permissions required",
        reason = "Allow the app to access Location Services (GPS) to record your route and distance.",
        body = "Your GPS is currently turned off. You won't be able to start a workout until Location " +
               "Services is enabled. You can turn it on in Settings at any time.",
        denyLabel = "Deny",
        allowLabel = "Allow",
        onDeny = onDismiss,
        onAllow = {
            context.startActivity(android.content.Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS))
            onDismiss()
        }
    )
}

@Composable
private fun WorkoutPermissionSettingsDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    PermissionBottomSheet(
        title = "Permissions required",
        reason = "Allow the app to access Location and Physical Activity.",
        body = "You won't be able to use this feature unless you grant the required permissions, " +
               "but it won't affect your use of other services. " +
               "You can always restrict permissions in Settings.",
        denyLabel = "Deny",
        allowLabel = "Allow",
        onDeny = onDismiss,
        onAllow = {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                android.net.Uri.fromParts("package", context.packageName, null)
            )
            context.startActivity(intent)
            onDismiss()
        }
    )
}

@Composable
private fun PermissionBottomSheet(
    title: String,
    reason: String,
    body: String,
    denyLabel: String,
    allowLabel: String,
    onDeny: () -> Unit,
    onAllow: () -> Unit
) {
    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDeny,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(28.dp))
                    .background(AppColors.surface)
                    .padding(horizontal = 24.dp, vertical = 28.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )

                Text(
                    text = reason,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )

                Text(
                    text = body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant,
                    lineHeight = 22.sp
                )

                Spacer(Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Deny
                    Button(
                        onClick = onDeny,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AppColors.surfaceVariant,
                            contentColor = AppColors.onSurface
                        ),
                        elevation = ButtonDefaults.buttonElevation(0.dp)
                    ) {
                        Text(denyLabel, fontWeight = FontWeight.SemiBold)
                    }
                    // Allow
                    Button(
                        onClick = onAllow,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = SecondaryColor),
                        elevation = ButtonDefaults.buttonElevation(0.dp)
                    ) {
                        Text(allowLabel, fontWeight = FontWeight.SemiBold, color = Color.White)
                    }
                }

                Spacer(Modifier.navigationBarsPadding())
            }
        }
    }
}
