plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    // Firebase — requires google-services.json in app/ directory from Firebase Console
    // To set up: https://console.firebase.google.com → Add Android app → Download google-services.json
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // firebase-perf plugin disabled — incompatible with AGP 9.x (no compatible version exists yet)
    // id("com.google.firebase.firebase-perf")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.swastricare.health"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.swastricare.health"
        minSdk = 26 // Raised from 24 to 26 for Health Connect support
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Google Sign-In Web Client ID (set in gradle.properties or local.properties)
        buildConfigField(
            "String",
            "GOOGLE_WEB_CLIENT_ID",
            "\"${project.findProperty("GOOGLE_WEB_CLIENT_ID") ?: ""}\""
        )

        // OpenWeatherMap API Key (set in gradle.properties: OPENWEATHERMAP_API_KEY=your_key)
        buildConfigField(
            "String",
            "OPENWEATHERMAP_API_KEY",
            "\"${project.findProperty("OPENWEATHERMAP_API_KEY") ?: ""}\""
        )

        // Google Maps API Key (set in gradle.properties: GOOGLE_MAPS_API_KEY=your_key)
        val mapsKey = project.findProperty("GOOGLE_MAPS_API_KEY") ?: ""
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsKey

        // Supabase credentials (set in gradle.properties)
        buildConfigField(
            "String",
            "SUPABASE_URL",
            "\"${project.findProperty("SUPABASE_URL") ?: ""}\""
        )
        buildConfigField(
            "String",
            "SUPABASE_ANON_KEY",
            "\"${project.findProperty("SUPABASE_ANON_KEY") ?: ""}\""
        )
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
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
        buildConfig = true
    }

    // Don't compress 3D model files — binary formats break when AAPT compresses them
    androidResources {
        noCompress += listOf("glb", "gltf", "hdr", "ktx")
    }
}

dependencies {
    // Core Android
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-process:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation:1.6.0")
    implementation("androidx.navigation:navigation-compose:2.7.6")
    implementation("androidx.compose.material:material-icons-extended")
    // Lucide Icons — stroke-only icon pack for nav bar and UI
    implementation("com.composables:icons-lucide:1.1.0")

    // Supabase
    implementation("io.github.jan-tennert.supabase:postgrest-kt:2.6.0")
    implementation("io.github.jan-tennert.supabase:gotrue-kt:2.6.0")
    implementation("io.github.jan-tennert.supabase:realtime-kt:2.6.0")
    implementation("io.github.jan-tennert.supabase:functions-kt:2.6.0")
    implementation("io.github.jan-tennert.supabase:storage-kt:2.6.0")
    implementation("io.ktor:ktor-client-android:2.3.12")
    implementation("io.ktor:ktor-client-core:2.3.12")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    implementation("io.coil-kt:coil-compose:2.5.0")

    // Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    implementation("com.google.firebase:firebase-perf-ktx")

    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:21.2.0")
    implementation("androidx.credentials:credentials:1.2.2")
    implementation("androidx.credentials:credentials-play-services-auth:1.2.2")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.0")

    // Health Connect
    implementation("androidx.health.connect:connect-client:1.1.0-alpha10")

    // Biometric
    implementation("androidx.biometric:biometric:1.2.0-alpha05")

    // Encrypted SharedPreferences (security-crypto)
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // SceneView for 3D rendering (wraps Filament with Compose support)
    implementation("io.github.sceneview:sceneview:2.2.1")

    // ML Kit Pose Detection (for AR Body Scan)
    implementation("com.google.mlkit:pose-detection:18.0.0-beta5")
    implementation("com.google.mlkit:pose-detection-accurate:18.0.0-beta5")

    // CameraX for PPG heart rate measurement and AR Body Scan (higher version)
    implementation("androidx.camera:camera-core:1.4.1")
    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")

    // Google Location Services for GPS workout tracking + weather-based hydration
    implementation("com.google.android.gms:play-services-location:21.2.0")

    // Google Maps SDK + Compose integration
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.maps.android:maps-compose:4.3.3")

    // Accompanist permissions helper
    implementation("com.google.accompanist:accompanist-permissions:0.34.0")

    // Media3 ExoPlayer (for video splash screen)
    implementation("androidx.media3:media3-exoplayer:1.2.1")
    implementation("androidx.media3:media3-ui:1.2.1")

    // DataStore Preferences (used for onboarding/consent state)
    implementation("androidx.datastore:datastore-preferences:1.0.0")

    // WorkManager — resilient background scheduling for AI nudges + activity checks
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // ViewModel Compose
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")

    // Jetpack Glance (App Widgets)
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.01.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
