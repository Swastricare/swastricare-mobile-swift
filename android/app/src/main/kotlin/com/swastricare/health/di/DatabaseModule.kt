package com.swastricare.health.di

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
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Qualifier
import javax.inject.Singleton

// DataStore extension on Context (single instance per process)
private val Context.appDataStore: DataStore<Preferences> by preferencesDataStore(name = "swastricare_settings")

// Preference keys used by SplashScreen and AppNavigation
val ONBOARDING_COMPLETE_KEY = booleanPreferencesKey("onboarding_complete")
val CONSENT_ACCEPTED_KEY = booleanPreferencesKey("consent_accepted")

/**
 * Qualifier for encrypted SharedPreferences.
 */
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class EncryptedPrefs

/**
 * Qualifier for regular SharedPreferences.
 */
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class RegularPrefs

/**
 * Hilt module for database and storage dependencies.
 * Provides SharedPreferences (encrypted and regular) and DataStore.
 */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    private const val TAG = "DatabaseModule"
    private const val ENCRYPTED_PREFS_NAME = "swastricare_secure_prefs"
    private const val REGULAR_PREFS_NAME = "swastricare_prefs"
    private const val MIGRATION_KEY = "encrypted_prefs_migrated"

    /**
     * Provides encrypted SharedPreferences for sensitive data storage.
     * Uses AES-256-GCM encryption with automatic fallback migration if encryption fails.
     */
    @Provides
    @Singleton
    @EncryptedPrefs
    fun provideEncryptedSharedPreferences(
        @ApplicationContext context: Context,
        @RegularPrefs regularPrefs: SharedPreferences
    ): SharedPreferences {
        // Check if we've already migrated to fallback
        if (regularPrefs.getBoolean(MIGRATION_KEY, false)) {
            Log.i(TAG, "Using fallback SharedPreferences (encrypted prefs failed previously)")
            return regularPrefs
        }

        return try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                ENCRYPTED_PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize EncryptedSharedPreferences, falling back to regular", e)

            // Mark that we've migrated to fallback
            regularPrefs.edit { putBoolean(MIGRATION_KEY, true) }

            // Try to delete the corrupted encrypted prefs file
            try {
                context.getSharedPreferences(ENCRYPTED_PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .clear()
                    .apply()
            } catch (clearEx: Exception) {
                Log.e(TAG, "Failed to clear corrupted encrypted prefs", clearEx)
            }

            regularPrefs
        }
    }

    /**
     * Provides regular (non-encrypted) SharedPreferences.
     * Used for non-sensitive data and as fallback for encrypted prefs.
     */
    @Provides
    @Singleton
    @RegularPrefs
    fun provideRegularSharedPreferences(
        @ApplicationContext context: Context
    ): SharedPreferences {
        return context.getSharedPreferences(REGULAR_PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Provides the default (non-qualified) SharedPreferences binding.
     * Delegates to the encrypted prefs so all repositories get secure storage by default.
     */
    @Provides
    @Singleton
    fun provideDefaultSharedPreferences(
        @EncryptedPrefs encryptedPrefs: SharedPreferences
    ): SharedPreferences = encryptedPrefs

    /**
     * Provides DataStore for persistent preferences (onboarding, consent, etc.).
     * Uses Preferences DataStore for type-safe key-value storage.
     */
    @Provides
    @Singleton
    fun provideDataStore(
        @ApplicationContext context: Context
    ): DataStore<Preferences> {
        return context.appDataStore
    }
}
