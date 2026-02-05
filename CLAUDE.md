# CLAUDE.md - SwasthiCare Mobile App

## Project Overview

SwasthiCare is a cross-platform health management mobile application with native implementations for iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose), backed by Supabase (PostgreSQL + Edge Functions). The iOS codebase is the primary platform.

**Purpose**: Comprehensive health tracking — medications, hydration, heart rate (PPG camera detection), vital signs, medical document vault, AI health analysis (Gemini/MedGemma), and telemedicine.

## Repository Structure

```
/
├── swastricare-mobile-swift/          # iOS app source (~42k lines Swift)
│   ├── App/                           # App entry point (SwiftUI @main)
│   ├── Views/                         # SwiftUI views (16 subdirectories)
│   │   ├── Main/ContentView.swift     # Tab-based main navigation
│   │   ├── Auth/                      # Login, consent
│   │   ├── Onboarding/               # Multi-step onboarding + graphics
│   │   ├── Home/                      # Dashboard, hydration, medications
│   │   ├── HeartRate/                 # PPG heart rate detection
│   │   ├── AI/                        # AI chat + medical disclaimer
│   │   ├── Vault/                     # Medical document storage
│   │   ├── Tracker/                   # Health metrics tracking
│   │   ├── Settings/                  # App settings
│   │   ├── Profile/                   # User profile
│   │   ├── Lock/                      # Biometric lock screen
│   │   ├── Splash/                    # Splash screen
│   │   └── Components/               # Reusable UI components
│   ├── ViewModels/                    # MVVM state management (12 files)
│   ├── Services/                      # Business logic layer (19 files)
│   ├── Models/                        # Codable data models (11 files)
│   ├── Core/DependencyContainer.swift # Singleton DI container
│   ├── Utils/                         # Helpers (DeviceModel, MedicalSafety)
│   ├── DesignSystem.swift             # Design tokens, glass effects, colors
│   ├── SupabaseManager.swift          # Backend client (1,482 LOC)
│   ├── HealthManager.swift            # HealthKit data management
│   ├── SpeechManager.swift            # Speech recognition
│   ├── Config.swift                   # Supabase URL + keys, app config
│   └── Assets.xcassets/               # Image assets
├── SwasthiCareWidgets/                # iOS widget extension
│   ├── HydrationWidget/              # Hydration tracking widget
│   ├── MedicationWidget/             # Medication reminder widget
│   └── Shared/WidgetDataManager.swift # Shared data via App Groups
├── android/                           # Android app (Kotlin, 41 files)
│   └── app/src/main/kotlin/com/swasthicare/mobile/
├── supabase/                          # Backend
│   ├── migrations/                    # 21 PostgreSQL migrations
│   └── functions/                     # 8 TypeScript Edge Functions (Deno)
├── docs/                              # 19 documentation files
├── swastricare-mobile-swift.xcodeproj/ # Xcode project (not SPM)
└── Config.swift                       # Root-level config copy
```

## Architecture

**Pattern**: MVVM (Model-View-ViewModel) with dependency injection.

- **Views** — SwiftUI declarative views. No UIKit except for specific integrations (camera, blur effects).
- **ViewModels** — `@StateObject`/`@ObservedObject` state management. Each major feature has its own ViewModel.
- **Services** — Business logic, API calls, data processing. Services use protocol abstractions (e.g., `AuthServiceProtocol`, `HealthKitServiceProtocol`).
- **Models** — `Codable` structs for data serialization.
- **DependencyContainer** — Singleton (`DependencyContainer.shared`) that initializes all services and provides lazy ViewModels. Injected via SwiftUI `@Environment`.

### Dependency Injection Pattern

```swift
// Services are protocol-based singletons
let authService: AuthServiceProtocol = AuthService.shared

// ViewModels are lazy-initialized from the container
lazy var authViewModel: AuthViewModel = AuthViewModel(authService: authService)

// Injected into SwiftUI view hierarchy
ContentView().withDependencies()

// Access in views via environment
@Environment(\.dependencies) var dependencies
```

### Navigation Flow

App entry point: `swastricare_mobile_swiftApp.swift` → sequential gates:
1. `SplashView` (version check + auth resolution)
2. `ForceUpdateView` (if update required)
3. `OnboardingView` (first-time users)
4. `ConsentView` (terms acceptance)
5. `LoginView` (authentication)
6. `OneQuestionPerScreenOnboardingView` (health profile)
7. `LockScreenView` (biometric unlock)
8. `ContentView` (main tab bar)

Main tabs: **Vitals** | **Vault** | **AI** | **Family** | **Profile**

## Build & Run

### iOS

- **IDE**: Xcode
- **Project file**: `swastricare-mobile-swift.xcodeproj` (not workspace/SPM)
- **Deployment target**: iOS 17.0
- **Swift version**: 5.0
- **Bundle ID**: `com.swastricare.health`
- **URL scheme**: `swastricareapp://`
- **App Groups**: `group.com.swasthicare.shared`

Open in Xcode:
```bash
open swastricare-mobile-swift.xcodeproj
```

Dependencies are managed via Xcode's Swift Package Manager integration (added through File > Add Package Dependencies). The primary dependency is `supabase-swift`.

### Android

- **Build tool**: Gradle 8.2.0
- **Language**: Kotlin 1.9.20
- **Min SDK**: 24 (Android 7.0) / **Target SDK**: 34
- **Namespace**: `com.swasthicare.mobile`

```bash
cd android && ./gradlew assembleDebug
```

### Supabase Backend

```bash
# Local development
supabase start          # Starts local Supabase (PostgreSQL on 54322, API on 54321)
supabase db reset       # Runs all migrations
supabase functions serve # Runs Edge Functions locally
```

## Code Conventions

### Swift Style

- **MARK comments** for section organization: `// MARK: - Section Name`
- **File headers** include file name, project name, and optional description
- **Protocol-based services**: Every service has a corresponding protocol (e.g., `AuthServiceProtocol`)
- **Singleton pattern**: Services use `static let shared` instances
- **`@MainActor`**: Used on classes that interact with UI state (e.g., `DependencyContainer`)
- **Async/await**: Preferred over Combine for async operations; `Task {}` blocks for launching async work from synchronous contexts
- **Print logging**: Uses emoji prefixes for log categories (e.g., `🔐` auth, `📋` health, `🔔` notifications, `🔗` deep links)

### Design System

Defined in `DesignSystem.swift`:
- **`PremiumColor`** struct: Static gradient definitions (`royalBlue`, `sunset`, `neonGreen`, `deepPurple`, `midnight`)
- **`Color(hex:)`** extension: Hex color initialization
- **`.glass()`** modifier: Liquid glass / frosted material effect (uses `.ultraThinMaterial`)
- **`.liquidGlassCapsule()`**, **`.liquidGlassCircle()`**: Shape-specific glass effects
- **`PremiumBackground`**: Animated gradient orbs background (dark/light mode aware)
- **`HeroHeader`**: Reusable page header component
- **`ScaleButtonStyle`**, **`LiquidGlassButtonStyle`**: Custom button styles

### Naming Conventions

- **Views**: `<Feature>View.swift` (e.g., `HomeView.swift`, `VaultView.swift`)
- **ViewModels**: `<Feature>ViewModel.swift` (e.g., `HomeViewModel.swift`)
- **Services**: `<Feature>Service.swift` (e.g., `HydrationService.swift`)
- **Models**: `<Domain>Models.swift` (e.g., `HealthModels.swift`, `MedicationModels.swift`)
- **Widgets**: `<Feature>Widget/` directory with `View`, `Entry`, `Provider` files

### Platform Rules

See `docs/PROJECT_PLATFORM_RULES.md`. Key rule: **always specify target platform** (iOS/Android/both) when making changes. File extensions identify platform: `.swift` = iOS, `.kt` = Android.

## Key Technical Details

### Entitlements & Permissions

The app requires extensive permissions (declared in `.entitlements` and `PrivacyInfo.plist`):
- **HealthKit** (read/write)
- **Camera** (heart rate PPG, document scanning)
- **Microphone + Speech Recognition** (AI voice assistant)
- **Face ID / Touch ID** (biometric lock)
- **Photo Library** (vault uploads)
- **Location** (weather-based hydration)
- **Push Notifications** (medication/hydration reminders)
- **Apple Sign-In**
- **App Groups** (widget data sharing)

### Backend (Supabase)

- **Database**: PostgreSQL 17 with 21 migration files covering users, medications, health metrics, medical records, AI interactions, telemedicine, wearables, insurance, and more
- **Auth**: Supabase Auth with Apple Sign-In (iOS) and Google Sign-In (Android)
- **Edge Functions**: TypeScript on Deno runtime — AI routing (`ai-router`), chat, health analysis, image analysis, text generation, MedGemma integration, hydration reminders
- **Storage**: Document/image storage for the medical vault

### AI Integration

- **Google Gemini**: General health chat and text generation
- **MedGemma**: Specialized medical AI for chat and vision (image analysis)
- **Routing**: `ai-router` Edge Function dispatches to appropriate AI model
- **Safety**: `MedicalSafetyUtils.swift` and `MedicalDisclaimerView.swift` enforce medical disclaimers

### Heart Rate Detection

Camera-based PPG (photoplethysmography) implemented in:
- `HeartRateDetector.swift` — Signal capture from camera
- `PPGSignalProcessor.swift` — Signal processing pipeline
- `SignalValidator.swift` — Quality validation
- `HeartRateViewModel.swift` — State management for the detection flow

## Testing

**No automated test suite exists.** There are no XCTest targets, no unit tests, and no CI/CD pipelines. Testing is manual.

`AppConfig.isTestingMode` (in `Config.swift`) controls whether onboarding is shown repeatedly during development — currently set to `true`.

## Important Files for Quick Reference

| Purpose | File |
|---------|------|
| App entry point | `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift` |
| Main tab navigation | `swastricare-mobile-swift/Views/Main/ContentView.swift` |
| DI container | `swastricare-mobile-swift/Core/DependencyContainer.swift` |
| Design system | `swastricare-mobile-swift/DesignSystem.swift` |
| Supabase client | `swastricare-mobile-swift/SupabaseManager.swift` |
| App config/keys | `swastricare-mobile-swift/Config.swift` |
| Database migrations | `supabase/migrations/` |
| Edge Functions | `supabase/functions/` |
| Platform rules | `docs/PROJECT_PLATFORM_RULES.md` |
| Database schema docs | `docs/database/swastricare_database_schema.md` |

## Common Tasks

### Adding a new feature (iOS)

1. Create model in `Models/<Feature>Models.swift`
2. Create service with protocol in `Services/<Feature>Service.swift`
3. Register service in `DependencyContainer.swift`
4. Create ViewModel in `ViewModels/<Feature>ViewModel.swift`
5. Create view in `Views/<Feature>/<Feature>View.swift`
6. Wire ViewModel into DependencyContainer as lazy property
7. Add navigation entry in `ContentView.swift` or parent view

### Adding a database table

1. Create migration in `supabase/migrations/` with timestamp prefix (format: `YYYYMMDDHHMMSS_description.sql`)
2. Include RLS policies in the migration
3. Update `SupabaseManager.swift` with query methods
4. Add corresponding `Codable` models in iOS and/or Android

### Adding an Edge Function

1. Create directory `supabase/functions/<function-name>/`
2. Add `index.ts` with Deno-compatible TypeScript
3. Deploy with `supabase functions deploy <function-name>`
4. Call from iOS via `SupabaseManager.invokeFunction(name:payload:)`
