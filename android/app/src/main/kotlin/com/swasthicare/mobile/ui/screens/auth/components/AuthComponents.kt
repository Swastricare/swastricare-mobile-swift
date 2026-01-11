package com.swasthicare.mobile.ui.screens.auth.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp

/**
 * Premium color palette matching iOS
 */
object PremiumColors {
    val RoyalBlue = Color(0xFF2E3192)
    val Cyan = Color(0xFF00C6FF) // Slightly darker cyan for better gradient
    val LightBlueBg = Color(0xFFF0F4F8)
    val TextDark = Color(0xFF1A1C29)
    val TextGrey = Color(0xFF757E95)
}

@Composable
fun PremiumTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Next,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    isFocused: Boolean = false,
    isError: Boolean = false
) {
    val borderBrush = if (isError) {
        SolidColor(MaterialTheme.colorScheme.error)
    } else if (isFocused) {
        Brush.linearGradient(listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan))
    } else {
        SolidColor(Color.Transparent)
    }
    
    // Animate scale on focus for a premium feel
    val scale by animateFloatAsState(if (isFocused) 1.02f else 1f, label = "field_scale")
    
    Row(
        modifier = modifier
            .scale(scale)
            .fillMaxWidth()
            .height(60.dp) // Slightly taller for premium feel
            .shadow(
                elevation = 0.dp, // Flat style inside card
                shape = RoundedCornerShape(16.dp),
                spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.15f),
                ambientColor = PremiumColors.RoyalBlue.copy(alpha = 0.1f)
            )
            .background(PremiumColors.LightBlueBg, RoundedCornerShape(16.dp)) // Light grey for contrast on white card
            .border(if (isFocused || isError) 1.5.dp else 0.dp, borderBrush, RoundedCornerShape(16.dp))
            .padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (isError) MaterialTheme.colorScheme.error else if (isFocused) PremiumColors.RoyalBlue else PremiumColors.TextGrey,
            modifier = Modifier.size(22.dp)
        )
        
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, color = PremiumColors.TextGrey.copy(alpha = 0.7f)) },
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                disabledContainerColor = Color.Transparent,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                cursorColor = if (isError) MaterialTheme.colorScheme.error else PremiumColors.RoyalBlue,
                errorCursorColor = MaterialTheme.colorScheme.error,
                focusedTextColor = PremiumColors.TextDark,
                unfocusedTextColor = PremiumColors.TextDark
            ),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
            keyboardActions = keyboardActions,
            singleLine = true,
            modifier = Modifier.weight(1f),
            isError = isError
        )
    }
}

@Composable
fun PremiumSecureField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    imeAction: ImeAction = ImeAction.Done,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    isFocused: Boolean = false,
    isError: Boolean = false
) {
    var passwordVisible by remember { mutableStateOf(false) }
    
    val borderBrush = if (isError) {
         SolidColor(MaterialTheme.colorScheme.error)
    } else if (isFocused) {
        Brush.linearGradient(listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan))
    } else {
        SolidColor(Color.Transparent)
    }
    
    val scale by animateFloatAsState(if (isFocused) 1.02f else 1f, label = "field_scale")
    
    Row(
        modifier = modifier
            .scale(scale)
            .fillMaxWidth()
            .height(60.dp)
            .shadow(
                elevation = 0.dp, // Flat style inside card
                shape = RoundedCornerShape(16.dp),
                spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.15f),
                ambientColor = PremiumColors.RoyalBlue.copy(alpha = 0.1f)
            )
            .background(Color.White, RoundedCornerShape(16.dp))
            .border(if (isFocused || isError) 1.5.dp else 0.dp, borderBrush, RoundedCornerShape(16.dp))
            .padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (isError) MaterialTheme.colorScheme.error else if (isFocused) PremiumColors.RoyalBlue else PremiumColors.TextGrey,
            modifier = Modifier.size(22.dp)
        )
        
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, color = PremiumColors.TextGrey.copy(alpha = 0.7f)) },
            visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                disabledContainerColor = Color.Transparent,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                cursorColor = if (isError) MaterialTheme.colorScheme.error else PremiumColors.RoyalBlue,
                errorCursorColor = MaterialTheme.colorScheme.error,
                focusedTextColor = PremiumColors.TextDark,
                unfocusedTextColor = PremiumColors.TextDark
            ),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = imeAction),
            keyboardActions = keyboardActions,
            singleLine = true,
            modifier = Modifier.weight(1f),
            isError = isError
        )
        
        IconButton(onClick = { passwordVisible = !passwordVisible }) {
            Icon(
                imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                contentDescription = if (passwordVisible) "Hide password" else "Show password",
                tint = PremiumColors.TextGrey
            )
        }
    }
}

@Composable
fun PremiumButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false
) {
    val scale by animateFloatAsState(
        targetValue = if (enabled) 1f else 0.98f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "button_scale"
    )
    
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(60.dp)
            .scale(scale)
            .shadow(
                elevation = if (enabled) 15.dp else 4.dp,
                shape = RoundedCornerShape(18.dp),
                spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.5f),
                ambientColor = PremiumColors.Cyan.copy(alpha = 0.2f)
            )
            .background(
                Brush.horizontalGradient(listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan)),
                RoundedCornerShape(18.dp)
            )
            .clickable(enabled = enabled && !isLoading, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
        } else {
            Text(
                text, 
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold), 
                color = Color.White
            )
        }
    }
}

@Composable
fun SocialLoginButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val alpha by animateFloatAsState(if (enabled) 1f else 0.5f, label = "button_alpha")

    Row(
        modifier = modifier
            .height(56.dp)
            .shadow(
                elevation = 4.dp,
                shape = RoundedCornerShape(16.dp),
                spotColor = Color.Black.copy(alpha = 0.1f)
            )
            .background(Color.White, RoundedCornerShape(16.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon, 
            contentDescription = null, 
            modifier = Modifier.size(24.dp),
            tint = if (label == "Google") Color.Unspecified else Color.Black.copy(alpha = alpha) // Allow original colors if needed
        )
        // Manual tint for Google if using vector icon that doesn't have intrinsic color
        // For now using default tint, but if using Vector drawable with color, invoke tint=Color.Unspecified
        
        Text(
            label, 
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
            color = PremiumColors.TextDark.copy(alpha = alpha)
        )
    }
}

@Composable
fun AnimatedLogo(modifier: Modifier = Modifier) {
    var isAnimating by remember { mutableStateOf(false) }
    
    val heartScale by animateFloatAsState(
        targetValue = if (isAnimating) 1.15f else 1.0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioLowBouncy),
        label = "heartbeat",
        finishedListener = { isAnimating = !isAnimating }
    )
    
    val infiniteTransition = rememberInfiniteTransition(label = "float")
    val floatOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = -8f,
        animationSpec = infiniteRepeatable(tween(2500, easing = EaseInOut), RepeatMode.Reverse),
        label = "float_offset"
    )
    
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.5f,
        animationSpec = infiniteRepeatable(tween(2500, easing = EaseInOut), RepeatMode.Reverse),
        label = "glow_alpha"
    )
    
    LaunchedEffect(Unit) { isAnimating = true }
    
    Box(modifier = modifier.size(120.dp).offset(y = floatOffset.dp), contentAlignment = Alignment.Center) {
        // Outer Glow
        Box(
            modifier = Modifier
                .size(90.dp)
                .blur(40.dp)
                .background(PremiumColors.RoyalBlue.copy(alpha = glowAlpha))
        )
        
        // Card Container
        Box(
            modifier = Modifier
                .size(100.dp)
                .shadow(
                    elevation = 20.dp,
                    shape = RoundedCornerShape(28.dp),
                    spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.3f)
                )
                .background(Color.White, RoundedCornerShape(28.dp))
                .border(
                    1.dp,
                    Brush.linearGradient(
                        listOf(
                            Color.White,
                            Color.White.copy(alpha = 0.5f),
                            Color(0xFFE8EEF5)
                        )
                    ),
                    RoundedCornerShape(28.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = "Logo",
                tint = PremiumColors.RoyalBlue,
                modifier = Modifier.size(48.dp).scale(heartScale)
            )
        }
    }
}

@Composable
fun PremiumBackground(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color(0xFFF8FAFC), // Almost white
                        Color(0xFFEFF4F9),
                        Color(0xFFE2E9F3)  // Soft Blue-Grey
                    )
                )
            )
    ) {
        // Add subtle decorative circles for depth
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 100.dp, y = (-100).dp)
                .size(400.dp)
                .background(PremiumColors.Cyan.copy(alpha = 0.05f), androidx.compose.foundation.shape.CircleShape)
                .blur(80.dp)
        )
        
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(x = (-100).dp, y = 100.dp)
                .size(400.dp)
                .background(PremiumColors.RoyalBlue.copy(alpha = 0.05f), androidx.compose.foundation.shape.CircleShape)
                .blur(80.dp)
        )
    }
}