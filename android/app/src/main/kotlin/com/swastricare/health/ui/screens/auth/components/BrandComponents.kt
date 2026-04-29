package com.swastricare.health.ui.screens.auth.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import com.swastricare.health.R
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Shared brand header for Login and Sign Up screens — logo + wordmark + tagline + illustration.
 */
@Composable
fun BrandAuthHeader(
    modifier: Modifier = Modifier,
    backgroundColor: Color = Color(0xFFF6FAFC)
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 220.dp)
        ) {
            androidx.compose.foundation.Image(
                painter = painterResource(R.drawable.signup_brand_header),
                contentDescription = "SwasthiCare illustration",
                contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                modifier = Modifier.fillMaxSize()
            )
            // Bottom fade — blends illustration into the page background
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp)
                    .align(Alignment.BottomCenter)
                    .background(
                        androidx.compose.ui.graphics.Brush.verticalGradient(
                            colors = listOf(Color.Transparent, backgroundColor)
                        )
                    )
            )
            // Top fade — softens any hard top edge
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(24.dp)
                    .align(Alignment.TopCenter)
                    .background(
                        androidx.compose.ui.graphics.Brush.verticalGradient(
                            colors = listOf(backgroundColor, Color.Transparent)
                        )
                    )
            )
        }
    }
}

@Composable
fun TermsCheckboxRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(if (checked) PremiumColors.Teal else Color.Transparent)
                .border(
                    width = 1.5.dp,
                    color = if (checked) PremiumColors.Teal else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f),
                    shape = RoundedCornerShape(4.dp)
                )
                .clickable { onCheckedChange(!checked) },
            contentAlignment = Alignment.Center
        ) {
            if (checked) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
        Spacer(modifier = Modifier.width(10.dp))
        val annotated = buildAnnotatedString {
            withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.75f))) {
                append("I agree to the ")
            }
            withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.SemiBold)) {
                append("Terms of Service")
            }
            withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.75f))) {
                append(" and ")
            }
            withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.SemiBold)) {
                append("Privacy Policy")
            }
        }
        Text(
            text = annotated,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
fun OrDividerRow(
    text: String = "or sign up with",
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        HorizontalDivider(
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
        )
        Text(
            text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
            modifier = Modifier.padding(horizontal = 12.dp)
        )
        HorizontalDivider(
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
        )
    }
}

@Composable
fun TrustBadgeRow(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(28.dp))
            .border(
                width = 0.5.dp,
                color = Color.Black.copy(alpha = 0.05f),
                shape = RoundedCornerShape(28.dp)
            )
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        TrustBadge(icon = Icons.Default.Verified, label = "ABDM Ready")
        BadgeDot()
        TrustBadge(icon = Icons.Default.Lock, label = "Secure Records")
        BadgeDot()
        TrustBadge(icon = Icons.Default.People, label = "Family Care")
    }
}

@Composable
private fun TrustBadge(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            icon,
            contentDescription = null,
            tint = PremiumColors.Teal,
            modifier = Modifier.size(16.dp)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
            fontSize = 12.sp
        )
    }
}

@Composable
private fun BadgeDot() {
    Box(
        modifier = Modifier
            .size(3.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f))
    )
}

/**
 * Brand social button — white card with leading icon and label, single row.
 */
@Composable
fun BrandSocialButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    iconContent: @Composable () -> Unit
) {
    Row(
        modifier = modifier
            .height(52.dp)
            .background(Color.White, RoundedCornerShape(14.dp))
            .border(
                width = 1.dp,
                color = Color.Black.copy(alpha = 0.06f),
                shape = RoundedCornerShape(14.dp)
            )
            .clip(RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        iconContent()
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = Color(0xFF111827)
        )
    }
}

@Composable
fun GoogleIcon(size: androidx.compose.ui.unit.Dp = 20.dp) {
    val context = LocalContext.current
    val bitmap = remember {
        runCatching {
            val inputStream = context.assets.open("icons/google_icon.png")
            android.graphics.BitmapFactory.decodeStream(inputStream)
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "Google",
            modifier = Modifier.size(size)
        )
    } else {
        Box(modifier = Modifier.size(size).background(Color.Gray.copy(alpha = 0.3f), CircleShape))
    }
}

@Composable
fun AppleIcon(size: androidx.compose.ui.unit.Dp = 20.dp) {
    Icon(
        painter = painterResource(id = R.drawable.ic_apple_logo),
        contentDescription = "Apple",
        tint = Color.Black,
        modifier = Modifier.size(size)
    )
}
