package com.swastricare.health.ui.screens.update

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.PoppinsFontFamily

/**
 * OptionalUpdateDialog
 *
 * Compact card-style prompt for non-mandatory updates. Mirrors the force-update
 * screen's visual language (AITeal accent, leafy hero, pure white surface) but
 * stays sized as a dialog so it can sit over the current screen. "Maybe Later"
 * dismisses for 24 hours via the parent.
 */
@Composable
fun OptionalUpdateDialog(
    newVersion: String,
    updateTitle: String? = null,
    updateMessage: String? = null,
    storeUrl: String?,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

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

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .clip(RoundedCornerShape(28.dp)),
            color = Color.White,
            shadowElevation = 12.dp
        ) {
            Box(modifier = Modifier.fillMaxWidth()) {
                // Subtle leafy band behind the CTA
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
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (heroBitmap != null) {
                        Image(
                            bitmap = heroBitmap,
                            contentDescription = null,
                            contentScale = ContentScale.Fit,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(160.dp)
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                    }

                    Text(
                        text = updateTitle ?: "Update Available",
                        fontFamily = PoppinsFontFamily,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A),
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = updateMessage
                            ?: "Version $newVersion is available with improvements and bug fixes.",
                        fontFamily = PoppinsFontFamily,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.Normal,
                        color = Color(0xFF64748B),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(24.dp))

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
                            onDismiss()
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
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

                    Spacer(modifier = Modifier.height(6.dp))

                    Text(
                        text = "Maybe Later",
                        fontFamily = PoppinsFontFamily,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color(0xFF64748B),
                        modifier = Modifier
                            .clickable { onDismiss() }
                            .padding(10.dp)
                    )
                }
            }
        }
    }
}
