# Enterprise Android Architecture Guide
## Production-Ready MVVM + Clean Architecture

**Target:** Scalable apps with 50+ features
**Stack:** Kotlin, Jetpack Compose, Hilt, Coroutines, Flow
**Principles:** SOLID, Clean Architecture, MVVM

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Folder Structure](#2-folder-structure)
3. [Core Layer](#3-core-layer)
4. [Data Layer](#4-data-layer)
5. [Domain Layer](#5-domain-layer)
6. [Presentation Layer](#6-presentation-layer)
7. [Dependency Injection](#7-dependency-injection)
8. [Navigation](#8-navigation)
9. [Error Handling](#9-error-handling)
10. [Logging System](#10-logging-system)
11. [Base Classes](#11-base-classes)
12. [Full Feature Example](#12-full-feature-example)
13. [Code Quality Standards](#13-code-quality-standards)
14. [Testing Strategy](#14-testing-strategy)

---

## 1. Architecture Overview

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  - UI (Compose)                                             │
│  - ViewModels (UI logic)                                    │
│  - Navigation                                               │
│  - Dependency: Domain Layer only                            │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                     DOMAIN LAYER                             │
│  - Use Cases (Business logic)                               │
│  - Domain Models (Pure Kotlin entities)                     │
│  - Repository Interfaces                                    │
│  - Dependency: None (pure Kotlin)                           │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                      DATA LAYER                              │
│  - Repository Implementations                               │
│  - Data Sources (API, Database, Cache)                      │
│  - DTOs (Data Transfer Objects)                             │
│  - Mappers (DTO ↔ Domain)                                   │
│  - Dependency: Domain Layer                                 │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Dependency Rule:** Dependencies point inward (outer layers depend on inner layers)
2. **Domain Layer is Pure:** No Android framework dependencies
3. **Single Responsibility:** Each class has one reason to change
4. **Dependency Inversion:** Depend on abstractions, not concretions
5. **Interface Segregation:** Clients shouldn't depend on interfaces they don't use

---

## 2. Folder Structure

### Complete Package Structure

```
com.company.app/
│
├── core/                                    # Shared utilities and base components
│   ├── constants/
│   │   ├── AppConstants.kt                 # App-wide constants
│   │   ├── NetworkConstants.kt             # API endpoints, timeouts
│   │   └── DatabaseConstants.kt            # Database config
│   │
│   ├── utils/
│   │   ├── DateUtils.kt                    # Date formatting, parsing
│   │   ├── StringUtils.kt                  # String operations
│   │   ├── ValidationUtils.kt              # Input validation
│   │   └── CryptoUtils.kt                  # Encryption helpers
│   │
│   ├── extensions/
│   │   ├── ContextExt.kt                   # Context extensions
│   │   ├── ViewExt.kt                      # View extensions
│   │   ├── FlowExt.kt                      # Flow extensions
│   │   └── StringExt.kt                    # String extensions
│   │
│   ├── network/
│   │   ├── NetworkMonitor.kt               # Network connectivity observer
│   │   ├── interceptor/
│   │   │   ├── AuthInterceptor.kt          # JWT token injection
│   │   │   ├── LoggingInterceptor.kt       # Request/response logging
│   │   │   └── ErrorInterceptor.kt         # Error parsing
│   │   └── NetworkConfig.kt                # Retrofit/OkHttp setup
│   │
│   ├── result/
│   │   ├── ResultWrapper.kt                # Sealed class for success/error
│   │   ├── ApiResponse.kt                  # Generic API response wrapper
│   │   └── NetworkResult.kt                # Network-specific result
│   │
│   ├── logger/
│   │   ├── Logger.kt                       # Centralized logging interface
│   │   ├── LoggerImpl.kt                   # Implementation (Timber, Firebase)
│   │   └── CrashReporter.kt                # Crashlytics integration
│   │
│   ├── security/
│   │   ├── EncryptionManager.kt            # Data encryption
│   │   └── BiometricManager.kt             # Biometric auth
│   │
│   └── base/
│       ├── BaseViewModel.kt                # ViewModel base class
│       ├── BaseRepository.kt               # Repository base class
│       └── BaseUseCase.kt                  # UseCase base class
│
├── data/                                    # Data layer (implements domain interfaces)
│   │
│   ├── remote/                             # Remote data sources
│   │   ├── api/
│   │   │   ├── UserApi.kt                  # User-related endpoints
│   │   │   ├── AuthApi.kt                  # Auth endpoints
│   │   │   └── ProductApi.kt               # Product endpoints
│   │   │
│   │   └── dto/                            # Data Transfer Objects (API models)
│   │       ├── user/
│   │       │   ├── UserDto.kt              # API user model
│   │       │   ├── UserResponseDto.kt      # API response wrapper
│   │       │   └── UpdateUserRequestDto.kt # Update user payload
│   │       │
│   │       └── common/
│   │           ├── ErrorDto.kt             # API error response
│   │           └── PaginationDto.kt        # Pagination metadata
│   │
│   ├── local/                              # Local data sources
│   │   ├── database/
│   │   │   ├── AppDatabase.kt              # Room database
│   │   │   └── DatabaseConfig.kt           # Database migrations
│   │   │
│   │   ├── dao/
│   │   │   ├── UserDao.kt                  # User CRUD operations
│   │   │   └── ProductDao.kt               # Product CRUD operations
│   │   │
│   │   ├── entity/
│   │   │   ├── UserEntity.kt               # Room entity for User
│   │   │   └── ProductEntity.kt            # Room entity for Product
│   │   │
│   │   └── preferences/
│   │       ├── PreferencesManager.kt       # SharedPreferences wrapper
│   │       └── EncryptedPreferences.kt     # Encrypted storage
│   │
│   ├── repository/                         # Repository implementations
│   │   ├── UserRepositoryImpl.kt           # Implements domain.UserRepository
│   │   ├── AuthRepositoryImpl.kt           # Auth repository
│   │   └── ProductRepositoryImpl.kt        # Product repository
│   │
│   └── mapper/                             # DTO ↔ Domain mappers
│       ├── UserMapper.kt                   # User DTO to Domain mapping
│       ├── ProductMapper.kt                # Product DTO to Domain mapping
│       └── BaseMapper.kt                   # Generic mapper interface
│
├── domain/                                  # Business logic layer (pure Kotlin)
│   │
│   ├── model/                              # Domain models (business entities)
│   │   ├── User.kt                         # User domain model
│   │   ├── Product.kt                      # Product domain model
│   │   └── Order.kt                        # Order domain model
│   │
│   ├── repository/                         # Repository interfaces
│   │   ├── UserRepository.kt               # User repository contract
│   │   ├── AuthRepository.kt               # Auth repository contract
│   │   └── ProductRepository.kt            # Product repository contract
│   │
│   └── usecase/                            # Use cases (business logic)
│       ├── user/
│       │   ├── GetUserUseCase.kt           # Get user by ID
│       │   ├── GetUsersUseCase.kt          # Get all users
│       │   ├── UpdateUserUseCase.kt        # Update user
│       │   └── DeleteUserUseCase.kt        # Delete user
│       │
│       ├── auth/
│       │   ├── LoginUseCase.kt             # Login logic
│       │   ├── LogoutUseCase.kt            # Logout logic
│       │   └── RefreshTokenUseCase.kt      # Token refresh
│       │
│       └── validation/
│           ├── ValidateEmailUseCase.kt     # Email validation
│           └── ValidatePasswordUseCase.kt  # Password validation
│
├── presentation/                            # UI layer
│   │
│   ├── navigation/
│   │   ├── AppNavigation.kt                # Navigation graph
│   │   ├── NavigationRoute.kt              # Type-safe routes
│   │   └── NavigationExt.kt                # Navigation extensions
│   │
│   ├── base/
│   │   ├── BaseViewModel.kt                # ViewModel base (if needed)
│   │   └── UiState.kt                      # Generic UI state wrapper
│   │
│   ├── theme/
│   │   ├── Color.kt                        # App colors
│   │   ├── Typography.kt                   # Text styles
│   │   ├── Shape.kt                        # Component shapes
│   │   └── Theme.kt                        # App theme
│   │
│   ├── components/                         # Reusable UI components
│   │   ├── button/
│   │   │   ├── PrimaryButton.kt
│   │   │   └── SecondaryButton.kt
│   │   │
│   │   ├── textfield/
│   │   │   ├── AppTextField.kt
│   │   │   └── PasswordTextField.kt
│   │   │
│   │   ├── loading/
│   │   │   ├── LoadingIndicator.kt
│   │   │   └── FullScreenLoader.kt
│   │   │
│   │   └── error/
│   │       ├── ErrorView.kt
│   │       └── RetryButton.kt
│   │
│   └── feature/                            # Feature modules (screens)
│       │
│       ├── user/
│       │   ├── UserViewModel.kt            # ViewModel for user screens
│       │   ├── UserUiState.kt              # UI state for user screens
│       │   ├── UserScreen.kt               # User list screen
│       │   ├── UserDetailScreen.kt         # User detail screen
│       │   └── components/                 # User-specific components
│       │       └── UserCard.kt
│       │
│       ├── auth/
│       │   ├── login/
│       │   │   ├── LoginViewModel.kt
│       │   │   ├── LoginUiState.kt
│       │   │   └── LoginScreen.kt
│       │   │
│       │   └── register/
│       │       ├── RegisterViewModel.kt
│       │       ├── RegisterUiState.kt
│       │       └── RegisterScreen.kt
│       │
│       └── home/
│           ├── HomeViewModel.kt
│           ├── HomeUiState.kt
│           └── HomeScreen.kt
│
├── di/                                      # Dependency Injection
│   ├── AppModule.kt                        # App-level dependencies
│   ├── NetworkModule.kt                    # Retrofit, OkHttp
│   ├── DatabaseModule.kt                   # Room, DAOs
│   ├── RepositoryModule.kt                 # Repository bindings
│   ├── UseCaseModule.kt                    # UseCase dependencies
│   └── ViewModelModule.kt                  # ViewModel dependencies (optional)
│
└── MyApplication.kt                         # Application class
```

### Folder Responsibilities

| Folder | Responsibility | Depends On |
|--------|---------------|------------|
| `core/` | Shared utilities, base classes, no feature-specific code | Nothing |
| `data/` | Data persistence, API calls, caching | Domain interfaces |
| `domain/` | Business logic, use cases, domain models | Nothing (pure Kotlin) |
| `presentation/` | UI, ViewModels, navigation, screens | Domain layer |
| `di/` | Dependency injection setup | All layers |

---

## 3. Core Layer

### 3.1 Result Wrapper

**File:** `core/result/ResultWrapper.kt`

```kotlin
package com.company.app.core.result

/**
 * Generic wrapper for operation results.
 * Encapsulates success and error states.
 */
sealed class ResultWrapper<out T> {
    /**
     * Success state with data.
     */
    data class Success<T>(val data: T) : ResultWrapper<T>()

    /**
     * Error state with exception.
     */
    data class Error(val exception: AppException) : ResultWrapper<Nothing>()

    /**
     * Loading state (optional, for UI progress).
     */
    data object Loading : ResultWrapper<Nothing>()

    /**
     * Returns true if this is a Success state.
     */
    val isSuccess: Boolean
        get() = this is Success

    /**
     * Returns true if this is an Error state.
     */
    val isError: Boolean
        get() = this is Error

    /**
     * Returns data if Success, null otherwise.
     */
    fun getOrNull(): T? = when (this) {
        is Success -> data
        else -> null
    }

    /**
     * Returns data if Success, throws exception if Error.
     */
    fun getOrThrow(): T = when (this) {
        is Success -> data
        is Error -> throw exception
        is Loading -> throw IllegalStateException("Cannot get data from Loading state")
    }

    /**
     * Maps Success data to another type.
     */
    inline fun <R> map(transform: (T) -> R): ResultWrapper<R> = when (this) {
        is Success -> Success(transform(data))
        is Error -> this
        is Loading -> this
    }

    /**
     * Executes block on Success.
     */
    inline fun onSuccess(block: (T) -> Unit): ResultWrapper<T> {
        if (this is Success) block(data)
        return this
    }

    /**
     * Executes block on Error.
     */
    inline fun onError(block: (AppException) -> Unit): ResultWrapper<T> {
        if (this is Error) block(exception)
        return this
    }
}
```

---

### 3.2 Exception Hierarchy

**File:** `core/result/AppException.kt`

```kotlin
package com.company.app.core.result

/**
 * Base sealed class for all app exceptions.
 * Provides centralized error handling.
 */
sealed class AppException(
    message: String? = null,
    cause: Throwable? = null
) : Exception(message, cause) {

    /**
     * Network-related errors (no internet, timeout, etc.)
     */
    sealed class NetworkException(message: String?, cause: Throwable? = null) :
        AppException(message, cause) {

        class NoInternet : NetworkException("No internet connection")
        class Timeout : NetworkException("Request timed out")
        class ServerUnreachable : NetworkException("Cannot reach server")
        class Unknown(cause: Throwable?) : NetworkException("Network error occurred", cause)
    }

    /**
     * API-related errors (4xx, 5xx responses)
     */
    sealed class ApiException(
        val code: Int,
        message: String?,
        cause: Throwable? = null
    ) : AppException(message, cause) {

        class BadRequest(message: String?) : ApiException(400, message)
        class Unauthorized : ApiException(401, "Unauthorized - please login again")
        class Forbidden : ApiException(403, "You don't have permission")
        class NotFound(message: String?) : ApiException(404, message)
        class Conflict(message: String?) : ApiException(409, message)
        class ServerError(message: String?) : ApiException(500, message)
        class ServiceUnavailable : ApiException(503, "Service temporarily unavailable")
        class Unknown(code: Int, message: String?) : ApiException(code, message)
    }

    /**
     * Database-related errors
     */
    sealed class DatabaseException(message: String?, cause: Throwable? = null) :
        AppException(message, cause) {

        class NotFound(entity: String) : DatabaseException("$entity not found in database")
        class InsertFailed(entity: String) : DatabaseException("Failed to insert $entity")
        class UpdateFailed(entity: String) : DatabaseException("Failed to update $entity")
        class DeleteFailed(entity: String) : DatabaseException("Failed to delete $entity")
        class Unknown(cause: Throwable?) : DatabaseException("Database error", cause)
    }

    /**
     * Validation errors (form inputs, business rules)
     */
    sealed class ValidationException(message: String) : AppException(message) {
        class InvalidEmail : ValidationException("Invalid email address")
        class InvalidPassword : ValidationException("Password must be at least 8 characters")
        class InvalidPhone : ValidationException("Invalid phone number")
        class Required(field: String) : ValidationException("$field is required")
        class Custom(message: String) : ValidationException(message)
    }

    /**
     * Unknown/unexpected errors
     */
    class UnknownException(message: String? = "An unexpected error occurred", cause: Throwable? = null) :
        AppException(message, cause)

    /**
     * User-friendly error message.
     */
    fun getUserMessage(): String = when (this) {
        is NetworkException.NoInternet -> "Please check your internet connection"
        is NetworkException.Timeout -> "Request took too long. Please try again"
        is NetworkException.ServerUnreachable -> "Cannot connect to server"
        is ApiException.Unauthorized -> "Your session has expired. Please login again"
        is ApiException.Forbidden -> "You don't have permission to perform this action"
        is ApiException.NotFound -> message ?: "Resource not found"
        is ApiException.ServerError -> "Server error. Please try again later"
        is ApiException.ServiceUnavailable -> "Service is temporarily unavailable"
        is ValidationException -> message ?: "Validation error"
        else -> message ?: "Something went wrong. Please try again"
    }
}
```

---

### 3.3 Logger

**File:** `core/logger/Logger.kt`

```kotlin
package com.company.app.core.logger

/**
 * Centralized logging interface.
 * Abstracts logging implementation (Timber, Firebase, etc.)
 */
interface Logger {
    fun d(tag: String, message: String)
    fun i(tag: String, message: String)
    fun w(tag: String, message: String, throwable: Throwable? = null)
    fun e(tag: String, message: String, throwable: Throwable? = null)
    fun wtf(tag: String, message: String, throwable: Throwable? = null)

    companion object {
        lateinit var instance: Logger
            private set

        fun initialize(logger: Logger) {
            instance = logger
        }

        fun d(tag: String, message: String) = instance.d(tag, message)
        fun i(tag: String, message: String) = instance.i(tag, message)
        fun w(tag: String, message: String, throwable: Throwable? = null) =
            instance.w(tag, message, throwable)
        fun e(tag: String, message: String, throwable: Throwable? = null) =
            instance.e(tag, message, throwable)
        fun wtf(tag: String, message: String, throwable: Throwable? = null) =
            instance.wtf(tag, message, throwable)
    }
}

/**
 * Implementation using Timber and Firebase Crashlytics.
 */
class LoggerImpl(
    private val crashReporter: CrashReporter
) : Logger {

    override fun d(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            timber.log.Timber.tag(tag).d(message)
        }
    }

    override fun i(tag: String, message: String) {
        timber.log.Timber.tag(tag).i(message)
    }

    override fun w(tag: String, message: String, throwable: Throwable?) {
        timber.log.Timber.tag(tag).w(throwable, message)
        crashReporter.log("WARNING: $tag - $message")
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        timber.log.Timber.tag(tag).e(throwable, message)
        throwable?.let { crashReporter.recordException(it) }
    }

    override fun wtf(tag: String, message: String, throwable: Throwable?) {
        timber.log.Timber.tag(tag).wtf(throwable, message)
        throwable?.let { crashReporter.recordException(it) }
    }
}

/**
 * Crash reporting interface (Firebase Crashlytics).
 */
interface CrashReporter {
    fun log(message: String)
    fun recordException(throwable: Throwable)
    fun setUserId(userId: String)
    fun setCustomKey(key: String, value: String)
}
```

---

### 3.4 Network Configuration

**File:** `core/network/NetworkConfig.kt`

```kotlin
package com.company.app.core.network

import com.company.app.core.logger.Logger
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object NetworkConfig {

    private const val TIMEOUT_SECONDS = 30L

    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        errorInterceptor: ErrorInterceptor
    ): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
            .addInterceptor(errorInterceptor)
            .addInterceptor(createLoggingInterceptor())
            .build()
    }

    fun provideRetrofit(
        baseUrl: String,
        okHttpClient: OkHttpClient
    ): Retrofit {
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    private fun createLoggingInterceptor(): HttpLoggingInterceptor {
        return HttpLoggingInterceptor { message ->
            Logger.d("OkHttp", message)
        }.apply {
            level = if (BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }
    }
}

/**
 * Injects auth token into requests.
 */
class AuthInterceptor(
    private val tokenProvider: () -> String?
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): okhttp3.Response {
        val originalRequest = chain.request()
        val token = tokenProvider()

        val request = if (token != null) {
            originalRequest.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        } else {
            originalRequest
        }

        return chain.proceed(request)
    }
}

/**
 * Intercepts and parses API errors.
 */
class ErrorInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): okhttp3.Response {
        val response = chain.proceed(chain.request())

        // If response is not successful, parse error
        if (!response.isSuccessful) {
            val errorBody = response.body?.string()
            Logger.e("API_ERROR", "Code: ${response.code}, Body: $errorBody")
            // You can parse errorBody to extract error details
        }

        return response
    }
}
```

---

## 4. Data Layer

### 4.1 Data Transfer Objects (DTOs)

**File:** `data/remote/dto/user/UserDto.kt`

```kotlin
package com.company.app.data.remote.dto.user

import com.google.gson.annotations.SerializedName

/**
 * API response model for User.
 * Maps directly to JSON from backend.
 */
data class UserDto(
    @SerializedName("id")
    val id: String,

    @SerializedName("email")
    val email: String,

    @SerializedName("name")
    val name: String,

    @SerializedName("avatar_url")
    val avatarUrl: String?,

    @SerializedName("created_at")
    val createdAt: String,

    @SerializedName("updated_at")
    val updatedAt: String
)

/**
 * Generic API response wrapper.
 */
data class ApiResponse<T>(
    @SerializedName("success")
    val success: Boolean,

    @SerializedName("data")
    val data: T?,

    @SerializedName("error")
    val error: ErrorDto?
)

/**
 * API error response.
 */
data class ErrorDto(
    @SerializedName("code")
    val code: String,

    @SerializedName("message")
    val message: String
)
```

---

### 4.2 API Interface

**File:** `data/remote/api/UserApi.kt`

```kotlin
package com.company.app.data.remote.api

import com.company.app.data.remote.dto.user.UserDto
import com.company.app.data.remote.dto.user.ApiResponse
import retrofit2.Response
import retrofit2.http.*

/**
 * User API endpoints.
 */
interface UserApi {

    @GET("users/{id}")
    suspend fun getUserById(
        @Path("id") userId: String
    ): Response<ApiResponse<UserDto>>

    @GET("users")
    suspend fun getUsers(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20
    ): Response<ApiResponse<List<UserDto>>>

    @POST("users")
    suspend fun createUser(
        @Body request: CreateUserRequestDto
    ): Response<ApiResponse<UserDto>>

    @PUT("users/{id}")
    suspend fun updateUser(
        @Path("id") userId: String,
        @Body request: UpdateUserRequestDto
    ): Response<ApiResponse<UserDto>>

    @DELETE("users/{id}")
    suspend fun deleteUser(
        @Path("id") userId: String
    ): Response<ApiResponse<Unit>>
}

data class CreateUserRequestDto(
    val email: String,
    val name: String,
    val password: String
)

data class UpdateUserRequestDto(
    val name: String?,
    val avatarUrl: String?
)
```

---

### 4.3 Mapper

**File:** `data/mapper/UserMapper.kt`

```kotlin
package com.company.app.data.mapper

import com.company.app.data.remote.dto.user.UserDto
import com.company.app.domain.model.User
import java.time.Instant

/**
 * Maps UserDto (API) to User (Domain).
 */
object UserMapper {

    fun toDomain(dto: UserDto): User {
        return User(
            id = dto.id,
            email = dto.email,
            name = dto.name,
            avatarUrl = dto.avatarUrl,
            createdAt = Instant.parse(dto.createdAt),
            updatedAt = Instant.parse(dto.updatedAt)
        )
    }

    fun toDomainList(dtos: List<UserDto>): List<User> {
        return dtos.map { toDomain(it) }
    }
}
```

---

### 4.4 Repository Implementation

**File:** `data/repository/UserRepositoryImpl.kt`

```kotlin
package com.company.app.data.repository

import com.company.app.core.logger.Logger
import com.company.app.core.result.AppException
import com.company.app.core.result.ResultWrapper
import com.company.app.data.mapper.UserMapper
import com.company.app.data.remote.api.UserApi
import com.company.app.domain.model.User
import com.company.app.domain.repository.UserRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import retrofit2.Response
import java.io.IOException
import javax.inject.Inject

/**
 * Implementation of UserRepository.
 * Handles data fetching from API and error mapping.
 */
class UserRepositoryImpl @Inject constructor(
    private val userApi: UserApi
) : UserRepository {

    override suspend fun getUserById(userId: String): ResultWrapper<User> =
        withContext(Dispatchers.IO) {
            try {
                val response = userApi.getUserById(userId)
                handleApiResponse(response) { dto ->
                    UserMapper.toDomain(dto)
                }
            } catch (e: Exception) {
                Logger.e(TAG, "Error fetching user", e)
                ResultWrapper.Error(handleException(e))
            }
        }

    override suspend fun getUsers(): ResultWrapper<List<User>> =
        withContext(Dispatchers.IO) {
            try {
                val response = userApi.getUsers()
                handleApiResponse(response) { dtos ->
                    UserMapper.toDomainList(dtos)
                }
            } catch (e: Exception) {
                Logger.e(TAG, "Error fetching users", e)
                ResultWrapper.Error(handleException(e))
            }
        }

    override suspend fun updateUser(
        userId: String,
        name: String?,
        avatarUrl: String?
    ): ResultWrapper<User> = withContext(Dispatchers.IO) {
        try {
            val request = UpdateUserRequestDto(name, avatarUrl)
            val response = userApi.updateUser(userId, request)
            handleApiResponse(response) { dto ->
                UserMapper.toDomain(dto)
            }
        } catch (e: Exception) {
            Logger.e(TAG, "Error updating user", e)
            ResultWrapper.Error(handleException(e))
        }
    }

    override suspend fun deleteUser(userId: String): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val response = userApi.deleteUser(userId)
                handleApiResponse(response) { }
            } catch (e: Exception) {
                Logger.e(TAG, "Error deleting user", e)
                ResultWrapper.Error(handleException(e))
            }
        }

    /**
     * Generic API response handler.
     */
    private fun <T, R> handleApiResponse(
        response: Response<ApiResponse<T>>,
        transform: (T) -> R
    ): ResultWrapper<R> {
        return when {
            response.isSuccessful -> {
                val body = response.body()
                if (body?.success == true && body.data != null) {
                    ResultWrapper.Success(transform(body.data))
                } else {
                    val error = body?.error
                    ResultWrapper.Error(
                        AppException.ApiException.Unknown(
                            response.code(),
                            error?.message ?: "Unknown error"
                        )
                    )
                }
            }
            else -> {
                ResultWrapper.Error(mapHttpError(response.code(), response.message()))
            }
        }
    }

    /**
     * Maps HTTP status codes to AppException.
     */
    private fun mapHttpError(code: Int, message: String?): AppException {
        return when (code) {
            400 -> AppException.ApiException.BadRequest(message)
            401 -> AppException.ApiException.Unauthorized()
            403 -> AppException.ApiException.Forbidden()
            404 -> AppException.ApiException.NotFound(message)
            409 -> AppException.ApiException.Conflict(message)
            500 -> AppException.ApiException.ServerError(message)
            503 -> AppException.ApiException.ServiceUnavailable()
            else -> AppException.ApiException.Unknown(code, message)
        }
    }

    /**
     * Maps exceptions to AppException.
     */
    private fun handleException(e: Exception): AppException {
        return when (e) {
            is IOException -> AppException.NetworkException.Unknown(e)
            is AppException -> e
            else -> AppException.UnknownException(cause = e)
        }
    }

    companion object {
        private const val TAG = "UserRepository"
    }
}
```

---

## 5. Domain Layer

### 5.1 Domain Model

**File:** `domain/model/User.kt`

```kotlin
package com.company.app.domain.model

import java.time.Instant

/**
 * Domain model for User.
 * Pure Kotlin class with no Android dependencies.
 */
data class User(
    val id: String,
    val email: String,
    val name: String,
    val avatarUrl: String?,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    /**
     * Business logic: Get user's display name.
     */
    fun getDisplayName(): String {
        return name.ifEmpty { email.substringBefore("@") }
    }

    /**
     * Business logic: Check if user has avatar.
     */
    fun hasAvatar(): Boolean = !avatarUrl.isNullOrEmpty()
}
```

---

### 5.2 Repository Interface

**File:** `domain/repository/UserRepository.kt`

```kotlin
package com.company.app.domain.repository

import com.company.app.core.result.ResultWrapper
import com.company.app.domain.model.User

/**
 * Repository contract for User data.
 * Implemented in data layer.
 */
interface UserRepository {
    suspend fun getUserById(userId: String): ResultWrapper<User>
    suspend fun getUsers(): ResultWrapper<List<User>>
    suspend fun updateUser(userId: String, name: String?, avatarUrl: String?): ResultWrapper<User>
    suspend fun deleteUser(userId: String): ResultWrapper<Unit>
}
```

---

### 5.3 Use Case

**File:** `domain/usecase/user/GetUserUseCase.kt`

```kotlin
package com.company.app.domain.usecase.user

import com.company.app.core.result.ResultWrapper
import com.company.app.domain.model.User
import com.company.app.domain.repository.UserRepository
import javax.inject.Inject

/**
 * Use case: Get user by ID.
 * Encapsulates business logic for fetching a single user.
 */
class GetUserUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    suspend operator fun invoke(userId: String): ResultWrapper<User> {
        // Add business logic here (validation, caching, etc.)
        if (userId.isBlank()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("User ID cannot be empty")
            )
        }

        return userRepository.getUserById(userId)
    }
}
```

**File:** `domain/usecase/user/GetUsersUseCase.kt`

```kotlin
package com.company.app.domain.usecase.user

import com.company.app.core.result.ResultWrapper
import com.company.app.domain.model.User
import com.company.app.domain.repository.UserRepository
import javax.inject.Inject

/**
 * Use case: Get all users.
 */
class GetUsersUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    suspend operator fun invoke(): ResultWrapper<List<User>> {
        return userRepository.getUsers()
    }
}
```

---

## 6. Presentation Layer

### 6.1 UI State

**File:** `presentation/feature/user/UserUiState.kt`

```kotlin
package com.company.app.presentation.feature.user

import com.company.app.domain.model.User

/**
 * UI state for User screens.
 * Represents all possible UI states.
 */
data class UserUiState(
    val isLoading: Boolean = false,
    val users: List<User> = emptyList(),
    val selectedUser: User? = null,
    val error: String? = null,
    val isRefreshing: Boolean = false
) {
    val hasUsers: Boolean
        get() = users.isNotEmpty()

    val showEmptyState: Boolean
        get() = !isLoading && !hasUsers && error == null
}
```

---

### 6.2 ViewModel

**File:** `presentation/feature/user/UserViewModel.kt`

```kotlin
package com.company.app.presentation.feature.user

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.company.app.core.logger.Logger
import com.company.app.core.result.ResultWrapper
import com.company.app.domain.usecase.user.GetUserUseCase
import com.company.app.domain.usecase.user.GetUsersUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for User feature.
 * Manages UI state and coordinates use cases.
 */
@HiltViewModel
class UserViewModel @Inject constructor(
    private val getUsersUseCase: GetUsersUseCase,
    private val getUserUseCase: GetUserUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(UserUiState())
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()

    init {
        loadUsers()
    }

    /**
     * Load all users.
     */
    fun loadUsers() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            when (val result = getUsersUseCase()) {
                is ResultWrapper.Success -> {
                    Logger.d(TAG, "Users loaded: ${result.data.size}")
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            users = result.data,
                            error = null
                        )
                    }
                }
                is ResultWrapper.Error -> {
                    val errorMessage = result.exception.getUserMessage()
                    Logger.e(TAG, "Failed to load users: $errorMessage")
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = errorMessage
                        )
                    }
                }
                is ResultWrapper.Loading -> {
                    // Already handled above
                }
            }
        }
    }

    /**
     * Refresh users (pull-to-refresh).
     */
    fun refreshUsers() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true) }

            when (val result = getUsersUseCase()) {
                is ResultWrapper.Success -> {
                    _uiState.update {
                        it.copy(
                            isRefreshing = false,
                            users = result.data,
                            error = null
                        )
                    }
                }
                is ResultWrapper.Error -> {
                    _uiState.update {
                        it.copy(
                            isRefreshing = false,
                            error = result.exception.getUserMessage()
                        )
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    /**
     * Select a user.
     */
    fun selectUser(userId: String) {
        viewModelScope.launch {
            when (val result = getUserUseCase(userId)) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(selectedUser = result.data) }
                }
                is ResultWrapper.Error -> {
                    Logger.e(TAG, "Failed to load user: ${result.exception.getUserMessage()}")
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    /**
     * Clear error state.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    companion object {
        private const val TAG = "UserViewModel"
    }
}
```

---

### 6.3 Screen (Compose)

**File:** `presentation/feature/user/UserScreen.kt`

```kotlin
package com.company.app.presentation.feature.user

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.company.app.presentation.components.error.ErrorView
import com.company.app.presentation.components.loading.LoadingIndicator
import com.company.app.presentation.feature.user.components.UserCard

/**
 * User list screen.
 */
@OptIn(ExperimentalMaterialApi::class)
@Composable
fun UserScreen(
    viewModel: UserViewModel = hiltViewModel(),
    onUserClick: (String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    val pullRefreshState = rememberPullRefreshState(
        refreshing = uiState.isRefreshing,
        onRefresh = { viewModel.refreshUsers() }
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Users") }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .pullRefresh(pullRefreshState)
        ) {
            when {
                uiState.isLoading -> {
                    LoadingIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                uiState.error != null -> {
                    ErrorView(
                        message = uiState.error!!,
                        onRetry = { viewModel.loadUsers() },
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                uiState.showEmptyState -> {
                    EmptyStateView(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                else -> {
                    UserList(
                        users = uiState.users,
                        onUserClick = onUserClick
                    )
                }
            }

            PullRefreshIndicator(
                refreshing = uiState.isRefreshing,
                state = pullRefreshState,
                modifier = Modifier.align(Alignment.TopCenter)
            )
        }
    }
}

@Composable
private fun UserList(
    users: List<User>,
    onUserClick: (String) -> Unit
) {
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(users, key = { it.id }) { user ->
            UserCard(
                user = user,
                onClick = { onUserClick(user.id) }
            )
        }
    }
}

@Composable
private fun EmptyStateView(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "No users found",
            style = MaterialTheme.typography.titleLarge
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Check back later",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
```

---

## 7. Dependency Injection

### 7.1 Network Module

**File:** `di/NetworkModule.kt`

```kotlin
package com.company.app.di

import com.company.app.BuildConfig
import com.company.app.core.network.AuthInterceptor
import com.company.app.core.network.ErrorInterceptor
import com.company.app.core.network.NetworkConfig
import com.company.app.data.local.preferences.PreferencesManager
import com.company.app.data.remote.api.UserApi
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideAuthInterceptor(
        preferencesManager: PreferencesManager
    ): AuthInterceptor {
        return AuthInterceptor(
            tokenProvider = { preferencesManager.getAuthToken() }
        )
    }

    @Provides
    @Singleton
    fun provideErrorInterceptor(): ErrorInterceptor {
        return ErrorInterceptor()
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        errorInterceptor: ErrorInterceptor
    ): OkHttpClient {
        return NetworkConfig.provideOkHttpClient(
            authInterceptor = authInterceptor,
            errorInterceptor = errorInterceptor
        )
    }

    @Provides
    @Singleton
    fun provideRetrofit(
        okHttpClient: OkHttpClient
    ): Retrofit {
        return NetworkConfig.provideRetrofit(
            baseUrl = BuildConfig.API_BASE_URL,
            okHttpClient = okHttpClient
        )
    }

    @Provides
    @Singleton
    fun provideUserApi(retrofit: Retrofit): UserApi {
        return retrofit.create(UserApi::class.java)
    }
}
```

---

### 7.2 Repository Module

**File:** `di/RepositoryModule.kt`

```kotlin
package com.company.app.di

import com.company.app.data.repository.UserRepositoryImpl
import com.company.app.domain.repository.UserRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindUserRepository(
        impl: UserRepositoryImpl
    ): UserRepository
}
```

---

## 8. Navigation

### 8.1 Navigation Routes

**File:** `presentation/navigation/NavigationRoute.kt`

```kotlin
package com.company.app.presentation.navigation

/**
 * Type-safe navigation routes.
 */
sealed class NavigationRoute(val route: String) {

    // Auth
    data object Login : NavigationRoute("login")
    data object Register : NavigationRoute("register")

    // Main
    data object Home : NavigationRoute("home")

    // User
    data object UserList : NavigationRoute("users")
    data object UserDetail : NavigationRoute("users/{userId}") {
        fun createRoute(userId: String) = "users/$userId"
    }

    // Settings
    data object Settings : NavigationRoute("settings")
    data object Profile : NavigationRoute("profile")
}
```

---

### 8.2 Navigation Graph

**File:** `presentation/navigation/AppNavigation.kt`

```kotlin
package com.company.app.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.company.app.presentation.feature.auth.login.LoginScreen
import com.company.app.presentation.feature.home.HomeScreen
import com.company.app.presentation.feature.user.UserScreen
import com.company.app.presentation.feature.user.UserDetailScreen

/**
 * Main navigation graph.
 */
@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController(),
    startDestination: String = NavigationRoute.Login.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Auth flow
        composable(NavigationRoute.Login.route) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(NavigationRoute.Home.route) {
                        popUpTo(NavigationRoute.Login.route) { inclusive = true }
                    }
                }
            )
        }

        // Home
        composable(NavigationRoute.Home.route) {
            HomeScreen(
                onNavigateToUsers = {
                    navController.navigate(NavigationRoute.UserList.route)
                }
            )
        }

        // User list
        composable(NavigationRoute.UserList.route) {
            UserScreen(
                onUserClick = { userId ->
                    navController.navigate(
                        NavigationRoute.UserDetail.createRoute(userId)
                    )
                }
            )
        }

        // User detail
        composable(
            route = NavigationRoute.UserDetail.route,
            arguments = listOf(
                navArgument("userId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val userId = backStackEntry.arguments?.getString("userId") ?: return@composable
            UserDetailScreen(
                userId = userId,
                onBackClick = { navController.popBackStack() }
            )
        }
    }
}
```

---

## 9. Error Handling

### Complete error handling is already covered in Section 3.2 (AppException hierarchy).

### Example usage in UI:

**File:** `presentation/components/error/ErrorView.kt`

```kotlin
package com.company.app.presentation.components.error

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun ErrorView(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Oops!",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.error
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(onClick = onRetry) {
            Text("Retry")
        }
    }
}
```

---

## 10. Logging System

Already covered in Section 3.3 (Logger interface and implementation).

---

## 11. Base Classes

### 11.1 Base ViewModel

**File:** `core/base/BaseViewModel.kt`

```kotlin
package com.company.app.core.base

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.company.app.core.logger.Logger
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Base ViewModel with error handling.
 */
abstract class BaseViewModel : ViewModel() {

    protected val tag: String = this::class.java.simpleName

    private val exceptionHandler = CoroutineExceptionHandler { _, throwable ->
        Logger.e(tag, "Unhandled exception in ViewModel", throwable)
        handleError(throwable)
    }

    /**
     * Launch coroutine with error handling.
     */
    protected fun launchSafe(block: suspend CoroutineScope.() -> Unit) {
        viewModelScope.launch(exceptionHandler) {
            block()
        }
    }

    /**
     * Override to handle errors in subclasses.
     */
    protected open fun handleError(throwable: Throwable) {
        // Default implementation - can be overridden
        Logger.e(tag, "Error in ViewModel", throwable)
    }
}
```

---

### 11.2 Base Use Case

**File:** `core/base/BaseUseCase.kt`

```kotlin
package com.company.app.core.base

import com.company.app.core.result.ResultWrapper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Base class for use cases.
 * Provides common functionality for all use cases.
 */
abstract class BaseUseCase<in Params, out T> {

    /**
     * Execute the use case.
     */
    suspend operator fun invoke(params: Params): ResultWrapper<T> {
        return withContext(Dispatchers.IO) {
            execute(params)
        }
    }

    /**
     * Execute the use case (no parameters).
     */
    suspend operator fun invoke(): ResultWrapper<T> where Params : Unit {
        return withContext(Dispatchers.IO) {
            execute(Unit as Params)
        }
    }

    /**
     * Implement this method in subclasses.
     */
    protected abstract suspend fun execute(params: Params): ResultWrapper<T>
}
```

---

## 12. Full Feature Example

### Complete User Feature

This section brings everything together to show a complete feature implementation.

---

#### 12.1 Domain Layer

**Model:** `domain/model/User.kt` (already shown in Section 5.1)

**Repository Interface:** `domain/repository/UserRepository.kt` (already shown in Section 5.2)

**Use Case:** `domain/usecase/user/GetUsersUseCase.kt` (already shown in Section 5.3)

---

#### 12.2 Data Layer

**DTO:** `data/remote/dto/user/UserDto.kt` (already shown in Section 4.1)

**API:** `data/remote/api/UserApi.kt` (already shown in Section 4.2)

**Mapper:** `data/mapper/UserMapper.kt` (already shown in Section 4.3)

**Repository Implementation:** `data/repository/UserRepositoryImpl.kt` (already shown in Section 4.4)

---

#### 12.3 Presentation Layer

**UI State:** `presentation/feature/user/UserUiState.kt` (already shown in Section 6.1)

**ViewModel:** `presentation/feature/user/UserViewModel.kt` (already shown in Section 6.2)

**Screen:** `presentation/feature/user/UserScreen.kt` (already shown in Section 6.3)

**Component:** `presentation/feature/user/components/UserCard.kt`

```kotlin
package com.company.app.presentation.feature.user.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.company.app.domain.model.User

@Composable
fun UserCard(
    user: User,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            AsyncImage(
                model = user.avatarUrl,
                contentDescription = "User avatar",
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape),
                contentScale = ContentScale.Crop
            )

            Spacer(modifier = Modifier.width(16.dp))

            // User info
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = user.name,
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = user.email,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
```

---

#### 12.4 Data Flow Diagram

```
┌─────────────┐
│  UserScreen │ (Composable)
└──────┬──────┘
       │ collectAsState()
       │
┌──────▼──────────┐
│  UserViewModel  │ (State management)
└──────┬──────────┘
       │ invoke()
       │
┌──────▼────────────┐
│  GetUsersUseCase  │ (Business logic)
└──────┬────────────┘
       │ getUsers()
       │
┌──────▼─────────────────┐
│  UserRepository (Interface) │
└──────┬─────────────────┘
       │
┌──────▼──────────────────┐
│ UserRepositoryImpl      │ (Data source coordination)
└──────┬──────────────────┘
       │ getUsers()
       │
┌──────▼────────┐
│    UserApi    │ (Network calls)
└──────┬────────┘
       │ HTTP GET
       │
┌──────▼────────┐
│  Backend API  │
└───────────────┘
```

---

## 13. Code Quality Standards

### 13.1 Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Classes | PascalCase | `UserViewModel` |
| Interfaces | PascalCase | `UserRepository` |
| Functions | camelCase | `getUserById()` |
| Variables | camelCase | `userName` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Private fields | _camelCase | `_uiState` |
| Composables | PascalCase | `UserScreen()` |
| Use Cases | `<Action><Entity>UseCase` | `GetUserUseCase` |
| ViewModels | `<Feature>ViewModel` | `UserViewModel` |
| Repositories | `<Entity>Repository` | `UserRepository` |
| DTOs | `<Entity>Dto` | `UserDto` |

---

### 13.2 File Size Limits

- **ViewModel:** Max 300 lines → split into multiple ViewModels
- **Screen:** Max 400 lines → extract components
- **Repository:** Max 400 lines → split by entity
- **Use Case:** Max 150 lines → single responsibility

---

### 13.3 Package Organization

```
feature/user/
├── UserViewModel.kt           # Max 1 ViewModel per feature
├── UserUiState.kt            # Separate UI state
├── UserScreen.kt             # Main screen
├── UserDetailScreen.kt       # Sub-screen
└── components/               # Feature-specific components
    ├── UserCard.kt
    └── UserListItem.kt
```

---

### 13.4 Dependency Rules

1. **Presentation** → depends on → **Domain** only
2. **Domain** → no dependencies (pure Kotlin)
3. **Data** → depends on → **Domain** (implements interfaces)

**Forbidden:**
- ❌ Domain depends on Data
- ❌ Domain depends on Presentation
- ❌ Data depends on Presentation

---

### 13.5 Code Metrics

Use **Detekt** or **ktlint** to enforce:

- Max function length: 30 lines
- Max file length: 400 lines
- Cyclomatic complexity: Max 15
- Cognitive complexity: Max 15
- Max parameters: 5

---

## 14. Testing Strategy

### 14.1 Test Structure

```
src/
├── test/                      # Unit tests
│   ├── domain/
│   │   └── usecase/
│   │       └── GetUserUseCaseTest.kt
│   ├── data/
│   │   └── repository/
│   │       └── UserRepositoryImplTest.kt
│   └── presentation/
│       └── viewmodel/
│           └── UserViewModelTest.kt
│
└── androidTest/               # Integration tests
    └── ui/
        └── UserScreenTest.kt
```

---

### 14.2 Example Unit Test (Use Case)

**File:** `test/domain/usecase/GetUserUseCaseTest.kt`

```kotlin
package com.company.app.domain.usecase.user

import com.company.app.core.result.ResultWrapper
import com.company.app.domain.model.User
import com.company.app.domain.repository.UserRepository
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.time.Instant

class GetUserUseCaseTest {

    private lateinit var userRepository: UserRepository
    private lateinit var getUserUseCase: GetUserUseCase

    @Before
    fun setup() {
        userRepository = mockk()
        getUserUseCase = GetUserUseCase(userRepository)
    }

    @Test
    fun `invoke returns success when repository returns user`() = runTest {
        // Given
        val userId = "123"
        val expectedUser = User(
            id = userId,
            email = "test@example.com",
            name = "Test User",
            avatarUrl = null,
            createdAt = Instant.now(),
            updatedAt = Instant.now()
        )
        coEvery { userRepository.getUserById(userId) } returns
            ResultWrapper.Success(expectedUser)

        // When
        val result = getUserUseCase(userId)

        // Then
        assertTrue(result is ResultWrapper.Success)
        assertEquals(expectedUser, (result as ResultWrapper.Success).data)
    }

    @Test
    fun `invoke returns error when userId is blank`() = runTest {
        // When
        val result = getUserUseCase("")

        // Then
        assertTrue(result is ResultWrapper.Error)
    }
}
```

---

### 14.3 Example ViewModel Test

**File:** `test/presentation/viewmodel/UserViewModelTest.kt`

```kotlin
package com.company.app.presentation.feature.user

import app.cash.turbine.test
import com.company.app.core.result.ResultWrapper
import com.company.app.domain.model.User
import com.company.app.domain.usecase.user.GetUsersUseCase
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class UserViewModelTest {

    private lateinit var getUsersUseCase: GetUsersUseCase
    private lateinit var viewModel: UserViewModel

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        getUsersUseCase = mockk()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `loadUsers updates state to success when use case succeeds`() = runTest {
        // Given
        val users = listOf(
            User("1", "user1@test.com", "User 1", null, Instant.now(), Instant.now()),
            User("2", "user2@test.com", "User 2", null, Instant.now(), Instant.now())
        )
        coEvery { getUsersUseCase() } returns ResultWrapper.Success(users)

        // When
        viewModel = UserViewModel(getUsersUseCase, mockk())

        // Then
        viewModel.uiState.test {
            val state = awaitItem()
            assertFalse(state.isLoading)
            assertEquals(2, state.users.size)
            assertNull(state.error)
        }
    }
}
```

---

## Summary & Best Practices

### Architecture Checklist

✅ **Separation of Concerns:** Presentation, Domain, Data layers are independent
✅ **SOLID Principles:** Each class has single responsibility
✅ **Testability:** 90%+ of code can be unit tested
✅ **Scalability:** Easy to add 50+ features without coupling
✅ **Error Handling:** Centralized exception hierarchy
✅ **Type Safety:** Sealed classes for states and results
✅ **Clean Code:** Max 400 lines per file, clear naming
✅ **Dependency Injection:** Hilt for compile-time DI
✅ **Modern Stack:** Jetpack Compose, Coroutines, Flow

---

### Key Takeaways

1. **Domain layer is pure Kotlin** — no Android dependencies
2. **Use cases encapsulate business logic** — not in ViewModels
3. **Repositories implement domain interfaces** — inversion of control
4. **ViewModels only manage UI state** — thin controllers
5. **Sealed classes for type-safe states** — compile-time safety
6. **ResultWrapper for all operations** — consistent error handling
7. **Hilt for dependency injection** — testable, scoped dependencies
8. **Navigation is centralized** — type-safe routes

---

### File Template Checklist

When adding a new feature, create:

1. ✅ Domain Model (`domain/model/Entity.kt`)
2. ✅ Repository Interface (`domain/repository/EntityRepository.kt`)
3. ✅ Use Cases (`domain/usecase/entity/GetEntityUseCase.kt`)
4. ✅ DTO (`data/remote/dto/entity/EntityDto.kt`)
5. ✅ API Interface (`data/remote/api/EntityApi.kt`)
6. ✅ Mapper (`data/mapper/EntityMapper.kt`)
7. ✅ Repository Implementation (`data/repository/EntityRepositoryImpl.kt`)
8. ✅ UI State (`presentation/feature/entity/EntityUiState.kt`)
9. ✅ ViewModel (`presentation/feature/entity/EntityViewModel.kt`)
10. ✅ Screen (`presentation/feature/entity/EntityScreen.kt`)
11. ✅ Navigation Route (`presentation/navigation/NavigationRoute.kt`)
12. ✅ DI Module Bindings (`di/RepositoryModule.kt`)

---

**This architecture is production-ready and scales to 50+ features.** 🚀
