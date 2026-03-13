package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.repository.HydrationRepository
import java.time.LocalDateTime
import java.util.UUID
import javax.inject.Inject

/**
 * Use case: Add a new hydration entry.
 * Encapsulates business logic for creating and storing hydration logs.
 */
class AddHydrationEntryUseCase @Inject constructor(
    private val repository: HydrationRepository
) {
    /**
     * Add a hydration entry.
     *
     * @param drinkType Type of beverage consumed
     * @param amountMl Amount in milliliters
     * @param notes Optional notes
     * @param consumedAt Timestamp (defaults to now)
     * @return Result with the created entry
     */
    suspend operator fun invoke(
        drinkType: DrinkType,
        amountMl: Int,
        notes: String? = null,
        consumedAt: LocalDateTime = LocalDateTime.now()
    ): ResultWrapper<HydrationEntry> {
        // Validation
        if (amountMl <= 0) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Amount must be greater than 0")
            )
        }

        if (amountMl > 5000) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Amount cannot exceed 5000ml")
            )
        }

        // Calculate effective hydration
        val effectiveMl = (amountMl * drinkType.hydrationMultiplier).toInt()

        // Create entry
        val entry = HydrationEntry(
            id = UUID.randomUUID().toString(),
            drinkType = drinkType,
            amountMl = amountMl,
            effectiveMl = effectiveMl,
            consumedAt = consumedAt,
            notes = notes?.takeIf { it.isNotBlank() },
            synced = false
        )

        // Save to local storage
        return when (val result = repository.addLocalEntry(entry)) {
            is ResultWrapper.Success -> ResultWrapper.Success(entry)
            is ResultWrapper.Error -> result
            is ResultWrapper.Loading -> ResultWrapper.Loading
        }
    }
}
