package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Unit test for GetHydrationEntriesUseCase.
 *
 * Tests:
 * - Fetching all entries
 * - Filtering entries by date
 * - Getting today's entries
 * - Getting entries in a date range
 */
@OptIn(ExperimentalCoroutinesApi::class)
class GetHydrationEntriesUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var hydrationRepository: HydrationRepository
    private lateinit var getHydrationEntriesUseCase: GetHydrationEntriesUseCase

    @Before
    fun setup() {
        hydrationRepository = mockk()
        getHydrationEntriesUseCase = GetHydrationEntriesUseCase(hydrationRepository)
    }

    @Test
    fun `invoke returns all entries from repository`() = runTest {
        // Given
        val expectedEntries = MockFactory.createHydrationEntries(count = 3)
        coEvery { hydrationRepository.loadLocalEntries() } returns expectedEntries

        // When
        val result = getHydrationEntriesUseCase()

        // Then
        assertEquals(expectedEntries.size, result.size)
        assertEquals(expectedEntries, result)
    }

    @Test
    fun `invoke returns empty list when no entries exist`() = runTest {
        // Given
        coEvery { hydrationRepository.loadLocalEntries() } returns emptyList()

        // When
        val result = getHydrationEntriesUseCase()

        // Then
        assertTrue(result.isEmpty())
    }

    @Test
    fun `getEntriesForDate returns only entries for specific date`() = runTest {
        // Given
        val targetDate = LocalDate.now().minusDays(1)
        val entries = listOf(
            MockFactory.createHydrationEntry(
                id = "1",
                consumedAt = targetDate.atTime(10, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "2",
                consumedAt = targetDate.atTime(15, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "3",
                consumedAt = LocalDate.now().atTime(10, 0)
            )
        )
        coEvery { hydrationRepository.loadLocalEntries() } returns entries

        // When
        val result = getHydrationEntriesUseCase.getEntriesForDate(targetDate)

        // Then
        assertEquals(2, result.size)
        assertTrue(result.all { it.consumedAt.toLocalDate() == targetDate })
    }

    @Test
    fun `getTodaysEntries returns only today's entries`() = runTest {
        // Given
        val today = LocalDate.now()
        val entries = listOf(
            MockFactory.createHydrationEntry(
                id = "1",
                consumedAt = today.atTime(8, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "2",
                consumedAt = today.atTime(12, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "3",
                consumedAt = today.minusDays(1).atTime(10, 0)
            )
        )
        coEvery { hydrationRepository.loadLocalEntries() } returns entries

        // When
        val result = getHydrationEntriesUseCase.getTodaysEntries()

        // Then
        assertEquals(2, result.size)
        assertTrue(result.all { it.isToday() })
    }

    @Test
    fun `getEntriesInRange returns entries within date range`() = runTest {
        // Given
        val startDate = LocalDate.now().minusDays(7)
        val endDate = LocalDate.now()
        val entries = listOf(
            MockFactory.createHydrationEntry(
                id = "1",
                consumedAt = startDate.atTime(10, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "2",
                consumedAt = startDate.plusDays(3).atTime(10, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "3",
                consumedAt = endDate.atTime(10, 0)
            ),
            MockFactory.createHydrationEntry(
                id = "4",
                consumedAt = startDate.minusDays(1).atTime(10, 0) // Outside range
            ),
            MockFactory.createHydrationEntry(
                id = "5",
                consumedAt = endDate.plusDays(1).atTime(10, 0) // Outside range
            )
        )
        coEvery { hydrationRepository.loadLocalEntries() } returns entries

        // When
        val result = getHydrationEntriesUseCase.getEntriesInRange(startDate, endDate)

        // Then
        assertEquals(3, result.size)
        assertTrue(result.all {
            val entryDate = it.consumedAt.toLocalDate()
            entryDate >= startDate && entryDate <= endDate
        })
    }

    @Test
    fun `entries are sorted by consumed time descending`() = runTest {
        // Given
        val now = LocalDateTime.now()
        val entries = listOf(
            MockFactory.createHydrationEntry(id = "1", consumedAt = now.minusHours(3)),
            MockFactory.createHydrationEntry(id = "2", consumedAt = now.minusHours(1)),
            MockFactory.createHydrationEntry(id = "3", consumedAt = now.minusHours(2))
        )
        coEvery { hydrationRepository.loadLocalEntries() } returns entries

        // When
        val result = getHydrationEntriesUseCase.getEntriesForDate(LocalDate.now())

        // Then
        assertEquals("2", result[0].id) // Most recent
        assertEquals("3", result[1].id) // Middle
        assertEquals("1", result[2].id) // Oldest
    }

    @Test
    fun `entries contain correct drink type information`() = runTest {
        // Given
        val entries = listOf(
            MockFactory.createHydrationEntry(
                id = "1",
                drinkType = DrinkType.WATER,
                amountMl = 250
            ),
            MockFactory.createHydrationEntry(
                id = "2",
                drinkType = DrinkType.COFFEE,
                amountMl = 200
            )
        )
        coEvery { hydrationRepository.loadLocalEntries() } returns entries

        // When
        val result = getHydrationEntriesUseCase()

        // Then
        assertEquals(DrinkType.WATER, result[0].drinkType)
        assertEquals(DrinkType.COFFEE, result[1].drinkType)
        assertEquals(250, result[0].amountMl)
        assertEquals(200, result[1].amountMl)
    }
}
