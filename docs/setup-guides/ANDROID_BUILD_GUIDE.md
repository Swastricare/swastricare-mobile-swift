# Android Build & Implementation Guide

This guide details the step-by-step process to recreate the SwasthiCare Android application from scratch. It documents the environment setup, project configuration, and implementation of the current codebase state.

## 1. Prerequisites

Before starting, ensure your development environment meets the following requirements:

*   **IDE**: Android Studio Hedgehog (2023.1.1) or later
*   **Java Development Kit (JDK)**: Version 17 or later
*   **Gradle**: Version 8.2 or later
*   **Kotlin**: Version 1.9.20
*   **System**: 
    *   Minimum 8GB RAM (16GB recommended)
    *   Minimum 4GB free disk space

## 2. Project Creation

1.  Open Android Studio and select **New Project**.
2.  Choose **Phone and Tablet** template: **Empty Activity** (Compose).
3.  Configure the project details:
    *   **Name**: `SwasthiCare`
    *   **Package Name**: `com.swasthicare.mobile`
    *   **Save Location**: `[Your/Project/Path]/android`
    *   **Language**: Kotlin
    *   **Minimum SDK**: API 24 (Android 7.0 "Nougat")
    *   **Build Configuration Language**: Kotlin DSL (`build.gradle.kts`)
4.  Click **Finish** and wait for the initial Gradle sync to complete.

## 3. Gradle Configuration

### Root Build Configuration
File: `android/build.gradle.kts`

Set up the build script repositories and dependencies for the project level.

```kotlin
// Top-level build file
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

### App Module Configuration
File: `android/app/build.gradle.kts`

Configure the application module, including plugins, Android settings, and dependencies.

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.swasthicare.mobile"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.swasthicare.mobile"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.4"
    }
}

dependencies {
    // Core Android
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.navigation:navigation-compose:2.7.6")

    // Supabase
    implementation("io.github.jan-tennert.supabase:postgrest-kt:2.6.0")
    implementation("io.github.jan-tennert.supabase:gotrue-kt:2.6.0")
    implementation("io.github.jan-tennert.supabase:realtime-kt:2.6.0")
    implementation("io.ktor:ktor-client-android:2.3.7")
    implementation("io.ktor:ktor-client-core:2.3.7")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.01.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
```

### Settings Configuration
File: `android/settings.gradle.kts`

```kotlin
rootProject.name = "SwasthiCare"
include(":app")
```

### Gradle Properties
File: `android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
kotlin.code.style=official
```

## 4. Project Structure Setup

Create the following package structure under `app/src/main/kotlin/com/swasthicare/mobile/`:

```
com/swasthicare/mobile/
├── MainActivity.kt
├── SwasthiCareApplication.kt
└── ui/
    ├── navigation/
    │   └── AppNavigation.kt
    ├── screens/
    │   ├── home/
    │   │   └── HomeScreen.kt
    │   └── splash/
    │   │   └── SplashScreen.kt
    └── theme/
        ├── Color.kt
        ├── Theme.kt
        └── Type.kt
```

## 5. Theme Implementation

Implement the application theme using Material3.

### Colors
File: `ui/theme/Color.kt`

Define the brand colors and theme palette.

```kotlin
package com.swasthicare.mobile.ui.theme

import androidx.compose.ui.graphics.Color

// Brand Colors
val PrimaryColor = Color(0xFF6C63FF)
val SecondaryColor = Color(0xFF00D4AA)
val AccentColor = Color(0xFFFF6584)

// Background Colors
val BackgroundLight = Color(0xFFFAFAFA)
val BackgroundDark = Color(0xFF121212)

// Surface Colors
val SurfaceLight = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF1E1E1E)

// Text Colors
val TextPrimary = Color(0xFF2D3748)
val TextSecondary = Color(0xFF718096)
```

### Typography
File: `ui/theme/Type.kt`

Configure the typography styles.

```kotlin
package com.swasthicare.mobile.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val Typography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
)
```

### Theme Composable
File: `ui/theme/Theme.kt`

Create the main theme wrapper that handles light/dark mode and status bar colors.

```kotlin
package com.swasthicare.mobile.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = PrimaryColor,
    secondary = SecondaryColor,
    tertiary = AccentColor,
    background = BackgroundDark,
    surface = SurfaceDark
)

private val LightColorScheme = lightColorScheme(
    primary = PrimaryColor,
    secondary = SecondaryColor,
    tertiary = AccentColor,
    background = BackgroundLight,
    surface = SurfaceLight
)

@Composable
fun SwasthiCareTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val view = LocalView.current
    
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
```

## 6. Screens Implementation

### Splash Screen
File: `ui/screens/splash/SplashScreen.kt`

A simple splash screen that navigates to home after a 2-second delay.

```kotlin
package com.swasthicare.mobile.ui.screens.splash

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Composable
fun SplashScreen(
    onNavigateToHome: () -> Unit
) {
    LaunchedEffect(Unit) {
        delay(2000)
        onNavigateToHome()
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.primary),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "SwasthiCare",
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Your Health Companion",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onPrimary
            )
        }
    }
}
```

### Home Screen
File: `ui/screens/home/HomeScreen.kt`

The main landing screen with a top app bar.

```kotlin
package com.swasthicare.mobile.ui.screens.home

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen() {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("SwasthiCare") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Welcome to SwasthiCare",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Your health companion app",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}
```

## 7. Navigation Setup

File: `ui/navigation/AppNavigation.kt`

Set up the navigation graph using Jetpack Compose Navigation.

```kotlin
package com.swasthicare.mobile.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.ui.screens.home.HomeScreen
import com.swasthicare.mobile.ui.screens.splash.SplashScreen

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = "splash"
    ) {
        composable("splash") {
            SplashScreen(
                onNavigateToHome = {
                    navController.navigate("home") {
                        popUpTo("splash") { inclusive = true }
                    }
                }
            )
        }
        
        composable("home") {
            HomeScreen()
        }
    }
}
```

## 8. App Entry Point

### Main Activity
File: `MainActivity.kt`

The main entry point Activity that sets up the theme and navigation.

```kotlin
package com.swasthicare.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.swasthicare.mobile.ui.navigation.AppNavigation
import com.swasthicare.mobile.ui.theme.SwasthiCareTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SwasthiCareTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AppNavigation()
                }
            }
        }
    }
}
```

### Application Class
File: `SwasthiCareApplication.kt`

```kotlin
package com.swasthicare.mobile

import android.app.Application

class SwasthiCareApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize app-wide services here
    }
}
```

## 9. Manifest Configuration

File: `android/app/src/main/AndroidManifest.xml`

Configure permissions and declare the application and activity.

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:name=".SwasthiCareApplication"
        android:allowBackup="true"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.SwasthiCare">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.SwasthiCare">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
```

## 10. Building the App

Navigate to the `android` directory in your terminal and run the following commands:

**Debug Build:**
```bash
./gradlew assembleDebug
```
*Output: `app/build/outputs/apk/debug/app-debug.apk`*

**Release Build:**
```bash
./gradlew assembleRelease
```
*Output: `app/build/outputs/apk/release/app-release.apk`*

**Run Unit Tests:**
```bash
./gradlew test
```

## 11. Troubleshooting

*   **Gradle Sync Failures**: Ensure you have JDK 17 selected in Android Studio Settings > Build, Execution, Deployment > Build Tools > Gradle.
*   **Unresolved References**: Perform `File > Invalidate Caches / Restart` in Android Studio.
*   **Emulator Issues**: Ensure the emulator is running API 34 (Android 14) or at least API 24 (Android 7.0).
