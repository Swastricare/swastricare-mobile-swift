package com.swastricare.health.ui.screens.auth.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.R
import com.swastricare.health.ui.theme.AppColors

/**
 * Premium color palette matching iOS auth screens
 */
object PremiumColors {
    // Primary teal accent (brand: SwasthiCare #0DBD9C)
    val Teal = Color(0xFF0DBD9C)
    // Secondary green accent
    val NeonGreen = Color(0xFF00CDB5)
    // Purple orb accent
    val Purple = Color(0xFF7C3AED)
    // Pink accent
    val Pink = Color(0xFFEC4899)

    // Legacy aliases for backward compatibility
    val RoyalBlue = Teal
    val Cyan = NeonGreen
    val LightBlueBg = Color(0xFFF0FDFA)
    val TextDark = Color(0xFF1A1C29)
    val TextGrey = Color(0xFF757E95)

    // Teal-green gradient (primary button)
    val TealGreenGradient = listOf(Teal, NeonGreen)
}

// --- Auth Background matching iOS AuthGradientBackground ---

@Composable
fun AuthGradientBackground(modifier: Modifier = Modifier) {
    val isDark = isSystemInDarkTheme()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(if (isDark) Color(0xFF0A1A1A) else Color.White)
    ) {
        if (isDark) {
            // Dark mode gradient base
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                Color(0xFF0A1A1A),
                                Color(0xFF0D1117),
                                Color(0xFF0A0E14)
                            )
                        )
                    )
            )

            // Teal orb - top right
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 60.dp, y = (-50).dp)
                    .size(280.dp)
                    .background(PremiumColors.Teal.copy(alpha = 0.12f), CircleShape)
                    .blur(80.dp)
            )

            // Purple orb - bottom left
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .offset(x = (-60).dp, y = 150.dp)
                    .size(250.dp)
                    .background(PremiumColors.Purple.copy(alpha = 0.08f), CircleShape)
                    .blur(90.dp)
            )

            // Pink accent - center bottom
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(x = 20.dp, y = 100.dp)
                    .size(200.dp)
                    .background(PremiumColors.Pink.copy(alpha = 0.05f), CircleShape)
                    .blur(70.dp)
            )
        } else {
            // Light mode gradient base
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                Color(0xFFF0FDFA),
                                Color.White,
                                Color(0xFFF5F3FF)
                            )
                        )
                    )
            )

            // Teal orb
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 60.dp, y = (-40).dp)
                    .size(280.dp)
                    .background(PremiumColors.Teal.copy(alpha = 0.06f), CircleShape)
                    .blur(80.dp)
            )

            // Purple orb
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .offset(x = (-60).dp, y = 140.dp)
                    .size(250.dp)
                    .background(PremiumColors.Purple.copy(alpha = 0.04f), CircleShape)
                    .blur(80.dp)
            )
        }
    }
}

// Legacy alias
@Composable
fun PremiumBackground(modifier: Modifier = Modifier) {
    AuthGradientBackground(modifier)
}

// --- Glass Card Container matching iOS .ultraThinMaterial + rounded rect ---

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val isDark = isSystemInDarkTheme()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = if (isDark) Color.White.copy(alpha = 0.06f) else Color.White.copy(alpha = 0.7f),
                shape = RoundedCornerShape(24.dp)
            )
            .border(
                width = 0.5.dp,
                color = if (isDark) Color.White.copy(alpha = 0.08f) else Color.White.copy(alpha = 0.25f),
                shape = RoundedCornerShape(24.dp)
            )
            .padding(20.dp),
        content = content
    )
}

// --- Auth Alert Banner matching iOS AuthAlertBanner ---

@Composable
fun AuthAlertBanner(
    message: String,
    isSuccess: Boolean = false,
    modifier: Modifier = Modifier
) {
    val color = if (isSuccess) Color(0xFF22C55E) else Color(0xFFEF4444)
    val icon = if (isSuccess) Icons.Default.CheckCircle else Icons.Default.Warning

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = color.copy(alpha = 0.08f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(16.dp)
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = color
        )
    }
}

// --- Input Label matching iOS AuthInputLabel ---

@Composable
private fun AuthInputLabel(
    title: String,
    isFocused: Boolean
) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall.copy(
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.8.sp
        ),
        color = if (isFocused) PremiumColors.Teal else MaterialTheme.colorScheme.onSurfaceVariant
    )
}

// --- Text Field matching iOS AuthTextField ---

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
    isError: Boolean = false,
    errorText: String? = null
) {
    val isDark = isSystemInDarkTheme()
    val borderColor = when {
        isError -> Color(0xFFEF4444)
        isFocused -> PremiumColors.Teal.copy(alpha = 0.6f)
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
    }
    val borderWidth = if (isFocused || isError) 1.dp else 0.5.dp

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (isDark) Color.White.copy(alpha = 0.04f) else Color.Black.copy(alpha = 0.035f),
                    shape = RoundedCornerShape(14.dp)
                )
                .border(
                    width = borderWidth,
                    color = borderColor,
                    shape = RoundedCornerShape(14.dp)
                )
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isFocused) PremiumColors.Teal else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )

            TextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = {
                    Text(
                        placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                    )
                },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = PremiumColors.Teal,
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface
                ),
                textStyle = MaterialTheme.typography.bodyLarge,
                keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
                keyboardActions = keyboardActions,
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
        }

        if (isError && !errorText.isNullOrBlank()) {
            Text(
                text = errorText,
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFFEF4444),
                modifier = Modifier.padding(start = 4.dp)
            )
        }
    }
}

// --- Secure Field matching iOS AuthSecureField ---

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
    isError: Boolean = false,
    errorText: String? = null
) {
    var passwordVisible by remember { mutableStateOf(false) }
    val isDark = isSystemInDarkTheme()
    val borderColor = when {
        isError -> Color(0xFFEF4444)
        isFocused -> PremiumColors.Teal.copy(alpha = 0.6f)
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
    }
    val borderWidth = if (isFocused || isError) 1.dp else 0.5.dp

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (isDark) Color.White.copy(alpha = 0.04f) else Color.Black.copy(alpha = 0.035f),
                    shape = RoundedCornerShape(14.dp)
                )
                .border(
                    width = borderWidth,
                    color = borderColor,
                    shape = RoundedCornerShape(14.dp)
                )
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isFocused) PremiumColors.Teal else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )

            TextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = {
                    Text(
                        placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                    )
                },
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = PremiumColors.Teal,
                    focusedTextColor = MaterialTheme.colorScheme.onSurface,
                    unfocusedTextColor = MaterialTheme.colorScheme.onSurface
                ),
                textStyle = MaterialTheme.typography.bodyLarge,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = imeAction),
                keyboardActions = keyboardActions,
                singleLine = true,
                modifier = Modifier.weight(1f)
            )

            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                Icon(
                    imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                    contentDescription = if (passwordVisible) "Hide password" else "Show password",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        if (isError && !errorText.isNullOrBlank()) {
            Text(
                text = errorText,
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFFEF4444),
                modifier = Modifier.padding(start = 4.dp)
            )
        }
    }
}

// --- Primary Button matching iOS AuthPrimaryButtonStyle (capsule, teal-green gradient) ---

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
            Box(
                modifier = modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .shadow(
                        elevation = if (enabled) 14.dp else 0.dp,
                        shape = RoundedCornerShape(26.dp),
                        spotColor = PremiumColors.Teal.copy(alpha = 0.35f)
                    )
                    .background(
                        brush = if (enabled) Brush.linearGradient(PremiumColors.TealGreenGradient)
                        else Brush.linearGradient(
                            listOf(Color.Gray.copy(alpha = 0.25f), Color.Gray.copy(alpha = 0.25f))
                        ),
                        shape = RoundedCornerShape(26.dp)
                    )
                    .clip(RoundedCornerShape(26.dp))
                    .clickable(enabled = enabled && !isLoading, onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
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
            val isDark = isSystemInDarkTheme()
            Box(
                modifier = modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .border(
                        width = 1.5.dp,
                        color = if (enabled) PremiumColors.Teal else Color.Gray.copy(alpha = 0.3f),
                        shape = RoundedCornerShape(26.dp)
                    )
                    .clip(RoundedCornerShape(26.dp))
                    .background(
                        if (enabled) PremiumColors.Teal.copy(alpha = 0.08f)
                        else Color.Transparent
                    )
                    .clickable(enabled = enabled && !isLoading, onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = PremiumColors.Teal,
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = if (enabled) PremiumColors.Teal else Color.Gray
                    )
                }
            }
        }
        PremiumButtonStyle.GHOST -> {
            Box(
                modifier = modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(RoundedCornerShape(26.dp))
                    .clickable(enabled = enabled && !isLoading, onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = PremiumColors.Teal,
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = if (enabled) PremiumColors.Teal else Color.Gray
                    )
                }
            }
        }
    }
}

// --- Social Button matching iOS AuthSocialButton (glass material, side-by-side) ---

@Composable
fun SocialLoginButton(
    assetPath: String,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val isDark = isSystemInDarkTheme()
    val context = LocalContext.current
    val bitmap = remember {
        val inputStream = context.assets.open(assetPath)
        android.graphics.BitmapFactory.decodeStream(inputStream)
    }

    Row(
        modifier = modifier
            .height(48.dp)
            .background(
                color = if (isDark) Color.White.copy(alpha = 0.06f) else Color.Black.copy(alpha = 0.035f),
                shape = RoundedCornerShape(14.dp)
            )
            .border(
                width = 0.5.dp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                shape = RoundedCornerShape(14.dp)
            )
            .clip(RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = label,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

// --- Animated Logo matching iOS logo hero section ---

@Composable
fun AnimatedLogo(
    modifier: Modifier = Modifier,
    logoScale: Float = 1f,
    glowBreathing: Boolean = false
) {
    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val breathScale by infiniteTransition.animateFloat(
        initialValue = 0.85f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(2500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "breathScale"
    )

    Box(modifier = modifier.padding(top = 20.dp), contentAlignment = Alignment.Center) {
        // Breathing glow behind logo
        Box(
            modifier = Modifier
                .size(160.dp)
                .scale(if (glowBreathing) breathScale else 0.85f)
                .background(
                    Brush.radialGradient(
                        listOf(
                            PremiumColors.Teal.copy(alpha = 0.35f),
                            PremiumColors.Teal.copy(alpha = 0f)
                        )
                    ),
                    CircleShape
                )
        )

        // Logo container - uses app logo from assets
        val context = LocalContext.current
        val logoBitmap = remember {
            val inputStream = context.assets.open("icons/swastricare icon.png")
            android.graphics.BitmapFactory.decodeStream(inputStream)
        }

        Image(
            bitmap = logoBitmap.asImageBitmap(),
            contentDescription = "SwastriCare",
            modifier = Modifier
                .size(88.dp)
                .scale(logoScale)
                .shadow(
                    elevation = 20.dp,
                    shape = RoundedCornerShape(22.dp),
                    spotColor = PremiumColors.Teal.copy(alpha = 0.4f)
                )
                .clip(RoundedCornerShape(22.dp))
        )
    }
}
