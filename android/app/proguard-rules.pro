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

# Kotlin serialization
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}

# Supabase / Ktor
-dontwarn io.ktor.**
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Coil
-dontwarn coil.**

# Health Connect
-keep class androidx.health.connect.** { *; }

# Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Firebase
-keep class com.google.firebase.** { *; }
