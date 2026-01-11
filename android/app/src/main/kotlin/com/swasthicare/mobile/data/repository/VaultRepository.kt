package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.DocumentMetadata
import com.swasthicare.mobile.data.model.MedicalDocument
import kotlinx.coroutines.delay
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

interface VaultRepository {
    suspend fun getDocuments(): List<MedicalDocument>
    suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ): MedicalDocument
    suspend fun deleteDocument(documentId: String)
    suspend fun getSignedUrl(path: String): String
}

class MockVaultRepository : VaultRepository {
    private val documents = mutableListOf<MedicalDocument>()

    init {
        // Add some mock data
        val formatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
        documents.add(
            MedicalDocument(
                id = UUID.randomUUID().toString(),
                title = "Blood Test Results",
                fileType = "pdf",
                category = "Lab Reports",
                fileSize = 1024 * 1024 * 2, // 2MB
                fileUrl = "mock/path/blood_test.pdf",
                createdAt = LocalDateTime.now().minusDays(2).format(formatter),
                documentDate = LocalDateTime.now().minusDays(2).format(formatter),
                doctorName = "Dr. Smith",
                location = "City Hospital"
            )
        )
        documents.add(
            MedicalDocument(
                id = UUID.randomUUID().toString(),
                title = "Prescription - Amoxicillin",
                fileType = "jpg",
                category = "Prescriptions",
                fileSize = 512 * 1024, // 512KB
                fileUrl = "mock/path/prescription.jpg",
                createdAt = LocalDateTime.now().minusWeeks(1).format(formatter),
                documentDate = LocalDateTime.now().minusWeeks(1).format(formatter),
                doctorName = "Dr. Jones",
                location = "Family Clinic"
            )
        )
    }

    override suspend fun getDocuments(): List<MedicalDocument> {
        delay(1000) // Simulate network delay
        return documents.toList()
    }

    override suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ): MedicalDocument {
        delay(2000)
        val doc = MedicalDocument(
            id = UUID.randomUUID().toString(),
            title = metadata.name.ifEmpty { fileName },
            fileType = fileName.substringAfterLast('.', "dat"),
            category = category,
            fileSize = fileData.size.toLong(),
            fileUrl = "mock/path/$fileName",
            createdAt = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            documentDate = metadata.documentDate
        )
        documents.add(0, doc)
        return doc
    }

    override suspend fun deleteDocument(documentId: String) {
        delay(500)
        documents.removeAll { it.id == documentId }
    }
    
    override suspend fun getSignedUrl(path: String): String {
        return "https://example.com/$path"
    }
}
