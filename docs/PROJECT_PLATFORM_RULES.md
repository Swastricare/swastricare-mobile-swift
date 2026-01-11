# Project Platform Rules & Guidelines

## Overview

SwasthiCare is a **dual-platform mobile application** with separate codebases:
- **iOS**: Swift + SwiftUI (Primary focus)
- **Android**: Kotlin + Jetpack Compose (Secondary implementation)

This document establishes clear rules to ensure changes are applied to the correct platform.

---

## Platform Identification Rules

### 1. Always Clarify Platform Intent

**RULE**: When requesting changes, always specify the target platform explicitly.

#### Good Examples:
- "Change dark mode colors in Android"
- "Add medication reminder to iOS app"
- "Update Swift authentication flow"
- "Fix Kotlin navigation issue"
- "Implement heart rate detection on iOS only"

#### Bad Examples (Ambiguous):
- ❌ "Change dark mode" → Which platform?
- ❌ "Add new screen" → iOS, Android, or both?
- ❌ "Update theme colors" → Swift or Kotlin?

### 2. Platform Keywords

Use these keywords to clearly indicate platform:

| Platform | Keywords |
|----------|----------|
| **iOS** | Swift, SwiftUI, iOS, Xcode, iPhone, iPad, .swift files |
| **Android** | Kotlin, Android, Jetpack Compose, .kt files, Gradle |
| **Both** | "both platforms", "cross-platform", "iOS and Android" |

---

## Project Structure Reference

### iOS/Swift Files Location
```
swastricare-mobile-swift/
├── ContentView.swift
├── SwasthiCareApp.swift
└── [Other .swift files]
```

### Android/Kotlin Files Location
```
android/
└── app/src/main/kotlin/com/swasthicare/mobile/
    ├── MainActivity.kt
    ├── SwasthiCareApplication.kt
    └── ui/
```

---

## Decision Flowchart

When making changes, follow this decision process:

```
┌─────────────────────────────┐
│ Change Request Received      │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Is platform specified?       │
└──────────┬──────────────────┘
           │
     ┌─────┴─────┐
     │           │
    YES          NO
     │           │
     │           ▼
     │     ┌──────────────────┐
     │     │ ASK USER:         │
     │     │ Which platform?   │
     │     │ - iOS (Swift)     │
     │     │ - Android (Kotlin)│
     │     │ - Both            │
     │     └──────────────────┘
     │
     ▼
┌─────────────────────────────┐
│ Check file extensions:       │
│ .swift → iOS                │
│ .kt → Android               │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Apply changes to correct     │
│ platform codebase only       │
└─────────────────────────────┘
```

---

## Common Scenarios

### Scenario 1: UI/Theme Changes
**Request**: "Change dark mode colors"

**Action Required**:
1. Ask: "Which platform - iOS (Swift) or Android (Kotlin)?"
2. iOS → Modify Swift color schemes
3. Android → Modify Kotlin `Color.kt` and theme files

### Scenario 2: New Feature Implementation
**Request**: "Add medication reminder"

**Action Required**:
1. Ask: "Should this be implemented on iOS, Android, or both?"
2. Clarify implementation timeline if both platforms
3. Implement separately for each platform with platform-specific code

### Scenario 3: Bug Fixes
**Request**: "Fix navigation issue"

**Action Required**:
1. Identify which platform has the bug
2. Check file path/extension to confirm platform
3. Apply fix only to affected platform

### Scenario 4: Database/Backend Changes
**Request**: "Update Supabase schema"

**Action**: This affects **both platforms** as backend is shared
- Update database schema
- Update both iOS and Android clients if needed

---

## Platform-Specific Features

### iOS-Only Features
- Apple Sign-In integration
- HealthKit integration
- iOS Widgets (SwasthiCareWidgets)
- Heart Rate detection via HealthKit

### Android-Only Features
- Google Play Services integration
- Android-specific permissions handling
- Material3 theming system

### Shared Features (Both Platforms)
- Supabase authentication
- Database schema
- Core business logic
- API endpoints

---

## File Extension Quick Reference

| Extension | Platform | Language |
|-----------|----------|----------|
| `.swift` | iOS | Swift |
| `.kt` | Android | Kotlin |
| `.xml` | Android | Resources/Manifest |
| `.gradle.kts` | Android | Build config |
| `.xcodeproj` | iOS | Xcode project |
| `.entitlements` | iOS | Capabilities |

---

## Best Practices

### ✅ DO:
- Explicitly state platform in every request
- Verify file paths before making changes
- Consider cross-platform implications for backend changes
- Document platform-specific implementations separately

### ❌ DON'T:
- Assume platform without confirmation
- Apply iOS changes to Android code (or vice versa)
- Mix Swift and Kotlin syntax
- Ignore platform-specific design guidelines

---

## Example Conversations

### Example 1: Clear Intent
**User**: "Update the splash screen background color to #FF6584 in Android"

**Response**: ✅ Clear - Will modify `android/app/src/main/kotlin/.../Color.kt`

### Example 2: Ambiguous Intent
**User**: "Change the primary button color"

**Response**: ⚠️ Ambiguous - "Which platform would you like to update - iOS (Swift), Android (Kotlin), or both?"

### Example 3: Both Platforms
**User**: "Add email validation to authentication on both platforms"

**Response**: ✅ Clear - Will implement in both Swift and Kotlin codebases

---

## Quick Platform Check Command

When in doubt, use these commands to identify current context:

```bash
# Check if in iOS workspace
ls *.swift

# Check if in Android workspace
ls android/app/src/main/kotlin/

# See both platforms
ls -la
```

---

## Summary

**Golden Rule**: **When in doubt, always ask which platform!**

This prevents:
- ❌ Wasted effort on wrong platform
- ❌ Breaking one platform while fixing another
- ❌ Confusion in codebase
- ❌ Merge conflicts and errors

Always confirm platform before proceeding with any implementation.
