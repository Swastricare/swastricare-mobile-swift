package com.swastricare.health.ui.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.navigation.NamedNavArgument
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.swastricare.health.data.services.AppUpdateCheckResult
import com.swastricare.health.data.services.AppUpdateStatus
import com.swastricare.health.navigation.DeepLinkHandler
import com.swastricare.health.navigation.DeepLinkRoute
import com.swastricare.health.ui.screens.analytics.HealthAnalyticsScreen
import com.swastricare.health.ui.screens.analytics.HealthMetricDetailScreen
import com.swastricare.health.ui.screens.ar.ARBodyScanScreen
import com.swastricare.health.ui.screens.auth.AuthUiState
import com.swastricare.health.ui.screens.auth.AuthViewModel
import com.swastricare.health.ui.screens.auth.EmailVerificationScreen
import com.swastricare.health.ui.screens.auth.LoginScreen
import com.swastricare.health.ui.screens.auth.NewPasswordScreen
import com.swastricare.health.ui.screens.auth.ResetPasswordScreen
import com.swastricare.health.ui.screens.auth.SignUpScreen
import com.swastricare.health.ui.screens.diet.AddFoodScreen
import com.swastricare.health.ui.screens.diet.DietScreen
import com.swastricare.health.ui.screens.diet.FoodSnapScreen
import com.swastricare.health.ui.screens.family.FamilyScreen
import com.swastricare.health.ui.screens.heartrate.HeartRateAnalyticsScreen
import com.swastricare.health.ui.screens.heartrate.HeartRateScreen
import com.swastricare.health.ui.screens.hydration.HydrationScreen
import com.swastricare.health.ui.screens.hydration.HydrationSettingsScreen
import com.swastricare.health.ui.screens.main.MainScreen
import com.swastricare.health.ui.screens.medications.AddMedicationScreen
import com.swastricare.health.ui.screens.medications.AllMedicationsScreen
import com.swastricare.health.ui.screens.medications.MedicationAnalyticsScreen
import com.swastricare.health.ui.screens.medications.MedicationCalendarScreen
import com.swastricare.health.ui.screens.medications.MedicationDetailScreen
import com.swastricare.health.ui.screens.medications.MedicationsScreen
import com.swastricare.health.ui.screens.menstrualcycle.CycleCalendarScreen
import com.swastricare.health.ui.screens.menstrualcycle.LogPeriodScreen
import com.swastricare.health.ui.screens.menstrualcycle.MenstrualCycleScreen
import com.swastricare.health.ui.screens.menstrualcycle.MenstrualCycleViewModel
import com.swastricare.health.ui.screens.notifications.NotificationHistoryScreen
import com.swastricare.health.ui.screens.notifications.NotificationSettingsScreen
import com.swastricare.health.ui.screens.onboarding.ConsentScreen
import com.swastricare.health.ui.screens.onboarding.HealthProfileScreen
import com.swastricare.health.ui.screens.onboarding.HealthProfileViewModel
import com.swastricare.health.ui.screens.onboarding.OnboardingScreen
import com.swastricare.health.ui.screens.profile.EditProfileScreen
import com.swastricare.health.ui.screens.profile.ProfileViewModel
import com.swastricare.health.ui.screens.runactivity.ActivityDetailScreen
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutScreen
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutViewModel
import com.swastricare.health.ui.screens.runactivity.RunCalendarScreen
import com.swastricare.health.ui.screens.runactivity.WorkoutType
import com.swastricare.health.ui.screens.settings.ActivityGoalsScreen
import com.swastricare.health.ui.screens.settings.GoogleHealthSettingsScreen
import com.swastricare.health.ui.screens.settings.HealthAppId
import com.swastricare.health.ui.screens.settings.HealthConnectSettingsScreen
import com.swastricare.health.ui.screens.settings.HealthDataSyncScreen
import com.swastricare.health.ui.screens.settings.SettingsViewModel
import com.swastricare.health.ui.screens.settings.ThemeSettingsScreen
import com.swastricare.health.ui.screens.sleep.LogSleepScreen
import com.swastricare.health.ui.screens.sleep.SleepScreen
import com.swastricare.health.ui.screens.splash.SplashScreen
import com.swastricare.health.ui.screens.stress.StressAnalyticsScreen
import com.swastricare.health.ui.screens.stress.StressScreen
import com.swastricare.health.ui.screens.update.ForceUpdateScreen
import com.swastricare.health.ui.screens.update.OptionalUpdateDialog
import kotlinx.coroutines.launch

/**
 * Root navigation graph.
 *
 * Architecture:
 *   • "main" hosts [MainScreen] — the 5-tab shell with the bottom nav bar.
 *   • Every detail screen (Medications, Hydration, Diet, Heart Rate, …)
 *     is a sibling of "main" at this top level. Opening one navigates
 *     away from the bottom-nav shell entirely, so detail screens are not
 *     part of the navigation bar's layout and never have the bar visible.
 *   • Auth/onboarding screens are their own top-level destinations.
 *
 * Matches iOS navigation state machine:
 *   Splash → ForceUpdate? → Onboarding → Consent → Login →
 *   HealthProfile? → Main ⇆ (Medications, Hydration, … detail screens)
 */
@Composable
fun AppNavigation(
    authViewModel: AuthViewModel,
    deepLinkRoute: DeepLinkRoute? = null,
    onDeepLinkConsumed: () -> Unit = {}
) {
    val navVm: AppNavigationViewModel = hiltViewModel()
    val navController = rememberNavController()
    val authState by authViewModel.uiState.collectAsState()
    val isProcessingDeepLink by authViewModel.isProcessingDeepLink.collectAsState()
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current

    // Version check state (matches iOS AppVersionService flow)
    var updateResult by remember { mutableStateOf<AppUpdateCheckResult?>(null) }
    var showOptionalDialog by remember { mutableStateOf(false) }

    suspend fun performVersionCheck() {
        val result = navVm.checkForUpdate() ?: return
        updateResult = result
        if (result.status == AppUpdateStatus.OPTIONAL_UPDATE &&
            navVm.shouldShowOptionalUpdate()
        ) {
            showOptionalDialog = true
        }
    }

    LaunchedEffect(Unit) {
        performVersionCheck()
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch { performVersionCheck() }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    if (updateResult?.status == AppUpdateStatus.FORCE_UPDATE) {
        ForceUpdateScreen(
            currentVersion = navVm.currentVersionName,
            latestVersion = updateResult?.record?.latestVersion ?: "",
            updateTitle = updateResult?.record?.updateTitle,
            updateMessage = updateResult?.record?.updateMessage,
            storeUrl = updateResult?.record?.updateUrl
        )
        return
    }

    val isSessionExpired by navVm.sessionManager.isSessionExpired.collectAsState()

    LaunchedEffect(isSessionExpired) {
        if (isSessionExpired) {
            authViewModel.onSessionExpired()
            navVm.sessionManager.clearExpiredFlag()
            navController.navigate("login") {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    LaunchedEffect(authState) {
        if (authState is AuthUiState.PasswordRecovery) {
            navController.navigate("new_password") {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    // Deep link handling — routes to either a tab (handled inside MainScreen)
    // or a top-level detail route (handled here by the root NavController).
    LaunchedEffect(deepLinkRoute) {
        if (deepLinkRoute != null) {
            val navRoute = DeepLinkHandler.toNavRoute(deepLinkRoute)
            val isTabRoute = BottomNavTab.isTabRoute(navRoute)
            if (isTabRoute) {
                // Tab routes can't be navigated to directly from the root —
                // route to "main" (MainScreen manages its inner tab state).
                // TODO: for proper tab selection on deep link, surface a hook.
                navController.navigate("main") {
                    popUpTo("main") { inclusive = true }
                }
            } else {
                navController.navigate(navRoute) {
                    launchSingleTop = true
                }
            }
            onDeepLinkConsumed()
        }
    }

    NavHost(
        navController = navController,
        startDestination = "splash",
        enterTransition = { pushEnter },
        exitTransition = { pushExit },
        popEnterTransition = { popEnter },
        popExitTransition = { popExit }
    ) {
        // ═══════════════════════════════════════════════════════════
        // Boot / auth flow
        // ═══════════════════════════════════════════════════════════
        composable("splash") {
            SplashScreen(
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("splash") { inclusive = true }
                    }
                },
                onNavigateToLogin = {
                    navController.navigate("login") {
                        popUpTo("splash") { inclusive = true }
                    }
                },
                onNavigateToOnboarding = {
                    navController.navigate("onboarding") {
                        popUpTo("splash") { inclusive = true }
                    }
                }
            )
        }

        composable("onboarding") {
            OnboardingScreen(
                onFinished = {
                    navController.navigate("consent")
                },
                onSignIn = {
                    scope.launch { navVm.markOnboardingComplete() }
                    navController.navigate("login") {
                        popUpTo("onboarding") { inclusive = true }
                    }
                }
            )
        }

        composable("consent") {
            ConsentScreen(
                onAccepted = {
                    scope.launch { navVm.markOnboardingComplete() }
                    navController.navigate("login") {
                        popUpTo("consent") { inclusive = true }
                    }
                },
                onBack = {
                    if (!navController.popBackStack()) {
                        navController.navigate("onboarding") {
                            popUpTo("consent") { inclusive = true }
                        }
                    }
                }
            )
        }

        composable("login") {
            LoginScreen(
                viewModel = authViewModel,
                onNavigateToSignUp = { navController.navigate("signup") },
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onNavigateToResetPassword = {
                    navController.navigate("reset_password")
                }
            )
        }

        composable("signup") {
            SignUpScreen(
                viewModel = authViewModel,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onNavigateToEmailVerification = {
                    navController.navigate("email_verification") {
                        popUpTo("signup") { inclusive = true }
                    }
                }
            )
        }

        composable("email_verification") {
            EmailVerificationScreen(
                viewModel = authViewModel,
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onNavigateBack = {
                    navController.navigate("signup") {
                        popUpTo("email_verification") { inclusive = true }
                    }
                }
            )
        }

        composable("reset_password") {
            ResetPasswordScreen(
                viewModel = authViewModel,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable("new_password") {
            NewPasswordScreen(
                viewModel = authViewModel,
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }

        composable("health_profile") {
            val healthProfileVm: HealthProfileViewModel = hiltViewModel()
            val userId = authState.let {
                (it as? AuthUiState.Success)?.user?.id ?: ""
            }
            HealthProfileScreen(
                userId = userId,
                profileRepository = healthProfileVm.profileRepository,
                onCompleted = {
                    navController.navigate("main") {
                        popUpTo("health_profile") { inclusive = true }
                    }
                }
            )
        }

        // ═══════════════════════════════════════════════════════════
        // Main (bottom-nav shell)
        // ═══════════════════════════════════════════════════════════
        composable("main") {
            MainScreen(
                onSignOut = {
                    navVm.sessionManager.clearExpiredFlag()
                    authViewModel.signOut()
                    navController.navigate("login") {
                        popUpTo("main") { inclusive = true }
                    }
                },
                onNavigateTo = { route ->
                    try { navController.navigate(route) } catch (_: Exception) { }
                }
            )
        }

        // ═══════════════════════════════════════════════════════════
        // Detail screens (top-level — not part of the bottom-nav shell)
        // ═══════════════════════════════════════════════════════════
        addDetailRoutes(navController)
    }

    if (isProcessingDeepLink) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.5f)),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
        }
    }

    if (showOptionalDialog && updateResult != null) {
        OptionalUpdateDialog(
            newVersion = updateResult?.record?.latestVersion ?: "",
            updateTitle = updateResult?.record?.updateTitle,
            updateMessage = updateResult?.record?.updateMessage,
            storeUrl = updateResult?.record?.updateUrl,
            onDismiss = {
                showOptionalDialog = false
                navVm.dismissOptionalUpdate()
            }
        )
    }
}

// ── Transition specs ──
private val pushEnter = slideInHorizontally(
    animationSpec = tween(durationMillis = 260),
    initialOffsetX = { it / 6 }
) + fadeIn(animationSpec = tween(durationMillis = 220))

private val pushExit = fadeOut(animationSpec = tween(durationMillis = 180))

private val popEnter = fadeIn(animationSpec = tween(durationMillis = 220))

private val popExit = slideOutHorizontally(
    animationSpec = tween(durationMillis = 260),
    targetOffsetX = { it / 6 }
) + fadeOut(animationSpec = tween(durationMillis = 220))

/**
 * Adds a top-level detail route. By default the screen is wrapped in a
 * `Box.statusBarsPadding()` so its content doesn't draw under the system
 * clock — this replaces the `innerPadding` that [MainScaffold]'s inner
 * Scaffold used to provide before these routes were lifted out of it.
 *
 * Screens that intentionally paint under the status bar (e.g. Hydration's
 * full-bleed gradient, AR body scan, Live Workout) can opt out via
 * `immersive = true` and handle insets themselves.
 */
private fun NavGraphBuilder.detailComposable(
    route: String,
    arguments: List<NamedNavArgument> = emptyList(),
    immersive: Boolean = false,
    content: @Composable (NavBackStackEntry) -> Unit
) {
    composable(route = route, arguments = arguments) { entry ->
        if (immersive) {
            content(entry)
        } else {
            Box(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
                content(entry)
            }
        }
    }
}

/**
 * All detail routes opened from the bottom-nav shell. Each lives at the
 * top level of [AppNavigation] so it renders without the nav bar and
 * pops back to "main" via standard back navigation.
 */
private fun NavGraphBuilder.addDetailRoutes(
    navController: NavHostController
) {
    // ─── Activity Goals ───
    detailComposable("activity_goals") {
        ActivityGoalsScreen(
            onNavigateBack = { navController.popBackStack() }
        )
    }

    // ─── Theme Settings ───
    detailComposable("theme_settings") {
        val settingsViewModel: SettingsViewModel = hiltViewModel()
        ThemeSettingsScreen(
            themePreferenceManager = settingsViewModel.themePreferenceManager,
            onNavigateBack = { navController.popBackStack() }
        )
    }

    // ─── Medications ───
    detailComposable("medications") {
        MedicationsScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToAddMedication = { navController.navigate("add_medication") },
            onNavigateToDetail = { id -> navController.navigate("medication_detail/$id") },
            onNavigateToAI = { navController.popBackStack("main", inclusive = false) },
            onNavigateToAllMedications = { navController.navigate("all_medications") },
            onNavigateToNotifications = { navController.navigate("notification_settings") },
            onNavigateToCalendar = { navController.navigate("medication_calendar") },
            onNavigateToAnalytics = { navController.navigate("medication_analytics") }
        )
    }

    detailComposable("add_medication") {
        AddMedicationScreen(onDismiss = { navController.popBackStack() })
    }

    detailComposable("all_medications") {
        AllMedicationsScreen(
            onBack = { navController.popBackStack() },
            onNavigateToDetail = { id -> navController.navigate("medication_detail/$id") },
            onNavigateToAddMedication = { navController.navigate("add_medication") }
        )
    }

    detailComposable(
        route = "medication_detail/{${NavArgs.MEDICATION_ID}}",
        arguments = listOf(navArgument(NavArgs.MEDICATION_ID) { type = NavType.StringType })
    ) { backStackEntry ->
        val id = backStackEntry.arguments?.getString(NavArgs.MEDICATION_ID) ?: return@detailComposable
        MedicationDetailScreen(
            medicationId = id,
            onBack = { navController.popBackStack() }
        )
    }

    detailComposable("medication_calendar") {
        MedicationCalendarScreen(
            onBack = { navController.popBackStack() },
            onAddMedication = { navController.navigate("add_medication") }
        )
    }

    detailComposable("medication_analytics") {
        MedicationAnalyticsScreen(onBack = { navController.popBackStack() })
    }

    // ─── Diet ───
    detailComposable("diet") {
        DietScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToAddFood = { mt -> navController.navigate("add_food/$mt") },
            onNavigateToFoodSearch = { mt -> navController.navigate("add_food/$mt") },
            onNavigateToAI = { navController.popBackStack("main", inclusive = false) },
            onNavigateToFoodSnap = { mt -> navController.navigate("food_snap/$mt") }
        )
    }

    detailComposable(
        route = "add_food/{${NavArgs.MEAL_TYPE}}",
        arguments = listOf(
            navArgument(NavArgs.MEAL_TYPE) {
                type = NavType.StringType
                defaultValue = "breakfast"
            }
        )
    ) { backStackEntry ->
        val mealTypeDb = backStackEntry.arguments?.getString(NavArgs.MEAL_TYPE) ?: "breakfast"
        AddFoodScreen(
            initialMealTypeDb = mealTypeDb,
            onDismiss = { navController.popBackStack() },
            onNavigateToFoodSnap = { mt -> navController.navigate("food_snap/$mt") }
        )
    }

    detailComposable(
        route = "food_snap/{${NavArgs.MEAL_TYPE}}",
        arguments = listOf(
            navArgument(NavArgs.MEAL_TYPE) {
                type = NavType.StringType
                defaultValue = "breakfast"
            }
        )
    ) { backStackEntry ->
        val mealTypeDb = backStackEntry.arguments?.getString(NavArgs.MEAL_TYPE) ?: "breakfast"
        FoodSnapScreen(
            mealTypeDb = mealTypeDb,
            onDismiss = { navController.popBackStack() },
            onNavigateToAddFood = { mt -> navController.navigate("add_food/$mt") }
        )
    }

    // ─── Hydration (immersive: gradient paints under the status bar) ───
    detailComposable("hydration", immersive = true) {
        HydrationScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToAI = { navController.popBackStack("main", inclusive = false) },
            onNavigateToSettings = { navController.navigate("hydration_settings") }
        )
    }

    detailComposable("hydration_settings") {
        HydrationSettingsScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToNotifications = { navController.navigate("notification_settings") }
        )
    }

    // ─── Menstrual Cycle ───
    detailComposable("cycle_tracker") {
        MenstrualCycleScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToLog = { navController.navigate("cycle_log") },
            onNavigateToCalendar = { navController.navigate("cycle_calendar") }
        )
    }

    detailComposable("cycle_calendar") {
        CycleCalendarScreen(onNavigateBack = { navController.popBackStack() })
    }

    detailComposable("cycle_log") {
        val viewModel: MenstrualCycleViewModel = hiltViewModel()
        LogPeriodScreen(
            viewModel = viewModel,
            onNavigateBack = { navController.popBackStack() }
        )
    }

    // ─── Heart Rate ───
    detailComposable("heart_rate") {
        HeartRateScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToAnalytics = { navController.navigate("heart_rate_analytics") },
            onNavigateToAI = { navController.popBackStack("main", inclusive = false) }
        )
    }

    detailComposable("heart_rate_analytics") {
        HeartRateAnalyticsScreen(onNavigateBack = { navController.popBackStack() })
    }

    // ─── Stress ───
    detailComposable("stress") {
        StressScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToAnalytics = { navController.navigate("stress_analytics") }
        )
    }

    detailComposable("stress_analytics") {
        StressAnalyticsScreen(onNavigateBack = { navController.popBackStack() })
    }

    // ─── Sleep ───
    detailComposable("sleep") {
        SleepScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToLog = { navController.navigate("sleep/log") }
        )
    }

    detailComposable("sleep/log") {
        LogSleepScreen(onNavigateBack = { navController.popBackStack() })
    }

    // ─── AR Body Scan (immersive full-screen) ───
    detailComposable("ar_body_scan", immersive = true) {
        ARBodyScanScreen(onNavigateBack = { navController.popBackStack() })
    }

    // ─── Live Workout (immersive full-screen) ───
    detailComposable(
        route = "live_workout?${NavArgs.WORKOUT_TYPE}={${NavArgs.WORKOUT_TYPE}}",
        arguments = listOf(
            navArgument(NavArgs.WORKOUT_TYPE) {
                type = NavType.StringType
                defaultValue = ""
            }
        ),
        immersive = true
    ) { backStackEntry ->
        val workoutTypeArg = backStackEntry.arguments?.getString(NavArgs.WORKOUT_TYPE) ?: ""
        val liveWorkoutViewModel: LiveWorkoutViewModel = hiltViewModel()
        if (workoutTypeArg.isNotEmpty()) {
            val wType = try {
                WorkoutType.valueOf(workoutTypeArg.uppercase())
            } catch (_: IllegalArgumentException) { null }
            if (wType != null) liveWorkoutViewModel.setWorkoutType(wType)
        }
        LiveWorkoutScreen(onNavigateBack = { navController.popBackStack() })
    }

    // ─── Run Calendar ───
    detailComposable("run_calendar") {
        RunCalendarScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToActivityDetail = { workoutId ->
                navController.navigate("activity_detail/$workoutId")
            }
        )
    }

    // ─── Health Analytics ───
    detailComposable("health_analytics") {
        HealthAnalyticsScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToAI = { navController.popBackStack("main", inclusive = false) },
            onNavigateToMetricDetail = { metric ->
                navController.navigate("metric_detail/${metric.name}")
            }
        )
    }

    detailComposable(
        route = "metric_detail/{${NavArgs.METRIC_TYPE}}",
        arguments = listOf(navArgument(NavArgs.METRIC_TYPE) { type = NavType.StringType })
    ) { backStackEntry ->
        val metricName = backStackEntry.arguments?.getString(NavArgs.METRIC_TYPE) ?: "Steps"
        HealthMetricDetailScreen(
            metricTypeName = metricName,
            onNavigateBack = { navController.popBackStack() }
        )
    }

    // ─── Activity Detail ───
    detailComposable(
        route = "activity_detail/{${NavArgs.WORKOUT_ID}}",
        arguments = listOf(navArgument(NavArgs.WORKOUT_ID) { type = NavType.StringType })
    ) { backStackEntry ->
        val workoutId = backStackEntry.arguments?.getString(NavArgs.WORKOUT_ID) ?: return@detailComposable
        ActivityDetailScreen(
            workoutId = workoutId,
            onNavigateBack = { navController.popBackStack() },
            onDelete = { navController.popBackStack() }
        )
    }

    // ─── Family ───
    detailComposable("family") {
        FamilyScreen(onNavigateBack = { navController.popBackStack() })
    }

    detailComposable(
        route = "family_join/{${NavArgs.FAMILY_CODE}}",
        arguments = listOf(navArgument(NavArgs.FAMILY_CODE) { type = NavType.StringType })
    ) { backStackEntry ->
        val code = backStackEntry.arguments?.getString(NavArgs.FAMILY_CODE) ?: ""
        FamilyScreen(
            onNavigateBack = { navController.popBackStack() },
            initialJoinCode = code
        )
    }

    // ─── Settings & Profile ───
    detailComposable("notification_settings") {
        NotificationSettingsScreen(onNavigateBack = { navController.popBackStack() })
    }

    detailComposable("notification_history") {
        NotificationHistoryScreen(onNavigateBack = { navController.popBackStack() })
    }

    detailComposable("edit_profile") {
        // Each top-level entry creates a fresh ProfileViewModel — acceptable
        // since edit_profile is a terminal detail screen.
        val profileViewModel: ProfileViewModel = hiltViewModel()
        EditProfileScreen(
            viewModel = profileViewModel,
            onNavigateBack = { navController.popBackStack() }
        )
    }

    // ─── Health Data Sync ───
    detailComposable("health_data_sync") {
        HealthDataSyncScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateTo = { appId ->
                when (appId) {
                    HealthAppId.HEALTH_CONNECT -> navController.navigate("health_connect_settings")
                    else -> { /* Removed apps */ }
                }
            }
        )
    }

    detailComposable("health_connect_settings") {
        HealthConnectSettingsScreen(onNavigateBack = { navController.popBackStack() })
    }

    detailComposable("google_health_settings") {
        GoogleHealthSettingsScreen(
            onNavigateBack = { navController.popBackStack() },
            onNavigateToHealthConnect = { navController.navigate("health_connect_settings") }
        )
    }
}
