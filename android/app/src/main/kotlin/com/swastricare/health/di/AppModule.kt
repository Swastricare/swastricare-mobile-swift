package com.swastricare.health.di

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.swastricare.health.BuildConfig
import com.swastricare.health.data.helpers.GoogleAuthHelper
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.CrashlyticsService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for app-level dependencies.
 * Provides services, helpers, and utilities.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    /**
     * Provides GoogleAuthHelper for Google Sign-In flow.
     */
    @Provides
    @Singleton
    fun provideGoogleAuthHelper(
        @ApplicationContext context: Context
    ): GoogleAuthHelper {
        return GoogleAuthHelper(
            applicationContext = context,
            webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID
        )
    }

    /**
     * Provides encrypted SharedPreferences for secure data storage.
     * Falls back to regular SharedPreferences if encryption is not available.
     */
    @Provides
    @Singleton
    fun provideSharedPreferences(
        @ApplicationContext context: Context
    ): SharedPreferences {
        return try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                "swastricare_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            // Fallback to regular SharedPreferences if encryption fails
            context.getSharedPreferences("swastricare_prefs", Context.MODE_PRIVATE)
        }
    }

    /**
     * Provides app analytics service backed by Supabase event pipeline.
     */
    @Provides
    @Singleton
    fun provideAnalyticsService(
        @ApplicationContext context: Context,
        supabaseClient: SupabaseClient
    ): AppAnalyticsService {
        return AppAnalyticsService(context, supabaseClient)
    }

    /**
     * Provides Firebase Crashlytics service.
     */
    @Provides
    @Singleton
    fun provideCrashlyticsService(): CrashlyticsService {
        return CrashlyticsService()
    }
}
