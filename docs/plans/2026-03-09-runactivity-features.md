# RunActivity Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add GPX export, workout templates, elevation profile chart, VO2Max/training load analytics, and battery-aware GPS to the Android RunActivity module.

**Architecture:** Each feature is a self-contained layer: services (GpxExporter, FitnessAnalyticsService) handle logic, models (WorkoutTemplate) handle data, UI composables render results. All wired through AppContainer. No new Supabase tables needed.

**Tech Stack:** Kotlin, Jetpack Compose Canvas, Health Connect API, Android BatteryManager, FileProvider for GPX sharing.

---

### Task 1: GPX Exporter Service

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/GpxExporter.kt`

**Step 1: Create GpxExporter**

```kotlin
package com.swasthicare.mobile.data.services

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.swasthicare.mobile.data.model.RoutePoint
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object GpxExporter {

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    fun exportToGpx(
        context: Context,
        routePoints: List<RoutePoint>,
        activityType: String,
        activityName: String = "$activityType Workout"
    ): File? {
        if (routePoints.size < 2) return null

        val gpxContent = buildString {
            appendLine("""<?xml version="1.0" encoding="UTF-8"?>""")
            appendLine("""<gpx version="1.1" creator="SwasthiCare" xmlns="http://www.topografix.com/GPX/1/1">""")
            appendLine("  <metadata>")
            appendLine("    <name>${escapeXml(activityName)}</name>")
            appendLine("    <time>${isoFormat.format(Date(routePoints.first().timestamp))}</time>")
            appendLine("  </metadata>")
            appendLine("  <trk>")
            appendLine("    <name>${escapeXml(activityName)}</name>")
            appendLine("    <type>${escapeXml(activityType)}</type>")
            appendLine("    <trkseg>")
            for (point in routePoints) {
                append("      <trkpt lat=\"${point.latitude}\" lon=\"${point.longitude}\">")
                if (point.altitude != 0.0) append("<ele>${point.altitude}</ele>")
                append("<time>${isoFormat.format(Date(point.timestamp))}</time>")
                appendLine("</trkpt>")
            }
            appendLine("    </trkseg>")
            appendLine("  </trk>")
            appendLine("</gpx>")
        }

        val fileName = "swasthicare_${activityType.lowercase()}_${System.currentTimeMillis()}.gpx"
        val file = File(context.cacheDir, fileName)
        file.writeText(gpxContent)
        return file
    }

    fun shareGpxFile(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/gpx+xml"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Export GPX"))
    }

    private fun escapeXml(text: String): String =
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}
```

**Step 2: Add FileProvider config**

Create `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="gpx_exports" path="." />
</paths>
```

Add to `AndroidManifest.xml` inside `<application>`:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

**Step 3: Add GPX export button to ActivityDetailScreen**

Modify `ActivityDetailScreen.kt` — update `ActivityDetailTopBar` to add an export button:

Find the `ActivityDetailTopBar` composable and add a second `IconButton` for GPX export alongside the existing share button. The `onExportGpx` callback should call `GpxExporter.exportToGpx()` then `GpxExporter.shareGpxFile()`.

Add `onExportGpx` parameter to `ActivityDetailTopBar`:
```kotlin
@Composable
private fun ActivityDetailTopBar(
    onBack: () -> Unit,
    onShare: () -> Unit,
    onExportGpx: () -> Unit,
    hasRoute: Boolean
)
```

Add the export icon between back and share:
```kotlin
if (hasRoute) {
    IconButton(onClick = onExportGpx) {
        Icon(
            Icons.Default.FileDownload,
            contentDescription = "Export GPX",
            tint = AppColors.onBackground
        )
    }
}
```

Wire it in the caller:
```kotlin
onExportGpx = {
    val file = GpxExporter.exportToGpx(
        context = context,
        routePoints = workout!!.routePoints,
        activityType = workout!!.type
    )
    file?.let { GpxExporter.shareGpxFile(context, it) }
},
hasRoute = workout!!.routePoints.size >= 2
```

**Step 4: Commit**
```
feat(android): add GPX export for workout routes
```

---

### Task 2: Workout Templates Model + Persistence

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/WorkoutTemplate.kt`

**Step 1: Create WorkoutTemplate model**

```kotlin
package com.swasthicare.mobile.data.models

import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class WorkoutTemplate(
    val id: String = java.util.UUID.randomUUID().toString(),
    val name: String,
    val activityType: String, // matches WorkoutType.name
    val targetDistanceMeters: Double? = null,
    val targetDurationSeconds: Long? = null,
    val targetPaceSecondsPerKm: Long? = null,
    val isBuiltIn: Boolean = false
) {
    val targetDistanceKm: Double? get() = targetDistanceMeters?.let { it / 1000.0 }

    val formattedTarget: String get() = buildString {
        targetDistanceKm?.let { append("%.1f km".format(it)) }
        targetDurationSeconds?.let {
            if (isNotEmpty()) append(" / ")
            val mins = it / 60
            append("${mins} min")
        }
        targetPaceSecondsPerKm?.let {
            if (isNotEmpty()) append(" / ")
            val m = it / 60
            val s = it % 60
            append("%d:%02d /km".format(m, s))
        }
    }

    companion object {
        private const val PREFS_KEY = "workout_templates"
        private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }

        val builtInTemplates = listOf(
            WorkoutTemplate(
                id = "builtin_easy_5k",
                name = "Easy Run 5K",
                activityType = "RUN",
                targetDistanceMeters = 5000.0,
                isBuiltIn = true
            ),
            WorkoutTemplate(
                id = "builtin_long_10k",
                name = "Long Run 10K",
                activityType = "RUN",
                targetDistanceMeters = 10000.0,
                isBuiltIn = true
            ),
            WorkoutTemplate(
                id = "builtin_walk_30",
                name = "Walk 30 min",
                activityType = "WALK",
                targetDurationSeconds = 1800,
                isBuiltIn = true
            ),
            WorkoutTemplate(
                id = "builtin_cycle_20k",
                name = "Cycle 20K",
                activityType = "CYCLE",
                targetDistanceMeters = 20000.0,
                isBuiltIn = true
            )
        )

        fun loadTemplates(prefs: SharedPreferences): List<WorkoutTemplate> {
            val saved = prefs.getString(PREFS_KEY, null)
            val custom = if (saved != null) {
                try {
                    json.decodeFromString<List<WorkoutTemplate>>(saved)
                } catch (_: Exception) { emptyList() }
            } else emptyList()
            return builtInTemplates + custom
        }

        fun saveCustomTemplate(prefs: SharedPreferences, template: WorkoutTemplate) {
            val existing = loadTemplates(prefs).filter { !it.isBuiltIn }
            val updated = existing + template
            prefs.edit().putString(PREFS_KEY, json.encodeToString(updated)).apply()
        }

        fun deleteCustomTemplate(prefs: SharedPreferences, templateId: String) {
            val existing = loadTemplates(prefs).filter { !it.isBuiltIn && it.id != templateId }
            prefs.edit().putString(PREFS_KEY, json.encodeToString(existing)).apply()
        }
    }
}
```

**Step 2: Commit**
```
feat(android): add WorkoutTemplate model with SharedPreferences persistence
```

---

### Task 3: Template Cards in LiveWorkoutScreen IdlePhase

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/LiveWorkoutViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/LiveWorkoutScreen.kt`

**Step 1: Add template state to LiveWorkoutViewModel**

Add to `LiveWorkoutUiState`:
```kotlin
val templates: List<WorkoutTemplate> = emptyList(),
val activeTemplate: WorkoutTemplate? = null
```

Add to `LiveWorkoutViewModel`:
```kotlin
fun loadTemplates() {
    val templates = WorkoutTemplate.loadTemplates(AppContainer.sharedPreferences)
    _uiState.update { it.copy(templates = templates) }
}

fun selectTemplate(template: WorkoutTemplate) {
    val type = WorkoutType.entries.find { it.name == template.activityType } ?: WorkoutType.RUN
    _uiState.update { it.copy(
        workoutType = type,
        activeTemplate = template
    ) }
}

fun clearTemplate() {
    _uiState.update { it.copy(activeTemplate = null) }
}

fun saveAsTemplate(name: String) {
    val state = _uiState.value
    val template = WorkoutTemplate(
        name = name,
        activityType = state.workoutType.name,
        targetDistanceMeters = if (state.distanceMeters > 100) state.distanceMeters else null,
        targetDurationSeconds = if (state.elapsedSeconds > 60) state.elapsedSeconds else null
    )
    WorkoutTemplate.saveCustomTemplate(AppContainer.sharedPreferences, template)
}
```

Call `loadTemplates()` in `init`.

**Step 2: Add template cards to IdlePhaseContent**

Below the workout type grid in `IdlePhaseContent`, add a templates section:

```kotlin
// Templates section
if (uiState.templates.isNotEmpty()) {
    Spacer(Modifier.height(24.dp))

    Text(
        "Templates",
        style = MaterialTheme.typography.titleMedium,
        color = AppColors.onBackground.copy(alpha = 0.7f),
        fontWeight = FontWeight.Medium,
        modifier = Modifier.fillMaxWidth()
    )

    Spacer(Modifier.height(12.dp))

    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(uiState.templates) { template ->
            TemplateCard(
                template = template,
                isSelected = uiState.activeTemplate?.id == template.id,
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onSelectTemplate(template)
                }
            )
        }
    }
}
```

Add `TemplateCard` composable:
```kotlin
@Composable
private fun TemplateCard(
    template: WorkoutTemplate,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .width(140.dp)
            .glass(
                cornerRadius = 16.dp,
                opacity = if (isSelected) 0.35f else 0.2f,
                accentColor = if (isSelected) PremiumColor.NeonGreenEnd else null
            )
            .clickable { onClick() }
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = template.name,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = if (isSelected) AppColors.onSurface else AppColors.onSurface.copy(alpha = 0.8f),
            maxLines = 1
        )
        Text(
            text = template.formattedTarget,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant,
            maxLines = 1
        )
    }
}
```

Add `onSelectTemplate` param to `IdlePhaseContent` and wire it:
```kotlin
onSelectTemplate = { viewModel.selectTemplate(it) }
```

Add `LazyRow` import: `import androidx.compose.foundation.lazy.LazyRow` and `import androidx.compose.foundation.lazy.items`.

**Step 3: Add target overlay during tracking**

In `TrackingPhaseContent`, after the timer display, add a target progress row when a template is active:

```kotlin
// Target progress
uiState.activeTemplate?.let { template ->
    Spacer(Modifier.height(8.dp))
    TargetProgressRow(
        template = template,
        currentDistanceMeters = uiState.distanceMeters,
        currentDurationSeconds = uiState.elapsedSeconds
    )
}
```

```kotlin
@Composable
private fun TargetProgressRow(
    template: WorkoutTemplate,
    currentDistanceMeters: Double,
    currentDurationSeconds: Long
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 12.dp, opacity = 0.2f)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            template.name,
            style = MaterialTheme.typography.labelMedium,
            color = AppColors.onSurface.copy(alpha = 0.6f)
        )

        val progress = when {
            template.targetDistanceMeters != null ->
                (currentDistanceMeters / template.targetDistanceMeters).coerceIn(0.0, 1.0)
            template.targetDurationSeconds != null ->
                (currentDurationSeconds.toDouble() / template.targetDurationSeconds).coerceIn(0.0, 1.0)
            else -> 0.0
        }

        Text(
            "${(progress * 100).toInt()}%",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = if (progress >= 1.0) PremiumColor.NeonGreenEnd else Color(0xFF00E5FF)
        )
    }
}
```

**Step 4: Commit**
```
feat(android): add workout templates with selection and live target tracking
```

---

### Task 4: Elevation Profile Chart

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/ElevationProfileChart.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/ActivityDetailScreen.kt`

**Step 1: Create ElevationProfileChart composable**

```kotlin
package com.swasthicare.mobile.ui.screens.runactivity

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.data.model.RoutePoint
import com.swasthicare.mobile.data.services.RouteTracker
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.AppColors
import com.swasthicare.mobile.ui.theme.PremiumColor

@Composable
fun ElevationTab(
    routePoints: List<RoutePoint>,
    modifier: Modifier = Modifier
) {
    if (routePoints.size < 2) {
        Box(
            modifier = modifier.fillMaxWidth().height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "No elevation data available",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
        }
        return
    }

    val altitudes = routePoints.map { it.altitude }
    val minAlt = altitudes.min()
    val maxAlt = altitudes.max()
    val elevationGain = calculateElevationGain(routePoints)

    // Calculate cumulative distances for x-axis
    val distances = mutableListOf(0.0)
    for (i in 1 until routePoints.size) {
        distances.add(distances.last() + RouteTracker.distanceBetween(routePoints[i - 1], routePoints[i]))
    }
    val totalDistanceKm = (distances.last() / 1000.0)

    Column(modifier = modifier.fillMaxWidth()) {
        // Stats row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ElevationStat("Min", "%.0f m".format(minAlt), Color(0xFF00E5FF))
            ElevationStat("Max", "%.0f m".format(maxAlt), Color(0xFFFF9F0A))
            ElevationStat("Gain", "%.0f m".format(elevationGain), PremiumColor.NeonGreenEnd)
        }

        Spacer(Modifier.height(16.dp))

        // Chart
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .glass(cornerRadius = 16.dp)
                .padding(16.dp)
        ) {
            ElevationChart(
                altitudes = altitudes,
                distances = distances,
                minAlt = minAlt,
                maxAlt = maxAlt
            )
        }

        Spacer(Modifier.height(8.dp))

        // X-axis label
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("0 km", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
            Text("%.1f km".format(totalDistanceKm), style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
        }
    }
}

@Composable
private fun ElevationStat(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = color)
        Text(label, style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
    }
}

@Composable
private fun ElevationChart(
    altitudes: List<Double>,
    distances: List<Double>,
    minAlt: Double,
    maxAlt: Double
) {
    val lineColor = PremiumColor.NeonGreenEnd
    val fillColor = PremiumColor.NeonGreenEnd.copy(alpha = 0.2f)
    val gridColor = AppColors.onSurfaceVariant.copy(alpha = 0.1f)
    val altRange = (maxAlt - minAlt).coerceAtLeast(1.0)
    val totalDist = distances.last().coerceAtLeast(1.0)

    Canvas(modifier = Modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val padding = 4.dp.toPx()

        // Grid lines (4 horizontal)
        for (i in 0..4) {
            val y = padding + (h - 2 * padding) * i / 4
            drawLine(gridColor, Offset(0f, y), Offset(w, y), strokeWidth = 1f)
        }

        // Build path
        val path = Path()
        val fillPath = Path()

        for (i in altitudes.indices) {
            val x = (distances[i] / totalDist * w).toFloat()
            val y = (h - padding - ((altitudes[i] - minAlt) / altRange * (h - 2 * padding))).toFloat()

            if (i == 0) {
                path.moveTo(x, y)
                fillPath.moveTo(x, h)
                fillPath.lineTo(x, y)
            } else {
                path.lineTo(x, y)
                fillPath.lineTo(x, y)
            }
        }

        // Close fill path
        fillPath.lineTo(w, h)
        fillPath.close()

        // Draw fill
        drawPath(
            fillPath,
            brush = Brush.verticalGradient(
                colors = listOf(fillColor, Color.Transparent),
                startY = 0f,
                endY = h
            )
        )

        // Draw line
        drawPath(path, color = lineColor, style = Stroke(width = 2.dp.toPx()))
    }
}

private fun calculateElevationGain(points: List<RoutePoint>): Double {
    var gain = 0.0
    for (i in 1 until points.size) {
        val diff = points[i].altitude - points[i - 1].altitude
        if (diff > 0) gain += diff
    }
    return gain
}
```

**Step 2: Add ELEVATION tab to ActivityDetailScreen**

Update the `DetailTab` enum:
```kotlin
private enum class DetailTab(val label: String) {
    OVERVIEW("Overview"),
    SPLITS("Splits"),
    PACE("Pace"),
    ELEVATION("Elevation"),
    HEART_RATE("Heart Rate")
}
```

Add the tab content case in the `when` block:
```kotlin
DetailTab.ELEVATION -> ElevationTab(
    routePoints = workout!!.routePoints,
    modifier = Modifier.padding(horizontal = 16.dp)
)
```

**Step 3: Commit**
```
feat(android): add elevation profile chart tab in activity detail
```

---

### Task 5: FitnessAnalyticsService (VO2Max + Training Load)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/FitnessAnalyticsService.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthConnectService.kt`

**Step 1: Add Vo2MaxRecord to HealthConnectService**

Add to `READ_PERMISSIONS`:
```kotlin
HealthPermission.getReadPermission(Vo2MaxRecord::class)
```

Add method:
```kotlin
suspend fun getVo2Max(): Double? {
    return try {
        val client = HealthConnectClient.getOrCreate(context)
        val now = Instant.now()
        val response = client.readRecords(
            ReadRecordsRequest(
                recordType = Vo2MaxRecord::class,
                timeRangeFilter = TimeRangeFilter.between(
                    now.minus(90, ChronoUnit.DAYS),
                    now
                )
            )
        )
        response.records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram
    } catch (e: Exception) {
        Log.w(TAG, "Failed to read VO2Max: ${e.message}")
        null
    }
}
```

**Step 2: Create FitnessAnalyticsService**

```kotlin
package com.swasthicare.mobile.data.services

import com.swasthicare.mobile.data.models.RunActivity
import com.swasthicare.mobile.data.models.ActivityType
import java.time.LocalDateTime

class FitnessAnalyticsService(
    private val healthConnectService: HealthConnectService
) {
    data class FitnessData(
        val vo2Max: Double? = null,
        val vo2MaxSource: String = "", // "Health Connect" or "Estimated"
        val weeklyTrainingLoad: Int = 0,
        val todayTrainingLoad: Int = 0,
        val loadTrend: LoadTrend = LoadTrend.MAINTAINING
    )

    enum class LoadTrend { INCREASING, MAINTAINING, DECREASING }

    suspend fun getFitnessData(activities: List<RunActivity>): FitnessData {
        val vo2MaxFromHC = healthConnectService.getVo2Max()

        val vo2Max: Double?
        val vo2Source: String
        if (vo2MaxFromHC != null) {
            vo2Max = vo2MaxFromHC
            vo2Source = "Health Connect"
        } else {
            vo2Max = estimateVo2MaxCooper(activities)
            vo2Source = if (vo2Max != null) "Estimated" else ""
        }

        val now = LocalDateTime.now()
        val weekAgo = now.minusDays(7)
        val twoWeeksAgo = now.minusDays(14)

        val thisWeekActivities = activities.filter {
            it.startTime?.isAfter(weekAgo) == true
        }
        val lastWeekActivities = activities.filter {
            it.startTime?.isAfter(twoWeeksAgo) == true &&
            it.startTime?.isBefore(weekAgo) == true
        }

        val weeklyLoad = thisWeekActivities.sumOf { calculateTrainingLoad(it, activities) }
        val lastWeekLoad = lastWeekActivities.sumOf { calculateTrainingLoad(it, activities) }

        val todayActivities = activities.filter {
            it.startTime?.toLocalDate() == now.toLocalDate()
        }
        val todayLoad = todayActivities.sumOf { calculateTrainingLoad(it, activities) }

        val trend = when {
            weeklyLoad > lastWeekLoad * 1.15 -> LoadTrend.INCREASING
            weeklyLoad < lastWeekLoad * 0.85 -> LoadTrend.DECREASING
            else -> LoadTrend.MAINTAINING
        }

        return FitnessData(
            vo2Max = vo2Max,
            vo2MaxSource = vo2Source,
            weeklyTrainingLoad = weeklyLoad,
            todayTrainingLoad = todayLoad,
            loadTrend = trend
        )
    }

    private fun estimateVo2MaxCooper(activities: List<RunActivity>): Double? {
        // Use best running activity >= 12 minutes
        val qualifying = activities.filter {
            it.activityType == ActivityType.RUNNING &&
            it.durationSeconds >= 720 && // 12 min
            it.distanceMeters > 0
        }
        if (qualifying.isEmpty()) return null

        // Use the best recent run (highest distance in 12 min equivalent)
        val best = qualifying.maxByOrNull { it.distanceMeters / it.durationSeconds }
            ?: return null

        // Extrapolate to 12-minute distance
        val metersPerSecond = best.distanceMeters / best.durationSeconds
        val twelveMinsDistance = metersPerSecond * 720

        // Cooper formula: VO2max = (d12 - 504.9) / 44.73
        val vo2 = (twelveMinsDistance - 504.9) / 44.73
        return if (vo2 in 15.0..85.0) vo2 else null
    }

    private fun calculateTrainingLoad(activity: RunActivity, allActivities: List<RunActivity>): Int {
        val durationMinutes = activity.durationSeconds / 60.0

        // Intensity factor: ratio of this pace to best pace (inverted — faster = higher)
        val bestPace = allActivities
            .filter { it.activityType == activity.activityType && it.avgPaceSecondsPerKm > 0 }
            .minOfOrNull { it.avgPaceSecondsPerKm }
            ?: activity.avgPaceSecondsPerKm

        val intensity = if (activity.avgPaceSecondsPerKm > 0 && bestPace > 0) {
            (bestPace.toDouble() / activity.avgPaceSecondsPerKm).coerceIn(0.5, 2.0)
        } else 1.0

        return (durationMinutes * intensity).toInt()
    }
}
```

**Step 3: Register in AppContainer**

Add to `AppContainer.kt`:
```kotlin
val fitnessAnalyticsService: FitnessAnalyticsService by lazy {
    FitnessAnalyticsService(healthConnectService)
}
```

Add import:
```kotlin
import com.swasthicare.mobile.data.services.FitnessAnalyticsService
```

**Step 4: Commit**
```
feat(android): add FitnessAnalyticsService with VO2Max and training load
```

---

### Task 6: Fitness Card on RunActivityScreen Dashboard

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/RunActivityViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/RunActivityScreen.kt`

**Step 1: Add fitness data to RunActivityUiState**

```kotlin
data class RunActivityUiState(
    // ... existing fields ...
    val vo2Max: Double? = null,
    val vo2MaxSource: String = "",
    val weeklyTrainingLoad: Int = 0,
    val loadTrend: FitnessAnalyticsService.LoadTrend = FitnessAnalyticsService.LoadTrend.MAINTAINING
)
```

Add import: `import com.swasthicare.mobile.data.services.FitnessAnalyticsService`

**Step 2: Load fitness data in RunActivityViewModel**

In `loadData()`, after loading activities, add:
```kotlin
// Load fitness analytics
try {
    val fitnessData = AppContainer.fitnessAnalyticsService.getFitnessData(activities)
    _uiState.value = _uiState.value.copy(
        vo2Max = fitnessData.vo2Max,
        vo2MaxSource = fitnessData.vo2MaxSource,
        weeklyTrainingLoad = fitnessData.weeklyTrainingLoad,
        loadTrend = fitnessData.loadTrend
    )
} catch (_: Exception) { }
```

**Step 3: Add FitnessCard composable to RunActivityScreen**

Place after `TodayStatsRow`, before `StartWorkoutCard`:

```kotlin
// Fitness insights
if (uiState.vo2Max != null || uiState.weeklyTrainingLoad > 0) {
    Spacer(Modifier.height(16.dp))
    FitnessCard(
        vo2Max = uiState.vo2Max,
        vo2MaxSource = uiState.vo2MaxSource,
        weeklyLoad = uiState.weeklyTrainingLoad,
        loadTrend = uiState.loadTrend
    )
}
```

```kotlin
@Composable
private fun FitnessCard(
    vo2Max: Double?,
    vo2MaxSource: String,
    weeklyLoad: Int,
    loadTrend: FitnessAnalyticsService.LoadTrend
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(16.dp)
    ) {
        Text(
            "Fitness Insights",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        Spacer(Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            if (vo2Max != null) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "%.1f".format(vo2Max),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF00E5FF)
                    )
                    Text(
                        "VO2 Max",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }

            if (weeklyLoad > 0) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "$weeklyLoad",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = PremiumColor.NeonGreenEnd
                    )
                    Text(
                        "Weekly Load",
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val (trendIcon, trendColor, trendLabel) = when (loadTrend) {
                    FitnessAnalyticsService.LoadTrend.INCREASING ->
                        Triple(Icons.Default.TrendingUp, PremiumColor.NeonGreenEnd, "Building")
                    FitnessAnalyticsService.LoadTrend.DECREASING ->
                        Triple(Icons.Default.TrendingDown, Color(0xFFFF9F0A), "Tapering")
                    FitnessAnalyticsService.LoadTrend.MAINTAINING ->
                        Triple(Icons.Default.TrendingFlat, Color(0xFF00E5FF), "Steady")
                }
                Icon(
                    trendIcon,
                    contentDescription = null,
                    tint = trendColor,
                    modifier = Modifier.size(24.dp)
                )
                Text(
                    trendLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}
```

Add import: `import com.swasthicare.mobile.data.services.FitnessAnalyticsService`

**Step 4: Commit**
```
feat(android): add fitness insights card with VO2Max and training load
```

---

### Task 7: Battery-Aware GPS in RouteTracker

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/RouteTracker.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/LiveWorkoutViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/LiveWorkoutScreen.kt`

**Step 1: Add battery-aware GPS modes to RouteTracker**

Add enum and battery check:
```kotlin
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager

enum class GpsMode(val label: String) {
    HIGH_ACCURACY("High Accuracy"),
    BALANCED("Balanced"),
    LOW_POWER("Low Power")
}
```

Add state flow:
```kotlin
private val _gpsMode = MutableStateFlow(GpsMode.HIGH_ACCURACY)
val gpsMode: StateFlow<GpsMode> = _gpsMode.asStateFlow()

private var batteryCheckJob: Job? = null
```

Add battery check method:
```kotlin
private fun getBatteryPercent(): Int {
    val batteryStatus = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    return if (level >= 0 && scale > 0) (level * 100 / scale) else 100
}

private fun updateGpsMode() {
    val battery = getBatteryPercent()
    val newMode = when {
        battery > 20 -> GpsMode.HIGH_ACCURACY
        battery > 10 -> GpsMode.BALANCED
        else -> GpsMode.LOW_POWER
    }
    if (newMode != _gpsMode.value) {
        _gpsMode.value = newMode
        applyGpsMode(newMode)
    }
}

@SuppressLint("MissingPermission")
private fun applyGpsMode(mode: GpsMode) {
    if (!isTracking) return

    fusedClient.removeLocationUpdates(locationCallback)

    val request = when (mode) {
        GpsMode.HIGH_ACCURACY -> LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 3_000L)
            .setMinUpdateIntervalMillis(2_000L)
            .setMinUpdateDistanceMeters(2f)
        GpsMode.BALANCED -> LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5_000L)
            .setMinUpdateIntervalMillis(3_000L)
            .setMinUpdateDistanceMeters(5f)
        GpsMode.LOW_POWER -> LocationRequest.Builder(Priority.PRIORITY_LOW_POWER, 10_000L)
            .setMinUpdateIntervalMillis(5_000L)
            .setMinUpdateDistanceMeters(10f)
    }.setWaitForAccurateLocation(false).build()

    fusedClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
}
```

Update `RouteTracker` constructor to accept `Context` (it already does) and store it:
```kotlin
class RouteTracker(private val context: Context) {
```

Modify `startTracking()` to check battery on start and start periodic check:
```kotlin
@SuppressLint("MissingPermission")
fun startTracking() {
    if (isTracking) return
    isTracking = true
    isPaused = false
    _gpsStatus.value = GpsStatus.SEARCHING
    _routePoints.value = emptyList()
    _totalDistanceMeters.value = 0.0

    updateGpsMode()

    fusedClient.requestLocationUpdates(
        buildLocationRequest(_gpsMode.value),
        locationCallback,
        Looper.getMainLooper()
    )

    // Check battery every 60s
    batteryCheckJob = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
        while (isTracking) {
            kotlinx.coroutines.delay(60_000)
            updateGpsMode()
        }
    }
}
```

Add `buildLocationRequest`:
```kotlin
private fun buildLocationRequest(mode: GpsMode): LocationRequest {
    return when (mode) {
        GpsMode.HIGH_ACCURACY -> LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 3_000L)
            .setMinUpdateIntervalMillis(2_000L)
            .setMinUpdateDistanceMeters(2f)
        GpsMode.BALANCED -> LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5_000L)
            .setMinUpdateIntervalMillis(3_000L)
            .setMinUpdateDistanceMeters(5f)
        GpsMode.LOW_POWER -> LocationRequest.Builder(Priority.PRIORITY_LOW_POWER, 10_000L)
            .setMinUpdateIntervalMillis(5_000L)
            .setMinUpdateDistanceMeters(10f)
    }.setWaitForAccurateLocation(false).build()
}
```

Update `stopTracking()`:
```kotlin
fun stopTracking() {
    isTracking = false
    isPaused = false
    _gpsStatus.value = GpsStatus.OFF
    _gpsMode.value = GpsMode.HIGH_ACCURACY
    fusedClient.removeLocationUpdates(locationCallback)
    batteryCheckJob?.cancel()
}
```

Remove the old hardcoded `locationRequest` field — it's now built dynamically.

**Step 2: Add GPS mode to LiveWorkoutUiState**

```kotlin
val gpsMode: GpsMode = GpsMode.HIGH_ACCURACY
```

Collect in `LiveWorkoutViewModel.init`:
```kotlin
viewModelScope.launch {
    routeTracker.gpsMode.collect { mode ->
        _uiState.update { it.copy(gpsMode = mode) }
    }
}
```

Import: `import com.swasthicare.mobile.data.services.GpsMode`

**Step 3: Add battery mode chip to TrackingPhaseContent**

Next to `GpsStatusChip`, show GPS mode when not HIGH_ACCURACY:

```kotlin
if (uiState.gpsMode != GpsMode.HIGH_ACCURACY) {
    Spacer(Modifier.width(8.dp))
    Text(
        uiState.gpsMode.label,
        style = MaterialTheme.typography.labelSmall,
        color = when (uiState.gpsMode) {
            GpsMode.BALANCED -> Color(0xFFFFD60A)
            GpsMode.LOW_POWER -> Color(0xFFFF9F0A)
            else -> AppColors.onSurfaceVariant
        },
        fontWeight = FontWeight.Medium,
        modifier = Modifier
            .glass(cornerRadius = 8.dp, opacity = 0.2f)
            .padding(horizontal = 8.dp, vertical = 4.dp)
    )
}
```

Import: `import com.swasthicare.mobile.data.services.GpsMode`

**Step 4: Commit**
```
feat(android): add battery-aware GPS accuracy with dynamic mode switching
```

---

### Task 8: Final Integration + Build Verification

**Step 1: Verify all imports in AppContainer**

Ensure `AppContainer.kt` has:
```kotlin
import com.swasthicare.mobile.data.services.FitnessAnalyticsService
```

And the `fitnessAnalyticsService` lazy property.

**Step 2: Build the project**

Run: `cd android && ./gradlew assembleDebug`

Fix any compilation errors.

**Step 3: Final commit**
```
feat(android): complete RunActivity features — GPX export, templates, elevation chart, fitness analytics, battery GPS
```
