# Android Clean Architecture - Quick Reference

**For:** Daily development, code reviews, onboarding
**Last Updated:** March 2026

---

## File Creation Checklist

When adding a new feature (e.g., "Product"):

### 1. Domain Layer (Pure Kotlin) ✅

```bash
domain/
├── model/Product.kt                        # Business entity
├── repository/ProductRepository.kt         # Contract (interface)
└── usecase/product/
    ├── GetProductsUseCase.kt              # Fetch products
    ├── GetProductByIdUseCase.kt           # Fetch single product
    ├── CreateProductUseCase.kt            # Create product
    └── DeleteProductUseCase.kt            # Delete product
```

**Template:**
```kotlin
// domain/model/Product.kt
data class Product(
    val id: String,
    val name: String,
    val price: Double
)

// domain/repository/ProductRepository.kt
interface ProductRepository {
    suspend fun getProducts(): ResultWrapper<List<Product>>
    suspend fun getProductById(id: String): ResultWrapper<Product>
}

// domain/usecase/product/GetProductsUseCase.kt
class GetProductsUseCase @Inject constructor(
    private val repository: ProductRepository
) {
    suspend operator fun invoke(): ResultWrapper<List<Product>> {
        return repository.getProducts()
    }
}
```

---

### 2. Data Layer (Implementation) ✅

```bash
data/
├── remote/
│   ├── dto/product/
│   │   ├── ProductDto.kt                  # API response model
│   │   └── CreateProductRequestDto.kt     # API request model
│   └── api/ProductApi.kt                  # Retrofit interface
├── mapper/ProductMapper.kt                # DTO ↔ Domain conversion
└── repository/ProductRepositoryImpl.kt    # Repository implementation
```

**Template:**
```kotlin
// data/remote/dto/product/ProductDto.kt
@Serializable
data class ProductDto(
    @SerializedName("id") val id: String,
    @SerializedName("name") val name: String,
    @SerializedName("price") val price: Double
)

// data/remote/api/ProductApi.kt
interface ProductApi {
    @GET("products")
    suspend fun getProducts(): Response<ApiResponse<List<ProductDto>>>
}

// data/mapper/ProductMapper.kt
class ProductMapper @Inject constructor() {
    fun toDomain(dto: ProductDto): Product {
        return Product(
            id = dto.id,
            name = dto.name,
            price = dto.price
        )
    }
}

// data/repository/ProductRepositoryImpl.kt
class ProductRepositoryImpl @Inject constructor(
    private val api: ProductApi,
    private val mapper: ProductMapper
) : ProductRepository {
    override suspend fun getProducts(): ResultWrapper<List<Product>> {
        return try {
            val response = api.getProducts()
            if (response.isSuccessful) {
                val products = response.body()?.data?.map { mapper.toDomain(it) }
                ResultWrapper.Success(products ?: emptyList())
            } else {
                ResultWrapper.Error(mapError(response.code()))
            }
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.NetworkException.Unknown(e))
        }
    }
}
```

---

### 3. Presentation Layer (UI) ✅

```bash
presentation/feature/product/
├── ProductUiState.kt                      # UI state model
├── ProductViewModel.kt                    # State management
├── ProductScreen.kt                       # Main screen
└── components/
    └── ProductCard.kt                     # Reusable component
```

**Template:**
```kotlin
// presentation/feature/product/ProductUiState.kt
data class ProductUiState(
    val isLoading: Boolean = false,
    val products: List<Product> = emptyList(),
    val error: String? = null
)

// presentation/feature/product/ProductViewModel.kt
@HiltViewModel
class ProductViewModel @Inject constructor(
    private val getProductsUseCase: GetProductsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProductUiState())
    val uiState: StateFlow<ProductUiState> = _uiState.asStateFlow()

    init {
        loadProducts()
    }

    fun loadProducts() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            when (val result = getProductsUseCase()) {
                is ResultWrapper.Success -> {
                    _uiState.update {
                        it.copy(isLoading = false, products = result.data)
                    }
                }
                is ResultWrapper.Error -> {
                    _uiState.update {
                        it.copy(isLoading = false, error = result.exception.getUserMessage())
                    }
                }
            }
        }
    }
}

// presentation/feature/product/ProductScreen.kt
@Composable
fun ProductScreen(
    viewModel: ProductViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    when {
        uiState.isLoading -> LoadingIndicator()
        uiState.error != null -> ErrorView(message = uiState.error!!)
        else -> ProductList(products = uiState.products)
    }
}
```

---

### 4. Dependency Injection ✅

```bash
di/
├── NetworkModule.kt                       # Retrofit, OkHttp
├── RepositoryModule.kt                    # Repository bindings
└── DatabaseModule.kt                      # Room, DAOs
```

**Template:**
```kotlin
// di/RepositoryModule.kt
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindProductRepository(
        impl: ProductRepositoryImpl
    ): ProductRepository
}
```

---

## Common Patterns

### Pattern 1: Result Handling

```kotlin
when (val result = useCase.invoke()) {
    is ResultWrapper.Success -> {
        // Handle success
        val data = result.data
    }
    is ResultWrapper.Error -> {
        // Handle error
        val message = result.exception.getUserMessage()
    }
    is ResultWrapper.Loading -> {
        // Show loading (optional)
    }
}
```

---

### Pattern 2: StateFlow UI State

```kotlin
// ViewModel
private val _uiState = MutableStateFlow(MyUiState())
val uiState: StateFlow<MyUiState> = _uiState.asStateFlow()

// Update state
_uiState.update { it.copy(isLoading = true) }

// Composable
val uiState by viewModel.uiState.collectAsState()
```

---

### Pattern 3: Error Handling

```kotlin
try {
    val response = api.getData()
    if (response.isSuccessful) {
        ResultWrapper.Success(response.body()!!)
    } else {
        ResultWrapper.Error(mapHttpError(response.code()))
    }
} catch (e: IOException) {
    ResultWrapper.Error(AppException.NetworkException.Unknown(e))
} catch (e: Exception) {
    ResultWrapper.Error(AppException.UnknownException(cause = e))
}
```

---

### Pattern 4: Navigation

```kotlin
// Define route
sealed class NavigationRoute(val route: String) {
    data object ProductList : NavigationRoute("products")
    data object ProductDetail : NavigationRoute("products/{id}") {
        fun createRoute(id: String) = "products/$id"
    }
}

// Navigate
navController.navigate(NavigationRoute.ProductDetail.createRoute("123"))

// Receive argument
val productId = backStackEntry.arguments?.getString("id")
```

---

## Code Review Checklist

### Domain Layer ✅
- [ ] No Android imports (`android.*`, `androidx.*`)
- [ ] Pure Kotlin types only
- [ ] Repository is interface (not implementation)
- [ ] Business logic in use cases (not ViewModels)

### Data Layer ✅
- [ ] DTOs in `data/remote/dto/`
- [ ] Mappers exist for DTO ↔ Domain
- [ ] Repository implements domain interface
- [ ] Network errors mapped to `AppException`

### Presentation Layer ✅
- [ ] ViewModel annotated with `@HiltViewModel`
- [ ] ViewModel uses use cases (not repositories directly)
- [ ] UI state is immutable (`data class`)
- [ ] StateFlow for reactive state
- [ ] No business logic in ViewModel
- [ ] Composable uses `hiltViewModel()`

### Dependency Injection ✅
- [ ] Repository bound in `RepositoryModule`
- [ ] Use cases auto-injected (constructor injection)
- [ ] No manual `AppContainer` usage

---

## Naming Conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| Domain Model | `PascalCase` | `Product` |
| DTO | `<Entity>Dto` | `ProductDto` |
| Repository Interface | `<Entity>Repository` | `ProductRepository` |
| Repository Impl | `<Entity>RepositoryImpl` | `ProductRepositoryImpl` |
| Use Case | `<Verb><Entity>UseCase` | `GetProductsUseCase` |
| ViewModel | `<Feature>ViewModel` | `ProductViewModel` |
| UI State | `<Feature>UiState` | `ProductUiState` |
| Screen | `<Feature>Screen` | `ProductScreen` |
| API | `<Entity>Api` | `ProductApi` |
| Mapper | `<Entity>Mapper` | `ProductMapper` |

---

## File Size Limits

- ViewModel: **< 300 lines** (split if larger)
- Screen: **< 400 lines** (extract components)
- Repository: **< 400 lines** (split by entity)
- Use Case: **< 150 lines** (single responsibility)

---

## Common Mistakes

### ❌ Mistake 1: Business Logic in ViewModel
```kotlin
// ❌ Wrong
@HiltViewModel
class ProductViewModel @Inject constructor(
    private val repository: ProductRepository
) : ViewModel() {
    fun createProduct(name: String, price: Double) {
        viewModelScope.launch {
            // ❌ Validation in ViewModel
            if (name.isBlank()) return@launch
            if (price < 0) return@launch

            repository.createProduct(name, price)
        }
    }
}

// ✅ Correct
@HiltViewModel
class ProductViewModel @Inject constructor(
    private val createProductUseCase: CreateProductUseCase
) : ViewModel() {
    fun createProduct(name: String, price: Double) {
        viewModelScope.launch {
            // ✅ Use case handles validation and business logic
            when (val result = createProductUseCase(name, price)) {
                is ResultWrapper.Success -> { /* update UI */ }
                is ResultWrapper.Error -> { /* show error */ }
            }
        }
    }
}
```

---

### ❌ Mistake 2: Android Dependencies in Domain
```kotlin
// ❌ Wrong
package com.app.domain.model

import android.os.Parcelable  // ❌ Android import

data class Product(...) : Parcelable

// ✅ Correct
package com.app.domain.model

data class Product(...)  // ✅ Pure Kotlin
```

---

### ❌ Mistake 3: DTO in Domain
```kotlin
// ❌ Wrong
package com.app.domain.model

data class ProductDto(...)  // ❌ DTO in domain

// ✅ Correct
// domain/model/Product.kt
package com.app.domain.model
data class Product(...)  // ✅ Domain model

// data/remote/dto/product/ProductDto.kt
package com.app.data.remote.dto.product
data class ProductDto(...)  // ✅ DTO in data layer
```

---

## Testing Quick Reference

### Test a Use Case
```kotlin
@Test
fun `invoke returns success when repository succeeds`() = runTest {
    // Given
    val expected = listOf(Product("1", "Product", 10.0))
    coEvery { repository.getProducts() } returns ResultWrapper.Success(expected)

    // When
    val result = useCase.invoke()

    // Then
    assertTrue(result is ResultWrapper.Success)
    assertEquals(expected, (result as ResultWrapper.Success).data)
}
```

### Test a ViewModel
```kotlin
@Test
fun `loadProducts updates state to success`() = runTest {
    // Given
    val products = listOf(Product("1", "Product", 10.0))
    coEvery { useCase() } returns ResultWrapper.Success(products)

    // When
    viewModel.loadProducts()

    // Then
    viewModel.uiState.test {
        val state = awaitItem()
        assertFalse(state.isLoading)
        assertEquals(1, state.products.size)
    }
}
```

---

## Dependency Flow

```
UI (Screen)
    ↓ collectAsState()
ViewModel
    ↓ invoke()
Use Case
    ↓ method call
Repository (Interface)
    ↓ implements
Repository (Impl)
    ↓ API call
Data Source (API/Database)
```

---

## Folder Navigation Shortcuts

```bash
# Domain layer (pure Kotlin)
cd domain/model/              # Business entities
cd domain/repository/         # Repository interfaces
cd domain/usecase/            # Business logic

# Data layer (implementation)
cd data/remote/dto/           # API response models
cd data/remote/api/           # Retrofit interfaces
cd data/mapper/               # DTO ↔ Domain converters
cd data/repository/           # Repository implementations

# Presentation layer (UI)
cd presentation/feature/      # Feature screens
cd presentation/components/   # Reusable UI components
cd presentation/navigation/   # Navigation setup

# Dependency injection
cd di/                        # Hilt modules
```

---

## Quick Commands

### Create new feature
```bash
# Create domain layer
mkdir -p domain/model domain/repository domain/usecase/product

# Create data layer
mkdir -p data/remote/dto/product data/remote/api data/mapper data/repository

# Create presentation layer
mkdir -p presentation/feature/product/components
```

### Run tests
```bash
./gradlew test                    # Unit tests
./gradlew connectedAndroidTest    # Instrumented tests
./gradlew testDebugUnitTest       # Debug unit tests
```

### Code quality
```bash
./gradlew ktlintCheck             # Check code style
./gradlew ktlintFormat            # Auto-format code
./gradlew detekt                  # Static analysis
```

---

## Useful Extensions

### Result Extension
```kotlin
// Unwrap or return error
suspend fun <T> ResultWrapper<T>.getOrReturn(): T? {
    return when (this) {
        is ResultWrapper.Success -> data
        is ResultWrapper.Error -> {
            Logger.e("Error", exception.getUserMessage())
            null
        }
        else -> null
    }
}
```

### StateFlow Extension
```kotlin
// Update state immutably
fun <T> MutableStateFlow<T>.update(transform: (T) -> T) {
    value = transform(value)
}
```

---

## Architecture Rules (Enforced)

1. ✅ **Domain has no dependencies** (pure Kotlin only)
2. ✅ **Presentation depends on Domain** (not Data)
3. ✅ **Data depends on Domain** (implements interfaces)
4. ✅ **Use cases in Domain** (not in ViewModels)
5. ✅ **ViewModels are thin** (delegate to use cases)
6. ✅ **DTOs in Data layer** (never in Domain)
7. ✅ **Mappers for all conversions** (DTO ↔ Domain)
8. ✅ **Hilt for DI** (no manual factories)
9. ✅ **StateFlow for UI state** (immutable data classes)
10. ✅ **ResultWrapper for all operations** (consistent error handling)

---

**Keep this reference handy during development!** 🚀

**Key Takeaway:** Domain is pure Kotlin → Data implements → Presentation consumes.
