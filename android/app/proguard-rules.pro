# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# ===========================================================================
# Android components
# ===========================================================================
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# ===========================================================================
# kotlinx.serialization
# ===========================================================================
-keepattributes *Annotation*, InnerClasses, EnclosingMethod
-dontnote kotlinx.serialization.AnnotationsKt

# Keep Companion object fields of serializable classes
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }

# Keep `serializer()` on Companion objects of all @Serializable classes
-keep,includedescriptorclasses class com.swastricare.health.**$$serializer { *; }
-keepclassmembers class com.swastricare.health.** {
    *** Companion;
}
-keepclasseswithmembers class com.swastricare.health.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep all @Serializable annotated classes and their @SerialName fields
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}
-keepclassmembers @kotlinx.serialization.Serializable class ** {
    *** Companion;
}
-keepclasseswithmembers class **.*$Companion {
    kotlinx.serialization.KSerializer serializer(...);
}

# ===========================================================================
# Kotlin coroutines
# ===========================================================================
-keepnames class kotlinx.coroutines.** { *; }
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# ===========================================================================
# Supabase / Ktor
# ===========================================================================
-keep class io.github.jan.supabase.** { *; }
-keepnames class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# ===========================================================================
# Firebase (Analytics, Crashlytics, Performance)
# ===========================================================================
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ===========================================================================
# Google Play Services (Auth, Location)
# ===========================================================================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ===========================================================================
# Google Credential Manager / Google Sign-In
# ===========================================================================
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**
-keep class com.google.android.libraries.identity.** { *; }
-dontwarn com.google.android.libraries.identity.**

# ===========================================================================
# SceneView / Filament (3D model viewer)
# ===========================================================================
-keep class io.github.sceneview.** { *; }
-keep class com.google.android.filament.** { *; }
-dontwarn io.github.sceneview.**
-dontwarn com.google.android.filament.**

# ===========================================================================
# ML Kit Pose Detection
# ===========================================================================
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ===========================================================================
# Health Connect
# ===========================================================================
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# ===========================================================================
# CameraX
# ===========================================================================
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ===========================================================================
# Coil (image loading)
# ===========================================================================
-keep class coil.** { *; }
-dontwarn coil.**

# ===========================================================================
# Media3 / ExoPlayer (video splash screen)
# ===========================================================================
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ===========================================================================
# Jetpack Glance (App Widgets)
# ===========================================================================
-keep class androidx.glance.** { *; }
-dontwarn androidx.glance.**

# ===========================================================================
# Biometric
# ===========================================================================
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ===========================================================================
# DataStore
# ===========================================================================
-keep class androidx.datastore.** { *; }
-dontwarn androidx.datastore.**

# ===========================================================================
# Phosphor Icons (community icon library — keep all icon composables)
# ===========================================================================
-keep class com.adamglin.phosphoricons.** { *; }

# ===========================================================================
# App data models and services (ensure serialization works)
# ===========================================================================
-keep class com.swastricare.health.data.model.** { *; }
-keep class com.swastricare.health.data.models.** { *; }
-keep class com.swastricare.health.data.services.** { *; }
-keep class com.swastricare.health.widgets.** { *; }
-keep class com.swastricare.health.notifications.** { *; }

# ===========================================================================
# Hilt / Dagger ViewModels (prevent R8 from merging ViewModel keys)
# ===========================================================================
-keep @dagger.hilt.android.lifecycle.HiltViewModel class * { *; }
-keep class * extends androidx.lifecycle.ViewModel { *; }

# ===========================================================================
# SLF4J (used by Ktor/Supabase internals — no runtime impl needed on Android)
# ===========================================================================
-dontwarn org.slf4j.impl.StaticLoggerBinder
