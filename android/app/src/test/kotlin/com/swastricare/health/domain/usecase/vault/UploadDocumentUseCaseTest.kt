package com.swastricare.health.domain.usecase.vault

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument
import com.swastricare.health.domain.repository.VaultRepository
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
 * Unit tests for UploadDocumentUseCase.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class UploadDocumentUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var vaultRepository: VaultRepository
    private lateinit var useCase: UploadDocumentUseCase

    @Before
    fun setup() {
        vaultRepository = mockk()
        useCase = UploadDocumentUseCase(vaultRepository)
    }

    private fun createTestDocument() = MedicalDocument(
        id = "doc-id",
        title = "Blood Test Report",
        category = DocumentCategory.LAB_REPORT,
        filePath = "path/to/document.pdf",
        uploadedAt = LocalDate.now(),
        metadata = DocumentMetadata(
            doctorName = "Dr. Smith",
            hospitalName = "City Hospital",
            testDate = LocalDate.now()
        )
    )

    @Test
    fun `invoke uploads document successfully`() = runTest {
        // Given
        val fileData = "test file content".toByteArray()
        val fileName = "test-report.pdf"
        val category = DocumentCategory.LAB_REPORT
        val metadata = DocumentMetadata(doctorName = "Dr. Smith")
        val expectedDocument = createTestDocument()

        coEvery {
            vaultRepository.uploadDocument(fileData, fileName, category, metadata)
        } returns ResultWrapper.Success(expectedDocument)

        // When
        val result = useCase(fileData, fileName, category, metadata)

        // Then
        assertTrue(result is ResultWrapper.Success)
        coVerify { vaultRepository.uploadDocument(fileData, fileName, category, metadata) }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty file data throws exception`() = runTest {
        // Given
        val fileData = ByteArray(0)
        val fileName = "test.pdf"
        val category = DocumentCategory.LAB_REPORT
        val metadata = DocumentMetadata()

        // When
        useCase(fileData, fileName, category, metadata)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty file name throws exception`() = runTest {
        // Given
        val fileData = "test content".toByteArray()
        val fileName = ""
        val category = DocumentCategory.LAB_REPORT
        val metadata = DocumentMetadata()

        // When
        useCase(fileData, fileName, category, metadata)

        // Then - exception thrown
    }

    @Test
    fun `invoke with large file succeeds`() = runTest {
        // Given - 5MB file
        val fileData = ByteArray(5 * 1024 * 1024) { it.toByte() }
        val fileName = "large-report.pdf"
        val category = DocumentCategory.LAB_REPORT
        val metadata = DocumentMetadata()
        val expectedDocument = createTestDocument()

        coEvery {
            vaultRepository.uploadDocument(fileData, fileName, category, metadata)
        } returns ResultWrapper.Success(expectedDocument)

        // When
        val result = useCase(fileData, fileName, category, metadata)

        // Then
        assertTrue(result is ResultWrapper.Success)
    }

    @Test
    fun `invoke returns error on upload failure`() = runTest {
        // Given
        val fileData = "test content".toByteArray()
        val fileName = "test.pdf"
        val category = DocumentCategory.LAB_REPORT
        val metadata = DocumentMetadata()

        coEvery {
            vaultRepository.uploadDocument(fileData, fileName, category, metadata)
        } returns ResultWrapper.Error("Upload failed")

        // When
        val result = useCase(fileData, fileName, category, metadata)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }
}
