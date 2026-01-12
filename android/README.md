# SwasthiCare Android App

## Overview
SwasthiCare is a health companion app built with Kotlin and Jetpack Compose.

## Tech Stack
- **Language**: Kotlin
- **UI Framework**: Jetpack Compose
- **Architecture**: MVVM (Model-View-ViewModel)
- **Backend**: Supabase
- **Minimum SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)

## Project Structure
```
app/
├── src/main/
│   ├── kotlin/com/swasthicare/mobile/
│   │   ├── ui/
│   │   │   ├── screens/        # App screens
│   │   │   ├── theme/          # App theme & colors
│   │   │   └── navigation/     # Navigation setup
│   │   ├── MainActivity.kt
│   │   └── SwasthiCareApplication.kt
│   ├── res/                    # Resources
│   └── AndroidManifest.xml
└── build.gradle.kts
```

## Setup Instructions

### Prerequisites
- Android Studio Hedgehog or later
- JDK 17 or later
- Gradle 8.2 or later

### Build & Run
1. Open project in Android Studio
2. Sync Gradle files
3. Run on emulator or physical device

### Build Commands
```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease

# Run tests
./gradlew test
```

## Features (Planned)
- User authentication
- Health tracking
- Medication reminders
- Doctor appointments
- Health records
- Analytics dashboard

## Contributing
Please follow Kotlin coding conventions and use ktlint for formatting.
