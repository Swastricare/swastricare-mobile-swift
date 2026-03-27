# Offline-First Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent false logouts on network loss, add network monitoring, cache health data for offline viewing, and gate network-dependent features with user-friendly messages.

**Architecture:** Five layers built bottom-up: (1) NetworkMonitor service on both platforms, (2) session persistence fix in auth flow, (3) generic CacheService + cached data loading, (4) offline banner + network-gated features, (5) cache cleanup on logout. Each layer is independent enough to ship incrementally.

**Tech Stack:** iOS — NWPathMonitor, Codable JSON files, SwiftUI environment. Android — ConnectivityManager.NetworkCallback, EncryptedSharedPreferences, Hilt, StateFlow, Jetpack Compose.

---

## Task 1: iOS NetworkMonitorService

**Files:**
- Create: `swastricare-mobile-swift/Services/NetworkMonitorService.swift`
- Modify: `swastricare-mobile-swift/Core/DependencyContainer.swift`

**Step 1: Create NetworkMonitorService**

```swift
// swastricare-mobile-swift/Services/NetworkMonitorService.swift

import Foundation
import Network
import Combine

protocol NetworkMonitorServiceProtocol: AnyObject {
    var isConnected: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
}

@MainActor
final class NetworkMonitorService: ObservableObject, NetworkMonitorServiceProtocol {
    static let shared = NetworkMonitorService()

    @Published private(set) var isConnected: Bool = true

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.swastricare.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
```

**Step 2: Register in DependencyContainer**

In `swastricare-mobile-swift/Core/DependencyContainer.swift`, add the service property alongside existing services (after line 36):

```swift
let networkMonitor: NetworkMonitorServiceProtocol
```

And in `private init()` (after line 124):

```swift
self.networkMonitor = NetworkMonitorService.shared
```

**Step 3: Add SwiftUI environment key for NetworkMonitor**

In `DependencyContainer.swift`, add a new environment key so views can observe connectivity directly:

```swift
// At the bottom of DependencyContainer.swift, after the existing EnvironmentValues extension

private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: NetworkMonitorService = NetworkMonitorService.shared
}

extension EnvironmentValues {
    var networkMonitor: NetworkMonitorService {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}
```

**Step 4: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add swastricare-mobile-swift/Services/NetworkMonitorService.swift swastricare-mobile-swift/Core/DependencyContainer.swift
git commit -m "feat(ios): add NetworkMonitorService with NWPathMonitor"
```

---

## Task 2: Android NetworkMonitorService

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/data/services/NetworkMonitorService.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/di/ServiceModule.kt`

**Step 1: Create NetworkMonitorService**

```kotlin
// android/app/src/main/kotlin/com/swastricare/health/data/services/NetworkMonitorService.kt

package com.swastricare.health.data.services

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class NetworkMonitorService(context: Context) {

    companion object {
        private const val TAG = "NetworkMonitor"
    }

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val _isConnected = MutableStateFlow(checkCurrentConnectivity())
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Log.d(TAG, "Network available")
            _isConnected.value = true
        }

        override fun onLost(network: Network) {
            Log.d(TAG, "Network lost")
            _isConnected.value = false
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            Log.d(TAG, "Capabilities changed: hasInternet=$hasInternet")
            _isConnected.value = hasInternet
        }
    }

    init {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
    }

    private fun checkCurrentConnectivity(): Boolean {
        return try {
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } catch (e: Exception) {
            false
        }
    }
}
```

**Step 2: Register in Hilt ServiceModule**

In `android/.../di/ServiceModule.kt`, add after `provideSessionManager` (after line 122):

```kotlin
@Provides
@Singleton
fun provideNetworkMonitorService(
    @ApplicationContext context: Context
): NetworkMonitorService {
    return NetworkMonitorService(context)
}
```

**Step 3: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/services/NetworkMonitorService.kt android/app/src/main/kotlin/com/swastricare/health/di/ServiceModule.kt
git commit -m "feat(android): add NetworkMonitorService with ConnectivityManager"
```

---

## Task 3: iOS Session Persistence Fix

**Files:**
- Modify: `swastricare-mobile-swift/Services/AuthService.swift` (lines 40-57)
- Modify: `swastricare-mobile-swift/ViewModels/AuthViewModel.swift` (lines 53-67)

**Step 1: Update AuthService.checkSession() to accept network state**

Replace `checkSession()` in `AuthService.swift` (lines 40-57) with:

```swift
func checkSession(isOnline: Bool = true) async throws -> AppUser? {
    // When offline, trust the locally cached session without network check
    if !isOnline {
        if let user = client.auth.currentUser {
            return mapUser(user)
        }
        return nil
    }

    // Online: check session with timeout (existing behavior)
    do {
        return try await withTimeout(seconds: 5) {
            do {
                let session = try await self.client.auth.session
                guard !session.isExpired else { return nil }
                return self.mapUser(session.user)
            } catch {
                return nil
            }
        }
    } catch {
        // Timeout — could be slow network. Fall back to local session.
        if let user = client.auth.currentUser {
            return mapUser(user)
        }
        return nil
    }
}
```

Also update the protocol in `AuthService.swift` (line 15):

```swift
func checkSession(isOnline: Bool) async throws -> AppUser?
```

**Step 2: Update AuthViewModel.checkAuthStatus() to use NetworkMonitor**

Replace `checkAuthStatus()` in `AuthViewModel.swift` (lines 53-67) with:

```swift
func checkAuthStatus() async {
    let isOnline = await MainActor.run { NetworkMonitorService.shared.isConnected }
    do {
        if let user = try await authService.checkSession(isOnline: isOnline) {
            authState = .authenticated(user)
            UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
            if isOnline {
                await fetchHealthProfile()
            }
        } else {
            authState = .unauthenticated
        }
    } catch {
        authState = .unauthenticated
    }
}
```

**Step 3: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Services/AuthService.swift swastricare-mobile-swift/ViewModels/AuthViewModel.swift
git commit -m "fix(ios): trust local session when offline, prevent false logout"
```

---

## Task 4: Android Session Persistence Fix

**Files:**
- Modify: `android/.../data/repository/SupabaseAuthRepository.kt` (lines 43-62)
- Modify: `android/.../ui/screens/auth/AuthViewModel.kt` (lines 67-81)

**Step 1: Update SupabaseAuthRepository.checkSession() to accept network state**

Replace `checkSession()` in `SupabaseAuthRepository.kt` (lines 43-62) with:

```kotlin
suspend fun checkSession(isOnline: Boolean = true): AppUser? {
    // When offline, trust the locally cached session
    if (!isOnline) {
        val user = supabaseClient.auth.currentUserOrNull()
        return user?.let { mapUser(it) }
    }

    // Online: check session with timeout (existing behavior)
    return try {
        withTimeout(5000) {
            try {
                val session = supabaseClient.auth.currentSessionOrNull()
                if (session != null) {
                    session.user?.let { mapUser(it) }
                } else {
                    null
                }
            } catch (e: Exception) {
                null
            }
        }
    } catch (e: Exception) {
        // Timeout — fall back to local session
        val user = supabaseClient.auth.currentUserOrNull()
        user?.let { mapUser(it) }
    }
}
```

**Step 2: Update AuthViewModel.checkSession() to use NetworkMonitor**

In `AuthViewModel.kt`, add `NetworkMonitorService` as a constructor dependency:

```kotlin
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: SupabaseAuthRepository,
    private val googleAuthHelper: GoogleAuthHelper,
    private val analyticsService: AnalyticsService,
    private val crashlyticsService: CrashlyticsService,
    private val networkMonitor: NetworkMonitorService
) : ViewModel() {
```

Replace `checkSession()` (lines 67-81) with:

```kotlin
private fun checkSession() {
    viewModelScope.launch {
        _uiState.value = AuthUiState.Loading
        try {
            val isOnline = networkMonitor.isConnected.value
            val user = authRepository.checkSession(isOnline)
            _uiState.value = if (user != null) {
                AuthUiState.Success(user)
            } else {
                AuthUiState.Idle
            }
        } catch (e: Exception) {
            _uiState.value = AuthUiState.Idle
        }
    }
}
```

**Step 3: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/repository/SupabaseAuthRepository.kt android/app/src/main/kotlin/com/swastricare/health/ui/screens/auth/AuthViewModel.kt
git commit -m "fix(android): trust local session when offline, prevent false logout"
```

---

## Task 5: iOS CacheService

**Files:**
- Create: `swastricare-mobile-swift/Services/CacheService.swift`
- Modify: `swastricare-mobile-swift/Core/DependencyContainer.swift`

**Step 1: Create CacheService**

```swift
// swastricare-mobile-swift/Services/CacheService.swift

import Foundation

protocol CacheServiceProtocol {
    func save<T: Encodable>(_ data: T, forKey key: String, ttl: TimeInterval) throws
    func load<T: Decodable>(forKey key: String, as type: T.Type) -> T?
    func remove(forKey key: String)
    func clearAll(forUserId userId: String)
}

@MainActor
final class CacheService: CacheServiceProtocol {
    static let shared = CacheService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var currentUserId: String?

    private var cacheDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HealthCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func setCurrentUser(_ userId: String) {
        currentUserId = userId
    }

    func save<T: Encodable>(_ data: T, forKey key: String, ttl: TimeInterval = 86400) throws {
        let wrapper = CacheWrapper(data: data, expiresAt: Date().addingTimeInterval(ttl))
        let encoded = try encoder.encode(wrapper)
        let fileURL = fileURL(for: prefixedKey(key))
        try encoded.write(to: fileURL, options: .atomic)
    }

    func load<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = fileURL(for: prefixedKey(key))
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let wrapper = try? decoder.decode(CacheWrapper<T>.self, from: data) else { return nil }
        // Return data even if expired (offline fallback) — caller refreshes if online
        return wrapper.data
    }

    func isExpired(forKey key: String) -> Bool {
        let fileURL = fileURL(for: prefixedKey(key))
        guard let data = try? Data(contentsOf: fileURL) else { return true }
        guard let wrapper = try? decoder.decode(CacheMetadata.self, from: data) else { return true }
        return wrapper.expiresAt < Date()
    }

    func remove(forKey key: String) {
        let fileURL = fileURL(for: prefixedKey(key))
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll(forUserId userId: String) {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        let prefix = "\(userId)_"
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func prefixedKey(_ key: String) -> String {
        guard let userId = currentUserId else { return key }
        return "\(userId)_\(key)"
    }

    private func fileURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }
}

// MARK: - Cache Wrapper

private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let expiresAt: Date
}

private struct CacheMetadata: Decodable {
    let expiresAt: Date
}
```

**Step 2: Register in DependencyContainer**

In `DependencyContainer.swift`, add alongside other services:

```swift
let cacheService: CacheServiceProtocol
```

In `private init()`:

```swift
self.cacheService = CacheService.shared
```

**Step 3: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Services/CacheService.swift swastricare-mobile-swift/Core/DependencyContainer.swift
git commit -m "feat(ios): add CacheService with TTL-based JSON file caching"
```

---

## Task 6: Android CacheService

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/data/services/CacheService.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/di/ServiceModule.kt`

**Step 1: Create CacheService**

```kotlin
// android/app/src/main/kotlin/com/swastricare/health/data/services/CacheService.kt

package com.swastricare.health.data.services

import android.content.SharedPreferences
import android.util.Log
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class CacheService(
    private val sharedPreferences: SharedPreferences
) {
    companion object {
        private const val TAG = "CacheService"
        private const val EXPIRY_SUFFIX = "_expiry"
    }

    private val json = Json { ignoreUnknownKeys = true }
    private var currentUserId: String? = null

    fun setCurrentUser(userId: String) {
        currentUserId = userId
    }

    inline fun <reified T> save(key: String, data: T, ttlMs: Long = 86_400_000L) {
        try {
            val prefixed = prefixedKey(key)
            val encoded = json.encodeToString(data)
            sharedPreferences.edit()
                .putString(prefixed, encoded)
                .putLong(prefixed + EXPIRY_SUFFIX, System.currentTimeMillis() + ttlMs)
                .apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cache $key", e)
        }
    }

    inline fun <reified T> load(key: String): T? {
        return try {
            val prefixed = prefixedKey(key)
            val raw = sharedPreferences.getString(prefixed, null) ?: return null
            json.decodeFromString<T>(raw)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load cache $key", e)
            null
        }
    }

    fun isExpired(key: String): Boolean {
        val prefixed = prefixedKey(key)
        val expiry = sharedPreferences.getLong(prefixed + EXPIRY_SUFFIX, 0L)
        return System.currentTimeMillis() > expiry
    }

    fun remove(key: String) {
        val prefixed = prefixedKey(key)
        sharedPreferences.edit()
            .remove(prefixed)
            .remove(prefixed + EXPIRY_SUFFIX)
            .apply()
    }

    fun clearAll(userId: String) {
        val prefix = "${userId}_"
        val editor = sharedPreferences.edit()
        sharedPreferences.all.keys.filter { it.startsWith(prefix) }.forEach { editor.remove(it) }
        editor.apply()
    }

    @PublishedApi
    internal fun prefixedKey(key: String): String {
        val uid = currentUserId ?: return key
        return "${uid}_$key"
    }
}
```

**Step 2: Register in Hilt ServiceModule**

In `ServiceModule.kt`, add:

```kotlin
@Provides
@Singleton
fun provideCacheService(
    sharedPreferences: SharedPreferences
): CacheService {
    return CacheService(sharedPreferences)
}
```

**Step 3: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/services/CacheService.kt android/app/src/main/kotlin/com/swastricare/health/di/ServiceModule.kt
git commit -m "feat(android): add CacheService with TTL-based EncryptedSharedPreferences caching"
```

---

## Task 7: iOS Cache Integration in Key ViewModels

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/AuthViewModel.swift`
- Modify: `swastricare-mobile-swift/ViewModels/HomeViewModel.swift`
- Modify: `swastricare-mobile-swift/ViewModels/HydrationViewModel.swift`
- Modify: `swastricare-mobile-swift/ViewModels/MedicationViewModel.swift`

**Step 1: Set currentUser on CacheService when auth succeeds**

In `AuthViewModel.swift`, after setting `authState = .authenticated(user)` in `checkAuthStatus()`, add:

```swift
CacheService.shared.setCurrentUser(user.id)
```

**Step 2: Add cache-first loading pattern to HomeViewModel**

Read `HomeViewModel.swift` first. Then add to its `loadTodaysData()` method:

At the start of `loadTodaysData()`:
```swift
// Load cached data first for instant UI
if let cached: HomeHealthData = CacheService.shared.load(forKey: "home_health_data", as: HomeHealthData.self) {
    self.applyHealthData(cached)
}
```

After successful network fetch, cache the result:
```swift
try? CacheService.shared.save(healthData, forKey: "home_health_data", ttl: 86400)
```

Note: The exact implementation depends on what `loadTodaysData()` returns. The engineer should read the file, identify the data model, and make it `Codable` if not already. The pattern is always: load cache → show → if online, fetch → update cache → update UI.

**Step 3: Apply same pattern to HydrationViewModel.loadData()**

```swift
// At start of loadData():
if let cached: [HydrationEntry] = CacheService.shared.load(forKey: "hydration_today", as: [HydrationEntry].self) {
    self.entries = cached
}

// After successful fetch:
try? CacheService.shared.save(entries, forKey: "hydration_today", ttl: 14400) // 4h TTL
```

**Step 4: Apply same pattern to MedicationViewModel**

```swift
// At start of load:
if let cached: [Medication] = CacheService.shared.load(forKey: "medications", as: [Medication].self) {
    self.medications = cached
}

// After successful fetch:
try? CacheService.shared.save(medications, forKey: "medications", ttl: 86400)
```

**Step 5: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(ios): add cache-first loading to Home, Hydration, and Medication ViewModels"
```

---

## Task 8: Android Cache Integration in Key ViewModels

**Files:**
- Modify: `android/.../ui/screens/auth/AuthViewModel.kt`
- Modify: `android/.../ui/screens/home/HomeViewModel.kt`
- Modify: `android/.../ui/screens/hydration/HydrationViewModel.kt`
- Modify: `android/.../ui/screens/medication/MedicationViewModel.kt`

**Step 1: Set currentUser on CacheService when auth succeeds**

In Android `AuthViewModel.kt`, inject `CacheService` and after setting `AuthUiState.Success(user)`, add:

```kotlin
cacheService.setCurrentUser(user.id)
```

**Step 2: Apply cache-first pattern to HomeViewModel, HydrationViewModel, MedicationViewModel**

Same pattern as iOS — read each ViewModel, find the data loading function, and add:

```kotlin
// At start of load:
val cached = cacheService.load<ModelType>("cache_key")
if (cached != null) {
    _uiState.value = /* apply cached data */
}

// After successful fetch:
cacheService.save("cache_key", data, ttlMs = 86_400_000L)
```

Note: The engineer must read each ViewModel first to understand the exact data types and state properties. All cached model classes must be `@Serializable`.

**Step 3: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(android): add cache-first loading to Home, Hydration, and Medication ViewModels"
```

---

## Task 9: iOS Offline Banner & Network-Gated Features

**Files:**
- Create: `swastricare-mobile-swift/Views/Components/OfflineBanner.swift`
- Modify: `swastricare-mobile-swift/Views/Main/ContentView.swift`
- Modify: `swastricare-mobile-swift/Views/AI/AIView.swift`
- Modify: `swastricare-mobile-swift/Views/Family/FamilyView.swift` (if exists)

**Step 1: Create OfflineBanner component**

```swift
// swastricare-mobile-swift/Views/Components/OfflineBanner.swift

import SwiftUI

struct OfflineBanner: View {
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.subheadline)
                Text("You're offline. Some features may be limited.")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        }
    }
}
```

**Step 2: Add OfflineBanner to ContentView**

In `ContentView.swift`, add `OfflineBanner()` at the top of the main VStack/ZStack (inside the body, above the tab content). Read the file first to find the exact insertion point.

```swift
VStack(spacing: 0) {
    OfflineBanner()
    // ... existing tab content
}
```

**Step 3: Gate AI chat when offline**

In `AIView.swift`, read the file first. Find the send button / input area and add a network check:

```swift
// Disable send when offline
@ObservedObject private var networkMonitor = NetworkMonitorService.shared

// On the send button:
.disabled(!networkMonitor.isConnected)

// Show message in chat area when offline:
if !networkMonitor.isConnected {
    Text("AI chat requires an internet connection")
        .foregroundColor(.secondary)
        .font(.subheadline)
}
```

**Step 4: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(ios): add offline banner and network-gated AI chat"
```

---

## Task 10: Android Offline Banner & Network-Gated Features

**Files:**
- Create: `android/.../ui/components/OfflineBanner.kt`
- Modify: `android/.../ui/screens/main/MainScreen.kt`
- Modify: `android/.../ui/screens/ai/AIScreen.kt`

**Step 1: Create OfflineBanner composable**

```kotlin
// android/.../ui/components/OfflineBanner.kt

package com.swastricare.health.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.services.NetworkMonitorService

@Composable
fun OfflineBanner(networkMonitor: NetworkMonitorService) {
    val isConnected by networkMonitor.isConnected.collectAsState()

    AnimatedVisibility(
        visible = !isConnected,
        enter = slideInVertically(initialOffsetY = { -it }),
        exit = slideOutVertically(targetOffsetY = { -it })
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFFF59E0B))
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.WifiOff,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "You're offline. Some features may be limited.",
                color = Color.White,
                fontSize = 13.sp
            )
        }
    }
}
```

**Step 2: Add OfflineBanner to MainScreen**

Read `MainScreen.kt` first. Add the banner at the top of the Scaffold content:

```kotlin
// Inject NetworkMonitorService in the ViewModel or pass directly
Column {
    OfflineBanner(networkMonitor = networkMonitor)
    // ... existing content
}
```

**Step 3: Gate AI Screen**

In `AIScreen.kt`, check `networkMonitor.isConnected` and disable send button when offline. Show inline message.

**Step 4: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(android): add offline banner and network-gated AI chat"
```

---

## Task 11: iOS Cache Cleanup on Logout

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/AuthViewModel.swift`
- Modify: `swastricare-mobile-swift/Services/AuthService.swift`

**Step 1: Clear cache on sign out**

In `AuthViewModel.swift`, in the `signOut()` method (lines 178-193), after `authState = .unauthenticated`, add:

```swift
if let userId = currentUser?.id {
    CacheService.shared.clearAll(forUserId: userId)
}
```

**Step 2: Clear cache on delete account**

In `AuthService.swift`, in `deleteAccount()` (lines 152-164), the cleanup already clears UserDefaults. CacheService uses the Documents directory, so add cache clearing in AuthViewModel when delete account completes.

**Step 3: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/AuthViewModel.swift
git commit -m "feat(ios): clear cached health data on logout"
```

---

## Task 12: Android Cache Cleanup on Logout

**Files:**
- Modify: `android/.../data/repository/SupabaseAuthRepository.kt`

**Step 1: Inject CacheService and clear on sign out**

Add `CacheService` as a constructor parameter to `SupabaseAuthRepository`:

```kotlin
@Singleton
class SupabaseAuthRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences,
    private val cacheService: CacheService
) : AuthRepository {
```

In `signOut()` (line 152-156) and `deleteAccount()` (line 164-178), add before `clearLocalData()`:

```kotlin
val userId = supabaseClient.auth.currentUserOrNull()?.id
if (userId != null) {
    cacheService.clearAll(userId)
}
```

**Step 2: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/data/repository/SupabaseAuthRepository.kt android/app/src/main/kotlin/com/swastricare/health/di/ServiceModule.kt
git commit -m "feat(android): clear cached health data on logout"
```

---

## Task 13: iOS Scene Phase — Re-check Auth on Network Restore

**Files:**
- Modify: `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift`

**Step 1: Add network restoration handler**

In `swastricare_mobile_swiftApp.swift`, add a listener that re-validates auth when network comes back while user was authenticated offline. Add this in the `.onChange(of: scenePhase)` handler or as a separate `.onReceive`:

After the existing `.onChange(of: scenePhase)` block (around line 190), add:

```swift
.onReceive(NetworkMonitorService.shared.$isConnected) { isConnected in
    if isConnected && authViewModel.isAuthenticated {
        // Network restored — let Supabase SDK refresh token in background
        // Also refresh health profile if it wasn't loaded offline
        Task {
            await authViewModel.fetchHealthProfile()
        }
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift
git commit -m "feat(ios): refresh health profile when network restores"
```

---

## Task 14: Android Network Restore Handler

**Files:**
- Modify: `android/.../ui/navigation/AppNavigation.kt`

**Step 1: Observe network restoration in AppNavigation**

In `AppNavigation.kt`, add a `LaunchedEffect` that watches for network restoration:

```kotlin
val networkMonitor: NetworkMonitorService = // inject via hiltViewModel or pass from MainActivity
val isConnected by networkMonitor.isConnected.collectAsState()

// When network restores and user is authenticated, let SDK refresh
LaunchedEffect(isConnected) {
    if (isConnected && authState is AuthUiState.Success) {
        // Supabase SDK auto-refreshes token in background
        // Log for debugging
        Log.d("AppNavigation", "Network restored — Supabase SDK will auto-refresh token")
    }
}
```

**Step 2: Build to verify**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/navigation/AppNavigation.kt
git commit -m "feat(android): handle network restoration in navigation"
```

---

## Task 15: Final Verification & Integration Test

**Step 1: iOS full build**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED

**Step 2: Android full build**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug 2>&1 | tail -10
```
Expected: BUILD SUCCESSFUL

**Step 3: Manual test checklist (for the developer)**

- [ ] iOS: Enable airplane mode → open app → should stay logged in, see cached data
- [ ] iOS: While offline, tap AI chat → see "requires internet" message
- [ ] iOS: Disable airplane mode → data refreshes automatically
- [ ] iOS: Sign out → sign in again → no stale cache from previous user
- [ ] Android: Same 4 tests as above
- [ ] Both: Offline banner appears/disappears correctly with animation

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: offline-first architecture — network monitor, session persistence, read cache, offline UX"
```
