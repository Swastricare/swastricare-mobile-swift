package com.swastricare.health.ui.screens.update

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.PoppinsFontFamily

/**
 * ForceUpdateScreen
 *
 * Full-screen blocking update prompt. Pure white background with:
 *  • Hero illustration (assets/images/update required screen.png) at top
 *  • Title + subtitle (server-overridable)
 *  • Three benefit rows (Better Performance / New Features / Enhanced Security)
 *  • Solid AITeal "Update Now" CTA
 *  • Optional "Not Now" link (only when [onNotNow] is provided)
 *  • Bottom leafy illustration sits behind the CTA as a decorative band
 */
@Composable
fun ForceUpdateScreen(
    currentVersion: String,
    latestVersion: String,
    updateTitle: String? = null,
    updateMessage: String? = null,
    storeUrl: String? = null,
    onNotNow: (() -> Unit)? = null
) {
    TrackScreen("ForceUpdate")
    val context = LocalContext.current

    BackHandler(enabled = onNotNow == null) {
        // Block back navigation on hard force update
    }

    val heroBitmap: ImageBitmap? = remember {
        runCatching {
            context.assets.open("images/update required screen.png").use {
                BitmapFactory.decodeStream(it)
            }.asImageBitmap()
        }.getOrNull()
    }

    val bottomBitmap: ImageBitmap? = remember {
        runCatching {
            context.assets.open("images/update required bottom illustration.png").use {
                BitmapFactory.decodeStream(it)
            }.asImageBitmap()
        }.getOrNull()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        // Decorative bottom illustration — sits behind the CTA
        if (bottomBitmap != null) {
            Image(
                bitmap = bottomBitmap,
                contentDescription = null,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            // Hero illustration
            if (heroBitmap != null) {
                Image(
                    bitmap = heroBitmap,
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(260.dp)
                )
            } else {
                Spacer(modifier = Modifier.height(260.dp))
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = updateTitle ?: "Update Required",
                fontFamily = PoppinsFontFamily,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF0F172A),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(10.dp))

            Text(
                text = updateMessage
                    ?: "A new version of the app is available. Update now to continue using all features and improvements.",
                fontFamily = PoppinsFontFamily,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Normal,
                color = Color(0xFF64748B),
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
            )

            Spacer(modifier = Modifier.height(28.dp))

            // Benefits
            BenefitRow(
                icon = Icons.Outlined.Shield,
                title = "Better Performance",
                subtitle = "Faster and more reliable experience"
            )
            Spacer(modifier = Modifier.height(18.dp))
            BenefitRow(
                icon = Icons.Outlined.Star,
                title = "New Features",
                subtitle = "Exciting features and improvements"
            )
            Spacer(modifier = Modifier.height(18.dp))
            BenefitRow(
                icon = Icons.Outlined.Lock,
                title = "Enhanced Security",
                subtitle = "Stronger protection for your data"
            )

            Spacer(modifier = Modifier.height(40.dp))

            // CTA
            Button(
                onClick = {
                    val url = storeUrl ?: "market://details?id=com.swastricare.health"
                    try {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    } catch (_: Exception) {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://play.google.com/store/apps/details?id=com.swastricare.health")
                            )
                        )
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                contentPadding = PaddingValues(0.dp)
            ) {
                Text(
                    text = "Update Now",
                    fontFamily = PoppinsFontFamily,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }

            if (onNotNow != null) {
                Spacer(modifier = Modifier.height(14.dp))
                Text(
                    text = "Not Now",
                    fontFamily = PoppinsFontFamily,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(0xFF64748B),
                    modifier = Modifier
                        .padding(8.dp)
                        .clickable { onNotNow() }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun BenefitRow(
    icon: ImageVector,
    title: String,
    subtitle: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .background(AITeal.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = AITeal,
                modifier = Modifier.size(22.dp)
            )
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontFamily = PoppinsFontFamily,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFF0F172A)
            )
            Text(
                text = subtitle,
                fontFamily = PoppinsFontFamily,
                fontSize = 13.sp,
                fontWeight = FontWeight.Normal,
                color = Color(0xFF64748B)
            )
        }
    }
}
