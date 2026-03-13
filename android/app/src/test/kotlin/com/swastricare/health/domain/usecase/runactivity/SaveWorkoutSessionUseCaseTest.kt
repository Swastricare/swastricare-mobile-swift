package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.model.ActivityType
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.repository.RunActivityRepository
import com.swastricare.health.util.MainDispatcherRule
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

/**
 * Unit tests for SaveWorkoutSessionUseCase.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SaveWorkoutSessionUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var runActivityRepository: RunActivityRepository
    private lateinit var useCase: SaveWorkoutSessionUseCase

    @Before
    fun setup() {
        runActivityRepository = mockk()
        useCase = SaveWorkoutSessionUseCase(runActivityRepository)
    }

    private fun createTestWorkoutSession() = WorkoutSession(
        id = UUID.randomUUID().toString(),
        userId = "test-user",
        activityType = ActivityType.RUNNING,
        startTime = LocalDateTime.now().minusHours(1),
        endTime = LocalDateTime.now(),
        distanceMeters = 5000.0,
        durationSeconds = 1800,
        avgPaceSecondsPerKm = 360,
        caloriesBurned = 300,
        avgHeartRate = 145
    )

    @Test
    fun `invoke saves workout session successfully`() = runTest {
        // Given
        val session = createTestWorkoutSession()
        coEvery { runActivityRepository.addLocalActivity(session) } just Runs

        // When
        useCase(session)

        // Then
        coVerify { runActivityRepository.addLocalActivity(session) }
    }

    @Test
    fun `invoke saves workout with zero distance`() = runTest {
        // Given - Short workout with minimal distance
        val session = createTestWorkoutSession().copy(
            distanceMeters = 0.0,
            durationSeconds = 60
        )
        coEvery { runActivityRepository.addLocalActivity(session) } just Runs

        // When
        useCase(session)

        // Then
        coVerify { runActivityRepository.addLocalActivity(session) }
    }

    @Test
    fun `invoke saves different activity types`() = runTest {
        // Given
        val walkingSession = createTestWorkoutSession().copy(activityType = ActivityType.WALKING)
        val cyclingSession = createTestWorkoutSession().copy(activityType = ActivityType.CYCLING)
        val hikingSession = createTestWorkoutSession().copy(activityType = ActivityType.HIKING)
        coEvery { runActivityRepository.addLocalActivity(any()) } just Runs

        // When
        useCase(walkingSession)
        useCase(cyclingSession)
        useCase(hikingSession)

        // Then
        coVerify(exactly = 3) { runActivityRepository.addLocalActivity(any()) }
    }
}
