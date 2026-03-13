package com.swastricare.health.ui.screens.splash

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.swastricare.health.di.ONBOARDING_COMPLETE_KEY
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SplashViewModelTest {

    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var viewModel: SplashViewModel

    @Before
    fun setup() {
        dataStore = mockk()
    }

    @Test
    fun `isOnboardingComplete returns true when preference is set`() = runTest {
        val prefs = mockk<Preferences> {
            every { get(ONBOARDING_COMPLETE_KEY) } returns true
        }
        every { dataStore.data } returns flowOf(prefs)
        viewModel = SplashViewModel(dataStore)

        assertTrue(viewModel.isOnboardingComplete())
    }

    @Test
    fun `isOnboardingComplete returns false when preference is not set`() = runTest {
        val prefs = mockk<Preferences> {
            every { get(ONBOARDING_COMPLETE_KEY) } returns null
        }
        every { dataStore.data } returns flowOf(prefs)
        viewModel = SplashViewModel(dataStore)

        assertFalse(viewModel.isOnboardingComplete())
    }

    @Test
    fun `isOnboardingComplete returns false when preference is false`() = runTest {
        val prefs = mockk<Preferences> {
            every { get(ONBOARDING_COMPLETE_KEY) } returns false
        }
        every { dataStore.data } returns flowOf(prefs)
        viewModel = SplashViewModel(dataStore)

        assertFalse(viewModel.isOnboardingComplete())
    }
}
