# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwasthiCare is a personal health management app targeting an Indian audience. It tracks hydration, medications, vitals, activity, diet, and menstrual cycles. It supports both self-care and family caregiving via role-based family groups. The backend is Supabase (Auth, Postgres, Storage, Edge Functions).

## Dual-Platform Codebase

This repository contains both **iOS (Swift/SwiftUI)** and **Android (Kotlin/Jetpack Compose)** codebases. When a request is ambiguous about platform, clarify before making changes.

- **iOS source**: `swastricare-mobile-swift/` (Swift files, models, views, services, viewmodels)
- **Android source**: `android/app/src/main/kotlin/com/swasthicare/mobile/`
- **Shared backend**: `supabase/` (migrations, edge functions — serves both platforms)
- **iOS widgets**: `SwasthiCareWidgets/`
- **Documentation**: `docs/` (setup guides, implementation guides, design plans)

## Build Commands

### iOS

```bash
# Build the iOS app (Debug)
xcodebuild -scheme swastricare-mobile-swift -configuration Debug build

# Build the widget extension
xcodebuild -scheme SwasthiCareWidgetsExtension -configuration Debug build

# Build for simulator (quick validation)
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build
```

### Android

```bash
# Debug build
cd android && ./gradlew assembleDebug

# Release build
cd android && ./gradlew assembleRelease

# Run tests
cd android && ./gradlew test
```

### Supabase

```bash
# Apply migrations locally
supabase db push

# Serve edge functions locally
supabase functions serve
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

- **Repositories** abstract all Supabase operations (13 repositories: Auth, Profile, Hydration, Medication, Diet, RunActivity, Vault, Family, AIConversation, MenstrualCycle, Nudge, etc.)
- **Services** handle platform-specific concerns (HealthConnect, Biometric, Notifications, Location, Workout, Weather, etc.)
- **ViewModels** are lazy-initialized from the container
- **SessionManager** observes auth state and detects token expiry
- Uses Encrypted SharedPreferences (AES-256-GCM) with automatic migration fallback, and DataStore for newer preferences

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
| `swastricare-mobile-swift/Core/DependencyContainer.swift` | All DI — services + ViewModels |
| `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift` | Entry point, navigation state machine, Firebase init |
| `swastricare-mobile-swift/SupabaseManager.swift` | All Supabase DB/Storage/Auth operations (~77KB, central data layer) |
| `swastricare-mobile-swift/Config.swift` | Supabase project URL and anon key, `AppConfig` flags |
| `swastricare-mobile-swift/DesignSystem.swift` | `AppColors`, `PremiumColor`, gradients, shared UI components |
| `swastricare-mobile-swift/Helpers/DeepLinkHandler.swift` | URL scheme routing for widgets + family invites |

### Android

| File | Role |
|------|------|
| `android/.../di/AppContainer.kt` | DI singleton — Supabase client, services, repositories, ViewModels |
| `android/.../MainActivity.kt` | Entry point, Compose host |
| `android/.../navigation/AppNavigation.kt` | Jetpack Compose navigation graph |
| `android/.../data/SupabaseConfig.kt` | Supabase credentials |
| `android/.../data/services/SessionManager.kt` | Auth token management + expiry detection |

## Design System (iOS)

Use `AppColors` for semantic colors (e.g., `AppColors.accentBlue`, `AppColors.heartRate`) and `PremiumColor` for gradients. Color hex values are extended via `Color(hex:)`. All screens should use these — never hardcode raw colors.

## Backend (Supabase)

- **Migrations**: `supabase/migrations/` — 30 SQL files, all tables use RLS
- **Edge Functions**: `supabase/functions/` — 10 Deno/TypeScript functions + `_shared/` utilities
- **Universal FK**: All health data connects via `health_profile_id` foreign key
- **Family access**: Controlled by `has_family_access(profile_id, permission)` SQL function
- **AI routing**: `ai-router` edge function auto-routes to Gemini Flash (general), MedGemma 27B (medical keywords), or MedGemma 4B (image analysis), with fallback
- **Health data sync**: iOS uses HealthKit, Android uses Health Connect — both sync bidirectionally with Supabase

## Widgets (iOS)

`SwasthiCareWidgets/` contains 6 widgets (Hydration, Medication, Steps, Run, Workout Live Activity, Health Live Activity). Data is shared between app and widgets via `WidgetDataManager` using shared `UserDefaults` (app group `group.com.swasthicare.shared`). Widget intents use `AppIntents` framework.

## Deep Links

Primary scheme is `swastricareapp://` (also used for OAuth redirect). Legacy schemes `swasthicare://` and `swastricare://` are also supported. Routes: `home`, `hydration`, `medications`, `heartRate`, `steps`, `run`, `activeWorkout`, `startRun/{type}`, `family/join?code=`, `workout/live`, `health/live`. Processed by `DeepLinkHandler`.

## Important Patterns

- All ViewModels and `DependencyContainer` are `@MainActor` — maintain this for any new iOS ViewModels
- iOS services follow the `XxxServiceProtocol` + `XxxService.shared` singleton pattern
- `SupabaseManager.shared.client` is the Supabase client — all iOS DB calls go through `SupabaseManager`
- Workout crash recovery: `WorkoutStateManager` auto-saves every 10s; `WorkoutLifecycleHandler` detects abandoned workouts on next launch (both platforms)
- Camera heart rate uses custom PPG signal processing (`PPGSignalProcessor`, `HeartRateDetector`, `SignalValidator`) on both platforms
- `NotificationService` manages all push notification categories (hydration, medication, diet, menstrual) on both platforms
- `AppConfig.isTestingMode` controls whether onboarding is shown every launch (set `false` for production)
- Android uses Encrypted SharedPreferences for sensitive data with automatic fallback migration
