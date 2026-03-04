# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Supabase classes
-keep class io.github.jan.supabase.** { *; }
-keepnames class io.github.jan.supabase.** { *; }

# Keep Kotlin coroutines
-keepnames class kotlinx.coroutines.** { *; }

# Keep Android components
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver

# Kotlin serialization
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
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

# Supabase / Ktor
-dontwarn io.ktor.**
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Coil
-dontwarn coil.**

# Health Connect
-keep class androidx.health.connect.** { *; }

# SceneView / Filament (3D model viewer)
-keep class io.github.sceneview.** { *; }
-keep class com.google.android.filament.** { *; }
-dontwarn io.github.sceneview.**
-dontwarn com.google.android.filament.**

# ML Kit Pose Detection
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# App data models (ensure serialization works)
-keep class com.swasthicare.mobile.data.model.** { *; }
-keep class com.swasthicare.mobile.data.models.** { *; }
