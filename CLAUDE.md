# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwasthiCare is a personal health management app targeting an Indian audience. It tracks hydration, medications, vitals, activity, diet, and menstrual cycles. It supports both self-care and family caregiving via role-based family groups. The backend is Supabase (Auth, Postgres, Storage, Edge Functions).

## Dual-Platform Codebase

This repository contains both **iOS (Swift/SwiftUI)** and **Android (Kotlin/Jetpack Compose)** codebases. When a request is ambiguous about platform, clarify before making changes.

- **iOS source**: `swastricare-mobile-swift/` (Swift files, models, views, services, viewmodels)
- **Android source**: `android/app/src/main/kotlin/com/swastricare/health/` (package was renamed from `com.swasthicare.mobile`)
- **Shared backend**: `supabase/` (migrations, edge functions — serves both platforms)
- **iOS widgets**: `SwasthiCareWidgets/`
- **Documentation**: `docs/` (setup guides, implementation guides, design plans)

## Build Commands

### iOS

```bash
# Build for simulator (quick validation — most common)
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build

# Build the widget extension
xcodebuild -scheme SwasthiCareWidgetsExtension -configuration Debug build
```

### Android

```bash
# Debug build (requires Android Studio JDK)
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug

# If Gradle OOM: ensure gradle.properties has kotlin.daemon.jvmargs=-Xmx2048m
```

### Supabase

```bash
supabase db push          # Apply migrations locally
supabase functions serve  # Serve edge functions locally
```

There are no unit tests, linter, or formatter configured for the iOS project.

## Architecture

### iOS: MVVM + Protocol-Oriented DI

`DependencyContainer` (`swastricare-mobile-swift/Core/DependencyContainer.swift`) is the single `@MainActor` singleton that owns all services and ViewModels:

- **Services** are protocol-typed singletons (`AuthServiceProtocol`, `HealthKitServiceProtocol`, etc.) initialized eagerly in `DependencyContainer.init()`
- **ViewModels** are `lazy var` properties on the container, injected into Views via `@StateObject private var vm = DependencyContainer.shared.someViewModel`
- The container is also available via SwiftUI environment: `.withDependencies()` modifier applied at root, accessed with `@Environment(\.dependencies)`

When adding a new iOS feature:
1. Define a service protocol in `Services/`
2. Implement the service as a singleton (`static let shared`)
3. Add the protocol-typed property to `DependencyContainer`
4. Add a lazy ViewModel property to `DependencyContainer`
5. Create the View using `@StateObject` from the container

### Android: MVVM + Repository Pattern

`AppContainer` (`android/.../di/AppContainer.kt`) is the DI singleton using Kotlin `by lazy`:

- **Repositories** abstract all Supabase operations (Auth, Profile, Hydration, Medication, Diet, RunActivity, Vault, Family, AIConversation, MenstrualCycle, HeartRate, Nudge, etc.)
- **Services** handle platform-specific concerns (HealthConnect, Biometric, Notifications, Location, Workout, Weather, etc.)
- **ViewModels** are lazy-initialized from the container
- **SessionManager** observes auth state and detects token expiry
- Uses Encrypted SharedPreferences (AES-256-GCM) with automatic migration fallback

When adding a new Android feature:
1. Create model classes in `data/models/`
2. Create a Supabase repository in `data/repository/`
3. Add the repository to `AppContainer`
4. Create a ViewModel with repository injection
5. Create Compose screen in `ui/screens/`

### Navigation

**iOS**: `swastricare_mobile_swiftApp.swift` implements a linear navigation state machine:
```
Splash → ForceUpdate? → Onboarding → Consent → Login → HealthProfileQuestionnaire → BiometricLock? → ContentView (5 tabs)
```
State is tracked via `@State` booleans with auth state from `AuthViewModel`.

**Android**: `AppNavigation.kt` uses Jetpack Compose Navigation with a similar flow.

### Tab Structure (both platforms)

5 tabs: **Vitals** (Home) → **Vault** → **AI** (center) → **Steps** (RunActivity) → **Profile**

## Key Architectural Files

### iOS

| File | Role |
|------|------|
| `Core/DependencyContainer.swift` | All DI — services + ViewModels |
| `App/swastricare_mobile_swiftApp.swift` | Entry point, navigation state machine, Firebase init |
| `SupabaseManager.swift` | All Supabase DB/Storage/Auth operations (~77KB, central data layer) |
| `Config.swift` | Supabase project URL and anon key, `AppConfig` flags |
| `DesignSystem.swift` | `AppColors`, `AppDimensions`, `PremiumColor`, gradients, `.glass()` modifier, `ScaleButtonStyle` |
| `Helpers/DeepLinkHandler.swift` | URL scheme routing for widgets + family invites |

### Android

| File | Role |
|------|------|
| `di/AppContainer.kt` | DI singleton — Supabase client, services, repositories, ViewModels |
| `MainActivity.kt` | Entry point, Compose host |
| `navigation/AppNavigation.kt` | Jetpack Compose navigation graph |
| `data/SupabaseConfig.kt` | Supabase credentials (injected via BuildConfig) |
| `data/services/SessionManager.kt` | Auth token management + expiry detection |

## Design System (iOS)

- **Colors**: `AppColors` for semantic colors (`accentBlue` #4F46E5, `accentGreen` #22C55E, `accentRed` #EF4444, `onboardingPurple` #7C3AED, `onboardingSkyBlue` #0EA5E9). Never hardcode raw hex colors.
- **Dimensions**: `AppDimensions` for consistent spacing (`cardRadius` 16, `largeCardRadius` 20, `cardPadding` 16, `quickActionHeight` 100)
- **Gradients**: `PremiumColor.royalBlue`, `.sunset`, `.neonGreen`, `.deepPurple`
- **Background**: `PremiumBackground()` for screen backgrounds (gradient orbs)
- **Glass effect**: `.glass(cornerRadius:)` modifier for frosted material cards
- **Button style**: `ScaleButtonStyle()` for tappable spring-scale buttons
- **Color extension**: `Color(hex:)` for hex string conversion

## Backend (Supabase)

- **Migrations**: `supabase/migrations/` — 32 SQL files, all tables use RLS
- **Edge Functions**: `supabase/functions/` — 12 Deno/TypeScript functions + `_shared/` utilities
- **Universal FK**: All health data connects via `health_profile_id` foreign key
- **Family access**: Controlled by `has_family_access(profile_id, permission)` SQL function
- **AI routing**: `ai-router` edge function auto-routes to Gemini Flash (general), MedGemma 27B (medical keywords), or MedGemma 4B (image analysis), with fallback
- **Health data sync**: iOS uses HealthKit, Android uses Health Connect — both sync bidirectionally with Supabase

## Home Screen Layout (iOS)

The home screen (`Views/Home/HomeView.swift`) uses a side-by-side layout:
- **Left**: 2×3 grid of `CompactStatCell` (Cal, Min, Stand, BPM, Sleep, km) with semantic color tints
- **Right**: 3D anatomy model (`ModelViewer`) — tappable to launch AR Body Scan
- **Below**: Diet summary card with calorie ring + macro pills (P/C/F)
- **Bottom**: 4 quick action cards (Medication, Hydration, Diet, Cycle) at 100pt height

## Diet/Food Tracking

- **Offline-first**: Local JSON storage (`DietLocalStorage` with in-memory cache) → async Supabase sync
- **Search**: Fuzzy token-based search with relevance scoring (not just substring)
- **Indian foods**: ~300 seeded items covering South/North Indian, Bengali, Gujarati, street food. Veg/non-veg FSSAI indicators + filter toggle.
- **Features**: Copy yesterday's meals, undo-on-delete (5s timer), weekly calorie chart, goal adherence tracking
- **Calorie goal**: Uses Mifflin-St Jeor BMR + TDEE with goal-based adjustment

## Widgets (iOS)

`SwasthiCareWidgets/` contains 6 widgets (Hydration, Medication, Steps, Run, Workout Live Activity, Health Live Activity). Data shared via `WidgetDataManager` using shared `UserDefaults` (app group `group.com.swasthicare.shared`). Widget intents use `AppIntents` framework.

## Deep Links

Primary scheme `swastricareapp://` (also OAuth redirect). Legacy: `swasthicare://`, `swastricare://`. Routes: `home`, `hydration`, `medications`, `heartRate`, `steps`, `run`, `activeWorkout`, `startRun/{type}`, `family/join?code=`. Processed by `DeepLinkHandler`.

## Important Patterns

- All ViewModels and `DependencyContainer` are `@MainActor` — maintain this for any new iOS ViewModels
- iOS services follow the `XxxServiceProtocol` + `XxxService.shared` singleton pattern
- `SupabaseManager.shared.client` is the Supabase client — all iOS DB calls go through `SupabaseManager`
- `DietLocalStorage` is `@MainActor` with in-memory caching — never access from background threads
- Workout crash recovery: `WorkoutStateManager` auto-saves every 10s; `WorkoutLifecycleHandler` detects abandoned workouts on next launch
- Camera heart rate uses custom PPG signal processing (`PPGSignalProcessor`, `HeartRateDetector`, `SignalValidator`) — wired on both platforms
- Android heart rate syncs to `vital_signs` Supabase table via `SupabaseHeartRateRepository`
- `NotificationService` manages all push notification categories (hydration, medication, diet, menstrual)
- `AppConfig.isTestingMode` controls whether onboarding is shown every launch (set `false` for production)
- Android uses Encrypted SharedPreferences for sensitive data with automatic fallback migration
- Xcode project uses `fileSystemSynchronizedGroups` — new files are auto-discovered, no need to modify `.pbxproj`
- SourceKit diagnostics ("Cannot find X in scope") on new files are false positives — always verify with actual `xcodebuild`
