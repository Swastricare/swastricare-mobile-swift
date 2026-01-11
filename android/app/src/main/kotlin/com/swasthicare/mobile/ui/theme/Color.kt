package com.swasthicare.mobile.ui.theme

import androidx.compose.ui.graphics.Brush
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
