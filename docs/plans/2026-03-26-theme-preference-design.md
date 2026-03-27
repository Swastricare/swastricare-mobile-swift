# Theme Preference Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a theme preference (Light / Dark / System / Auto) to the Profile screen on both iOS and Android.

**Architecture:** Each platform gets a ThemeManager singleton that reads the preference from local storage and exposes a reactive theme state. The app's root theme wrapper consumes this state. The Profile Settings section gets a new "Theme" row with a selection dialog.

**Tech Stack:** SwiftUI + UserDefaults (iOS), Jetpack Compose + SharedPreferences + Hilt (Android)

---

## Theme Options Reference

| Option | Value | Behavior |
|--------|-------|----------|
| Light | `light` | Always light mode |
| Dark | `dark` | Always dark mode |
| System | `system` | Follows device setting (default) |
| Auto | `auto` | Time-based: light 6AM–6PM, dark otherwise |

---

### Task 1: iOS — Create ThemeManager

**Files:**
- Create: `swastricare-mobile-swift/Services/ThemeManager.swift`

**Step 1: Create ThemeManager.swift**

```swift
import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable {
    case light, dark, system, auto

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        case .auto: return "Auto"
        }
    }

    var description: String {
        switch self {
        case .light: return "Always light"
        case .dark: return "Always dark"
        case .system: return "Follow device"
        case .auto: return "Light 6AM–6PM"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "appThemePreference"

    @Published var currentTheme: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.key)
            updateColorScheme()
        }
    }

    @Published private(set) var colorScheme: ColorScheme?

    private var timer: Timer?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key) ?? "system"
        self.currentTheme = ThemeMode(rawValue: stored) ?? .system
        self.colorScheme = nil
        updateColorScheme()
        startAutoTimerIfNeeded()
    }

    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil
        case .auto:
            let hour = Calendar.current.component(.hour, from: Date())
            colorScheme = (hour >= 6 && hour < 18) ? .light : .dark
        }
        startAutoTimerIfNeeded()
    }

    private func startAutoTimerIfNeeded() {
        timer?.invalidate()
        timer = nil

        guard currentTheme == .auto else { return }

        // Calculate seconds until next 6AM or 6PM boundary
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let targetHour = hour < 6 ? 6 : (hour < 18 ? 18 : 30) // 30 = 6AM next day

        var target = calendar.date(bySettingHour: targetHour % 24, minute: 0, second: 0, of: now)!
        if targetHour >= 24 {
            target = calendar.date(byAdding: .day, value: 1, to: target)!
        }
        if target <= now {
            target = calendar.date(byAdding: .second, value: 1, to: target)!
        }

        let interval = target.timeIntervalSince(now)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.updateColorScheme()
            }
        }
    }
}
```

**Step 2: Verify file is saved and compiles conceptually (no tests in this project)**

---

### Task 2: iOS — Wire ThemeManager into App Entry Point

**Files:**
- Modify: `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift`

**Step 1: Add ThemeManager as a StateObject**

In the `swastricare_mobile_swiftApp` struct, add after the existing `@StateObject` declarations (around line 24):

```swift
@StateObject private var themeManager = ThemeManager.shared
```

**Step 2: Apply `.preferredColorScheme` to root view**

Find the `.withDependencies()` modifier (line 170) and add `.preferredColorScheme(themeManager.colorScheme)` right after it:

```swift
.withDependencies()
.preferredColorScheme(themeManager.colorScheme)
.environmentObject(appVersionService)
```

Also add `.environmentObject(themeManager)` so ProfileView can access it:

```swift
.preferredColorScheme(themeManager.colorScheme)
.environmentObject(themeManager)
.environmentObject(appVersionService)
```

---

### Task 3: iOS — Add Theme Row to ProfileView Settings Section

**Files:**
- Modify: `swastricare-mobile-swift/Views/Profile/ProfileView.swift`

**Step 1: Add themeManager environment object and state**

Add to the existing state declarations (around line 24):

```swift
@EnvironmentObject private var themeManager: ThemeManager
@State private var showThemePicker = false
```

**Step 2: Add theme row in `settingsSection`**

In the `settingsSection` computed property (line 444), add a theme row before the Notifications toggle. Insert before `Toggle(isOn: $viewModel.notificationsEnabled)`:

```swift
Button(action: { showThemePicker = true }) {
    HStack {
        Label("Theme", systemImage: "paintpalette.fill")
        Spacer()
        Text(themeManager.currentTheme.displayName)
            .foregroundColor(.secondary)
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
.foregroundColor(.primary)
```

**Step 3: Add the theme picker confirmation dialog**

Add a `.confirmationDialog` modifier to the body (after the existing `.sheet` modifier around line 115):

```swift
.confirmationDialog("Choose Theme", isPresented: $showThemePicker) {
    ForEach(ThemeMode.allCases, id: \.self) { mode in
        Button(mode.displayName + " — " + mode.description) {
            themeManager.currentTheme = mode
        }
    }
    Button("Cancel", role: .cancel) {}
}
```

---

### Task 4: Android — Create ThemePreferenceManager

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/ThemePreferenceManager.kt`

**Step 1: Create ThemePreferenceManager.kt**

```kotlin
package com.swastricare.health.ui.theme

import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

enum class ThemeMode(val value: String, val displayName: String, val description: String) {
    LIGHT("light", "Light", "Always light"),
    DARK("dark", "Dark", "Always dark"),
    SYSTEM("system", "System", "Follow device"),
    AUTO("auto", "Auto", "Light 6AM–6PM");

    companion object {
        fun fromValue(value: String): ThemeMode =
            entries.find { it.value == value } ?: SYSTEM
    }
}

@Singleton
class ThemePreferenceManager @Inject constructor(
    private val prefs: SharedPreferences
) {
    private val key = "app_theme_preference"

    private val _themeMode = MutableStateFlow(
        ThemeMode.fromValue(prefs.getString(key, "system") ?: "system")
    )
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    fun setTheme(mode: ThemeMode) {
        prefs.edit().putString(key, mode.value).apply()
        _themeMode.value = mode
    }

    fun isDarkTheme(isSystemDark: Boolean): Boolean {
        return when (_themeMode.value) {
            ThemeMode.LIGHT -> false
            ThemeMode.DARK -> true
            ThemeMode.SYSTEM -> isSystemDark
            ThemeMode.AUTO -> {
                val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                !(hour in 6..17)
            }
        }
    }
}
```

---

### Task 5: Android — Wire ThemePreferenceManager into SwastriCareTheme

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/Theme.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/MainActivity.kt`

**Step 1: Update SwastriCareTheme to accept ThemePreferenceManager**

Replace the `SwastriCareTheme` composable signature to accept an optional `ThemePreferenceManager`:

```kotlin
@Composable
fun SwastriCareTheme(
    themePreferenceManager: ThemePreferenceManager? = null,
    darkTheme: Boolean = if (themePreferenceManager != null) {
        val themeMode by themePreferenceManager.themeMode.collectAsState()
        themePreferenceManager.isDarkTheme(isSystemInDarkTheme())
    } else {
        isSystemInDarkTheme()
    },
    content: @Composable () -> Unit
)
```

Actually, since default parameter expressions can't use `collectAsState`, restructure the function body instead. Keep the signature simple and resolve inside:

In `Theme.kt`, update `SwastriCareTheme`:

```kotlin
@Composable
fun SwastriCareTheme(
    themePreferenceManager: ThemePreferenceManager? = null,
    content: @Composable () -> Unit
) {
    val darkTheme = if (themePreferenceManager != null) {
        val themeMode by themePreferenceManager.themeMode.collectAsState()
        themePreferenceManager.isDarkTheme(isSystemInDarkTheme())
    } else {
        isSystemInDarkTheme()
    }

    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    // ... rest remains the same
```

Add required import at top of Theme.kt:
```kotlin
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
```

**Step 2: Pass ThemePreferenceManager from MainActivity**

In `MainActivity.kt`, inject the manager and pass it to the theme:

Add field (around line 43):
```kotlin
@Inject lateinit var themePreferenceManager: ThemePreferenceManager
```

Update the `setContent` block (line 77):
```kotlin
SwastriCareTheme(themePreferenceManager = themePreferenceManager) {
```

Add import:
```kotlin
import com.swastricare.health.ui.theme.ThemePreferenceManager
```

---

### Task 6: Android — Add Theme Row to ProfileScreen Settings Section

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/profile/ProfileScreen.kt`

**Step 1: Update SettingsSection to include theme picker**

Add `themePreferenceManager` parameter to `SettingsSection` and `ProfileScreenContent` and `ProfileScreen`:

In `ProfileScreen` composable, inject ThemePreferenceManager via `hiltViewModel` isn't possible for a non-ViewModel, so pass it from MainActivity through navigation. Simpler approach: use `LocalContext` + Hilt entry point, or pass it as a composable parameter.

Simplest: add `themePreferenceManager` parameter to `ProfileScreen` and thread it down.

**In ProfileScreen (top-level):**
```kotlin
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel = hiltViewModel(),
    themePreferenceManager: ThemePreferenceManager,  // Add this
    onSignOut: () -> Unit = {},
    // ... rest unchanged
)
```

Thread it to `ProfileScreenContent`, then to `SettingsSection`.

**In SettingsSection, add theme row before the Notification Settings row:**

```kotlin
@Composable
fun SettingsSection(
    themePreferenceManager: ThemePreferenceManager,
    notificationsEnabled: Boolean,
    biometricEnabled: Boolean,
    healthSyncEnabled: Boolean,
    onNotificationToggle: () -> Unit,
    onBiometricToggle: (Boolean) -> Unit,
    onSyncToggle: (Boolean) -> Unit
) {
    var showThemeDialog by remember { mutableStateOf(false) }
    val currentTheme by themePreferenceManager.themeMode.collectAsState()

    SectionContainer(title = "Settings") {
        // Theme row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showThemeDialog = true },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Palette,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = PrimaryColor
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "Theme",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = currentTheme.displayName,
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = AppColors.onSurfaceVariant
            )
        }

        HorizontalDivider(Modifier.padding(vertical = 8.dp))

        // ... existing Notification Settings row and Biometric row unchanged
    }

    // Theme selection dialog
    if (showThemeDialog) {
        AlertDialog(
            onDismissRequest = { showThemeDialog = false },
            title = { Text("Choose Theme") },
            text = {
                Column {
                    ThemeMode.entries.forEach { mode ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    themePreferenceManager.setTheme(mode)
                                    showThemeDialog = false
                                }
                                .padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = mode == currentTheme,
                                onClick = {
                                    themePreferenceManager.setTheme(mode)
                                    showThemeDialog = false
                                },
                                colors = RadioButtonDefaults.colors(selectedColor = PrimaryColor)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = mode.displayName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = AppColors.onSurface
                                )
                                Text(
                                    text = mode.description,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = AppColors.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showThemeDialog = false }) {
                    Text("Cancel")
                }
            },
            containerColor = AppColors.surface,
            titleContentColor = AppColors.onSurface
        )
    }
}
```

Add imports to ProfileScreen.kt:
```kotlin
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import com.swastricare.health.ui.theme.ThemePreferenceManager
import com.swastricare.health.ui.theme.ThemeMode
```

**Step 2: Thread themePreferenceManager through AppNavigation**

The `themePreferenceManager` needs to reach `ProfileScreen`. Since it's `@Singleton` and injected via Hilt, pass it from `MainActivity` → `AppNavigation` → profile route → `ProfileScreen`. Update `AppNavigation.kt` to accept and forward the parameter.

---

### Task 7: Build Verification

**Step 1: iOS build**
```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build
```

**Step 2: Android build**
```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

**Step 3: Fix any compilation errors**

---

### Task 8: Commit

```bash
git add swastricare-mobile-swift/Services/ThemeManager.swift \
       swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift \
       swastricare-mobile-swift/Views/Profile/ProfileView.swift \
       android/app/src/main/kotlin/com/swastricare/health/ui/theme/ThemePreferenceManager.kt \
       android/app/src/main/kotlin/com/swastricare/health/ui/theme/Theme.kt \
       android/app/src/main/kotlin/com/swastricare/health/MainActivity.kt \
       android/app/src/main/kotlin/com/swastricare/health/ui/screens/profile/ProfileScreen.kt
git commit -m "feat: add theme preference (Light/Dark/System/Auto) to Profile on iOS and Android"
```
