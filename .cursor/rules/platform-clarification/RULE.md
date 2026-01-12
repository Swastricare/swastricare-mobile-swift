---
description: "Ensures platform clarity when working with SwasthiCare dual-platform codebase (iOS/Swift vs Android/Kotlin)"
alwaysApply: true
---

# Platform Clarification Rule

## Context
SwasthiCare is a dual-platform mobile application:
- **iOS**: Swift + SwiftUI (in root directory)
- **Android**: Kotlin + Jetpack Compose (in `android/` directory)

## Core Rules

### 1. Always Identify Platform Intent
Before making ANY changes, explicitly confirm which platform is targeted:
- iOS/Swift
- Android/Kotlin  
- Both platforms

### 2. Platform Detection by File Extension
- `.swift` files = iOS/Swift codebase
- `.kt` files = Android/Kotlin codebase
- `.xml` (in android/) = Android resources
- `.gradle.kts` = Android build config

### 3. When User Request is Ambiguous
If the user's request doesn't specify platform (e.g., "change dark mode", "add new screen", "update theme"), IMMEDIATELY ask:

> "Which platform would you like to update - iOS (Swift), Android (Kotlin), or both?"

### 4. Platform-Specific Keywords
- **iOS indicators**: Swift, SwiftUI, Xcode, HealthKit, Apple Sign-In, .swift
- **Android indicators**: Kotlin, Jetpack Compose, Gradle, Material3, .kt
- **Both**: "both platforms", "cross-platform", Supabase, database schema

### 5. Confirm Before Implementing
When user says something like:
- "Change colors" → Ask which platform
- "Add authentication" → Ask which platform
- "Fix navigation bug" → Ask which platform
- "Update Supabase schema" → Note this affects both platforms

### 6. Clear Communication
When implementing changes, always state:
- "Updating iOS/Swift code..."
- "Modifying Android/Kotlin files..."
- "This affects both platforms because..."

## Examples

### ✅ Good (Clear Intent)
- "Update splash screen in Android"
- "Add HealthKit integration to iOS app"
- "Change Kotlin theme colors"
- "Fix Swift navigation issue"

### ❌ Bad (Ambiguous - Requires Clarification)
- "Change the primary color" → Which platform?
- "Add new screen" → iOS, Android, or both?
- "Update authentication" → Which codebase?

## File Structure Reference

**iOS/Swift Location:**
```
/swastricare-mobile-swift/
├── *.swift files
├── SwasthiCareWidgets/
└── *.xcodeproj
```

**Android/Kotlin Location:**
```
/android/
└── app/src/main/kotlin/com/swasthicare/mobile/
```

## Action Items
1. ✅ Check if platform is specified in user request
2. ❌ If not specified → Ask user immediately
3. ✅ Once confirmed → Apply changes to correct platform only
4. ✅ State which platform you're modifying in your response

See full documentation: `docs/PROJECT_PLATFORM_RULES.md`
