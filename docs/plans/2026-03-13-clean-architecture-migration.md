# Clean Architecture Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the Android Clean Architecture migration by populating Hilt modules, wiring new ViewModels into navigation, and retiring AppContainer.

**Architecture:** Migrate from manual DI (AppContainer singleton with 56 lazy properties) to Hilt dependency injection. New `*RepositoryImpl` classes already exist with `@Inject constructor` — they just need Hilt `@Binds` wiring. New `presentation/feature/` ViewModels exist but are orphaned — navigation still uses old `ui/screens/` ViewModels from AppContainer.

**Tech Stack:** Kotlin 2.0.20, Hilt/Dagger 2.51, Jetpack Compose, Supabase SDK 2.6.0, KSP

---

## Current State Inventory

### Domain Repository Interfaces (12)
`domain/repository/`: AIRepository, AnalyticsRepository, AuthRepository, DietRepository, FamilyRepository, HeartRateRepository, HydrationRepository, MedicationRepository, MenstrualCycleRepository, ProfileRepository, RunActivityRepository, VaultRepository

### New RepositoryImpl Classes (11) — all have `@Inject constructor`
`data/repository/`: AIRepositoryImpl, AnalyticsRepositoryImpl, AuthRepositoryImpl, DietRepositoryImpl, FamilyRepositoryImpl, HeartRateRepositoryImpl, HydrationRepositoryImpl, MedicationRepositoryImpl, MenstrualCycleRepositoryImpl, ProfileRepositoryImpl, VaultRepositoryImpl
`data/repository/runactivity/`: RunActivityRepositoryImpl

### Old Supabase* Repository Classes (still used by AppContainer)
`data/repository/`: SupabaseAuthRepository, SupabaseProfileRepository, SupabaseVaultRepository, SupabaseMedicationRepository, SupabaseDietRepository, SupabaseHydrationRepository, SupabaseFamilyRepository, SupabaseAIConversationRepository, SupabaseMenstrualCycleRepository, SupabaseRunActivityRepository, SupabaseNudgeRepository

### New Presentation ViewModels (8 — orphaned, not wired)
`presentation/feature/`: AuthViewModel, AIViewModel, DietViewModel, HydrationViewModel, MedicationsViewModel, ProfileViewModel, RunActivityViewModel, VaultViewModel

### Old UI ViewModels (18+ — currently in use via AppContainer)
`ui/screens/`: AuthViewModel, AIViewModel, DietViewModel, HydrationViewModel, MedicationsViewModel, ProfileViewModel, RunActivityViewModel, HeartRateViewModel, HomeViewModel, FamilyViewModel, MenstrualCycleViewModel, HealthAnalyticsViewModel, LiveWorkoutViewModel, RunCalendarViewModel, SettingsViewModel, NotificationSettingsViewModel, ARBodyScanViewModel, HeartRateViewModelNew, HealthAnalyticsViewModelNew, MenstrualCycleViewModelNew

---

## Migration Phases

### Phase 1: Wire Hilt Repository Bindings (RepositoryModule.kt)

**Rationale:** This is the foundation — all new ViewModels depend on domain repository interfaces being injectable via Hilt.

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/di/RepositoryModule.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/di/ServiceModule.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/di/AppModule.kt`

**What to do:**

1. Populate `RepositoryModule.kt` with `@Binds @Singleton` for all 12 repository interfaces:

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds @Singleton
    abstract fun bindAuthRepository(impl: AuthRepositoryImpl): AuthRepository

    @Binds @Singleton
    abstract fun bindProfileRepository(impl: ProfileRepositoryImpl): ProfileRepository

    @Binds @Singleton
    abstract fun bindHydrationRepository(impl: HydrationRepositoryImpl): HydrationRepository

    @Binds @Singleton
    abstract fun bindMedicationRepository(impl: MedicationRepositoryImpl): MedicationRepository

    @Binds @Singleton
    abstract fun bindDietRepository(impl: DietRepositoryImpl): DietRepository

    @Binds @Singleton
    abstract fun bindRunActivityRepository(impl: RunActivityRepositoryImpl): RunActivityRepository

    @Binds @Singleton
    abstract fun bindVaultRepository(impl: VaultRepositoryImpl): VaultRepository

    @Binds @Singleton
    abstract fun bindFamilyRepository(impl: FamilyRepositoryImpl): FamilyRepository

    @Binds @Singleton
    abstract fun bindAIRepository(impl: AIRepositoryImpl): AIRepository

    @Binds @Singleton
    abstract fun bindAnalyticsRepository(impl: AnalyticsRepositoryImpl): AnalyticsRepository

    @Binds @Singleton
    abstract fun bindHeartRateRepository(impl: HeartRateRepositoryImpl): HeartRateRepository

    @Binds @Singleton
    abstract fun bindMenstrualCycleRepository(impl: MenstrualCycleRepositoryImpl): MenstrualCycleRepository
}
```

2. Add Logger binding to `ServiceModule.kt`:

```kotlin
@Binds @Singleton
abstract fun bindLogger(impl: LoggerImpl): Logger
```

Note: `ServiceModule` is currently an `object` — must convert to `abstract class` with a `companion object` holding `@Provides` methods, OR create a separate `ServiceBindsModule` abstract class.

3. Ensure `LoggerImpl` has `@Inject constructor` and `CrashReporter` is provided. If `LoggerImpl` doesn't have `@Inject`, add it or use `@Provides`.

4. Fix SharedPreferences qualifier issue: RepositoryImpl classes take `SharedPreferences` without qualifier, but `DatabaseModule` provides with `@EncryptedPrefs` and `@RegularPrefs` qualifiers. Either:
   - Add a non-qualified `@Provides` that delegates to `@EncryptedPrefs`, OR
   - Add `@EncryptedPrefs` qualifier to all RepositoryImpl constructor params

**Recommended approach:** Add a non-qualified provider in `DatabaseModule`:
```kotlin
@Provides @Singleton
fun provideSharedPreferences(@EncryptedPrefs prefs: SharedPreferences): SharedPreferences = prefs
```

5. Build and verify: `cd android && ./gradlew assembleDebug`

---

### Phase 2: Verify New Presentation ViewModels Compile with Hilt

**Rationale:** With repository bindings in place, the new `@HiltViewModel` ViewModels should now be injectable. Verify each compiles and fix any missing dependencies.

**Files:**
- All files in `android/app/src/main/kotlin/com/swastricare/health/presentation/feature/*/`

**What to do:**

1. Verify each presentation ViewModel has `@HiltViewModel` and `@Inject constructor`
2. Verify their constructor params match what Hilt can provide (domain repository interfaces, use cases)
3. Ensure use cases have `@Inject constructor` — check all ~75 use case files
4. Build and verify: `cd android && ./gradlew assembleDebug`

---

### Phase 3: Migrate Navigation to Hilt ViewModels (Feature by Feature)

**Rationale:** This is the actual screen-level migration. Each feature's screen switches from `AppContainer.xxxViewModel` to `hiltViewModel()`. Do this one feature at a time to minimize risk.

**Order of migration** (least risk to most risk):

#### 3a. Auth (Login/Signup/Reset)
- Old: `ui/screens/auth/AuthViewModel` via `AppContainer.authViewModel`
- New: `presentation/feature/auth/AuthViewModel` via `hiltViewModel()`
- Files: `AppNavigation.kt`, `LoginScreen.kt`, `SignUpScreen.kt`, `ResetPasswordScreen.kt`, `EmailVerificationScreen.kt`

#### 3b. Hydration
- Old: `ui/screens/hydration/HydrationViewModel` via `AppContainer.hydrationViewModel`
- New: `presentation/feature/hydration/HydrationViewModel` via `hiltViewModel()`
- Files: `MainScreen.kt` (or wherever HydrationScreen is composed)

#### 3c. Diet
- Old: `ui/screens/diet/DietViewModel` via `AppContainer.dietViewModel`
- New: `presentation/feature/diet/DietViewModel` via `hiltViewModel()`

#### 3d. Medication
- Old: `ui/screens/medications/MedicationsViewModel` via `AppContainer.medicationsViewModel`
- New: `presentation/feature/medication/MedicationsViewModel` via `hiltViewModel()`

#### 3e. Profile
- Old: `ui/screens/profile/ProfileViewModel`
- New: `presentation/feature/profile/ProfileViewModel` via `hiltViewModel()`

#### 3f. Vault
- Old: `ui/screens/vault/VaultViewModel`
- New: `presentation/feature/vault/VaultViewModel` via `hiltViewModel()`

#### 3g. AI Chat
- Old: `ui/screens/ai/AIViewModel`
- New: `presentation/feature/ai/AIViewModel` via `hiltViewModel()`

#### 3h. Run Activity
- Old: `ui/screens/runactivity/RunActivityViewModel` via `AppContainer.runActivityViewModel`
- New: `presentation/feature/runactivity/RunActivityViewModel` via `hiltViewModel()`

**For each feature:**
1. Find all screen composables that reference the old ViewModel
2. Replace `AppContainer.xxxViewModel` with `hiltViewModel<XxxViewModel>()`
3. Update imports from `ui.screens.xxx.XxxViewModel` to `presentation.feature.xxx.XxxViewModel`
4. If screens use ViewModel-specific state classes, update to new `*UiState` from `presentation/feature/`
5. Build and verify

---

### Phase 4: Migrate Remaining ViewModels Without New Counterparts

**Rationale:** Some old ViewModels don't have new `presentation/feature/` counterparts yet. These need to be created OR migrated in-place to use `@HiltViewModel`.

**ViewModels needing new presentation counterparts:**
- `FamilyViewModel` — already partially migrated (uses domain use cases + AppContainer)
- `HeartRateViewModel` — has `HeartRateViewModelNew` in `ui/screens/heartrate/`
- `HealthAnalyticsViewModel` — has `HealthAnalyticsViewModelNew` in `ui/screens/analytics/`
- `MenstrualCycleViewModel` — has `MenstrualCycleViewModelNew` in `ui/screens/menstrualcycle/`
- `LiveWorkoutViewModel` — no new counterpart
- `HomeViewModel` — no new counterpart
- `SettingsViewModel` — no new counterpart
- `NotificationSettingsViewModel` — no new counterpart
- `ARBodyScanViewModel` — no new counterpart
- `RunCalendarViewModel` — no new counterpart

**For VMs with "New" variants:** Wire the *New variants into navigation, remove old variants.
**For VMs without counterparts:** Add `@HiltViewModel` + `@Inject constructor` to existing VM, update it to use domain repositories.

---

### Phase 5: Retire AppContainer

**Rationale:** Once all ViewModels use Hilt, AppContainer can be removed.

1. Remove all `AppContainer.xxxViewModel` references
2. Remove all `AppContainer.xxxRepository` references (screens should use Hilt-injected VMs)
3. Keep `AppContainer` only for:
   - Widget code (`WidgetActionReceiver`, `WidgetDataManager`) — widgets can't use Hilt easily
   - OR migrate widgets to use `EntryPointAccessors` from Hilt
4. Delete old `Supabase*Repository` classes that are fully replaced by `*RepositoryImpl`
5. Delete old `ui/screens/*/XxxViewModel` classes that are fully replaced by `presentation/feature/*/XxxViewModel`
6. Final build + test: `cd android && ./gradlew assembleDebug && ./gradlew test`

---

## Execution Strategy

**Phases 1-2 are independent of each other and can be parallelized.**
**Phase 3 features (3a-3h) are independent and can be parallelized.**
**Phases 4-5 depend on Phase 3 completion.**

### Recommended Agent Split:
- **Agent 1:** Phase 1 (RepositoryModule + dependency wiring)
- **Agent 2:** Phase 2 (Verify use cases + presentation VMs have @Inject)
- After both complete and build passes:
- **Agents 3-6:** Phase 3 features in parallel (2 features per agent)
- After Phase 3 complete:
- **Phase 4-5:** Sequential, single agent

---

## Build Verification Command

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

## Success Criteria
- `./gradlew assembleDebug` passes with 0 errors
- All screens use `hiltViewModel()` instead of `AppContainer.*ViewModel`
- `RepositoryModule.kt` has @Binds for all 12 repository interfaces
- AppContainer has no ViewModel properties (only retained for widget support if needed)
- No duplicate repository implementations remain
