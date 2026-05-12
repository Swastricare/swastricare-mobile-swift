package com.swastricare.health.di

import android.content.Context
import android.content.SharedPreferences
import com.swastricare.health.core.logger.CrashReporter
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.logger.LoggerImpl
import com.swastricare.health.data.repository.ProfileRepository
import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.data.repository.SupabaseRunActivityRepository
import com.swastricare.health.data.services.AIService
import com.swastricare.health.data.services.HeartRateDetectorServiceImpl
import com.swastricare.health.domain.usecase.heartrate.HeartRateDetectorService
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.BiometricService
import com.swastricare.health.data.services.CrashlyticsService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.data.services.NotificationService
import com.swastricare.health.data.services.CacheService
import com.swastricare.health.data.services.NetworkMonitorService
import com.swastricare.health.data.services.SessionManager
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for service dependencies.
 * Provides singleton instances of service classes.
 */
@Module
@InstallIn(SingletonComponent::class)
object ServiceModule {

    /**
     * Provides AIService singleton.
     * Used for AI-powered features like chat, food analysis, health insights.
     */
    @Provides
    @Singleton
    fun provideAIService(
        supabaseClient: SupabaseClient
    ): AIService {
        return AIService(supabaseClient)
    }

    /**
     * Provides HealthConnectService singleton.
     * Requires Context and CrashlyticsService for Health Connect access.
     */
    @Provides
    @Singleton
    fun provideHealthConnectService(
        @ApplicationContext context: Context,
        crashlyticsService: CrashlyticsService
    ): HealthConnectService {
        return HealthConnectService(context, crashlyticsService)
    }

    /**
     * Provides SupabaseAuthRepository (data-layer concrete type, not yet domain-abstracted).
     * Used directly by AuthViewModel.
     */
    @Provides
    @Singleton
    fun provideSupabaseAuthRepository(
        supabaseClient: SupabaseClient,
        sharedPreferences: SharedPreferences,
        cacheService: CacheService,
        dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
    ): SupabaseAuthRepository {
        return SupabaseAuthRepository(supabaseClient, sharedPreferences, cacheService, dataStore)
    }

    /**
     * Provides Firebase AnalyticsService singleton.
     * No constructor parameters — Firebase initialises itself via google-services.json.
     */
    @Provides
    @Singleton
    fun provideFirebaseAnalyticsService(): AnalyticsService {
        return AnalyticsService()
    }

    /**
     * Provides NotificationService singleton.
     * Requires Context for AlarmManager / NotificationManager access and
     * SharedPreferences to persist per-category toggle state.
     */
    @Provides
    @Singleton
    fun provideNotificationService(
        @ApplicationContext context: Context,
        sharedPreferences: SharedPreferences
    ): NotificationService {
        return NotificationService(context, sharedPreferences)
    }

    /**
     * Provides BiometricService singleton.
     * Requires Context for BiometricManager / BiometricPrompt access.
     */
    @Provides
    @Singleton
    fun provideBiometricService(
        @ApplicationContext context: Context
    ): BiometricService {
        return BiometricService(context)
    }

    /**
     * Provides SessionManager singleton.
     * Observes Supabase auth session, detects token expiry, and registers the
     * device's FCM token on each successful authentication.
     */
    @Provides
    @Singleton
    fun provideSessionManager(
        supabaseClient: SupabaseClient,
        deviceTokenRepository: com.swastricare.health.data.repository.DeviceTokenRepository,
        @ApplicationContext context: Context
    ): SessionManager {
        return SessionManager(supabaseClient, deviceTokenRepository, context)
    }

    @Provides
    @Singleton
    fun provideNetworkMonitorService(
        @ApplicationContext context: Context
    ): NetworkMonitorService {
        return NetworkMonitorService(context)
    }

    @Provides
    @Singleton
    fun provideCacheService(
        sharedPreferences: SharedPreferences
    ): CacheService {
        return CacheService(sharedPreferences)
    }

    /**
     * Provides the data-layer ProfileRepository (SupabaseProfileRepository).
     * Used by ProfileViewModel and SettingsViewModel which pre-date the domain-layer migration.
     * This is com.swastricare.health.data.repository.ProfileRepository — a distinct type
     * from the domain interface (com.swastricare.health.domain.repository.ProfileRepository),
     * so no qualifier is needed.
     */
    @Provides
    @Singleton
    fun provideDataLayerProfileRepository(
        supabaseClient: SupabaseClient
    ): ProfileRepository {
        return SupabaseProfileRepository(supabaseClient)
    }

    /**
     * Provides the data-layer RunActivityRepository (SupabaseRunActivityRepository).
     * Used by RunActivityViewModel and LiveWorkoutViewModel which use the data-layer interface.
     */
    @Provides
    @Singleton
    fun provideDataLayerRunActivityRepository(
        impl: SupabaseRunActivityRepository
    ): com.swastricare.health.data.repository.RunActivityRepository {
        return impl
    }
}

/**
 * Abstract module for interface-to-implementation bindings.
 * Kept separate from ServiceModule (object) because @Binds requires an abstract class.
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class ServiceBindsModule {

    /**
     * Binds CrashlyticsService as the CrashReporter implementation.
     */
    @Binds
    @Singleton
    abstract fun bindCrashReporter(impl: CrashlyticsService): CrashReporter

    /**
     * Binds LoggerImpl as the Logger implementation.
     */
    @Binds
    @Singleton
    abstract fun bindLogger(impl: LoggerImpl): Logger

    /**
     * Binds HeartRateDetectorServiceImpl as the HeartRateDetectorService implementation.
     */
    @Binds
    @Singleton
    abstract fun bindHeartRateDetectorService(impl: HeartRateDetectorServiceImpl): HeartRateDetectorService
}
