package com.swastricare.health.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationEntry
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime

/**
 * Example Compose UI test for Hydration screen.
 *
 * Demonstrates:
 * - Testing Compose UI components
 * - Finding nodes by text, content description, tag
 * - Performing click actions
 * - Asserting UI state
 * - Testing loading states
 * - Testing empty states
 * - Testing error states
 *
 * NOTE: This is a simplified example for demonstration purposes.
 * The actual HydrationScreen has more complex UI and interactions.
 */

/**
 * Simple UI state for testing.
 */
data class SimpleHydrationUiState(
    val entries: List<HydrationEntry> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val totalIntakeMl: Int = 0,
    val goalMl: Int = 2500
) {
    val progress: Float get() = if (goalMl > 0) (totalIntakeMl.toFloat() / goalMl).coerceIn(0f, 1f) else 0f
    val remainingMl: Int get() = maxOf(0, goalMl - totalIntakeMl)
}

/**
 * Simplified Hydration Screen for testing demonstration.
 */
@androidx.compose.runtime.Composable
fun SimpleHydrationScreen(
    uiState: SimpleHydrationUiState,
    onAddWater: () -> Unit = {},
    onRetry: () -> Unit = {}
) {
    androidx.compose.foundation.layout.Column(
        modifier = androidx.compose.ui.Modifier
            .fillMaxSize()
            .testTag("hydration_screen")
    ) {
        when {
            uiState.isLoading -> {
                androidx.compose.foundation.layout.Box(
                    modifier = androidx.compose.ui.Modifier.fillMaxSize(),
                    contentAlignment = androidx.compose.ui.Alignment.Center
                ) {
                    androidx.compose.material3.CircularProgressIndicator(
                        modifier = androidx.compose.ui.Modifier.testTag("loading_indicator")
                    )
                }
            }

            uiState.error != null -> {
                androidx.compose.foundation.layout.Column(
                    modifier = androidx.compose.ui.Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
                    verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center
                ) {
                    androidx.compose.material3.Text(
                        text = uiState.error,
                        modifier = androidx.compose.ui.Modifier.testTag("error_text")
                    )
                    androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.height(16.dp))
                    androidx.compose.material3.Button(
                        onClick = onRetry,
                        modifier = androidx.compose.ui.Modifier.testTag("retry_button")
                    ) {
                        androidx.compose.material3.Text("Retry")
                    }
                }
            }

            uiState.entries.isEmpty() -> {
                androidx.compose.foundation.layout.Column(
                    modifier = androidx.compose.ui.Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
                    verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center
                ) {
                    androidx.compose.material3.Text(
                        text = "No hydration entries yet",
                        modifier = androidx.compose.ui.Modifier.testTag("empty_state_text")
                    )
                    androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.height(16.dp))
                    androidx.compose.material3.Text(
                        text = "Start tracking your water intake!",
                        style = androidx.compose.material3.MaterialTheme.typography.bodyMedium
                    )
                }
            }

            else -> {
                // Progress Card
                androidx.compose.material3.Card(
                    modifier = androidx.compose.ui.Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .testTag("progress_card")
                ) {
                    androidx.compose.foundation.layout.Column(
                        modifier = androidx.compose.ui.Modifier.padding(16.dp)
                    ) {
                        androidx.compose.material3.Text(
                            text = "Today's Progress",
                            style = androidx.compose.material3.MaterialTheme.typography.titleLarge
                        )
                        androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.height(8.dp))
                        androidx.compose.material3.LinearProgressIndicator(
                            progress = uiState.progress,
                            modifier = androidx.compose.ui.Modifier
                                .fillMaxWidth()
                                .testTag("progress_indicator")
                        )
                        androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.height(8.dp))
                        androidx.compose.material3.Text(
                            text = "${uiState.totalIntakeMl}ml / ${uiState.goalMl}ml",
                            modifier = androidx.compose.ui.Modifier.testTag("progress_text")
                        )
                        androidx.compose.material3.Text(
                            text = "${uiState.remainingMl}ml remaining",
                            style = androidx.compose.material3.MaterialTheme.typography.bodySmall
                        )
                    }
                }

                // Entry List
                androidx.compose.foundation.lazy.LazyColumn(
                    modifier = androidx.compose.ui.Modifier.weight(1f)
                ) {
                    items(uiState.entries.size) { index ->
                        val entry = uiState.entries[index]
                        HydrationEntryItem(entry)
                    }
                }

                // Add Button
                androidx.compose.material3.FloatingActionButton(
                    onClick = onAddWater,
                    modifier = androidx.compose.ui.Modifier
                        .align(androidx.compose.ui.Alignment.End)
                        .padding(16.dp)
                        .testTag("add_water_button")
                ) {
                    androidx.compose.material3.Icon(
                        imageVector = androidx.compose.material.icons.Icons.Default.Add,
                        contentDescription = "Add water"
                    )
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
fun HydrationEntryItem(entry: HydrationEntry) {
    androidx.compose.material3.Card(
        modifier = androidx.compose.ui.Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .testTag("entry_item_${entry.id}")
    ) {
        androidx.compose.foundation.layout.Row(
            modifier = androidx.compose.ui.Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween
        ) {
            androidx.compose.material3.Text(
                text = entry.drinkType.displayName,
                style = androidx.compose.material3.MaterialTheme.typography.bodyLarge
            )
            androidx.compose.material3.Text(
                text = "${entry.amountMl}ml",
                style = androidx.compose.material3.MaterialTheme.typography.bodyMedium
            )
        }
    }
}

/**
 * UI tests for Hydration screen.
 */
class HydrationScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun hydrationScreen_displaysCorrectly() {
        // Given
        val entries = listOf(
            HydrationEntry(
                id = "1",
                drinkType = DrinkType.WATER,
                amountMl = 250,
                effectiveMl = 250,
                consumedAt = LocalDateTime.now()
            )
        )
        val uiState = SimpleHydrationUiState(
            entries = entries,
            totalIntakeMl = 250,
            goalMl = 2500
        )

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(uiState = uiState)
            }
        }

        // Then
        composeTestRule.onNodeWithTag("hydration_screen").assertExists()
        composeTestRule.onNodeWithTag("progress_card").assertExists()
        composeTestRule.onNodeWithText("Today's Progress").assertExists()
        composeTestRule.onNodeWithTag("add_water_button").assertExists()
    }

    @Test
    fun hydrationScreen_showsLoadingState() {
        // Given
        val uiState = SimpleHydrationUiState(isLoading = true)

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(uiState = uiState)
            }
        }

        // Then
        composeTestRule.onNodeWithTag("loading_indicator").assertExists()
        composeTestRule.onNodeWithTag("progress_card").assertDoesNotExist()
    }

    @Test
    fun hydrationScreen_showsEmptyState() {
        // Given
        val uiState = SimpleHydrationUiState(entries = emptyList())

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(uiState = uiState)
            }
        }

        // Then
        composeTestRule.onNodeWithTag("empty_state_text").assertExists()
        composeTestRule.onNodeWithText("No hydration entries yet").assertExists()
        composeTestRule.onNodeWithText("Start tracking your water intake!").assertExists()
    }

    @Test
    fun hydrationScreen_showsErrorState() {
        // Given
        val errorMessage = "Failed to load data"
        val uiState = SimpleHydrationUiState(error = errorMessage)

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(uiState = uiState)
            }
        }

        // Then
        composeTestRule.onNodeWithTag("error_text").assertTextEquals(errorMessage)
        composeTestRule.onNodeWithTag("retry_button").assertExists()
    }

    @Test
    fun hydrationScreen_retryButtonCallsCallback() {
        // Given
        var retryClicked = false
        val uiState = SimpleHydrationUiState(error = "Test error")

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(
                    uiState = uiState,
                    onRetry = { retryClicked = true }
                )
            }
        }

        // Then
        composeTestRule.onNodeWithTag("retry_button").performClick()
        assert(retryClicked)
    }

    @Test
    fun hydrationScreen_addWaterButtonCallsCallback() {
        // Given
        var addWaterClicked = false
        val entries = listOf(
            HydrationEntry(
                id = "1",
                drinkType = DrinkType.WATER,
                amountMl = 250,
                effectiveMl = 250,
                consumedAt = LocalDateTime.now()
            )
        )
        val uiState = SimpleHydrationUiState(entries = entries, totalIntakeMl = 250)

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(
                    uiState = uiState,
                    onAddWater = { addWaterClicked = true }
                )
            }
        }

        // Then
        composeTestRule.onNodeWithTag("add_water_button").performClick()
        assert(addWaterClicked)
    }

    @Test
    fun hydrationScreen_displaysProgressCorrectly() {
        // Given
        val uiState = SimpleHydrationUiState(
            entries = listOf(
                HydrationEntry(
                    id = "1",
                    drinkType = DrinkType.WATER,
                    amountMl = 1250,
                    effectiveMl = 1250,
                    consumedAt = LocalDateTime.now()
                )
            ),
            totalIntakeMl = 1250,
            goalMl = 2500
        )

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(uiState = uiState)
            }
        }

        // Then
        composeTestRule.onNodeWithTag("progress_text").assertTextEquals("1250ml / 2500ml")
        composeTestRule.onNodeWithText("1250ml remaining").assertExists()
    }

    @Test
    fun hydrationScreen_displaysMultipleEntries() {
        // Given
        val entries = listOf(
            HydrationEntry("1", DrinkType.WATER, 250, 250, LocalDateTime.now()),
            HydrationEntry("2", DrinkType.COFFEE, 200, 160, LocalDateTime.now()),
            HydrationEntry("3", DrinkType.TEA, 300, 255, LocalDateTime.now())
        )
        val uiState = SimpleHydrationUiState(entries = entries, totalIntakeMl = 750)

        // When
        composeTestRule.setContent {
            androidx.compose.material3.MaterialTheme {
                SimpleHydrationScreen(uiState = uiState)
            }
        }

        // Then
        composeTestRule.onNodeWithTag("entry_item_1").assertExists()
        composeTestRule.onNodeWithTag("entry_item_2").assertExists()
        composeTestRule.onNodeWithTag("entry_item_3").assertExists()
        composeTestRule.onNodeWithText("Water").assertExists()
        composeTestRule.onNodeWithText("Coffee").assertExists()
        composeTestRule.onNodeWithText("Tea").assertExists()
    }
}
