# Android Onboarding Port — iOS Parity (Structure)

**Date:** 2026-05-11
**Trigger:** Android users have no `health_profiles` row, which blocks the family-join RPC (`health profile not found`). iOS already runs an 8-question onboarding that creates the row; Android has the screen but never navigates to it.
**Goal:** Port the iOS one-question-per-screen onboarding flow to Android with iOS structure and Android brand styling.

## Decisions captured

| Topic | Choice |
|---|---|
| Visual scope | iOS structure (8 sequential question screens, same questions/order, loading transition); Android brand (AITeal, Material 3, white background, no gradient buttons). |
| Q6/Q7/Q8 persistence | Match iOS — collected for UX, **not** persisted. No schema change. |
| Existing logged-in users without a profile | Force through onboarding on next launch (matches iOS `checkHealthProfileFromDB`). |
| Skip control | None. Each step's Continue is disabled until valid. |
| Loading transition | Yes — match iOS `OnboardingSetupLoadingView` (~1.5s indeterminate progress + caption + checkmark on success). |

## Architecture

Compose flow rooted at the existing nav route `health_profile` (replaces the old single-form `HealthProfileScreen`). State is held in a `OneQuestionOnboardingViewModel` (Hilt-injected) backed by a single `OnboardingFormState` data class. The host screen renders one of 8 step composables based on `currentStep`. Forward/back is via Continue/back-arrow only — `HorizontalPager` with `userScrollEnabled = false` for the slide animation. Progress dots at the top show step n/8.

After step 8 → `OnboardingSetupLoadingScreen` → on success, navigate to `main` and pop the back stack. On failure, snackbar with Retry.

A `OnboardingPrefs` DataStore-backed flag (`hasCompletedHealthProfile`) is set on success. Splash uses this flag + a DB check to decide the post-login destination.

## Question content (verbatim from iOS)

Pulled from `swastricare-mobile-swift/ViewModels/OneQuestionOnboardingViewModel.swift` and `Models/OnboardingModels.swift`.

| # | Title | Subtitle | Input | Persisted |
|---|---|---|---|---|
| 1 | What's your name? | This is how we'll address you | Single-line text | `health_profiles.full_name` |
| 2 | Which gender do you identify with? | Select your gender identity | 4-pill row: Male / Female / Other / Prefer not to say | `health_profiles.gender` |
| 3 | What's your date of birth? | This helps us provide age-appropriate insights | Wheel date picker (Material `DatePicker` set to year-month-day spinner mode) | `health_profiles.date_of_birth` |
| 4 | How tall are you? | Select your height | Slider 100–250 cm with cm/ft toggle | `health_profiles.height_cm` |
| 5 | What is your weight? | Select your weight | Slider 20–250 kg with kg/lb toggle | `health_profiles.weight_kg` |
| 6 | What's your primary health goal? | Select your main health objective | Single-select list: Track health, Control sugar, Control BP, Improve heart health, Improve sleep, Reduce stress, Fitness tracking, Pregnancy care, Other | **No** |
| 7 | What's your activity level? | How active are you daily? | Single-select list: Sedentary, Light, Moderate, Very active | **No** |
| 8 | How much water do you drink daily? | Daily water consumption | Single-select list: <1L, 1-2L, 2-3L, 3L+ | **No** |

`blood_type` is left null (iOS does the same in this flow).

## Components & files

**New**

- `ui/screens/onboarding/OneQuestionOnboardingScreen.kt` — host composable. Holds the 8 step composables in the same file.
- `ui/screens/onboarding/OnboardingSetupLoadingScreen.kt` — finish transition.
- `ui/screens/onboarding/OneQuestionOnboardingViewModel.kt` — Hilt VM. State: `OnboardingFormState`, current step index, validation flags, submit state. Submit calls `profileRepository.createHealthProfile(...)` then `profileRepository.markUserOnboardingComplete(userId, fullName)` (new method).
- `data/local/OnboardingPrefs.kt` — DataStore wrapper for `hasCompletedHealthProfile: Boolean`.

**Modified**

- `navigation/AppNavigation.kt` — splash/post-login decision now reads (in order): auth state → `OnboardingPrefs.hasCompletedHealthProfile` → DB lookup `profileRepository.getHealthProfile(userId)`. Routes to `health_profile` if no row.
- `di/AppContainer.kt` (or relevant Hilt module) — provide `OnboardingPrefs`.
- `data/repository/ProfileRepositoryImpl.kt` — add `markUserOnboardingComplete(userId, fullName)` that updates `users.full_name` and `users.onboarding_completed = true`. Mirrors iOS `HealthProfileService.swift:105–125`.

**Deleted**

- `ui/screens/onboarding/HealthProfileScreen.kt` — replaced by the new flow.

## Visual conventions (Android brand)

- Background: pure `Color.White` everywhere (per standing rule).
- CTA: solid `AITeal`, 56dp tall, 16dp corner radius, no gradient (per standing rule).
- Title: `headlineSmall`, bold, `AppColors.onSurface`.
- Subtitle: `bodyMedium`, `AppColors.onSurfaceVariant`.
- Progress dots: 8 dots, current dot AITeal, others `AppColors.outlineVariant`.
- Back arrow: standard top-leading `IconButton` with `Icons.AutoMirrored.Filled.ArrowBack`.
- Pill selectors (Q2, Q6–Q8): `RoundedCornerShape(50.dp)`, AITeal fill when selected, `AITeal.copy(alpha=0.1f)` when not.
- Slider thumb / track: AITeal.
- Loading screen: vertical center, AITeal `CircularProgressIndicator`, caption "Setting up your profile…", switches to a green check icon + "All set!" on success.

## Data flow

```
SplashScreen
   └─ authViewModel.isLoggedIn?
        ├─ no  → "login"
        └─ yes → OnboardingPrefs.hasCompletedHealthProfile?
                 ├─ true  → "main"
                 └─ false → profileRepository.getHealthProfile(uid)?
                            ├─ Success(non-null) → mark prefs true, "main"
                            └─ Success(null) or Error → "health_profile"
```

`OneQuestionOnboardingViewModel.submit()`:

1. Build `HealthProfile` domain from collected answers.
2. `profileRepository.createHealthProfile(profile)` → INSERT into `health_profiles`.
3. `profileRepository.markUserOnboardingComplete(userId, fullName)` → UPDATE `users` row.
4. `onboardingPrefs.setCompleted(true)`.
5. Emit `Success` state → screen navigates to `main` and pops the back stack.

## Error handling

- Each step validates locally; Continue is disabled until valid (no error text displayed mid-step).
- Final submit failure (network, RLS, etc.) → loading screen flips to error state with the Postgrest message and a "Retry" button.
- Splash DB check failure → fall back to local flag; if also missing, route to onboarding (over-show is safer than skip).
- Network failure on retry → snackbar, stay on loading screen.

## Test plan

1. `cd android && ./gradlew assembleDebug` → green.
2. Cold-launch existing logged-in account with no `health_profiles` row → lands on Q1.
3. Complete all 8 steps → loading splash → main.
4. Navigate to Family → enter a valid invite code → join succeeds (no "Health profile not found").
5. Cold-launch again → lands directly on main (flag set).
6. Brand-new sign-up → after login, lands on Q1.
7. Force-stop and clear DataStore (`adb shell pm clear com.swastricare.health`) on a profile-bearing account → splash should flip the flag back to true after the DB check and route to main.

## Out of scope

- No schema changes. Q6/Q7/Q8 are dropped after collection.
- No referral-code screen (iOS has one between login and onboarding; not requested).
- No re-edit flow from settings (existing profile-edit screens are unchanged).
- Animations are Material defaults (slide transition between steps); no custom Lottie or hero animations.
