package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.MedicationStatus
import com.swastricare.health.domain.model.ai.HealthContext
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.domain.repository.MedicationRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case: Build health context from various health data sources.
 * Aggregates data from multiple repositories to create comprehensive health context.
 */
class BuildHealthContextUseCase @Inject constructor(
    private val hydrationRepository: HydrationRepository,
    private val medicationRepository: MedicationRepository
) {
    /**
     * Build health context with all available health data.
     * This will be expanded to include more data sources.
     */
    suspend operator fun invoke(): HealthContext {
        // Get hydration data
        val hydrationEntries = hydrationRepository.loadLocalEntries()
        val todayHydration = hydrationEntries
            .filter { it.consumedAt.toLocalDate() == LocalDate.now() }
            .sumOf { it.effectiveMl }

        // Get current medications from cache (no profile ID required at this layer)
        val medications = medicationRepository.getCachedMedications()
        val currentMedications = medications
            .filter { it.status == MedicationStatus.ACTIVE }
            .map { it.name }

        return HealthContext(
            hydrationMl = todayHydration,
            currentMedications = currentMedications
            // TODO: Add steps, heart rate, sleep, etc. from HealthConnect
            // This will be implemented when HealthConnect data is migrated to Clean Architecture
        )
    }

    /**
     * Build basic health context (without external data sources).
     * Used when full context is not needed or available.
     */
    suspend fun buildBasic(): HealthContext {
        return HealthContext()
    }

    /**
     * Build health context with specific data.
     * Allows custom health context creation.
     */
    fun buildCustom(
        steps: Int = 0,
        heartRate: Int = 0,
        sleep: String = "0h 0m",
        activeCalories: Int = 0,
        exerciseMinutes: Int = 0,
        bloodPressure: String = "--/--",
        weight: String = "--"
    ): HealthContext {
        return HealthContext(
            steps = steps,
            heartRate = heartRate,
            sleep = sleep,
            activeCalories = activeCalories,
            exerciseMinutes = exerciseMinutes,
            bloodPressure = bloodPressure,
            weight = weight
        )
    }
}
