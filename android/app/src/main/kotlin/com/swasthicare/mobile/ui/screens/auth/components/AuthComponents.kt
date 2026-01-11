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
import androidx.compose.ui.graphics.vector.ImageVector
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
    val Cyan = Color(0xFF1BFFFF)
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
    isFocused: Boolean = false
) {
    val borderBrush = if (isFocused) {
        Brush.linearGradient(listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan))
    } else {
        Brush.linearGradient(listOf(Color.White.copy(alpha = 0.3f), Color.Transparent))
    }
    
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
            .border(if (isFocused) 1.5.dp else 1.dp, borderBrush, RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(15.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (isFocused) PremiumColors.RoyalBlue else Color.Gray,
            modifier = Modifier.size(20.dp)
        )
        
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, color = Color.Gray) },
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                disabledContainerColor = Color.Transparent,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                cursorColor = PremiumColors.RoyalBlue
            ),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
            keyboardActions = keyboardActions,
            singleLine = true,
            modifier = Modifier.weight(1f)
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
    isFocused: Boolean = false
) {
    var passwordVisible by remember { mutableStateOf(false) }
    
    val borderBrush = if (isFocused) {
        Brush.linearGradient(listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan))
    } else {
        Brush.linearGradient(listOf(Color.White.copy(alpha = 0.3f), Color.Transparent))
    }
    
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
            .border(if (isFocused) 1.5.dp else 1.dp, borderBrush, RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(15.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (isFocused) PremiumColors.RoyalBlue else Color.Gray,
            modifier = Modifier.size(20.dp)
        )
        
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, color = Color.Gray) },
            visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                disabledContainerColor = Color.Transparent,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                cursorColor = PremiumColors.RoyalBlue
            ),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = imeAction),
            keyboardActions = keyboardActions,
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        
        IconButton(onClick = { passwordVisible = !passwordVisible }) {
            Icon(
                imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                contentDescription = if (passwordVisible) "Hide password" else "Show password",
                tint = Color.Gray
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
        targetValue = if (enabled) 1f else 0.95f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "button_scale"
    )
    
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .scale(scale)
            .shadow(if (enabled) 10.dp else 0.dp, RoundedCornerShape(16.dp))
            .background(
                Brush.horizontalGradient(listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan)),
                RoundedCornerShape(16.dp)
            )
            .border(
                1.dp,
                Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.5f), Color.Transparent)),
                RoundedCornerShape(16.dp)
            )
            .clickable(enabled = enabled && !isLoading, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
        } else {
            Text(text, style = MaterialTheme.typography.titleMedium, color = Color.White)
        }
    }
}

@Composable
fun SocialLoginButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .height(56.dp)
            .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
            .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(24.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
fun AnimatedLogo(modifier: Modifier = Modifier) {
    var isAnimating by remember { mutableStateOf(false) }
    
    val heartScale by animateFloatAsState(
        targetValue = if (isAnimating) 1.2f else 1.0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioLowBouncy),
        label = "heartbeat",
        finishedListener = { isAnimating = !isAnimating }
    )
    
    val infiniteTransition = rememberInfiniteTransition(label = "float")
    val floatOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = -10f,
        animationSpec = infiniteRepeatable(tween(3000, easing = EaseInOut), RepeatMode.Reverse),
        label = "float_offset"
    )
    
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.5f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(tween(3000, easing = EaseInOut), RepeatMode.Reverse),
        label = "glow_alpha"
    )
    
    LaunchedEffect(Unit) { isAnimating = true }
    
    Box(modifier = modifier.size(110.dp).offset(y = floatOffset.dp), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .size(90.dp)
                .blur(50.dp)
                .background(Brush.radialGradient(listOf(PremiumColors.RoyalBlue.copy(alpha = glowAlpha), Color.Transparent)))
        )
        
        Box(
            modifier = Modifier
                .size(110.dp)
                .shadow(20.dp, RoundedCornerShape(32.dp))
                .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(32.dp))
                .border(
                    1.dp,
                    Brush.linearGradient(listOf(Color.White.copy(alpha = 0.8f), Color.White.copy(alpha = 0.2f))),
                    RoundedCornerShape(32.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = "Logo",
                tint = PremiumColors.RoyalBlue,
                modifier = Modifier.size(50.dp).scale(heartScale)
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
                    listOf(Color(0xFFF5F7FA), Color(0xFFE8EEF5), Color(0xFFD9E7F5))
                )
            )
    )
}
