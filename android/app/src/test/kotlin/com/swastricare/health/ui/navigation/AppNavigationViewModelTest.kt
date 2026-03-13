package com.swastricare.health.ui.navigation

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.swastricare.health.data.services.AppUpdateCheckResult
import com.swastricare.health.data.services.AppUpdateStatus
import com.swastricare.health.data.services.AppVersionService
import com.swastricare.health.data.services.SessionManager
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppNavigationViewModelTest {

    private lateinit var appVersionService: AppVersionService
    private lateinit var sessionManager: SessionManager
    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var viewModel: AppNavigationViewModel

    @Before
    fun setup() {
        appVersionService = mockk()
        sessionManager = mockk()
        dataStore = mockk(relaxed = true)
        viewModel = AppNavigationViewModel(appVersionService, sessionManager, dataStore)
    }

    @Test
    fun `checkForUpdate returns result on success`() = runTest {
        val expected = AppUpdateCheckResult(
            status = AppUpdateStatus.OPTIONAL_UPDATE,
            currentVersion = "1.0.0",
            currentBuild = 1
        )
        coEvery { appVersionService.checkForUpdate(any(), any()) } returns expected

        val result = viewModel.checkForUpdate()

        assertEquals(expected, result)
        coVerify { appVersionService.checkForUpdate(any(), any()) }
    }

    @Test
    fun `checkForUpdate returns null on exception`() = runTest {
        coEvery { appVersionService.checkForUpdate(any(), any()) } throws RuntimeException("Network error")

        val result = viewModel.checkForUpdate()

        assertNull(result)
    }

    @Test
    fun `shouldShowOptionalUpdate delegates to AppVersionService`() {
        every { appVersionService.shouldShowOptionalUpdate() } returns true
        assertTrue(viewModel.shouldShowOptionalUpdate())

        every { appVersionService.shouldShowOptionalUpdate() } returns false
        assertFalse(viewModel.shouldShowOptionalUpdate())
    }

    @Test
    fun `dismissOptionalUpdate delegates to AppVersionService`() {
        every { appVersionService.dismissOptionalUpdate() } just Runs

        viewModel.dismissOptionalUpdate()

        verify { appVersionService.dismissOptionalUpdate() }
    }
}
