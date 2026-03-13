package com.swastricare.health.di

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * Hilt module for repository bindings.
 * Maps repository interfaces to their implementations.
 *
 * This module will be populated as we migrate repositories from AppContainer.
 * For now, repositories continue to be accessed via AppContainer.
 *
 * Example usage (to be added during migration):
 * ```
 * @Binds
 * @Singleton
 * abstract fun bindAuthRepository(
 *     impl: AuthRepositoryImpl
 * ): AuthRepository
 * ```
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    // Repository bindings will be added here during feature migration
    // Phase 1: Auth repositories
    // Phase 2: Health data repositories (Hydration, Medication, Diet)
    // Phase 3: Activity repositories (RunActivity, WorkoutTemplate)
    // Phase 4: Other repositories (Vault, Family, AI, etc.)
}
