package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.medication.Medication
import com.swastricare.health.domain.model.medication.MedicationSchedule
import com.swastricare.health.domain.repository.MedicationRepository
import com.swastricare.health.util.MainDispatcherRule
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime

/**
 * Unit tests for AddMedicationUseCase.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AddMedicationUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var medicationRepository: MedicationRepository
    private lateinit var useCase: AddMedicationUseCase

    @Before
    fun setup() {
        medicationRepository = mockk()
        useCase = AddMedicationUseCase(medicationRepository)
    }

    private fun createTestMedication() = Medication(
        id = "med-id",
        name = "Aspirin",
        dosage = "100mg",
        frequency = "Once daily",
        startDate = LocalDate.now(),
        endDate = LocalDate.now().plusDays(30),
        instructions = "Take with food",
        schedules = listOf(
            MedicationSchedule(
                id = "schedule-1",
                medicationId = "med-id",
                timeOfDay = LocalTime.of(9, 0)
            )
        )
    )

    @Test
    fun `invoke adds medication successfully`() = runTest {
        // Given
        val medication = createTestMedication()
        coEvery { medicationRepository.addMedication(medication) } returns
            ResultWrapper.Success(medication)

        // When
        val result = useCase(medication)

        // Then
        assertTrue(result is ResultWrapper.Success)
        coVerify { medicationRepository.addMedication(medication) }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty name throws exception`() = runTest {
        // Given
        val medication = createTestMedication().copy(name = "")

        // When
        useCase(medication)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty dosage throws exception`() = runTest {
        // Given
        val medication = createTestMedication().copy(dosage = "")

        // When
        useCase(medication)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with end date before start date throws exception`() = runTest {
        // Given
        val medication = createTestMedication().copy(
            startDate = LocalDate.now(),
            endDate = LocalDate.now().minusDays(1)
        )

        // When
        useCase(medication)

        // Then - exception thrown
    }

    @Test
    fun `invoke with no end date succeeds`() = runTest {
        // Given
        val medication = createTestMedication().copy(endDate = null)
        coEvery { medicationRepository.addMedication(medication) } returns
            ResultWrapper.Success(medication)

        // When
        val result = useCase(medication)

        // Then
        assertTrue(result is ResultWrapper.Success)
    }

    @Test
    fun `invoke returns error on repository failure`() = runTest {
        // Given
        val medication = createTestMedication()
        coEvery { medicationRepository.addMedication(medication) } returns
            ResultWrapper.Error("Database error")

        // When
        val result = useCase(medication)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }
}
