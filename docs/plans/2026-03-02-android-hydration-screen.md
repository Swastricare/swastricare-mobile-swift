# Android Hydration Screen — iOS Carbon Copy

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a full Hydration tracking screen on Android matching iOS HydrationView — animated water glass, 7-day calendar strip, drink types with caffeine tracking, quick-add presets, insights, and today's log.

**Architecture:** Local-first using SharedPreferences (same pattern as Diet). `HydrationEntry` records are written locally first, synced to Supabase `hydration_logs` table in background. The home screen hydration card navigates to this new screen instead of just incrementing inline.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, `kotlinx.serialization`, Supabase Kotlin SDK, `rememberInfiniteTransition` for water wave animation.

---

## Task 1: Data Models (`HydrationModels.kt`)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/HydrationModels.kt`

**Step 1: Write the full file**

```kotlin
package com.swasthicare.mobile.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

// ── Drink Type ──

enum class DrinkType(
    val displayName: String,
    val emoji: String,
    val effectivenessRatio: Float,
    val containsCaffeine: Boolean
) {
    WATER("Water", "💧", 1.0f, false),
    COFFEE("Coffee", "☕", 0.5f, true),
    TEA("Tea", "🍵", 0.75f, true),
    JUICE("Juice", "🥤", 0.9f, false),
    SPORTS_DRINK("Sports Drink", "🏃", 0.8f, false),
    MILK("Milk", "🥛", 0.85f, false),
    SODA("Soda", "🫧", 0.6f, false);

    companion object {
        fun fromName(name: String): DrinkType =
            values().firstOrNull { it.name == name } ?: WATER
    }
}

// ── Quick Add Preset ──

data class QuickAddPreset(
    val amountMl: Int,
    val label: String,
    val emoji: String
) {
    companion object {
        val defaults = listOf(
            QuickAddPreset(250, "250 ml", "🥃"),
            QuickAddPreset(500, "500 ml", "🫗"),
            QuickAddPreset(750, "750 ml", "🍶")
        )
    }
}

// ── Hydration Entry ──

@Serializable
data class HydrationEntry(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("amount_ml") val amountMl: Int,
    @SerialName("drink_type") val drinkType: String = DrinkType.WATER.name,
    @SerialName("logged_at") val loggedAt: String = Instant.now().toString(),
    @SerialName("is_synced") val isSynced: Boolean = false
) {
    val drinkTypeEnum: DrinkType get() = DrinkType.fromName(drinkType)
    val effectiveHydration: Int get() = (amountMl * drinkTypeEnum.effectivenessRatio).toInt()
    val formattedTime: String get() = try {
        val dt = LocalDateTime.ofInstant(Instant.parse(loggedAt), ZoneId.systemDefault())
        dt.format(DateTimeFormatter.ofPattern("h:mm a"))
    } catch (_: Exception) { "" }
    val loggedDate: LocalDate get() = try {
        LocalDateTime.ofInstant(Instant.parse(loggedAt), ZoneId.systemDefault()).toLocalDate()
    } catch (_: Exception) { LocalDate.now() }
}

// ── Hydration Goals ──

@Serializable
data class HydrationGoals(
    @SerialName("daily_goal_ml") val dailyGoalMl: Int = 2500,
    @SerialName("activity_level") val activityLevel: String = "moderate",
    @SerialName("weight_kg") val weightKg: Double? = null
) {
    companion object {
        val Default = HydrationGoals()
    }

    val goalDescription: String get() {
        val base = weightKg?.let { "${it.toInt()}kg body weight" } ?: "standard"
        return "Goal based on $base & $activityLevel activity"
    }
}

// ── Hydration Insights ──

data class HydrationInsights(
    val currentStreak: Int = 0,
    val averageDailyIntake: Int = 0,
    val bestDayAmount: Int? = null,
    val caffeineWarning: String? = null
)

// ── Supabase DTO ──

@Serializable
data class HydrationLogRecord(
    val id: String,
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("amount_ml") val amountMl: Int,
    @SerialName("drink_type") val drinkType: String,
    @SerialName("logged_at") val loggedAt: String
) {
    companion object {
        fun from(entry: HydrationEntry, profileId: String) = HydrationLogRecord(
            id = entry.id,
            healthProfileId = profileId,
            amountMl = entry.amountMl,
            drinkType = entry.drinkType,
            loggedAt = entry.loggedAt
        )
    }
}
```

**Step 2: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/models/HydrationModels.kt
git commit -m "feat(hydration): add HydrationModels — DrinkType, HydrationEntry, HydrationGoals, HydrationInsights"
```

---

## Task 2: Repository (`HydrationRepository.kt`)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/HydrationRepository.kt`

**Step 1: Write the file**

```kotlin
package com.swasthicare.mobile.data.repository

import android.content.SharedPreferences
import com.swasthicare.mobile.data.models.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val hydrationJson = Json { ignoreUnknownKeys = true; isLenient = true }

interface HydrationRepository {
    fun loadLocalEntries(): List<HydrationEntry>
    fun addLocalEntry(entry: HydrationEntry)
    fun deleteLocalEntry(id: String)
    fun markEntriesAsSynced(ids: List<String>)
    fun loadGoals(): HydrationGoals
    fun saveGoals(goals: HydrationGoals)
    suspend fun syncEntriesToCloud(entries: List<HydrationEntry>, profileId: String): Result<Unit>
    suspend fun deleteCloudEntry(id: String): Result<Unit>
}

class SupabaseHydrationRepository(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : HydrationRepository {

    override fun loadLocalEntries(): List<HydrationEntry> = try {
        val raw = prefs.getString("hydration_entries", null) ?: return emptyList()
        hydrationJson.decodeFromString<List<HydrationEntry>>(raw)
    } catch (_: Exception) { emptyList() }

    override fun addLocalEntry(entry: HydrationEntry) {
        val current = loadLocalEntries().toMutableList()
        current.add(0, entry) // newest first
        prefs.edit().putString("hydration_entries", hydrationJson.encodeToString(current)).apply()
    }

    override fun deleteLocalEntry(id: String) {
        val current = loadLocalEntries().filter { it.id != id }
        prefs.edit().putString("hydration_entries", hydrationJson.encodeToString(current)).apply()
    }

    override fun markEntriesAsSynced(ids: List<String>) {
        val current = loadLocalEntries().map { e ->
            if (ids.contains(e.id)) e.copy(isSynced = true) else e
        }
        prefs.edit().putString("hydration_entries", hydrationJson.encodeToString(current)).apply()
    }

    override fun loadGoals(): HydrationGoals = try {
        val raw = prefs.getString("hydration_goals", null) ?: return HydrationGoals.Default
        hydrationJson.decodeFromString<HydrationGoals>(raw)
    } catch (_: Exception) { HydrationGoals.Default }

    override fun saveGoals(goals: HydrationGoals) {
        prefs.edit().putString("hydration_goals", hydrationJson.encodeToString(goals)).apply()
    }

    override suspend fun syncEntriesToCloud(
        entries: List<HydrationEntry>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            if (entries.isEmpty()) return@withContext Result.success(Unit)
            val records = entries.map { HydrationLogRecord.from(it, profileId) }
            supabaseClient.from("hydration_logs").upsert(records)
            markEntriesAsSynced(entries.map { it.id })
            Result.success(Unit)
        } catch (e: Exception) { Result.failure(e) }
    }

    override suspend fun deleteCloudEntry(id: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("hydration_logs").delete {
                    filter { eq("id", id) }
                }
                Result.success(Unit)
            } catch (e: Exception) { Result.failure(e) }
        }
}
```

**Step 2: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/HydrationRepository.kt
git commit -m "feat(hydration): add HydrationRepository with SharedPrefs local storage and Supabase sync"
```

---

## Task 3: ViewModel (`HydrationViewModel.kt`)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationViewModel.kt`

**Step 1: Create the directory and file**

```kotlin
package com.swasthicare.mobile.ui.screens.hydration

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.HydrationRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

data class HydrationUiState(
    val entries: List<HydrationEntry> = emptyList(),
    val goals: HydrationGoals = HydrationGoals.Default,
    val insights: HydrationInsights? = null,
    val selectedDate: LocalDate = LocalDate.now(),
    val selectedDrinkType: DrinkType = DrinkType.WATER,
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val todaysEntries: List<HydrationEntry>
        get() = entries.filter { it.loggedDate == selectedDate }

    val totalIntake: Int
        get() = todaysEntries.sumOf { it.amountMl }

    val effectiveIntake: Int
        get() = todaysEntries.sumOf { it.effectiveHydration }

    val progress: Float
        get() = if (goals.dailyGoalMl > 0) {
            (effectiveIntake.toFloat() / goals.dailyGoalMl).coerceIn(0f, 1f)
        } else 0f

    val remainingMl: Int
        get() = maxOf(0, goals.dailyGoalMl - effectiveIntake)

    val caffeineCount: Int
        get() = todaysEntries.count { it.drinkTypeEnum.containsCaffeine }

    val isGoalMet: Boolean
        get() = effectiveIntake >= goals.dailyGoalMl
}

class HydrationViewModel(
    private val repository: HydrationRepository,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HydrationUiState())
    val uiState: StateFlow<HydrationUiState> = _uiState.asStateFlow()

    init { loadData() }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val entries = repository.loadLocalEntries()
            val goals = repository.loadGoals()
            val insights = computeInsights(entries)
            _uiState.value = _uiState.value.copy(
                entries = entries,
                goals = goals,
                insights = insights,
                isLoading = false
            )
            syncInBackground()
        }
    }

    fun addEntry(amountMl: Int, drinkType: DrinkType) {
        viewModelScope.launch {
            val entry = HydrationEntry(
                amountMl = amountMl,
                drinkType = drinkType.name,
                loggedAt = Instant.now().toString()
            )
            repository.addLocalEntry(entry)
            val updated = repository.loadLocalEntries()
            _uiState.value = _uiState.value.copy(
                entries = updated,
                insights = computeInsights(updated)
            )
        }
    }

    fun deleteEntry(id: String) {
        viewModelScope.launch {
            repository.deleteLocalEntry(id)
            val updated = repository.loadLocalEntries()
            _uiState.value = _uiState.value.copy(
                entries = updated,
                insights = computeInsights(updated)
            )
            repository.deleteCloudEntry(id)
        }
    }

    fun selectDate(date: LocalDate) {
        _uiState.value = _uiState.value.copy(selectedDate = date)
    }

    fun selectDrinkType(drinkType: DrinkType) {
        _uiState.value = _uiState.value.copy(selectedDrinkType = drinkType)
    }

    private fun syncInBackground() {
        viewModelScope.launch {
            val unsynced = _uiState.value.entries.filter { !it.isSynced }
            if (unsynced.isEmpty()) return@launch
            val profileId = try { profileRepository.getProfile()?.id ?: return@launch }
                            catch (_: Exception) { return@launch }
            repository.syncEntriesToCloud(unsynced, profileId)
        }
    }

    private fun computeInsights(entries: List<HydrationEntry>): HydrationInsights {
        val today = LocalDate.now()
        // Streak: consecutive days with entries
        var streak = 0
        var checkDate = today
        while (true) {
            val dayEntries = entries.filter { it.loggedDate == checkDate }
            if (dayEntries.isEmpty()) break
            streak++
            checkDate = checkDate.minusDays(1)
        }
        // Average daily intake over last 7 days
        val last7 = (0..6).map { today.minusDays(it.toLong()) }
        val dailyTotals = last7.map { day ->
            entries.filter { it.loggedDate == day }.sumOf { it.effectiveHydration }
        }.filter { it > 0 }
        val avg = if (dailyTotals.isNotEmpty()) dailyTotals.average().toInt() else 0
        // Best day this week
        val bestDay = last7.maxByOrNull { day ->
            entries.filter { it.loggedDate == day }.sumOf { it.effectiveHydration }
        }
        val bestDayAmount = bestDay?.let { day ->
            entries.filter { it.loggedDate == day }.sumOf { it.effectiveHydration }.takeIf { it > 0 }
        }
        // Caffeine warning
        val caffeineCount = entries.filter { it.loggedDate == today && it.drinkTypeEnum.containsCaffeine }.size
        val caffeineWarning = if (caffeineCount >= 3) "You've had $caffeineCount caffeinated drinks today. Consider switching to water." else null

        return HydrationInsights(
            currentStreak = streak,
            averageDailyIntake = avg,
            bestDayAmount = bestDayAmount,
            caffeineWarning = caffeineWarning
        )
    }
}
```

**Step 2: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationViewModel.kt
git commit -m "feat(hydration): add HydrationViewModel with effective intake, insights, and background sync"
```

---

## Task 4: Components (`HydrationComponents.kt`)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationComponents.kt`

**Step 1: Write the file**

```kotlin
package com.swasthicare.mobile.ui.screens.hydration

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.DrinkType
import com.swasthicare.mobile.data.models.HydrationEntry
import com.swasthicare.mobile.data.models.HydrationInsights
import com.swasthicare.mobile.ui.screens.home.glass
import java.time.LocalDate
import kotlin.math.PI
import kotlin.math.sin

private val HydrationCyan = Color(0xFF00C7BE)

// ── Calendar Strip ──

@Composable
fun HydrationCalendarStrip(
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val dates = (-3..3).map { today.plusDays(it.toLong()) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        dates.forEach { date ->
            val isSelected = date == selectedDate
            val isToday = date == today
            Column(
                modifier = Modifier
                    .width(42.dp)
                    .clickable { onDateSelected(date) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = date.dayOfWeek.name.take(3),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isSelected) HydrationCyan else MaterialTheme.colorScheme.onSurfaceVariant
                )
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(
                            color = when {
                                isSelected -> HydrationCyan
                                isToday -> HydrationCyan.copy(alpha = 0.12f)
                                else -> Color.Transparent
                            },
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = date.dayOfMonth.toString(),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }
    }
}

// ── Water Glass View ──

@Composable
fun WaterGlassComposable(
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(durationMillis = 800, easing = FastOutSlowInEasing),
        label = "glassFill"
    )

    val infiniteTransition = rememberInfiniteTransition(label = "glassWave")
    val wavePhase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2f * PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "glassPhase"
    )

    val cyanColor = HydrationCyan
    val strokeColor = HydrationCyan.copy(alpha = 0.35f)
    val backWaveColor = HydrationCyan.copy(alpha = 0.25f)
    val frontWaveColor = HydrationCyan.copy(alpha = 0.50f)
    val textColor = MaterialTheme.colorScheme.onSurface

    Box(
        modifier = modifier.size(width = 120.dp, height = 160.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val baseInset = w * 0.125f
            val bottomRadius = minOf(w * 0.1f, 30f)

            // Build glass outline path
            fun buildGlassPath(): Path {
                val path = Path()
                path.moveTo(0f, 0f)
                path.lineTo(w, 0f)
                path.lineTo(w - baseInset, h - bottomRadius)
                path.quadraticBezierTo(w - baseInset, h, w - baseInset - bottomRadius, h)
                path.lineTo(baseInset + bottomRadius, h)
                path.quadraticBezierTo(baseInset, h, baseInset, h - bottomRadius)
                path.lineTo(0f, 0f)
                path.close()
                return path
            }

            val glassPath = buildGlassPath()
            val fillHeight = h * animatedProgress

            // Clip to glass shape and draw water fill
            clipPath(glassPath) {
                // Draw back wave
                val backPath = Path()
                backPath.moveTo(0f, h)
                backPath.lineTo(0f, h - fillHeight)
                for (x in 0..w.toInt() step 4) {
                    val xf = x.toFloat()
                    val angle = (xf / w) * 2f * PI.toFloat() + wavePhase
                    val y = h - fillHeight + sin(angle) * (h * 0.025f)
                    backPath.lineTo(xf, y)
                }
                backPath.lineTo(w, h)
                backPath.close()
                drawPath(backPath, color = backWaveColor)

                // Draw front wave (offset by π)
                val frontPath = Path()
                frontPath.moveTo(0f, h)
                frontPath.lineTo(0f, h - fillHeight)
                for (x in 0..w.toInt() step 4) {
                    val xf = x.toFloat()
                    val angle = (xf / w) * 2f * PI.toFloat() + wavePhase + PI.toFloat() * 1.5f
                    val y = h - fillHeight + sin(angle) * (h * 0.02f)
                    frontPath.lineTo(xf, y)
                }
                frontPath.lineTo(w, h)
                frontPath.close()
                drawPath(frontPath, color = frontWaveColor)
            }

            // Draw glass outline on top
            drawPath(glassPath, color = strokeColor, style = Stroke(width = 3f))
        }

        // Percentage label
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = "${(progress * 100).toInt()}%",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = textColor
            )
            if (progress >= 1f) {
                Text("✓", fontSize = 16.sp, color = Color.Green)
            }
        }
    }
}

// ── Stat Pill ──

@Composable
fun HydrationStatPill(
    emoji: String,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .background(color.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .padding(vertical = 10.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(emoji, fontSize = 14.sp)
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ── Insights Card ──

@Composable
fun HydrationInsightsCard(
    insights: HydrationInsights,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .glass(cornerRadius = 16.dp)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("📊", fontSize = 18.sp)
            Text("Insights", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            InsightItem(value = "${insights.currentStreak}", label = "Day Streak", emoji = "🔥")
            InsightItem(value = "${insights.averageDailyIntake}", label = "Avg ml/day", emoji = "📈")
            insights.bestDayAmount?.let {
                InsightItem(value = "$it", label = "Best Day", emoji = "🏆")
            }
        }
    }
}

@Composable
private fun InsightItem(value: String, label: String, emoji: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(emoji, fontSize = 20.sp)
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ── Hydration Entry Card ──

@Composable
fun HydrationEntryCard(
    entry: HydrationEntry,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Drink type icon
        Box(
            modifier = Modifier
                .size(50.dp)
                .background(HydrationCyan.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(entry.drinkTypeEnum.emoji, fontSize = 22.sp)
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "${entry.amountMl} ml",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                if (entry.drinkTypeEnum != DrinkType.WATER) {
                    Text(
                        "(${entry.effectiveHydration} ml effective)",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Text(
                "${entry.drinkTypeEnum.displayName} · ${entry.formattedTime}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        IconButton(onClick = onDelete) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete",
                tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

// ── Drink Type Picker Sheet ──

@Composable
fun DrinkTypePickerSheet(
    selectedType: DrinkType,
    onTypeSelected: (DrinkType) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "Select Drink",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        DrinkType.values().forEach { type ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onTypeSelected(type) }
                    .background(
                        if (type == selectedType) HydrationCyan.copy(alpha = 0.08f) else Color.Transparent,
                        RoundedCornerShape(12.dp)
                    )
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(type.emoji, fontSize = 22.sp)
                Column(modifier = Modifier.weight(1f)) {
                    Text(type.displayName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                    if (type.containsCaffeine) {
                        Text("Contains caffeine", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                if (type == selectedType) {
                    Text("✓", color = HydrationCyan, fontWeight = FontWeight.Bold)
                }
            }
        }
        Spacer(modifier = Modifier.height(20.dp))
    }
}
```

**Step 2: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationComponents.kt
git commit -m "feat(hydration): add WaterGlassComposable, HydrationCalendarStrip, stat pills, entry card, and drink type picker"
```

---

## Task 5: Main Screen (`HydrationScreen.kt`)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationScreen.kt`

**Step 1: Write the file**

```kotlin
package com.swasthicare.mobile.ui.screens.hydration

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.DrinkType
import com.swasthicare.mobile.data.models.QuickAddPreset
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass

private val HydrationCyan = Color(0xFF00C7BE)
private val HydrationBrandBlue = Color(0xFF2E3192)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HydrationScreen(
    viewModel: HydrationViewModel,
    onNavigateBack: () -> Unit = {},
    onNavigateToAI: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    var showDrinkTypePicker by remember { mutableStateOf(false) }
    var customAmount by remember { mutableStateOf("") }
    var showCustomAmount by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text("Hydration", fontWeight = FontWeight.Bold) },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                    },
                    actions = {
                        // Ask AI button
                        TextButton(onClick = onNavigateToAI) {
                            Icon(
                                Icons.Default.AutoAwesome,
                                contentDescription = null,
                                tint = HydrationCyan,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Ask AI", color = HydrationCyan, fontWeight = FontWeight.SemiBold)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
                )
            }
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                // 1. Calendar Strip
                HydrationCalendarStrip(
                    selectedDate = uiState.selectedDate,
                    onDateSelected = { viewModel.selectDate(it) }
                )

                // 2. Progress Section
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp)
                        .glass(cornerRadius = 20.dp)
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text(
                        uiState.goals.goalDescription,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    WaterGlassComposable(progress = uiState.progress)

                    // Stat pills row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        HydrationStatPill(
                            emoji = "💧",
                            value = "${uiState.totalIntake}",
                            label = "of ${uiState.goals.dailyGoalMl} ml",
                            color = HydrationCyan,
                            modifier = Modifier.weight(1f)
                        )
                        HydrationStatPill(
                            emoji = "⬆️",
                            value = "${uiState.remainingMl}",
                            label = "remaining",
                            color = Color(0xFF34C759),
                            modifier = Modifier.weight(1f)
                        )
                        HydrationStatPill(
                            emoji = "☕",
                            value = "${uiState.caffeineCount}",
                            label = "caffeine",
                            color = Color(0xFF8E6B3E),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // 3. Quick Add Section
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp)
                        .glass(cornerRadius = 20.dp)
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "Quick Add",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f)
                        )
                        // Drink type pill selector
                        Row(
                            modifier = Modifier
                                .glass(cornerRadius = 20.dp)
                                .clickable { showDrinkTypePicker = true }
                                .padding(horizontal = 14.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Text(uiState.selectedDrinkType.emoji, fontSize = 14.sp)
                            Text(uiState.selectedDrinkType.displayName, style = MaterialTheme.typography.labelLarge)
                        }
                    }

                    // Preset buttons
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        QuickAddPreset.defaults.forEach { preset ->
                            Column(
                                modifier = Modifier
                                    .weight(1f)
                                    .background(
                                        HydrationCyan.copy(alpha = 0.12f),
                                        RoundedCornerShape(12.dp)
                                    )
                                    .clickable { viewModel.addEntry(preset.amountMl, uiState.selectedDrinkType) }
                                    .padding(vertical = 14.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(preset.emoji, fontSize = 24.sp)
                                Text(
                                    preset.label,
                                    style = MaterialTheme.typography.labelMedium,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }

                    // Custom amount
                    if (showCustomAmount) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = customAmount,
                                onValueChange = { customAmount = it.filter { c -> c.isDigit() } },
                                label = { Text("Amount") },
                                suffix = { Text("ml") },
                                modifier = Modifier.weight(1f),
                                singleLine = true
                            )
                            Button(
                                onClick = {
                                    val amount = customAmount.toIntOrNull()
                                    if (amount != null && amount > 0) {
                                        viewModel.addEntry(amount, uiState.selectedDrinkType)
                                        customAmount = ""
                                        showCustomAmount = false
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = HydrationBrandBlue)
                            ) { Text("Add") }
                            IconButton(onClick = { showCustomAmount = false; customAmount = "" }) {
                                Text("✕", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    } else {
                        TextButton(
                            onClick = { showCustomAmount = true },
                            modifier = Modifier.align(Alignment.Start)
                        ) {
                            Text("+ Custom Amount", color = HydrationBrandBlue, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }

                // 4. Insights Card
                uiState.insights?.let { insights ->
                    HydrationInsightsCard(insights = insights)
                }

                // 5. Caffeine warning
                uiState.insights?.caffeineWarning?.let { warning ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp)
                            .background(Color(0xFF8E6B3E).copy(alpha = 0.1f), RoundedCornerShape(12.dp))
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("☕", fontSize = 22.sp)
                        Text(
                            warning,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // 6. Today's Log
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(
                        "Today's Log",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 20.dp)
                    )

                    if (uiState.todaysEntries.isEmpty()) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 40.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text("💧", fontSize = 40.sp)
                            Text("No entries yet", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                "Tap the quick add buttons above to log your water intake",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 40.dp)
                            )
                        }
                    } else {
                        uiState.todaysEntries.forEach { entry ->
                            HydrationEntryCard(
                                entry = entry,
                                onDelete = { viewModel.deleteEntry(entry.id) },
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                        }
                    }
                }

                // 7. Ask AI button
                TextButton(
                    onClick = onNavigateToAI,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp)
                        .background(HydrationBrandBlue.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                ) {
                    Text("✨ Ask AI about my hydration", color = HydrationBrandBlue, fontWeight = FontWeight.SemiBold)
                }

                Spacer(modifier = Modifier.height(120.dp))
            }
        }
    }

    // Drink type picker bottom sheet
    if (showDrinkTypePicker) {
        ModalBottomSheet(
            onDismissRequest = { showDrinkTypePicker = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            DrinkTypePickerSheet(
                selectedType = uiState.selectedDrinkType,
                onTypeSelected = {
                    viewModel.selectDrinkType(it)
                    showDrinkTypePicker = false
                }
            )
        }
    }
}
```

**Step 2: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationScreen.kt
git commit -m "feat(hydration): add HydrationScreen — glass progress, calendar, quick-add, insights, today's log"
```

---

## Task 6: Wire up DI, Navigation, and Home Screen

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeScreen.kt`

### AppContainer.kt

Add to imports:
```kotlin
import com.swasthicare.mobile.data.repository.HydrationRepository
import com.swasthicare.mobile.data.repository.SupabaseHydrationRepository
import com.swasthicare.mobile.ui.screens.hydration.HydrationViewModel
```

Add after `dietViewModel`:
```kotlin
val hydrationRepository: HydrationRepository by lazy {
    SupabaseHydrationRepository(supabaseClient, sharedPreferences)
}

val hydrationViewModel: HydrationViewModel by lazy {
    HydrationViewModel(hydrationRepository, profileRepository)
}
```

### MainScreen.kt

Add imports:
```kotlin
import com.swasthicare.mobile.ui.screens.hydration.HydrationScreen
import com.swasthicare.mobile.di.AppContainer
```

Update `HomeScreen(...)` call to add `onNavigateToHydration`:
```kotlin
HomeScreen(
    onNavigateToMedications = { navController.navigate("medications") },
    onNavigateToDiet = { navController.navigate("diet") },
    onNavigateToCycleTracker = { /* stub */ },
    onNavigateToHydration = { navController.navigate("hydration") }
)
```

Add new route inside `NavHost`:
```kotlin
composable("hydration") {
    val vm = remember { AppContainer.hydrationViewModel }
    HydrationScreen(
        viewModel = vm,
        onNavigateBack = { navController.popBackStack() },
        onNavigateToAI = {
            navController.navigate(MainTab.AI.route) {
                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                launchSingleTop = true
                restoreState = true
            }
        }
    )
}
```

### HomeScreen.kt

Add `onNavigateToHydration: () -> Unit = {}` parameter to `HomeScreen`.

Find the Hydration card's `.clickable { viewModel.incrementHydration() }` and change to:
```kotlin
.clickable { onNavigateToHydration() }
```

**Step: Commit all wiring**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeScreen.kt
git commit -m "feat(hydration): wire HydrationRepository, VM, navigation route, and home card tap"
```

---

## Task 7: Build verification

```bash
cd android && ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL` with 0 errors.

Common issues to check:
- `AppContainer` uses the hydrationViewModel as `remember { AppContainer.hydrationViewModel }` — confirm `AppContainer` is accessible in `MainScreen.kt` context (it already is for `dietViewModel`)
- `HydrationScreen.kt` imports `PremiumBackground` and `glass` from the `home` package — confirm import paths match
- `WaterGlassComposable` uses `quadraticBezierTo` — correct Compose Canvas API name

---

## Testing Checklist

- [ ] `./gradlew assembleDebug` — 0 errors
- [ ] Home screen hydration card taps → navigates to `HydrationScreen`
- [ ] Calendar strip shows today centered with 3 days on each side, cyan selection circle
- [ ] Water glass starts at 0%, animates to current progress on screen load
- [ ] Wave animation plays continuously inside glass shape
- [ ] Tap 250ml preset → entry appears in Today's Log, glass level rises
- [ ] Drink type pill → bottom sheet opens, select Coffee → preset buttons tint to coffee color
- [ ] Coffee entry shows "(X ml effective)" note in log entry
- [ ] Delete button removes entry from log and lowers glass level
- [ ] Custom amount field → enter 300 → Add → logged
- [ ] Caffeine warning appears after 3+ caffeinated drinks
- [ ] Insights card shows streak, avg, best day
- [ ] Select past date → log empties (no entries for past day)
- [ ] Ask AI button navigates to AI tab
- [ ] Kill/relaunch → entries persist from SharedPreferences
