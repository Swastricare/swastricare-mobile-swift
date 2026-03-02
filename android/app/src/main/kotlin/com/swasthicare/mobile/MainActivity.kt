package com.swasthicare.mobile

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.navigation.DeepLinkHandler
import com.swasthicare.mobile.navigation.DeepLinkRoute
import com.swasthicare.mobile.ui.navigation.AppNavigation
import com.swasthicare.mobile.ui.theme.SwasthiCareTheme

class MainActivity : ComponentActivity() {

    // Deep link route parsed from intent, observed by AppNavigation
    private val pendingDeepLink = mutableStateOf<DeepLinkRoute?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // Initialize AppContainer
        AppContainer.initialize(this)

        // Handle deep link from launch intent
        handleDeepLink(intent)

        setContent {
            SwasthiCareTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AppNavigation(
                        authViewModel = AppContainer.authViewModel,
                        deepLinkRoute = pendingDeepLink.value,
                        onDeepLinkConsumed = { pendingDeepLink.value = null }
                    )
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
        val route = DeepLinkHandler.parse(uri) ?: return
        if (route is DeepLinkRoute.Unknown) return
        pendingDeepLink.value = route
    }
}
