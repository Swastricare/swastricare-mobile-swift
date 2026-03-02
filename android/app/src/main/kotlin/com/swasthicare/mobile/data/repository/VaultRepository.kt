package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.DocumentMetadata
import com.swasthicare.mobile.data.model.MedicalDocument
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
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

class SupabaseVaultRepository(
    private val client: SupabaseClient,
    private val userId: String
) : VaultRepository {

    private val bucketId = "vault-documents"
    private val tableName = "vault_documents"

    override suspend fun getDocuments(): List<MedicalDocument> {
        return try {
            client.from(tableName).select {
                filter { eq("user_id", userId) }
                order("created_at", revert = true)
            }.decodeList<MedicalDocument>()
        } catch (e: Exception) {
            emptyList()
        }
    }

    override suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ): MedicalDocument {
        // 1. Upload file to Supabase Storage
        val storagePath = "$userId/$fileName"
        client.storage[bucketId].upload(storagePath, fileData, upsert = true)
        val fileUrl = client.storage[bucketId].publicUrl(storagePath)

        // 2. Insert metadata row
        val doc = MedicalDocument(
            userId = userId,
            title = metadata.name.ifEmpty { fileName },
            category = category,
            fileType = fileName.substringAfterLast('.', "dat"),
            fileUrl = fileUrl,
            fileSize = fileData.size.toLong(),
            doctorName = metadata.doctorName,
            location = metadata.location,
            documentDate = metadata.documentDate,
            notes = metadata.description
        )
        client.from(tableName).insert(doc)
        return doc
    }

    override suspend fun deleteDocument(documentId: String) {
        // Get file URL first to delete from storage
        val doc = client.from(tableName).select {
            filter { eq("id", documentId) }
        }.decodeSingleOrNull<MedicalDocument>()

        doc?.fileUrl?.let { url ->
            val path = url.substringAfter("$bucketId/")
            runCatching { client.storage[bucketId].delete(listOf(path)) }
        }

        client.from(tableName).delete {
            filter { eq("id", documentId) }
        }
    }

    override suspend fun getSignedUrl(path: String): String {
        return client.storage[bucketId].createSignedUrl(path, 3600)
    }
}
