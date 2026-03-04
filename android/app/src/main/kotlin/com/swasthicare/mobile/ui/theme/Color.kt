package com.swasthicare.mobile.ui.theme

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

// Brand Colors — matched to iOS exact hex values
val PrimaryColor = Color(0xFF4F46E5) // Indigo 600 (iOS accentBlue)
val SecondaryColor = Color(0xFF22C55E) // Green 500 (iOS accentGreen)
val AccentColor = Color(0xFFEF4444) // Red 500 (iOS accentRed)

// Background Colors
val BackgroundLight = Color(0xFFF2F2F7) // Slight grey for depth
val BackgroundDark = Color(0xFF000000) // True OLED Black

// Surface Colors
val SurfaceLight = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF1C1C1E) // iOS Dark Gray

// Text Colors
val TextPrimaryLight = Color(0xFF000000)
val TextSecondaryLight = Color(0xFF8E8E93)
val TextPrimaryDark = Color(0xFFFFFFFF)
val TextSecondaryDark = Color(0xFF8E8E93)

// Functional Colors
val HeartRateColor = Color(0xFFFF3B30)
val SleepColor = Color(0xFF4F46E5)
val ActivityColor = Color(0xFFFF9F0A)
val HydrationColor = Color(0xFF00C7BE)

val MedicationColor = Color(0xFF5856D6)
val DietColor = Color(0xFF34C759)
val StepsColor = Color(0xFF30D158)
val DistanceColor = Color(0xFF0A84FF)

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
