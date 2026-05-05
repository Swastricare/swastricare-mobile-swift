package com.swastricare.health

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.compose.setContent
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.fragment.app.FragmentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import com.swastricare.health.ui.theme.AppColors
import androidx.compose.runtime.*
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.swastricare.health.navigation.DeepLinkHandler
import com.swastricare.health.navigation.DeepLinkRoute
import com.swastricare.health.ui.lock.LockScreenViewModel
import com.swastricare.health.ui.navigation.AppNavigation
import com.swastricare.health.ui.screens.auth.AuthViewModel
import com.swastricare.health.ui.theme.SwastriCareTheme
import com.swastricare.health.ui.theme.ThemePreferenceManager
import dagger.hilt.android.AndroidEntryPoint
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.handleDeeplinks
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : FragmentActivity() {

    @Inject lateinit var notificationService: com.swastricare.health.data.services.NotificationService
    @Inject lateinit var supabaseClient: SupabaseClient
    @Inject lateinit var themePreferenceManager: ThemePreferenceManager
    @Inject lateinit var analyticsService: com.swastricare.health.data.services.AppAnalyticsService

    // AuthViewModel obtained at Activity level so deep link callbacks can call it
    // outside of Compose composition (e.g. from onNewIntent).
    private val authViewModel: AuthViewModel by viewModels()

    // Deep link route parsed from intent, observed by AppNavigation
    private val pendingDeepLink = MutableStateFlow<DeepLinkRoute?>(null)

    private val notifPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            CoroutineScope(Dispatchers.Default).launch {
                notificationService.scheduleAllNotifications()
            }
        }
    }

    // Force the activity's configuration into night-mode-NO. This is what
    // isSystemInDarkTheme() reads, so every Composable that branches on it
    // sees light, regardless of the OS dark setting. Temporary until theme
    // switching is reintroduced.
    override fun attachBaseContext(newBase: Context) {
        val config = Configuration(newBase.resources.configuration)
        config.uiMode = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            Configuration.UI_MODE_NIGHT_NO
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        newConfig.uiMode = (newConfig.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            Configuration.UI_MODE_NIGHT_NO
        super.onConfigurationChanged(newConfig)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Force a pure-white status/nav bar with dark icons across the app.
        val whiteScrim = android.graphics.Color.WHITE
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(whiteScrim, whiteScrim),
            navigationBarStyle = SystemBarStyle.light(whiteScrim, whiteScrim)
        )
        super.onCreate(savedInstanceState)

        // Request POST_NOTIFICATIONS permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!com.swastricare.health.data.services.NotificationPermissionManager.hasNotificationPermission(this)) {
                notifPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        // Track notification tap if launched from a notification
        intent?.getStringExtra(com.swastricare.health.data.services.NotificationService.EXTRA_NOTIFICATION_TYPE)?.let { type ->
            analyticsService.trackNotificationTapped(type)
        }

        // Handle deep link from launch intent
        handleDeepLink(intent)

        setContent {
            SwastriCareTheme(themePreferenceManager = themePreferenceManager) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = androidx.compose.ui.graphics.Color.White
                ) {
                    val lockViewModel: LockScreenViewModel = hiltViewModel()
                    val isLocked by lockViewModel.isLocked.collectAsState()

                    // Lifecycle observer drives both the lock-on-background and the
                    // show-prompt-on-foreground behavior. This is more reliable than
                    // keying a LaunchedEffect on the isLocked StateFlow because state
                    // changes that happen during ON_STOP can be missed by the recomposer
                    // when the activity returns — manifesting as a black screen with no
                    // biometric prompt on minimise + reopen.
                    //
                    // On attach, the observer is replayed the current state events
                    // (ON_CREATE → ON_START → ON_RESUME), so initial launches also
                    // trigger the prompt via the same code path.
                    val lifecycleOwner = LocalLifecycleOwner.current
                    DisposableEffect(lifecycleOwner) {
                        val observer = LifecycleEventObserver { _, event ->
                            when (event) {
                                Lifecycle.Event.ON_STOP -> {
                                    // Only lock when the activity is truly going to background,
                                    // not during configuration changes (rotation) or when a
                                    // system overlay (permission dialog, notification shade)
                                    // temporarily covers the window.
                                    if (!isChangingConfigurations && lockViewModel.isBiometricEnabled) {
                                        lockViewModel.onAppBackgrounded()
                                    }
                                }
                                Lifecycle.Event.ON_RESUME -> {
                                    // Activity is fully resumed — safe to commit the
                                    // BiometricPrompt DialogFragment. If the app is locked
                                    // (either from initial launch or from a background trip),
                                    // show the native system prompt. On user cancel, finish
                                    // the activity (WhatsApp / Signal app-lock pattern).
                                    if (lockViewModel.isLocked.value) {
                                        lockViewModel.authenticate(
                                            activity = this@MainActivity,
                                            onCancel = { finish() }
                                        )
                                    }
                                }
                                else -> {}
                            }
                        }
                        lifecycleOwner.lifecycle.addObserver(observer)
                        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
                    }

                    val currentDeepLink by pendingDeepLink.collectAsState()

                    Box(modifier = Modifier.fillMaxSize()) {
                        // Only compose the main app when unlocked.
                        // SurfaceView/GLSurfaceView used by the 3D model viewer renders at the
                        // hardware compositor level and punches through any Compose overlay,
                        // so the only safe way to hide it is to remove it from composition.
                        if (!isLocked) {
                            AppNavigation(
                                authViewModel = authViewModel,
                                deepLinkRoute = currentDeepLink,
                                onDeepLinkConsumed = { pendingDeepLink.value = null }
                            )
                        } else {
                            // Solid background rendered behind the system biometric prompt
                            // so private app content is never visible while locked.
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(AppColors.background)
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }

    /**
     * Extract the `type` parameter from a Supabase auth callback URI.
     * Supabase encodes auth params in the URL fragment: `#type=recovery&access_token=...`
     * Also checks query parameters as a fallback.
     */
    private fun extractAuthType(uri: Uri): String? {
        // Try fragment first (Supabase default: #type=recovery&access_token=...)
        val fragment = uri.fragment
        if (!fragment.isNullOrEmpty()) {
            fragment.split("&").forEach { param ->
                val parts = param.split("=", limit = 2)
                if (parts.size == 2 && parts[0] == "type") {
                    return parts[1]
                }
            }
        }
        // Fallback: check query parameter
        return uri.getQueryParameter("type")
    }

    private fun handleDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return

        // Handle HTTPS app links from app.swastricare.com (email verification redirects)
        if (uri.scheme == "https" && uri.host == "swastricare.com") {
            val path = uri.path ?: ""
            if (path.startsWith("/auth/callback") || path.startsWith("/auth/confirm")) {
                val callbackType = extractAuthType(uri)
                try {
                    supabaseClient.handleDeeplinks(intent = intent) { session ->
                        Log.d("Auth", "HTTPS deep link auth session established for: ${session.user?.email}")
                        CoroutineScope(Dispatchers.Main).launch {
                            authViewModel.onAuthCallback(callbackType)
                        }
                    }
                } catch (e: Exception) {
                    Log.e("Auth", "Failed to handle HTTPS auth deep link: ${e.message}", e)
                    CoroutineScope(Dispatchers.Main).launch {
                        authViewModel.onAuthCallback(callbackType)
                    }
                }
                return
            }
            // Non-auth HTTPS links: try to parse as navigation deep link
            val route = DeepLinkHandler.parse(uri)
            if (route != null && route !is DeepLinkRoute.Unknown) {
                pendingDeepLink.value = route
            }
            return
        }

        // Handle Supabase auth callbacks (email verification, OAuth redirect)
        if (uri.scheme == "swastricareapp" && uri.host == "auth-callback") {
            val callbackType = extractAuthType(uri)
            try {
                supabaseClient.handleDeeplinks(intent = intent) { session ->
                    Log.d("Auth", "Deep link auth session established for: ${session.user?.email}")
                    CoroutineScope(Dispatchers.Main).launch {
                        authViewModel.onAuthCallback(callbackType)
                    }
                }
            } catch (e: Exception) {
                Log.e("Auth", "Failed to handle auth deep link: ${e.message}", e)
                // Fallback: try to check session anyway (link may have verified the email server-side)
                CoroutineScope(Dispatchers.Main).launch {
                    authViewModel.onAuthCallback(callbackType)
                }
            }
            return
        }

        // Handle app navigation deep links
        val route = DeepLinkHandler.parse(uri) ?: return
        if (route is DeepLinkRoute.Unknown) return

        // For the activeworkout deep link (from notification tap): only navigate
        // if there is an active workout.  If the back stack already has the
        // live_workout entry the navigation layer will reuse it (launchSingleTop),
        // so the in-progress workout is never reset.
        if (route is DeepLinkRoute.StartRun && uri.host?.lowercase() == "activeworkout") {
            pendingDeepLink.value = DeepLinkRoute.StartRun("__resume__")
        } else {
            pendingDeepLink.value = route
        }
    }
}
