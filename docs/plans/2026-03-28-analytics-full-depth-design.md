# Analytics Full-Depth Design
**Date:** 2026-03-28
**Scope:** iOS (Swift/SwiftUI) + Android (Kotlin/Jetpack Compose) + Supabase `app_events` table
**Level:** C — Screen views + feature actions + dwell time + session duration

---

## Section 1: Database & Service Layer

### Database
All events append to the existing `app_events` table. One migration adds:
- `platform VARCHAR(20)` column — reliable iOS/Android split (Android service already sends this value but the column doesn't exist yet)

No new tables. The `properties` JSONB column carries all event-specific payload.

### iOS: AppAnalyticsService
Singleton at `Services/AppAnalyticsService.swift`. Existing infrastructure (offline queue, batch flush, retry) is retained. Additions:
- Send `platform: "ios"` in `deviceInfo` on every event
- Add `logScreen(name:, durationSeconds:)` method
- Add `logSessionEnd(durationSeconds:)` method
- Add feature event helpers for Diet, Cycle, Family, Settings, AR

### Android: AppAnalyticsService
Singleton at `data/services/AppAnalyticsService.kt`. `AppEventRow` already sends `platform: "android"`. Additions:
- Add `trackScreen(name, durationSeconds)` method
- Add feature event helpers for Diet, Cycle, Family, Settings, Health Connect

---

## Section 2: Screen Tracking Pattern

### Approach
**Single enriched `screen_view` event on screen exit** with `duration_seconds` computed client-side. No enter/exit pairs. No separate tables.

### iOS: View+ScreenTracking.swift (new file)
```swift
struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    @State private var enteredAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear { enteredAt = Date() }
            .onDisappear {
                let duration = enteredAt.map { Date().timeIntervalSince($0) } ?? 0
                AppAnalyticsService.shared.logScreen(screenName, durationSeconds: Int(duration))
                enteredAt = nil
            }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(screenName: name))
    }
}
```

Usage: `.trackScreen("Hydration")` on the outermost `NavigationView` or `ZStack` of each screen.

### Android: ScreenTracking.kt (new file)
```kotlin
@Composable
fun TrackScreen(name: String, analyticsService: AppAnalyticsService) {
    val enteredAt = remember { System.currentTimeMillis() }
    DisposableEffect(name) {
        onDispose {
            val duration = ((System.currentTimeMillis() - enteredAt) / 1000).toInt()
            analyticsService.trackScreen(name, duration)
        }
    }
}
```

Usage: `TrackScreen("Hydration", analyticsService)` at the top of each Composable screen.

### Session Tracking

**iOS:** In the App struct, `.onChange(of: scenePhase)` → when `.background`, call `AppAnalyticsService.shared.logSessionEnd()` + `flushNow()`. Session start time stored as `sessionStartTime: Date` on the service.

**Android:** `AppAnalyticsService` implements `DefaultLifecycleObserver`. `onStop` computes `(System.currentTimeMillis() - sessionStartTime) / 1000` and calls `trackSessionEnd(duration)`.

### Rule
Only full screens and modal sheets are tracked. Sub-components (cards, cells, list rows) are not tracked.

### Canonical Screen Names
All 82 iOS views and 89 Android screens receive canonical names:
- `Home`, `Hydration`, `AddHydration`, `Medication`, `MedicationDetail`, `AddMedication`
- `Diet`, `FoodSearch`, `AddFood`, `FoodDetail`
- `Workout`, `WorkoutActive`, `WorkoutSummary`, `RunActivity`, `RunActive`
- `AI`, `AIChat`, `Vault`, `VaultDetail`, `AddVault`
- `HeartRate`, `HeartRateScan`, `Steps`
- `Profile`, `Settings`, `NotificationSettings`, `FamilyGroup`, `FamilyMemberDetail`
- `Login`, `Signup`, `Onboarding`, `HealthProfileQuestionnaire`, `BiometricLock`
- `ARBodyScan`, `CycleTracker`, `AddCycleEntry`, `CyclePrediction`

---

## Section 3: Feature Events Inventory

All events use `event_type: 'feature_usage'`. Payloads go into `properties` JSONB.

### Diet
| Event | Trigger | Properties |
|---|---|---|
| `food_searched` | Search executed | `query_length`, `results_count` |
| `food_added` | Meal item logged | `meal_type`, `calories`, `is_custom` |
| `food_deleted` | Item removed | `meal_type` |
| `meal_copied` | "Copy yesterday" tapped | — |
| `calorie_goal_reached` | Daily goal hit | `goal_kcal`, `actual_kcal` |

### Menstrual Cycle
| Event | Trigger | Properties |
|---|---|---|
| `cycle_logged` | Period start/end saved | `entry_type` (start/end) |
| `symptom_logged` | Symptom added | `symptom_type` |
| `cycle_prediction_viewed` | Prediction card tapped | — |

### Family
| Event | Trigger | Properties |
|---|---|---|
| `family_created` | New group created | — |
| `family_joined` | Joined via invite code | — |
| `family_member_viewed` | Member dashboard tapped | — |
| `family_invite_sent` | Invite sent | — |

### Settings
| Event | Trigger | Properties |
|---|---|---|
| `notification_toggled` | Push setting changed | `type`, `enabled` |
| `profile_updated` | Profile saved | `fields_changed` |
| `healthkit_toggled` | iOS: HealthKit permission | `enabled` |
| `health_connect_toggled` | Android: Health Connect | `enabled` |

### AR Body Scan (iOS only)
| Event | Trigger | Properties |
|---|---|---|
| `ar_launched` | Body scan opened | — |
| `ar_scan_completed` | Scan finished | `duration_seconds` |

### Notifications
| Event | Trigger | Properties |
|---|---|---|
| `notification_tapped` | App opened from notification | `notification_type` |

---

## Implementation Order

1. **DB migration** — add `platform` column
2. **iOS service** — add `logScreen`, `logSessionEnd`, new feature helpers; send `platform: "ios"`
3. **Android service** — add `trackScreen`, `trackSessionEnd`, new feature helpers
4. **iOS screen tracking** — create `View+ScreenTracking.swift`; add `.trackScreen()` to all 82 views
5. **Android screen tracking** — create `ScreenTracking.kt`; add `TrackScreen()` to all 89 screens
6. **iOS feature events** — add calls for Diet, Cycle, Family, Settings, AR, Notifications
7. **Android feature events** — add calls for Diet, Cycle, Family, Settings, Health Connect, Notifications
8. **Dashboard** — deferred until app-side complete
