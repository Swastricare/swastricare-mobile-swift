# Migration Guide: Current → Clean Architecture

**From:** Current MVVM + Repository Pattern
**To:** Enterprise Clean Architecture + MVVM

---

## Migration Strategy

### Phase 1: Add Domain Layer (Week 1-2)
### Phase 2: Refactor Data Layer (Week 3-4)
### Phase 3: Migrate to Hilt (Week 5-6)
### Phase 4: Update Presentation Layer (Week 7-8)

---

## Before & After Comparison

### Current Architecture (SwastriCare)

```
com.swastricare.health/
├── data/
│   ├── model/              # Domain + DTO mixed ❌
│   ├── models/             # Duplicate ❌
│   ├── repository/         # Implementation only ❌
│   └── services/
├── ui/
│   └── screens/
│       └── hydration/
│           ├── HydrationViewModel.kt    # Business logic here ❌
│           └── HydrationScreen.kt
└── di/
    └── AppContainer.kt     # Manual DI ❌
```

### Recommended Architecture

```
com.swastricare.health/
├── domain/                 # Pure Kotlin ✅
│   ├── model/             # Domain entities
│   ├── repository/        # Interfaces ✅
│   └── usecase/           # Business logic ✅
├── data/
│   ├── remote/
│   │   ├── dto/           # API models ✅
│   │   └── api/
│   ├── repository/        # Implementations ✅
│   └── mapper/            # DTO ↔ Domain ✅
├── presentation/
│   └── feature/
│       └── hydration/
│           ├── HydrationViewModel.kt   # Thin, uses use cases ✅
│           ├── HydrationUiState.kt     # Separate state ✅
│           └── HydrationScreen.kt
└── di/
    └── modules/           # Hilt modules ✅
```

---

## Step-by-Step Migration

### Step 1: Create Domain Layer

#### 1.1 Create Package Structure

```bash
mkdir -p android/app/src/main/kotlin/com/swastricare/health/domain/{model,repository,usecase}
```

#### 1.2 Move Models to Domain

**Before:** `data/models/HydrationModels.kt`
```kotlin
// Mixed data models ❌
data class HydrationEntry(...)
data class HydrationEntryRecord(...)  // DTO
data class HydrationPreferences(...)
```

**After:** `domain/model/Hydration.kt`
```kotlin
package com.swastricare.health.domain.model

// Pure domain model ✅
data class HydrationEntry(
    val id: String,
    val amountMl: Int,
    val effectiveMl: Int,
    val drinkType: String,
    val consumedAt: Instant,
    val synced: Boolean
) {
    // Business logic methods
    fun isWater(): Boolean = drinkType == "water"
    fun isCaffeinated(): Boolean = drinkType in listOf("coffee", "tea")
}

data class HydrationGoal(
    val dailyGoalMl: Int,
    val adjustForWeather: Boolean = false
)
```

**Create DTO:** `data/remote/dto/hydration/HydrationDto.kt`
```kotlin
package com.swastricare.health.data.remote.dto.hydration

import kotlinx.serialization.SerializedName
import kotlinx.serialization.Serializable

// API response model ✅
@Serializable
data class HydrationEntryDto(
    @SerializedName("id")
    val id: String,

    @SerializedName("amount_ml")
    val amountMl: Int,

    @SerializedName("hydration_factor")
    val hydrationFactor: Double,

    @SerializedName("drink_type")
    val drinkType: String,

    @SerializedName("consumed_at")
    val consumedAt: String,

    @SerializedName("health_profile_id")
    val healthProfileId: String
)
```

---

### Step 2: Extract Repository Interfaces

#### Before: `data/repository/HydrationRepository.kt`
```kotlin
// Interface in data layer ❌
interface HydrationRepository {
    fun loadLocalEntries(): List<HydrationEntry>
    suspend fun fetchFromCloud(profileId: String): Result<List<HydrationEntry>>
}

class SupabaseHydrationRepository(...) : HydrationRepository {
    // Implementation
}
```

#### After

**Interface:** `domain/repository/HydrationRepository.kt`
```kotlin
package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.HydrationEntry

// Repository contract in domain ✅
interface HydrationRepository {
    suspend fun getEntries(profileId: String, date: LocalDate): ResultWrapper<List<HydrationEntry>>
    suspend fun addEntry(entry: HydrationEntry): ResultWrapper<HydrationEntry>
    suspend fun deleteEntry(entryId: String): ResultWrapper<Unit>
    suspend fun syncEntries(profileId: String): ResultWrapper<Unit>
}
```

**Implementation:** `data/repository/HydrationRepositoryImpl.kt`
```kotlin
package com.swastricare.health.data.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.HydrationMapper
import com.swastricare.health.data.remote.api.HydrationApi
import com.swastricare.health.domain.model.HydrationEntry
import com.swastricare.health.domain.repository.HydrationRepository
import javax.inject.Inject

// Implementation in data layer ✅
class HydrationRepositoryImpl @Inject constructor(
    private val api: HydrationApi,
    private val mapper: HydrationMapper
) : HydrationRepository {

    override suspend fun getEntries(
        profileId: String,
        date: LocalDate
    ): ResultWrapper<List<HydrationEntry>> {
        return try {
            val response = api.getEntries(profileId, date.toString())
            if (response.isSuccessful) {
                val dtos = response.body()?.data ?: emptyList()
                ResultWrapper.Success(mapper.toDomainList(dtos))
            } else {
                ResultWrapper.Error(mapError(response.code()))
            }
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.NetworkException.Unknown(e))
        }
    }

    // Other methods...
}
```

---

### Step 3: Create Use Cases

#### Before: Business logic in ViewModel ❌

**File:** `ui/screens/hydration/HydrationViewModel.kt`
```kotlin
class HydrationViewModel(...) : ViewModel() {

    fun addEntry(drinkType: DrinkType, amount: Int) {
        viewModelScope.launch {
            // ❌ Business logic in ViewModel
            val factor = when (drinkType) {
                DrinkType.COFFEE -> 0.8
                DrinkType.JUICE -> 0.9
                // ...
            }
            val effectiveMl = (amount * factor).toInt()

            // ❌ Weather adjustment logic
            val weatherFactor = calculateWeatherFactor()

            val entry = HydrationEntry(...)
            repository.addLocalEntry(entry)

            // ❌ UI state update
            _uiState.value = ...
        }
    }
}
```

#### After: Business logic in Use Case ✅

**File:** `domain/usecase/hydration/AddHydrationEntryUseCase.kt`
```kotlin
package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.HydrationEntry
import com.swastricare.health.domain.repository.HydrationRepository
import java.time.LocalDateTime
import java.util.UUID
import javax.inject.Inject

// ✅ Business logic in use case
class AddHydrationEntryUseCase @Inject constructor(
    private val repository: HydrationRepository
) {
    suspend operator fun invoke(
        drinkType: String,
        amountMl: Int
    ): ResultWrapper<HydrationEntry> {

        // ✅ Validation
        if (amountMl <= 0) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Amount must be positive")
            )
        }

        // ✅ Business logic: calculate hydration factor
        val factor = when (drinkType) {
            "water" -> 1.0
            "coffee" -> 0.8
            "tea" -> 0.85
            "juice" -> 0.9
            "milk" -> 0.88
            "soda" -> 0.6
            else -> 1.0
        }

        val effectiveMl = (amountMl * factor).toInt()

        // ✅ Create domain entity
        val entry = HydrationEntry(
            id = UUID.randomUUID().toString(),
            amountMl = amountMl,
            effectiveMl = effectiveMl,
            drinkType = drinkType,
            consumedAt = LocalDateTime.now(),
            synced = false
        )

        // ✅ Delegate to repository
        return repository.addEntry(entry)
    }
}
```

**Updated ViewModel:** `presentation/feature/hydration/HydrationViewModel.kt`
```kotlin
@HiltViewModel
class HydrationViewModel @Inject constructor(
    private val addEntryUseCase: AddHydrationEntryUseCase,  // ✅ Use case injection
    private val getEntriesUseCase: GetHydrationEntriesUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(HydrationUiState())
    val uiState: StateFlow<HydrationUiState> = _uiState.asStateFlow()

    // ✅ Thin ViewModel - only UI state management
    fun addEntry(drinkType: String, amount: Int) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            when (val result = addEntryUseCase(drinkType, amount)) {
                is ResultWrapper.Success -> {
                    _uiState.update { state ->
                        state.copy(
                            isLoading = false,
                            entries = state.entries + result.data
                        )
                    }
                }
                is ResultWrapper.Error -> {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = result.exception.getUserMessage()
                        )
                    }
                }
            }
        }
    }
}
```

---

### Step 4: Migrate to Hilt

#### 4.1 Add Dependencies

**File:** `android/build.gradle.kts` (project-level)
```kotlin
plugins {
    id("com.google.dagger.hilt.android") version "2.50" apply false
}
```

**File:** `android/app/build.gradle.kts`
```kotlin
plugins {
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.50")
    ksp("com.google.dagger:hilt-compiler:2.50")

    // Hilt ViewModel
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")
}
```

---

#### 4.2 Annotate Application

**File:** `SwastriCareApplication.kt`
```kotlin
@HiltAndroidApp  // ✅ Add this
class SwastriCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Remove: AppContainer.initialize(this) ❌
    }
}
```

---

#### 4.3 Create Hilt Modules

**File:** `di/NetworkModule.kt`
```kotlin
package com.swastricare.health.di

import com.swastricare.health.BuildConfig
import com.swastricare.health.data.SupabaseConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.storage.Storage
import javax.inject.Singleton

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
            install(Auth) {
                scheme = "swastricareapp"
                host = "auth-callback"
            }
            install(Postgrest)
            install(Storage)
        }
    }
}
```

**File:** `di/RepositoryModule.kt`
```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindHydrationRepository(
        impl: HydrationRepositoryImpl
    ): HydrationRepository

    @Binds
    @Singleton
    abstract fun bindMedicationRepository(
        impl: MedicationRepositoryImpl
    ): MedicationRepository

    // ... other repositories
}
```

---

#### 4.4 Update ViewModels

**Before:** Manual DI ❌
```kotlin
class HydrationViewModel(...) : ViewModel() {
    // Constructor with manual dependencies
}

// Usage
val viewModel = AppContainer.hydrationViewModel  // ❌
```

**After:** Hilt DI ✅
```kotlin
@HiltViewModel
class HydrationViewModel @Inject constructor(
    private val addEntryUseCase: AddHydrationEntryUseCase,
    private val getEntriesUseCase: GetHydrationEntriesUseCase
) : ViewModel() {
    // Implementation
}

// Usage in Composable
@Composable
fun HydrationScreen(
    viewModel: HydrationViewModel = hiltViewModel()  // ✅
) {
    // ...
}
```

---

#### 4.5 Update MainActivity

```kotlin
@AndroidEntryPoint  // ✅ Add this
class MainActivity : FragmentActivity() {
    // No changes needed to onCreate
}
```

---

### Step 5: Add Mappers

**File:** `data/mapper/HydrationMapper.kt`
```kotlin
package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.hydration.HydrationEntryDto
import com.swastricare.health.domain.model.HydrationEntry
import java.time.Instant
import javax.inject.Inject

class HydrationMapper @Inject constructor() {

    fun toDomain(dto: HydrationEntryDto): HydrationEntry {
        return HydrationEntry(
            id = dto.id,
            amountMl = dto.amountMl,
            effectiveMl = (dto.amountMl * dto.hydrationFactor).toInt(),
            drinkType = dto.drinkType,
            consumedAt = Instant.parse(dto.consumedAt),
            synced = true
        )
    }

    fun toDomainList(dtos: List<HydrationEntryDto>): List<HydrationEntry> {
        return dtos.map { toDomain(it) }
    }

    fun toDto(domain: HydrationEntry, profileId: String): HydrationEntryDto {
        return HydrationEntryDto(
            id = domain.id,
            amountMl = domain.amountMl,
            hydrationFactor = domain.effectiveMl.toDouble() / domain.amountMl,
            drinkType = domain.drinkType,
            consumedAt = domain.consumedAt.toString(),
            healthProfileId = profileId
        )
    }
}
```

---

## Migration Checklist by Feature

For each existing feature (Hydration, Medication, Diet, etc.):

### ✅ Domain Layer
- [ ] Create domain model in `domain/model/`
- [ ] Create repository interface in `domain/repository/`
- [ ] Create use cases in `domain/usecase/<feature>/`

### ✅ Data Layer
- [ ] Create DTOs in `data/remote/dto/<feature>/`
- [ ] Create mapper in `data/mapper/`
- [ ] Rename repository implementation to `<Feature>RepositoryImpl`
- [ ] Update repository to implement domain interface
- [ ] Move business logic from repository to use cases

### ✅ Presentation Layer
- [ ] Create UI state class (`<Feature>UiState.kt`)
- [ ] Annotate ViewModel with `@HiltViewModel`
- [ ] Inject use cases (not repositories) into ViewModel
- [ ] Remove business logic from ViewModel
- [ ] Update Composable to use `hiltViewModel()`

### ✅ Dependency Injection
- [ ] Add repository binding to `RepositoryModule`
- [ ] Remove from `AppContainer`

---

## Example: Complete Hydration Feature Migration

### Files to Create/Modify

1. ✅ `domain/model/Hydration.kt` (NEW)
2. ✅ `domain/repository/HydrationRepository.kt` (MOVE from data/)
3. ✅ `domain/usecase/hydration/AddHydrationEntryUseCase.kt` (NEW)
4. ✅ `domain/usecase/hydration/GetHydrationEntriesUseCase.kt` (NEW)
5. ✅ `data/remote/dto/hydration/HydrationDto.kt` (NEW)
6. ✅ `data/mapper/HydrationMapper.kt` (NEW)
7. ✅ `data/repository/HydrationRepositoryImpl.kt` (RENAME + REFACTOR)
8. ✅ `presentation/feature/hydration/HydrationUiState.kt` (NEW)
9. ✅ `presentation/feature/hydration/HydrationViewModel.kt` (REFACTOR)
10. ✅ `di/RepositoryModule.kt` (UPDATE)

### Before/After Line Count

| Component | Before | After | Change |
|-----------|--------|-------|--------|
| ViewModel | 250 lines | 150 lines | -40% (business logic removed) |
| Repository | 200 lines | 180 lines | -10% (error handling improved) |
| Domain | 0 lines | 120 lines | +120 (new layer) |
| **Total** | 450 lines | 450 lines | Same, but better organized ✅ |

---

## Common Pitfalls & Solutions

### Pitfall 1: Putting DTOs in Domain
❌ **Wrong:**
```kotlin
// domain/model/User.kt
data class UserDto(...)  // DTO in domain ❌
```

✅ **Correct:**
```kotlin
// domain/model/User.kt
data class User(...)  // Pure domain model

// data/remote/dto/user/UserDto.kt
data class UserDto(...)  // DTO in data layer
```

---

### Pitfall 2: Domain Depends on Android
❌ **Wrong:**
```kotlin
// domain/model/User.kt
import android.os.Parcelable  // ❌ Android dependency

data class User(...) : Parcelable
```

✅ **Correct:**
```kotlin
// domain/model/User.kt
data class User(...)  // Pure Kotlin, no Android imports ✅
```

---

### Pitfall 3: Business Logic in ViewModel
❌ **Wrong:**
```kotlin
@HiltViewModel
class UserViewModel @Inject constructor(
    private val repository: UserRepository
) : ViewModel() {

    fun createUser(email: String, password: String) {
        // ❌ Validation in ViewModel
        if (!email.contains("@")) {
            // error
        }
        // ❌ Business logic in ViewModel
        repository.createUser(...)
    }
}
```

✅ **Correct:**
```kotlin
// Use case handles business logic ✅
class CreateUserUseCase @Inject constructor(
    private val repository: UserRepository,
    private val validateEmailUseCase: ValidateEmailUseCase
) {
    suspend operator fun invoke(email: String, password: String): ResultWrapper<User> {
        // ✅ Validation
        validateEmailUseCase(email).onError { return it }

        // ✅ Business logic
        return repository.createUser(email, password)
    }
}

// ViewModel is thin ✅
@HiltViewModel
class UserViewModel @Inject constructor(
    private val createUserUseCase: CreateUserUseCase
) : ViewModel() {

    fun createUser(email: String, password: String) {
        viewModelScope.launch {
            when (val result = createUserUseCase(email, password)) {
                is ResultWrapper.Success -> { /* update UI */ }
                is ResultWrapper.Error -> { /* show error */ }
            }
        }
    }
}
```

---

## Timeline

### Week 1-2: Domain Layer
- Create `domain/` package structure
- Extract all domain models
- Create repository interfaces
- Create first 5-10 use cases

### Week 3-4: Data Layer
- Create DTOs for all features
- Create mappers
- Rename repository implementations
- Update repository methods to return `ResultWrapper`

### Week 5-6: Hilt Migration
- Add Hilt dependencies
- Create Hilt modules
- Annotate ViewModels
- Remove `AppContainer` (gradually)

### Week 7-8: Presentation Layer
- Create UI state classes
- Refactor ViewModels to use use cases
- Extract business logic to use cases
- Update Composables to use `hiltViewModel()`

### Week 9-10: Testing
- Write use case tests
- Write repository tests
- Write ViewModel tests
- Achieve 60% coverage

---

## Validation Checklist

After migration, verify:

- [ ] `domain/` has zero Android imports
- [ ] All ViewModels use `@HiltViewModel`
- [ ] All business logic is in use cases
- [ ] All repositories implement domain interfaces
- [ ] All DTOs are in `data/remote/dto/`
- [ ] All mappers exist and are tested
- [ ] `AppContainer` is deleted
- [ ] All screens use `hiltViewModel()`
- [ ] Test coverage > 60%
- [ ] No cyclic dependencies

---

## Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Test coverage | 0% | 60%+ |
| ViewModel avg lines | 250 | 150 |
| Testable code | 30% | 90% |
| Dependency injection | Manual | Hilt |
| Business logic location | ViewModel | Use Cases |
| Repository testability | Hard | Easy |

---

**Follow this guide step-by-step to migrate to enterprise-grade architecture!** 🚀
