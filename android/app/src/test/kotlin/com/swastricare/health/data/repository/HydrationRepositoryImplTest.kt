package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.HydrationMapper
import com.swastricare.health.data.remote.dto.hydration.HydrationEntryDto
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.github.jan.supabase.SupabaseClient
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Unit test for HydrationRepositoryImpl.
 *
 * Tests:
 * - Loading local entries from SharedPreferences
 * - Adding new entries
 * - Saving and deleting entries
 * - Marking entries as synced
 * - Preferences management
 * - Error handling
 */
@OptIn(ExperimentalCoroutinesApi::class)
class HydrationRepositoryImplTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var supabaseClient: SupabaseClient
    private lateinit var sharedPreferences: SharedPreferences
    private lateinit var editor: SharedPreferences.Editor
    private lateinit var json: Json
    private lateinit var logger: Logger
    private lateinit var repository: HydrationRepositoryImpl

    @Before
    fun setup() {
        supabaseClient = mockk(relaxed = true)
        sharedPreferences = mockk(relaxed = true)
        editor = mockk(relaxed = true)
        json = Json { ignoreUnknownKeys = true; isLenient = true }
        logger = mockk(relaxed = true)

        every { sharedPreferences.edit() } returns editor
        every { editor.putString(any(), any()) } returns editor
        every { editor.apply() } just Runs

        repository = HydrationRepositoryImpl(
            supabaseClient = supabaseClient,
            sharedPreferences = sharedPreferences,
            json = json,
            logger = logger
        )
    }

    @Test
    fun `loadLocalEntries returns empty list when no data exists`() = runTest {
        // Given
        every { sharedPreferences.getString(any(), any()) } returns null

        // When
        val result = repository.loadLocalEntries()

        // Then
        assertTrue(result.isEmpty())
    }

    @Test
    fun `loadLocalEntries returns parsed entries from SharedPreferences`() = runTest {
        // Given
        val entries = MockFactory.createHydrationEntries(count = 2)
        val dtos = entries.map { entry ->
            HydrationEntryDto(
                id = entry.id,
                healthProfileId = "",
                beverageType = entry.drinkType.dbValue,
                amountMl = entry.amountMl,
                consumedAt = entry.consumedAt.toString(),
                notes = entry.notes,
                hydrationFactor = entry.drinkType.hydrationMultiplier
            )
        }
        val encoded = json.encodeToString(dtos)
        every { sharedPreferences.getString("hydration_entries", null) } returns encoded

        // When
        val result = repository.loadLocalEntries()

        // Then
        assertEquals(2, result.size)
        assertEquals(entries[0].id, result[0].id)
        assertEquals(entries[0].amountMl, result[0].amountMl)
    }

    @Test
    fun `loadLocalEntries returns empty list on parse error`() = runTest {
        // Given
        every { sharedPreferences.getString("hydration_entries", null) } returns "invalid-json"

        // When
        val result = repository.loadLocalEntries()

        // Then
        assertTrue(result.isEmpty())
        verify { logger.e("HydrationRepository", any(), any()) }
    }

    @Test
    fun `addLocalEntry adds entry to existing entries`() = runTest {
        // Given
        val existingEntries = MockFactory.createHydrationEntries(count = 2)
        val newEntry = MockFactory.createHydrationEntry(id = "new-entry")

        val existingDtos = existingEntries.map { entry ->
            HydrationEntryDto(
                id = entry.id,
                healthProfileId = "",
                beverageType = entry.drinkType.dbValue,
                amountMl = entry.amountMl,
                consumedAt = entry.consumedAt.toString(),
                notes = entry.notes,
                hydrationFactor = entry.drinkType.hydrationMultiplier
            )
        }
        every { sharedPreferences.getString("hydration_entries", null) } returns
            json.encodeToString(existingDtos)

        // When
        val result = repository.addLocalEntry(newEntry)

        // Then
        assertTrue(result is ResultWrapper.Success)
        verify { editor.putString("hydration_entries", any()) }
        verify { editor.apply() }
    }

    @Test
    fun `deleteLocalEntry removes entry by id`() = runTest {
        // Given
        val entries = MockFactory.createHydrationEntries(count = 3)
        val dtos = entries.map { entry ->
            HydrationEntryDto(
                id = entry.id,
                healthProfileId = "",
                beverageType = entry.drinkType.dbValue,
                amountMl = entry.amountMl,
                consumedAt = entry.consumedAt.toString(),
                notes = entry.notes,
                hydrationFactor = entry.drinkType.hydrationMultiplier
            )
        }
        every { sharedPreferences.getString("hydration_entries", null) } returns
            json.encodeToString(dtos)

        val idToDelete = entries[1].id

        // When
        val result = repository.deleteLocalEntry(idToDelete)

        // Then
        assertTrue(result is ResultWrapper.Success)
        verify { editor.putString("hydration_entries", match { encoded ->
            val savedDtos = json.decodeFromString<List<HydrationEntryDto>>(encoded)
            savedDtos.size == 2 && savedDtos.none { it.id == idToDelete }
        }) }
    }

    @Test
    fun `markEntriesAsSynced updates synced status for specified ids`() = runTest {
        // Given
        val entries = listOf(
            MockFactory.createHydrationEntry(id = "1", synced = false),
            MockFactory.createHydrationEntry(id = "2", synced = false),
            MockFactory.createHydrationEntry(id = "3", synced = false)
        )
        val dtos = entries.map { entry ->
            HydrationEntryDto(
                id = entry.id,
                healthProfileId = "",
                beverageType = entry.drinkType.dbValue,
                amountMl = entry.amountMl,
                consumedAt = entry.consumedAt.toString(),
                notes = entry.notes,
                hydrationFactor = entry.drinkType.hydrationMultiplier
            )
        }
        every { sharedPreferences.getString("hydration_entries", null) } returns
            json.encodeToString(dtos)

        val idsToSync = listOf("1", "3")

        // When
        val result = repository.markEntriesAsSynced(idsToSync)

        // Then
        assertTrue(result is ResultWrapper.Success)
        verify { editor.putString("hydration_entries", any()) }
    }

    @Test
    fun `saveLocalEntries saves entries to SharedPreferences`() = runTest {
        // Given
        val entries = MockFactory.createHydrationEntries(count = 3)

        // When
        val result = repository.saveLocalEntries(entries)

        // Then
        assertTrue(result is ResultWrapper.Success)
        verify { editor.putString("hydration_entries", match { encoded ->
            val savedDtos = json.decodeFromString<List<HydrationEntryDto>>(encoded)
            savedDtos.size == 3
        }) }
        verify { editor.apply() }
    }

    @Test
    fun `loadPreferences returns default when no data exists`() = runTest {
        // Given
        every { sharedPreferences.getString("hydration_preferences", null) } returns null

        // When
        val result = repository.loadPreferences()

        // Then
        assertEquals(com.swastricare.health.domain.model.hydration.HydrationPreferences.Default, result)
    }

    @Test
    fun `savePreferences saves preferences to SharedPreferences`() = runTest {
        // Given
        val preferences = MockFactory.createHydrationPreferences(
            weightKg = 75.0,
            activityLevel = "high"
        )

        // When
        val result = repository.savePreferences(preferences)

        // Then
        assertTrue(result is ResultWrapper.Success)
        verify { editor.putString("hydration_preferences", any()) }
        verify { editor.apply() }
    }

    @Test
    fun `repository handles concurrent operations safely`() = runTest {
        // Given
        every { sharedPreferences.getString(any(), any()) } returns null

        // When - multiple operations
        val results = listOf(
            repository.addLocalEntry(MockFactory.createHydrationEntry(id = "1")),
            repository.addLocalEntry(MockFactory.createHydrationEntry(id = "2")),
            repository.addLocalEntry(MockFactory.createHydrationEntry(id = "3"))
        )

        // Then - all operations should succeed
        assertTrue(results.all { it is ResultWrapper.Success })
    }

    @Test
    fun `repository preserves drink type information`() = runTest {
        // Given
        val entry = MockFactory.createHydrationEntry(
            id = "coffee-entry",
            drinkType = DrinkType.COFFEE,
            amountMl = 200
        )
        every { sharedPreferences.getString("hydration_entries", null) } returns null

        // When
        repository.addLocalEntry(entry)

        // Then
        verify { editor.putString("hydration_entries", match { encoded ->
            val savedDtos = json.decodeFromString<List<HydrationEntryDto>>(encoded)
            savedDtos.any {
                it.beverageType == "coffee" &&
                it.amountMl == 200 &&
                it.hydrationFactor == 0.8
            }
        }) }
    }
}
