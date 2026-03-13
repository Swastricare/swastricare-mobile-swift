package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CycleEntry
import com.swastricare.health.domain.model.menstrualcycle.FlowIntensity
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import com.swastricare.health.util.MainDispatcherRule
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDate

/**
 * Unit tests for LogCycleStartUseCase.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class LogCycleStartUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var menstrualCycleRepository: MenstrualCycleRepository
    private lateinit var useCase: LogCycleStartUseCase

    @Before
    fun setup() {
        menstrualCycleRepository = mockk()
        useCase = LogCycleStartUseCase(menstrualCycleRepository)
    }

    private fun createTestCycleEntry() = CycleEntry(
        id = "cycle-id",
        startDate = LocalDate.now(),
        endDate = null,
        cycleLength = null,
        flowIntensity = FlowIntensity.MEDIUM,
        symptoms = listOf("Cramps", "Fatigue"),
        notes = "Normal cycle"
    )

    @Test
    fun `invoke logs cycle start successfully`() = runTest {
        // Given
        val cycleEntry = createTestCycleEntry()
        coEvery { menstrualCycleRepository.addCycleEntry(cycleEntry) } returns
            ResultWrapper.Success(cycleEntry)

        // When
        val result = useCase(cycleEntry)

        // Then
        assertTrue(result is ResultWrapper.Success)
        coVerify { menstrualCycleRepository.addCycleEntry(cycleEntry) }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with future start date throws exception`() = runTest {
        // Given
        val cycleEntry = createTestCycleEntry().copy(
            startDate = LocalDate.now().plusDays(1)
        )

        // When
        useCase(cycleEntry)

        // Then - exception thrown
    }

    @Test
    fun `invoke with today's date succeeds`() = runTest {
        // Given
        val cycleEntry = createTestCycleEntry().copy(
            startDate = LocalDate.now()
        )
        coEvery { menstrualCycleRepository.addCycleEntry(cycleEntry) } returns
            ResultWrapper.Success(cycleEntry)

        // When
        val result = useCase(cycleEntry)

        // Then
        assertTrue(result is ResultWrapper.Success)
    }

    @Test
    fun `invoke with different flow intensities succeeds`() = runTest {
        // Given
        coEvery { menstrualCycleRepository.addCycleEntry(any()) } returns
            ResultWrapper.Success(createTestCycleEntry())

        // When
        val light = createTestCycleEntry().copy(flowIntensity = FlowIntensity.LIGHT)
        val medium = createTestCycleEntry().copy(flowIntensity = FlowIntensity.MEDIUM)
        val heavy = createTestCycleEntry().copy(flowIntensity = FlowIntensity.HEAVY)

        useCase(light)
        useCase(medium)
        useCase(heavy)

        // Then
        coVerify(exactly = 3) { menstrualCycleRepository.addCycleEntry(any()) }
    }

    @Test
    fun `invoke with empty symptoms succeeds`() = runTest {
        // Given
        val cycleEntry = createTestCycleEntry().copy(symptoms = emptyList())
        coEvery { menstrualCycleRepository.addCycleEntry(cycleEntry) } returns
            ResultWrapper.Success(cycleEntry)

        // When
        val result = useCase(cycleEntry)

        // Then
        assertTrue(result is ResultWrapper.Success)
    }

    @Test
    fun `invoke returns error on repository failure`() = runTest {
        // Given
        val cycleEntry = createTestCycleEntry()
        coEvery { menstrualCycleRepository.addCycleEntry(cycleEntry) } returns
            ResultWrapper.Error("Database error")

        // When
        val result = useCase(cycleEntry)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }
}
