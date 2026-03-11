package com.swasthicare.mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import com.swasthicare.mobile.ui.theme.AppColors
import androidx.compose.runtime.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.navigation.DeepLinkHandler
import com.swasthicare.mobile.navigation.DeepLinkRoute
import com.swasthicare.mobile.ui.lock.LockScreen
import com.swasthicare.mobile.ui.lock.LockScreenViewModel
import com.swasthicare.mobile.ui.navigation.AppNavigation
import com.swasthicare.mobile.ui.theme.SwasthiCareTheme
import io.github.jan.supabase.gotrue.handleDeeplinks

class MainActivity : FragmentActivity() {

    // Deep link route parsed from intent, observed by AppNavigation
    private val pendingDeepLink = MutableStateFlow<DeepLinkRoute?>(null)

    private val notifPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            CoroutineScope(Dispatchers.Default).launch {
                AppContainer.notificationService.scheduleAllNotifications()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // AppContainer is already initialized in SwasthiCareApplication.onCreate()

        // Request POST_NOTIFICATIONS permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!com.swasthicare.mobile.data.services.NotificationPermissionManager.hasNotificationPermission(this)) {
                notifPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        // Handle deep link from launch intent
        handleDeepLink(intent)

        setContent {
            SwasthiCareTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = AppColors.background
                ) {
                    val lockViewModel: LockScreenViewModel = viewModel()
                    val isLocked by lockViewModel.isLocked.collectAsState()

                    // Lifecycle observer: lock app when going to background
                    val lifecycleOwner = LocalLifecycleOwner.current
                    DisposableEffect(lifecycleOwner) {
                        val observer = LifecycleEventObserver { _, event ->
                            when (event) {
                                Lifecycle.Event.ON_STOP -> {
                                    // App going to background
                                    if (lockViewModel.isBiometricEnabled) {
                                        lockViewModel.onAppResumed() // This sets isLocked = true
                                    }
                                }
                                Lifecycle.Event.ON_START -> {
                                    // App coming to foreground — lock screen will show if needed
                                }
                                else -> {}
                            }
                        }
                        lifecycleOwner.lifecycle.addObserver(observer)
                        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
                    }

                    // Check initial lock state on first composition
                    LaunchedEffect(Unit) {
                        lockViewModel.checkInitialLock()
                    }

                    val currentDeepLink by pendingDeepLink.collectAsState()

                    Box(modifier = Modifier.fillMaxSize()) {
                        // Only compose the main app when unlocked.
                        // SurfaceView/GLSurfaceView used by the 3D model viewer renders at the
                        // hardware compositor level and punches through any Compose overlay,
                        // so the only safe way to hide it is to remove it from composition.
                        if (!isLocked) {
                            AppNavigation(
                                authViewModel = AppContainer.authViewModel,
                                deepLinkRoute = currentDeepLink,
                                onDeepLinkConsumed = { pendingDeepLink.value = null }
                            )
                        }

                        // Lock screen — rendered when app is locked
                        if (isLocked) {
                            LockScreen(viewModel = lockViewModel)
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

    private fun handleDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return

        // Handle Supabase auth callbacks (email verification, OAuth redirect)
        if (uri.scheme == "swastricareapp" && uri.host == "auth-callback") {
            try {
                AppContainer.supabaseClient.handleDeeplinks(intent = intent) { session ->
                    Log.d("Auth", "Deep link auth session established for: ${session.user?.email}")
                    CoroutineScope(Dispatchers.Main).launch {
                        AppContainer.authViewModel.onAuthCallback()
                    }
                }
            } catch (e: Exception) {
                Log.e("Auth", "Failed to handle auth deep link: ${e.message}", e)
                // Fallback: try to check session anyway (link may have verified the email server-side)
                CoroutineScope(Dispatchers.Main).launch {
                    AppContainer.authViewModel.onAuthCallback()
                }
            }
            return
        }

        // Handle app navigation deep links
        val route = DeepLinkHandler.parse(uri) ?: return
        if (route is DeepLinkRoute.Unknown) return
        pendingDeepLink.value = route
    }
}
