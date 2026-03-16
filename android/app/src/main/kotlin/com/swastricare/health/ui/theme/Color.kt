package com.swastricare.health.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

// Brand Colors — matched to iOS exact hex values
val PrimaryColor = Color(0xFF4F46E5) // Indigo 600 (iOS accentBlue)
val SecondaryColor = Color(0xFF22C55E) // Green 500 (iOS accentGreen)
val AccentColor = Color(0xFFEF4444) // Red 500 (iOS accentRed)

// Background Colors
val BackgroundLight = Color(0xFFFFFFFF) // Pure white for light theme
val BackgroundDark = Color(0xFF000000) // True OLED Black

// Surface Colors
val SurfaceLight = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF1C1C1E) // iOS Dark Gray

// Text Colors
val TextPrimaryLight = Color(0xFF000000)
val TextSecondaryLight = Color(0xFF8E8E93)
val TextPrimaryDark = Color(0xFFFFFFFF)
val TextSecondaryDark = Color(0xFF8E8E93)

// Functional Colors — per-feature semantic tokens
val HeartRateColor = Color(0xFFFF3B30)
val SleepColor = Color(0xFF4F46E5)
val ActivityColor = Color(0xFFFF9F0A)
val HydrationColor = Color(0xFF00C7BE)
val HydrationCyan = Color(0xFF64D2FF)

val MedicationColor = Color(0xFF5856D6)
val DietColor = Color(0xFF34C759)
val StepsColor = Color(0xFF30D158)
val DistanceColor = Color(0xFF0A84FF)
val CycleColor = Color(0xFFBF5AF2)
val SystemBlue = Color(0xFF007AFF)

// Nutrition-specific Colors
val NutritionProtein = Color(0xFFFF6B6B)
val NutritionCarbs = Color(0xFF4ECDC4)
val NutritionFat = Color(0xFFFFD93D)

// Danger / Warning
val DangerRed = Color(0xFFFF453A)
val WarningOrange = Color(0xFFFF9F0A)

// Theme-aware semantic color accessor
object AppColors {
    val background: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) BackgroundDark else BackgroundLight

    val surface: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) SurfaceDark else SurfaceLight

    val surfaceVariant: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF2C2C2E) else Color(0xFFE5E5EA)

    val primary: Color
        @Composable @ReadOnlyComposable
        get() = PrimaryColor

    val secondary: Color
        @Composable @ReadOnlyComposable
        get() = SecondaryColor

    val error: Color
        @Composable @ReadOnlyComposable
        get() = DangerRed

    val errorContainer: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF93000A) else Color(0xFFFFDAD6)

    val onPrimary: Color
        @Composable @ReadOnlyComposable
        get() = Color.White

    val onSecondary: Color
        @Composable @ReadOnlyComposable
        get() = Color.Black

    val onBackground: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) TextPrimaryDark else TextPrimaryLight

    val onSurface: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) TextPrimaryDark else TextPrimaryLight

    val onSurfaceVariant: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFFAEAEB2) else TextSecondaryLight

    val onErrorContainer: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFFFFDAD6) else Color(0xFF410002)

    val primaryContainer: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF2A2570) else Color(0xFFE8E5FF)

    val onPrimaryContainer: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFFE8E5FF) else Color(0xFF1B1464)

    val outline: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF8E8E93) else Color(0xFFC7C7CC)

    val outlineVariant: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color(0xFF48484A) else Color(0xFFD1D1D6)

    val cardBorder: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color.Transparent else Color.Black.copy(alpha = 0.3f)

    val navBar: Color
        @Composable @ReadOnlyComposable
        get() = if (isSystemInDarkTheme()) Color.Black else Color.White
}

// Premium Colors (Ported from iOS)
object PremiumColor {
    val RoyalBlueStart = Color(0xFF2E3192)
    val RoyalBlueEnd = Color(0xFF1BFFFF)
    
    val SunsetStart = Color(0xFFFF512F)
    val SunsetEnd = Color(0xFFDD2476)
    
    val NeonGreenStart = Color(0xFF11998E)
    val NeonGreenEnd = Color(0xFF38EF7D)
    
    val DeepPurpleStart = Color(0xFF654EA3)
    val DeepPurpleEnd = Color(0xFFEAAFC8)
    
    val MidnightStart = Color(0xFF232526)
    val MidnightEnd = Color(0xFF414345)
    
    // Gradients
    val RoyalBlue = Brush.linearGradient(listOf(RoyalBlueStart, RoyalBlueEnd))
    val Sunset = Brush.linearGradient(listOf(SunsetStart, SunsetEnd))
    val NeonGreen = Brush.linearGradient(listOf(NeonGreenStart, NeonGreenEnd))
    val DeepPurple = Brush.linearGradient(listOf(DeepPurpleStart, DeepPurpleEnd))
    val Midnight = Brush.verticalGradient(listOf(MidnightStart, MidnightEnd))
}
