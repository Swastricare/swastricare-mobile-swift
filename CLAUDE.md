# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwasthiCare is a personal health management iOS app targeting an Indian audience. It tracks hydration, medications, vitals, activity, diet, and menstrual cycles. It supports both self-care and family caregiving via role-based family groups. The backend is Supabase (Auth, Postgres, Storage, Edge Functions). An Android companion app exists in `android/`.

## Dual-Platform Codebase

This repository contains both **iOS (Swift/SwiftUI)** and **Android (Kotlin/Jetpack Compose)** codebases. When a request is ambiguous about platform, clarify before making changes. iOS source is in the root; Android is in `android/`.

## Build Commands

```bash
# Build the iOS app (Debug)
xcodebuild -scheme swastricare-mobile-swift -configuration Debug build

# Build the widget extension
xcodebuild -scheme SwasthiCareWidgetsExtension -configuration Debug build

# Build for simulator (useful for quick validation)
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build

# Supabase: apply migrations locally
supabase db push

# Supabase: serve edge functions locally
supabase functions serve
```

There are no unit tests, linter, or formatter configured in this project.

## Architecture: MVVM + Protocol-Oriented DI

### Dependency Injection Pattern

`DependencyContainer` (`Core/DependencyContainer.swift`) is the single `@MainActor` singleton that owns all services and ViewModels:

- **Services** are protocol-typed singletons (`AuthServiceProtocol`, `HealthKitServiceProtocol`, etc.) initialized eagerly in `DependencyContainer.init()`
- **ViewModels** are `lazy var` properties on the container, injected into Views via `@StateObject private var vm = DependencyContainer.shared.someViewModel`
- The container is also available via SwiftUI environment: `.withDependencies()` modifier applied at root, accessed with `@Environment(\.dependencies)`

When adding a new feature:
1. Define a service protocol in `Services/`
2. Implement the service as a singleton (`static let shared`)
3. Add the protocol-typed property to `DependencyContainer`
4. Add a lazy ViewModel property to `DependencyContainer`
5. Create the View using `@StateObject` from the container

### Navigation State Machine

`swastricare_mobile_swiftApp.swift` implements a linear navigation state machine:
```
Splash → ForceUpdate? → Onboarding → Consent → Login → HealthProfileQuestionnaire → BiometricLock? → ContentView (5 tabs)
```

State is tracked via `@State` booleans (`hasCompletedOnboarding`, `hasAcceptedConsent`, `hasCompletedHealthProfile`, etc.) with auth state from `AuthViewModel`.

### Tab Structure (ContentView)

5 tabs: **Vitals** (HomeView) → **Vault** (VaultView) → **AI** (AIView, center) → **Steps** (RunActivityView) → **Profile** (ProfileView). Each tab wraps its content in a `NavigationStack`.

## Key Architectural Files

| File | Role |
|------|------|
| `Core/DependencyContainer.swift` | All DI — services + ViewModels |
| `App/swastricare_mobile_swiftApp.swift` | Entry point, navigation state machine, Firebase init |
| `SupabaseManager.swift` | All Supabase DB/Storage/Auth operations (77KB, central data layer) |
| `Config.swift` | Supabase project URL and anon key, `AppConfig` flags |
| `DesignSystem.swift` | `AppColors`, `PremiumColor`, gradients, shared UI components |
| `Helpers/DeepLinkHandler.swift` | URL scheme routing (`swastricare://`) for widgets + family invites |

## Design System

Use `AppColors` for semantic colors (e.g., `AppColors.accentBlue`, `AppColors.heartRate`) and `PremiumColor` for gradients. Color hex values are extended via `Color(hex:)`. All screens should use these — never hardcode raw colors.

## Backend (Supabase)

- **Migrations**: `supabase/migrations/` — 26 SQL files, all tables use RLS
- **Edge Functions**: `supabase/functions/` — 9 Deno/TypeScript functions
- **Universal FK**: All health data connects via `health_profile_id` foreign key
- **Family access**: Controlled by `has_family_access(profile_id, permission)` SQL function
- **AI routing**: `ai-router` edge function auto-routes to Gemini Flash (general), MedGemma 27B (medical keywords), or MedGemma 4B (image analysis), with fallback

## Widgets

`SwasthiCareWidgets/` contains 6 widgets (Hydration, Medication, Steps, Run, Workout Live Activity, Health Live Activity). Data is shared between app and widgets via `WidgetDataManager` using shared `UserDefaults` (app group). Widget intents use `AppIntents` framework.

## Deep Links

URL scheme `swastricare://` handles: `home`, `hydration`, `medications`, `heartRate`, `steps`, `run`, `activeWorkout`, `startRun/{type}`, `family/join?code=`. Processed by `DeepLinkHandler`.

## Important Patterns

- All ViewModels and `DependencyContainer` are `@MainActor` — maintain this for any new ViewModels
- Services follow the `XxxServiceProtocol` + `XxxService.shared` singleton pattern
- `SupabaseManager.shared.client` is the Supabase client — all DB calls go through `SupabaseManager`
- Health data syncs bidirectionally: HealthKit ↔ App ↔ Supabase
- Workout crash recovery: `WorkoutStateManager` auto-saves every 10s; `WorkoutLifecycleHandler` detects abandoned workouts on next launch
- Camera heart rate uses custom PPG signal processing (`PPGSignalProcessor`, `HeartRateDetector`, `SignalValidator`)
- `NotificationService` (62KB) manages all push notification categories (hydration, medication, diet, menstrual)
- `AppConfig.isTestingMode` controls whether onboarding is shown every launch (set `false` for production)
