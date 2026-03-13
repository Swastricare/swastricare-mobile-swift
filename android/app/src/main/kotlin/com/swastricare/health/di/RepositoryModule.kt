package com.swastricare.health.di

import com.swastricare.health.data.repository.AIRepositoryImpl
import com.swastricare.health.data.repository.AnalyticsRepositoryImpl
import com.swastricare.health.data.repository.AuthRepositoryImpl
import com.swastricare.health.data.repository.DietRepositoryImpl
import com.swastricare.health.data.repository.FamilyRepositoryImpl
import com.swastricare.health.data.repository.HeartRateRepositoryImpl
import com.swastricare.health.data.repository.HydrationRepositoryImpl
import com.swastricare.health.data.repository.MedicationRepositoryImpl
import com.swastricare.health.data.repository.MenstrualCycleRepositoryImpl
import com.swastricare.health.data.repository.ProfileRepositoryImpl
import com.swastricare.health.data.repository.VaultRepositoryImpl
import com.swastricare.health.data.repository.runactivity.RunActivityRepositoryImpl
import com.swastricare.health.domain.repository.AIRepository
import com.swastricare.health.domain.repository.AnalyticsRepository
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.DietRepository
import com.swastricare.health.domain.repository.FamilyRepository
import com.swastricare.health.domain.repository.HeartRateRepository
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.domain.repository.MedicationRepository
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.domain.repository.RunActivityRepository
import com.swastricare.health.domain.repository.VaultRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(impl: AuthRepositoryImpl): AuthRepository

    @Binds
    @Singleton
    abstract fun bindProfileRepository(impl: ProfileRepositoryImpl): ProfileRepository

    @Binds
    @Singleton
    abstract fun bindHydrationRepository(impl: HydrationRepositoryImpl): HydrationRepository

    @Binds
    @Singleton
    abstract fun bindMedicationRepository(impl: MedicationRepositoryImpl): MedicationRepository

    @Binds
    @Singleton
    abstract fun bindDietRepository(impl: DietRepositoryImpl): DietRepository

    @Binds
    @Singleton
    abstract fun bindRunActivityRepository(impl: RunActivityRepositoryImpl): RunActivityRepository

    @Binds
    @Singleton
    abstract fun bindVaultRepository(impl: VaultRepositoryImpl): VaultRepository

    @Binds
    @Singleton
    abstract fun bindFamilyRepository(impl: FamilyRepositoryImpl): FamilyRepository

    @Binds
    @Singleton
    abstract fun bindAIRepository(impl: AIRepositoryImpl): AIRepository

    @Binds
    @Singleton
    abstract fun bindAnalyticsRepository(impl: AnalyticsRepositoryImpl): AnalyticsRepository

    @Binds
    @Singleton
    abstract fun bindHeartRateRepository(impl: HeartRateRepositoryImpl): HeartRateRepository

    @Binds
    @Singleton
    abstract fun bindMenstrualCycleRepository(impl: MenstrualCycleRepositoryImpl): MenstrualCycleRepository
}
