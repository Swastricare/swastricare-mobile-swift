# Android Onboarding Port Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port the iOS one-question-per-screen health-profile onboarding (8 questions + loading transition) to Android, gated after login so users without a `health_profiles` row are forced through it. Unblocks the family-join RPC for all Android users.

**Architecture:** New Compose flow at the existing `health_profile` nav route with one HorizontalPager step per question and progress dots. State held in a single Hilt `OneQuestionOnboardingViewModel`. Routing decision moves to `SplashViewModel` — it checks a new `HEALTH_PROFILE_COMPLETE_KEY` DataStore flag and falls back to a Supabase lookup of the caller's `health_profiles` row. After completion, INSERT to `health_profiles` (existing `ProfileRepositoryImpl.createHealthProfile`) plus an UPDATE to `users.full_name`/`onboarding_completed` mirroring iOS, then flip the flag and navigate to `main`.

**Tech Stack:** Kotlin, Jetpack Compose, Material 3, Hilt, Jetpack DataStore (Preferences), supabase-kt 2.6.0. Brand: AITeal `#22C5A6`, pure white background, no gradient buttons (per project rules in `MEMORY.md`).

**Verification model (no test infra):** This codebase has no Android test infrastructure (per `CLAUDE.md`). Verification per task is `assembleDebug` build green; final verification is install + manual flow on the OnePlus 8T (`acac8d4b`) and emulator (`emulator-5554`).

**Reference design:** `docs/plans/2026-05-11-android-onboarding-port-design.md`.

---

## Task 1: Add health-profile DataStore key

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/di/DatabaseModule.kt`

**Step 1: Add the key** next to the existing `ONBOARDING_COMPLETE_KEY` (find it with `grep -n ONBOARDING_COMPLETE_KEY` in that file). Add:

```kotlin
val HEALTH_PROFILE_COMPLETE_KEY = booleanPreferencesKey("health_profile_complete")
```

**Step 2: Build**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/di/DatabaseModule.kt
git commit -m "feat(android): add HEALTH_PROFILE_COMPLETE_KEY DataStore key"
```

---

## Task 2: Extend SplashViewModel with health-profile check

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/splash/SplashViewModel.kt`

**Step 1: Inject ProfileRepository and add accessors.**

Add an `import` for `HEALTH_PROFILE_COMPLETE_KEY` and `ProfileRepository` (`com.swastricare.health.domain.repository.ProfileRepository`). Inject it in the constructor. Add:

```kotlin
suspend fun isHealthProfileComplete(): Boolean {
    val flag = dataStore.data.first()[HEALTH_PROFILE_COMPLETE_KEY] ?: false
    if (flag) return true
    val userId = authRepository.currentUser?.id ?: return false
    val res = profileRepository.getHealthProfile(userId)
    val exists = (res as? ResultWrapper.Success)?.data != null
    if (exists) markHealthProfileComplete()
    return exists
}

suspend fun markHealthProfileComplete() {
    dataStore.edit { it[HEALTH_PROFILE_COMPLETE_KEY] = true }
}
```

Imports needed: `androidx.datastore.preferences.core.edit`, `com.swastricare.health.core.result.ResultWrapper`.

**Step 2: Build**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git commit -am "feat(android): SplashViewModel checks health profile via flag + DB"
```

---

## Task 3: Add `markUserOnboardingComplete` to ProfileRepository

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/domain/repository/ProfileRepository.kt` (add method to interface)
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/repository/ProfileRepositoryImpl.kt` (implement)

**Step 1: Interface addition**

```kotlin
suspend fun markUserOnboardingComplete(userId: String, fullName: String?): ResultWrapper<Unit>
```

**Step 2: Impl** — at the bottom of the class:

```kotlin
override suspend fun markUserOnboardingComplete(
    userId: String,
    fullName: String?
): ResultWrapper<Unit> = try {
    supabaseClient.from("users")
        .update(buildJsonObject {
            put("onboarding_completed", true)
            if (!fullName.isNullOrBlank()) put("full_name", fullName)
        }) {
            filter { eq("id", userId) }
        }
    ResultWrapper.Success(Unit)
} catch (e: Exception) {
    logger.e(tag, "markUserOnboardingComplete failed", e)
    ResultWrapper.Error(AppException.UnknownException(cause = e))
}
```

(Imports: `kotlinx.serialization.json.buildJsonObject`, `put`. Match style of any existing `update(buildJsonObject {...})` call in the same file.)

**Step 3: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
git commit -am "feat(android): ProfileRepository.markUserOnboardingComplete (mirror iOS)"
```

---

## Task 4: Update SplashScreen routing

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/splash/SplashScreen.kt`

**Step 1: Add a fourth callback parameter** `onNavigateToHealthProfile: () -> Unit` to the composable signature.

**Step 2: Replace the routing block at lines 84–94** with:

```kotlin
val isAuthed = splashVm.isAuthenticated()
val onboardingDone = splashVm.isOnboardingComplete()
val healthProfileDone = if (isAuthed) splashVm.isHealthProfileComplete() else true

fadeOut = true
delay(250)

when {
    !isAuthed && !onboardingDone -> onNavigateToOnboarding()
    !isAuthed -> onNavigateToLogin()
    !healthProfileDone -> onNavigateToHealthProfile()
    else -> onNavigateToHome()
}
```

**Step 3: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
git commit -am "feat(android): SplashScreen routes to health profile when missing"
```

---

## Task 5: Wire the new callback in AppNavigation

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/AppNavigation.kt`

**Step 1:** In the `composable("splash")` block (around line 220), add a fourth callback:

```kotlin
onNavigateToHealthProfile = {
    navController.navigate("health_profile") {
        popUpTo("splash") { inclusive = true }
    }
}
```

Also: change the post-login `onLoginSuccess` (around line 277) and post-signup `onSignUpSuccess` (line 292) navigation targets from `"main"` to a small inline check — easiest is to navigate to `"splash"` so the splash gate re-runs:

```kotlin
onLoginSuccess = {
    navController.navigate("splash") {
        popUpTo("login") { inclusive = true }
    }
}
```

Repeat for signup and any other "go to main after auth" sites.

**Step 2: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
git commit -am "feat(android): route post-auth through splash so profile gate runs"
```

---

## Task 6: Create OnboardingFormState data class

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/OnboardingFormState.kt`

**Step 1: Write**

```kotlin
package com.swastricare.health.ui.screens.onboarding

import com.swastricare.health.domain.model.Gender
import java.time.LocalDate

enum class HeightUnit { CM, FT_IN }
enum class WeightUnit { KG, LB }

enum class PrimaryGoal(val display: String) {
    TRACK_HEALTH("Track health"),
    CONTROL_SUGAR("Control sugar"),
    CONTROL_BP("Control BP"),
    IMPROVE_HEART_HEALTH("Improve heart health"),
    IMPROVE_SLEEP("Improve sleep"),
    REDUCE_STRESS("Reduce stress"),
    FITNESS_TRACKING("Fitness tracking"),
    PREGNANCY_CARE("Pregnancy care"),
    OTHER("Other")
}

enum class ActivityLevel(val display: String) {
    SEDENTARY("Sedentary"),
    LIGHT("Light"),
    MODERATE("Moderate"),
    VERY_ACTIVE("Very active")
}

enum class WaterIntake(val display: String) {
    LESS_THAN_1L("<1L"),
    ONE_TO_TWO("1-2L"),
    TWO_TO_THREE("2-3L"),
    THREE_PLUS("3L+")
}

data class OnboardingFormState(
    val fullName: String = "",
    val gender: Gender? = null,
    val dateOfBirth: LocalDate? = null,
    val heightCm: Int = 170,
    val heightUnit: HeightUnit = HeightUnit.CM,
    val weightKg: Int = 65,
    val weightUnit: WeightUnit = WeightUnit.KG,
    val primaryGoal: PrimaryGoal? = null,
    val activityLevel: ActivityLevel? = null,
    val waterIntake: WaterIntake? = null
)
```

If `Gender` enum doesn't exist at that import path, locate it via `grep -rn "enum class Gender" android/app/src/main/kotlin/`. If absent, define a small enum in this same file.

**Step 2: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
git commit -am "feat(android): OnboardingFormState + iOS-parity question enums"
```

---

## Task 7: Create OneQuestionOnboardingViewModel

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/OneQuestionOnboardingViewModel.kt`

**Step 1: Write**

```kotlin
package com.swastricare.health.ui.screens.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.domain.model.HealthProfile
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.ui.screens.splash.SplashViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID
import javax.inject.Inject

enum class SubmitState { IDLE, SUBMITTING, SUCCESS, ERROR }

data class OnboardingUiState(
    val step: Int = 0,                    // 0..7
    val form: OnboardingFormState = OnboardingFormState(),
    val submitState: SubmitState = SubmitState.IDLE,
    val errorMessage: String? = null
)

@HiltViewModel
class OneQuestionOnboardingViewModel @Inject constructor(
    private val authRepository: SupabaseAuthRepository,
    private val profileRepository: ProfileRepository,
    private val splashViewModel: SplashViewModel,    // reuse markHealthProfileComplete; if injection fails, inline the prefs write
    private val logger: Logger
) : ViewModel() {

    private val tag = "OneQuestionOnboarding"
    private val _state = MutableStateFlow(OnboardingUiState())
    val state: StateFlow<OnboardingUiState> = _state.asStateFlow()

    val totalSteps: Int = 8

    fun update(transform: OnboardingFormState.() -> OnboardingFormState) {
        _state.update { it.copy(form = it.form.transform()) }
    }

    fun next() {
        val s = _state.value
        if (!isStepValid(s.step, s.form)) return
        if (s.step < totalSteps - 1) {
            _state.update { it.copy(step = it.step + 1) }
        } else {
            submit()
        }
    }

    fun back() {
        _state.update { if (it.step > 0) it.copy(step = it.step - 1) else it }
    }

    fun isStepValid(step: Int = _state.value.step, form: OnboardingFormState = _state.value.form): Boolean = when (step) {
        0 -> form.fullName.isNotBlank()
        1 -> form.gender != null
        2 -> form.dateOfBirth != null && form.dateOfBirth <= LocalDate.now()
            && form.dateOfBirth >= LocalDate.now().minusYears(120)
        3 -> form.heightCm in 100..250
        4 -> form.weightKg in 20..250
        5 -> form.primaryGoal != null
        6 -> form.activityLevel != null
        7 -> form.waterIntake != null
        else -> false
    }

    private fun submit() {
        val userId = authRepository.currentUser?.id ?: run {
            _state.update { it.copy(submitState = SubmitState.ERROR, errorMessage = "Not signed in") }
            return
        }
        val form = _state.value.form
        viewModelScope.launch {
            _state.update { it.copy(submitState = SubmitState.SUBMITTING, errorMessage = null) }

            val profile = HealthProfile(
                id = UUID.randomUUID().toString(),
                userId = userId,
                fullName = form.fullName,
                gender = form.gender,
                dateOfBirth = form.dateOfBirth,
                heightCm = form.heightCm,
                weightKg = form.weightKg,
                bloodType = null
                // any other required fields - inspect HealthProfile.kt and add nulls/defaults
            )

            val createRes = profileRepository.createHealthProfile(profile)
            if (createRes is ResultWrapper.Error) {
                logger.e(tag, "createHealthProfile failed", createRes.exception)
                _state.update {
                    it.copy(
                        submitState = SubmitState.ERROR,
                        errorMessage = createRes.exception.message ?: "Failed to save profile"
                    )
                }
                return@launch
            }

            // Best-effort users-table sync; failure here doesn't block onboarding completion.
            profileRepository.markUserOnboardingComplete(userId, form.fullName)
            splashViewModel.markHealthProfileComplete()

            _state.update { it.copy(submitState = SubmitState.SUCCESS) }
        }
    }

    fun retry() {
        _state.update { it.copy(submitState = SubmitState.IDLE, errorMessage = null) }
        submit()
    }
}
```

Note: if Hilt rejects injecting `SplashViewModel` (because it's also a Hilt-scoped VM), refactor: extract a `OnboardingPrefs` class that wraps `dataStore.edit { it[HEALTH_PROFILE_COMPLETE_KEY] = true }` and inject that into both `SplashViewModel` and `OneQuestionOnboardingViewModel`. Inspect `HealthProfile` (`domain/model/HealthProfile.kt`) for required vs optional fields.

**Step 2: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -8
git commit -am "feat(android): OneQuestionOnboardingViewModel with submit + validation"
```

---

## Task 8: Create the host onboarding screen

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/OneQuestionOnboardingScreen.kt`

**Step 1: Write the host composable.**

Layout: `Scaffold` with white background. Top bar = back-arrow IconButton (calls `vm.back()` if `state.step > 0`, else `onBack()`) + 8 horizontal progress dots. Body = `AnimatedContent(state.step)` rendering one of the 8 step composables. Bottom = primary `Button` "Continue" (or "Complete" on the last step). Disabled when `!vm.isStepValid()`.

When `state.submitState == SUBMITTING || SUCCESS`, replace the whole body with `OnboardingSetupLoadingScreen(state.submitState, state.errorMessage, vm::retry, onComplete = onFinished)`.

Style rules (from `MEMORY.md`):
- Background `Color.White`
- Continue button: `containerColor = AITeal`, height 56dp, corner 16dp, no gradient
- Active dot: AITeal, others `AppColors.outlineVariant`
- Title: `MaterialTheme.typography.headlineSmall`, bold
- Subtitle: `bodyMedium`, `AppColors.onSurfaceVariant`

Inside this same file (private composables), implement the 8 step bodies. Each receives `state: OnboardingFormState` and `onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit`:

| # | Step composable | UI |
|---|---|---|
| 0 | `NameStep` | `OutlinedTextField` for `fullName`, single line |
| 1 | `GenderStep` | Row of 4 pill buttons (Male / Female / Other / Prefer not to say) — selected = AITeal fill, unselected = AITeal alpha 0.1 fill |
| 2 | `DobStep` | `androidx.compose.material3.DatePicker` configured to year-month-day, default selection 30 years ago |
| 3 | `HeightStep` | `Slider(value = heightCm.toFloat(), valueRange = 100f..250f, steps = 149)`; cm/ft toggle (TabRow). When ft selected, display computed ft+in but persist cm. |
| 4 | `WeightStep` | Same shape as HeightStep, range 20..250, kg/lb toggle. |
| 5 | `GoalStep` | `LazyColumn` of selectable rows for each `PrimaryGoal`, single-select, AITeal accent on selected |
| 6 | `ActivityStep` | Same pattern, 4 `ActivityLevel` rows |
| 7 | `WaterStep` | Same pattern, 4 `WaterIntake` rows |

Each step renders the question title and subtitle from the design doc table at the top.

**Step 2: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -8
git commit -am "feat(android): OneQuestionOnboardingScreen + 8 step composables"
```

---

## Task 9: Create OnboardingSetupLoadingScreen

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/OnboardingSetupLoadingScreen.kt`

**Step 1: Write**

Vertical center column on white background:
- `SubmitState.SUBMITTING`: AITeal `CircularProgressIndicator` (64dp) + `Text("Setting up your profile…", titleMedium)`.
- `SubmitState.SUCCESS`: green check icon (64dp) + `Text("All set!")`. Trigger `LaunchedEffect(Unit) { delay(800); onComplete() }`.
- `SubmitState.ERROR`: red error icon + `Text(errorMessage ?: "Something went wrong")` + `Button("Retry", onClick = onRetry)` styled per project rules.

Composable signature: `fun OnboardingSetupLoadingScreen(state: SubmitState, errorMessage: String?, onRetry: () -> Unit, onComplete: () -> Unit)`.

**Step 2: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -8
git commit -am "feat(android): OnboardingSetupLoadingScreen (success/error/retry)"
```

---

## Task 10: Wire `health_profile` route to the new screen

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/AppNavigation.kt`

**Step 1:** Replace the body of `composable("health_profile") { ... }` (around line 338–352):

```kotlin
composable("health_profile") {
    OneQuestionOnboardingScreen(
        onFinished = {
            navController.navigate("main") {
                popUpTo("health_profile") { inclusive = true }
            }
        }
    )
}
```

Remove the `import` for the old `HealthProfileScreen` and add `OneQuestionOnboardingScreen`.

**Step 2: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:compileDebugKotlin 2>&1 | tail -5
git commit -am "feat(android): wire health_profile route to OneQuestionOnboardingScreen"
```

---

## Task 11: Delete old HealthProfileScreen

**Files:**
- Delete: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/HealthProfileScreen.kt`

**Step 1: Confirm no other references**

```
grep -rn "HealthProfileScreen" android/app/src/main/kotlin/ 2>&1 | head -5
```
Expected: no matches (or only the file itself).

**Step 2: Delete**

```bash
git rm android/app/src/main/kotlin/com/swastricare/health/ui/screens/onboarding/HealthProfileScreen.kt
```

**Step 3: Build & commit**

```
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
git commit -m "chore(android): remove single-form HealthProfileScreen (replaced)"
```

---

## Task 12: Install + verify on both devices

**Step 1: Install**

```
~/Library/Android/sdk/platform-tools/adb -s acac8d4b install -r /Users/syamsundar/Onwords/swastricare-mobile-swift/android/app/build/outputs/apk/debug/app-debug.apk
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 install -r /Users/syamsundar/Onwords/swastricare-mobile-swift/android/app/build/outputs/apk/debug/app-debug.apk
```

If emulator returns `INSUFFICIENT_STORAGE`, uninstall the app first then re-install.

**Step 2: Verify on the OnePlus**

1. Launch from cold (force-stop first: `adb -s acac8d4b shell am force-stop com.swastricare.health`).
2. Splash → should land on Q1 ("What's your name?") since this account has no `health_profiles` row.
3. Walk through all 8 steps — confirm each Continue is disabled until valid.
4. Final tap → loading screen → main.
5. Open Family → enter a valid invite code → expect success (no "Health profile not found").
6. Force-stop and re-launch → should land directly on main (flag set).

**Step 3: Verify on emulator**

Repeat steps 1–6 with `-s emulator-5554`.

**Step 4: Probe Supabase to confirm the row landed**

```
ANON='<the anon key already used in this session>'
USER_JWT='<grab from logcat>'
curl -s 'https://jlumbeyukpnuicyxzvre.supabase.co/rest/v1/health_profiles?select=id,full_name,user_id' \
  -H "apikey: $ANON" -H "Authorization: Bearer $USER_JWT" | head -c 400
```

Expected: an array containing a row whose `user_id` matches the test account.

---

## Notes for the executor

- **No tests** — Verify each task with `:app:compileDebugKotlin` (cheaper than `assembleDebug`); use `assembleDebug` only at task 11/12 when packaging matters.
- **Style rules** in `MEMORY.md` are non-negotiable: white backgrounds, AITeal CTAs, no gradients, no `AppColors.background`. Audit each new composable against these before committing.
- **Error path matters:** if the splash gate misroutes (e.g. an authed user with a profile lands on onboarding by mistake), check `SplashViewModel.isHealthProfileComplete` log output first — the DB lookup may have failed silently. Flip to local-flag-only if the network is down.
- **Do not attempt schema changes** — Q6/Q7/Q8 are intentionally not persisted. Resist the urge to add columns "while we're here."

