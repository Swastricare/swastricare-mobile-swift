# Cycle Tracker Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Android cycle tracker with a 6-step period logging sheet, hero illustration, and fixed state management so that logged data persists and the calendar updates immediately.

**Architecture:** The existing MVVM stack is kept. `MenstrualCycleRepositoryImpl` gains a cached profile ID resolver. A new `LogPeriodSheet` composable (in `CycleSheets.kt`) replaces the simple date-picker button with a 6-step `AnimatedContent` bottom sheet. The ViewModel gets optimistic state updates after successful logs.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, Hilt, Supabase (postgrest), `coil-compose` for loading the PNG illustration asset.

---

## Task 1: Cache Profile ID in Repository

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt`

**Context:** `getProfileId()` was already changed to be `suspend` and query `health_profiles`. Now add a `@Volatile` cache so we don't hit the network on every local read.

**Step 1: Add cached field and update `getProfileId()`**

Replace the current `getProfileId()` body:

```kotlin
@Volatile private var cachedProfileId: String? = null

private suspend fun getProfileId(): String {
    cachedProfileId?.let { return it }
    return try {
        val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return ""
        val id = supabaseClient.from("health_profiles")
            .select { filter { eq("user_id", userId) } }
            .decodeSingleOrNull<HealthProfileIdRow>()?.id ?: ""
        if (id.isNotEmpty()) cachedProfileId = id
        id
    } catch (_: Exception) {
        ""
    }
}
```

Also add a `clearCache()` method for sign-out (call it from wherever sign-out happens if needed — for now just add it):

```kotlin
fun clearProfileIdCache() { cachedProfileId = null }
```

**Step 2: Build to verify no compile errors**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew compileDebugKotlin 2>&1 | tail -10
```
Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/repository/MenstrualCycleRepositoryImpl.kt
git commit -m "fix(android): cache health profile ID in cycle repository to avoid repeated network calls"
```

---

## Task 2: Optimistic State Update in ViewModel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/MenstrualCycleViewModel.kt`

**Context:** After `startPeriod()` or `logDailyData()` succeeds, the UI still shows the empty state because `isNotSetUp` isn't cleared until `loadData()` finishes fetching. We fix this with an optimistic update.

**Step 1: Update `startPeriod()` to optimistically clear `isNotSetUp`**

Find the `startPeriod()` function and update the success branch:

```kotlin
fun startPeriod(date: LocalDate) {
    viewModelScope.launch {
        when (cycleRepository.startCycle(date)) {
            is ResultWrapper.Success -> {
                analyticsService.trackCycleLogged("start")
                // Optimistically clear empty state so calendar shows immediately
                _uiState.value = _uiState.value.copy(isNotSetUp = false, isLoading = true)
                loadData()
            }
            is ResultWrapper.Error -> {
                _uiState.value = _uiState.value.copy(error = "Failed to start period")
            }
            is ResultWrapper.Loading -> { /* no-op */ }
        }
    }
}
```

**Step 2: Add `logPeriodWithDetails()` function to ViewModel**

This is called by the new 6-step sheet after the user completes all steps:

```kotlin
fun logPeriodWithDetails(
    startDate: LocalDate,
    flowLevel: com.swastricare.health.domain.model.menstrualcycle.FlowLevel,
    symptoms: List<com.swastricare.health.domain.model.menstrualcycle.Symptom>,
    mood: com.swastricare.health.domain.model.menstrualcycle.Mood?,
    painLevel: Int,
    notes: String?
) {
    viewModelScope.launch {
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)
        // 1. Start the cycle
        val cycleResult = cycleRepository.startCycle(startDate, notes)
        if (cycleResult is ResultWrapper.Error) {
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                error = "Failed to log period"
            )
            return@launch
        }
        // 2. Log daily data for the start date
        cycleRepository.logDailyData(
            date = startDate,
            flowLevel = flowLevel,
            symptoms = symptoms,
            mood = mood,
            notes = notes,
            painLevel = painLevel
        )
        analyticsService.trackCycleLogged("full_log")
        // 3. Optimistic clear + reload
        _uiState.value = _uiState.value.copy(isNotSetUp = false, isLoading = true)
        loadData()
    }
}
```

**Step 3: Build**

```bash
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew compileDebugKotlin 2>&1 | tail -10
```
Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/MenstrualCycleViewModel.kt
git commit -m "feat(android): add logPeriodWithDetails() and optimistic state clear in cycle ViewModel"
```

---

## Task 3: Build the LogPeriodSheet Composable

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/CycleSheets.kt`

**Context:** Add a new `LogPeriodSheet` composable at the bottom of `CycleSheets.kt`. It's a `ModalBottomSheet` with 6 steps animated via `AnimatedContent`. The illustration PNG is loaded with `coil-compose` `Image(painter = rememberAsyncImagePainter(...))`.

**Step 1: Add required imports at top of CycleSheets.kt**

```kotlin
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import coil.compose.rememberAsyncImagePainter
import coil.request.ImageRequest
import com.swastricare.health.domain.model.menstrualcycle.FlowLevel
import com.swastricare.health.domain.model.menstrualcycle.Mood
import com.swastricare.health.domain.model.menstrualcycle.Symptom
import java.time.Instant
import java.time.ZoneId
```

**Step 2: Add the LogPeriodSheet composable**

Add this at the end of `CycleSheets.kt`, before the closing of the file:

```kotlin
// ─────────────────────────────────────
// MARK: - LogPeriodSheet (6-step flow)
// ─────────────────────────────────────

private data class LogPeriodData(
    val startDate: LocalDate = LocalDate.now(),
    val flowLevel: FlowLevel = FlowLevel.MEDIUM,
    val symptoms: Set<Symptom> = emptySet(),
    val mood: Mood? = null,
    val painLevel: Int = 0,
    val notes: String = ""
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
internal fun LogPeriodSheet(
    onDismiss: () -> Unit,
    onConfirm: (
        startDate: LocalDate,
        flowLevel: FlowLevel,
        symptoms: List<Symptom>,
        mood: Mood?,
        painLevel: Int,
        notes: String?
    ) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var step by remember { mutableIntStateOf(0) }
    var data by remember { mutableStateOf(LogPeriodData()) }
    val totalSteps = 6

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.surface,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
        ) {
            // ── Illustration header ──
            val context = LocalContext.current
            Image(
                painter = rememberAsyncImagePainter(
                    ImageRequest.Builder(context)
                        .data("file:///android_asset/illustrations/cycle illustration.png")
                        .build()
                ),
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(130.dp),
                contentScale = ContentScale.Crop
            )

            // ── Step dots ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(totalSteps) { index ->
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .size(if (index == step) 10.dp else 7.dp)
                            .background(
                                if (index <= step) CyclePink else CyclePink.copy(alpha = 0.25f),
                                CircleShape
                            )
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // ── Animated step content ──
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    if (targetState > initialState) {
                        slideInHorizontally { it } togetherWith slideOutHorizontally { -it }
                    } else {
                        slideInHorizontally { -it } togetherWith slideOutHorizontally { it }
                    }
                },
                label = "LogStep"
            ) { currentStep ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 340.dp)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 24.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    when (currentStep) {
                        0 -> StepDate(data.startDate) { data = data.copy(startDate = it) }
                        1 -> StepFlow(data.flowLevel) { data = data.copy(flowLevel = it) }
                        2 -> StepSymptoms(data.symptoms) { data = data.copy(symptoms = it) }
                        3 -> StepMood(data.mood) { data = data.copy(mood = it) }
                        4 -> StepPain(data.painLevel) { data = data.copy(painLevel = it) }
                        5 -> StepNotes(data.notes, data) { data = data.copy(notes = it) }
                    }
                }
            }

            // ── Navigation buttons ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (step > 0) {
                    OutlinedButton(
                        onClick = { step-- },
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = CyclePink),
                        border = BorderStroke(1.dp, CyclePink),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.ArrowBack, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Back")
                    }
                } else {
                    Spacer(Modifier.weight(1f))
                }

                if (step < totalSteps - 1) {
                    Button(
                        onClick = { step++ },
                        colors = ButtonDefaults.buttonColors(containerColor = CyclePink),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Next")
                        Spacer(Modifier.width(4.dp))
                        Icon(Icons.Default.ArrowForward, null, modifier = Modifier.size(16.dp))
                    }
                } else {
                    Button(
                        onClick = {
                            onConfirm(
                                data.startDate,
                                data.flowLevel,
                                data.symptoms.toList(),
                                data.mood,
                                data.painLevel,
                                data.notes.ifBlank { null }
                            )
                            onDismiss()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = CyclePink),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(0.6f)
                    ) {
                        Text("Log Period", fontWeight = FontWeight.Bold)
                    }
                }
            }

            Spacer(Modifier.height(8.dp))
        }
    }
}

// ── Step 1: Date ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StepDate(selected: LocalDate, onChange: (LocalDate) -> Unit) {
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = selected.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
    )
    LaunchedEffect(datePickerState.selectedDateMillis) {
        datePickerState.selectedDateMillis?.let { millis ->
            val date = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
            onChange(date)
        }
    }
    Text("When did it start?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    DatePicker(
        state = datePickerState,
        colors = DatePickerDefaults.colors(
            selectedDayContainerColor = CyclePink,
            todayDateBorderColor = CyclePink
        )
    )
}

// ── Step 2: Flow Level ──
@Composable
private fun StepFlow(selected: FlowLevel, onChange: (FlowLevel) -> Unit) {
    val levels = listOf(
        FlowLevel.NONE to ("💧" to "None"),
        FlowLevel.LIGHT to ("🩸" to "Light"),
        FlowLevel.MEDIUM to ("🩸🩸" to "Medium"),
        FlowLevel.HEAVY to ("🩸🩸🩸" to "Heavy"),
        FlowLevel.VERY_HEAVY to ("🩸🩸🩸🩸" to "Very Heavy")
    )
    Text("How heavy is the flow?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        levels.forEach { (level, display) ->
            val (emoji, label) = display
            val isSelected = selected == level
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (isSelected) CyclePink.copy(alpha = 0.12f) else AppColors.surfaceVariant.copy(alpha = 0.5f))
                    .border(
                        width = if (isSelected) 1.5.dp else 0.dp,
                        color = if (isSelected) CyclePink else Color.Transparent,
                        shape = RoundedCornerShape(14.dp)
                    )
                    .clickable { onChange(level) }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(emoji, fontSize = 22.sp)
                Text(
                    label,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                    color = if (isSelected) CyclePink else AppColors.onSurface
                )
                if (isSelected) {
                    Spacer(Modifier.weight(1f))
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .background(CyclePink, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("✓", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

// ── Step 3: Symptoms ──
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun StepSymptoms(selected: Set<Symptom>, onChange: (Set<Symptom>) -> Unit) {
    val allSymptoms = listOf(
        Symptom.CRAMPS to "🤕 Cramps",
        Symptom.BLOATING to "🫧 Bloating",
        Symptom.FATIGUE to "😴 Fatigue",
        Symptom.MOOD_SWINGS to "🌊 Mood Swings",
        Symptom.HEADACHE to "🤯 Headache",
        Symptom.BACKACHE to "🔙 Backache",
        Symptom.NAUSEA to "🤢 Nausea",
        Symptom.ACNE to "😤 Acne",
        Symptom.INSOMNIA to "🌙 Insomnia",
        Symptom.CRAVINGS to "🍫 Cravings",
        Symptom.BREAST_TENDERNESS to "💗 Tenderness",
        Symptom.SPOTTING to "🩹 Spotting",
        Symptom.ANXIETY to "😰 Anxiety",
        Symptom.IRRITABILITY to "😠 Irritability"
    )
    Text("Any symptoms?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Text("Select all that apply", style = MaterialTheme.typography.bodySmall, color = AppColors.onSurfaceVariant)
    Spacer(Modifier.height(8.dp))
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        allSymptoms.forEach { (symptom, label) ->
            val isSelected = symptom in selected
            FilterChip(
                selected = isSelected,
                onClick = {
                    onChange(if (isSelected) selected - symptom else selected + symptom)
                },
                label = { Text(label, style = MaterialTheme.typography.bodySmall) },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = CyclePink.copy(alpha = 0.15f),
                    selectedLabelColor = CyclePink
                ),
                border = FilterChipDefaults.filterChipBorder(
                    enabled = true,
                    selected = isSelected,
                    selectedBorderColor = CyclePink,
                    selectedBorderWidth = 1.5.dp
                )
            )
        }
    }
}

// ── Step 4: Mood ──
@Composable
private fun StepMood(selected: Mood?, onChange: (Mood?) -> Unit) {
    val moods = listOf(
        Mood.HAPPY to ("😊" to "Happy"),
        Mood.CALM to ("😌" to "Calm"),
        Mood.ENERGETIC to ("⚡" to "Energetic"),
        Mood.ANXIOUS to ("😰" to "Anxious"),
        Mood.SAD to ("😢" to "Sad"),
        Mood.IRRITABLE to ("😤" to "Irritable"),
        Mood.TIRED to ("😴" to "Tired"),
        Mood.NEUTRAL to ("😐" to "Neutral")
    )
    Text("How's your mood?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    val chunked = moods.chunked(4)
    chunked.forEach { row ->
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            row.forEach { (mood, display) ->
                val (emoji, label) = display
                val isSelected = selected == mood
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (isSelected) CyclePink.copy(alpha = 0.12f) else AppColors.surfaceVariant.copy(alpha = 0.4f))
                        .border(
                            width = if (isSelected) 1.5.dp else 0.dp,
                            color = if (isSelected) CyclePink else Color.Transparent,
                            shape = RoundedCornerShape(14.dp)
                        )
                        .clickable { onChange(if (isSelected) null else mood) }
                        .padding(vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(emoji, fontSize = 28.sp)
                    Text(
                        label,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) CyclePink else AppColors.onSurfaceVariant,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

// ── Step 5: Pain Level ──
@Composable
private fun StepPain(level: Int, onChange: (Int) -> Unit) {
    val emoji = when {
        level == 0 -> "😊"
        level <= 2 -> "🙂"
        level <= 4 -> "😐"
        level <= 6 -> "😟"
        level <= 8 -> "😣"
        else -> "😭"
    }
    Text("Pain level?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(16.dp))
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(emoji, fontSize = 56.sp)
            Text(
                "$level / 10",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = when {
                    level <= 3 -> Color(0xFF4CAF50)
                    level <= 6 -> Color(0xFFFF9800)
                    else -> CyclePink
                }
            )
            Text(
                when {
                    level == 0 -> "No pain"
                    level <= 2 -> "Mild"
                    level <= 4 -> "Moderate"
                    level <= 6 -> "Uncomfortable"
                    level <= 8 -> "Severe"
                    else -> "Unbearable"
                },
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
        }
    }
    Spacer(Modifier.height(16.dp))
    Slider(
        value = level.toFloat(),
        onValueChange = { onChange(it.toInt()) },
        valueRange = 0f..10f,
        steps = 9,
        colors = SliderDefaults.colors(
            thumbColor = CyclePink,
            activeTrackColor = CyclePink,
            inactiveTrackColor = CyclePink.copy(alpha = 0.2f)
        )
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text("0", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
        Text("10", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
    }
}

// ── Step 6: Notes + Summary ──
@Composable
private fun StepNotes(notes: String, data: LogPeriodData, onChange: (String) -> Unit) {
    Text("Anything else?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    OutlinedTextField(
        value = notes,
        onValueChange = onChange,
        modifier = Modifier.fillMaxWidth(),
        placeholder = { Text("Optional notes...", color = AppColors.onSurfaceVariant) },
        minLines = 3,
        maxLines = 5,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = CyclePink,
            cursorColor = CyclePink
        ),
        shape = RoundedCornerShape(12.dp)
    )
    Spacer(Modifier.height(8.dp))
    // Summary card
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text("Summary", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, color = CyclePink)
        SummaryRow("📅 Start", data.startDate.toString())
        SummaryRow("🩸 Flow", data.flowLevel.name.lowercase().replaceFirstChar { it.uppercase() })
        if (data.symptoms.isNotEmpty()) {
            SummaryRow("🤕 Symptoms", "${data.symptoms.size} selected")
        }
        data.mood?.let { SummaryRow("😊 Mood", it.name.lowercase().replaceFirstChar { it.uppercase() }) }
        SummaryRow("💊 Pain", "${data.painLevel}/10")
    }
}

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium, color = AppColors.onSurface)
    }
}
```

**Step 3: Build**

```bash
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew compileDebugKotlin 2>&1 | tail -15
```
Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/CycleSheets.kt
git commit -m "feat(android): add 6-step LogPeriodSheet with flow, symptoms, mood, pain, notes"
```

---

## Task 4: Wire LogPeriodSheet into Main Screen + UI Polish

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/MenstrualCycleScreen.kt`

**Context:** Replace the inline `CycleOnboardingContent` date-picker button with `LogPeriodSheet`. Add a FAB on the main screen for re-logging. Replace the emoji box with the hero illustration. Polish the calendar month header.

**Step 1: Update `MenstrualCycleScreen()` — add state + sheet wiring**

At the top of `MenstrualCycleScreen`, add a new state var:

```kotlin
var showLogPeriodSheet by remember { mutableStateOf(false) }
```

Remove `showStatisticsSheet` and `showSettingsSheet` are already there — just add this one.

**Step 2: Add FAB to the Box wrapping the Column**

Inside the outer `Box(modifier = Modifier.fillMaxSize())`, add a FAB aligned to the bottom-right, shown only when the cycle is set up:

```kotlin
// FAB — shown only on the main cycle view (not during loading or empty state)
if (!uiState.isLoading && !uiState.isNotSetUp) {
    FloatingActionButton(
        onClick = { showLogPeriodSheet = true },
        modifier = Modifier
            .align(Alignment.BottomEnd)
            .padding(end = 24.dp, bottom = 100.dp),
        containerColor = CyclePink,
        contentColor = Color.White,
        shape = CircleShape
    ) {
        Icon(Icons.Default.Add, contentDescription = "Log period")
    }
}
```

**Step 3: Replace `CycleOnboardingContent` onboarding button**

In `CycleOnboardingContent`, the "Log Your Period" button currently shows a `DatePickerDialog` inline. Change `onClick` to call the passed-in callback which triggers `showLogPeriodSheet = true`.

Change the composable signature from:
```kotlin
private fun CycleOnboardingContent(onStartPeriod: (LocalDate) -> Unit)
```
To:
```kotlin
private fun CycleOnboardingContent(onLogPeriod: () -> Unit)
```

Remove the `showDatePicker` state and `DatePickerDialog` from `CycleOnboardingContent`.

Change button's onClick:
```kotlin
Button(
    onClick = onLogPeriod,
    ...
)
```

Update the call site in `MenstrualCycleScreen`:
```kotlin
CycleOnboardingContent(onLogPeriod = { showLogPeriodSheet = true })
```

**Step 4: Replace emoji box with illustration in `CycleOnboardingContent`**

Replace:
```kotlin
Box(
    modifier = Modifier
        .size(100.dp)
        .background(...)
        ...
) {
    Text(text = "\uD83C\uDF38", fontSize = 48.sp)
}
```

With:
```kotlin
val context = LocalContext.current
Image(
    painter = rememberAsyncImagePainter(
        ImageRequest.Builder(context)
            .data("file:///android_asset/illustrations/cycle illustration.png")
            .build()
    ),
    contentDescription = null,
    modifier = Modifier
        .fillMaxWidth()
        .height(220.dp)
        .clip(RoundedCornerShape(20.dp)),
    contentScale = ContentScale.Crop
)
```

**Step 5: Wire LogPeriodSheet at the bottom of MenstrualCycleScreen**

Below the existing bottom sheet conditionals, add:

```kotlin
if (showLogPeriodSheet) {
    LogPeriodSheet(
        onDismiss = { showLogPeriodSheet = false },
        onConfirm = { date, flow, symptoms, mood, painLevel, notes ->
            viewModel.logPeriodWithDetails(date, flow, symptoms, mood, painLevel, notes)
        }
    )
}
```

**Step 6: Polish — calendar month header**

In `CycleCalendar`, change the month/year Text style from `titleMedium` to `titleLarge`:

```kotlin
Text(
    text = "${selectedMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${selectedMonth.year}",
    style = MaterialTheme.typography.titleLarge,  // was titleMedium
    fontWeight = FontWeight.Bold
)
```

**Step 7: Add required imports to MenstrualCycleScreen.kt**

```kotlin
import androidx.compose.material3.FloatingActionButton
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import coil.compose.rememberAsyncImagePainter
import coil.request.ImageRequest
```

**Step 8: Build**

```bash
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -15
```
Expected: `BUILD SUCCESSFUL`

**Step 9: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/screens/menstrualcycle/MenstrualCycleScreen.kt
git commit -m "feat(android): wire LogPeriodSheet, add FAB, replace emoji with hero illustration"
```

---

## Task 5: Install and Verify

**Step 1: Install on device**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew installDebug 2>&1 | tail -10
```
Expected: `Installed on 1 device.`

**Step 2: Manual verification checklist**

- [ ] Empty state shows the illustration (not an emoji)
- [ ] "Log Your Period" button opens the 6-step bottom sheet
- [ ] Step 1: Date picker works, pre-selects today
- [ ] Step 2: Flow level rows are selectable, highlight pink when selected
- [ ] Step 3: Symptom chips multi-select works
- [ ] Step 4: Mood grid selects / deselects on tap
- [ ] Step 5: Pain slider moves, emoji and label update
- [ ] Step 6: Notes field + summary card shows all selections, "Log Period" button submits
- [ ] After submitting: calendar shows logged dates immediately (no blank screen)
- [ ] FAB "+" appears on main screen when cycle is set up
- [ ] Tapping FAB opens the log sheet again
- [ ] Navigate away and back — data is preserved

**Step 3: Commit final build confirmation**

```bash
git add -A
git commit -m "feat(android): complete cycle tracker redesign with 6-step log flow, illustration, state fix"
```
