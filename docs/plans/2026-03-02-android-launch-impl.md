# Android Launch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Take the Android app from 70% demo-data to a fully backend-connected, launch-ready app with iOS visual parity across 4 core tabs.

**Architecture:** MVVM with singleton `AppContainer` DI, Supabase SDK for all backend, Jetpack Compose UI, `DataStore<Preferences>` for settings persistence. Each task replaces one mock/stub with a real implementation and wires it into the existing navigation.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, Supabase Kotlin SDK v2.6.0, Ktor 2.3.12, Health Connect API, AlarmManager, DataStore, Firebase Crashlytics

---

## Pre-flight checks

Before starting, verify these in Android Studio:
1. Open `android/` as the project root
2. Sync Gradle — should succeed with no errors
3. Run on emulator: app launches to SplashScreen → Login

---

## Phase 1 — Backend Connections

---

### Task 1: Add Missing Dependencies

**Files:**
- Modify: `android/app/build.gradle.kts`

**Step 1: Add DataStore, Health Connect, and WorkManager to dependencies**

In `build.gradle.kts`, inside the `dependencies { }` block, add after the existing Compose dependencies:

```kotlin
// DataStore for settings persistence
implementation("androidx.datastore:datastore-preferences:1.0.0")

// Health Connect
implementation("androidx.health.connect:connect-client:1.1.0-alpha07")

// WorkManager (for background health sync)
implementation("androidx.work:work-runtime-ktx:2.9.0")
```

Also change `minSdk = 24` to `minSdk = 26` in `defaultConfig` — Health Connect requires API 26.

**Step 2: Enable minification in release build**

In `buildTypes.release`, change:
```kotlin
isMinifyEnabled = true
```

**Step 3: Sync Gradle**

Click "Sync Now" in Android Studio or run:
```bash
cd android && ./gradlew dependencies --configuration releaseRuntimeClasspath
```
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/build.gradle.kts
git commit -m "build(android): add DataStore, Health Connect, WorkManager; bump minSdk to 26"
```

---

### Task 2: Supabase Profile Repository

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/ProfileRepository.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`

**Step 1: Add `SupabaseProfileRepository` to `ProfileRepository.kt`**

Append this class after `MockProfileRepository`:

```kotlin
class SupabaseProfileRepository(
    private val client: SupabaseClient
) : ProfileRepository {

    override suspend fun getHealthProfile(userId: String): HealthProfile? {
        return try {
            client.postgrest["health_profiles"]
                .select {
                    filter { eq("user_id", userId) }
                    limit(1)
                }
                .decodeSingleOrNull<HealthProfile>()
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun createHealthProfile(profile: HealthProfile): HealthProfile {
        return client.postgrest["health_profiles"]
            .insert(profile) { select() }
            .decodeSingle<HealthProfile>()
    }

    override suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile {
        return client.postgrest["health_profiles"]
            .update(profile) {
                filter { eq("user_id", profile.userId) }
                select()
            }
            .decodeSingle<HealthProfile>()
    }
}
```

Add the required imports at the top of the file:
```kotlin
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.filter.eq
```

**Step 2: Wire into `AppContainer.kt`**

Replace line 83:
```kotlin
// OLD:
val profileRepository: ProfileRepository by lazy {
    MockProfileRepository()
}
// NEW:
val profileRepository: ProfileRepository by lazy {
    SupabaseProfileRepository(supabaseClient)
}
```

**Step 3: Add DataStore to AppContainer for settings persistence**

Add after the `sharedPreferences` property (line 79):

```kotlin
// DataStore for persisting settings
val dataStore: DataStore<Preferences> by lazy {
    context.createDataStore(name = "swasthicare_settings")
}
```

Add import at the top:
```kotlin
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import android.content.Context
```

Replace with extension property pattern — add at top of file (after package, before imports are used):
```kotlin
// Extension property for DataStore
private val Context.dataStore by preferencesDataStore(name = "swasthicare_settings")
```

Then in AppContainer:
```kotlin
val dataStore get() = context.dataStore
```

**Step 4: Verify**

Run the app → go to Profile tab → profile data should load from Supabase (if user has a profile) or show empty state. Check Logcat for `"health_profiles"` Postgrest calls.

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/ProfileRepository.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): replace MockProfileRepository with SupabaseProfileRepository"
```

---

### Task 3: Persist Profile Settings with DataStore

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/profile/ProfileViewModel.kt`

**Step 1: Add DataStore reads/writes to `ProfileViewModel`**

At the top of the class body, after `private val profileRepository`, add:

```kotlin
private val dataStore = AppContainer.dataStore

companion object {
    val NOTIFICATIONS_KEY = booleanPreferencesKey("notifications_enabled")
    val BIOMETRIC_KEY = booleanPreferencesKey("biometric_enabled")
    val HEALTH_SYNC_KEY = booleanPreferencesKey("health_sync_enabled")
}
```

Add imports:
```kotlin
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import kotlinx.coroutines.flow.first
```

Replace the `init` block's hardcoded settings with DataStore reads:

```kotlin
init {
    loadUser()
    loadSettings()
}

private fun loadSettings() {
    viewModelScope.launch {
        val prefs = dataStore.data.first()
        _uiState.update {
            it.copy(
                notificationsEnabled = prefs[NOTIFICATIONS_KEY] ?: true,
                biometricEnabled = prefs[BIOMETRIC_KEY] ?: false,
                healthSyncEnabled = prefs[HEALTH_SYNC_KEY] ?: true
            )
        }
    }
}
```

Replace `toggleNotifications`, `toggleBiometric`, `toggleHealthSync` with persisting versions:

```kotlin
fun toggleNotifications(enabled: Boolean) {
    viewModelScope.launch {
        dataStore.edit { it[NOTIFICATIONS_KEY] = enabled }
        _uiState.update { it.copy(notificationsEnabled = enabled) }
    }
}

fun toggleBiometric(enabled: Boolean) {
    viewModelScope.launch {
        dataStore.edit { it[BIOMETRIC_KEY] = enabled }
        _uiState.update { it.copy(biometricEnabled = enabled) }
    }
}

fun toggleHealthSync(enabled: Boolean) {
    viewModelScope.launch {
        dataStore.edit { it[HEALTH_SYNC_KEY] = enabled }
        _uiState.update { it.copy(healthSyncEnabled = enabled) }
    }
}
```

**Step 2: Verify**

Run app → Profile → toggle Notifications off → kill and relaunch app → Profile should still show Notifications toggled off.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/profile/ProfileViewModel.kt
git commit -m "feat(android): persist profile settings to DataStore"
```

---

### Task 4: Health Connect Integration (Home/Vitals)

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthConnectService.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`
- Modify: `android/app/AndroidManifest.xml`

**Step 1: Create `HealthConnectService.kt`**

```kotlin
package com.swasthicare.mobile.data.services

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class DailyHealthSummary(
    val steps: Int = 0,
    val heartRate: Int = 0,
    val activeCalories: Int = 0,
    val totalCalories: Int = 0
)

class HealthConnectService(private val context: Context) {

    val client: HealthConnectClient? by lazy {
        if (HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(context)
        } else null
    }

    val isAvailable: Boolean get() = client != null

    val requiredPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)
    )

    suspend fun hasPermissions(): Boolean {
        val client = client ?: return false
        val granted = client.permissionController.getGrantedPermissions()
        return granted.containsAll(requiredPermissions)
    }

    suspend fun getTodaySummary(): DailyHealthSummary {
        val client = client ?: return DailyHealthSummary()
        if (!hasPermissions()) return DailyHealthSummary()

        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val now = Instant.now()
        val range = TimeRangeFilter.between(startOfDay, now)

        val steps = try {
            client.readRecords(ReadRecordsRequest(StepsRecord::class, range))
                .records.sumOf { it.count }.toInt()
        } catch (e: Exception) { 0 }

        val heartRate = try {
            client.readRecords(ReadRecordsRequest(HeartRateRecord::class, range))
                .records.lastOrNull()?.samples?.lastOrNull()?.beatsPerMinute?.toInt() ?: 0
        } catch (e: Exception) { 0 }

        val activeCalories = try {
            client.readRecords(ReadRecordsRequest(ActiveCaloriesBurnedRecord::class, range))
                .records.sumOf { it.energy.inKilocalories }.toInt()
        } catch (e: Exception) { 0 }

        val totalCalories = try {
            client.readRecords(ReadRecordsRequest(TotalCaloriesBurnedRecord::class, range))
                .records.sumOf { it.energy.inKilocalories }.toInt()
        } catch (e: Exception) { 0 }

        return DailyHealthSummary(steps, heartRate, activeCalories, totalCalories)
    }
}
```

**Step 2: Add `HealthConnectService` to `AppContainer.kt`**

Add after `sharedPreferences`:
```kotlin
val healthConnectService: HealthConnectService by lazy {
    HealthConnectService(context)
}
```

Add import:
```kotlin
import com.swasthicare.mobile.data.services.HealthConnectService
```

**Step 3: Update `HomeViewModel.kt` to use `HealthConnectService`**

Change the class signature to accept the service:
```kotlin
class HomeViewModel(
    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService
) : ViewModel() {
```

Replace the `loadData()` function body:
```kotlin
private fun loadData() {
    viewModelScope.launch {
        val hour = LocalDateTime.now().hour
        val greeting = when (hour) {
            in 5..11 -> "Good Morning,"
            in 12..16 -> "Good Afternoon,"
            in 17..20 -> "Good Evening,"
            else -> "Good Night,"
        }
        val weekDates = generateWeekDates()

        if (healthConnectService.isAvailable && healthConnectService.hasPermissions()) {
            val summary = healthConnectService.getTodaySummary()
            val weeklySteps = generateSampleWeeklySteps() // TODO: fetch real weekly data
            _uiState.value = HomeState(
                greeting = greeting,
                stepCount = summary.steps,
                calories = summary.activeCalories,
                heartRate = summary.heartRate,
                isLoading = false,
                isDemoMode = false,
                isAuthorized = true,
                weekDates = weekDates,
                selectedDate = Date(),
                weeklySteps = weeklySteps
            )
        } else {
            // Demo fallback while permissions not granted
            delay(800)
            _uiState.value = HomeState(
                greeting = greeting,
                stepCount = 0,
                calories = 0,
                heartRate = 0,
                isLoading = false,
                isDemoMode = !healthConnectService.isAvailable,
                isAuthorized = false,
                weekDates = weekDates,
                selectedDate = Date(),
                weeklySteps = generateSampleWeeklySteps()
            )
        }
        loadNudges()
    }
}
```

Replace `requestHealthPermissions()` stub:
```kotlin
// This is called after the user grants permissions via the system dialog
fun onPermissionsGranted() {
    viewModelScope.launch {
        _uiState.value = _uiState.value.copy(isAuthorized = true, isDemoMode = false)
        loadData()
    }
}
```

**Step 4: Add Health Connect permission to AndroidManifest.xml**

Find `android/app/src/main/AndroidManifest.xml`. Inside `<manifest>`, before `<application>`:
```xml
<!-- Health Connect permissions -->
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
```

Inside `<application>`:
```xml
<!-- Declare Health Connect usage -->
<activity
    android:name="androidx.health.connect.client.permission.HealthPermissionActivity"
    android:exported="true"/>
```

**Step 5: Verify**

Run app on device with Health Connect installed → Home tab → step count should show real data if permissions granted, or 0 with `isDemoMode=true` fallback otherwise. Check Logcat for Health Connect reads.

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthConnectService.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeViewModel.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt \
        android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): integrate Health Connect for real steps/heart rate/calories on Home"
```

---

### Task 5: Supabase Vault Repository

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/VaultRepository.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`

**Step 1: Add `SupabaseVaultRepository` to `VaultRepository.kt`**

Append after `MockVaultRepository`:

```kotlin
class SupabaseVaultRepository(
    private val client: SupabaseClient,
    private val userId: String
) : VaultRepository {

    private val bucketId = "vault-documents"
    private val tableName = "vault_documents"

    override suspend fun getDocuments(): List<MedicalDocument> {
        return try {
            client.postgrest[tableName]
                .select {
                    filter { eq("user_id", userId) }
                    order("created_at", ascending = false)
                }
                .decodeList<MedicalDocument>()
        } catch (e: Exception) {
            emptyList()
        }
    }

    override suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ): MedicalDocument {
        // 1. Upload file to Supabase Storage
        val storagePath = "$userId/$fileName"
        client.storage[bucketId].upload(storagePath, fileData, upsert = true)
        val fileUrl = client.storage[bucketId].publicUrl(storagePath)

        // 2. Insert metadata row
        val doc = MedicalDocument(
            userId = userId,
            title = metadata.name.ifEmpty { fileName },
            category = category,
            fileType = fileName.substringAfterLast('.', "dat"),
            fileUrl = fileUrl,
            fileSize = fileData.size.toLong(),
            doctorName = metadata.doctorName,
            location = metadata.location,
            documentDate = metadata.documentDate,
            notes = metadata.description
        )
        return client.postgrest[tableName]
            .insert(doc) { select() }
            .decodeSingle<MedicalDocument>()
    }

    override suspend fun deleteDocument(documentId: String) {
        // Get file URL first to delete from storage
        val doc = client.postgrest[tableName]
            .select { filter { eq("id", documentId) } }
            .decodeSingleOrNull<MedicalDocument>()

        doc?.fileUrl?.let { url ->
            val path = url.substringAfter("$bucketId/")
            runCatching { client.storage[bucketId].delete(listOf(path)) }
        }

        client.postgrest[tableName]
            .delete { filter { eq("id", documentId) } }
    }

    override suspend fun getSignedUrl(path: String): String {
        return client.storage[bucketId].createSignedUrl(path, 3600)
    }
}
```

Add required imports:
```kotlin
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.filter.eq
import io.github.jan.supabase.storage.storage
```

**Step 2: Update `VaultViewModel.kt`** to resolve real `userId` before creating the repository

Open `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt`.

Find where `MockVaultRepository` is used and replace the repository initialization with:
```kotlin
private val repository: VaultRepository by lazy {
    val userId = AppContainer.authRepository.currentUser?.id
    if (userId != null) {
        SupabaseVaultRepository(AppContainer.supabaseClient, userId)
    } else {
        MockVaultRepository()
    }
}
```

Add imports:
```kotlin
import com.swasthicare.mobile.data.repository.SupabaseVaultRepository
import com.swasthicare.mobile.di.AppContainer
```

**Step 3: Remove `MockVaultRepository` from `AppContainer.kt`**

In `AppContainer.kt`, replace:
```kotlin
val vaultRepository: VaultRepository by lazy {
    MockVaultRepository()
}
```
With a note that vault uses userId-scoped repository — remove it from AppContainer entirely since `VaultViewModel` now self-resolves. Delete the `vaultRepository` property from `AppContainer`.

**Step 4: Verify**

Run app → Vault tab → list should be empty (no documents yet) or show real Supabase documents. Upload a file → check Supabase Storage bucket `vault-documents` in dashboard. Delete a document → verify it disappears from both Storage and the table.

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/VaultRepository.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): replace MockVaultRepository with SupabaseVaultRepository + Storage"
```

---

### Task 6: AI Chat Backend Connection

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AIService.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/SpeechService.kt`

**Step 1: Rewrite `AIService.kt` to call the Supabase `ai-router` edge function**

Replace the entire file content:

```kotlin
package com.swasthicare.mobile.data.services

import com.swasthicare.mobile.data.models.ChatMessage
import com.swasthicare.mobile.data.models.ChatRequest
import com.swasthicare.mobile.data.models.ChatResponse
import com.swasthicare.mobile.data.models.ContextMessage
import com.swasthicare.mobile.data.models.HealthAnalysisResponse
import com.swasthicare.mobile.data.models.HealthMetrics
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.call.body
import kotlinx.serialization.json.Json

class AIService(private val client: SupabaseClient) {

    suspend fun sendChatMessage(message: String, context: List<ChatMessage>): String {
        val contextMessages = context.takeLast(10).map { msg ->
            ContextMessage(
                role = if (msg.isUser) "user" else "assistant",
                content = msg.content
            )
        }
        val request = ChatRequest(message = message, context = contextMessages)

        return try {
            val response = client.functions.invoke(
                function = "ai-router",
                body = request
            )
            val body = response.body<String>()
            Json.decodeFromString<ChatResponse>(body).response
        } catch (e: Exception) {
            "I'm having trouble connecting right now. Please try again. (${e.message})"
        }
    }

    suspend fun analyzeHealth(metrics: HealthMetrics): HealthAnalysisResponse {
        return try {
            val response = client.functions.invoke(
                function = "ai-router",
                body = mapOf(
                    "type" to "health_analysis",
                    "metrics" to metrics
                )
            )
            val body = response.body<String>()
            Json.decodeFromString<HealthAnalysisResponse>(body)
        } catch (e: Exception) {
            HealthAnalysisResponse(
                assessment = "Unable to analyze at this time.",
                insights = "",
                recommendations = listOf("Please check your connection and try again.")
            )
        }
    }
}
```

**Step 2: Update `AppContainer.kt` to inject `AIService`**

Add:
```kotlin
val aiService: AIService by lazy {
    AIService(supabaseClient)
}
```

Add import:
```kotlin
import com.swasthicare.mobile.data.services.AIService
```

**Step 3: Update `AIViewModel.kt` to use injected service**

Open `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt`.

Find where `AIService()` is instantiated and replace with:
```kotlin
private val aiService: AIService = AppContainer.aiService
```

Add import:
```kotlin
import com.swasthicare.mobile.di.AppContainer
```

**Step 4: Implement `SpeechService.kt`**

Replace the entire file:

```kotlin
package com.swasthicare.mobile.data.services

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import java.util.Locale

sealed class SpeechResult {
    data class Partial(val text: String) : SpeechResult()
    data class Final(val text: String) : SpeechResult()
    data class Error(val message: String) : SpeechResult()
}

class SpeechService(private val context: Context) {

    fun isAvailable(): Boolean = SpeechRecognizer.isRecognitionAvailable(context)

    fun startListening(): Flow<SpeechResult> = callbackFlow {
        val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }

        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onPartialResults(partialResults: Bundle?) {
                val partial = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: return
                trySend(SpeechResult.Partial(partial))
            }
            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                trySend(SpeechResult.Final(text))
                close()
            }
            override fun onError(error: Int) {
                trySend(SpeechResult.Error("Speech error code: $error"))
                close()
            }
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        recognizer.startListening(intent)
        awaitClose { recognizer.destroy() }
    }
}
```

**Step 5: Add `SpeechService` to `AppContainer.kt`**

```kotlin
val speechService: SpeechService by lazy {
    SpeechService(context)
}
```

**Step 6: Verify**

Run app → AI tab → type a message → send → should get real AI response (not demo text). Check Logcat for `"ai-router"` function invocation.

**Step 7: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AIService.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/data/services/SpeechService.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): connect AI chat to Supabase ai-router edge function; implement speech recognition"
```

---

## Phase 2 — Missing Screens & Flows

---

### Task 7: Onboarding Screen

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/onboarding/OnboardingScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`

**Step 1: Create `OnboardingScreen.kt`**

```kotlin
package com.swasthicare.mobile.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PrimaryColor
import com.swasthicare.mobile.ui.theme.SecondaryColor

data class OnboardingPage(
    val title: String,
    val subtitle: String,
    val emoji: String,
    val accentColor: Color
)

private val pages = listOf(
    OnboardingPage("Track Your Health", "Monitor vitals, hydration, and medications all in one place.", "🏥", PrimaryColor),
    OnboardingPage("AI-Powered Insights", "Get personalized health advice from Swastri AI, powered by MedGemma.", "🤖", SecondaryColor),
    OnboardingPage("Secure Health Vault", "Store prescriptions, lab reports, and medical documents safely.", "🔒", Color(0xFF5856D6)),
    OnboardingPage("Your Family, Together", "Manage health for your entire family from one account.", "👨‍👩‍👧", Color(0xFFFF9500))
)

@Composable
fun OnboardingScreen(onFinished: () -> Unit) {
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val isLastPage = pagerState.currentPage == pages.size - 1

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val p = pages[page]
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(text = p.emoji, fontSize = 80.sp)
                Spacer(Modifier.height(32.dp))
                Text(
                    text = p.title,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    color = p.accentColor
                )
                Spacer(Modifier.height(16.dp))
                Text(
                    text = p.subtitle,
                    fontSize = 16.sp,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
            }
        }

        // Page indicator dots
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 140.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(pages.size) { i ->
                val isSelected = pagerState.currentPage == i
                Box(
                    modifier = Modifier
                        .size(if (isSelected) 24.dp else 8.dp, 8.dp)
                        .clip(CircleShape)
                        .background(if (isSelected) PrimaryColor else Color.Gray.copy(alpha = 0.4f))
                )
            }
        }

        // Next / Get Started button
        Button(
            onClick = onFinished,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 32.dp, vertical = 48.dp)
                .fillMaxWidth()
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text(
                text = if (isLastPage) "Get Started" else "Next",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
```

**Step 2: Add DataStore key for onboarding completion in `AppContainer.kt`**

Add companion/top-level:
```kotlin
// Top-level DataStore keys (add near the Context extension)
val ONBOARDING_COMPLETE_KEY = booleanPreferencesKey("onboarding_complete")
val CONSENT_ACCEPTED_KEY = booleanPreferencesKey("consent_accepted")
val HEALTH_PROFILE_COMPLETE_KEY = booleanPreferencesKey("health_profile_complete")
```

Add import:
```kotlin
import androidx.datastore.preferences.core.booleanPreferencesKey
```

**Step 3: Add `"onboarding"` route to `AppNavigation.kt`**

In the `NavHost` block, add before the `"splash"` composable:

```kotlin
// Onboarding
composable("onboarding") {
    OnboardingScreen(
        onFinished = {
            // Mark complete in DataStore
            navController.currentBackStackEntry?.savedStateHandle?.set("action", "onboarding_done")
            navController.navigate("consent") {
                popUpTo("onboarding") { inclusive = true }
            }
        }
    )
}
```

Update `SplashScreen` navigation logic: after the `delay(2000)` check DataStore to decide if onboarding was completed:

```kotlin
// In SplashScreen.kt, update the LaunchedEffect
LaunchedEffect(Unit) {
    delay(1500)
    val prefs = AppContainer.dataStore.data.first()
    val onboardingDone = prefs[ONBOARDING_COMPLETE_KEY] ?: false
    if (onboardingDone) {
        onNavigateToLogin()
    } else {
        onNavigateToOnboarding()
    }
}
```

Add `onNavigateToOnboarding: () -> Unit` parameter to `SplashScreen`.

Update `AppNavigation.kt`'s splash composable to pass this new callback:
```kotlin
composable("splash") {
    SplashScreen(
        onNavigateToHome = { navController.navigate("main") { popUpTo("splash") { inclusive = true } } },
        onNavigateToLogin = { navController.navigate("login") { popUpTo("splash") { inclusive = true } } },
        onNavigateToOnboarding = { navController.navigate("onboarding") { popUpTo("splash") { inclusive = true } } }
    )
}
```

**Step 4: Verify**

Fresh install → should show OnboardingScreen with 4 slides. Tap "Get Started" → should navigate. Second launch → should skip onboarding.

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/onboarding/ \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/splash/SplashScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): add onboarding screen with 4 slides and DataStore completion tracking"
```

---

### Task 8: Consent Screen

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/onboarding/ConsentScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt`

**Step 1: Create `ConsentScreen.kt`**

```kotlin
package com.swasthicare.mobile.ui.screens.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PrimaryColor

@Composable
fun ConsentScreen(onAccepted: () -> Unit) {
    var hasScrolledToBottom by remember { mutableStateOf(false) }
    val scrollState = rememberScrollState()

    // Enable button after user scrolls to near-bottom
    LaunchedEffect(scrollState.value) {
        if (scrollState.value >= scrollState.maxValue * 0.8f) {
            hasScrolledToBottom = true
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp)
    ) {
        Text(
            "Privacy & Consent",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 48.dp, bottom = 24.dp)
        )

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(scrollState)
        ) {
            Text(
                text = """
SwasthiCare Privacy Policy (Summary)

Last updated: March 2026

DATA WE COLLECT
• Health data: steps, heart rate, calories, medication logs, diet entries
• Profile data: name, date of birth, gender, height, weight, blood type
• Documents: medical records you upload to your Vault
• Usage data: app interactions for improving the experience

HOW WE USE YOUR DATA
• To display your health dashboard and trends
• To power Swastri AI health insights (processed by Google Gemini/MedGemma)
• To sync data across your devices via Supabase

DATA STORAGE
• All data is stored on Supabase servers (AWS ap-south-1 region, India)
• We comply with India's Digital Personal Data Protection Act (DPDPA) 2023

YOUR RIGHTS
• Access: View all your data in the app
• Delete: Delete your account and all data from Profile settings
• Export: Contact support for a data export

AI DISCLAIMER
• Swastri AI provides general health information only
• It is NOT a substitute for professional medical advice
• Always consult a qualified doctor for medical decisions

By tapping "I Agree", you consent to this privacy policy and terms of service.
                """.trimIndent(),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
            )
        }

        Spacer(Modifier.height(16.dp))

        if (!hasScrolledToBottom) {
            Text(
                "Scroll down to read and accept",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
            )
        }

        Button(
            onClick = onAccepted,
            enabled = hasScrolledToBottom,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text("I Agree & Continue", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(16.dp))
    }
}
```

**Step 2: Add `"consent"` route to `AppNavigation.kt`**

```kotlin
composable("consent") {
    ConsentScreen(
        onAccepted = {
            // Persist consent acceptance
            // Navigate to login
            navController.navigate("login") {
                popUpTo("consent") { inclusive = true }
            }
        }
    )
}
```

For persisting consent in the `onAccepted` callback, launch a coroutine using `rememberCoroutineScope`:

In `AppNavigation.kt` body, add before the NavHost:
```kotlin
val scope = rememberCoroutineScope()
```

In the `ConsentScreen` callback:
```kotlin
onAccepted = {
    scope.launch {
        AppContainer.dataStore.edit { it[CONSENT_ACCEPTED_KEY] = true }
        // Also mark onboarding complete (belt and suspenders)
        AppContainer.dataStore.edit { it[ONBOARDING_COMPLETE_KEY] = true }
    }
    navController.navigate("login") {
        popUpTo("consent") { inclusive = true }
    }
}
```

**Step 3: Verify**

After onboarding → ConsentScreen shows. Scroll to bottom → "I Agree" button enables. Tap → navigates to Login.

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/onboarding/ConsentScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt
git commit -m "feat(android): add consent screen with DPDPA-compliant privacy policy and DataStore persistence"
```

---

### Task 9: Health Profile Questionnaire

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/onboarding/HealthProfileScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt`

**Step 1: Create `HealthProfileScreen.kt`**

```kotlin
package com.swasthicare.mobile.ui.screens.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.model.Gender
import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.ui.theme.PrimaryColor
import kotlinx.coroutines.launch

@Composable
fun HealthProfileScreen(
    userId: String,
    profileRepository: ProfileRepository,
    onCompleted: () -> Unit
) {
    var fullName by remember { mutableStateOf("") }
    var dateOfBirth by remember { mutableStateOf("") } // YYYY-MM-DD
    var gender by remember { mutableStateOf(Gender.Male) }
    var heightCm by remember { mutableStateOf("") }
    var weightKg by remember { mutableStateOf("") }
    var bloodType by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val bloodTypes = listOf("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
    val genders = Gender.values().toList()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Spacer(Modifier.height(48.dp))
        Text("Your Health Profile", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "We use this to personalize your health insights.",
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.padding(top = 8.dp, bottom = 32.dp)
        )

        OutlinedTextField(
            value = fullName,
            onValueChange = { fullName = it },
            label = { Text("Full Name") },
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        OutlinedTextField(
            value = dateOfBirth,
            onValueChange = { dateOfBirth = it },
            label = { Text("Date of Birth (YYYY-MM-DD)") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        // Gender selector
        Text("Gender", fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(bottom = 8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 16.dp)) {
            genders.forEach { g ->
                FilterChip(
                    selected = gender == g,
                    onClick = { gender = g },
                    label = { Text(g.displayName) }
                )
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            OutlinedTextField(
                value = heightCm,
                onValueChange = { heightCm = it },
                label = { Text("Height (cm)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = weightKg,
                onValueChange = { weightKg = it },
                label = { Text("Weight (kg)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(16.dp))

        // Blood type selector
        Text("Blood Type", fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(bottom = 8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 32.dp)) {
            bloodTypes.forEach { bt ->
                FilterChip(
                    selected = bloodType == bt,
                    onClick = { bloodType = bt },
                    label = { Text(bt) }
                )
            }
        }

        errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(bottom = 8.dp))
        }

        Button(
            onClick = {
                val h = heightCm.toDoubleOrNull()
                val w = weightKg.toDoubleOrNull()
                if (fullName.isBlank() || dateOfBirth.length != 10 || h == null || w == null) {
                    errorMessage = "Please fill in all required fields."
                    return@Button
                }
                isLoading = true
                scope.launch {
                    try {
                        val profile = HealthProfile(
                            userId = userId,
                            fullName = fullName.trim(),
                            gender = gender,
                            dateOfBirth = dateOfBirth,
                            heightCm = h,
                            weightKg = w,
                            bloodType = bloodType.ifEmpty { null }
                        )
                        profileRepository.createHealthProfile(profile)
                        onCompleted()
                    } catch (e: Exception) {
                        errorMessage = "Failed to save profile: ${e.message}"
                        isLoading = false
                    }
                }
            },
            enabled = !isLoading,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
            } else {
                Text("Save & Continue", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(Modifier.height(32.dp))
    }
}
```

**Step 2: Add `"health_profile"` route to `AppNavigation.kt`**

Inside `NavHost`:
```kotlin
composable("health_profile") {
    val userId = authViewModel.uiState.value.let {
        (it as? AuthUiState.Success)?.user?.id ?: ""
    }
    HealthProfileScreen(
        userId = userId,
        profileRepository = AppContainer.profileRepository,
        onCompleted = {
            navController.navigate("main") {
                popUpTo("health_profile") { inclusive = true }
            }
        }
    )
}
```

Update the `"main"` destination check: after successful login, check if health profile exists. In the login `onNavigateToHome` callback:

```kotlin
onNavigateToHome = {
    // Check if health profile exists before going to main
    navController.navigate("main") {
        popUpTo("login") { inclusive = true }
    }
    // Note: ProfileViewModel will prompt user to create profile if none exists
}
```

Actually, the profile check happens in `ProfileViewModel.loadHealthProfile` — if it returns null, show a prompt. Add a `showProfileSetupPrompt` state to `ProfileViewModel` and navigate to `"health_profile"` from `ProfileScreen` if profile is null.

Add to `ProfileUiState`:
```kotlin
val needsHealthProfile: Boolean = false
```

In `ProfileViewModel.loadHealthProfile`:
```kotlin
if (profile == null) {
    _uiState.update { it.copy(isLoadingHealthProfile = false, needsHealthProfile = true) }
} else {
    _uiState.update { it.copy(healthProfile = profile, isLoadingHealthProfile = false, needsHealthProfile = false) }
}
```

**Step 3: Verify**

New user login → should show HealthProfileScreen. Fill in data → tap Save → data appears in Supabase `health_profiles` table and Profile tab shows real values.

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/onboarding/HealthProfileScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/profile/ProfileViewModel.kt
git commit -m "feat(android): add health profile questionnaire with Supabase write and nav integration"
```

---

### Task 10: Force Update Screen

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/splash/ForceUpdateScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/splash/SplashScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt`

**Step 1: Create `ForceUpdateScreen.kt`**

```kotlin
package com.swasthicare.mobile.ui.screens.splash

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PrimaryColor

@Composable
fun ForceUpdateScreen() {
    val context = LocalContext.current
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("🔄", fontSize = 64.sp)
        Spacer(Modifier.height(24.dp))
        Text(
            "Update Required",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "A newer version of SwasthiCare is available. Please update to continue.",
            fontSize = 16.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
        )
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.swasthicare.mobile"))
                context.startActivity(intent)
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text("Update on Play Store", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}
```

**Step 2: Add version check to `SplashScreen.kt`**

Add `onForceUpdate: () -> Unit` parameter and version check logic:

```kotlin
@Composable
fun SplashScreen(
    onNavigateToHome: () -> Unit,
    onNavigateToLogin: () -> Unit,
    onNavigateToOnboarding: () -> Unit,
    onForceUpdate: () -> Unit
) {
    LaunchedEffect(Unit) {
        delay(1500)
        try {
            // Fetch minimum required version from Supabase app_config table
            val config = AppContainer.supabaseClient.postgrest["app_config"]
                .select { filter { eq("key", "min_android_version") } }
                .decodeSingleOrNull<Map<String, String>>()
            val minVersion = config?.get("value")?.toIntOrNull() ?: 1
            val currentVersion = 1 // BuildConfig.VERSION_CODE

            if (currentVersion < minVersion) {
                onForceUpdate()
                return@LaunchedEffect
            }
        } catch (_: Exception) {
            // Network error — allow app to proceed
        }

        val prefs = AppContainer.dataStore.data.first()
        val onboardingDone = prefs[ONBOARDING_COMPLETE_KEY] ?: false
        if (onboardingDone) onNavigateToLogin() else onNavigateToOnboarding()
    }
    // ... existing Box UI ...
}
```

**Step 3: Add `"force_update"` route to `AppNavigation.kt`**

```kotlin
composable("force_update") {
    ForceUpdateScreen()
}
```

Update splash composable to pass `onForceUpdate`:
```kotlin
onForceUpdate = {
    navController.navigate("force_update") {
        popUpTo("splash") { inclusive = true }
    }
}
```

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/splash/ \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/AppNavigation.kt
git commit -m "feat(android): add force update screen with Supabase version check"
```

---

### Task 11: Google OAuth Fix

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`
- No code changes to write — this is a configuration task.

**Step 1: Get SHA-1 fingerprint**

```bash
cd android
./gradlew signingReport
```

Copy the SHA-1 from the `debug` variant output.

**Step 2: Register in Google Cloud Console**

1. Go to https://console.cloud.google.com/
2. Select (or create) project matching Supabase project
3. APIs & Services → Credentials → Create OAuth 2.0 Client ID
4. Application type: Android
5. Package name: `com.swasthicare.mobile`
6. SHA-1: paste from step 1
7. Also create a Web Application client ID (needed for Supabase)
8. Copy the Web Client ID (format: `XXXXXXXX.apps.googleusercontent.com`)

**Step 3: Register in Supabase Dashboard**

1. Go to https://supabase.com/dashboard/project/jlumbeyukpnuicyxzvre/auth/providers
2. Enable Google provider
3. Paste the Web Client ID and Client Secret

**Step 4: Update `AppContainer.kt`**

Replace line 62:
```kotlin
webClientId = "YOUR_ACTUAL_WEB_CLIENT_ID.apps.googleusercontent.com"
```

**Step 5: Verify**

Run app → Login → "Continue with Google" → should open Google account picker → should authenticate successfully.

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "config(android): set Google OAuth Web Client ID for Supabase auth"
```

---

### Task 12: Medication Reminders

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/notifications/MedicationReminderReceiver.kt`
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/notifications/MedicationReminderScheduler.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/medications/MedicationsViewModel.kt`

**Step 1: Create `MedicationReminderReceiver.kt`**

```kotlin
package com.swasthicare.mobile.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.swasthicare.mobile.MainActivity

class MedicationReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val medName = intent.getStringExtra("med_name") ?: "Medication"
        val medId = intent.getStringExtra("med_id") ?: return
        val scheduleId = intent.getStringExtra("schedule_id") ?: return

        val channelId = "medication_reminders"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Medication Reminders", NotificationManager.IMPORTANCE_HIGH)
            )
        }

        val openIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("Time for your medication")
            .setContentText("$medName is due now")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openIntent)
            .build()

        manager.notify(medId.hashCode(), notification)
    }
}
```

**Step 2: Create `MedicationReminderScheduler.kt`**

```kotlin
package com.swasthicare.mobile.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object MedicationReminderScheduler {

    fun schedule(
        context: Context,
        medId: String,
        scheduleId: String,
        medName: String,
        timeHour: Int,
        timeMinute: Int
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Check exact alarm permission on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) return
        }

        val intent = Intent(context, MedicationReminderReceiver::class.java).apply {
            putExtra("med_id", medId)
            putExtra("schedule_id", scheduleId)
            putExtra("med_name", medName)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            scheduleId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, timeHour)
            set(Calendar.MINUTE, timeMinute)
            set(Calendar.SECOND, 0)
            if (timeInMillis < System.currentTimeMillis()) {
                add(Calendar.DAY_OF_MONTH, 1) // Schedule for tomorrow if time has passed today
            }
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            cal.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }

    fun cancel(context: Context, scheduleId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, MedicationReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            scheduleId.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) ?: return
        alarmManager.cancel(pendingIntent)
    }
}
```

**Step 3: Register receiver and permissions in `AndroidManifest.xml`**

Inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Inside `<application>`:
```xml
<receiver
    android:name=".notifications.MedicationReminderReceiver"
    android:exported="false"/>
```

**Step 4: Schedule reminders when medications are added in `MedicationsViewModel.kt`**

After a medication is successfully added (find the `addMedication` function), add:

```kotlin
// Schedule reminders for each schedule
medication.schedules.forEach { schedule ->
    val parts = schedule.time.split(":")
    val hour = parts.getOrNull(0)?.toIntOrNull() ?: return@forEach
    val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
    MedicationReminderScheduler.schedule(
        context = AppContainer.context, // expose context from AppContainer
        medId = medication.id ?: return@forEach,
        scheduleId = schedule.id ?: UUID.randomUUID().toString(),
        medName = medication.name,
        timeHour = hour,
        timeMinute = minute
    )
}
```

Expose `context` from `AppContainer`:
```kotlin
// In AppContainer, add:
val context: Context get() = _context ?: throw IllegalStateException("AppContainer not initialized")
```

**Step 5: Cancel reminders on medication deletion**

After `deleteMedication` succeeds, add:
```kotlin
medication.schedules.forEach { schedule ->
    MedicationReminderScheduler.cancel(AppContainer.context, schedule.id ?: return@forEach)
}
```

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/notifications/ \
        android/app/src/main/AndroidManifest.xml \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/medications/MedicationsViewModel.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): add medication reminder notifications with AlarmManager"
```

---

### Task 13: Diet Goals Settings Sheet

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietSettingsSheet.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietScreen.kt` (line ~85)

**Step 1: Create `DietSettingsSheet.kt`**

```kotlin
package com.swasthicare.mobile.ui.screens.diet

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PrimaryColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DietSettingsSheet(
    currentCalories: Int,
    currentProtein: Int,
    currentCarbs: Int,
    currentFat: Int,
    onSave: (calories: Int, protein: Int, carbs: Int, fat: Int) -> Unit,
    onDismiss: () -> Unit
) {
    var calories by remember { mutableStateOf(currentCalories.toString()) }
    var protein by remember { mutableStateOf(currentProtein.toString()) }
    var carbs by remember { mutableStateOf(currentCarbs.toString()) }
    var fat by remember { mutableStateOf(currentFat.toString()) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text("Daily Nutrition Goals", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(20.dp))

            OutlinedTextField(
                value = calories,
                onValueChange = { calories = it },
                label = { Text("Calories (kcal)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )
            OutlinedTextField(
                value = protein,
                onValueChange = { protein = it },
                label = { Text("Protein (g)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )
            OutlinedTextField(
                value = carbs,
                onValueChange = { carbs = it },
                label = { Text("Carbohydrates (g)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )
            OutlinedTextField(
                value = fat,
                onValueChange = { fat = it },
                label = { Text("Fat (g)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp)
            )

            Button(
                onClick = {
                    onSave(
                        calories.toIntOrNull() ?: 2000,
                        protein.toIntOrNull() ?: 50,
                        carbs.toIntOrNull() ?: 250,
                        fat.toIntOrNull() ?: 65
                    )
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
            ) {
                Text("Save Goals", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
```

**Step 2: Wire into `DietScreen.kt`**

Find the TODO at line ~85:
```kotlin
// OLD:
onClick = { showMenu = false /* TODO: settings */ }
// NEW:
onClick = {
    showMenu = false
    showSettingsSheet = true
}
```

Add `var showSettingsSheet by remember { mutableStateOf(false) }` near other state.

Below the `DropdownMenu`, add:
```kotlin
if (showSettingsSheet) {
    DietSettingsSheet(
        currentCalories = uiState.dailyGoal,
        currentProtein = uiState.proteinGoalG,
        currentCarbs = uiState.carbsGoalG,
        currentFat = uiState.fatGoalG,
        onSave = { cal, prot, carb, fat -> viewModel.updateGoals(cal, prot, carb, fat) },
        onDismiss = { showSettingsSheet = false }
    )
}
```

**Step 3: Add `updateGoals()` to `DietViewModel`**

```kotlin
fun updateGoals(calories: Int, protein: Int, carbs: Int, fat: Int) {
    viewModelScope.launch {
        // Save to DataStore
        val prefs = AppContainer.sharedPreferences
        prefs.edit()
            .putInt("diet_calorie_goal", calories)
            .putInt("diet_protein_goal", protein)
            .putInt("diet_carbs_goal", carbs)
            .putInt("diet_fat_goal", fat)
            .apply()
        _uiState.update {
            it.copy(dailyGoal = calories, proteinGoalG = protein, carbsGoalG = carbs, fatGoalG = fat)
        }
    }
}
```

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietSettingsSheet.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietViewModel.kt
git commit -m "feat(android): add diet goals settings bottom sheet with local persistence"
```

---

## Phase 3 — UI Polish

---

### Task 14: Animated Premium Background

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Theme.kt`

**Step 1: Add `PremiumBackground` animated composable to `Theme.kt`**

Append to the end of `Theme.kt`:

```kotlin
@Composable
fun PremiumBackground(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition(label = "premiumBg")
    val animatedOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 8000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "bgOffset"
    )

    val gradient = Brush.linearGradient(
        colors = listOf(
            Color(0xFF0A0A1A),
            Color(0xFF0D0D2B).copy(alpha = 0.95f + animatedOffset * 0.05f),
            Color(0xFF12122A)
        ),
        start = Offset(0f, animatedOffset * 800f),
        end = Offset(800f, (1f - animatedOffset) * 800f)
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(gradient),
        content = content
    )
}
```

Add required imports:
```kotlin
import androidx.compose.animation.core.*
import androidx.compose.runtime.getValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
```

**Step 2: Apply `PremiumBackground` to `HomeScreen.kt`**

Find the outermost `Box` or `Scaffold` in `HomeScreen.kt` and wrap content with `PremiumBackground`:

```kotlin
PremiumBackground {
    // existing HomeScreen content
}
```

**Step 3: Add staggered card entry animations to Home stats cards**

In `HomeComponents.kt`, find the stat cards. Wrap each with an `AnimatedVisibility` or use `animateFloatAsState`:

```kotlin
var visible by remember { mutableStateOf(false) }
val alpha by animateFloatAsState(if (visible) 1f else 0f, tween(400, delayMillis = index * 100))
LaunchedEffect(Unit) { visible = true }

Box(modifier = Modifier.alpha(alpha)) {
    // existing card content
}
```

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Theme.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeComponents.kt
git commit -m "feat(android): add animated PremiumBackground and staggered card entry animations"
```

---

### Task 15: Typography & Color Audit

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Type.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Color.kt`

**Step 1: Update `Type.kt` to match iOS scale**

Replace the `Typography` definition:

```kotlin
val AppTypography = Typography(
    headlineLarge = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp),
    headlineMedium = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold),
    headlineSmall = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold),
    titleLarge = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Medium),
    titleMedium = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Medium),
    titleSmall = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium),
    bodyLarge = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Normal, lineHeight = 24.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Normal, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal, lineHeight = 16.sp),
    labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium),
    labelMedium = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium),
    labelSmall = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.5.sp)
)
```

**Step 2: Verify semantic colors in `Color.kt` match iOS**

Check these against `DesignSystem.swift` `AppColors`:
```kotlin
// Semantic health colors — verify these match iOS exactly
val HeartRateColor = Color(0xFFFF3B30)    // iOS: AppColors.heartRate
val HydrationColor = Color(0xFF00C7BE)    // iOS: AppColors.hydration
val MedicationColor = Color(0xFF5856D6)   // iOS: AppColors.medication
val DietColor = Color(0xFF34C759)         // iOS: AppColors.diet
val SleepColor = Color(0xFF5E5CE6)        // iOS: AppColors.sleep
val ActivityColor = Color(0xFFFF9F0A)     // iOS: AppColors.activity
val StepsColor = Color(0xFF30D158)        // iOS: AppColors.steps
val DistanceColor = Color(0xFF0A84FF)     // iOS: AppColors.distance
```

Add any missing colors to `Color.kt`.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Type.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Color.kt
git commit -m "style(android): align typography scale and semantic colors with iOS design system"
```

---

### Task 16: Tab Crossfade Animation & Dark Mode Audit

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Theme.kt`

**Step 1: Add `Crossfade` transition between tabs in `MainScreen.kt`**

Find the tab content area and wrap with `Crossfade`:

```kotlin
Crossfade(
    targetState = currentTab,
    animationSpec = tween(250),
    label = "tabContent"
) { tab ->
    when (tab) {
        MainTab.Vitals -> VitalsTabContent(...)
        MainTab.AI -> AITabContent(...)
        MainTab.Vault -> VaultTabContent(...)
        MainTab.Profile -> ProfileTabContent(...)
    }
}
```

**Step 2: Dark mode surface color audit**

In `Theme.kt`, verify `darkColorScheme` surfaces:
```kotlin
val DarkColorScheme = darkColorScheme(
    primary = PrimaryColor,
    secondary = SecondaryColor,
    background = Color(0xFF000000),
    surface = Color(0xFF1C1C1E),
    surfaceVariant = Color(0xFF2C2C2E),
    onBackground = Color.White,
    onSurface = Color.White,
    onSurfaceVariant = Color(0xFFAEAEB2)
)
```

Ensure no hardcoded `Color.White` or `Color.Black` in screen files — they should use `MaterialTheme.colorScheme.onSurface` etc.

Run on emulator in dark mode (Settings → Display → Dark theme) and spot-check all 4 tabs.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/theme/Theme.kt
git commit -m "style(android): add Crossfade tab animation and fix dark mode surface colors"
```

---

### Task 17: Empty States

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/medications/MedicationsScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt`

**Step 1: Create a reusable `EmptyStateView` composable**

Add to `android/app/src/main/kotlin/com/swasthicare/mobile/ui/components/TrackerComponents.kt` (or create a new file):

```kotlin
@Composable
fun EmptyStateView(
    emoji: String,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(emoji, fontSize = 48.sp)
        Spacer(Modifier.height(16.dp))
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(subtitle, fontSize = 14.sp, textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
    }
}
```

**Step 2: Add to each screen where list is empty**

In `VaultScreen.kt`, where the document list is displayed:
```kotlin
if (documents.isEmpty()) {
    EmptyStateView(
        emoji = "📁",
        title = "No documents yet",
        subtitle = "Upload prescriptions, lab reports, and medical records to keep them safe."
    )
}
```

In `DietScreen.kt`, for empty meal section:
```kotlin
if (meals.isEmpty()) {
    EmptyStateView(emoji = "🥗", title = "No meals logged today", subtitle = "Tap + to add breakfast, lunch, or dinner.")
}
```

In `MedicationsScreen.kt`, for empty list:
```kotlin
if (medications.isEmpty()) {
    EmptyStateView(emoji = "💊", title = "No medications added", subtitle = "Tap + to add your first medication and set reminders.")
}
```

In `AIScreen.kt`, for empty chat history (welcome state):
```kotlin
if (messages.isEmpty()) {
    EmptyStateView(
        emoji = "🤖",
        title = "Ask Swastri AI",
        subtitle = "Get personalized health insights, medication information, and wellness advice."
    )
}
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/components/ \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/diet/DietScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/medications/MedicationsScreen.kt \
        android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "style(android): add empty state illustrations to Vault, Diet, Medications, AI screens"
```

---

## Phase 4 — Pre-Launch

---

### Task 18: Firebase Crashlytics

**Files:**
- Modify: `android/build.gradle.kts` (root)
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/SwasthiCareApplication.kt`
- Add: `android/app/google-services.json` (manual — from Firebase console)

**Step 1: Add Firebase to root `build.gradle.kts`**

Find `android/build.gradle.kts`. Add to plugins block:
```kotlin
id("com.google.gms.google-services") version "4.4.0" apply false
id("com.google.firebase.crashlytics") version "2.9.9" apply false
```

**Step 2: Add to app `build.gradle.kts`**

In plugins block:
```kotlin
id("com.google.gms.google-services")
id("com.google.firebase.crashlytics")
```

In dependencies:
```kotlin
implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
implementation("com.google.firebase:firebase-crashlytics-ktx")
implementation("com.google.firebase:firebase-analytics-ktx")
```

**Step 3: Initialize in `SwasthiCareApplication.kt`**

```kotlin
class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppContainer.initialize(this)
        FirebaseApp.initializeApp(this)
    }
}
```

Add import:
```kotlin
import com.google.firebase.FirebaseApp
```

**Step 4: Download `google-services.json`**

1. Go to Firebase Console → Project Settings → Add Android app
2. Package name: `com.swasthicare.mobile`
3. Download `google-services.json`
4. Place at `android/app/google-services.json`

**Step 5: Commit**

```bash
git add android/build.gradle.kts android/app/build.gradle.kts \
        android/app/src/main/kotlin/com/swasthicare/mobile/SwasthiCareApplication.kt \
        android/app/google-services.json
git commit -m "feat(android): add Firebase Crashlytics and Analytics"
```

---

### Task 19: ProGuard Rules & App Signing

**Files:**
- Modify: `android/app/proguard-rules.pro`
- Modify: `android/app/build.gradle.kts`

**Step 1: Add ProGuard keep rules to `proguard-rules.pro`**

```pro
# Kotlin serialization
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}

# Supabase / Ktor
-dontwarn io.ktor.**
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Coil
-dontwarn coil.**

# Health Connect
-keep class androidx.health.connect.** { *; }

# Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Firebase
-keep class com.google.firebase.** { *; }
```

**Step 2: Generate release keystore (run once, store securely)**

```bash
keytool -genkey -v \
  -keystore swasthicare-release.jks \
  -alias swasthicare \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Store the keystore file outside the repo. Add `*.jks` to `.gitignore`.

**Step 3: Configure signing in `build.gradle.kts`**

In `android { }` block:
```kotlin
signingConfigs {
    create("release") {
        storeFile = file(System.getenv("KEYSTORE_PATH") ?: "../swasthicare-release.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
        keyAlias = System.getenv("KEY_ALIAS") ?: "swasthicare"
        keyPassword = System.getenv("KEY_PASSWORD") ?: ""
    }
}

buildTypes {
    release {
        isMinifyEnabled = true
        signingConfig = signingConfigs.getByName("release")
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```

**Step 4: Build signed AAB**

```bash
cd android
KEYSTORE_PATH=../swasthicare-release.jks \
KEYSTORE_PASSWORD=yourpass \
KEY_ALIAS=swasthicare \
KEY_PASSWORD=yourpass \
./gradlew bundleRelease
```

Output: `android/app/build/outputs/bundle/release/app-release.aab`

**Step 5: Commit**

```bash
git add android/app/proguard-rules.pro android/app/build.gradle.kts
git commit -m "build(android): add ProGuard rules and release signing config"
```

---

### Task 20: Final Verification & Internal Beta

**This task is manual — no code changes.**

**Step 1: Build release AAB**
```bash
cd android && ./gradlew bundleRelease
```

**Step 2: Test on 3 physical devices**

| Device | Android Version | Check |
|--------|----------------|-------|
| Device 1 | Android 8 (API 26) | Auth, Diet, Medications, AI, Vault, Profile |
| Device 2 | Android 11 (API 30) | Same + Health Connect availability check |
| Device 3 | Android 14 (API 34) | Same + Health Connect full integration |

**Verification checklist per device:**
- [ ] App launches → Splash → Onboarding (first install only)
- [ ] Consent screen scrolls and "I Agree" enables
- [ ] Login with email/password works
- [ ] Login with Google works
- [ ] Health profile questionnaire saves to Supabase
- [ ] Home tab shows real data (or graceful demo fallback)
- [ ] Diet: add a meal → shows in timeline → syncs to Supabase
- [ ] Medications: add a med → reminder notification fires at scheduled time
- [ ] AI Chat: send a message → gets real response (not demo text)
- [ ] Vault: upload a PDF → appears in list → delete works
- [ ] Profile: real name/age/BMI from Supabase
- [ ] Settings toggles persist across app restart
- [ ] Sign out → returns to Login screen
- [ ] Dark mode: all screens look correct

**Step 3: Upload to Play Console Internal Track**

1. Go to https://play.google.com/console
2. Create new app (package: `com.swasthicare.mobile`)
3. Complete store listing (description, screenshots, icon, feature graphic)
4. Release → Internal testing → Create new release
5. Upload `app-release.aab`
6. Add testers (email addresses)

**Step 4: Commit any fixes found during testing**

```bash
git add -A
git commit -m "fix(android): pre-launch testing fixes"
```

---

## Navigation State Machine (Final)

```
SplashScreen
  ├─► ForceUpdateScreen  (if server version > app version)
  └─► OnboardingScreen   (first launch only)
        └─► ConsentScreen
              └─► LoginScreen ◄─── ResetPasswordScreen
                    └─► SignUpScreen
                    └─► MainScreen (4 tabs)
                          ├─ Vitals (HomeScreen → HydrationScreen, DietScreen, MedicationsScreen)
                          ├─ AI (AIScreen)
                          ├─ Vault (VaultScreen → AddDocumentSheet)
                          └─ Profile (ProfileScreen → HealthProfileScreen if no profile)
```

---

## File Reference Summary

| Task | Files Created | Files Modified |
|------|--------------|----------------|
| 1 | — | `build.gradle.kts` |
| 2 | — | `ProfileRepository.kt`, `AppContainer.kt` |
| 3 | — | `ProfileViewModel.kt` |
| 4 | `HealthConnectService.kt` | `HomeViewModel.kt`, `AppContainer.kt`, `AndroidManifest.xml` |
| 5 | — | `VaultRepository.kt`, `VaultViewModel.kt`, `AppContainer.kt` |
| 6 | — | `AIService.kt`, `SpeechService.kt`, `AIViewModel.kt`, `AppContainer.kt` |
| 7 | `OnboardingScreen.kt` | `AppNavigation.kt`, `SplashScreen.kt`, `AppContainer.kt` |
| 8 | `ConsentScreen.kt` | `AppNavigation.kt` |
| 9 | `HealthProfileScreen.kt` | `AppNavigation.kt`, `ProfileViewModel.kt` |
| 10 | `ForceUpdateScreen.kt` | `SplashScreen.kt`, `AppNavigation.kt` |
| 11 | — | `AppContainer.kt` (config only) |
| 12 | `MedicationReminderReceiver.kt`, `MedicationReminderScheduler.kt` | `AndroidManifest.xml`, `MedicationsViewModel.kt` |
| 13 | `DietSettingsSheet.kt` | `DietScreen.kt`, `DietViewModel.kt` |
| 14 | — | `Theme.kt`, `HomeScreen.kt`, `HomeComponents.kt` |
| 15 | — | `Type.kt`, `Color.kt` |
| 16 | — | `MainScreen.kt`, `Theme.kt` |
| 17 | — | `VaultScreen.kt`, `DietScreen.kt`, `MedicationsScreen.kt`, `AIScreen.kt` |
| 18 | — | root `build.gradle.kts`, app `build.gradle.kts`, `SwasthiCareApplication.kt` |
| 19 | — | `proguard-rules.pro`, `build.gradle.kts` |
| 20 | — | Play Console (manual) |
