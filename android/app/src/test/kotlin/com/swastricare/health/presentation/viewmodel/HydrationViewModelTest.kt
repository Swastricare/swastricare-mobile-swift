package com.swastricare.health.presentation.viewmodel

import app.cash.turbine.test
import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.usecase.hydration.AddHydrationEntryUseCase
import com.swastricare.health.domain.usecase.hydration.DeleteHydrationEntryUseCase
import com.swastricare.health.domain.usecase.hydration.GetHydrationEntriesUseCase
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime

/**
 * Example ViewModel test demonstrating:
 * - Testing StateFlow emissions with Turbine
 * - Mocking use cases with MockK
 * - Testing loading states
 * - Testing error handling
 * - Testing user actions
 *
 * NOTE: This is a simplified example ViewModel for demonstration.
 * The actual HydrationViewModel in ui.screens.hydration is more complex.
 */

/**
 * Simplified UI State for testing demonstration.
 */
data class SimpleHydrationUiState(
    val entries: List<HydrationEntry> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val totalIntakeMl: Int = 0
) {
    val hasEntries: Boolean get() = entries.isNotEmpty()
}

/**
 * Simplified ViewModel for testing demonstration.
 * Demonstrates MVVM patterns with use cases.
 */
class SimpleHydrationViewModel(
    private val getHydrationEntriesUseCase: GetHydrationEntriesUseCase,
    private val addHydrationEntryUseCase: AddHydrationEntryUseCase,
    private val deleteHydrationEntryUseCase: DeleteHydrationEntryUseCase
) {
    private val _uiState = kotlinx.coroutines.flow.MutableStateFlow(SimpleHydrationUiState())
    val uiState: kotlinx.coroutines.flow.StateFlow<SimpleHydrationUiState> = _uiState

    suspend fun loadEntries() {
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        try {
            val entries = getHydrationEntriesUseCase()
            val totalIntake = entries.sumOf { it.amountMl }

            _uiState.value = _uiState.value.copy(
                entries = entries,
                totalIntakeMl = totalIntake,
                isLoading = false,
                error = null
            )
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                error = e.message ?: "Failed to load entries"
            )
        }
    }

    suspend fun addEntry(drinkType: DrinkType, amountMl: Int) {
        try {
            val entry = HydrationEntry(
                id = java.util.UUID.randomUUID().toString(),
                drinkType = drinkType,
                amountMl = amountMl,
                effectiveMl = (amountMl * drinkType.hydrationMultiplier).toInt(),
                consumedAt = LocalDateTime.now()
            )

            addHydrationEntryUseCase(entry)
            loadEntries() // Reload to update UI
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                error = e.message ?: "Failed to add entry"
            )
        }
    }

    suspend fun deleteEntry(entryId: String) {
        try {
            deleteHydrationEntryUseCase(entryId)
            loadEntries() // Reload to update UI
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                error = e.message ?: "Failed to delete entry"
            )
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

/**
 * Unit tests for SimpleHydrationViewModel.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class HydrationViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private lateinit var getHydrationEntriesUseCase: GetHydrationEntriesUseCase
    private lateinit var addHydrationEntryUseCase: AddHydrationEntryUseCase
    private lateinit var deleteHydrationEntryUseCase: DeleteHydrationEntryUseCase
    private lateinit var viewModel: SimpleHydrationViewModel

    @Before
    fun setup() {
        getHydrationEntriesUseCase = mockk()
        addHydrationEntryUseCase = mockk()
        deleteHydrationEntryUseCase = mockk()

        viewModel = SimpleHydrationViewModel(
            getHydrationEntriesUseCase = getHydrationEntriesUseCase,
            addHydrationEntryUseCase = addHydrationEntryUseCase,
            deleteHydrationEntryUseCase = deleteHydrationEntryUseCase
        )
    }

    @Test
    fun `loadEntries updates state with loading and success`() = runTest {
        // Given
        val entries = MockFactory.createHydrationEntries(count = 3)
        coEvery { getHydrationEntriesUseCase() } returns entries

        // When & Then
        viewModel.uiState.test {
            // Initial state
            val initialState = awaitItem()
            assertFalse(initialState.isLoading)
            assertTrue(initialState.entries.isEmpty())

            // Load entries
            viewModel.loadEntries()

            // Loading state
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)
            assertNull(loadingState.error)

            // Success state
            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(3, successState.entries.size)
            assertEquals(entries, successState.entries)
            assertNull(successState.error)
        }
    }

    @Test
    fun `loadEntries calculates total intake correctly`() = runTest {
        // Given
        val entries = listOf(
            MockFactory.createHydrationEntry(amountMl = 250),
            MockFactory.createHydrationEntry(amountMl = 500),
            MockFactory.createHydrationEntry(amountMl = 300)
        )
        coEvery { getHydrationEntriesUseCase() } returns entries

        // When
        viewModel.loadEntries()

        // Then
        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(1050, state.totalIntakeMl) // 250 + 500 + 300
            assertTrue(state.hasEntries)
        }
    }

    @Test
    fun `loadEntries handles error correctly`() = runTest {
        // Given
        val errorMessage = "Network error"
        coEvery { getHydrationEntriesUseCase() } throws Exception(errorMessage)

        // When
        viewModel.loadEntries()

        // Then
        viewModel.uiState.test {
            val state = awaitItem()
            assertFalse(state.isLoading)
            assertEquals(errorMessage, state.error)
            assertTrue(state.entries.isEmpty())
        }
    }

    @Test
    fun `addEntry calls use case and reloads entries`() = runTest {
        // Given
        val drinkType = DrinkType.WATER
        val amountMl = 250
        val existingEntries = MockFactory.createHydrationEntries(count = 2)

        coEvery { addHydrationEntryUseCase(any()) } returns Unit
        coEvery { getHydrationEntriesUseCase() } returns existingEntries

        // When
        viewModel.addEntry(drinkType, amountMl)

        // Then
        coVerify { addHydrationEntryUseCase(match { entry ->
            entry.drinkType == drinkType &&
            entry.amountMl == amountMl &&
            entry.effectiveMl == amountMl // Water has 1.0 multiplier
        }) }
        coVerify { getHydrationEntriesUseCase() }
    }

    @Test
    fun `addEntry with coffee calculates effective ml correctly`() = runTest {
        // Given
        val drinkType = DrinkType.COFFEE
        val amountMl = 200
        val entries = emptyList<HydrationEntry>()

        coEvery { addHydrationEntryUseCase(any()) } returns Unit
        coEvery { getHydrationEntriesUseCase() } returns entries

        // When
        viewModel.addEntry(drinkType, amountMl)

        // Then
        coVerify { addHydrationEntryUseCase(match { entry ->
            entry.effectiveMl == 160 // 200 * 0.8 (coffee multiplier)
        }) }
    }

    @Test
    fun `deleteEntry removes entry and reloads`() = runTest {
        // Given
        val entryId = "test-entry-id"
        val remainingEntries = MockFactory.createHydrationEntries(count = 2)

        coEvery { deleteHydrationEntryUseCase(entryId) } returns Unit
        coEvery { getHydrationEntriesUseCase() } returns remainingEntries

        // When
        viewModel.deleteEntry(entryId)

        // Then
        coVerify { deleteHydrationEntryUseCase(entryId) }
        coVerify { getHydrationEntriesUseCase() }

        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(2, state.entries.size)
        }
    }

    @Test
    fun `clearError clears error state`() = runTest {
        // Given - trigger an error
        coEvery { getHydrationEntriesUseCase() } throws Exception("Test error")
        viewModel.loadEntries()

        // When
        viewModel.clearError()

        // Then
        viewModel.uiState.test {
            val state = awaitItem()
            assertNull(state.error)
        }
    }

    @Test
    fun `multiple load calls handle state correctly`() = runTest {
        // Given
        val firstEntries = MockFactory.createHydrationEntries(count = 2)
        val secondEntries = MockFactory.createHydrationEntries(count = 4)

        coEvery { getHydrationEntriesUseCase() } returnsMany listOf(firstEntries, secondEntries)

        // When
        viewModel.loadEntries()
        viewModel.loadEntries()

        // Then
        viewModel.uiState.test {
            val state = awaitItem()
            assertEquals(4, state.entries.size)
        }
    }

    @Test
    fun `empty entries shows correct state`() = runTest {
        // Given
        coEvery { getHydrationEntriesUseCase() } returns emptyList()

        // When
        viewModel.loadEntries()

        // Then
        viewModel.uiState.test {
            val state = awaitItem()
            assertFalse(state.hasEntries)
            assertEquals(0, state.totalIntakeMl)
            assertFalse(state.isLoading)
            assertNull(state.error)
        }
    }
}
