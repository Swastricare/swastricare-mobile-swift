package com.swasthicare.mobile.di

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.core.content.edit
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.swastricare.health.BuildConfig
import com.swasthicare.mobile.data.SupabaseConfig
import com.swasthicare.mobile.data.helpers.GoogleAuthHelper
import com.swasthicare.mobile.data.repository.*
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.AnalyticsService
import com.swasthicare.mobile.data.services.AppAnalyticsService
import com.swasthicare.mobile.data.services.AppVersionService
import com.swasthicare.mobile.data.services.BiometricService
import com.swasthicare.mobile.data.services.CrashlyticsService
import com.swasthicare.mobile.data.services.HealthConnectService
import com.swasthicare.mobile.data.services.AppointmentAlarmScheduler
import com.swasthicare.mobile.data.services.CycleNotificationScheduler
import com.swasthicare.mobile.data.services.MedicationAlarmScheduler
import com.swasthicare.mobile.data.services.NotificationService
import com.swasthicare.mobile.data.services.PoseDetectionService
import com.swasthicare.mobile.data.services.SessionManager
import com.swasthicare.mobile.data.services.WeatherService
import com.swasthicare.mobile.data.services.WorkoutStateManager
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

// DataStore extension on Context (single instance per process)
private val Context.appDataStore: DataStore<Preferences> by preferencesDataStore(name = "swasthicare_settings")

// Preference keys used by SplashScreen and AppNavigation
val ONBOARDING_COMPLETE_KEY = booleanPreferencesKey("onboarding_complete")
val CONSENT_ACCEPTED_KEY = booleanPreferencesKey("consent_accepted")

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

    // DataStore for persistent preferences (onboarding, consent, etc.)
    val dataStore: DataStore<Preferences>
        get() = context.appDataStore

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
            applicationContext = context,
            webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID
        )
    }

    // Auth Repository
    val authRepository: SupabaseAuthRepository by lazy {
        SupabaseAuthRepository(supabaseClient, sharedPreferences)
    }

    // Auth ViewModel
    val authViewModel: AuthViewModel by lazy {
        AuthViewModel(authRepository, googleAuthHelper)
    }

    // Shared preferences — encrypted at rest (AES-256-GCM) with automatic migration
    // from the old plain-text "swasthicare_prefs" file on first launch after upgrade.
    // Falls back to unencrypted prefs on devices with broken Keystore implementations.
    val sharedPreferences: SharedPreferences by lazy {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val encrypted = EncryptedSharedPreferences.create(
                context,
                "swasthicare_prefs_encrypted",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            migratePrefsIfNeeded(context, encrypted)
            encrypted
        } catch (e: Exception) {
            Log.w("AppContainer", "EncryptedSharedPreferences unavailable, using plain", e)
            context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
        }
    }

    /**
     * One-time migration: copies all entries from the old unencrypted
     * "swasthicare_prefs" file into the new encrypted store, then clears the old file.
     */
    private fun migratePrefsIfNeeded(context: Context, encrypted: SharedPreferences) {
        val old = context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
        if (old.all.isEmpty()) return

        Log.i("AppContainer", "Migrating ${old.all.size} prefs to EncryptedSharedPreferences")
        encrypted.edit {
            old.all.forEach { (key, value) ->
                when (value) {
                    is String -> putString(key, value)
                    is Int -> putInt(key, value)
                    is Boolean -> putBoolean(key, value)
                    is Long -> putLong(key, value)
                    is Float -> putFloat(key, value)
                    is Set<*> -> putStringSet(key, value.filterIsInstance<String>().toSet())
                }
            }
        }
        old.edit { clear() }
        Log.i("AppContainer", "SharedPreferences migration complete")
    }

    // ── Services ──

    val healthConnectService: HealthConnectService by lazy {
        HealthConnectService(context)
    }

    val biometricService: BiometricService by lazy {
        BiometricService(context)
    }

    // Session Manager — observes Supabase auth session and detects token expiry
    val sessionManager: SessionManager by lazy {
        SessionManager(supabaseClient)
    }

    val notificationService: NotificationService by lazy {
        NotificationService(context, sharedPreferences)
    }

    val medicationAlarmScheduler: MedicationAlarmScheduler by lazy {
        MedicationAlarmScheduler(context)
    }

    val appointmentAlarmScheduler: AppointmentAlarmScheduler by lazy {
        AppointmentAlarmScheduler(context)
    }

    val cycleNotificationScheduler: CycleNotificationScheduler by lazy {
        CycleNotificationScheduler(context)
    }

    val aiService: AIService by lazy {
        AIService(supabaseClient)
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
        SupabaseProfileRepository(supabaseClient)
    }

    val vaultRepository: VaultRepository by lazy {
        SupabaseVaultRepository(supabaseClient)
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
        MenstrualCycleViewModel()
    }

    // ── Heart Rate ──

    val heartRateViewModel: HeartRateViewModel by lazy {
        HeartRateViewModel(context, sharedPreferences)
    }

    // ── Run Activity ──

    val runActivityRepository: RunActivityRepository by lazy {
        SupabaseRunActivityRepository(supabaseClient, sharedPreferences)
    }

    val runActivityViewModel: RunActivityViewModel by lazy {
        RunActivityViewModel(runActivityRepository, profileRepository)
    }

    val liveWorkoutViewModel: LiveWorkoutViewModel by lazy {
        LiveWorkoutViewModel(context, workoutStateManager)
    }

    // ── Workout Recovery ──

    val workoutStateManager: WorkoutStateManager by lazy {
        WorkoutStateManager(sharedPreferences)
    }

    // Nudge Repository (Feature 10: Live Server Nudges)
    val nudgeRepository: NudgeRepository by lazy {
        SupabaseNudgeRepository(supabaseClient, sharedPreferences)
    }
}
