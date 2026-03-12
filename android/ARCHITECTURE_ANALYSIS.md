# Android Architecture Analysis & Recommendations

**Project:** SwastriCare Android
**Package:** `com.swastricare.health`
**Architecture Pattern:** MVVM + Repository Pattern
**Analysis Date:** March 12, 2026

---

## 📊 Current Architecture Overview

### Package Structure
```
com.swastricare.health/
├── data/                          # Data layer
│   ├── helpers/                   # Auth helpers (Google Sign-In)
│   ├── model/                     # Domain models (7 files) ⚠️
│   ├── models/                    # Feature models (8 files) ⚠️
│   ├── repository/                # 13 repositories (~2,387 lines)
│   ├── services/                  # 20+ platform services
│   ├── workers/                   # WorkManager background tasks
│   └── SupabaseConfig.kt
├── di/                            # Dependency injection
│   └── AppContainer.kt            # Manual DI container (370 lines)
├── navigation/                    # Deep link handling
│   └── DeepLinkHandler.kt
├── notifications/                 # Local notification scheduling
│   ├── MedicationReminderReceiver.kt
│   └── MedicationReminderScheduler.kt
├── ui/                            # Presentation layer
│   ├── components/                # Shared UI components
│   ├── lock/                      # Biometric lock screen
│   ├── navigation/                # Navigation graph & bottom bar
│   ├── screens/                   # 17 feature screens + ViewModels
│   └── theme/                     # Design system (Color, Type, Theme)
├── widgets/                       # App widgets (5 widgets)
├── MainActivity.kt
└── SwastriCareApplication.kt
```

**Total Files:** 166 Kotlin files
**Lines of Code:** ~15,000+ (estimated)

---

## ✅ Strengths (What's Done Well)

### 1. **Clean Architecture Layers**
- ✅ Clear separation: `data` → `repository` → `viewmodel` → `ui`
- ✅ Proper use of interfaces for repositories (testable & mockable)
- ✅ No direct Supabase calls in UI or ViewModels

### 2. **Modern Android Stack**
- ✅ **Jetpack Compose** for UI (100% Compose, no XML layouts)
- ✅ **Kotlin Coroutines & Flow** for async/reactive programming
- ✅ **ViewModel + StateFlow** for state management
- ✅ **Navigation Compose** for routing
- ✅ **WorkManager** for background tasks
- ✅ **Health Connect** integration

### 3. **Security**
- ✅ **EncryptedSharedPreferences** (AES-256-GCM) for sensitive data
- ✅ Automatic migration from plain SharedPreferences
- ✅ Biometric authentication (fingerprint/face unlock)
- ✅ Secure credential storage with Master Key

### 4. **Data Management**
- ✅ Local-first architecture with cloud sync
- ✅ Offline support via SharedPreferences caching
- ✅ Proper error handling with `Result<T>` types
- ✅ Repository pattern abstracts all data sources

### 5. **Code Organization**
- ✅ Feature-based screen organization (`ui/screens/hydration/*`)
- ✅ Shared components extracted to `ui/components/`
- ✅ Centralized theme in `ui/theme/`
- ✅ Consistent naming conventions

### 6. **Firebase Integration**
- ✅ Crashlytics for crash reporting
- ✅ Analytics for user behavior tracking
- ✅ Performance monitoring

---

## ⚠️ Critical Issues & Anti-Patterns

### 1. **❌ No Testing Whatsoever**
**Severity:** CRITICAL

```bash
# No unit tests
android/app/src/test/        # Empty

# No integration tests
android/app/src/androidTest/ # Empty
```

**Impact:**
- Zero code coverage
- No regression safety net
- Refactoring is dangerous
- Business logic bugs go undetected

**Recommendation:** Add tests (see detailed plan in "Recommendations" section)

---

### 2. **❌ Manual Dependency Injection (Object Singleton)**
**Severity:** HIGH

```kotlin
// Current: AppContainer.kt (object singleton)
object AppContainer {
    val authRepository: SupabaseAuthRepository by lazy { /* ... */ }
    val authViewModel: AuthViewModel by lazy { /* ... */ }
    val medicationsViewModel: MedicationsViewModel by lazy { /* ... */ }
    // ... 20+ dependencies
}

// Usage in Composables
@Composable
fun HomeScreen() {
    val viewModel = AppContainer.hydrationViewModel  // ❌ Hard-coded dependency
}
```

**Problems:**
- ❌ **Not testable** — cannot inject mocks for testing
- ❌ **Tight coupling** — all code depends on AppContainer
- ❌ **Single instance only** — can't create fresh ViewModels for multiple screens
- ❌ **No scoping** — ViewModels live forever, potential memory leaks
- ❌ **Difficult to preview** — Compose previews can't easily mock dependencies

**Why This Matters:**
```kotlin
// ❌ Cannot write unit tests like this:
@Test
fun `when user logs in, profile is loaded`() {
    val mockRepo = MockAuthRepository()  // Can't inject this!
    val viewModel = AuthViewModel(mockRepo)
    // ... test assertions
}
```

**Recommendation:** Migrate to **Hilt** or **Koin** (see detailed migration plan below)

---

### 3. **❌ Missing Domain Layer**
**Severity:** MEDIUM-HIGH

**Current architecture:**
```
UI (Composables) → ViewModel → Repository → Supabase
                       ↑
                Business logic lives here ❌
```

**Problems:**
- Business logic scattered across ViewModels
- ViewModels are fat (100+ lines, multiple responsibilities)
- Hard to reuse logic between features
- Testing business logic requires testing ViewModels (bloated tests)

**Example of the problem:**
```kotlin
// HydrationViewModel.kt
class HydrationViewModel(...) : ViewModel() {

    // ❌ Business logic mixed with UI state management
    fun addEntry(drinkType: DrinkType, amount: Int) {
        viewModelScope.launch {
            // Validation logic
            val factor = when (drinkType) {
                DrinkType.COFFEE -> 0.8
                DrinkType.JUICE -> 0.9
                // ...
            }

            // Calculation logic
            val effectiveMl = (amount * factor).toInt()

            // Weather adjustment logic
            val weatherFactor = calculateWeatherFactor()

            // Persistence logic
            repository.addLocalEntry(entry)

            // UI state update
            _uiState.value = ...
        }
    }
}
```

**Better architecture with domain layer:**
```
UI → ViewModel → Use Case → Repository → Data Source
                     ↑
              Business logic lives here ✅
```

**Recommendation:** Introduce a `domain/` layer (see detailed plan below)

---

### 4. **❌ Duplicate Model Packages**
**Severity:** LOW-MEDIUM

```
data/model/       # 7 files (AppUser, HealthProfile, VaultCategory, etc.)
data/models/      # 8 files (AIModels, DietModels, HydrationModels, etc.)
```

**Problems:**
- Confusing for developers ("where does this model go?")
- Inconsistent organization
- No clear naming convention

**Recommendation:**
- Consolidate to `data/model/` OR
- Use feature-based organization: `data/hydration/model/`, `data/diet/model/`

---

### 5. **⚠️ God Object: AppContainer**
**Severity:** MEDIUM

`AppContainer.kt` has **370 lines** and manages:
- 13 repositories
- 20+ services
- 10+ ViewModels
- Supabase client
- SharedPreferences
- DataStore
- Google Auth
- Firebase services

**Problems:**
- Single Responsibility Principle violation
- Hard to maintain
- All dependencies in one file
- Circular dependency risk

**Recommendation:** Split into modules (see "Recommendations" section)

---

### 6. **⚠️ ViewModels Injected Globally**
**Severity:** MEDIUM

```kotlin
// AppContainer.kt
val hydrationViewModel: HydrationViewModel by lazy {
    HydrationViewModel(hydrationRepository, profileRepository, weatherService)
}

// Usage
@Composable
fun HydrationScreen() {
    val vm = AppContainer.hydrationViewModel  // ❌ Global singleton
}
```

**Problems:**
- ViewModels are singletons (should be scoped to screen lifecycle)
- State persists across screen navigations (can cause bugs)
- Can't have multiple instances (e.g., for multi-window or tablets)
- Not compatible with `viewModel()` composable function

**Proper pattern:**
```kotlin
@Composable
fun HydrationScreen(viewModel: HydrationViewModel = viewModel()) {  // ✅
    // ViewModel is scoped to composable lifecycle
}
```

---

### 7. **⚠️ No ProGuard/R8 Configuration Validation**
**Severity:** LOW-MEDIUM

```kotlin
// build.gradle.kts
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles("proguard-rules.pro")
}
```

**Risk:**
- Supabase models use Kotlin Serialization → need `@Keep` annotations
- Runtime crashes in release builds if ProGuard strips serialization metadata

**Recommendation:** Add serialization keep rules (see below)

---

## 📋 Detailed Recommendations

### Priority 1: Add Testing Infrastructure (CRITICAL)

#### Step 1: Add test dependencies

**File:** `android/app/build.gradle.kts`
```kotlin
dependencies {
    // Unit testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.0")
    testImplementation("io.mockk:mockk:1.13.9")
    testImplementation("app.cash.turbine:turbine:1.0.0")  // Flow testing
    testImplementation("com.google.truth:truth:1.1.5")

    // Android instrumented tests
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:1.6.0")
    debugImplementation("androidx.compose.ui:ui-test-manifest:1.6.0")
}
```

#### Step 2: Create test structure

```
android/app/src/
├── test/kotlin/com/swastricare/health/
│   ├── data/
│   │   └── repository/
│   │       ├── HydrationRepositoryTest.kt
│   │       └── MedicationRepositoryTest.kt
│   ├── domain/
│   │   └── usecase/
│   │       ├── AddHydrationEntryUseCaseTest.kt
│   │       └── CalculateGoalUseCaseTest.kt
│   └── ui/
│       └── viewmodel/
│           └── HydrationViewModelTest.kt
│
└── androidTest/kotlin/com/swastricare/health/
    ├── ui/
    │   └── HydrationScreenTest.kt
    └── integration/
        └── HydrationFlowTest.kt
```

#### Step 3: Example repository test

**File:** `android/app/src/test/.../HydrationRepositoryTest.kt`
```kotlin
class HydrationRepositoryTest {

    private lateinit var repository: HydrationRepository
    private lateinit var mockPrefs: SharedPreferences
    private lateinit var mockSupabase: SupabaseClient

    @Before
    fun setup() {
        mockPrefs = mockk(relaxed = true)
        mockSupabase = mockk(relaxed = true)
        repository = SupabaseHydrationRepository(mockSupabase, mockPrefs)
    }

    @Test
    fun `loadLocalEntries returns empty list when no data`() {
        every { mockPrefs.getString("hydration_entries", null) } returns null

        val result = repository.loadLocalEntries()

        assertThat(result).isEmpty()
    }

    @Test
    fun `addLocalEntry persists to SharedPreferences`() {
        val entry = HydrationEntry(
            id = "1",
            amountMl = 250,
            drinkType = "water",
            consumedAt = "2026-03-12T10:00:00"
        )

        repository.addLocalEntry(entry)

        verify {
            mockPrefs.edit().putString(
                "hydration_entries",
                match { it.contains("\"id\":\"1\"") }
            )
        }
    }
}
```

#### Step 4: Example ViewModel test (after adding domain layer)

```kotlin
class HydrationViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var viewModel: HydrationViewModel
    private lateinit var mockUseCase: AddHydrationEntryUseCase

    @Before
    fun setup() {
        mockUseCase = mockk()
        viewModel = HydrationViewModel(mockUseCase)
    }

    @Test
    fun `addEntry updates UI state with new entry`() = runTest {
        coEvery { mockUseCase.invoke(any()) } returns Result.success(Unit)

        viewModel.addEntry(DrinkType.WATER, 250)

        viewModel.uiState.test {
            val state = awaitItem()
            assertThat(state.todaysEntries).hasSize(1)
            assertThat(state.todaysEntries[0].amountMl).isEqualTo(250)
        }
    }
}
```

**Target:** Achieve **60% code coverage** within 3 months.

---

### Priority 2: Migrate to Hilt (HIGH)

#### Why Hilt over manual DI?

| Feature | Manual DI (Current) | Hilt |
|---------|---------------------|------|
| Testability | ❌ Hard-coded dependencies | ✅ Easy to inject mocks |
| Scoping | ❌ All singletons | ✅ ViewModels, Activities, Fragments scoped |
| Boilerplate | ⚠️ Medium (370 lines) | ✅ Minimal (annotations) |
| Android-aware | ❌ No | ✅ Lifecycle-aware |
| Compose integration | ⚠️ Manual | ✅ `hiltViewModel()` |

#### Migration Plan

**Step 1:** Add Hilt dependencies

```kotlin
// android/build.gradle.kts (project-level)
buildscript {
    dependencies {
        classpath("com.google.dagger:hilt-android-gradle-plugin:2.50")
    }
}

// android/app/build.gradle.kts
plugins {
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp") version "2.0.0-1.0.21"
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.50")
    ksp("com.google.dagger:hilt-compiler:2.50")

    // Hilt ViewModel integration
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")
}
```

**Step 2:** Annotate Application class

```kotlin
@HiltAndroidApp  // Add this
class SwastriCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // No more AppContainer.initialize()
    }
}
```

**Step 3:** Create Hilt modules

**File:** `android/app/src/.../di/NetworkModule.kt`
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient {
        return createSupabaseClient(
            supabaseUrl = SupabaseConfig.SUPABASE_URL,
            supabaseKey = SupabaseConfig.SUPABASE_KEY
        ) {
            install(Auth) { /* ... */ }
            install(Postgrest)
            install(Realtime)
            install(Storage)
        }
    }
}
```

**File:** `android/app/src/.../di/RepositoryModule.kt`
```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    abstract fun bindAuthRepository(
        impl: SupabaseAuthRepository
    ): AuthRepository

    @Binds
    abstract fun bindHydrationRepository(
        impl: SupabaseHydrationRepository
    ): HydrationRepository
}
```

**Step 4:** Inject into ViewModels

```kotlin
@HiltViewModel
class HydrationViewModel @Inject constructor(
    private val repository: HydrationRepository,
    private val profileRepository: ProfileRepository,
    private val weatherService: WeatherService
) : ViewModel() {
    // Same implementation
}
```

**Step 5:** Use in Composables

```kotlin
@Composable
fun HydrationScreen(
    viewModel: HydrationViewModel = hiltViewModel()  // ✅ Injected automatically
) {
    val uiState by viewModel.uiState.collectAsState()
    // ...
}
```

**Step 6:** Annotate MainActivity

```kotlin
@AndroidEntryPoint  // Add this
class MainActivity : FragmentActivity() {
    // ...
}
```

**Benefits after migration:**
- ✅ Testable ViewModels (inject mocks)
- ✅ Proper scoping (ViewModels scoped to composable lifecycle)
- ✅ Reduced boilerplate (no manual factory creation)
- ✅ Better Compose integration

---

### Priority 3: Add Domain Layer (MEDIUM-HIGH)

#### Create domain package structure

```
android/app/src/main/kotlin/com/swastricare/health/
├── domain/
│   ├── model/              # Domain entities (pure business objects)
│   │   ├── Hydration.kt
│   │   ├── Medication.kt
│   │   └── Goal.kt
│   ├── repository/         # Repository interfaces (moved from data/)
│   │   ├── HydrationRepository.kt
│   │   └── MedicationRepository.kt
│   └── usecase/            # Business logic use cases
│       ├── hydration/
│       │   ├── AddHydrationEntryUseCase.kt
│       │   ├── CalculateHydrationGoalUseCase.kt
│       │   └── GetTodaysHydrationUseCase.kt
│       └── medication/
│           ├── AddMedicationUseCase.kt
│           └── ScheduleMedicationReminderUseCase.kt
```

#### Example Use Case

**File:** `domain/usecase/hydration/AddHydrationEntryUseCase.kt`
```kotlin
class AddHydrationEntryUseCase @Inject constructor(
    private val repository: HydrationRepository,
    private val profileRepository: ProfileRepository,
    private val analyticsService: AnalyticsService
) {
    suspend operator fun invoke(
        drinkType: DrinkType,
        amountMl: Int
    ): Result<HydrationEntry> = withContext(Dispatchers.IO) {
        try {
            // Validation
            require(amountMl > 0) { "Amount must be positive" }

            // Business logic: calculate hydration factor
            val factor = when (drinkType) {
                DrinkType.WATER -> 1.0
                DrinkType.COFFEE -> 0.8
                DrinkType.TEA -> 0.85
                DrinkType.JUICE -> 0.9
                DrinkType.MILK -> 0.88
                DrinkType.SODA -> 0.6
            }

            val effectiveMl = (amountMl * factor).toInt()

            // Create entry
            val entry = HydrationEntry(
                id = UUID.randomUUID().toString(),
                amountMl = amountMl,
                effectiveMl = effectiveMl,
                drinkType = drinkType.dbValue,
                consumedAt = LocalDateTime.now().toString(),
                synced = false
            )

            // Persist
            repository.addLocalEntry(entry)

            // Analytics
            analyticsService.logEvent("hydration_entry_added", mapOf(
                "drink_type" to drinkType.name,
                "amount_ml" to amountMl
            ))

            Result.success(entry)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

**Updated ViewModel:**
```kotlin
@HiltViewModel
class HydrationViewModel @Inject constructor(
    private val addEntryUseCase: AddHydrationEntryUseCase,  // ✅ Use case, not repository
    private val getTodaysHydrationUseCase: GetTodaysHydrationUseCase
) : ViewModel() {

    fun addEntry(drinkType: DrinkType, amount: Int) {
        viewModelScope.launch {
            addEntryUseCase(drinkType, amount)  // ✅ Clean, testable
                .onSuccess { entry ->
                    _uiState.update { it.copy(entries = it.entries + entry) }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = error.message) }
                }
        }
    }
}
```

**Benefits:**
- ✅ Business logic in testable use cases (no Android dependencies)
- ✅ Reusable across features (e.g., use case in widget + screen)
- ✅ Single Responsibility (ViewModels only manage UI state)
- ✅ Easy to test (use cases are pure Kotlin)

---

### Priority 4: Fix Model Organization (LOW)

#### Option A: Consolidate to single package

```
data/model/
├── user/
│   ├── AppUser.kt
│   └── HealthProfile.kt
├── hydration/
│   ├── HydrationEntry.kt
│   ├── HydrationPreferences.kt
│   └── HydrationGoal.kt
├── medication/
│   ├── Medication.kt
│   ├── MedicationSchedule.kt
│   └── MedicationReminder.kt
└── shared/
    ├── VaultCategory.kt
    └── HealthNudge.kt
```

#### Option B: Feature-based models

```
data/
├── hydration/
│   ├── model/
│   │   ├── HydrationEntry.kt
│   │   └── HydrationPreferences.kt
│   └── repository/
│       └── HydrationRepository.kt
├── medication/
│   ├── model/
│   └── repository/
└── ...
```

**Recommendation:** **Option B** (feature-based) for better modularity.

---

### Priority 5: Add ProGuard Rules (LOW-MEDIUM)

**File:** `android/app/proguard-rules.pro`
```proguard
# Kotlin Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep all data models for Supabase serialization
-keep @kotlinx.serialization.Serializable class com.swastricare.health.data.model.** { *; }
-keep @kotlinx.serialization.Serializable class com.swastricare.health.data.models.** { *; }

# Supabase
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Health Connect
-keep class androidx.health.connect.client.** { *; }

# Firebase (already has default rules via google-services plugin)
# Just ensure Crashlytics doesn't strip stack traces
-keepattributes SourceFile,LineNumberTable
```

---

## 🎯 Migration Roadmap

### Phase 1: Foundation (2-3 weeks)
1. ✅ Add test dependencies to `build.gradle.kts`
2. ✅ Set up test folder structure
3. ✅ Write first repository tests (HydrationRepository, MedicationRepository)
4. ✅ Add ProGuard rules for serialization

### Phase 2: Dependency Injection (1-2 weeks)
1. ✅ Add Hilt dependencies
2. ✅ Create Hilt modules (NetworkModule, RepositoryModule)
3. ✅ Migrate 1-2 ViewModels to Hilt (e.g., HydrationViewModel, AuthViewModel)
4. ✅ Test migrated screens
5. ✅ Gradually migrate remaining ViewModels
6. ✅ Delete AppContainer once migration is complete

### Phase 3: Domain Layer (2-3 weeks)
1. ✅ Create `domain/` package structure
2. ✅ Move repository interfaces to `domain/repository/`
3. ✅ Create use cases for 2-3 features (hydration, medication)
4. ✅ Write use case unit tests
5. ✅ Update ViewModels to use use cases
6. ✅ Gradually extract business logic from remaining ViewModels

### Phase 4: Model Reorganization (1 week)
1. ✅ Choose feature-based model organization
2. ✅ Create new package structure
3. ✅ Move files and update imports
4. ✅ Delete duplicate `data/model` and `data/models` packages

### Phase 5: Testing & Refinement (Ongoing)
1. ✅ Achieve 60% code coverage
2. ✅ Add integration tests for critical flows
3. ✅ Add UI tests for key screens (Compose UI testing)
4. ✅ Set up CI to run tests on every PR

**Total estimated time:** 8-12 weeks (part-time)

---

## 📈 Success Metrics

| Metric | Current | Target (3 months) |
|--------|---------|-------------------|
| Unit test coverage | 0% | 60% |
| Repository tests | 0 | 13 (one per repository) |
| Use case tests | 0 | 30+ |
| ViewModel tests | 0 | 10+ (key ViewModels) |
| DI framework | Manual | Hilt |
| Domain layer | None | Use cases for 6+ features |
| Model packages | 2 (inconsistent) | 1 (feature-based) |
| ProGuard validation | None | Validated on release builds |

---

## 🏗️ Architecture Comparison

### Current (Before)
```
┌─────────────────────────────────────┐
│           UI (Compose)              │
│  - Screens + ViewModels (fat)       │
│  - Business logic here ❌           │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│      Repository Interface           │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│  Data Layer (Supabase + SharedPrefs)│
└─────────────────────────────────────┘

DI: AppContainer object (global singletons) ❌
Testing: 0% coverage ❌
```

### Recommended (After)
```
┌─────────────────────────────────────┐
│           UI (Compose)              │
│  - Screens + ViewModels (thin)      │
│  - Only UI state management ✅      │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│    Domain Layer (Use Cases)         │
│  - Business logic ✅                │
│  - Pure Kotlin, testable ✅         │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│      Repository Interface           │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│  Data Layer (Supabase + SharedPrefs)│
└─────────────────────────────────────┘

DI: Hilt (scoped, testable) ✅
Testing: 60%+ coverage ✅
```

---

## 🔧 Appendix: Quick Wins (Can implement immediately)

### 1. Add EditorConfig for consistency
**File:** `android/.editorconfig`
```ini
[*.{kt,kts}]
indent_size = 4
insert_final_newline = true
max_line_length = 120
```

### 2. Add ktlint for code formatting
```kotlin
// android/build.gradle.kts
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}

ktlint {
    android.set(true)
    ignoreFailures.set(false)
}
```

### 3. Add Detekt for static analysis
```kotlin
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.5"
}

detekt {
    config.setFrom("$projectDir/config/detekt.yml")
    buildUponDefaultConfig = true
}
```

### 4. Add GitHub Actions CI
**File:** `.github/workflows/android-ci.yml`
```yaml
name: Android CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - name: Build with Gradle
        run: cd android && ./gradlew assembleDebug
      - name: Run tests
        run: cd android && ./gradlew test
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## 📚 References & Resources

- [Android Architecture Guide](https://developer.android.com/topic/architecture)
- [Guide to app architecture](https://developer.android.com/topic/architecture/recommendations)
- [Hilt Documentation](https://developer.android.com/training/dependency-injection/hilt-android)
- [Testing ViewModels](https://developer.android.com/codelabs/android-testing)
- [Compose Testing](https://developer.android.com/jetpack/compose/testing)

---

## Summary

Your Android architecture is **solid** for an MVP, with clean separation of concerns and modern Android patterns. However, to scale and maintain long-term quality:

**Must Fix (Critical):**
1. ❌ **No tests** — blocks refactoring, prevents regression detection
2. ❌ **Manual DI** — prevents unit testing, tight coupling

**Should Fix (High Priority):**
3. ⚠️ **No domain layer** — business logic scattered, hard to test
4. ⚠️ **ViewModels as singletons** — lifecycle issues, memory leaks

**Nice to Have (Medium Priority):**
5. ⚠️ **Duplicate model packages** — confusing organization
6. ⚠️ **ProGuard validation** — potential release build crashes

Follow the migration roadmap, and your codebase will be production-ready, testable, and maintainable at scale. 🚀
