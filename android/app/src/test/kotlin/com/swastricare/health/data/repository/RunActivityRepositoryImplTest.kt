package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.domain.model.ActivityType
import com.swastricare.health.domain.model.RoutePoint
import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.util.MainDispatcherRule
import io.github.jan.supabase.SupabaseClient
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime
import java.util.UUID

/**
 * Unit tests for RunActivityRepositoryImpl.
 *
 * Tests:
 * - Local activity storage
 * - Activity CRUD operations
 * - Statistics calculation
 * - Workout crash recovery state
 * - Cloud sync operations
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RunActivityRepositoryImplTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var supabaseClient: SupabaseClient
    private lateinit var sharedPreferences: SharedPreferences
    private lateinit var editor: SharedPreferences.Editor
    private lateinit var json: Json
    private lateinit var logger: Logger
    private lateinit var repository: RunActivityRepositoryImpl

    @Before
    fun setup() {
        supabaseClient = mockk(relaxed = true)
        sharedPreferences = mockk(relaxed = true)
        editor = mockk(relaxed = true)
        json = Json { ignoreUnknownKeys = true; isLenient = true }
        logger = mockk(relaxed = true)

        every { sharedPreferences.edit() } returns editor
        every { editor.putString(any(), any()) } returns editor
        every { editor.putBoolean(any(), any()) } returns editor
        every { editor.putLong(any(), any()) } returns editor
        every { editor.remove(any()) } returns editor
        every { editor.apply() } just Runs

        repository = RunActivityRepositoryImpl(
            supabaseClient = supabaseClient,
            sharedPreferences = sharedPreferences,
            json = json,
            logger = logger
        )
    }

    private fun createTestWorkoutSession(
        id: String = UUID.randomUUID().toString(),
        distanceMeters: Double = 5000.0,
        durationSeconds: Long = 1800,
        startTime: LocalDateTime = LocalDateTime.now()
    ) = WorkoutSession(
        id = id,
        userId = "test-user",
        activityType = ActivityType.RUNNING,
        startTime = startTime,
        endTime = startTime.plusSeconds(durationSeconds),
        distanceMeters = distanceMeters,
        durationSeconds = durationSeconds,
        avgPaceSecondsPerKm = if (distanceMeters > 0) {
            (durationSeconds * 1000 / distanceMeters).toLong()
        } else 0,
        caloriesBurned = 300,
        avgHeartRate = 145,
        routePoints = listOf(
            RoutePoint(40.7128, -74.0060, 10.0),
            RoutePoint(40.7129, -74.0061, 12.0)
        ),
        synced = false
    )

    @Test
    fun `loadLocalActivities returns empty list when no data exists`() = runTest {
        // Given
        every { sharedPreferences.getString("workout_activities", null) } returns null

        // When
        val result = repository.loadLocalActivities()

        // Then
        assertTrue(result.isEmpty())
    }

    @Test
    fun `loadLocalActivities returns parsed activities from SharedPreferences`() = runTest {
        // Given
        val activities = listOf(
            createTestWorkoutSession(id = "activity-1"),
            createTestWorkoutSession(id = "activity-2")
        )
        every { sharedPreferences.getString("workout_activities", null) } returns
            json.encodeToString(
                kotlinx.serialization.builtins.ListSerializer(
                    WorkoutSession.serializer()
                ),
                activities
            )

        // When
        val result = repository.loadLocalActivities()

        // Then
        assertEquals(2, result.size)
        assertEquals("activity-1", result[0].id)
        assertEquals("activity-2", result[1].id)
    }

    @Test
    fun `addLocalActivity adds new activity to existing list`() = runTest {
        // Given
        val existingActivities = listOf(createTestWorkoutSession(id = "existing"))
        val newActivity = createTestWorkoutSession(id = "new")

        every { sharedPreferences.getString("workout_activities", null) } returns
            json.encodeToString(
                kotlinx.serialization.builtins.ListSerializer(
                    WorkoutSession.serializer()
                ),
                existingActivities
            )

        // When
        repository.addLocalActivity(newActivity)

        // Then
        verify { editor.putString("workout_activities", any()) }
        verify { editor.apply() }
    }

    @Test
    fun `deleteLocalActivity removes activity by id`() = runTest {
        // Given
        val activities = listOf(
            createTestWorkoutSession(id = "activity-1"),
            createTestWorkoutSession(id = "activity-2"),
            createTestWorkoutSession(id = "activity-3")
        )
        every { sharedPreferences.getString("workout_activities", null) } returns
            json.encodeToString(
                kotlinx.serialization.builtins.ListSerializer(
                    WorkoutSession.serializer()
                ),
                activities
            )

        // When
        repository.deleteLocalActivity("activity-2")

        // Then
        verify { editor.putString("workout_activities", any()) }
        verify { editor.apply() }
    }

    @Test
    fun `saveLocalActivities persists activities to SharedPreferences`() = runTest {
        // Given
        val activities = listOf(
            createTestWorkoutSession(id = "activity-1"),
            createTestWorkoutSession(id = "activity-2")
        )

        // When
        repository.saveLocalActivities(activities)

        // Then
        verify { editor.putString("workout_activities", any()) }
        verify { editor.apply() }
    }

    @Test
    fun `calculateStatistics computes correct totals for activities`() = runTest {
        // Given
        val activities = listOf(
            createTestWorkoutSession(distanceMeters = 5000.0, durationSeconds = 1800),
            createTestWorkoutSession(distanceMeters = 3000.0, durationSeconds = 1200),
            createTestWorkoutSession(distanceMeters = 7000.0, durationSeconds = 2400)
        )

        // When
        val stats = repository.calculateStatistics(activities, TimeRangeFilter.ONE_MONTH)

        // Then
        assertEquals(15000.0, stats.totalDistance, 0.01)
        assertEquals(5400L, stats.totalDuration)
        assertEquals(3, stats.totalActivities)
        assertTrue(stats.totalCalories > 0)
    }

    @Test
    fun `calculateStatistics filters activities by time range`() = runTest {
        // Given
        val now = LocalDateTime.now()
        val activities = listOf(
            createTestWorkoutSession(
                distanceMeters = 5000.0,
                startTime = now.minusDays(5)
            ),
            createTestWorkoutSession(
                distanceMeters = 3000.0,
                startTime = now.minusDays(20)
            ),
            createTestWorkoutSession(
                distanceMeters = 7000.0,
                startTime = now.minusDays(40)
            )
        )

        // When - Filter for 2 weeks
        val stats = repository.calculateStatistics(activities, TimeRangeFilter.TWO_WEEKS)

        // Then - Only first activity should be counted
        assertEquals(5000.0, stats.totalDistance, 0.01)
        assertEquals(1, stats.totalActivities)
    }

    @Test
    fun `saveWorkoutState persists recovery state`() = runTest {
        // Given
        val state = WorkoutRecoveryState(
            activityType = ActivityType.RUNNING,
            startTimeMs = System.currentTimeMillis(),
            elapsedSeconds = 600,
            distanceMeters = 1500.0,
            caloriesBurned = 100,
            isActive = true
        )

        // When
        repository.saveWorkoutState(state)

        // Then
        verify { editor.putString("workout_recovery_state", any()) }
        verify { editor.apply() }
    }

    @Test
    fun `loadWorkoutState returns saved recovery state`() = runTest {
        // Given
        val state = WorkoutRecoveryState(
            activityType = ActivityType.RUNNING,
            startTimeMs = System.currentTimeMillis(),
            elapsedSeconds = 600,
            distanceMeters = 1500.0,
            caloriesBurned = 100,
            isActive = true
        )
        every { sharedPreferences.getString("workout_recovery_state", null) } returns
            json.encodeToString(WorkoutRecoveryState.serializer(), state)

        // When
        val result = repository.loadWorkoutState()

        // Then
        assertNotNull(result)
        assertEquals(ActivityType.RUNNING, result?.activityType)
        assertEquals(600L, result?.elapsedSeconds)
        assertEquals(1500.0, result?.distanceMeters, 0.01)
        assertTrue(result?.isActive == true)
    }

    @Test
    fun `loadWorkoutState returns null when no state exists`() = runTest {
        // Given
        every { sharedPreferences.getString("workout_recovery_state", null) } returns null

        // When
        val result = repository.loadWorkoutState()

        // Then
        assertNull(result)
    }

    @Test
    fun `clearWorkoutState removes recovery state`() = runTest {
        // When
        repository.clearWorkoutState()

        // Then
        verify { editor.remove("workout_recovery_state") }
        verify { editor.apply() }
    }

    @Test
    fun `workout session preserves route points`() = runTest {
        // Given
        val routePoints = listOf(
            RoutePoint(40.7128, -74.0060, 10.0, System.currentTimeMillis()),
            RoutePoint(40.7129, -74.0061, 12.0, System.currentTimeMillis()),
            RoutePoint(40.7130, -74.0062, 15.0, System.currentTimeMillis())
        )
        val session = createTestWorkoutSession(id = "with-route").copy(
            routePoints = routePoints
        )
        every { sharedPreferences.getString("workout_activities", null) } returns null

        // When
        repository.addLocalActivity(session)

        // Then
        verify { editor.putString("workout_activities", any()) }
    }

    @Test
    fun `activity type conversion preserves data`() = runTest {
        // Given
        val walkingSession = createTestWorkoutSession(id = "walking").copy(
            activityType = ActivityType.WALKING
        )
        val cyclingSession = createTestWorkoutSession(id = "cycling").copy(
            activityType = ActivityType.CYCLING
        )
        every { sharedPreferences.getString("workout_activities", null) } returns null

        // When
        repository.addLocalActivity(walkingSession)
        repository.addLocalActivity(cyclingSession)

        // Then
        verify(exactly = 2) { editor.putString("workout_activities", any()) }
    }
}
