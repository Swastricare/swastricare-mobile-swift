package com.swasthicare.mobile.di

import android.content.Context
import android.content.SharedPreferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.swasthicare.mobile.data.SupabaseConfig
import com.swasthicare.mobile.data.helpers.GoogleAuthHelper
import com.swasthicare.mobile.data.repository.*
import com.swasthicare.mobile.ui.screens.auth.AuthViewModel
import com.swasthicare.mobile.ui.screens.diet.DietViewModel
import com.swasthicare.mobile.ui.screens.hydration.HydrationViewModel
import com.swasthicare.mobile.ui.screens.medications.MedicationsViewModel
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.HealthConnectService
import com.swasthicare.mobile.data.services.SpeechService
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import io.github.jan.supabase.functions.Functions

// Extension property for DataStore
private val Context.dataStore by preferencesDataStore(name = "swasthicare_settings")

// DataStore keys for navigation state
val ONBOARDING_COMPLETE_KEY = booleanPreferencesKey("onboarding_complete")
val CONSENT_ACCEPTED_KEY = booleanPreferencesKey("consent_accepted")
val HEALTH_PROFILE_COMPLETE_KEY = booleanPreferencesKey("health_profile_complete")

/**
 * App Dependency Container
 * Provides Supabase authentication and repositories
 */
object AppContainer {
    
    private var _context: Context? = null
    
    fun initialize(context: Context) {
        _context = context.applicationContext
    }
    
    private val context: Context
        get() = _context ?: throw IllegalStateException("AppContainer not initialized")

    /** Public accessor for services that need application context (e.g. notifications) */
    val appContext: Context
        get() = context
    
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
    
    // Google Auth Helper
    val googleAuthHelper: GoogleAuthHelper by lazy {
        GoogleAuthHelper(
            context = context,
            webClientId = "5434673166-6r2i53pm96o9otvhd5ms0k2ogf0gvqul.apps.googleusercontent.com"
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

    // DataStore for persisting settings
    val dataStore get() = context.dataStore

    // AI Services
    val aiService: AIService by lazy {
        AIService(supabaseClient)
    }

    val speechService: SpeechService by lazy {
        SpeechService(context)
    }

    // Health Connect
    val healthConnectService: HealthConnectService by lazy {
        HealthConnectService(context)
    }

    // Other repositories
    val profileRepository: ProfileRepository by lazy {
        SupabaseProfileRepository(supabaseClient)
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
        HydrationViewModel(hydrationRepository, profileRepository)
    }
}
