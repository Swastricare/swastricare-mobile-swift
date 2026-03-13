package com.swastricare.health.di

import android.content.Context
import com.swastricare.health.BuildConfig
import com.swastricare.health.data.helpers.GoogleAuthHelper
import com.swastricare.health.data.services.AppAnalyticsService
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

}
