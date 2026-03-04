package com.swasthicare.mobile.ui.screens.splash

import android.net.Uri
import androidx.annotation.OptIn
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.swasthicare.mobile.BuildConfig
import com.swasthicare.mobile.R
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.di.ONBOARDING_COMPLETE_KEY
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

@OptIn(UnstableApi::class)
@Composable
fun SplashScreen(
    onNavigateToHome: () -> Unit,
    onNavigateToLogin: () -> Unit,
    onNavigateToOnboarding: () -> Unit,
    onForceUpdate: () -> Unit
) {
    val context = LocalContext.current

    // Fade-out overlay for cinematic exit (matches iOS)
    var fadeOut by remember { mutableStateOf(false) }
    val screenAlpha by animateFloatAsState(
        targetValue = if (fadeOut) 1f else 0f,
        animationSpec = tween(400),
        label = "fadeOut"
    )

    // Create ExoPlayer — plays once and holds on last frame
    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply {
            val videoUri = Uri.parse("android.resource://${context.packageName}/${R.raw.sw_logo_v1}")
            setMediaItem(MediaItem.fromUri(videoUri))
            repeatMode = Player.REPEAT_MODE_OFF
            playWhenReady = true
            prepare()
        }
    }

    // Clean up player on dispose
    DisposableEffect(Unit) {
        onDispose { exoPlayer.release() }
    }

    // Navigation logic — wait for video to finish, then route
    LaunchedEffect(Unit) {
        // Wait for the video to finish (poll every 100ms)
        while (exoPlayer.currentPosition < exoPlayer.duration - 100 || exoPlayer.duration <= 0) {
            delay(100)
        }
        // Hold on last frame briefly
        delay(500)

        // Check for force update
        try {
            val config = AppContainer.supabaseClient.postgrest["app_config"]
                .select { filter { eq("key", "min_android_version") } }
                .decodeSingleOrNull<Map<String, String>>()
            val minVersion = config?.get("value")?.toIntOrNull() ?: 1
            val currentVersion = BuildConfig.VERSION_CODE

            if (currentVersion < minVersion) {
                fadeOut = true
                delay(400)
                onForceUpdate()
                return@LaunchedEffect
            }
        } catch (_: Exception) { }

        val prefs = AppContainer.dataStore.data.first()
        val onboardingDone = prefs[ONBOARDING_COMPLETE_KEY] ?: false

        fadeOut = true
        delay(400)

        if (onboardingDone) {
            onNavigateToLogin()
        } else {
            onNavigateToOnboarding()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Full-screen video player (no controls)
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = false
                    resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                    setBackgroundColor(android.graphics.Color.BLACK)
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Fade-to-black overlay for cinematic exit
        Box(
            modifier = Modifier
                .fillMaxSize()
                .alpha(screenAlpha)
                .background(Color.Black)
        )
    }
}
