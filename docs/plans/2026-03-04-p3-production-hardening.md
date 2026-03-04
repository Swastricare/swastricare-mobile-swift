# P3: Android Production Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Harden the Android app for production release — fix crash paths, plug memory leaks, secure health data, and wire up analytics.

**Architecture:** Surgical fixes across repositories, ViewModels, services, and build config. No new screens. Each task targets a specific gap discovered during audit.

**Tech Stack:** Kotlin, Jetpack Compose, Supabase Kotlin SDK, Firebase (Analytics/Crashlytics), AndroidX Security (EncryptedSharedPreferences), Health Connect API

---

## Task 1: Wrap ProfileRepository Supabase Calls in try-catch

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/ProfileRepository.kt`

**Context:** `createHealthProfile` (line ~86) and `updateHealthProfile` (line ~92) have no try-catch — a Supabase network error propagates uncaught and crashes the app. `updateUserProfile` and `uploadAvatar` re-throw exceptions instead of returning `Result.failure`.

**Step 1: Wrap `createHealthProfile` in try-catch**

Change from direct call to:
```kotlin
suspend fun createHealthProfile(profile: HealthProfile): Result<HealthProfile> {
    return try {
        withContext(Dispatchers.IO) {
            val result = supabaseClient.postgrest["health_profiles"]
                .insert(profile) { select() }
                .decodeSingle<HealthProfile>()
            Result.success(result)
        }
    } catch (e: Exception) {
        Result.failure(e)
    }
}
```

**Step 2: Wrap `updateHealthProfile` the same way**

**Step 3: Fix `updateUserProfile` — return `Result.failure(e)` instead of `throw e`**

**Step 4: Fix `uploadAvatar` — return `Result.failure(e)` instead of `throw e`**

**Step 5: Update any callers** (likely `ProfileViewModel`) to handle `Result` instead of catching exceptions at the ViewModel level. If the ViewModel already wraps in try-catch, the change is backwards-compatible.

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/ProfileRepository.kt
git commit -m "fix(android): wrap ProfileRepository Supabase calls in try-catch returning Result"
```

---

## Task 2: Add Supabase Session Expiry Detection and Re-auth Navigation

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/SessionManager.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/AppContainer.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt` (or wherever the auth state is observed)

**Context:** No 401/unauthorized detection exists. When the Supabase refresh token expires, all API calls silently fail. The Supabase Kotlin SDK has `sessionStatus` flow that emits `SessionStatus.NotAuthenticated` when the token refresh fails.

**Step 1: Create `SessionManager.kt`**

```kotlin
class SessionManager(
    private val supabaseClient: SupabaseClient,
    private val authRepository: SupabaseAuthRepository
) {
    val isSessionExpired: StateFlow<Boolean>
        get() = _isSessionExpired.asStateFlow()
    private val _isSessionExpired = MutableStateFlow(false)

    fun observeSessionStatus(scope: CoroutineScope) {
        scope.launch {
            supabaseClient.auth.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.NotAuthenticated -> {
                        _isSessionExpired.value = true
                    }
                    is SessionStatus.Authenticated -> {
                        _isSessionExpired.value = false
                    }
                    else -> {}
                }
            }
        }
    }
}
```

**Step 2: Register `SessionManager` in `AppContainer`**

**Step 3: In `MainScreen` (or the app root composable), observe `sessionManager.isSessionExpired` and navigate to the login screen when `true`**

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/SessionManager.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/AppContainer.kt
git commit -m "feat(android): add session expiry detection with auto-redirect to login"
```

---

## Task 3: Wire Workout Crash Recovery (Save State During Live Workout)

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/run/LiveWorkoutViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/AppContainer.kt` (if `WorkoutStateManager` not already injected)

**Context:** `WorkoutStateManager` and `RunActivityRepository.WorkoutRecoveryState` exist but `LiveWorkoutViewModel` never calls `saveState()`. A crash during a workout saves nothing.

**Step 1: Inject `WorkoutStateManager` into `LiveWorkoutViewModel`**

**Step 2: Add periodic save every 10 seconds during active workout**

```kotlin
private var autoSaveJob: Job? = null

private fun startAutoSave() {
    autoSaveJob = viewModelScope.launch {
        while (isActive) {
            delay(10_000)
            workoutStateManager.saveState(
                SavedWorkoutState(
                    activityType = currentActivityType,
                    startTime = startTime,
                    elapsedSeconds = elapsedSeconds.value,
                    distanceMeters = distanceMeters.value,
                    routePoints = routeTracker.routePoints.value,
                    isPaused = isPaused.value
                )
            )
        }
    }
}
```

**Step 3: Call `startAutoSave()` when workout begins, cancel on workout end**

**Step 4: Call `workoutStateManager.clearState()` when workout completes normally or is discarded**

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/run/LiveWorkoutViewModel.kt
git commit -m "fix(android): wire workout crash recovery with 10s periodic auto-save"
```

---

## Task 4: Fix Camera Init Failure Handling in AR Screen

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ar/ARBodyScanScreen.kt`

**Context:** The camera init catch block (line ~216) is completely empty — no log, no state update. If the camera fails to bind, the user sees a black screen with no explanation.

**Step 1: Add error state to AR ViewModel or local state**

**Step 2: In the catch block, update state and log the error**

```kotlin
} catch (e: Exception) {
    Log.e("ARBodyScan", "Camera initialization failed", e)
    cameraError = true  // local mutableStateOf
}
```

**Step 3: Show an error message composable when `cameraError` is true**

```kotlin
if (cameraError) {
    Text(
        "Camera unavailable. Please close other camera apps and try again.",
        color = Color.White,
        modifier = Modifier.padding(16.dp)
    )
}
```

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ar/ARBodyScanScreen.kt
git commit -m "fix(android): show error message when AR camera initialization fails"
```

---

## Task 5: Fix 3D Model Loading Off Main Thread + Lifecycle Cleanup

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/components/ModelViewer.kt`

**Context:** The GLB model is loaded via `stream.readBytes()` + `ByteBuffer.allocateDirect()` on the main thread inside `View.post{}`. This can cause ANR for large models. Also, no `DisposableEffect` tears down the `SceneView`.

**Step 1: Move model loading to a background coroutine**

Replace the `View.post {}` model loading with a `LaunchedEffect` that loads on `Dispatchers.IO`:

```kotlin
var modelBuffer by remember { mutableStateOf<ByteBuffer?>(null) }

LaunchedEffect(assetPath) {
    modelBuffer = withContext(Dispatchers.IO) {
        context.assets.open(assetPath).use { stream ->
            val bytes = stream.readBytes()
            ByteBuffer.allocateDirect(bytes.size).apply {
                put(bytes)
                rewind()
            }
        }
    }
}
```

Then in the `AndroidView.update {}` block, create the model instance only when `modelBuffer` is non-null.

**Step 2: Add `DisposableEffect` to destroy SceneView resources**

```kotlin
DisposableEffect(Unit) {
    onDispose {
        // SceneView cleanup if needed
        modelNode?.destroy()
    }
}
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/components/ModelViewer.kt
git commit -m "perf(android): load 3D model off main thread and add lifecycle cleanup"
```

---

## Task 6: Fix ViewModel Lifecycle Scoping (LiveWorkout + HeartRate)

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/run/LiveWorkoutScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateScreen.kt`

**Context:** Both screens use `remember { ViewModel() }` instead of Compose's `viewModel()` factory. This bypasses lifecycle scoping — on configuration change, the old ViewModel is abandoned without `onCleared()` being called, leaking GPS callbacks and camera executors.

**Step 1: Fix `LiveWorkoutScreen`**

Replace:
```kotlin
val viewModel = remember { LiveWorkoutViewModel(context) }
```
With proper ViewModel creation using a factory or `AppContainer`:
```kotlin
val viewModel = remember { AppContainer.liveWorkoutViewModel }
```
Or use Compose `viewModel()` with a factory. Ensure `onCleared()` is called on config changes.

**Step 2: Fix `HeartRateScreen`**

Same pattern — ensure the ViewModel survives config changes but is properly cleared when the screen is removed from the back stack.

**Step 3: Add `DisposableEffect` in `HeartRateScreen` to stop measurement on navigation away**

```kotlin
DisposableEffect(Unit) {
    onDispose {
        viewModel.stopMeasurement()
    }
}
```

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/run/LiveWorkoutScreen.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateScreen.kt
git commit -m "fix(android): scope ViewModels properly to prevent GPS and camera leaks"
```

---

## Task 7: Fix PDF Viewer Memory — Bitmap Eviction + Temp File Cleanup

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/DocumentViewerScreen.kt`

**Context:** Rendered PDF page bitmaps are stored in a map and never evicted — a 20-page PDF at 2x resolution could use 380MB. Temp PDF files are never deleted.

**Step 1: Limit rendered pages to a sliding window of ±1 from current page**

Evict (recycle) bitmaps outside the window:
```kotlin
LaunchedEffect(currentVisiblePage) {
    val keepRange = (currentVisiblePage - 1)..(currentVisiblePage + 1)
    renderedPages.keys.filter { it !in keepRange }.forEach { pageNum ->
        renderedPages[pageNum]?.recycle()
        renderedPages.remove(pageNum)
    }
    // Render pages in keepRange that aren't already rendered
}
```

**Step 2: Delete temp PDF file on dispose**

```kotlin
DisposableEffect(document.fileUrl) {
    onDispose {
        pdfRenderer?.close()
        tempFile?.delete()
    }
}
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/DocumentViewerScreen.kt
git commit -m "perf(android): evict PDF bitmaps outside viewport and clean temp files"
```

---

## Task 8: Add Document Upload File Type and Size Validation

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt`

**Context:** `OpenDocument()` accepts any file type with no MIME filter and no size limit. A multi-GB file would OOM the app.

**Step 1: Add MIME type filter to file picker**

```kotlin
val filePickerLauncher = rememberLauncherForActivityResult(
    contract = ActivityResultContracts.OpenDocument()
) { uri -> ... }

// When launching:
filePickerLauncher.launch(arrayOf(
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp"
))
```

**Step 2: Add file size validation (20MB cap)**

```kotlin
uri?.let { selectedUri ->
    val size = context.contentResolver.openFileDescriptor(selectedUri, "r")?.use { it.statSize } ?: 0
    if (size > 20 * 1024 * 1024) {
        // Show error: "File too large. Maximum size is 20 MB."
        return@rememberLauncherForActivityResult
    }
    // proceed with reading
}
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultScreen.kt
git commit -m "fix(android): validate file type and size on vault document upload"
```

---

## Task 9: Enable R8 Minification for Release Builds + ProGuard Rules

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/proguard-rules.pro`

**Context:** `isMinifyEnabled = false` in release — no obfuscation, no dead code elimination, no resource shrinking. The Supabase key is trivially readable.

**Step 1: Enable minification in `build.gradle.kts`**

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro"
    )
}
```

**Step 2: Write ProGuard keep rules for serialization, Supabase, Firebase, SceneView**

```proguard
# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keep,includedescriptorclasses class com.swasthicare.mobile.**$$serializer { *; }
-keepclassmembers class com.swasthicare.mobile.** {
    *** Companion;
}
-keepclasseswithmembers class com.swasthicare.mobile.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Supabase / Ktor
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# Firebase
-keep class com.google.firebase.** { *; }

# SceneView / Filament
-keep class io.github.sceneview.** { *; }
-keep class com.google.android.filament.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }

# Health Connect
-keep class androidx.health.connect.** { *; }
```

**Step 3: Build release and test**

```bash
cd android && ./gradlew assembleRelease
```

**Step 4: Commit**

```bash
git add android/app/build.gradle.kts android/app/proguard-rules.pro
git commit -m "build(android): enable R8 minification with ProGuard keep rules"
```

---

## Task 10: Migrate Sensitive SharedPreferences to EncryptedSharedPreferences

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/AppContainer.kt`
- Modify: `android/app/build.gradle.kts` (add dependency)

**Context:** Menstrual cycles, medication names, heart rate readings, GPS routes, and AI conversations are stored in plain SharedPreferences — readable on rooted devices. EncryptedSharedPreferences uses AES-256.

**Step 1: Add AndroidX Security dependency**

```kotlin
implementation("androidx.security:security-crypto:1.1.0-alpha06")
```

**Step 2: Replace SharedPreferences creation in `AppContainer`**

```kotlin
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val sharedPreferences: SharedPreferences = EncryptedSharedPreferences.create(
    context,
    "swasthicare_prefs_encrypted",
    masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)
```

**Step 3: Add migration logic** to read from old prefs and copy to encrypted prefs on first run, then clear old prefs:

```kotlin
private fun migratePrefsIfNeeded(context: Context, encrypted: SharedPreferences) {
    val old = context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
    if (old.all.isEmpty()) return  // nothing to migrate
    encrypted.edit {
        old.all.forEach { (key, value) ->
            when (value) {
                is String -> putString(key, value)
                is Int -> putInt(key, value)
                is Boolean -> putBoolean(key, value)
                is Long -> putLong(key, value)
                is Float -> putFloat(key, value)
                is Set<*> -> putStringSet(key, value.filterIsInstance<String>().toSet())
            }
        }
    }
    old.edit { clear() }
}
```

**Step 4: Commit**

```bash
git add android/app/build.gradle.kts android/app/src/main/kotlin/com/swasthicare/mobile/data/AppContainer.kt
git commit -m "security(android): migrate SharedPreferences to EncryptedSharedPreferences"
```

---

## Task 11: Disable ADB Backup and Add Network Security Config

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/network_security_config.xml`

**Step 1: Set `android:allowBackup="false"` in manifest**

**Step 2: Create `network_security_config.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

**Step 3: Reference in manifest**

```xml
android:networkSecurityConfig="@xml/network_security_config"
```

**Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/res/xml/network_security_config.xml
git commit -m "security(android): disable ADB backup and add explicit network security config"
```

---

## Task 12: Move Supabase Key to BuildConfig Injection

**Files:**
- Modify: `android/gradle.properties`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/SupabaseConfig.kt`

**Context:** Supabase anon key is hardcoded in Kotlin source. While it's a public key, best practice is BuildConfig injection so it's not in version control and can differ per build variant.

**Step 1: Move key to `gradle.properties`**

```properties
SUPABASE_URL=https://jlumbeyukpnuicyxzvre.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...
```

**Step 2: Add `buildConfigField` in `build.gradle.kts`**

```kotlin
defaultConfig {
    buildConfigField("String", "SUPABASE_URL", "\"${project.properties["SUPABASE_URL"]}\"")
    buildConfigField("String", "SUPABASE_ANON_KEY", "\"${project.properties["SUPABASE_ANON_KEY"]}\"")
}
```

**Step 3: Update `SupabaseConfig.kt`**

```kotlin
object SupabaseConfig {
    val SUPABASE_URL: String = BuildConfig.SUPABASE_URL
    val SUPABASE_KEY: String = BuildConfig.SUPABASE_ANON_KEY
}
```

**Step 4: Commit**

```bash
git add android/gradle.properties android/app/build.gradle.kts android/app/src/main/kotlin/com/swasthicare/mobile/data/SupabaseConfig.kt
git commit -m "security(android): move Supabase credentials to BuildConfig injection"
```

---

## Task 13: Wire Analytics Calls Across All ViewModels

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AppAnalyticsService.kt` (fix `start()` vs `initialize()`)
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/run/LiveWorkoutViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateViewModel.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt` (screen view tracking)

**Context:** `AnalyticsService` has methods for workout, AI, vault, and screen views that are never called. `AppAnalyticsService.start()` doesn't register the lifecycle observer (should call `initialize()` instead).

**Step 1: Fix `AppAnalyticsService.start()` to call `initialize()` internally**

In `start()`, add the `ProcessLifecycleOwner` observer registration that currently only lives in `initialize()`.

**Step 2: Add analytics calls to LiveWorkoutViewModel**

```kotlin
analyticsService.logWorkoutStart(activityType)
// on completion:
analyticsService.logWorkoutComplete(activityType, durationSeconds, distanceKm)
```

**Step 3: Add analytics calls to AIViewModel**

```kotlin
analyticsService.logAIMessageSent(currentMode.name)
```

**Step 4: Add analytics calls to VaultViewModel**

```kotlin
analyticsService.logVaultUpload(category)
```

**Step 5: Add analytics calls to HeartRateViewModel**

```kotlin
appAnalyticsService.trackHeartbeatMeasurement(bpm, confidence)
```

**Step 6: Add screen view tracking in MainScreen tab switches**

```kotlin
LaunchedEffect(currentTab) {
    analyticsService.logScreenView(currentTab.route)
}
```

**Step 7: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AppAnalyticsService.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/run/LiveWorkoutViewModel.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/vault/VaultViewModel.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/heartrate/HeartRateViewModel.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt
git commit -m "feat(android): wire Firebase and Supabase analytics across all ViewModels"
```

---

## Task 14: Wire Crashlytics Non-Fatal Exception Reporting

**Files:**
- Modify: All repository files that catch exceptions
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/AppContainer.kt` (inject CrashlyticsService into repositories)

**Context:** `CrashlyticsService.recordException()` is defined but never called. Non-fatal exceptions from Supabase, Health Connect, etc. go unreported.

**Step 1: Add `CrashlyticsService` parameter to key repositories** (or make it accessible as a singleton)

**Step 2: In each repository's catch block, add `crashlyticsService.recordException(e)`**

Focus on the highest-value catch blocks:
- `ProfileRepository` — profile creation/update failures
- `SupabaseAuthRepository` — session check failures
- `HealthConnectService` — Health Connect read failures
- `MedicationRepository` — sync failures

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/repository/*.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthConnectService.kt
git commit -m "feat(android): report non-fatal exceptions to Crashlytics"
```

---

## Task 15: Optimize Health Connect Queries — Batch and Cache

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthConnectService.kt`

**Context:** `estimateStandHours()` makes up to 17 sequential queries (one per hour). `getWeeklyStepCounts()` makes 7 sequential queries. No caching exists.

**Step 1: Replace `estimateStandHours()` — single query for full day's step records, bucket by hour in memory**

```kotlin
private suspend fun estimateStandHours(): Int {
    val hc = client ?: return 0
    try {
        val now = LocalDate.now()
        val records = hc.readRecords(
            ReadRecordsRequest(
                StepsRecord::class,
                TimeRangeFilter.between(
                    now.atTime(6, 0).toInstant(ZoneOffset.systemDefault().rules.getOffset(Instant.now())),
                    now.atTime(22, 0).toInstant(ZoneOffset.systemDefault().rules.getOffset(Instant.now()))
                )
            )
        ).records
        return (6..21).count { hour ->
            val hourStart = now.atTime(hour, 0)
            val hourEnd = now.atTime(hour + 1, 0)
            records.any { record ->
                // Check if any record overlaps this hour and has steps > 0
                record.count > 0
            }
        }
    } catch (_: Exception) { return 0 }
}
```

**Step 2: Replace `getWeeklyStepCounts()` — single query for 7 days, group by day in memory**

Use a single `ReadRecordsRequest` for the full 7-day range, then `groupBy` the records by `LocalDate`.

**Step 3: Remove duplicate `getWeeklySteps()` function** (if identical functionality confirmed)

**Step 4: Add simple in-memory cache for `getTodaySummary()`**

```kotlin
private var cachedSummary: DailyHealthSummary? = null
private var cacheTimestamp: Long = 0

suspend fun getTodaySummary(): DailyHealthSummary {
    val now = System.currentTimeMillis()
    if (cachedSummary != null && (now - cacheTimestamp) < 60_000) {
        return cachedSummary!!
    }
    val summary = fetchTodaySummary()
    cachedSummary = summary
    cacheTimestamp = now
    return summary
}
```

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthConnectService.kt
git commit -m "perf(android): batch Health Connect queries and add 60s summary cache"
```

---

## Task 16: Move App Startup Work Off Main Thread

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/SwasthiCareApplication.kt`

**Context:** `scheduleAllNotifications()`, Firebase reflection init, and `AppAnalyticsService.start()` all run synchronously on the main thread in `Application.onCreate()`, delaying first frame.

**Step 1: Move notification scheduling to a background coroutine**

```kotlin
override fun onCreate() {
    super.onCreate()
    AppContainer.initialize(this)

    // Create channels synchronously (fast, required for immediate notifications)
    AppContainer.notificationService.createNotificationChannels()

    // Defer heavy work
    CoroutineScope(Dispatchers.Default).launch {
        AppContainer.notificationService.scheduleAllNotifications()
        AppContainer.appAnalyticsService.start()
    }

    initializeFirebase()
}
```

**Step 2: Remove redundant `AppContainer.initialize(this)` from `MainActivity.onCreate()`**

**Step 3: Remove Firebase reflection-based init** if Firebase auto-initializes via google-services plugin (it does)

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/SwasthiCareApplication.kt
git commit -m "perf(android): move notification scheduling and analytics init off main thread"
```

---

## Task 17: Add Splash Screen Network Timeout

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/splash/SplashScreen.kt`

**Context:** Splash screen blocks on a Supabase `app_config` query with no timeout. On slow/no network, the user stares at the splash indefinitely.

**Step 1: Add `withTimeoutOrNull` around the version check**

```kotlin
val config = withTimeoutOrNull(3000) {
    try {
        AppContainer.supabaseClient.postgrest["app_config"]
            .select { filter { eq("key", "min_android_version") } }
            .decodeSingleOrNull<Map<String, String>>()
    } catch (_: Exception) { null }
}
// If null (timeout or error), skip force update check and proceed
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/splash/SplashScreen.kt
git commit -m "fix(android): add 3s timeout to splash screen version check"
```

---

## Execution Order and Dependencies

| Task | Depends on | Priority |
|------|-----------|----------|
| 1. ProfileRepository try-catch | — | P0 (crash fix) |
| 2. Session expiry detection | — | P0 (crash fix) |
| 3. Workout crash recovery | — | P0 (data loss) |
| 4. AR camera error handling | — | P1 (UX) |
| 5. 3D model off-thread loading | — | P1 (ANR) |
| 6. ViewModel lifecycle scoping | — | P1 (memory leak) |
| 7. PDF bitmap eviction | — | P1 (OOM) |
| 8. Vault file validation | — | P1 (OOM) |
| 9. R8 minification + ProGuard | — | P1 (security) |
| 10. EncryptedSharedPreferences | — | P1 (security) |
| 11. Disable backup + network config | — | P2 (security) |
| 12. Supabase key to BuildConfig | — | P2 (security) |
| 13. Wire analytics | — | P2 (monitoring) |
| 14. Wire Crashlytics | — | P2 (monitoring) |
| 15. Health Connect query optimization | — | P2 (performance) |
| 16. Startup off main thread | — | P2 (performance) |
| 17. Splash timeout | — | P2 (UX) |

Tasks 1-8 are independent and can be parallelized. Tasks 9-17 are also independent.
