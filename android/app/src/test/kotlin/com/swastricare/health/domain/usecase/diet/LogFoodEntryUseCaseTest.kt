package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.diet.FoodEntry
import com.swastricare.health.domain.model.diet.MealType
import com.swastricare.health.domain.repository.DietRepository
import com.swastricare.health.util.MainDispatcherRule
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime

/**
 * Unit tests for LogFoodEntryUseCase.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class LogFoodEntryUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var dietRepository: DietRepository
    private lateinit var useCase: LogFoodEntryUseCase

    @Before
    fun setup() {
        dietRepository = mockk()
        useCase = LogFoodEntryUseCase(dietRepository)
    }

    private fun createTestFoodEntry() = FoodEntry(
        id = "entry-id",
        foodName = "Apple",
        calories = 95,
        protein = 0.5,
        carbs = 25.0,
        fat = 0.3,
        servingSize = "1 medium",
        mealType = MealType.SNACK,
        consumedAt = LocalDateTime.now()
    )

    @Test
    fun `invoke logs food entry successfully`() = runTest {
        // Given
        val foodEntry = createTestFoodEntry()
        coEvery { dietRepository.addFoodEntry(foodEntry) } returns
            ResultWrapper.Success(foodEntry)

        // When
        val result = useCase(foodEntry)

        // Then
        assertTrue(result is ResultWrapper.Success)
        coVerify { dietRepository.addFoodEntry(foodEntry) }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty food name throws exception`() = runTest {
        // Given
        val foodEntry = createTestFoodEntry().copy(foodName = "")

        // When
        useCase(foodEntry)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with negative calories throws exception`() = runTest {
        // Given
        val foodEntry = createTestFoodEntry().copy(calories = -10)

        // When
        useCase(foodEntry)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with negative protein throws exception`() = runTest {
        // Given
        val foodEntry = createTestFoodEntry().copy(protein = -1.0)

        // When
        useCase(foodEntry)

        // Then - exception thrown
    }

    @Test
    fun `invoke with zero values succeeds`() = runTest {
        // Given - Food with zero macros (e.g., water)
        val foodEntry = createTestFoodEntry().copy(
            calories = 0,
            protein = 0.0,
            carbs = 0.0,
            fat = 0.0
        )
        coEvery { dietRepository.addFoodEntry(foodEntry) } returns
            ResultWrapper.Success(foodEntry)

        // When
        val result = useCase(foodEntry)

        // Then
        assertTrue(result is ResultWrapper.Success)
    }

    @Test
    fun `invoke logs different meal types`() = runTest {
        // Given
        coEvery { dietRepository.addFoodEntry(any()) } returns
            ResultWrapper.Success(createTestFoodEntry())

        // When
        val breakfast = createTestFoodEntry().copy(mealType = MealType.BREAKFAST)
        val lunch = createTestFoodEntry().copy(mealType = MealType.LUNCH)
        val dinner = createTestFoodEntry().copy(mealType = MealType.DINNER)
        val snack = createTestFoodEntry().copy(mealType = MealType.SNACK)

        useCase(breakfast)
        useCase(lunch)
        useCase(dinner)
        useCase(snack)

        // Then
        coVerify(exactly = 4) { dietRepository.addFoodEntry(any()) }
    }
}
