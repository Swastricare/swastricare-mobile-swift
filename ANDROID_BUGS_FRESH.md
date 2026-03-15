# Android Codebase Bug Audit Report

**Date**: 2026-03-07
**Scope**: Full audit of `android/app/src/main/kotlin/com/swasthicare/mobile/` (120+ files)
**Method**: Systematic file-by-file review across all layers (models, repositories, services, ViewModels, UI screens, navigation, widgets)

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High | 28 |
| Medium | 40 |
| Low | 35 |
| **Total** | **107** |

---

## Critical Bugs

### C-1. HeartRateScreen: Missing Camera Permission Check -- Crash on Android 6+

- **File**: `ui/screens/heartrate/HeartRateScreen.kt:138-142`
- **Category**: Crash / UX Bug
- **Code**:
```kotlin
else -> HeartRateIdleView(
    lastBpm = uiState.lastBpm,
    error = uiState.error,
    onStartMeasurement = { viewModel.startMeasurement(previewView, lifecycleOwner) }
)
```
- **Impact**: The "Start Measurement" button directly calls `startMeasurement()` which binds CameraX without checking or requesting the CAMERA permission. On Android 6+, this crashes with SecurityException. No permission request flow exists in this screen.
- **Fix**: Add `rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission())` to request camera permission before starting measurement.

### C-2. WorkoutSummaryScreen: Hardcoded Fake Data for Every Completed Workout

- **File**: `ui/screens/runactivity/WorkoutSummaryScreen.kt:53-61`
- **Category**: Data Bug
- **Code**:
```kotlin
val workoutType = "Running"
val duration = "32:15"
val distance = "4.25 km"
val avgPace = "7'35\"/km"
val calories = "342 kcal"
val avgHeartRate = "145 bpm"
val elevationGain = "28 m"
val steps = "5,230"
```
- **Impact**: Every completed workout shows identical fake data. User finishes a real 10km run and sees "4.25 km, 32:15" regardless of actual performance. Zero real data integration.
- **Fix**: Accept workout data via navigation arguments or retrieve the latest completed workout from the LiveWorkoutViewModel.

### C-3. Malformed `live_workout` Navigation Route Pattern

- **File**: `ui/navigation/MainNavGraph.kt:247`
- **Category**: Crash / Navigation
- **Code**:
```kotlin
composable(
    route = "live_workout?{NavArgs.WORKOUT_TYPE}={type}",
    // ...
)
```
- **Impact**: The route pattern is malformed. `{NavArgs.WORKOUT_TYPE}` is treated as a literal string rather than the constant value `"type"`. Deep links generating `"live_workout?type=run"` will fail to match this route, causing navigation failure or crash.
- **Fix**: Change route to `"live_workout?type={type}"`.

### C-4. VaultScreen: Entire File Read Into Memory on Main Thread (ANR)

- **File**: `ui/screens/vault/VaultScreen.kt:91-93, 131-133, 161`
- **Category**: ANR / Memory
- **Code**:
```kotlin
contentResolver.openInputStream(it)?.use { stream ->
    pendingFileData = stream.readBytes()  // Up to 20 MB on main thread
}
```
- **Impact**: `readBytes()` loads the entire file into a `ByteArray` in memory on the main thread. Max file size is 20 MB. For batch uploads (5 files x 20 MB = 100 MB heap), this causes `OutOfMemoryError` on low-memory devices and ANR on all devices.
- **Fix**: Store the Uri and defer file reading to `Dispatchers.IO`. Stream bytes directly to Supabase upload.

---

## High Severity Bugs

### H-1. `mapUser()` Casts JsonElement to String -- Always Returns Null

- **File**: `data/repository/SupabaseAuthRepository.kt:147-153`
- **Category**: Logic Bug
- **Code**:
```kotlin
val avatarUrl = metadata?.get("avatar_url") as? String   // JsonElement as? String => always null
val fullName = metadata?.get("full_name") as? String      // always null
```
- **Impact**: In the Supabase Kotlin SDK, `userMetadata` values are `JsonElement`, not `String`. Casting with `as? String` always returns null. Every user's avatar URL and full name will be null, even for Google OAuth users.
- **Fix**: Use `metadata?.get("avatar_url")?.jsonPrimitive?.contentOrNull`.

### H-2. `signUp()` Silently Drops `fullName` Parameter

- **File**: `data/repository/SupabaseAuthRepository.kt:75-83`
- **Category**: Data Bug
- **Code**:
```kotlin
suspend fun signUp(email: String, password: String, fullName: String): AppUser? {
    supabaseClient.auth.signUpWith(Email) {
        this.email = email
        this.password = password
        // fullName is NEVER set in user metadata!
    }
}
```
- **Impact**: The user's full name is accepted as a parameter but never sent to Supabase during sign-up. All email sign-up users have null names.
- **Fix**: Add `data = buildJsonObject { put("full_name", fullName) }` inside the signUpWith block.

### H-3. `deleteAccount()` Only Signs Out, Does Not Delete the Account

- **File**: `data/repository/SupabaseAuthRepository.kt:118-122`
- **Category**: Security / Privacy
- **Code**:
```kotlin
override suspend fun deleteAccount() {
    supabaseClient.auth.signOut()
    clearLocalData()
}
```
- **Impact**: When a user taps "Delete Account", the app only signs them out. Their account, profile, and all health data remain on the server. Privacy/compliance violation.
- **Fix**: Call a Supabase Edge Function that performs `supabase.auth.admin.deleteUser(userId)` with cascading data deletion.

### H-4. HeartRateDetector Reads Luminance Instead of Red Channel

- **File**: `data/services/HeartRateDetector.kt:242-257`
- **Category**: Logic Bug (Signal Processing)
- **Code**:
```kotlin
private fun extractRedChannelAverage(imageProxy: ImageProxy): Double {
    val yPlane = image.planes.getOrNull(0) ?: return 0.0  // Y plane = luminance, NOT red
    // ...
}
```
- **Impact**: Method is named `extractRedChannelAverage` but reads the Y (luminance) plane in YUV_420_888 format. The red channel is critical for PPG heart rate detection. The Y plane dilutes the red signal with green and blue noise, reducing BPM accuracy significantly.
- **Fix**: Convert to RGB and extract the red channel, or request RGBA output format from CameraX.

### H-5. Incorrect Bandpass Filter Math in PPGSignalProcessor

- **File**: `data/services/PPGSignalProcessor.kt:183-184`
- **Category**: Logic Bug (Signal Processing)
- **Code**:
```kotlin
val w0 = 2 * PI * ((LOW_CUTOFF_HZ + HIGH_CUTOFF_HZ) / 2) / SAMPLE_RATE
val bw = 2 * PI * (HIGH_CUTOFF_HZ - LOW_CUTOFF_HZ) / SAMPLE_RATE
val alpha = sin(bw) / 2.0  // Non-standard formulation
```
- **Impact**: The bandwidth parameter `alpha = sin(bw) / 2.0` is not a standard Butterworth formulation. This yields a very different filter response than intended, potentially producing inaccurate heart rate readings.
- **Fix**: Use standard audio EQ cookbook Butterworth bandpass coefficients.

### H-6. Hardcoded Fake Step Data Shown to Users

- **File**: `data/services/HealthConnectService.kt:489-498`
- **Category**: Data Bug
- **Code**:
```kotlin
private fun generateFallbackWeeklySteps(): List<DailyStepCount> {
    val sampleSteps = listOf(6500L, 8200L, 7800L, 9100L, 8432L, 5600L, 4200L)
    return (6 downTo 0).mapIndexed { index, dayOffset ->
        DailyStepCount(date = today.minusDays(dayOffset.toLong()), steps = sampleSteps.getOrElse(index) { 0L })
    }
}
```
- **Impact**: When Health Connect is unavailable, fabricated step data (6500, 8200, etc.) is displayed as real user data. Showing fake health data in a health app is dangerous.
- **Fix**: Return empty list or zeros and show a "no data" UI state.

### H-7. Executor Not Shut Down on Natural Measurement Completion

- **File**: `data/services/HeartRateDetector.kt:228-234`
- **Category**: Resource Leak
- **Code**:
```kotlin
if (elapsed >= MEASUREMENT_DURATION_MS) {
    _measurementState.value = MeasurementState.RESULT
    // ... camera unbind, but analysisExecutor.shutdown() is MISSING
}
```
- **Impact**: When measurement completes naturally (30s timer), the `analysisExecutor` is never shut down. Only `stopMeasurement()` shuts it down. The executor thread pool runs indefinitely.
- **Fix**: Also shut down the executor in the completion block.

### H-8. MedicationReminderScheduler.cancel() Uses Mismatched Request Code

- **File**: `notifications/MedicationReminderScheduler.kt:70-81`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun cancel(context: Context, scheduleId: String) {
    val requestCode = scheduleId.hashCode() and Int.MAX_VALUE  // Uses scheduleId ONLY
    // But schedule() uses: "${medId}_${scheduleId}".hashCode() and Int.MAX_VALUE
}
```
- **Impact**: `cancel()` and `schedule()` produce different hash codes, so `cancel()` can never find the existing PendingIntent. Users cannot stop medication reminders once scheduled.
- **Fix**: Use `"${medId}_${scheduleId}".hashCode() and Int.MAX_VALUE` in `cancel()`, adding `medId` as a parameter.

### H-9. MedicationReminderReceiver Reschedule Causes Daily Time Drift

- **File**: `notifications/MedicationReminderReceiver.kt:46-49`
- **Category**: Logic Bug
- **Code**:
```kotlin
val cal = java.util.Calendar.getInstance().apply {
    add(java.util.Calendar.DAY_OF_MONTH, 1)  // Uses CURRENT time, not original schedule time
    set(java.util.Calendar.SECOND, 0)
}
```
- **Impact**: Reschedules at current time + 1 day, not the original medication time. If the alarm fires 5 minutes late (common with Doze), this drift compounds daily. After a week, the alarm could be 35 minutes late.
- **Fix**: Pass original `timeHour`/`timeMinute` as intent extras and use them to set the exact next-day time.

### H-10. `AppAnalyticsService.stop()` Permanently Kills CoroutineScope

- **File**: `data/services/AppAnalyticsService.kt:131-135`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun stop() {
    persistQueue()
    flushJob?.cancel()
    scope.cancel()  // Permanently dead -- cannot launch new coroutines
}
```
- **Impact**: Called from `onTrimMemory()`. After this, the scope is dead: all subsequent `track()` calls, periodic flushes, and `shutdown()` silently fail. Analytics stop working permanently until app process restart.
- **Fix**: Only cancel `flushJob`, not the entire scope. Or recreate the scope in `start()`.

### H-11. RunActivity.toDto() Discards Route and Split Data

- **File**: `data/models/RunActivityModels.kt:163-176`
- **Category**: Data Bug
- **Code**:
```kotlin
fun RunActivity.toDto(profileId: String): RunActivityDto = RunActivityDto(
    routeCoordinates = null,  // "Simplified: skip route serialization for now"
    splits = null
)
```
- **Impact**: GPS route coordinates and split data are permanently lost upon sync to cloud. Route map visualizations and split analysis are destroyed.
- **Fix**: Serialize `routeCoordinates` and `splits` as JSON strings using `Json.encodeToString()`.

### H-12. AIConversation Queries Have No User Scope Filter

- **File**: `data/repository/AIConversationRepository.kt:62-66`
- **Category**: Security
- **Code**:
```kotlin
override suspend fun getConversations(): List<AIConversation> = withContext(Dispatchers.IO) {
    supabaseClient.from("ai_conversations")
        .select()  // No user_id filter!
        .decodeList<AIConversation>()
}
```
- **Impact**: If Row Level Security is misconfigured, this fetches ALL users' AI conversations. Same issue with `getBookmarkedMessages()`.
- **Fix**: Add explicit `user_id` filter as defense-in-depth.

### H-13. Duplicate RoutePoint Classes in Different Packages

- **File**: `data/model/RoutePoint.kt` and `data/services/WorkoutStateManager.kt:82-87`
- **Category**: Logic Bug / Data Loss
- **Code**:
```kotlin
// data/model/RoutePoint has: latitude, longitude, altitude, speed, timestamp
// WorkoutStateManager.RoutePoint has: latitude, longitude, timestamp (missing altitude, speed)
```
- **Impact**: Two distinct `RoutePoint` classes with different fields. Crash recovery serialization may use the wrong type, causing altitude/speed data loss or serialization failures.
- **Fix**: Remove the duplicate from `WorkoutStateManager.kt` and use `com.swasthicare.mobile.data.model.RoutePoint` everywhere.

### H-14. AIViewModel Image Analysis Sends No Actual Image Data

- **File**: `ui/screens/ai/AIViewModel.kt:229-271`
- **Category**: Logic Bug
- **Code**:
```kotlin
private fun sendImageForAnalysis(imageType: ImageType) {
    val responseText = aiService.sendChatMessage(
        "Analyze this ${imageType.label} image using MedGemma 4B model",
        priorMessages  // Only text! No image bytes/URI included
    )
}
```
- **Impact**: The `pendingImageUri` is stored in state but never read or sent. The function sends only a text prompt asking the AI to "analyze an image" without any image data. Users think their medical image is being analyzed, but only text is sent.
- **Fix**: Read image from `pendingImageUri`, convert to Base64, and pass as image attachment.

### H-15. SettingsViewModel Shows Mock "John Doe" User in Production

- **File**: `ui/screens/settings/SettingsViewModel.kt:56-64`
- **Category**: Data Bug / Security
- **Code**:
```kotlin
val mockUser = AppUser(
    id = "mock-user-1",
    email = "john.doe@example.com",
    fullName = "John Doe",
    createdAt = "2024-01-01T12:00:00Z"
)
_uiState.update { it.copy(user = mockUser, isLoading = false) }
```
- **Impact**: When no user is authenticated, a fake "John Doe" user is shown in settings and a network call is made with a fake ID.
- **Fix**: Show an unauthenticated/empty state instead.

### H-16. RunCalendarViewModel Uses 100% Hardcoded Demo Data

- **File**: `ui/screens/runactivity/RunCalendarViewModel.kt:51, 101-179`
- **Category**: Data Bug
- **Code**:
```kotlin
private val allWorkouts: List<WorkoutSummary> = generateDemoWorkouts()
private fun generateDemoWorkouts(): List<WorkoutSummary> {
    val random = Random(42)
    // ...generates 12-15 fake workouts...
}
```
- **Impact**: The Run Calendar shows entirely fake workout history. No connection to any repository or real data.
- **Fix**: Integrate with `RunActivityRepository`.

### H-17. HealthAnalyticsViewModel Uses 100% Hardcoded Demo Data

- **File**: `ui/screens/analytics/HealthAnalyticsViewModel.kt:88-164`
- **Category**: Data Bug
- **Code**:
```kotlin
private fun generateSummaryValues(type: MetricType): Pair<Float, Float> = when (type) {
    MetricType.Steps -> 8432f to 7350f
    MetricType.Calories -> 450f to 410f
    // ...all fabricated...
}
```
- **Impact**: The entire Health Analytics screen shows fabricated data. No connection to Health Connect or any repository. Users see fake step counts, heart rates, calories.
- **Fix**: Integrate with `HealthConnectService` and repositories.

### H-18. MenstrualCycleViewModel Uses 100% Hardcoded Demo Data

- **File**: `ui/screens/menstrualcycle/MenstrualCycleViewModel.kt:215-248, 360-403`
- **Category**: Data Bug
- **Code**:
```kotlin
private fun loadData() {
    val lastPeriodStart = LocalDate.now().minusDays(14) // always 14 days ago
    // ...hardcoded cycle records, symptom frequencies...
}
```
- **Impact**: Menstrual cycle tracker shows no real data. Last period start is always hardcoded to 14 days ago. User-logged data is lost on ViewModel recreation.
- **Fix**: Integrate with `MenstrualCycleRepository`.

### H-19. Auth Navigation Race Condition -- Duplicate Navigation

- **File**: `ui/screens/auth/LoginScreen.kt:54-58` and `ui/screens/auth/SignUpScreen.kt:55-59`
- **Category**: Race Condition
- **Code**:
```kotlin
LaunchedEffect(uiState) {
    if (uiState is AuthUiState.Success) {
        onNavigateToHome()  // Can fire multiple times
    }
}
```
- **Impact**: The `LaunchedEffect` re-fires every time `uiState` changes. If the user navigates back and `uiState` is still `Success`, they're immediately navigated away again. Can cause duplicate navigation entries.
- **Fix**: Use a consumed-event pattern or reset `uiState` to `Idle` after consuming `Success`.

### H-20. AddMedicationScreen Dismisses Before Save Completes

- **File**: `ui/screens/medications/AddMedicationScreen.kt:196-208`
- **Category**: Data Loss
- **Code**:
```kotlin
vm.addMedication(name = name, dosage = dosage, ...)
onDismiss()  // Called immediately, not waiting for addMedication to complete
```
- **Impact**: The screen dismisses immediately without waiting for the async save. If the save fails, the user never sees the error. Data can be silently lost.
- **Fix**: Wait for completion before dismissing. Use a callback from the ViewModel.

### H-21. ViewModels Accessed via `remember { AppContainer.viewModel }` Instead of Proper Scoping

- **File**: Multiple -- `HydrationScreen.kt:45`, `MedicationsScreen.kt:71`, `DietScreen.kt:39`, `MedicationDetailScreen.kt:37`, `HydrationSettingsScreen.kt:39`
- **Category**: State Management / Memory
- **Code**:
```kotlin
val vm = remember { AppContainer.hydrationViewModel }
```
- **Impact**: ViewModels tied to composable lifecycle rather than navigation backstack. They're never garbage collected even when the screen leaves the backstack. State from previous sessions persists unexpectedly.
- **Fix**: Use Jetpack's `viewModel()` delegate or navigation-scoped DI.

### H-22. Dynamic `startDestination` Causes NavHost Recreation

- **File**: `ui/navigation/AppNavigation.kt:137-145`
- **Category**: Logic Bug / UX
- **Code**:
```kotlin
val startDestination = when (authState) {
    is AuthUiState.Success -> "main"
    else -> "splash"
}
NavHost(navController = navController, startDestination = startDestination)
```
- **Impact**: When `authState` changes, `startDestination` changes, causing the entire `NavHost` to recreate. This destroys the back stack, causes flickering, and can lead to duplicate navigation.
- **Fix**: Keep `startDestination = "splash"` always and use `LaunchedEffect(authState)` to navigate imperatively.

### H-23. Consent DataStore Writes Race with Navigation

- **File**: `ui/navigation/AppNavigation.kt:192-198`
- **Category**: Race Condition
- **Code**:
```kotlin
onAccepted = {
    scope.launch {
        AppContainer.dataStore.edit { it[CONSENT_ACCEPTED_KEY] = true }
        AppContainer.dataStore.edit { it[ONBOARDING_COMPLETE_KEY] = true }
    }
    navController.navigate("login") { ... }  // Navigates BEFORE writes complete
}
```
- **Impact**: Navigation fires synchronously while DataStore writes are async. If the app crashes before writes complete, consent is lost and user re-sees onboarding. Two separate `edit` calls create unnecessary transactions.
- **Fix**: Combine writes in a single `edit` block and navigate inside the coroutine after writes complete.

### H-24. OnboardingScreen "Next" Button Skips All Pages

- **File**: `ui/screens/onboarding/OnboardingScreen.kt:97-111`
- **Category**: UX Bug
- **Code**:
```kotlin
Button(
    onClick = onFinished,  // Always calls onFinished, even on pages 1-3
) {
    Text(text = if (isLastPage) "Get Started" else "Next")
}
```
- **Impact**: Button says "Next" on pages 1-3 but always calls `onFinished`. Users never see all four onboarding pages unless they manually swipe.
- **Fix**: On non-last pages, animate to the next page: `scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }`.

### H-25. AIScreen Force-Unwrap `uiState.error!!` Race Condition

- **File**: `ui/screens/ai/AIScreen.kt:172`
- **Category**: Crash
- **Code**:
```kotlin
if (uiState.error != null) {
    Snackbar(...) {
        Text(uiState.error!!)  // Can be null by this point
    }
}
```
- **Impact**: If `clearError()` fires between the null check and the `!!`, the app crashes with NPE.
- **Fix**: Use `uiState.error?.let { errorMsg -> ... Text(errorMsg) }`.

### H-26. PdfRenderer Concurrent Access Can Crash

- **File**: `ui/screens/vault/DocumentViewerScreen.kt:314-345`
- **Category**: Race Condition / Crash
- **Code**:
```kotlin
LaunchedEffect(currentVisiblePage) {
    withContext(Dispatchers.IO) {
        val page = renderer.openPage(pageIndex)  // PdfRenderer is NOT thread-safe
    }
}
```
- **Impact**: Fast scrolling causes multiple coroutines to call `renderer.openPage()` concurrently, leading to `IllegalStateException: Current page not closed` or native crashes.
- **Fix**: Use a `Mutex` to serialize access to the PdfRenderer.

### H-27. ARBodyScanScreen Camera Not Unbound in DisposableEffect

- **File**: `ui/screens/ar/ARBodyScanScreen.kt:193-197, 199-239`
- **Category**: Resource Leak
- **Code**:
```kotlin
DisposableEffect(Unit) {
    onDispose {
        cameraExecutor.shutdown()
        // Missing: cameraProvider?.unbindAll()
    }
}
```
- **Impact**: Camera stays active after navigating away, consuming battery. Can cause conflicts when another screen tries to open the camera.
- **Fix**: Store `cameraProvider` reference and call `unbindAll()` in `onDispose`.

### H-28. NotificationHistoryScreen ViewModel Created via `remember` -- Loses State on Rotation

- **File**: `ui/screens/notifications/NotificationHistoryScreen.kt:190`
- **Category**: Memory / Logic Bug
- **Code**:
```kotlin
val vm: NotificationHistoryViewModel = remember { NotificationHistoryViewModel() }
```
- **Impact**: `remember` does not survive configuration changes. Each rotation creates a new ViewModel, losing all loaded state. Old ViewModel's `onCleared()` is never called, leaking coroutine scopes.
- **Fix**: Use `viewModel()` delegate.

---

## Medium Severity Bugs

### M-1. MedicationsViewModel Produces Corrupt Time Strings

- **File**: `ui/screens/medications/MedicationsViewModel.kt:318-320`
- **Category**: Data Bug
- **Code**:
```kotlin
timeOfDay = time.padEnd(8, ':').take(8)  // "08:00" -> "08:00:::"  -> "08:00:::"
```
- **Impact**: Corrupt time strings break schedule parsing and may cause medication reminders to fail.
- **Fix**: Use `if (time.length == 5) "$time:00" else time.take(8)`.

### M-2. HomeViewModel.incrementHydration Does Not Persist to Repository

- **File**: `ui/screens/home/HomeViewModel.kt:171-176`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun incrementHydration() {
    _uiState.value = current.copy(hydrationCurrent = current.hydrationCurrent + 250)
    // No HydrationEntry created, nothing persisted
}
```
- **Impact**: Quick-add hydration on home screen is in-memory only. Lost on navigation or app restart.
- **Fix**: Create a `HydrationEntry` via `hydrationRepository.addLocalEntry()`.

### M-3. HomeViewModel Medications Always Shows 0/0

- **File**: `ui/screens/home/HomeViewModel.kt:125-126`
- **Category**: Data Bug
- **Code**:
```kotlin
medicationsTaken = 0,
medicationsTotal = 0,
```
- **Impact**: Home screen medication card always shows 0/0 even when medications exist.
- **Fix**: Load from `MedicationRepository` and compute today's stats.

### M-4. HomeViewModel.requestHealthPermissions Fakes Permission Grant

- **File**: `ui/screens/home/HomeViewModel.kt:187-191`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun requestHealthPermissions() {
    _uiState.value = _uiState.value.copy(isAuthorized = true, isDemoMode = false)
    // No actual permission request!
}
```
- **Impact**: UI pretends Health Connect access was granted without actually requesting. Subsequent Health Connect calls fail silently.
- **Fix**: Call `healthConnectService.requestPermissions()` and set `isAuthorized` based on actual result.

### M-5. Division by Zero in ProfileViewModel BMI Calculation

- **File**: `ui/screens/profile/ProfileViewModel.kt:229-233` and `ui/screens/settings/SettingsViewModel.kt:203-209`
- **Category**: Crash
- **Code**:
```kotlin
val heightM = profile.heightCm / 100.0
val bmi = profile.weightKg / (heightM * heightM)  // heightCm=0 -> Infinity
```
- **Impact**: If `heightCm` is 0 (new profile with no height), division by zero produces "Infinity" in the UI.
- **Fix**: Add guard: `if (heightM <= 0) return "Not set"`.

### M-6. Division by Zero in DietViewModel.logFood

- **File**: `ui/screens/diet/DietViewModel.kt:115`
- **Category**: Crash
- **Code**:
```kotlin
val multiplier = quantity / item.servingSize  // servingSize could be 0
```
- **Impact**: If `servingSize` is 0 from a corrupt database record, this produces Infinity/NaN.
- **Fix**: Guard: `if (item.servingSize > 0) quantity / item.servingSize else 0.0`.

### M-7. Profile/Settings Toggle Changes Not Persisted

- **File**: `ui/screens/profile/ProfileViewModel.kt:118-128` and `ui/screens/settings/SettingsViewModel.kt:95-105`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun toggleNotifications(enabled: Boolean) {
    _uiState.update { it.copy(notificationsEnabled = enabled) }
    // Never written to SharedPreferences
}
```
- **Impact**: All toggle states (notifications, biometric, health sync) reset to defaults on ViewModel recreation. Biometric toggle is disconnected from `LockScreenViewModel`'s `prefs.getBoolean("biometric_enabled")`.
- **Fix**: Read/write to SharedPreferences.

### M-8. ProfileViewModel.deleteAccount Does Not Navigate to Login

- **File**: `ui/screens/profile/ProfileViewModel.kt:163-183`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun deleteAccount() {
    authRepository.deleteAccount()
    _uiState.update { it.copy(user = null, ...) }
    // Missing: _signOutEvent.value = true
}
```
- **Impact**: After deletion, user stays on blank profile screen. Compare with `SettingsViewModel.deleteAccount()` which correctly sets `_signOutEvent.value = true`.
- **Fix**: Add `_signOutEvent.value = true`.

### M-9. `WorkoutDetail` Missing `@SerialName` Annotations

- **File**: `data/model/WorkoutDetail.kt:6-21`
- **Category**: Data Bug
- **Code**:
```kotlin
val startTime: String,      // missing @SerialName("start_time")
val endTime: String,        // missing @SerialName("end_time")
val durationSeconds: Long,  // missing @SerialName("duration_seconds")
```
- **Impact**: Deserialization from Supabase (snake_case) will fail or silently produce defaults.
- **Fix**: Add `@SerialName` annotations or configure `JsonNamingStrategy.SnakeCase`.

### M-10. `RoutePoint.timestamp` Default Evaluated at Deserialization Time

- **File**: `data/model/RoutePoint.kt:11`
- **Category**: Data Bug
- **Code**:
```kotlin
val timestamp: Long = System.currentTimeMillis()  // Wrong for deserialized historical data
```
- **Impact**: Deserializing historical routes without a timestamp field produces current time, corrupting the data.
- **Fix**: Default to `0L`.

### M-11. `fetchFoodItems()` Ignores the `limit` Parameter

- **File**: `data/repository/DietRepository.kt:114-126`
- **Category**: Logic Bug
- **Code**:
```kotlin
override suspend fun fetchFoodItems(limit: Int): Result<List<FoodItem>> {
    val items = supabaseClient.from("food_items").select { ... }.decodeList<FoodItem>()
    // 'limit' parameter never applied to query
}
```
- **Impact**: All rows fetched regardless of caller's limit. Wastes bandwidth/memory as table grows.
- **Fix**: Add `limit(limit.toLong())` in the select builder.

### M-12. `MenstrualCycleRepository.saveLocalCycles` Saves with Empty profileId

- **File**: `data/repository/MenstrualCycleRepository.kt:68-70`
- **Category**: Data Bug
- **Code**:
```kotlin
override fun saveLocalCycles(cycles: List<MenstrualCycle>) {
    val dtos = cycles.map { it.toDto("") }  // profileId = ""
}
```
- **Impact**: Local cycles have empty `health_profile_id`. Same issue in `saveLocalDailyLogs` and `RunActivityRepository.saveLocalActivities`.
- **Fix**: Pass real `profileId` or strip it for local-only storage.

### M-13. `generateCalendarData` Hardcodes Cycle Length to 28

- **File**: `data/repository/MenstrualCycleRepository.kt:325`
- **Category**: Logic Bug
- **Code**:
```kotlin
val cycleLen = 28  // Hardcoded instead of using settings.averageCycleLength
```
- **Impact**: Users with non-28-day cycles see incorrect phase coloring on the calendar.
- **Fix**: Use `settings.averageCycleLength`.

### M-14. `FamilyRepository.joinGroup` Uses `decodeSingleOrNull` -- Crashes on Multiple Results

- **File**: `data/repository/FamilyRepository.kt:89-91`
- **Category**: Crash
- **Code**:
```kotlin
val existingMember = supabaseClient.from("family_members")
    .select { filter { eq("user_id", userId) } }
    .decodeSingleOrNull<FamilyMember>()  // Throws if >1 result
```
- **Impact**: If a data integrity issue causes duplicate family_member records, this crashes.
- **Fix**: Use `.decodeList<FamilyMember>().firstOrNull()`.

### M-15. `HydrationEntry.effectiveMl` Always Defaults to 0

- **File**: `data/models/HydrationModels.kt:58-66`
- **Category**: Logic Bug
- **Code**:
```kotlin
@SerialName("effective_ml") val effectiveMl: Int = 0,  // Never auto-computed
```
- **Impact**: If caller forgets to set it, hydration calculations using `effectiveMl` show 0ml.
- **Fix**: Make it a computed property or ensure all creation paths set it.

### M-16. `expandScheduleTimes` Integer Division Produces Uneven Intervals

- **File**: `data/models/MedicationModels.kt:212-219`
- **Category**: Logic Bug
- **Code**:
```kotlin
val intervalHours = 24 / count  // For count=7, interval=3 (21h total, missing 3h)
```
- **Impact**: Unevenly distributed medication times for certain counts.
- **Fix**: Use floating-point division for interval calculation.

### M-17. `createHealthProfile` Returns Profile Without Server-Generated ID

- **File**: `data/repository/ProfileRepository.kt:90-99`
- **Category**: Data Bug
- **Code**:
```kotlin
supabaseClient.postgrest["health_profiles"].insert(profile)
Result.success(profile)  // Returns original profile with id=null
```
- **Impact**: Caller never gets the server-generated ID needed for subsequent operations.
- **Fix**: Use `.insert(profile) { select() }.decodeSingle<HealthProfile>()`.

### M-18. `syncCyclesToCloud` Marks All as Synced Even if Upsert Fails

- **File**: `data/repository/MenstrualCycleRepository.kt:73-89`
- **Category**: Data Bug
- **Impact**: Cycles marked synced but stored with empty profileId from M-12.
- **Fix**: Fix M-12 first, then ensure sync status is set correctly.

### M-19. `DietLogEntry.id` UUID Default Breaks Upsert Deduplication

- **File**: `data/models/DietModels.kt:108` (same pattern in 10+ model classes)
- **Category**: Data Bug
- **Code**:
```kotlin
val id: String = UUID.randomUUID().toString()  // New ID on every deserialization
```
- **Impact**: If server response omits `id`, each deserialization creates a different ID for the same record, causing duplicates.
- **Fix**: Default to `""` to make missing-id detectable.

### M-20. HealthConnectService Cache Not Thread-Safe

- **File**: `data/services/HealthConnectService.kt:101-102, 144-153`
- **Category**: Race Condition
- **Code**:
```kotlin
private var cachedSummary: DailyHealthSummary? = null
private var cacheTimestamp: Long = 0L
```
- **Impact**: Non-atomic reads of `cachedSummary` and `cacheTimestamp` from `Dispatchers.IO` can return inconsistent pairs.
- **Fix**: Use `@Volatile`, `Mutex`, or `AtomicReference`.

### M-21. LocationTrackingService Calorie Calculation ~15x Too Low

- **File**: `data/services/LocationTrackingService.kt:195-203`
- **Category**: Logic Bug
- **Code**:
```kotlin
_caloriesBurned.value = (_totalDistanceMeters.value * factor * DEFAULT_WEIGHT_KG / 1000).toInt()
// 1000m running at 70kg: 1000 * 0.063 * 70 / 1000 = 4.41 kcal (should be ~70)
```
- **Impact**: Displayed calories are about 15x too low. A 5km run shows ~22 kcal instead of ~350.
- **Fix**: Remove the `/1000` and adjust factors to kcal/kg/km standard values.

### M-22. SpeechService `isSpeaking` Never Resets After TTS Completes

- **File**: `data/services/SpeechService.kt:129-137`
- **Category**: Logic Bug
- **Code**:
```kotlin
fun speak(text: String) {
    textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "UtteranceId")
    isSpeaking = true  // Never set to false when TTS finishes naturally
}
```
- **Impact**: Any UI checking `isSpeaking` shows "speaking" indicator permanently.
- **Fix**: Register an `UtteranceProgressListener` to set `isSpeaking = false` in `onDone()`.

### M-23. SpeechService Created Off Main Thread Risks Crash

- **File**: `data/services/SpeechService.kt:17, 31-33`
- **Category**: Crash
- **Code**:
```kotlin
private val speechRecognizer: SpeechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
```
- **Impact**: `SpeechRecognizer` must be created on the main thread. If instantiated from a background thread, throws RuntimeException.
- **Fix**: Assert main thread in constructor or defer creation.

### M-24. SpeechService Callback Lambdas Leak Activity References

- **File**: `data/services/SpeechService.kt:21-23`
- **Category**: Memory Leak
- **Code**:
```kotlin
private var onResult: ((String) -> Unit)? = null
private var onError: ((String) -> Unit)? = null
```
- **Impact**: Lambdas capture UI references, preventing garbage collection of destroyed Activities.
- **Fix**: Clear callbacks after results are delivered.

### M-25. AIService.sendChatMessage Has No Exception Handling

- **File**: `data/services/AIService.kt:16-31`
- **Category**: Crash
- **Code**:
```kotlin
suspend fun sendChatMessage(message: String, context: List<ChatMessage>): String {
    val response = client.functions.invoke(function = "ai-router", body = request)
    return Json.decodeFromString<ChatResponse>(body).response
    // No try-catch -- any network/parsing error propagates
}
```
- **Impact**: Unlike `analyzeHealth()` which has a try-catch, this method lets exceptions propagate and crash.
- **Fix**: Add try-catch.

### M-26. WeatherService Empty API Key Produces Silent Failures

- **File**: `data/services/WeatherService.kt:62`
- **Category**: Logic Bug
- **Code**:
```kotlin
private val API_KEY = BuildConfig.OPENWEATHERMAP_API_KEY  // defaults to ""
```
- **Impact**: Weather-adjusted hydration never works in builds without the key. No warning logged.
- **Fix**: Check if blank before making HTTP request and log a warning.

### M-27. WeatherService Cache Uses Pipe-Delimited Serialization

- **File**: `data/services/WeatherService.kt:138-143`
- **Category**: Data Bug
- **Code**:
```kotlin
.putString(CACHE_KEY, "${data.temperatureCelsius}|${data.description}|${data.city}")
```
- **Impact**: If description or city contains `|`, deserialization produces incorrect data.
- **Fix**: Use JSON serialization.

### M-28. NotificationReceiver Creates New NotificationService Instead of Using Singleton

- **File**: `data/services/NotificationReceiver.kt:26-28`
- **Category**: Logic Bug
- **Code**:
```kotlin
val notificationService = NotificationService(context, prefs)  // New instance every broadcast
```
- **Impact**: Bypasses `AppContainer.notificationService` singleton; state is not shared.
- **Fix**: Use `AppContainer.notificationService`.

### M-29. Quiet Hours End-Boundary Is Inclusive (Off-by-One)

- **File**: `data/services/NotificationService.kt:389-396`
- **Category**: Logic Bug
- **Code**:
```kotlin
hour >= start || hour <= end  // hour 7 (7:00-7:59) is considered quiet
```
- **Impact**: With defaults `start=22, end=7`, notifications are suppressed until 8:00 AM. Users expect first notification at 7:00.
- **Fix**: Change `hour <= end` to `hour < end`.

### M-30. MedicationReminderReceiver Uses Inexact Alarms for Reschedule

- **File**: `notifications/MedicationReminderReceiver.kt:62-63`
- **Category**: Logic Bug
- **Code**:
```kotlin
alarmManager.setAndAllowWhileIdle(...)  // Original uses setExactAndAllowWhileIdle
```
- **Impact**: Rescheduled medication reminders can be delayed up to 10 minutes by Doze batching.
- **Fix**: Check `canScheduleExactAlarms()` and use `setExactAndAllowWhileIdle()` when available.

### M-31. ACTION_MARK_MED_TAKEN Notification Quick Action Is a No-Op

- **File**: `data/services/NotificationReceiver.kt:124-128`
- **Category**: Logic Bug (Stub)
- **Code**:
```kotlin
NotificationService.ACTION_MARK_MED_TAKEN -> {
    Log.d(TAG, "Quick action: mark medication $medicationId taken")
    // No actual update -- just a log statement
}
```
- **Impact**: Tapping "Mark as Taken" on a medication notification does nothing.
- **Fix**: Implement actual medication state update via repository.

### M-32. Duplicate ForceUpdateScreen Files

- **File**: `ui/screens/splash/ForceUpdateScreen.kt` and `ui/screens/update/ForceUpdateScreen.kt`
- **Category**: Logic Bug / UX
- **Impact**: Two different implementations. The splash version is basic (no version info, no back-button blocking). Users hitting force update via splash get a worse, escapable screen.
- **Fix**: Delete the splash-package version, use the update-package version everywhere.

### M-33. PoseDetectionService ML Kit Detector Never Closed in Normal Path

- **File**: `data/services/PoseDetectionService.kt:35-40, 184-186`
- **Category**: Resource Leak
- **Impact**: If caller forgets to call `close()`, native ML Kit resources leak indefinitely.
- **Fix**: Implement `Closeable` interface. Add flag to prevent processing after close.

### M-34. AppAnalyticsService Duplicate `app_open` Events on Cold Start

- **File**: `data/services/AppAnalyticsService.kt:115-124, 154-157`
- **Category**: Data Bug
- **Code**:
```kotlin
fun start() { track("app_open") }       // Called in Application.onCreate
override fun onStart() { track("app_open") }  // Lifecycle observer also fires
```
- **Impact**: Every cold start produces 2 `app_open` events, inflating analytics.
- **Fix**: Remove `track("app_open")` from `start()`.

### M-35. AppAnalyticsService Event Deduplication Missing

- **File**: `data/services/AppAnalyticsService.kt:338-343, 361-374`
- **Category**: Data Bug
- **Impact**: Failed flush re-adds events to queue and persists them. On next restart, `loadPersistedEvents()` loads them again. Events can be duplicated.
- **Fix**: Add deduplication by event `id` when loading persisted events.

### M-36. Three Conflicting `PremiumBackground` Composable Definitions

- **File**: `ui/screens/home/HomeComponents.kt:137`, `ui/screens/auth/components/AuthComponents.kt:417`, `ui/theme/Theme.kt:79`
- **Category**: Logic Bug
- **Impact**: Three different implementations with different signatures. Easy to import wrong one. Inconsistent visual treatment across screens.
- **Fix**: Consolidate into a single version in the theme package.

### M-37. LockScreen Unsafe Cast to FragmentActivity

- **File**: `ui/lock/LockScreen.kt:50`
- **Category**: Crash
- **Code**:
```kotlin
val activity = context as? FragmentActivity  // null if ContextThemeWrapper
```
- **Impact**: If null, biometric auth silently fails. User is permanently locked out with no feedback.
- **Fix**: Display error when activity is null or unwrap context.

### M-38. Theme SideEffect Unsafe Cast to Activity

- **File**: `ui/theme/Theme.kt:63`
- **Category**: Crash
- **Code**:
```kotlin
val window = (view.context as Activity).window  // Unsafe cast
```
- **Impact**: `ClassCastException` if context is a `ContextThemeWrapper`.
- **Fix**: Use safe cast: `val activity = view.context as? Activity ?: return@SideEffect`.

### M-39. Widget Data Staleness -- No Daily Reset

- **File**: `widgets/WidgetDataManager.kt`
- **Category**: Data Bug
- **Impact**: No timestamp tracking. Hydration widget accumulates across days with no daily reset. If app not opened next day, widget shows yesterday's total.
- **Fix**: Store `lastUpdatedDate` and reset daily values when date changes.

### M-40. BottomNav Shown on All Nested Detail Screens

- **File**: `ui/navigation/NavConfig.kt:66-80`
- **Category**: UX Bug
- **Impact**: Bottom nav shown on detail/form screens (medications, hydration, diet, etc.) where it's redundant. Parameterized routes like `"medication_detail/{id}"` never match `hiddenRoutes` exact-string set.
- **Fix**: Use `startsWith` matching and consider hiding on all non-tab routes.

---

## Low Severity Bugs

### L-1. `SwasthiCareApplication.onCreate` Launches Analytics on Wrong Thread
- **File**: `SwasthiCareApplication.kt:36-49`
- `ProcessLifecycleOwner.addObserver()` requires main thread but called from `Dispatchers.Default`.

### L-2. Unscoped CoroutineScope in SwasthiCareApplication
- **File**: `SwasthiCareApplication.kt:36`
- No `SupervisorJob()` or exception handling for `scheduleAllNotifications()`.

### L-3. SessionManager Scope Never Cancelled
- **File**: `data/services/SessionManager.kt:32`
- Process-scoped singleton; acceptable but no `destroy()` method.

### L-4. AppAnalyticsService `ConcurrentLinkedQueue.size` Is O(n)
- **File**: `data/services/AppAnalyticsService.kt:183-186`
- Queue size check in while loop: O(n^2) when queue is near capacity.

### L-5. NotificationReceiver Does Not Dismiss Notification After Quick Action
- **File**: `data/services/NotificationReceiver.kt:98-121`
- User can tap "Log 250ml" multiple times, logging duplicate entries.

### L-6. ACTION_LOG_MEAL Quick Action Is a No-Op
- **File**: `data/services/NotificationReceiver.kt:130-133`
- Tapping "Log Meal" on a diet notification does nothing.

### L-7. PPGSignalProcessor Filter Coefficients Recomputed Every Sample
- **File**: `data/services/PPGSignalProcessor.kt:180-207`
- Trigonometric functions computed ~30x/second unnecessarily.

### L-8. PPGSignalProcessor Unbounded Buffer Growth
- **File**: `data/services/PPGSignalProcessor.kt:30-31`
- `rawBuffer` and `filteredBuffer` grow without bound; `detectPeaks()` iterates entire buffer every frame: O(n^2).

### L-9. LocationTrackingService Location Updates on Main Thread
- **File**: `data/services/LocationTrackingService.kt:105-109`
- Haversine calculations on main thread. Minor concern at 3-5s intervals.

### L-10. GoogleAuthHelper Dead Code (Unused Nonce Methods)
- **File**: `data/helpers/GoogleAuthHelper.kt:106-115`
- `generateNonce()` and `hashNonce()` defined but never called.

### L-11. WorkoutNotificationService Stop Receiver Race Condition
- **File**: `data/services/WorkoutNotificationService.kt:17-22, 64-67`
- `unregisterReceiver` could throw if receiver never registered. Stop button doesn't stop actual workout tracking.

### L-12. `HydrationEntry.formattedTime` Displays Garbage for Non-ISO Strings
- **File**: `data/models/HydrationModels.kt:70-84`
- If `consumedAt` lacks "T" separator, displays garbage like "2026-" as time.

### L-13. QuickAction.suggestions Uses iOS SF Symbol Icon Names on Android
- **File**: `data/models/AIModels.kt:79-84`
- Icons like `"waveform.path.ecg"`, `"moon.fill"` won't resolve on Android.

### L-14. AIFeature Enum Uses iOS SF Symbol Icon Names
- **File**: `data/models/AIModels.kt:26-28`
- Same issue as L-13.

### L-15. `HealthMetrics.sleep` Stored as Human-Readable String
- **File**: `data/models/AIModels.kt:90-103`
- `isEmpty()` does exact string comparison with `"0h 0m"`. Any format variation breaks it.

### L-16. MockVaultRepository Non-Thread-Safe List
- **File**: `data/repository/VaultRepository.kt:30`
- `mutableListOf()` accessed from multiple suspend functions. Low risk since not used in production.

### L-17. LiveWorkoutViewModel Hardcodes 70kg for Calories
- **File**: `ui/screens/runactivity/LiveWorkoutViewModel.kt:243`
- Calorie estimation uses 70kg regardless of user's actual weight.

### L-18. HeartRateViewModel `resultHandled` Flag Not Thread-Safe
- **File**: `ui/screens/heartrate/HeartRateViewModel.kt:79, 115-117`
- Plain Boolean check-then-set in a coroutine; could handle result twice.

### L-19. LockScreenViewModel Locks on Every Resume Without Grace Period
- **File**: `ui/lock/LockScreenViewModel.kt:30-34`
- No grace period. Switching apps briefly requires re-authentication.

### L-20. HomeViewModel.syncToCloud Is a No-Op
- **File**: `ui/screens/home/HomeViewModel.kt:193-195`
- Empty function body.

### L-21. AuthViewModel Uses errorMessage for Success Message
- **File**: `ui/screens/auth/AuthViewModel.kt:216`
- Success message displayed through error channel; may show with red styling.

### L-22. HomeViewModel Error Path Swallows All Errors Silently
- **File**: `ui/screens/home/HomeViewModel.kt:137-140`
- No error state shown to user; blank screen with no retry option.

### L-23. RunActivityViewModel Error Path Swallows Errors Silently
- **File**: `ui/screens/runactivity/RunActivityViewModel.kt:70-72`
- `RunActivityUiState` has an `error` field but it is never set.

### L-24. HydrationViewModel.loadData Has No Error Handling
- **File**: `ui/screens/hydration/HydrationViewModel.kt:94-119`
- Exception crashes coroutine; UI stuck in `isLoading = true` forever.

### L-25. DietViewModel.syncInBackground Can Crash
- **File**: `ui/screens/diet/DietViewModel.kt:296-313`
- `resolveProfileId()` throws if no authenticated user; no try-catch.

### L-26. Non-Atomic State Updates Across Multiple ViewModels
- **File**: Multiple ViewModels (HomeViewModel, HydrationViewModel, DietViewModel, RunActivityViewModel, AuthViewModel)
- `_uiState.value = _uiState.value.copy(...)` is not atomic; concurrent coroutines can overwrite each other's updates.
- **Fix**: Use `_uiState.update { it.copy(...) }`.

### L-27. ARBodyScanViewModel Uses Hardcoded Health Values
- **File**: `ui/screens/ar/ARBodyScanViewModel.kt:44-48`
- Hardcoded 72 BPM, 45 min exercise, 1240 cal, etc. Never fetches real data.

### L-28. ARBodyScanViewModel.frameCounter Integer Overflow
- **File**: `ui/screens/ar/ARBodyScanViewModel.kt:62, 73-78`
- At 30fps, overflows after ~828 days. Produces negative modulus values after overflow.

### L-29. SplashScreen Never Checks If User Is Already Authenticated
- **File**: `ui/screens/splash/SplashScreen.kt:97-107`
- Always goes to login even with active session. `onNavigateToHome` callback is never used.

### L-30. MedicationDetailScreen Infinite Loading Spinner for Missing Medication
- **File**: `ui/screens/medications/MedicationDetailScreen.kt:63-65`
- If medication ID is invalid, spinner shows forever. No back button visible.

### L-31. DietSettingsSheet Doesn't Validate Macro Percentages Sum to 100%
- **File**: `ui/screens/diet/DietSettingsSheet.kt:72-83`
- User can set protein=80%, carbs=80%, fat=80% (240% total).

### L-32. HydrationSettingsScreen Weather Adjustment Toggle Not Persisted
- **File**: `ui/screens/hydration/HydrationSettingsScreen.kt:48, 207-209`
- Toggle updates local variable only; never saved when "Save" is pressed.

### L-33. Widget "Start Run" Button Does Not Deep Link
- **File**: `widgets/RunWidget.kt:150-167, 190-208`
- Deep-link intent created but never used. Button opens home screen instead of live workout.

### L-34. WidgetActionReceiver Silently Swallows All Exceptions
- **File**: `widgets/WidgetActionReceiver.kt:76, 105`
- Widget quick actions ("+250ml", "Mark Taken") fail silently with no user feedback.

### L-35. Medication Widget Shows "All done!" After Single Dose
- **File**: `widgets/WidgetActionReceiver.kt:96-101`
- After marking one medication taken, widget shows "All done!" without checking remaining doses.

---

## Patterns of Concern

### 1. Pervasive Hardcoded Demo Data (8 instances)
WorkoutSummaryScreen, RunCalendarViewModel, HealthAnalyticsViewModel, MenstrualCycleViewModel, ARBodyScanViewModel, SettingsViewModel mock user, HealthConnectService fake steps, and HomeViewModel (0/0 medications). Significant portions of the app display fabricated health data to users.

### 2. Missing Error Feedback (12+ instances)
Most ViewModels either swallow errors silently, show infinite loading states on failure, or use no-op stubs. Users get no retry options or explanations when operations fail.

### 3. `remember` Instead of `viewModel()` (6+ instances)
Feature screens use `remember { AppContainer.viewModel }` which doesn't survive configuration changes and never calls `onCleared()`.

### 4. Force-Unwrap `!!` in Compose (3+ instances)
AI Screen, ActivityDetailScreen, and ARBodyScanScreen use `!!` on state values that can be nulled concurrently.

### 5. iOS-to-Android Port Artifacts
SF Symbol icon names used on Android, missing snake_case `@SerialName` annotations, auth metadata parsing copied without adapting to Kotlin SDK types.

---

*Generated by comprehensive file-by-file audit of 120+ Kotlin files across all layers of the Android codebase.*
