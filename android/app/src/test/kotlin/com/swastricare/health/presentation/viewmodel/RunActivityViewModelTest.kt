package com.swastricare.health.presentation.viewmodel

import app.cash.turbine.test
import com.swastricare.health.domain.model.ActivityType
import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.model.WorkoutStats
import com.swastricare.health.domain.usecase.runactivity.*
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
 * Unit tests for RunActivityViewModel.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RunActivityViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var getWorkoutSessionsUseCase: GetWorkoutSessionsUseCase
    private lateinit var saveWorkoutSessionUseCase: SaveWorkoutSessionUseCase
    private lateinit var deleteWorkoutSessionUseCase: DeleteWorkoutSessionUseCase
    private lateinit var calculateWorkoutStatsUseCase: CalculateWorkoutStatsUseCase
    private lateinit var viewModel: RunActivityViewModel

    @Before
    fun setup() {
        getWorkoutSessionsUseCase = mockk()
        saveWorkoutSessionUseCase = mockk()
        deleteWorkoutSessionUseCase = mockk()
        calculateWorkoutStatsUseCase = mockk()

        viewModel = RunActivityViewModel(
            getWorkoutSessionsUseCase = getWorkoutSessionsUseCase,
            saveWorkoutSessionUseCase = saveWorkoutSessionUseCase,
            deleteWorkoutSessionUseCase = deleteWorkoutSessionUseCase,
            calculateWorkoutStatsUseCase = calculateWorkoutStatsUseCase
        )
    }

    private fun createTestWorkoutSession(
        id: String = "workout-id",
        distanceMeters: Double = 5000.0
    ) = WorkoutSession(
        id = id,
        userId = "test-user",
        activityType = ActivityType.RUNNING,
        startTime = LocalDateTime.now().minusHours(1),
        endTime = LocalDateTime.now(),
        distanceMeters = distanceMeters,
        durationSeconds = 1800,
        avgPaceSecondsPerKm = 360,
        caloriesBurned = 300
    )

    @Test
    fun `loadWorkouts updates state with activities`() = runTest {
        // Given
        val workouts = listOf(
            createTestWorkoutSession(id = "1"),
            createTestWorkoutSession(id = "2")
        )
        coEvery { getWorkoutSessionsUseCase() } returns workouts

        // When
        viewModel.uiState.test {
            viewModel.loadWorkouts()

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(2, successState.activities.size)
            assertNull(successState.error)
        }
    }

    @Test
    fun `loadWorkouts handles empty list`() = runTest {
        // Given
        coEvery { getWorkoutSessionsUseCase() } returns emptyList()

        // When
        viewModel.uiState.test {
            viewModel.loadWorkouts()

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertTrue(successState.activities.isEmpty())
        }
    }

    @Test
    fun `loadWorkouts handles error`() = runTest {
        // Given
        val errorMessage = "Failed to load workouts"
        coEvery { getWorkoutSessionsUseCase() } throws Exception(errorMessage)

        // When
        viewModel.uiState.test {
            viewModel.loadWorkouts()

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val errorState = awaitItem()
            assertFalse(errorState.isLoading)
            assertNotNull(errorState.error)
        }
    }

    @Test
    fun `deleteWorkout removes activity from list`() = runTest {
        // Given
        val workoutId = "workout-to-delete"
        coEvery { deleteWorkoutSessionUseCase(workoutId) } just Runs
        coEvery { getWorkoutSessionsUseCase() } returns emptyList()

        // When
        viewModel.uiState.test {
            viewModel.deleteWorkout(workoutId)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
        }
        coVerify { deleteWorkoutSessionUseCase(workoutId) }
    }

    @Test
    fun `calculateStats updates statistics`() = runTest {
        // Given
        val workouts = listOf(createTestWorkoutSession())
        val expectedStats = WorkoutStats(
            totalDistance = 5000.0,
            totalDuration = 1800,
            totalCalories = 300,
            totalActivities = 1
        )
        coEvery { getWorkoutSessionsUseCase() } returns workouts
        coEvery {
            calculateWorkoutStatsUseCase(workouts, TimeRangeFilter.ONE_MONTH)
        } returns expectedStats

        // When
        viewModel.uiState.test {
            viewModel.loadWorkouts()
            viewModel.calculateStats(TimeRangeFilter.ONE_MONTH)

            // Then - Skip initial states and get to stats state
            skipItems(2) // Skip initial and loading

            val statsState = awaitItem()
            assertEquals(expectedStats, statsState.stats)
        }
    }

    @Test
    fun `changing time range filter recalculates stats`() = runTest {
        // Given
        val workouts = listOf(createTestWorkoutSession())
        coEvery { getWorkoutSessionsUseCase() } returns workouts

        val twoWeeksStats = WorkoutStats(totalActivities = 1)
        val oneMonthStats = WorkoutStats(totalActivities = 5)

        coEvery {
            calculateWorkoutStatsUseCase(workouts, TimeRangeFilter.TWO_WEEKS)
        } returns twoWeeksStats
        coEvery {
            calculateWorkoutStatsUseCase(workouts, TimeRangeFilter.ONE_MONTH)
        } returns oneMonthStats

        // When
        viewModel.loadWorkouts()
        viewModel.calculateStats(TimeRangeFilter.TWO_WEEKS)
        viewModel.calculateStats(TimeRangeFilter.ONE_MONTH)

        // Then
        coVerify { calculateWorkoutStatsUseCase(workouts, TimeRangeFilter.TWO_WEEKS) }
        coVerify { calculateWorkoutStatsUseCase(workouts, TimeRangeFilter.ONE_MONTH) }
    }
}
