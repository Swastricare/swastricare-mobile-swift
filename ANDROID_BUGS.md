# Android Bug Report

> **Generated**: 2026-03-04 | **Branch**: android-nikhil
> **Total Bugs**: 28 (3 Critical, 10 High, 12 Medium, 3 Low)

---

## CRITICAL — Must Fix Before Launch

### BUG-1: HomeViewModel uses hardcoded demo data everywhere
**File**: `ui/screens/home/HomeViewModel.kt:79-101`
```kotlin
stepCount = 8432,        // FAKE
calories = 450,          // FAKE
activeMinutes = 45,      // FAKE
heartRate = 72,          // FAKE
distance = 5.2,          // FAKE
hydrationCurrent = 1250, // FAKE
medicationsTaken = 2,    // FAKE
calorieCurrent = 1240,   // FAKE
userName = "Alex Johnson" // FAKE
```
**Impact**: Users see fake health data on the main dashboard. None of the home screen metrics are real.
**Fix**: Wire to `HealthConnectService`, `HydrationRepository`, `MedicationRepository`, `DietRepository`.

---

### BUG-2: RunActivityViewModel uses hardcoded demo data
**File**: `ui/screens/runactivity/RunActivityViewModel.kt:59-61`
```kotlin
todaySteps = 8432,     // FAKE
todayDistance = 5.2,   // FAKE
todayCalories = 450    // FAKE
```
**Impact**: Steps tab shows fake data.
**Fix**: Read from `HealthConnectService.getTodaySteps()` etc.

---

### BUG-3: AI "Analyze My Health" sends fake metrics to AI
**File**: `ui/screens/ai/AIViewModel.kt:350-358`
```kotlin
val metrics = HealthMetrics(
    steps = 5432,              // FAKE
    heartRate = 72,            // FAKE
    sleep = "7h 15m",         // FAKE
    activeCalories = 320,     // FAKE
    bloodPressure = "120/80", // FAKE
    weight = "70.5"           // FAKE
)
```
**Impact**: AI analyzes fake data, gives irrelevant health advice. Dangerous in a health app.
**Fix**: Fetch real metrics from HealthConnect and user's health profile.

---

## HIGH — Serious Bugs

### BUG-4: HeartRateDetector executor shutdown kills reuse
**File**: `data/services/HeartRateDetector.kt:94`
```kotlin
fun stopMeasurement() {
    ...
    analysisExecutor.shutdown()  // Permanently killed!
}
```
**Impact**: Second heart rate measurement crashes — `ExecutorService` cannot be reused after `shutdown()`.
**Fix**: Either don't shut down the executor, or recreate it in `startMeasurement()`.

---

### BUG-5: HeartRateDetector race condition on bpmReadings
**File**: `data/services/HeartRateDetector.kt:62`
```kotlin
private var bpmReadings = mutableListOf<Int>()
// Written from analysisExecutor thread, read from main thread
```
**Impact**: `ConcurrentModificationException` crash or corrupted readings.
**Fix**: Use `Collections.synchronizedList()` or `CopyOnWriteArrayList`.

---

### BUG-6: HeartRateDetector torch left on
**File**: `data/services/HeartRateDetector.kt:92`
```kotlin
camera?.cameraControl?.enableTorch(false)  // No try-catch
```
**Impact**: If this throws (camera already released), phone flashlight stays on permanently, draining battery.
**Fix**: Wrap in try-catch.

---

### BUG-7: ProfileViewModel shows mock user data in production
**File**: `ui/screens/profile/ProfileViewModel.kt:86-94`
```kotlin
val mockUser = AppUser(
    id = "mock-user-1",
    email = "john.doe@example.com",
    fullName = "John Doe",
    ...
)
```
**Impact**: If auth state is momentarily null, user sees "John Doe" profile with fake data. Security issue — should redirect to login.
**Fix**: Navigate to login instead of showing mock data.

---

### BUG-8: Empty profileId passed to Supabase on sync (multiple files)
**Files**:
- `ui/screens/medications/MedicationsViewModel.kt:264-266`
- `ui/screens/diet/DietViewModel.kt:322-324`
- `ui/screens/runactivity/RunActivityViewModel.kt:104-106`

```kotlin
private fun resolveProfileId(): String {
    return AppContainer.authRepository.currentUser?.id ?: ""  // Empty string!
}
```
**Impact**: When user is null, syncs with `health_profile_id = ""` — creates orphaned DB records or RLS rejects silently.
**Fix**: Return nullable `String?`, skip sync if null.

---

### BUG-9: Silent error swallowing in sync functions (multiple files)
**Files**:
- `ui/screens/diet/DietViewModel.kt:315-320`
- `ui/screens/hydration/HydrationViewModel.kt:261-266`
- `ui/screens/runactivity/RunActivityViewModel.kt:94-102`

```kotlin
} catch (_: Exception) { }  // Data loss hidden from user
```
**Impact**: Network failures silently swallowed — users think data is saved when it's not.
**Fix**: Log errors, optionally surface sync status in UI.

---

### BUG-10: MedicationReminder notification ID collisions
**File**: `notifications/MedicationReminderReceiver.kt:43`
```kotlin
manager.notify(medId.hashCode(), notification)
```
**Impact**: Multiple medications can hash to same ID — new notification replaces previous. Users miss medication reminders.
**Fix**: Use unique compound hash: `(medId + scheduleId).hashCode()`.

---

### BUG-11: MedicationReminderScheduler PendingIntent collisions
**File**: `notifications/MedicationReminderScheduler.kt:34`
```kotlin
val pendingIntent = PendingIntent.getBroadcast(
    context,
    scheduleId.hashCode(),  // Can collide with FLAG_UPDATE_CURRENT
    ...
)
```
**Impact**: Different schedules overwrite each other's alarms.
**Fix**: Use `abs(scheduleId.hashCode())` or a sequence-based ID.

---

### BUG-12: LocationTrackingService GPS not always removed
**File**: `data/services/LocationTrackingService.kt:121-127`
```kotlin
fun stopTracking() {
    locationCallback?.let { callback ->
        fusedLocationClient?.removeLocationUpdates(callback)
    }
    locationCallback = null
    fusedLocationClient = null
}
```
**Impact**: If `fusedLocationClient` is null when `stopTracking` is called, callback persists — continuous GPS drain in background.
**Fix**: Store client reference before nulling, ensure removal happens.

---

### BUG-13: AIConversationRepository wrong Supabase update syntax
**File**: `data/repository/AIConversationRepository.kt:100-103`
```kotlin
supabaseClient.from("ai_conversations").update(
    { set("is_archived", true) }  // Wrong lambda syntax
) { filter { eq("id", id) } }
```
**Impact**: Runtime crash when archiving a conversation.
**Fix**: Use `buildJsonObject { put("is_archived", true) }`.

---

## MEDIUM — Should Fix

### BUG-14: RouteTracker isTracking stuck on permission error
**File**: `data/services/RouteTracker.kt:122-135`
```kotlin
fun startTracking() {
    if (isTracking) return
    isTracking = true  // Set before requestLocationUpdates
    fusedClient.requestLocationUpdates(...)  // May throw SecurityException
}
```
**Impact**: If permission denied, `isTracking = true` but no GPS. Can't restart.
**Fix**: Wrap in try-catch, reset `isTracking` on failure.

---

### BUG-15: HydrationViewModel infinite streak loop
**File**: `ui/screens/hydration/HydrationViewModel.kt:238-251`
```kotlin
while (true) {  // No upper bound!
    val dateStr = date.toString()
    val dayEffective = entries.filter { ... }.sumOf { ... }
    if (dayEffective < goal.dailyGoalMl * 0.5) break
    streak++
    date = date.minusDays(1)
}
```
**Impact**: If entries span years, this loops thousands of times, causing UI freeze/ANR.
**Fix**: Add `maxDays` limit (e.g., 365).

---

### BUG-16: ProfileViewModel date parsing NPE risk
**File**: `ui/screens/profile/ProfileViewModel.kt:220-223`
```kotlin
val date = inputFormat.parse(dateStr.take(19))  // Can return null
val outputFormat = SimpleDateFormat("MMM d, yyyy", Locale.US)
outputFormat.format(date ?: Date())  // Falls back to today silently
```
**Impact**: Shows today's date instead of "Unknown" when parsing fails.
**Fix**: Handle null explicitly: `date?.let { outputFormat.format(it) } ?: "Unknown"`.

---

### BUG-17: NotificationService quiet hours edge case
**File**: `data/services/NotificationService.kt:389-397`
```kotlin
private fun isInQuietHours(hour: Int, start: Int, end: Int): Boolean {
    return if (start <= end) {
        hour in start..end  // This is wrong for non-wraparound!
    } else {
        hour >= start || hour <= end
    }
}
```
**Impact**: If quiet hours are 22-7, notifications at exactly 22:00 and 7:00 are still blocked. The `start <= end` branch (e.g., 9-17) includes both endpoints, which may not be intended.
**Fix**: Clarify inclusive/exclusive boundaries.

---

### BUG-18: LiveWorkoutViewModel timer not cancellation-safe
**File**: `ui/screens/runactivity/LiveWorkoutViewModel.kt:254-259`
```kotlin
timerJob = viewModelScope.launch {
    while (true) {
        delay(1000)
        _uiState.update { it.copy(elapsedSeconds = it.elapsedSeconds + 1) }
    }
}
```
**Impact**: Timer relies solely on coroutine cancellation. If ViewModel leaks, timer runs forever.
**Fix**: Use `while(isActive)` instead of `while(true)`.

---

### BUG-19: ModelViewer stuck loading on material error
**File**: `ui/components/ModelViewer.kt:145`
```kotlin
val material = materialLoader.createColorInstance(...)  // No try-catch
```
**Impact**: If material creation fails, model never loads, UI shows loading placeholder forever.
**Fix**: Wrap in try-catch, show error state.

---

### BUG-20: MedicationsViewModel isLoading not reset on error
**File**: `ui/screens/medications/MedicationsViewModel.kt:63-90`
**Impact**: If loadData throws, spinner shows forever.
**Fix**: Add `finally { isLoading = false }`.

---

### BUG-21: RunActivityViewModel syncs all activities not just unsynced
**File**: `ui/screens/runactivity/RunActivityViewModel.kt:99`
```kotlin
repository.syncActivitiesToCloud(_uiState.value.activities, profileId)
// Should be: repository.syncActivitiesToCloud(unsynced, profileId)
```
**Impact**: Redundant network calls on every sync.
**Fix**: Pass `unsynced` list.

---

### BUG-22: AppContainer accessed before initialization
**File**: `di/AppContainer.kt:51-60`
**Impact**: If any service is accessed before `initialize()` in Application.onCreate(), crashes with IllegalStateException.
**Fix**: Verify initialization order in `SwasthiCareApplication.kt`.

---

### BUG-23: MedicationSchedule time parsing silent skip
**File**: `ui/screens/medications/MedicationsViewModel.kt:188-190`
```kotlin
val parts = schedule.timeOfDay.split(":")
val hour = parts.getOrNull(0)?.toIntOrNull() ?: return@forEach  // Silent skip
```
**Impact**: Malformed time strings cause medication reminders to silently not schedule.
**Fix**: Log warning when skipping.

---

### BUG-24: LiveWorkoutViewModel flow collectors no error handling
**File**: `ui/screens/runactivity/LiveWorkoutViewModel.kt:116-157`
**Impact**: If any `collect {}` throws, workout UI stops updating silently mid-workout.
**Fix**: Add `catch {}` on flows or try-catch in launch blocks.

---

### BUG-25: HeartRateDetector getResult index out of bounds
**File**: `data/services/HeartRateDetector.kt:99-103`
```kotlin
if (bpmReadings.isEmpty()) return null  // Check here...
val sorted = bpmReadings.sorted()       // But bpmReadings could be emptied by concurrent clear
val medianBPM = sorted[sorted.size / 2] // Crash if concurrent modification emptied it
```
**Impact**: Possible IndexOutOfBoundsException due to race with BUG-5.
**Fix**: Snapshot the list first: `val snapshot = bpmReadings.toList()`.

---

## LOW — Minor Issues

### BUG-26: DietViewModel sync failure not logged
**File**: `ui/screens/diet/DietViewModel.kt:296-312`
**Impact**: Stale food database with no indication.

### BUG-27: HydrationRepository integer division
**File**: `data/repository/HydrationRepository.kt:212-213`
**Impact**: Slightly inaccurate average calculations.

### BUG-28: ProfileViewModel hardcoded delete error message
**File**: `ui/screens/profile/ProfileViewModel.kt:200-203`
```kotlin
it.copy(errorMessage = "Account deletion not fully implemented on backend yet.")
```
**Impact**: Shows wrong message if backend actually supports deletion but throws a different error.

---

## Fix Priority Order

| Priority | Bugs | Effort |
|----------|------|--------|
| **Immediate** | BUG-1,2,3 (fake data) | High — requires wiring HealthConnect + repos to ViewModels |
| **Immediate** | BUG-4,5,6 (HeartRate crashes) | Medium — executor reuse, thread safety, try-catch |
| **Immediate** | BUG-7 (mock profile) | Low — remove mock, redirect to login |
| **Before launch** | BUG-8,9 (profileId + silent errors) | Medium — null checks + error surfacing |
| **Before launch** | BUG-10,11 (notification collisions) | Low — fix hash logic |
| **Before launch** | BUG-12,13 (GPS leak, API crash) | Medium |
| **Should fix** | BUG-14 through BUG-25 | Low-Medium each |
| **Nice to have** | BUG-26,27,28 | Low |
