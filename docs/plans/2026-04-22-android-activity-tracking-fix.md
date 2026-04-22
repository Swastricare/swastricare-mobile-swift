# Android Activity Tracking Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix Android live-workout GPS tracking so distance, pace, splits, and step count accumulate correctly during walks and runs.

**Architecture:** The live-workout GPS pipeline in `RouteTracker.kt` is over-filtering real movement: (1) it waits for an accurate first fix instead of emitting early, (2) its Kalman filter dampens real motion, (3) its per-update auto-pause treats normal walking as stationary, and (4) its accuracy ceiling is too strict. Fix by aligning defaults to the iOS implementation (`LocationTrackingService.swift`): trust raw FusedLocation output, widen the accuracy cap to 50 m, remove the Kalman filter, and rewrite auto-pause as a rolling-window check. Add `steps` to the active persistence path so session step count survives to Supabase and back.

**Tech Stack:** Kotlin, Google Play Services FusedLocationProviderClient, kotlinx.serialization, Hilt, Supabase kotlin client.

**Design doc:** `docs/plans/2026-04-22-android-activity-tracking-fix-design.md`

**Reference files (already explored):**
- Android tracker: `android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt`
- Android viewmodel: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/LiveWorkoutViewModel.kt`
- Android models + active DTO path: `android/app/src/main/kotlin/com/swastricare/health/data/models/RunActivityModels.kt`
- iOS parity reference: `swastricare-mobile-swift/Services/LocationTrackingService.swift`

**Testing note:** There is no unit-test harness for `RouteTracker` in the repo. Per project convention (see `CLAUDE.md`), there are no iOS unit tests either. Verification in this plan is **manual on-device** plus a debug build via Gradle. Do not add JUnit scaffolding as part of this change — that is a separate tech-debt item.

**Device for manual test:** OnePlus 8T (adb serial `KB2001`). Outdoors preferred for real GPS behavior; indoors-at-window is acceptable to validate cold-start fix acquisition and auto-pause.

---

## Task 1: Remove the Kalman filter

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt`

**Why:** The Kalman filter with `processNoise = 0.00001` dampens real walking motion so much that smoothed deltas fall under the 2 m jitter threshold and every point is rejected. iOS uses no Kalman filter and tracks reliably. FusedLocation already applies smoothing internally.

**Step 1: Delete the `GpsKalmanFilter` class**

In `RouteTracker.kt`, delete lines 40–83 (the entire `// MARK: - Kalman Filter for GPS` section, from the `GpsKalmanFilter` class open to close).

**Step 2: Delete the Kalman filter fields**

In `RouteTracker.kt`, delete lines 134–136:

```kotlin
// Kalman filters for lat/lng smoothing
private val latKalman = GpsKalmanFilter()
private val lngKalman = GpsKalmanFilter()
```

**Step 3: Use raw coordinates in `processLocation`**

In `RouteTracker.kt`, replace the two Kalman update lines (currently around lines 183–185):

```kotlin
// Apply Kalman filter to smooth lat/lng
val smoothedLat = latKalman.update(location.latitude, accuracy)
val smoothedLng = lngKalman.update(location.longitude, accuracy)
```

with:

```kotlin
val smoothedLat = location.latitude
val smoothedLng = location.longitude
```

(Keep the variable names to minimise diff against the rest of the function.)

**Step 4: Remove Kalman resets in `startTracking`, `reset`, and `clearRouteData`**

In `RouteTracker.kt`, delete these two lines wherever they appear (they appear three times: once in `startTracking` ~lines 278–279, once in `reset` ~lines 353–354, once in `clearRouteData` ~lines 376–377):

```kotlin
latKalman.reset()
lngKalman.reset()
```

**Step 5: Build**

Run:

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`. No references to `GpsKalmanFilter` or `latKalman`/`lngKalman` should remain — the compiler will catch any you missed.

**Step 6: Commit**

```
git add android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt
git commit -m "fix(android): remove Kalman filter from RouteTracker"
```

---

## Task 2: Widen accuracy cap and drop `setWaitForAccurateLocation`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt`

**Why:** `setWaitForAccurateLocation(true)` on the `HIGH_ACCURACY` request can delay the very first location callback by 30–90+ s on cold start — the user's "no tracking for a minute" symptom. `MAX_ACCURACY_METERS = 25f` rejects the 30–60 m fixes typical of early GPS lock; iOS's equivalent is 50 m.

**Step 1: Raise the accuracy cap**

In `RouteTracker.kt`, change line ~149:

```kotlin
private val MAX_ACCURACY_METERS = 25f           // reject points with worse accuracy
```

to:

```kotlin
private val MAX_ACCURACY_METERS = 50f           // matches iOS horizontalAccuracy <= 50m
```

**Step 2: Retune the `HIGH_ACCURACY` location request**

In `RouteTracker.kt`, find `buildLocationRequest` (~line 414). Replace the `HIGH_ACCURACY` branch:

```kotlin
GpsMode.HIGH_ACCURACY -> LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 3_000L)
    .setMinUpdateIntervalMillis(2_000L)
    .setMinUpdateDistanceMeters(2f)
    .setWaitForAccurateLocation(true)
```

with:

```kotlin
GpsMode.HIGH_ACCURACY -> LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2_000L)
    .setMinUpdateIntervalMillis(1_000L)
    .setMinUpdateDistanceMeters(0f)
    .setWaitForAccurateLocation(false)
```

Rationale for each number:
- Interval `2_000L` and min interval `1_000L`: roughly 1 Hz updates, comparable to iOS default `distanceFilter = 5m` with `kCLLocationAccuracyBest`.
- `setMinUpdateDistanceMeters(0f)`: don't let FusedLocation silently drop updates — the app already filters via `MIN_DISTANCE_METERS = 2.0`.
- `setWaitForAccurateLocation(false)`: emit the first fix immediately; the app rejects low-quality fixes via `MAX_ACCURACY_METERS`.

**Step 3: Build**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

**Step 4: Commit**

```
git add android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt
git commit -m "fix(android): match iOS GPS accuracy/timing in RouteTracker"
```

---

## Task 3: Rewrite auto-pause using a rolling-window check

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt`

**Why (this is the dominant bug):** The current check fires per-update:

```kotlin
val isStationary = smoothedSpeed < STATIONARY_SPEED && actualDistance < STATIONARY_DISTANCE
```

`STATIONARY_DISTANCE = 5.0 m` per update. A normal walker covers ~3 m per ~3 s update, always below the threshold. After 6 consecutive updates (~18 s of real walking) auto-pause triggers and `if (_isAutopaused.value) return` halts route recording. Replace with a cumulative distance over a time window — actual walking easily beats the window total, while true stationary does not.

**Step 1: Replace the stationary constants**

In `RouteTracker.kt`, find the block around lines 142–146 that defines auto-pause constants:

```kotlin
// Auto-pause: track consecutive stationary readings
private var stationaryCount = 0
private val STATIONARY_THRESHOLD = 6  // ~18s at 3s intervals to trigger auto-pause (was 3 = ~9s, too aggressive)
private val STATIONARY_SPEED = 0.5f   // m/s — reported speed below this is "not moving"
private val STATIONARY_DISTANCE = 5.0 // meters — actual movement below this is "not moving"
```

Replace the whole block with:

```kotlin
// Auto-pause: rolling-window check.
// If the user has moved less than AUTO_PAUSE_MIN_METERS in the last
// AUTO_PAUSE_WINDOW_SECONDS, they are considered stationary. Exits auto-pause
// as soon as a new accepted point adds >= AUTO_PAUSE_RESUME_METERS of motion.
private val AUTO_PAUSE_WINDOW_SECONDS = 20L
private val AUTO_PAUSE_MIN_METERS = 10.0
private val AUTO_PAUSE_RESUME_METERS = 5.0
```

Also delete the `stationaryCount` field (it is now unused) and the `autopauseJob` field at line 132 and its `.cancel()` in `stopTracking` (see Step 4).

**Step 2: Rewrite the auto-pause block inside `processLocation`**

In `RouteTracker.kt`, find the auto-pause block inside `processLocation` (currently around lines 220–242):

```kotlin
// Auto-pause: use BOTH speed AND actual distance to detect stationary state
// GPS can report false speed while sitting still due to signal noise
if (autoPauseEnabled) {
    val isStationary = smoothedSpeed < STATIONARY_SPEED && actualDistance < STATIONARY_DISTANCE

    if (isStationary) {
        stationaryCount++
        if (stationaryCount >= STATIONARY_THRESHOLD && !_isAutopaused.value) {
            _isAutopaused.value = true
        }
        // While autopaused, don't add route points (prevents GPS drift cluster)
        if (_isAutopaused.value) return
    } else {
        if (_isAutopaused.value) {
            _isAutopaused.value = false
        }
        stationaryCount = 0
    }
} else {
    // Auto-pause disabled — clear any existing auto-pause state
    if (_isAutopaused.value) {
        _isAutopaused.value = false
    }
    stationaryCount = 0
}
```

Replace with:

```kotlin
// Auto-pause: rolling-window distance check.
// Look at the last AUTO_PAUSE_WINDOW_SECONDS of accepted route points.
// If the user has moved less than AUTO_PAUSE_MIN_METERS in that window,
// treat as stationary. Exit auto-pause when a new point adds
// AUTO_PAUSE_RESUME_METERS or more of motion.
if (autoPauseEnabled) {
    if (_isAutopaused.value) {
        // Currently paused — resume as soon as we see real motion.
        if (actualDistance >= AUTO_PAUSE_RESUME_METERS) {
            _isAutopaused.value = false
        } else {
            // Stay paused; swallow this point so drifty GPS doesn't inflate distance.
            return
        }
    } else if (current.isNotEmpty()) {
        val cutoff = location.time - AUTO_PAUSE_WINDOW_SECONDS * 1000L
        val windowPoints = current.filter { it.timestamp >= cutoff }
        if (windowPoints.size >= 2) {
            val windowDistance = RouteTracker.totalDistance(windowPoints)
            if (windowDistance < AUTO_PAUSE_MIN_METERS) {
                _isAutopaused.value = true
                return
            }
        }
    }
} else {
    if (_isAutopaused.value) {
        _isAutopaused.value = false
    }
}
```

Note: `RouteTracker.totalDistance(points)` is the companion function already defined at the bottom of the file (~line 452). No new helper needed.

**Step 3: Remove `autopauseJob` references**

- Delete line ~132: `private var autopauseJob: Job? = null`
- In `stopTracking` (~line 320), delete: `autopauseJob?.cancel()`

**Step 4: Remove `stationaryCount` resets**

Search `RouteTracker.kt` for every `stationaryCount` reference and delete them. They should appear in:
- `startTracking` (around line 276)
- `stopTracking` is not affected
- `reset` (around line 351)
- `clearRouteData` (around line 374)

The compiler will tell you if you missed any.

**Step 5: Build**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

**Step 6: Commit**

```
git add android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt
git commit -m "fix(android): rewrite auto-pause as rolling-window distance check"
```

---

## Task 4: Persist session step count on `RunActivity`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/models/RunActivityModels.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/LiveWorkoutViewModel.kt`

**Why:** `RunActivity.toDto(...)` hardcodes `steps = 0` (line 226). The live workout already tracks the session step count in `LiveWorkoutUiState.totalSteps` via the hardware step counter. Wire it through so history and Supabase both receive it.

**Step 1: Add `steps` to the `RunActivity` domain class**

In `RunActivityModels.kt`, in the `RunActivity` data class (lines 55–68), add a new field. Change:

```kotlin
data class RunActivity(
    val id: String = UUID.randomUUID().toString(),
    val userId: String = "",
    val activityType: ActivityType = ActivityType.RUNNING,
    val startTime: LocalDateTime? = null,
    val endTime: LocalDateTime? = null,
    val distanceMeters: Double = 0.0,
    val durationSeconds: Long = 0,
    val avgPaceSecondsPerKm: Long = 0,
    val caloriesBurned: Int = 0,
    val avgHeartRate: Int? = null,
    val routeCoordinates: List<RouteCoordinate> = emptyList(),
    val splits: List<ActivitySplit> = emptyList(),
    val synced: Boolean = false
)
```

to:

```kotlin
data class RunActivity(
    val id: String = UUID.randomUUID().toString(),
    val userId: String = "",
    val activityType: ActivityType = ActivityType.RUNNING,
    val startTime: LocalDateTime? = null,
    val endTime: LocalDateTime? = null,
    val distanceMeters: Double = 0.0,
    val durationSeconds: Long = 0,
    val avgPaceSecondsPerKm: Long = 0,
    val caloriesBurned: Int = 0,
    val avgHeartRate: Int? = null,
    val steps: Int = 0,
    val routeCoordinates: List<RouteCoordinate> = emptyList(),
    val splits: List<ActivitySplit> = emptyList(),
    val synced: Boolean = false
)
```

**Step 2: Use `steps` in `toDto`**

In `RunActivityModels.kt`, in `RunActivity.toDto(...)` (around line 226), replace:

```kotlin
steps = 0 // TODO: Add step counting from Health Connect if available
```

with:

```kotlin
steps = steps
```

**Step 3: Restore `steps` in `toDomain`**

In `RunActivityModels.kt`, in `RunActivityDto.toDomain()` (around lines 259–281), add `steps = steps` into the `RunActivity(...)` constructor call. Place it next to `avgHeartRate = avgHeartRate` to keep related scalars together:

```kotlin
return RunActivity(
    id = id,
    userId = healthProfileId,
    activityType = ActivityType.fromDb(activityType),
    startTime = ...,
    endTime = ...,
    distanceMeters = distanceMeters,
    durationSeconds = durationSeconds,
    avgPaceSecondsPerKm = avgPaceSecondsPerKm,
    caloriesBurned = caloriesBurned,
    avgHeartRate = avgHeartRate,
    steps = steps,
    routeCoordinates = coords,
    splits = decodedSplits,
    synced = true
)
```

**Step 4: Pass `totalSteps` through in `LiveWorkoutViewModel`**

In `LiveWorkoutViewModel.kt`, inside `saveCompletedWorkoutInternal` where the `RunActivity` is constructed (around line 597), add `steps = state.totalSteps` next to `caloriesBurned`:

```kotlin
val activity = RunActivity(
    activityType = activityType,
    startTime = workoutStartTime?.let {
        java.time.LocalDateTime.ofInstant(it, java.time.ZoneId.systemDefault())
    },
    endTime = java.time.LocalDateTime.now(),
    distanceMeters = state.distanceMeters,
    durationSeconds = state.elapsedSeconds,
    avgPaceSecondsPerKm = paceSecondsPerKm,
    caloriesBurned = finalCalories,
    steps = state.totalSteps,
    routeCoordinates = routeCoords,
    splits = accumulatedSplits.toList(),
    synced = false
)
```

**Step 5: Build**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

**Step 6: Commit**

```
git add android/app/src/main/kotlin/com/swastricare/health/data/models/RunActivityModels.kt \
        android/app/src/main/kotlin/com/swastricare/health/ui/screens/runactivity/LiveWorkoutViewModel.kt
git commit -m "fix(android): persist session step count on RunActivity"
```

---

## Task 5: Manual verification on device

**Prerequisites:**
- OnePlus 8T (adb serial `KB2001`) connected.
- Location + physical activity permissions granted to the app.
- Ideally outdoors or next to a window. Cellular/Wi-Fi on (aids GPS lock via Assisted GPS).

**Step 1: Install the new build**

Assuming the build from Task 4 succeeded, install:

```
adb -s KB2001 install -r android/app/build/outputs/apk/debug/app-debug.apk
```

If there are multiple debug APK flavours, pick the one written by `assembleDebug` — `ls android/app/build/outputs/apk/debug/` will show the path.

**Step 2: Test 1 — Cold-start fix acquisition**

1. Force-stop the app: `adb -s KB2001 shell am force-stop com.swastricare.health`
2. Launch it, sign in if needed.
3. Go to the Run (Steps) tab → pick Walk → tap start.
4. After the 3-2-1 countdown, observe the map.

Pass: the blue "you are here" dot appears within ~10 s. GPS status chip reads `GOOD` or `FAIR`.
Fail: dot never appears within 60 s, GPS chip stuck on `SEARCHING`.

**Step 3: Test 2 — Walk accumulation**

From the tracking screen started in Test 1, walk for 2 minutes at normal pace.

Pass: distance passes ~100 m. Pace display shows a number like `12:30` instead of `--:--`. Auto-pause indicator does **not** activate while you are moving.
Fail: distance stays < 20 m, or pace stays `--:--`, or auto-pause activates mid-walk.

**Step 4: Test 3 — Real stop, real resume**

Still tracking from Test 2: stand still for 30 s, then walk again for 20 s.

Pass: auto-pause activates within ~25 s of standing still; clears within a few seconds of walking again.
Fail: auto-pause never activates during the stop, or never clears after walking resumes.

**Step 5: Test 4 — Splits**

Continue walking/running until you pass 1 km (check the distance counter).

Pass: a split card appears at 1.00 km with that split's time (e.g. `10:42`). `completedKmSplits` increments to `1`.
Fail: distance passes 1 km but no split card appears.

**Step 6: Test 5 — Stop, history, round-trip**

1. Stop the workout. Go to the activity list. Confirm the workout appears with non-zero distance, duration, steps, and splits.
2. Fully kill the app: `adb -s KB2001 shell am force-stop com.swastricare.health`
3. Relaunch, open the same workout from history.

Pass: detail screen still shows the splits, route, distance, duration, step count.
Fail: any of those fields are empty or `0`.

**Step 7: If any test fails**

Stop. Don't patch symptoms. Invoke `superpowers:systematic-debugging` and diagnose before changing code. Common issues:
- Fix never arrives → check permissions via `adb shell dumpsys location | grep -A5 com.swastricare` and device Location setting is on.
- Auto-pause fires on real walking → double-check Task 3, specifically `RouteTracker.totalDistance(windowPoints)` returning 0. The companion function works only on the Android `RoutePoint` from `com.swastricare.health.data.model` (same package it's declared in). Verify the import.
- Splits missing → confirm `accumulatedSplits` is being added to in `LiveWorkoutViewModel`; the split-adding coroutine only runs when `routeTracker.totalDistanceMeters` increases past a km boundary.

**Step 8: No commit in this task** (verification only).

---

## Task 6: Final reality check

**Step 1: Review the diff**

```
git log --oneline main..HEAD
git diff main..HEAD --stat
```

Expected: 4 commits touching `RouteTracker.kt`, `RunActivityModels.kt`, and `LiveWorkoutViewModel.kt`. No other files changed.

**Step 2: Rebuild from clean**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew clean assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

**Step 3: Confirm verification**

Confirm every test in Task 5 passed. If any failed, do not claim this plan complete.

**Step 4: Ready for merge**

At this point the branch is ready to hand back. Do not merge or push from this plan — that is the user's decision.

---

## Out of scope (do NOT do)

These are flagged by the design doc and explicitly excluded:

- Calorie formula rework (still `1 cal/kg/km`, 70 kg).
- Heart-rate streaming during live workout.
- Abandoned-workout resume prompt.
- Cleaning up the parallel unused `RunActivityMapper.kt` / `RunActivityRepositoryImpl.kt` path.
- Adding a JUnit harness for `RouteTracker`.
- Any change to iOS code or the widget extension.

If you think any of these is blocking correctness, stop and ask the user — don't scope-creep.
