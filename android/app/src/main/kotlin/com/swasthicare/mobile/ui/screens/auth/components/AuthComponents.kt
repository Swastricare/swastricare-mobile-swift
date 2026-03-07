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
import androidx.compose.ui.draw.clip
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
import com.swasthicare.mobile.ui.theme.AppColors

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
    // Matching iOS AuthTextField: label above, icon + field inside rounded container
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Label above (matching iOS)
        Text(
            text = placeholder,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = AppColors.onSurfaceVariant
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    AppColors.onSurface.copy(alpha = 0.05f),
                    RoundedCornerShape(16.dp)
                )
                .border(
                    width = 1.dp,
                    color = if (isError) AppColors.error
                           else AppColors.onSurface.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isError) AppColors.error else AppColors.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )

            TextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = { Text("", color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = PremiumColors.RoyalBlue,
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface
                ),
                keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
                keyboardActions = keyboardActions,
                singleLine = true,
                modifier = Modifier.weight(1f),
                isError = isError
            )
        }
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

    // Matching iOS AuthSecureField: label above, icon + field + eye toggle
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = placeholder,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = AppColors.onSurfaceVariant
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    AppColors.onSurface.copy(alpha = 0.05f),
                    RoundedCornerShape(16.dp)
                )
                .border(
                    width = 1.dp,
                    color = if (isError) AppColors.error
                           else AppColors.onSurface.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isError) AppColors.error else AppColors.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )

            TextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = { Text("", color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)) },
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = PremiumColors.RoyalBlue,
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface
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
                    tint = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

enum class PremiumButtonStyle { PRIMARY, SECONDARY, GHOST }

@Composable
fun PremiumButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: PremiumButtonStyle = PremiumButtonStyle.PRIMARY,
    enabled: Boolean = true,
    isLoading: Boolean = false
) {
    when (style) {
        PremiumButtonStyle.PRIMARY -> {
            // Matching iOS PremiumButton .primary: gradient fill, shadow
            Box(
                modifier = modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .shadow(
                        elevation = if (enabled) 12.dp else 0.dp,
                        shape = RoundedCornerShape(16.dp),
                        spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.4f)
                    )
                    .background(
                        brush = if (enabled) Brush.linearGradient(
                            listOf(PremiumColors.RoyalBlue, Color(0xFF4A5FE0))
                        ) else Brush.linearGradient(
                            listOf(Color.Gray.copy(alpha = 0.3f), Color.Gray.copy(alpha = 0.3f))
                        ),
                        shape = RoundedCornerShape(16.dp)
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
        PremiumButtonStyle.SECONDARY -> {
            // Matching iOS PremiumButton .secondary: outlined, transparent fill
            Box(
                modifier = modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .border(
                        width = 1.5.dp,
                        color = if (enabled) PremiumColors.RoyalBlue else Color.Gray.copy(alpha = 0.3f),
                        shape = RoundedCornerShape(16.dp)
                    )
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (enabled) PremiumColors.RoyalBlue.copy(alpha = 0.08f)
                        else Color.Transparent
                    )
                    .clickable(enabled = enabled && !isLoading, onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = PremiumColors.RoyalBlue,
                        modifier = Modifier.size(24.dp)
                    )
                } else {
                    Text(
                        text,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = if (enabled) PremiumColors.RoyalBlue else Color.Gray
                    )
                }
            }
        }
        PremiumButtonStyle.GHOST -> {
            // Matching iOS PremiumButton .ghost: no border, just text
            Box(
                modifier = modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .clickable(enabled = enabled && !isLoading, onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = PremiumColors.RoyalBlue,
                        modifier = Modifier.size(24.dp)
                    )
                } else {
                    Text(
                        text,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = if (enabled) PremiumColors.RoyalBlue else Color.Gray
                    )
                }
            }
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
    // Matching iOS AuthSocialButton: outlined, 56dp, icon + text centered
    Row(
        modifier = modifier
            .height(56.dp)
            .background(
                AppColors.onSurface.copy(alpha = 0.05f),
                RoundedCornerShape(16.dp)
            )
            .border(
                width = 1.dp,
                color = AppColors.onSurface.copy(alpha = 0.1f),
                shape = RoundedCornerShape(16.dp)
            )
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = AppColors.onSurface
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyLarge.copy(
                fontWeight = FontWeight.SemiBold
            ),
            color = AppColors.onSurface
        )
    }
}

@Composable
fun AnimatedLogo(modifier: Modifier = Modifier) {
    val surface = MaterialTheme.colorScheme.surface
    val surfaceVariant = MaterialTheme.colorScheme.surfaceVariant

    Box(modifier = modifier.size(120.dp), contentAlignment = Alignment.Center) {
        // Outer Glow
        Box(
            modifier = Modifier
                .size(90.dp)
                .blur(40.dp)
                .background(PremiumColors.RoyalBlue.copy(alpha = 0.3f))
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
                .background(surface, RoundedCornerShape(28.dp))
                .border(
                    1.dp,
                    Brush.linearGradient(
                        listOf(
                            surfaceVariant,
                            surfaceVariant.copy(alpha = 0.5f),
                            surfaceVariant
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
                modifier = Modifier.size(48.dp)
            )
        }
    }
}

@Composable
fun PremiumBackground(modifier: Modifier = Modifier) {
    // Matching iOS AuthBackground: system background + two blurred circles
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AppColors.background)
    ) {
        // Top Right - Blue circle
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 50.dp, y = (-50).dp)
                .size(300.dp)
                .background(PremiumColors.RoyalBlue.copy(alpha = 0.05f), androidx.compose.foundation.shape.CircleShape)
                .blur(100.dp)
        )

        // Bottom Left - Cyan circle
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(x = (-50).dp, y = 50.dp)
                .size(250.dp)
                .background(PremiumColors.Cyan.copy(alpha = 0.05f), androidx.compose.foundation.shape.CircleShape)
                .blur(90.dp)
        )
    }
}