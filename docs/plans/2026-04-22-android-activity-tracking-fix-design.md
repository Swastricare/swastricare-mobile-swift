# Android Activity Tracking Fix — Design

**Date:** 2026-04-22
**Status:** Approved, ready for implementation
**Scope:** Fix Android live-workout GPS tracking so distance, pace, and splits record correctly during walks and runs. Add session-step persistence.

## Problem

On Android, starting a Walk or Run from the Run tab does not record meaningful data:

- Distance stays at or near `0` even after a minute of walking
- Pace displays `--:--`
- Splits never record
- The on-screen route trail does not form

The iOS build of the same feature tracks correctly using a far simpler location pipeline. Parity is the goal.

## Root cause

Four interacting defects in `android/app/src/main/kotlin/com/swastricare/health/data/services/RouteTracker.kt`:

1. **`setWaitForAccurateLocation(true)` on the high-accuracy `LocationRequest`** (line 419) tells Google's FusedLocation API to hold back the first fix until it is deemed accurate. On cold start, this can delay the first callback for 30–90+ seconds. iOS emits every fix and filters in app.

2. **Auto-pause per-update stationary check** (lines 146, 221):
   ```kotlin
   private val STATIONARY_DISTANCE = 5.0  // meters per 3-second update
   val isStationary = smoothedSpeed < STATIONARY_SPEED && actualDistance < STATIONARY_DISTANCE
   ```
   Walking at ~1 m/s covers ~3 m per 3-second update — always below the 5 m threshold. After 6 consecutive updates (~18 s), the tracker enters auto-pause and `if (_isAutopaused.value) return` stops recording new points. The tracker treats normal walking as standing still.

3. **Kalman filter dampens real motion** (line 49): `processNoise = 0.00001` assumes position barely moves between samples. Combined with the 2 m jitter threshold, slow walking produces sub-2 m smoothed deltas, so every point is rejected. iOS uses no Kalman filter — raw CoreLocation data with simple accuracy/distance thresholds.

4. **Accuracy threshold too strict** (line 149): `MAX_ACCURACY_METERS = 25f`. iOS uses 50 m. Early fixes commonly report 30–60 m; Android rejects all of them until the signal fully locks.

The downstream effects are direct: `paceFormatted` requires `distanceMeters > 10` to render (LiveWorkoutViewModel.kt:143), and splits are only appended when a new km boundary is crossed (LiveWorkoutViewModel.kt:267–295). Neither happens when distance is stuck at 0.

## Persistence note

The splits persistence issue flagged during exploration (`RunActivityMapper.kt:60,110`) is on a parallel, unused Clean-Architecture path. The live path — `LiveWorkoutViewModel` → `SupabaseRunActivityRepository` → `RunActivity.toDto()` in `RunActivityModels.kt:188–228` — already serializes splits and route coordinates correctly as JSON strings into the Supabase `run_activities.splits` JSONB column. Once tracking accumulates distance, splits will persist and round-trip without further changes.

One persistence gap remains on the active path: `steps = 0` is hardcoded at `RunActivityModels.kt:226`, discarding the session step count the view model already tracks (`LiveWorkoutUiState.totalSteps`).

## Changes

### 1. `RouteTracker.kt` — tracker tuning

- **Remove** `setWaitForAccurateLocation(true)` from the `HIGH_ACCURACY` branch of `buildLocationRequest` so the first fix ships immediately.
- **Relax** `MAX_ACCURACY_METERS` from `25f` to `50f` to match iOS.
- **Delete** the `GpsKalmanFilter` class and every call site. Store raw `location.latitude`/`location.longitude` into `RoutePoint`.
- **Rewrite** auto-pause. Replace the per-update stationary check with a rolling-window check:
  - Track the last 20 seconds of accepted points.
  - If total distance in that window < 10 m, enter auto-pause.
  - Exit auto-pause when a new point adds ≥ 5 m of motion.
  - Remove `STATIONARY_DISTANCE` and the per-update `actualDistance` stationary condition.
- **Tighten** the `HIGH_ACCURACY` location request:
  - `intervalMillis`: `3_000L` → `2_000L`
  - `minUpdateDistanceMeters`: `2f` → `0f` (filter in app, not at the OS)
- **Keep** the teleportation guard (`MAX_DISTANCE_PER_UPDATE_METERS = 80.0`) and the `MIN_DISTANCE_METERS = 2.0` jitter filter.

### 2. `RunActivityModels.kt` — steps persistence

- Add `steps: Int = 0` field to the `RunActivity` data class.
- Pass `steps` through `RunActivity.toDto()` instead of the hardcoded `0`.
- In `LiveWorkoutViewModel.saveCompletedWorkoutInternal`, set `steps = state.totalSteps` when constructing the `RunActivity`.
- In `RunActivityDto.toDomain()`, propagate `steps` onto the restored `RunActivity`.

## Out of scope

- Calorie formula (currently `1 cal/kg/km` with assumed 70 kg). Iterate after tracking works.
- Heart-rate streaming during the live workout.
- Abandoned-workout resume prompt.
- Cleaning up the parallel unused `RunActivityMapper.kt` / `RunActivityRepositoryImpl.kt` path.
- Unit tests for `RouteTracker` — no existing test harness for this service.

## Verification

Manual tests (ideally on a phone outdoors):

1. **Cold-start fix** — fresh app launch → Run tab → start Walk. First GPS point visible within ~10 s.
2. **Slow-walk accumulation** — walk 2 minutes at normal pace. Distance passes 100 m; pace displays a number.
3. **Splits** — walk or run past 1 km. A split card appears at the boundary with the split's time.
4. **Real stop** — stand still for 30 s. Auto-pause activates. Resume walking — auto-pause clears.
5. **Splits round-trip** — complete a run with splits, kill the app, reopen the saved workout from history. Splits display.
6. **Reinstall** — uninstall, reinstall, sign in. Activities rehydrate from Supabase with splits intact.
7. **Steps in history** — completed workout shows the session step count (not 0).

Build check:

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

## Rollback

Single branch + commit. `git revert` restores prior tracking behavior.
