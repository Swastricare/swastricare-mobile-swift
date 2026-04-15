# Sleep Manual Entry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a full-screen manual sleep logging UI with a circular arc duration slider, accessible from the SleepScreen empty state and a FAB, only when Health Connect has no data for that date.

**Architecture:** New `LogSleepScreen` + `LogSleepViewModel` (Hilt) that saves a `SleepSession` to Supabase via a new `SleepRepository.saveManualSession()`. The screen is reached via a new `sleep/log` nav route. The SleepScreen gains an `onNavigateToLog` parameter and a FAB.

**Tech Stack:** Kotlin, Jetpack Compose, Hilt, Supabase (postgrest upsert), existing `SleepRepository` / `SleepMapper` / `DailyMetricsSleepDto` patterns.

---

### Task 1: Add `saveManualSession` to SleepRepository

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/domain/repository/SleepRepository.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/repository/SleepRepositoryImpl.kt`

**Step 1: Add method to interface**

Open `SleepRepository.kt`. Add after `syncToCloud`:

```kotlin
/**
 * Save a manually entered sleep session to Supabase.
 * Overwrites any previous manual entry for the same date.
 */
suspend fun saveManualSession(session: SleepSession, profileId: String): ResultWrapper<Unit>
```

**Step 2: Implement in SleepRepositoryImpl**

Open `SleepRepositoryImpl.kt`. Add after `syncToCloud`:

```kotlin
override suspend fun saveManualSession(
    session: SleepSession,
    profileId: String
): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
    try {
        val dto = SleepMapper.toDailyMetricsDto(session, profileId)
        supabaseClient.from("daily_health_metrics").upsert(dto) {
            onConflict = "health_profile_id,metric_date"
        }
        logger.i(TAG, "Saved manual sleep for ${session.date}")
        ResultWrapper.Success(Unit)
    } catch (e: Exception) {
        logger.e(TAG, "Failed to save manual sleep", e)
        ResultWrapper.Error(AppException.UnknownException("Failed to save sleep", e))
    }
}
```

**Step 3: Build to verify no compile errors**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/domain/repository/SleepRepository.kt \
        android/app/src/main/kotlin/com/swastricare/health/data/repository/SleepRepositoryImpl.kt
git commit -m "feat(sleep): add saveManualSession to SleepRepository"
```

---

### Task 2: Create LogSleepViewModel

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/sleep/LogSleepViewModel.kt`

**Step 1: Create the file**

```kotlin
package com.swastricare.health.ui.screens.sleep

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.SleepRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import javax.inject.Inject

data class LogSleepUiState(
    val selectedDate: LocalDate = LocalDate.now(),
    val durationMinutes: Int = 450,         // default 7h 30m
    val bedtimeMillis: Long = 0L,
    val wakeTimeMillis: Long = 0L,
    val notes: String = "",
    val disabledDates: Set<LocalDate> = emptySet(),
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class LogSleepViewModel @Inject constructor(
    private val sleepRepository: SleepRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: SupabaseProfileRepository
) : ViewModel() {

    companion object {
        private const val TAG = "LogSleepViewModel"
    }

    private val _uiState = MutableStateFlow(LogSleepUiState())
    val uiState: StateFlow<LogSleepUiState> = _uiState.asStateFlow()

    init {
        initDefaultTimes()
        loadDisabledDates()
    }

    private fun initDefaultTimes() {
        // Wake = now rounded to nearest 30 min; bedtime = wake - duration
        val now = LocalTime.now()
        val roundedMinute = (now.minute / 30) * 30
        val wakeTime = now.withMinute(roundedMinute).withSecond(0).withNano(0)
        val bedTime = wakeTime.minusMinutes(_uiState.value.durationMinutes.toLong())

        val today = LocalDate.now()
        val zone = ZoneId.systemDefault()

        val wakeMillis = today.atTime(wakeTime).atZone(zone).toInstant().toEpochMilli()
        val bedMillis = today.atTime(bedTime).atZone(zone).toInstant().toEpochMilli()

        _uiState.update { it.copy(wakeTimeMillis = wakeMillis, bedtimeMillis = bedMillis) }
    }

    private fun loadDisabledDates() {
        viewModelScope.launch {
            try {
                val endDate = LocalDate.now()
                val startDate = endDate.minusDays(6)
                val result = sleepRepository.getSleepSessions(startDate, endDate)
                if (result is ResultWrapper.Success) {
                    val hcDates = result.data.map { it.date }.toSet()
                    _uiState.update { it.copy(disabledDates = hcDates) }
                    // If today is disabled, find first non-disabled date
                    if (hcDates.contains(endDate)) {
                        val firstAvailable = (0..6)
                            .map { endDate.minusDays(it.toLong()) }
                            .firstOrNull { !hcDates.contains(it) }
                        firstAvailable?.let { selectDate(it) }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not load HC dates: ${e.message}")
            }
        }
    }

    fun selectDate(date: LocalDate) {
        if (_uiState.value.disabledDates.contains(date)) return
        _uiState.update { state ->
            // Re-derive millis for the new date keeping same times-of-day
            val zone = ZoneId.systemDefault()
            val bedLocal = Instant.ofEpochMilli(state.bedtimeMillis)
                .atZone(zone).toLocalTime()
            val wakeLocal = Instant.ofEpochMilli(state.wakeTimeMillis)
                .atZone(zone).toLocalTime()
            val newBed = date.atTime(bedLocal).atZone(zone).toInstant().toEpochMilli()
            val newWake = date.atTime(wakeLocal).atZone(zone).toInstant().toEpochMilli()
            state.copy(selectedDate = date, bedtimeMillis = newBed, wakeTimeMillis = newWake)
        }
    }

    fun setDuration(minutes: Int) {
        _uiState.update { state ->
            // Anchor wake time, recalculate bedtime
            val newBedMillis = state.wakeTimeMillis - (minutes * 60_000L)
            state.copy(durationMinutes = minutes, bedtimeMillis = newBedMillis)
        }
    }

    fun setBedtime(millis: Long) {
        _uiState.update { state ->
            val durationMs = state.wakeTimeMillis - millis
            val newDuration = (durationMs / 60_000L).coerceIn(0L, 720L).toInt()
            state.copy(bedtimeMillis = millis, durationMinutes = newDuration)
        }
    }

    fun setWakeTime(millis: Long) {
        _uiState.update { state ->
            val durationMs = millis - state.bedtimeMillis
            val newDuration = (durationMs / 60_000L).coerceIn(0L, 720L).toInt()
            state.copy(wakeTimeMillis = millis, durationMinutes = newDuration)
        }
    }

    fun setNotes(text: String) {
        _uiState.update { it.copy(notes = text) }
    }

    fun save() {
        val state = _uiState.value
        if (state.durationMinutes <= 0 || state.isSaving) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null) }
            try {
                val userId = authRepository.getCurrentUser()?.id ?: run {
                    _uiState.update { it.copy(isSaving = false, error = "Not logged in") }
                    return@launch
                }
                val healthProfile = profileRepository.getHealthProfile(userId) ?: run {
                    _uiState.update { it.copy(isSaving = false, error = "Profile not found") }
                    return@launch
                }
                val profileId = healthProfile.id ?: run {
                    _uiState.update { it.copy(isSaving = false, error = "Profile ID missing") }
                    return@launch
                }

                val session = SleepSession(
                    date = state.selectedDate,
                    startTimeEpochMillis = state.bedtimeMillis,
                    endTimeEpochMillis = state.wakeTimeMillis,
                    totalMinutes = state.durationMinutes
                )

                when (val result = sleepRepository.saveManualSession(session, profileId)) {
                    is ResultWrapper.Success -> {
                        _uiState.update { it.copy(isSaving = false, saveSuccess = true) }
                    }
                    is ResultWrapper.Error -> {
                        _uiState.update {
                            it.copy(isSaving = false, error = "Failed to save. Try again.")
                        }
                    }
                    else -> _uiState.update { it.copy(isSaving = false) }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Save failed", e)
                _uiState.update { it.copy(isSaving = false, error = "Unexpected error") }
            }
        }
    }
}
```

**Step 2: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/sleep/LogSleepViewModel.kt
git commit -m "feat(sleep): add LogSleepViewModel with arc state management"
```

---

### Task 3: Create LogSleepScreen

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/sleep/LogSleepScreen.kt`

**Step 1: Create the file**

```kotlin
package com.swastricare.health.ui.screens.sleep

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SleepColor
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.*

// Arc constants
private const val ARC_START_ANGLE = 135f      // degrees
private const val ARC_SWEEP = 270f             // degrees = full range
private const val MAX_SLEEP_MINUTES = 720      // 12h

@Composable
fun LogSleepScreen(
    onNavigateBack: () -> Unit,
    viewModel: LogSleepViewModel = hiltViewModel()
) {
    TrackScreen("LogSleep")
    val uiState by viewModel.uiState.collectAsState()

    // Navigate back on save success
    LaunchedEffect(uiState.saveSuccess) {
        if (uiState.saveSuccess) onNavigateBack()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        // Top bar
        LogSleepTopBar(onNavigateBack = onNavigateBack)

        // Date chips
        DateChipsRow(
            selectedDate = uiState.selectedDate,
            disabledDates = uiState.disabledDates,
            onDateSelected = { viewModel.selectDate(it) }
        )

        Spacer(Modifier.height(24.dp))

        // Circular arc slider
        SleepArcSlider(
            durationMinutes = uiState.durationMinutes,
            onDurationChanged = { viewModel.setDuration(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
        )

        Spacer(Modifier.height(24.dp))

        // Bedtime / Wake time chips
        TimeChipsRow(
            bedtimeMillis = uiState.bedtimeMillis,
            wakeTimeMillis = uiState.wakeTimeMillis,
            onBedtimeChanged = { viewModel.setBedtime(it) },
            onWakeTimeChanged = { viewModel.setWakeTime(it) }
        )

        Spacer(Modifier.height(20.dp))

        // Notes
        OutlinedTextField(
            value = uiState.notes,
            onValueChange = { viewModel.setNotes(it) },
            placeholder = {
                Text("How did you feel?", color = AppColors.onSurfaceVariant)
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(12.dp),
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = SleepColor,
                unfocusedBorderColor = AppColors.onSurface.copy(alpha = 0.2f)
            )
        )

        Spacer(Modifier.height(24.dp))

        // Error
        uiState.error?.let { err ->
            Text(
                err,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(8.dp))
        }

        // Save button
        Button(
            onClick = { viewModel.save() },
            enabled = uiState.durationMinutes > 0 && !uiState.isSaving,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(52.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = SleepColor)
        ) {
            if (uiState.isSaving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    "Save Sleep",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                    color = Color.White
                )
            }
        }

        Spacer(Modifier.height(40.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Top Bar
// ─────────────────────────────────────

@Composable
private fun LogSleepTopBar(onNavigateBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(Icons.Default.ArrowBack, "Back", tint = AppColors.onSurface)
        }
        Text(
            "Log Sleep",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f).padding(start = 4.dp)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Date Chips Row
// ─────────────────────────────────────

@Composable
private fun DateChipsRow(
    selectedDate: LocalDate,
    disabledDates: Set<LocalDate>,
    onDateSelected: (LocalDate) -> Unit
) {
    val today = LocalDate.now()
    val dates = (0..6).map { today.minusDays(it.toLong()) }
    val dayFmt = DateTimeFormatter.ofPattern("EEE")
    val dateFmt = DateTimeFormatter.ofPattern("d")

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        dates.forEach { date ->
            val isSelected = date == selectedDate
            val isDisabled = disabledDates.contains(date)
            val label = if (date == today) "Today" else if (date == today.minusDays(1)) "Yesterday" else date.format(dayFmt)

            val bg = when {
                isSelected -> SleepColor
                isDisabled -> AppColors.onSurface.copy(alpha = 0.05f)
                else -> AppColors.onSurface.copy(alpha = 0.08f)
            }
            val textColor = when {
                isSelected -> Color.White
                isDisabled -> AppColors.onSurface.copy(alpha = 0.3f)
                else -> AppColors.onSurface
            }

            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(bg)
                    .clickable(enabled = !isDisabled) { onDateSelected(date) }
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(label, style = MaterialTheme.typography.labelSmall, color = textColor)
                Text(
                    date.format(dateFmt),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = textColor
                )
                if (isDisabled) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        "Synced",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                        color = textColor
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Circular Arc Slider
// ─────────────────────────────────────

@Composable
fun SleepArcSlider(
    durationMinutes: Int,
    onDurationChanged: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val arcSize = 260.dp

    // Progress 0..1 on the arc
    val progress = durationMinutes.toFloat() / MAX_SLEEP_MINUTES

    // Animate arc fill on first appearance
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }
    val animatedProgress by animateFloatAsState(
        targetValue = if (isVisible) progress else 0f,
        animationSpec = tween(800, easing = FastOutSlowInEasing),
        label = "arcProgress"
    )

    val hours = durationMinutes / 60
    val mins = durationMinutes % 60
    val durationLabel = "${hours}h ${mins}m"

    Box(
        modifier = modifier.aspectRatio(1f),
        contentAlignment = Alignment.Center
    ) {
        Canvas(
            modifier = Modifier
                .size(arcSize)
                .pointerInput(Unit) {
                    detectDragGestures { change, _ ->
                        change.consume()
                        val center = Offset(size.width / 2f, size.height / 2f)
                        val pos = change.position
                        val angle = Math
                            .toDegrees(
                                atan2(
                                    (pos.y - center.y).toDouble(),
                                    (pos.x - center.x).toDouble()
                                )
                            )
                            .toFloat()

                        // Normalize angle relative to arc start (135°)
                        var normalized = angle - ARC_START_ANGLE
                        if (normalized < 0) normalized += 360f
                        if (normalized > ARC_SWEEP) normalized = ARC_SWEEP

                        val newProgress = (normalized / ARC_SWEEP).coerceIn(0f, 1f)
                        // Snap to 15-minute increments
                        val rawMinutes = (newProgress * MAX_SLEEP_MINUTES).roundToInt()
                        val snapped = (rawMinutes / 15) * 15
                        onDurationChanged(snapped.coerceIn(0, MAX_SLEEP_MINUTES))
                    }
                }
        ) {
            val strokeWidth = 22.dp.toPx()
            val padding = strokeWidth / 2 + 4.dp.toPx()
            val diameter = size.width - padding * 2
            val topLeft = Offset(padding, padding)
            val arcSizePx = Size(diameter, diameter)

            // Background arc
            drawArc(
                color = Color.White.copy(alpha = 0.08f),
                startAngle = ARC_START_ANGLE,
                sweepAngle = ARC_SWEEP,
                useCenter = false,
                topLeft = topLeft,
                size = arcSizePx,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )

            // Filled arc
            if (animatedProgress > 0f) {
                drawArc(
                    brush = Brush.sweepGradient(
                        colors = listOf(
                            SleepColor.copy(alpha = 0.7f),
                            SleepColor,
                            Color(0xFF9B5DE5)
                        ),
                        center = center
                    ),
                    startAngle = ARC_START_ANGLE,
                    sweepAngle = ARC_SWEEP * animatedProgress,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSizePx,
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                )
            }

            // Handle position (moon icon approximated as a circle)
            val handleAngleDeg = ARC_START_ANGLE + ARC_SWEEP * progress
            val handleAngleRad = Math.toRadians(handleAngleDeg.toDouble())
            val radius = diameter / 2
            val handleX = center.x + radius * cos(handleAngleRad).toFloat()
            val handleY = center.y + radius * sin(handleAngleRad).toFloat()

            drawCircle(
                color = Color.White,
                radius = 14.dp.toPx(),
                center = Offset(handleX, handleY)
            )
            drawCircle(
                color = SleepColor,
                radius = 10.dp.toPx(),
                center = Offset(handleX, handleY)
            )
        }

        // Center label
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                durationLabel,
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                "Sleep Duration",
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Time Chips Row
// ─────────────────────────────────────

@Composable
private fun TimeChipsRow(
    bedtimeMillis: Long,
    wakeTimeMillis: Long,
    onBedtimeChanged: (Long) -> Unit,
    onWakeTimeChanged: (Long) -> Unit
) {
    val context = LocalContext.current
    val zone = ZoneId.systemDefault()
    val timeFmt = DateTimeFormatter.ofPattern("hh:mm a")

    fun millisToLocalTime(millis: Long) = if (millis > 0)
        Instant.ofEpochMilli(millis).atZone(zone).toLocalTime()
    else null

    fun showTimePicker(initialMillis: Long, onPicked: (Long) -> Unit) {
        val lt = millisToLocalTime(initialMillis)
        val cal = java.util.Calendar.getInstance().apply {
            lt?.let { set(java.util.Calendar.HOUR_OF_DAY, it.hour) }
            lt?.let { set(java.util.Calendar.MINUTE, it.minute) }
        }
        android.app.TimePickerDialog(
            context,
            { _, hour, minute ->
                // Keep same date, just update time
                val ld = Instant.ofEpochMilli(initialMillis).atZone(zone).toLocalDate()
                val newMillis = ld.atTime(hour, minute).atZone(zone).toInstant().toEpochMilli()
                onPicked(newMillis)
            },
            cal.get(java.util.Calendar.HOUR_OF_DAY),
            cal.get(java.util.Calendar.MINUTE),
            false
        ).show()
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Bedtime chip
        TimeChip(
            icon = Icons.Default.Bedtime,
            label = "Bedtime",
            timeText = millisToLocalTime(bedtimeMillis)?.format(timeFmt) ?: "--",
            color = SleepColor,
            modifier = Modifier.weight(1f),
            onClick = { showTimePicker(bedtimeMillis, onBedtimeChanged) }
        )
        // Wake chip
        TimeChip(
            icon = Icons.Default.WbSunny,
            label = "Wake Up",
            timeText = millisToLocalTime(wakeTimeMillis)?.format(timeFmt) ?: "--",
            color = Color(0xFFF59E0B),
            modifier = Modifier.weight(1f),
            onClick = { showTimePicker(wakeTimeMillis, onWakeTimeChanged) }
        )
    }
}

@Composable
private fun TimeChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    timeText: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
            Text(
                timeText,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
        }
    }
}
```

**Step 2: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/sleep/LogSleepScreen.kt
git commit -m "feat(sleep): add LogSleepScreen with circular arc duration slider"
```

---

### Task 4: Wire navigation — add `sleep/log` route

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/MainNavGraph.kt`

**Step 1: Add import**

At the top of `MainNavGraph.kt`, add:

```kotlin
import com.swastricare.health.ui.screens.sleep.LogSleepScreen
```

**Step 2: Update the `sleep` composable to accept onNavigateToLog**

Find (around line 329):

```kotlin
// ─── Sleep ───
composable("sleep") {
    SleepScreen(
        onNavigateBack = { navController.popBackStack() }
    )
}
```

Replace with:

```kotlin
// ─── Sleep ───
composable("sleep") {
    SleepScreen(
        onNavigateBack = { navController.popBackStack() },
        onNavigateToLog = { navController.navigate("sleep/log") }
    )
}

composable("sleep/log") {
    LogSleepScreen(
        onNavigateBack = { navController.popBackStack() }
    )
}
```

**Step 3: Build to verify (will fail — SleepScreen doesn't have the param yet, expected)**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | grep -E "error:|BUILD"
```

Continue to Task 5 to fix the compile error.

---

### Task 5: Update SleepScreen — add FAB + empty state CTA + onNavigateToLog param

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/sleep/SleepScreen.kt`

**Step 1: Add `onNavigateToLog` parameter to `SleepScreen`**

Find (line 52):

```kotlin
@Composable
fun SleepScreen(
    onNavigateBack: () -> Unit = {},
    viewModel: SleepViewModel = hiltViewModel()
) {
```

Replace with:

```kotlin
@Composable
fun SleepScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToLog: () -> Unit = {},
    viewModel: SleepViewModel = hiltViewModel()
) {
```

**Step 2: Add FAB — wrap the Column in a Box with a Scaffold or use Box overlay**

Find (line 59):

```kotlin
Column(modifier = Modifier.fillMaxSize()) {
    // Top Bar
    SleepTopBar(onNavigateBack = onNavigateBack)

    when {
        uiState.isLoading -> SleepSkeletonContent()
        uiState.todaySession == null && uiState.sleepHistory.isEmpty() -> EmptySleepContent()
        else -> SleepContent(
            uiState = uiState,
            onRangeSelected = { viewModel.selectTimeRange(it) }
        )
    }
}
```

Replace with:

```kotlin
Box(modifier = Modifier.fillMaxSize()) {
    Column(modifier = Modifier.fillMaxSize()) {
        SleepTopBar(onNavigateBack = onNavigateBack)

        when {
            uiState.isLoading -> SleepSkeletonContent()
            uiState.todaySession == null && uiState.sleepHistory.isEmpty() ->
                EmptySleepContent(onLogSleep = onNavigateToLog)
            else -> SleepContent(
                uiState = uiState,
                onRangeSelected = { viewModel.selectTimeRange(it) }
            )
        }
    }

    // FAB — only when today has no Health Connect data
    if (!uiState.isLoading && uiState.todaySession == null) {
        FloatingActionButton(
            onClick = onNavigateToLog,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(bottom = 24.dp, end = 16.dp),
            containerColor = SleepColor,
            contentColor = Color.White
        ) {
            Icon(Icons.Default.Bedtime, contentDescription = "Log Sleep")
        }
    }
}
```

**Step 3: Update `EmptySleepContent` to accept and show the CTA button**

Find (line 1086):

```kotlin
@Composable
private fun EmptySleepContent() {
    Box(
```

Replace with:

```kotlin
@Composable
private fun EmptySleepContent(onLogSleep: () -> Unit = {}) {
    Box(
```

Find the closing of `EmptySleepContent` — just before `}` of the Column inside the Box, add the button after the last Text:

```kotlin
            Text(
                "Sleep data will appear here once it's recorded by your wearable or sleep tracking app via Health Connect.",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
```

After that Text, add:

```kotlin
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = onLogSleep,
                colors = ButtonDefaults.buttonColors(containerColor = SleepColor),
                shape = RoundedCornerShape(14.dp)
            ) {
                Icon(
                    Icons.Default.Bedtime,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text("Log Sleep Manually", fontWeight = FontWeight.SemiBold)
            }
```

**Step 4: Add missing imports to SleepScreen.kt**

At the top of the imports section, add (if not already present):

```kotlin
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.ButtonDefaults
import androidx.compose.ui.graphics.Color
```

**Step 5: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL`

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/sleep/SleepScreen.kt \
        android/app/src/main/kotlin/com/swastricare/health/ui/navigation/MainNavGraph.kt
git commit -m "feat(sleep): wire LogSleepScreen into nav, add FAB and empty state CTA"
```

---

### Task 6: Final build verification

**Step 1: Clean build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -30
```
Expected: `BUILD SUCCESSFUL` with no errors or warnings about unresolved references.

**Step 2: Smoke-test checklist (manual on device/emulator)**

- [ ] Open Sleep screen with no HC data → see "Log Sleep Manually" button + FAB
- [ ] Tap either → LogSleepScreen opens
- [ ] Drag arc handle → duration label updates in center, arc fills
- [ ] Tap "Bedtime" chip → time picker dialog opens, picking a time updates bedtime and recalculates arc
- [ ] Tap "Wake Up" chip → same, recalculates duration
- [ ] Date chips show Today / Yesterday etc; HC-synced dates show "Synced" and are not tappable
- [ ] Tap "Save Sleep" → spinner shows → on success, screen pops back to SleepScreen
- [ ] SleepScreen reloads and now shows the manually logged session

**Step 3: Final commit if any fixups were needed**

```bash
git add -p
git commit -m "fix(sleep): address any build fixups from smoke test"
```
