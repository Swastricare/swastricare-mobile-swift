package com.swastricare.health.ui.screens.runactivity

import android.Manifest
import android.os.Build
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
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
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.*
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val ScreenBackground = Color.White
private val CardSurface = Color.White
private val SoftBorder = Color(0xFFE5EAF0)
private val MintTint = Color(0xFFE6F7F2)
private val MintTintDeep = Color(0xFFD3F0E6)
private val TextPrimary = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val DividerSoft = Color(0xFFE5EAF0)

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

    // Gated workout launch — checks permissions + GPS before navigating.
    val launchWorkout: (WorkoutType?) -> Unit = { type ->
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
            else -> onNavigateToLiveWorkout(type)
        }
    }

    val today = LocalDate.now()
    val todayActivities = remember(uiState.activities, today) {
        uiState.activities.filter { it.startTime?.toLocalDate() == today }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ScreenBackground)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            ActivityHeader(
                onBack = onNavigateBack,
                onCalendar = onNavigateToCalendar
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = 4.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                item { DateSelectorPill(today = today, onClick = onNavigateToCalendar) }

                if (todayActivities.isEmpty()) {
                    item { EmptyTodayHero(onStartWorkout = { launchWorkout(null) }) }
                } else {
                    items(todayActivities, key = { it.id }) { activity ->
                        TodayActivityCard(
                            activity = activity,
                            onClick = { onNavigateToActivityDetail(activity.id) }
                        )
                    }
                    item { StartAnotherButton(onClick = { launchWorkout(null) }) }
                }

                item { IdeasSectionHeader() }
                item { IdeaCardsRow(onIdeaClick = launchWorkout) }
                item { TipCard() }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
        )
    }
}

// ─── Header ──────────────────────────────────────────────────────────────────

@Composable
private fun ActivityHeader(
    onBack: (() -> Unit)?,
    onCalendar: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 12.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack, modifier = Modifier.size(44.dp)) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = TextPrimary
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Activity",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary,
                lineHeight = 22.sp
            )
            Text(
                text = "Track your daily movement and progress",
                fontSize = 12.sp,
                color = TextSecondary,
                lineHeight = 14.sp
            )
        }
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(CardSurface)
                .border(1.dp, SoftBorder, CircleShape)
                .clickable { onCalendar() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.CalendarMonth,
                contentDescription = "Calendar",
                tint = AITeal,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

// ─── Date Selector ───────────────────────────────────────────────────────────

@Composable
private fun DateSelectorPill(today: LocalDate, onClick: () -> Unit) {
    val label = remember(today) {
        "Today, " + today.format(DateTimeFormatter.ofPattern("d MMM"))
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier
                .clip(CircleShape)
                .background(CardSurface)
                .border(1.dp, SoftBorder, CircleShape)
                .clickable { onClick() }
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Icon(
                imageVector = Icons.Default.ChevronLeft,
                contentDescription = null,
                tint = TextSecondary,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = label,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = TextSecondary,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

// ─── Empty State Hero ────────────────────────────────────────────────────────

@Composable
private fun EmptyTodayHero(onStartWorkout: () -> Unit) {
    val context = LocalContext.current
    val bitmap = remember {
        runCatching {
            context.assets.open("icons/no activity illustration 1.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .width(220.dp)
                    .height(170.dp)
            )
        }

        Text(
            text = "No activity yet today",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )

        Text(
            text = "You haven't logged any workout or movement.\nLet's get moving!",
            fontSize = 13.sp,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            lineHeight = 18.sp
        )

        Button(
            onClick = onStartWorkout,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp)
                .height(54.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Start a Workout",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

@Composable
private fun StartAnotherButton(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
    ) {
        Button(
            onClick = onClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Start another workout",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

// ─── Today Activity Card (compact) ───────────────────────────────────────────

@Composable
private fun TodayActivityCard(activity: RunActivity, onClick: () -> Unit) {
    val typeIcon: ImageVector = when (activity.activityType) {
        ActivityType.RUNNING -> Icons.Default.DirectionsRun
        ActivityType.WALKING -> Icons.Default.DirectionsWalk
        ActivityType.CYCLING -> Icons.Default.DirectionsRun
        ActivityType.HIKING -> Icons.Default.Terrain
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(MintTint),
            contentAlignment = Alignment.Center
        ) {
            Icon(typeIcon, null, tint = AITeal, modifier = Modifier.size(22.dp))
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = activity.activityType.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "${activity.formattedDistance} km · ${activity.caloriesBurned} kcal",
                fontSize = 12.sp,
                color = TextSecondary
            )
        }
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ─── Ideas Section ───────────────────────────────────────────────────────────

@Composable
private fun IdeasSectionHeader() {
    Column(modifier = Modifier.padding(horizontal = 20.dp)) {
        Text(
            text = "Ideas to get moving",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )
    }
}

private data class WorkoutIdea(
    val title: String,
    val subtitle: String,
    val durationLabel: String,
    val icon: ImageVector,
    val type: WorkoutType
)

private val Ideas = listOf(
    WorkoutIdea(
        title = "Go for a Walk",
        subtitle = "Fresh air and steps",
        durationLabel = "20 min",
        icon = Icons.Default.DirectionsWalk,
        type = WorkoutType.WALK
    ),
    WorkoutIdea(
        title = "Quick Run",
        subtitle = "Cardio boost",
        durationLabel = "15 min",
        icon = Icons.Default.DirectionsRun,
        type = WorkoutType.RUN
    ),
    WorkoutIdea(
        title = "Outdoor Hike",
        subtitle = "Explore the trail",
        durationLabel = "30 min",
        icon = Icons.Default.Terrain,
        type = WorkoutType.HIKE
    )
)

@Composable
private fun IdeaCardsRow(onIdeaClick: (WorkoutType) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Ideas.forEach { idea ->
            IdeaCard(
                idea = idea,
                modifier = Modifier.weight(1f),
                onClick = { onIdeaClick(idea.type) }
            )
        }
    }
}

@Composable
private fun IdeaCard(
    idea: WorkoutIdea,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(horizontal = 10.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(MintTint),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = idea.icon,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = idea.title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary,
            textAlign = TextAlign.Center,
            minLines = 2,
            maxLines = 2,
            lineHeight = 16.sp
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = idea.subtitle,
            fontSize = 11.sp,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            minLines = 1,
            maxLines = 2,
            lineHeight = 14.sp
        )
        Spacer(Modifier.height(10.dp))
        Box(
            modifier = Modifier
                .clip(CircleShape)
                .background(MintTintDeep)
                .padding(horizontal = 12.dp, vertical = 5.dp)
        ) {
            Text(
                text = idea.durationLabel,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = AITealDark,
                lineHeight = 13.sp
            )
        }
    }
}

// ─── Tip Card ────────────────────────────────────────────────────────────────

@Composable
private fun TipCard() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(MintTint)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(Color.White),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.FavoriteBorder,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Stay active, stay healthy",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "Just 30 minutes of activity can boost your mood and energy.",
                fontSize = 11.sp,
                color = TextSecondary,
                lineHeight = 14.sp
            )
        }
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
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
                    Button(
                        onClick = onAllow,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AITeal),
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
