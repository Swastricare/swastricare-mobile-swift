package com.swasthicare.mobile.di

import android.content.Context
import android.content.SharedPreferences
import com.swasthicare.mobile.BuildConfig
import com.swasthicare.mobile.data.SupabaseConfig
import com.swasthicare.mobile.data.helpers.GoogleAuthHelper
import com.swasthicare.mobile.data.repository.*
import com.swasthicare.mobile.data.services.AnalyticsService
import com.swasthicare.mobile.data.services.AppAnalyticsService
import com.swasthicare.mobile.data.services.AppVersionService
import com.swasthicare.mobile.data.services.BiometricService
import com.swasthicare.mobile.data.services.CrashlyticsService
import com.swasthicare.mobile.data.services.HealthConnectService
import com.swasthicare.mobile.data.services.NotificationService
import com.swasthicare.mobile.data.services.PoseDetectionService
import com.swasthicare.mobile.data.services.WeatherService
import com.swasthicare.mobile.ui.screens.auth.AuthViewModel
import com.swasthicare.mobile.ui.screens.diet.DietViewModel
import com.swasthicare.mobile.ui.screens.family.FamilyViewModel
import com.swasthicare.mobile.ui.screens.heartrate.HeartRateViewModel
import com.swasthicare.mobile.ui.screens.hydration.HydrationViewModel
import com.swasthicare.mobile.ui.screens.medications.MedicationsViewModel
import com.swasthicare.mobile.ui.screens.menstrualcycle.MenstrualCycleViewModel
import com.swasthicare.mobile.ui.screens.runactivity.LiveWorkoutViewModel
import com.swasthicare.mobile.ui.screens.runactivity.RunActivityViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import io.github.jan.supabase.functions.Functions

/**
 * App Dependency Container
 * Provides Supabase authentication, repositories, and services.
 */
object AppContainer {

    private var _context: Context? = null

    fun initialize(context: Context) {
        _context = context.applicationContext
    }

    val context: Context
        get() = _context ?: throw IllegalStateException("AppContainer not initialized")

    // Supabase Client - matching iOS
    val supabaseClient: SupabaseClient by lazy {
        createSupabaseClient(
            supabaseUrl = SupabaseConfig.SUPABASE_URL,
            supabaseKey = SupabaseConfig.SUPABASE_KEY
        ) {
            install(Auth) {
                scheme = "swastricareapp"
                host = "auth-callback"
            }
            install(Postgrest)
            install(Realtime)
            install(Storage)
            install(Functions)
        }
    }

    // Google Auth Helper - reads Web Client ID from BuildConfig (set via gradle.properties)
    val googleAuthHelper: GoogleAuthHelper by lazy {
        GoogleAuthHelper(
            context = context,
            webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID
        )
    }

    // Auth Repository
    val authRepository: SupabaseAuthRepository by lazy {
        SupabaseAuthRepository(supabaseClient)
    }

    // Auth ViewModel
    val authViewModel: AuthViewModel by lazy {
        AuthViewModel(authRepository, googleAuthHelper)
    }

    // Shared preferences
    val sharedPreferences: SharedPreferences by lazy {
        context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
    }

    // ── Services ──

    val healthConnectService: HealthConnectService by lazy {
        HealthConnectService(context)
    }

    val biometricService: BiometricService by lazy {
        BiometricService(context)
    }

    val notificationService: NotificationService by lazy {
        NotificationService(context, sharedPreferences)
    }

    // Weather Service (for hydration adjustments)
    val weatherService: WeatherService by lazy {
        WeatherService(context, sharedPreferences)
    }

    // ─────────────────────────────────────
    // MARK: - Firebase / Analytics Services
    // ─────────────────────────────────────

    val firebaseAnalyticsService: AnalyticsService by lazy {
        AnalyticsService()
    }

    val crashlyticsService: CrashlyticsService by lazy {
        CrashlyticsService()
    }

    val appAnalyticsService: AppAnalyticsService by lazy {
        AppAnalyticsService(context, supabaseClient)
    }

    // ─────────────────────────────────────
    // MARK: - New Services (Features 16-18)
    // ─────────────────────────────────────

    // Pose Detection Service (Feature 16: AR Body Scan)
    val poseDetectionService: PoseDetectionService by lazy {
        PoseDetectionService()
    }

    // Analytics Service (Feature 17: Custom Supabase Analytics - Agent 5 instance)
    val analyticsService: AppAnalyticsService by lazy {
        AppAnalyticsService(context, supabaseClient)
    }

    // App Version Service (Feature 18: Force Update Checking)
    val appVersionService: AppVersionService by lazy {
        AppVersionService(context, supabaseClient)
    }

    /**
     * Current app version name from BuildConfig.
     */
    val currentVersionName: String
        get() = BuildConfig.VERSION_NAME

    // ─────────────────────────────────────
    // MARK: - Repositories
    // ─────────────────────────────────────

    val profileRepository: ProfileRepository by lazy {
        MockProfileRepository()
    }

    val vaultRepository: VaultRepository by lazy {
        MockVaultRepository()
    }

    val medicationRepository: MedicationRepository by lazy {
        SupabaseMedicationRepository(supabaseClient, sharedPreferences)
    }

    val medicationsViewModel: MedicationsViewModel by lazy {
        MedicationsViewModel(medicationRepository, profileRepository)
    }

    val dietRepository: DietRepository by lazy {
        SupabaseDietRepository(supabaseClient, sharedPreferences)
    }

    val dietViewModel: DietViewModel by lazy {
        DietViewModel(dietRepository, profileRepository)
    }

    val hydrationRepository: HydrationRepository by lazy {
        SupabaseHydrationRepository(supabaseClient, sharedPreferences)
    }

    val hydrationViewModel: HydrationViewModel by lazy {
        HydrationViewModel(hydrationRepository, profileRepository, weatherService)
    }

    // Family
    val familyRepository: FamilyRepository by lazy {
        SupabaseFamilyRepository(supabaseClient)
    }

    val familyViewModel: FamilyViewModel by lazy {
        FamilyViewModel(familyRepository, authRepository)
    }

    val aiConversationRepository: AIConversationRepository by lazy {
        SupabaseAIConversationRepository(supabaseClient, sharedPreferences)
    }

    // ── Menstrual Cycle ──

    val menstrualCycleRepository: MenstrualCycleRepository by lazy {
        SupabaseMenstrualCycleRepository(supabaseClient, sharedPreferences)
    }

    val menstrualCycleViewModel: MenstrualCycleViewModel by lazy {
        MenstrualCycleViewModel(menstrualCycleRepository, profileRepository)
    }

    // ── Heart Rate ──

    val heartRateViewModel: HeartRateViewModel by lazy {
        HeartRateViewModel(context, supabaseClient)
    }

    // ── Run Activity ──

    val runActivityRepository: RunActivityRepository by lazy {
        SupabaseRunActivityRepository(supabaseClient, sharedPreferences)
    }

    val runActivityViewModel: RunActivityViewModel by lazy {
        RunActivityViewModel(runActivityRepository, profileRepository)
    }

    val liveWorkoutViewModel: LiveWorkoutViewModel by lazy {
        LiveWorkoutViewModel(context, runActivityRepository, profileRepository)
    }

    // Nudge Repository (Feature 10: Live Server Nudges)
    val nudgeRepository: NudgeRepository by lazy {
        SupabaseNudgeRepository(supabaseClient, sharedPreferences)
    }
}
