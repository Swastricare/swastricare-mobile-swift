# P1 Feature Parity Gaps — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close 7 confirmed feature gaps between Android and iOS for production parity.

**Architecture:** Each gap is an independent task touching 1-3 files. Tasks follow the existing MVVM + Protocol-Oriented DI pattern — services are protocol-typed singletons in `AppContainer`, ViewModels are `lazy val` properties. All Supabase operations use `io.github.jan.supabase` SDK (v2.6.0, already in deps).

**Tech Stack:** Kotlin, Jetpack Compose, Supabase Kotlin SDK (Postgrest + Storage), CameraX, Android ForegroundService

---

## Task 1: SupabaseVaultRepository

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/SupabaseVaultRepository.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt:175-177`

**Step 1: Create SupabaseVaultRepository**

Create the file implementing `VaultRepository` interface. Mirror the iOS `SupabaseManager.swift` vault operations. Table: `medical_documents`, bucket: `medical-vault`.

```kotlin
package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.DocumentMetadata
import com.swasthicare.mobile.data.model.MedicalDocument
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

class SupabaseVaultRepository(
    private val supabaseClient: SupabaseClient
) : VaultRepository {

    companion object {
        private const val TABLE = "medical_documents"
        private const val BUCKET = "medical-vault"
    }

    private fun currentUserId(): String =
        supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("User not authenticated")

    override suspend fun getDocuments(): List<MedicalDocument> = withContext(Dispatchers.IO) {
        supabaseClient.from(TABLE).select {
            filter { eq("user_id", currentUserId()) }
            order("uploaded_at", io.github.jan.supabase.postgrest.query.Order.DESCENDING)
        }.decodeList<MedicalDocument>()
    }

    override suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ): MedicalDocument = withContext(Dispatchers.IO) {
        val userId = currentUserId()
        val storagePath = "$userId/${UUID.randomUUID()}_$fileName"
        val fileType = fileName.substringAfterLast('.', "dat")

        // 1. Upload to Storage bucket
        supabaseClient.storage.from(BUCKET).upload(storagePath, fileData) {
            upsert = false
        }

        // 2. Insert DB record
        val now = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        val doc = MedicalDocument(
            userId = userId,
            title = metadata.name.ifEmpty { fileName },
            fileType = fileType,
            category = category,
            fileUrl = storagePath,
            fileSize = fileData.size.toLong(),
            createdAt = now,
            uploadedAt = now,
            documentDate = metadata.documentDate,
            description = metadata.description,
            folderName = metadata.folderName,
            reminderDate = metadata.reminderDate,
            appointmentDate = metadata.appointmentDate,
            doctorName = metadata.doctorName,
            location = metadata.location,
            tags = metadata.tags
        )

        try {
            supabaseClient.from(TABLE).insert(doc) {
                select()
            }.decodeSingle<MedicalDocument>()
        } catch (e: Exception) {
            // Rollback storage on DB failure
            try { supabaseClient.storage.from(BUCKET).delete(storagePath) } catch (_: Exception) {}
            throw e
        }
    }

    override suspend fun deleteDocument(documentId: String) = withContext(Dispatchers.IO) {
        val userId = currentUserId()
        // Get the file URL first for storage deletion
        val doc = supabaseClient.from(TABLE).select {
            filter {
                eq("id", documentId)
                eq("user_id", userId)
            }
        }.decodeSingleOrNull<MedicalDocument>()

        if (doc != null) {
            // Delete from storage
            try { supabaseClient.storage.from(BUCKET).delete(doc.fileUrl) } catch (_: Exception) {}
            // Delete DB record
            supabaseClient.from(TABLE).delete {
                filter {
                    eq("id", documentId)
                    eq("user_id", userId)
                }
            }
        }
    }

    override suspend fun getSignedUrl(path: String): String = withContext(Dispatchers.IO) {
        supabaseClient.storage.from(BUCKET)
            .createSignedUrl(path, expiresIn = 3600)
    }

    override suspend fun updateDocument(
        documentId: String,
        title: String,
        category: String,
        notes: String?,
        tags: List<String>
    ): MedicalDocument = withContext(Dispatchers.IO) {
        val userId = currentUserId()
        @kotlinx.serialization.Serializable
        data class UpdatePayload(
            val title: String,
            val category: String,
            val notes: String?,
            val tags: List<String>,
            @kotlinx.serialization.SerialName("updated_at")
            val updatedAt: String
        )

        val payload = UpdatePayload(
            title = title,
            category = category,
            notes = notes,
            tags = tags,
            updatedAt = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        )

        supabaseClient.from(TABLE).update(payload) {
            filter {
                eq("id", documentId)
                eq("user_id", userId)
            }
            select()
        }.decodeSingle<MedicalDocument>()
    }
}
```

**Step 2: Swap MockVaultRepository for SupabaseVaultRepository in AppContainer**

In `AppContainer.kt`, change lines 175-177:

```kotlin
// BEFORE:
val vaultRepository: VaultRepository by lazy {
    MockVaultRepository()
}

// AFTER:
val vaultRepository: VaultRepository by lazy {
    SupabaseVaultRepository(supabaseClient)
}
```

**Step 3: Build and verify**

Run: `cd android && ./gradlew assembleDebug`
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/SupabaseVaultRepository.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): add SupabaseVaultRepository replacing mock implementation

Wire VaultRepository to real Supabase Storage (medical-vault bucket) and
Postgrest (medical_documents table) with upload rollback on failure."
```

---

## Task 2: Wire HeartRateViewModel to Real PPG Services

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt:226-229`

**Context:** `HeartRateDetector.kt` and `PPGSignalProcessor.kt` already exist as fully implemented services with CameraX integration, signal processing, peak detection, and BPM calculation. The problem is `HeartRateViewModel` uses a fake random-number simulation loop instead of calling these services.

**Step 1: Rewrite HeartRateViewModel to use HeartRateDetector**

Replace the entire `HeartRateViewModel.kt` with a version that:
- Accepts `Context` and `SharedPreferences` as dependencies
- Creates `HeartRateDetector` internally
- Collects its `StateFlow`s (`measurementState`, `currentBPM`, `signalQuality`, `progress`, `waveformData`, `phase`)
- Maps detector states to the existing `HeartRateUiState` shape so the UI doesn't need major changes
- Stores `PreviewView` reference for camera binding
- On `startMeasurement()`: calls `detector.startMeasurement(previewView, lifecycleOwner)`
- On measurement complete (RESULT state): calls `detector.getResult()`, saves to SharedPreferences
- Keeps existing `getReadings()`, `saveReading()`, `clearReadings()` persistence code

Key changes to `HeartRateUiState`:
- Add `signalQuality: SignalQuality = SignalQuality.POOR`
- Add `phase: MeasurementPhase = MeasurementPhase.PREPARING`
- Add `waveformData: List<Float> = emptyList()`
- Add `measurementState: MeasurementState = MeasurementState.IDLE`

```kotlin
package com.swasthicare.mobile.ui.screens.heartrate

import android.content.Context
import android.content.SharedPreferences
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.services.*
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────

@Serializable
data class HeartRateReading(
    val bpm: Int,
    val timestamp: String,
    val source: String,
    val confidence: Float = 0.9f
)

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class HeartRateUiState(
    val measurementState: MeasurementState = MeasurementState.IDLE,
    val measurementProgress: Float = 0f,
    val currentBpm: Int = 0,
    val lastBpm: Int = 0,
    val confidence: Float = 0.95f,
    val source: String = "Camera",
    val signalQuality: SignalQuality = SignalQuality.POOR,
    val phase: MeasurementPhase = MeasurementPhase.PREPARING,
    val waveformData: List<Float> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    // Convenience for existing UI code
    val isMeasuring: Boolean get() = measurementState in listOf(
        MeasurementState.PREPARING, MeasurementState.CALIBRATING,
        MeasurementState.MEASURING, MeasurementState.COMPLETING
    )
    val showResult: Boolean get() = measurementState == MeasurementState.RESULT
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

class HeartRateViewModel(
    private val context: Context = AppContainer.context,
    private val prefs: SharedPreferences = AppContainer.sharedPreferences
) : ViewModel() {

    private val detector = HeartRateDetector(context)

    private val _uiState = MutableStateFlow(HeartRateUiState())
    val uiState: StateFlow<HeartRateUiState> = _uiState.asStateFlow()

    private val json = Json { ignoreUnknownKeys = true }

    companion object {
        private const val PREF_KEY_READINGS = "heart_rate_readings"
    }

    init {
        loadLastReading()
        collectDetectorState()
    }

    private fun collectDetectorState() {
        viewModelScope.launch {
            detector.measurementState.collect { state ->
                _uiState.value = _uiState.value.copy(measurementState = state)
                if (state == MeasurementState.RESULT) {
                    handleMeasurementComplete()
                }
            }
        }
        viewModelScope.launch {
            detector.currentBPM.collect { bpm ->
                _uiState.value = _uiState.value.copy(currentBpm = bpm)
            }
        }
        viewModelScope.launch {
            detector.signalQuality.collect { quality ->
                _uiState.value = _uiState.value.copy(signalQuality = quality)
            }
        }
        viewModelScope.launch {
            detector.progress.collect { progress ->
                _uiState.value = _uiState.value.copy(measurementProgress = progress)
            }
        }
        viewModelScope.launch {
            detector.phase.collect { phase ->
                _uiState.value = _uiState.value.copy(phase = phase)
            }
        }
        viewModelScope.launch {
            detector.waveformData.collect { data ->
                _uiState.value = _uiState.value.copy(waveformData = data)
            }
        }
    }

    fun startMeasurement(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        detector.startMeasurement(previewView, lifecycleOwner)
    }

    fun cancelMeasurement() {
        detector.stopMeasurement()
        _uiState.value = _uiState.value.copy(
            measurementState = MeasurementState.IDLE,
            measurementProgress = 0f,
            currentBpm = 0
        )
    }

    private fun handleMeasurementComplete() {
        val result = detector.getResult() ?: return
        saveReading(
            HeartRateReading(
                bpm = result.bpm,
                timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                source = "Camera",
                confidence = result.confidence
            )
        )
        _uiState.value = _uiState.value.copy(
            lastBpm = result.bpm,
            confidence = result.confidence,
            source = "Camera"
        )
    }

    private fun loadLastReading() {
        val readings = getReadings()
        val lastReading = readings.lastOrNull()
        if (lastReading != null) {
            _uiState.value = _uiState.value.copy(
                lastBpm = lastReading.bpm,
                confidence = lastReading.confidence,
                source = lastReading.source
            )
        }
    }

    // ── Persistence ──

    fun getReadings(): List<HeartRateReading> {
        val raw = prefs.getString(PREF_KEY_READINGS, null) ?: return emptyList()
        return try {
            json.decodeFromString<List<HeartRateReading>>(raw)
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveReading(reading: HeartRateReading) {
        val readings = getReadings().toMutableList()
        readings.add(reading)
        val trimmed = if (readings.size > 500) readings.takeLast(500) else readings
        prefs.edit().putString(PREF_KEY_READINGS, json.encodeToString(trimmed)).apply()
    }

    fun clearReadings() {
        prefs.edit().remove(PREF_KEY_READINGS).apply()
        _uiState.value = _uiState.value.copy(lastBpm = 0)
    }

    override fun onCleared() {
        super.onCleared()
        detector.stopMeasurement()
    }
}
```

**Step 2: Update HeartRateScreen to pass PreviewView and LifecycleOwner**

The `HeartRateScreen.kt` currently calls `viewModel.startMeasurement()` with no args. Update:
- Add a CameraX `PreviewView` in the measuring view (hidden, finger-over-lens style — no visible preview needed)
- Pass `previewView` and `lifecycleOwner` to `viewModel.startMeasurement()`
- Show signal quality indicator and phase text from the new state fields
- Display real waveform data instead of a placeholder

Changes to `HeartRateScreen`:
- Create `PreviewView` using `AndroidView` in `HeartRateMeasuringView`
- Get `lifecycleOwner` via `LocalLifecycleOwner.current`
- The PreviewView can be 1x1dp (invisible) since user places finger over camera

Changes to `HeartRateIdleView`:
- `onStartMeasurement` callback must accept no args (PreviewView created in MeasuringView)

Changes to `HeartRateMeasuringView`:
- Add `phase` and `signalQuality` display
- Add real waveform rendering from `uiState.waveformData`

**Step 3: Update AppContainer to pass context**

In `AppContainer.kt` line 228:
```kotlin
// BEFORE:
val heartRateViewModel: HeartRateViewModel by lazy {
    HeartRateViewModel(sharedPreferences)
}

// AFTER:
val heartRateViewModel: HeartRateViewModel by lazy {
    HeartRateViewModel(context, sharedPreferences)
}
```

**Step 4: Build and verify**

Run: `cd android && ./gradlew assembleDebug`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateViewModel.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateScreen.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): wire HeartRateViewModel to real CameraX PPG measurement

Replace simulated random-number loop with actual HeartRateDetector and
PPGSignalProcessor services. Add CameraX PreviewView, signal quality
indicator, phase display, and real-time waveform data."
```

---

## Task 3: Heart Rate Supabase Sync

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateViewModel.kt`

**Context:** Heart rate readings are stored only in SharedPreferences. There is no dedicated `heart_rate_readings` Supabase table, but `health_metrics` has `heart_rate`, `heart_rate_variability`, `resting_heart_rate` columns. Camera readings should sync to `health_metrics`.

**Step 1: Add Supabase sync after saving reading**

Add a method `syncReadingToCloud(reading: HeartRateReading)` that:
- Gets the user's `health_profile_id` from `ProfileRepository`
- Upserts into `health_metrics` table with `heart_rate = reading.bpm`, `date = today`
- Fails silently (fire-and-forget) — SharedPreferences is the primary store

```kotlin
// Add to HeartRateViewModel constructor:
private val supabaseClient: SupabaseClient = AppContainer.supabaseClient,
private val profileRepository: ProfileRepository = AppContainer.profileRepository

// Add method:
private fun syncReadingToCloud(reading: HeartRateReading) {
    viewModelScope.launch(Dispatchers.IO) {
        try {
            val profile = profileRepository.getProfile() ?: return@launch
            val profileId = profile.id ?: return@launch

            @kotlinx.serialization.Serializable
            data class HealthMetricUpsert(
                @kotlinx.serialization.SerialName("health_profile_id")
                val healthProfileId: String,
                @kotlinx.serialization.SerialName("heart_rate")
                val heartRate: Int,
                val date: String,
                val source: String
            )

            supabaseClient.from("health_metrics").upsert(
                HealthMetricUpsert(
                    healthProfileId = profileId,
                    heartRate = reading.bpm,
                    date = java.time.LocalDate.now().toString(),
                    source = "camera_ppg"
                )
            )
        } catch (_: Exception) {
            // Silent failure — local persistence is primary
        }
    }
}
```

Call `syncReadingToCloud(reading)` after `saveReading(reading)` in `handleMeasurementComplete()`.

**Step 2: Build and verify**

Run: `cd android && ./gradlew assembleDebug`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateViewModel.kt
git commit -m "feat(android): sync heart rate readings to Supabase health_metrics

Fire-and-forget upsert of camera PPG readings to health_metrics table.
SharedPreferences remains primary store for offline access."
```

---

## Task 4: ActivityDetailScreen Supabase Fetch

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/ActivityDetailScreen.kt:87-91`

**Step 1: Replace sample fallback with Supabase fetch**

Change the data loading block from:
```kotlin
val workout = remember {
    val activities = AppContainer.runActivityRepository.loadLocalActivities()
    activities.find { it.id == workoutId }?.toWorkoutDetail() ?: generateSampleWorkout(workoutId)
}
```

To a coroutine-based loader:
```kotlin
var workout by remember { mutableStateOf<WorkoutDetail?>(null) }
var isLoading by remember { mutableStateOf(true) }

LaunchedEffect(workoutId) {
    // Try local first
    val local = AppContainer.runActivityRepository.loadLocalActivities()
        .find { it.id == workoutId }?.toWorkoutDetail()
    if (local != null) {
        workout = local
        isLoading = false
        return@LaunchedEffect
    }

    // Try Supabase
    try {
        val profileId = AppContainer.profileRepository.getProfile()?.id
        if (profileId != null) {
            val cloudResult = AppContainer.runActivityRepository
                .fetchActivitiesFromCloud(profileId)
            cloudResult.getOrNull()
                ?.find { it.id == workoutId }
                ?.toWorkoutDetail()
                ?.let { workout = it }
        }
    } catch (_: Exception) { }
    isLoading = false
}
```

If both local and cloud miss, show an empty state instead of fake data.

**Step 2: Add loading and empty state UI**

Wrap the existing content in a `when` block:
```kotlin
when {
    isLoading -> {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = PremiumColor.primary)
        }
    }
    workout == null -> {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.SearchOff, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(16.dp))
                Text("Workout not found", style = MaterialTheme.typography.titleMedium)
            }
        }
    }
    else -> { /* existing workout detail UI, using workout!! or workout as non-null */ }
}
```

**Step 3: Remove generateSampleWorkout()**

Delete the `generateSampleWorkout()` function (approx lines 1348-1402) entirely. It generates fake data that should never be shown to users.

**Step 4: Build and verify**

Run: `cd android && ./gradlew assembleDebug`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/ActivityDetailScreen.kt
git commit -m "fix(android): fetch ActivityDetail from Supabase, remove fake sample data

Replace generateSampleWorkout() fallback with real Supabase fetch.
Show empty state when workout not found locally or in cloud."
```

---

## Task 5: Urine Color Guide Enhancement

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationComponents.kt:533-613`

**Step 1: Add interactive selection and "Log Now" action**

Update `UrineColorGuideSheet` to:
- Accept `onLogWater: (Int) -> Unit` callback
- Add `selectedLevel` state
- Make each color swatch row tappable (`clickable`)
- When selected, show expanded detail with a "Log 250ml Water" button
- Button calls `onLogWater(250)` and `onDismiss()`

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UrineColorGuideSheet(
    onDismiss: () -> Unit,
    onLogWater: (Int) -> Unit = {}
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedLevel by remember { mutableStateOf<Int?>(null) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                "Urine Color Guide",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            Text(
                "Tap a color to check your hydration level",
                fontSize = 14.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.padding(bottom = 12.dp)
            )

            UrineColorLevel.guide.forEach { level ->
                val isSelected = selectedLevel == level.level
                Column {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                if (isSelected)
                                    MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
                                else
                                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                            )
                            .clickable { selectedLevel = if (isSelected) null else level.level }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(level.colorHex))
                                .then(
                                    if (isSelected) Modifier.border(
                                        2.dp, MaterialTheme.colorScheme.primary,
                                        RoundedCornerShape(8.dp)
                                    ) else Modifier
                                )
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(level.name, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                            Text(
                                level.status, fontSize = 12.sp, fontWeight = FontWeight.Medium,
                                color = when {
                                    level.level <= 2 -> Color(0xFF34C759)
                                    level.level <= 4 -> Color(0xFFFF9500)
                                    else -> Color(0xFFFF3B30)
                                }
                            )
                            Text(
                                level.recommendation, fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                maxLines = if (isSelected) Int.MAX_VALUE else 2,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    // "Log Water" action when selected and dehydration level > 2
                    if (isSelected && level.level > 2) {
                        Button(
                            onClick = {
                                onLogWater(250)
                                onDismiss()
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 4.dp, start = 52.dp, end = 0.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF00C7BE)
                            ),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("Log 250ml Water")
                        }
                    }
                }
            }
        }
    }
}
```

**Step 2: Update HydrationScreen to pass onLogWater**

In `HydrationScreen.kt`, where `UrineColorGuideSheet` is shown, pass the callback:

```kotlin
UrineColorGuideSheet(
    onDismiss = { showUrineGuide = false },
    onLogWater = { amount -> viewModel.addDrink(DrinkType.WATER, amount) }
)
```

**Step 3: Build and verify**

Run: `cd android && ./gradlew assembleDebug`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationComponents.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationScreen.kt
git commit -m "feat(android): make urine color guide interactive with Log Water action

Add tappable color selection and 'Log 250ml Water' button for levels
indicating dehydration, matching iOS interactive behavior."
```

---

## Task 6: Drinking Pattern Learner

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/DrinkingPatternService.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationViewModel.kt` (minimal — call service on addDrink)

**Step 1: Create DrinkingPatternService**

Heuristic pattern detection (not ML). Analyzes timestamps of hydration entries over last 14 days to find natural drinking time clusters. Returns suggested reminder times.

```kotlin
package com.swasthicare.mobile.data.services

import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalTime
import kotlin.math.abs

@Serializable
data class DrinkingPattern(
    val clusterTimes: List<String>,      // ISO times like "08:30", "12:15", "18:00"
    val gapMinutes: List<Int>,           // minutes between clusters
    val longestGapStartHour: Int,        // hour where user goes longest without drinking
    val totalDataDays: Int,
    val updatedAt: String
)

class DrinkingPatternService(
    private val prefs: SharedPreferences
) {
    companion object {
        private const val PREF_KEY = "drinking_pattern"
        private const val MIN_ENTRIES_FOR_PATTERN = 20
        private const val CLUSTER_THRESHOLD_MINUTES = 60 // times within 60min = same cluster
    }

    private val json = Json { ignoreUnknownKeys = true }

    fun getPattern(): DrinkingPattern? {
        val raw = prefs.getString(PREF_KEY, null) ?: return null
        return try { json.decodeFromString<DrinkingPattern>(raw) } catch (_: Exception) { null }
    }

    /**
     * Analyze drink timestamps to find clusters.
     * @param timestamps list of ISO datetime strings (e.g. "2026-03-01T08:30:00")
     */
    fun analyzePatterns(timestamps: List<String>): DrinkingPattern? {
        if (timestamps.size < MIN_ENTRIES_FOR_PATTERN) return null

        // Extract hour:minute from each timestamp
        val times = timestamps.mapNotNull { ts ->
            try {
                val timePart = ts.substringAfter("T").take(5) // "HH:mm"
                val parts = timePart.split(":")
                parts[0].toInt() * 60 + parts[1].toInt() // minutes since midnight
            } catch (_: Exception) { null }
        }.sorted()

        if (times.isEmpty()) return null

        // Cluster times within CLUSTER_THRESHOLD_MINUTES
        val clusters = mutableListOf<MutableList<Int>>()
        var currentCluster = mutableListOf(times.first())

        for (i in 1 until times.size) {
            if (times[i] - currentCluster.last() <= CLUSTER_THRESHOLD_MINUTES) {
                currentCluster.add(times[i])
            } else {
                clusters.add(currentCluster)
                currentCluster = mutableListOf(times[i])
            }
        }
        clusters.add(currentCluster)

        // Median of each cluster = representative time
        val clusterMedians = clusters
            .filter { it.size >= 3 } // only clusters with enough data
            .map { cluster ->
                val sorted = cluster.sorted()
                sorted[sorted.size / 2]
            }

        if (clusterMedians.size < 2) return null

        val clusterTimes = clusterMedians.map { mins ->
            "${(mins / 60).toString().padStart(2, '0')}:${(mins % 60).toString().padStart(2, '0')}"
        }

        val gaps = clusterMedians.zipWithNext { a, b -> b - a }
        val longestGapIdx = gaps.indexOf(gaps.maxOrNull())
        val longestGapStartHour = clusterMedians.getOrNull(longestGapIdx)?.div(60) ?: 12

        val totalDays = timestamps.mapNotNull { it.take(10) }.distinct().size

        val pattern = DrinkingPattern(
            clusterTimes = clusterTimes,
            gapMinutes = gaps,
            longestGapStartHour = longestGapStartHour,
            totalDataDays = totalDays,
            updatedAt = java.time.LocalDateTime.now().toString()
        )

        prefs.edit().putString(PREF_KEY, json.encodeToString(pattern)).apply()
        return pattern
    }

    /**
     * Get suggested reminder times based on patterns.
     * Adds reminders in detected gaps where user typically doesn't drink.
     */
    fun getSuggestedReminderTimes(): List<String> {
        val pattern = getPattern() ?: return defaultReminderTimes()

        val reminders = pattern.clusterTimes.toMutableList()
        // Add a reminder in the middle of the longest gap
        if (pattern.gapMinutes.isNotEmpty()) {
            val longestGap = pattern.gapMinutes.max()
            if (longestGap > 120) { // Only suggest if gap > 2 hours
                val gapIdx = pattern.gapMinutes.indexOf(longestGap)
                val gapStart = pattern.clusterTimes.getOrNull(gapIdx) ?: return reminders
                val startMinutes = gapStart.split(":").let { it[0].toInt() * 60 + it[1].toInt() }
                val midpoint = startMinutes + longestGap / 2
                val midTime = "${(midpoint / 60).toString().padStart(2, '0')}:${(midpoint % 60).toString().padStart(2, '0')}"
                reminders.add(gapIdx + 1, midTime)
            }
        }
        return reminders
    }

    private fun defaultReminderTimes() = listOf("08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00")
}
```

**Step 2: Wire into HydrationViewModel**

In `HydrationViewModel`, after loading entries, trigger pattern analysis:

```kotlin
// Add to constructor params:
private val patternService: DrinkingPatternService = DrinkingPatternService(AppContainer.sharedPreferences)

// In loadEntries() or init, after entries are loaded:
fun analyzePatterns() {
    val timestamps = _uiState.value.entries.map { it.consumedAt }
    patternService.analyzePatterns(timestamps)
}
```

Call `analyzePatterns()` after entries are loaded from repository.

**Step 3: Build and verify**

Run: `cd android && ./gradlew assembleDebug`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/DrinkingPatternService.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/hydration/HydrationViewModel.kt
git commit -m "feat(android): add DrinkingPatternService for smart hydration reminders

Heuristic pattern detection analyzes 14-day drinking timestamps to
find natural clusters and suggest reminder times in detected gaps."
```

---

## Task 7: Live Workout Foreground Notification

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/WorkoutNotificationService.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/LiveWorkoutViewModel.kt`
- Modify: `android/app/src/main/AndroidManifest.xml` (add service declaration)

**Step 1: Create WorkoutNotificationService**

Android foreground service that shows an ongoing notification with live workout stats (time, distance, pace). Updates every 5 seconds. Has Pause/Resume and Stop action buttons.

```kotlin
package com.swasthicare.mobile.data.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.swasthicare.mobile.MainActivity
import com.swasthicare.mobile.R

class WorkoutNotificationService : Service() {

    companion object {
        const val CHANNEL_ID = "workout_tracking"
        const val NOTIFICATION_ID = 2001
        const val ACTION_PAUSE = "com.swasthicare.mobile.WORKOUT_PAUSE"
        const val ACTION_RESUME = "com.swasthicare.mobile.WORKOUT_RESUME"
        const val ACTION_STOP = "com.swasthicare.mobile.WORKOUT_STOP"
        const val EXTRA_TIME = "elapsed_time"
        const val EXTRA_DISTANCE = "distance_km"
        const val EXTRA_PACE = "current_pace"
        const val EXTRA_CALORIES = "calories"

        fun start(context: Context) {
            val intent = Intent(context, WorkoutNotificationService::class.java)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, WorkoutNotificationService::class.java)
            context.stopService(intent)
        }

        fun update(context: Context, time: String, distanceKm: String, pace: String, calories: Int) {
            val intent = Intent(context, WorkoutNotificationService::class.java).apply {
                putExtra(EXTRA_TIME, time)
                putExtra(EXTRA_DISTANCE, distanceKm)
                putExtra(EXTRA_PACE, pace)
                putExtra(EXTRA_CALORIES, calories)
            }
            context.startForegroundService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE, ACTION_RESUME, ACTION_STOP -> {
                // These are handled by LiveWorkoutViewModel via broadcast
                return START_STICKY
            }
        }

        val time = intent?.getStringExtra(EXTRA_TIME) ?: "00:00"
        val distance = intent?.getStringExtra(EXTRA_DISTANCE) ?: "0.00 km"
        val pace = intent?.getStringExtra(EXTRA_PACE) ?: "--:--"
        val calories = intent?.getIntExtra(EXTRA_CALORIES, 0) ?: 0

        val notification = buildNotification(time, distance, pace, calories)
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Workout Tracking",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows live workout stats"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(time: String, distance: String, pace: String, calories: Int): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = android.net.Uri.parse("swastricare://activeworkout")
        }
        val pendingTap = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = PendingIntent.getBroadcast(
            this, 1,
            Intent(ACTION_STOP).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("Workout in Progress")
            .setContentText("$time  •  $distance  •  $pace /km")
            .setSubText("$calories cal")
            .setOngoing(true)
            .setContentIntent(pendingTap)
            .addAction(R.drawable.ic_launcher_foreground, "Stop", stopIntent)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
    }
}
```

**Step 2: Add service to AndroidManifest.xml**

```xml
<service
    android:name=".data.services.WorkoutNotificationService"
    android:foregroundServiceType="location"
    android:exported="false" />
```

**Step 3: Wire LiveWorkoutViewModel to start/update/stop notification**

In `LiveWorkoutViewModel`:
- Call `WorkoutNotificationService.start(context)` when workout starts (after countdown)
- Call `WorkoutNotificationService.update(...)` every 5 seconds with current stats
- Call `WorkoutNotificationService.stop(context)` when workout ends

**Step 4: Build and verify**

Run: `cd android && ./gradlew assembleDebug`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/WorkoutNotificationService.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/runactivity/LiveWorkoutViewModel.kt
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): add foreground notification for live workout tracking

Shows ongoing notification with time, distance, pace, and calories.
Android equivalent of iOS Live Activity for active workouts."
```
