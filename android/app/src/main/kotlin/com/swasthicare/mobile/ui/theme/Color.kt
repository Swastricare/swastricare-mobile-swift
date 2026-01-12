package com.swasthicare.mobile.ui.theme

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

// Brand Colors
val PrimaryColor = Color(0xFF5E5CE6) // A more vibrant Indigo
val SecondaryColor = Color(0xFF32D74B) // iOS Health Green
val AccentColor = Color(0xFFFF375F) // Modern Pink

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
val HeartRateColor = Color(0xFFFF2D55)
val SleepColor = Color(0xFF5E5CE6)
val ActivityColor = Color(0xFFFF9F0A)
val HydrationColor = Color(0xFF64D2FF)

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
