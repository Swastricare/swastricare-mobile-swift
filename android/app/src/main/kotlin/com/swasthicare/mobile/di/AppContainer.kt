package com.swasthicare.mobile.di

import android.content.Context
import android.content.SharedPreferences
import com.swasthicare.mobile.data.SupabaseConfig
import com.swasthicare.mobile.data.helpers.GoogleAuthHelper
import com.swasthicare.mobile.data.repository.*
import com.swasthicare.mobile.ui.screens.auth.AuthViewModel
import com.swasthicare.mobile.ui.screens.diet.DietViewModel
import com.swasthicare.mobile.ui.screens.hydration.HydrationViewModel
import com.swasthicare.mobile.ui.screens.medications.MedicationsViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import io.github.jan.supabase.functions.Functions

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
            // TODO: Replace with your Google Web Client ID from Supabase Dashboard
            // Steps:
            // 1. Go to https://supabase.com/dashboard/project/jlumbeyukpnuicyxzvre/auth/providers
            // 2. Enable Google provider
            // 3. Add Android package name: com.swasthicare.mobile
            // 4. Add SHA-1 certificate fingerprint
            // 5. Copy the Web Client ID from Google Cloud Console
            webClientId = "YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com"
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

    // Other repositories
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
        HydrationViewModel(hydrationRepository, profileRepository)
    }
}
