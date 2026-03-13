package com.swastricare.health.widgets

import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.data.repository.SupabaseHydrationRepository
import com.swastricare.health.data.repository.SupabaseMedicationRepository
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * Hilt EntryPoint for widget BroadcastReceivers.
 * BroadcastReceivers cannot use constructor injection, so dependencies are
 * retrieved via EntryPointAccessors.fromApplication().
 *
 * Uses the concrete data-layer repository types directly because:
 * - The domain-layer interfaces (bound in RepositoryModule) are different types
 * - SupabaseHydrationRepository / SupabaseMedicationRepository have @Inject constructors
 *   and are auto-provided by Hilt as @Singleton concrete bindings
 */
@EntryPoint
@InstallIn(SingletonComponent::class)
interface WidgetEntryPoint {
    fun hydrationRepository(): SupabaseHydrationRepository
    fun medicationRepository(): SupabaseMedicationRepository
    fun authRepository(): SupabaseAuthRepository
}
