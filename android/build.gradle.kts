// Top-level build file
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.5.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.10")
        classpath("org.jetbrains.kotlin:kotlin-serialization:2.2.10")
        // Firebase
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
        // Firebase perf-plugin removed — no version supports AGP 9.x yet
        // See: https://github.com/firebase/firebase-android-sdk/issues/7293
        // The runtime library (firebase-perf-ktx) still works without the plugin
        classpath("org.jetbrains.kotlin:compose-compiler-gradle-plugin:2.2.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
