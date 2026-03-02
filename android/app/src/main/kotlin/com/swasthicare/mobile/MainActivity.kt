package com.swasthicare.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.lock.LockScreen
import com.swasthicare.mobile.ui.lock.LockScreenViewModel
import com.swasthicare.mobile.ui.navigation.AppNavigation
import com.swasthicare.mobile.ui.theme.SwasthiCareTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // Initialize AppContainer
        AppContainer.initialize(this)

        setContent {
            SwasthiCareTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
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

                    Box(modifier = Modifier.fillMaxSize()) {
                        // Main app content
                        AppNavigation(authViewModel = AppContainer.authViewModel)

                        // Lock screen overlay
                        if (isLocked) {
                            LockScreen(viewModel = lockViewModel)
                        }
                    }
                }
            }
        }
    }
}
