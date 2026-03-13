package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.VaultMapper
import com.swastricare.health.data.remote.dto.vault.MedicalDocumentDto
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument
import com.swastricare.health.domain.repository.VaultRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject
import kotlin.time.Duration.Companion.hours

/**
 * Implementation of VaultRepository using Supabase.
 * Handles medical document storage and retrieval.
 *
 * Storage structure:
 * - Files: Supabase Storage bucket "medical-vault"
 * - Metadata: PostgreSQL table "medical_documents"
 */
class VaultRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val logger: Logger
) : VaultRepository {

    companion object {
        private const val TAG = "VaultRepository"
        private const val BUCKET_NAME = "medical-vault"
        private const val TABLE_NAME = "medical_documents"
        private const val MAX_FILE_SIZE = 50 * 1024 * 1024L // 50MB
    }

    // ── Helpers ──

    /**
     * Get current authenticated user ID.
     */
    private fun requireUserId(): String {
        return supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("User not authenticated")
    }

    /**
     * Sanitize filename for storage.
     */
    private fun sanitizeFileName(fileName: String): String {
        return fileName
            .replace(" ", "_")
            .replace(Regex("[^a-zA-Z0-9._-]"), "")
            .ifEmpty { "document" }
    }

    /**
     * Map exceptions to domain exceptions.
     */
    private fun mapException(e: Exception): AppException {
        return when {
            e.message?.contains("network", ignoreCase = true) == true ->
                AppException.NetworkException.Unknown(e)
            e.message?.contains("unauthorized", ignoreCase = true) == true ->
                AppException.ApiException.Unauthorized()
            e.message?.contains("not found", ignoreCase = true) == true ->
                AppException.ApiException.NotFound(e.message)
            else -> AppException.UnknownException(cause = e)
        }
    }

    // ── Document Operations ──

    override suspend fun getDocuments(): ResultWrapper<List<MedicalDocument>> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Fetching documents for user: $userId")

                val dtos = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("user_id", userId)
                        }
                        order("uploaded_at", Order.DESCENDING)
                    }
                    .decodeList<MedicalDocumentDto>()

                val documents = VaultMapper.toDomainList(dtos)
                logger.d(TAG, "Fetched ${documents.size} documents")

                ResultWrapper.Success(documents)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch documents", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun getDocumentById(documentId: String): ResultWrapper<MedicalDocument> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Fetching document: $documentId")

                val dto = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("id", documentId)
                            eq("user_id", userId)
                        }
                    }
                    .decodeSingleOrNull<MedicalDocumentDto>()
                    ?: return@withContext ResultWrapper.Error(
                        AppException.ApiException.NotFound("Document not found")
                    )

                val document = VaultMapper.toDomain(dto)
                ResultWrapper.Success(document)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch document by ID", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): ResultWrapper<MedicalDocument> = withContext(Dispatchers.IO) {
        try {
            val userId = requireUserId()
            logger.d(TAG, "Uploading document: $fileName")

            // Validate file size
            if (fileData.size > MAX_FILE_SIZE) {
                return@withContext ResultWrapper.Error(
                    AppException.ValidationException.Custom("File size exceeds maximum of 50MB")
                )
            }

            // Build storage path: {userId}/{UUID}_{fileName}
            val sanitizedName = sanitizeFileName(fileName)
            val uniqueFileName = "${UUID.randomUUID()}_$sanitizedName"
            val storagePath = "$userId/$uniqueFileName"
            val fileExtension = fileName.substringAfterLast('.', "dat").lowercase()

            // 1. Upload to storage bucket
            try {
                val bucket = supabaseClient.storage[BUCKET_NAME]
                bucket.upload(storagePath, fileData, upsert = true)
                logger.d(TAG, "File uploaded to storage: $storagePath")
            } catch (e: Exception) {
                logger.e(TAG, "Storage upload failed", e)
                return@withContext ResultWrapper.Error(
                    AppException.UnknownException("Failed to upload file to storage", e)
                )
            }

            // 2. Determine document title
            val documentTitle = when {
                !metadata.folderName.isNullOrEmpty() -> metadata.folderName!!
                !metadata.description.isNullOrEmpty() -> metadata.description!!
                else -> fileName.substringBeforeLast('.', fileName)
            }

            // 3. Create document record in database
            val createDto = VaultMapper.toCreateDto(
                userId = userId,
                title = documentTitle,
                category = category,
                fileType = fileExtension,
                fileUrl = storagePath,
                fileSize = fileData.size.toLong(),
                metadata = metadata
            )

            try {
                supabaseClient.from(TABLE_NAME).insert(createDto)
                logger.d(TAG, "Document record created in database")

                // Re-fetch to get server-generated fields
                val inserted = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("user_id", userId)
                            eq("file_url", storagePath)
                        }
                    }
                    .decodeSingleOrNull<MedicalDocumentDto>()
                    ?: return@withContext ResultWrapper.Error(
                        AppException.ApiException.NotFound("Failed to retrieve uploaded document")
                    )

                val document = VaultMapper.toDomain(inserted)
                ResultWrapper.Success(document)
            } catch (e: Exception) {
                logger.e(TAG, "Database insert failed, cleaning up storage", e)
                // Rollback: delete uploaded file
                try {
                    supabaseClient.storage[BUCKET_NAME].delete(storagePath)
                } catch (cleanupError: Exception) {
                    logger.w(TAG, "Failed to cleanup storage after error", cleanupError)
                }
                ResultWrapper.Error(mapException(e))
            }
        } catch (e: Exception) {
            logger.e(TAG, "Unexpected error during upload", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    override suspend fun updateDocument(
        documentId: String,
        title: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): ResultWrapper<MedicalDocument> = withContext(Dispatchers.IO) {
        try {
            val userId = requireUserId()
            logger.d(TAG, "Updating document: $documentId")

            val updateDto = VaultMapper.toUpdateDto(title, category, metadata)

            supabaseClient.from(TABLE_NAME).update(updateDto) {
                filter {
                    eq("id", documentId)
                    eq("user_id", userId)
                }
            }

            // Re-fetch updated document
            val updated = supabaseClient.from(TABLE_NAME)
                .select {
                    filter {
                        eq("id", documentId)
                        eq("user_id", userId)
                    }
                }
                .decodeSingleOrNull<MedicalDocumentDto>()
                ?: return@withContext ResultWrapper.Error(
                    AppException.ApiException.NotFound("Document not found after update")
                )

            val document = VaultMapper.toDomain(updated)
            logger.d(TAG, "Document updated successfully")
            ResultWrapper.Success(document)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to update document", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    override suspend fun deleteDocument(documentId: String): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Deleting document: $documentId")

                // 1. Fetch document to get storage path
                val document = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("id", documentId)
                            eq("user_id", userId)
                        }
                    }
                    .decodeSingleOrNull<MedicalDocumentDto>()

                // 2. Delete from storage
                if (document != null && document.fileUrl.isNotEmpty()) {
                    try {
                        supabaseClient.storage[BUCKET_NAME].delete(document.fileUrl)
                        logger.d(TAG, "File deleted from storage")
                    } catch (e: Exception) {
                        logger.w(TAG, "Failed to delete from storage (continuing)", e)
                    }
                }

                // 3. Delete from database
                supabaseClient.from(TABLE_NAME).delete {
                    filter {
                        eq("id", documentId)
                        eq("user_id", userId)
                    }
                }

                logger.d(TAG, "Document deleted successfully")
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to delete document", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun deleteDocuments(documentIds: List<String>): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Deleting ${documentIds.size} documents")

                val errors = mutableListOf<String>()

                documentIds.forEach { documentId ->
                    when (val result = deleteDocument(documentId)) {
                        is ResultWrapper.Error -> errors.add(documentId)
                        is ResultWrapper.Success -> { /* success */ }
                        else -> { /* ignore loading state */ }
                    }
                }

                if (errors.isNotEmpty()) {
                    logger.w(TAG, "Failed to delete ${errors.size} documents")
                    ResultWrapper.Error(
                        AppException.UnknownException(
                            "Failed to delete ${errors.size} documents"
                        )
                    )
                } else {
                    logger.d(TAG, "All documents deleted successfully")
                    ResultWrapper.Success(Unit)
                }
            } catch (e: Exception) {
                logger.e(TAG, "Failed to delete documents", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    // ── File Operations ──

    override suspend fun getSignedUrl(path: String): ResultWrapper<String> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Getting signed URL for: $path")

                val bucket = supabaseClient.storage[BUCKET_NAME]
                val url = bucket.createSignedUrl(path = path, expiresIn = 1.hours)

                logger.d(TAG, "Signed URL created")
                ResultWrapper.Success(url)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to create signed URL", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun downloadDocument(documentId: String): ResultWrapper<ByteArray> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Downloading document: $documentId")

                // Get document to find storage path
                val document = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("id", documentId)
                            eq("user_id", userId)
                        }
                    }
                    .decodeSingleOrNull<MedicalDocumentDto>()
                    ?: return@withContext ResultWrapper.Error(
                        AppException.ApiException.NotFound("Document not found")
                    )

                // Download from storage
                val bucket = supabaseClient.storage[BUCKET_NAME]
                val fileData = bucket.downloadPublic(document.fileUrl)

                logger.d(TAG, "Document downloaded: ${fileData.size} bytes")
                ResultWrapper.Success(fileData)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to download document", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    // ── Search & Filter ──

    override suspend fun searchDocuments(query: String): ResultWrapper<List<MedicalDocument>> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Searching documents: $query")

                val dtos = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("user_id", userId)
                            or {
                                ilike("title", "%$query%")
                                ilike("description", "%$query%")
                                ilike("doctor_name", "%$query%")
                            }
                        }
                        order("uploaded_at", Order.DESCENDING)
                    }
                    .decodeList<MedicalDocumentDto>()

                val documents = VaultMapper.toDomainList(dtos)
                logger.d(TAG, "Found ${documents.size} documents")
                ResultWrapper.Success(documents)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to search documents", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun getDocumentsByCategory(category: DocumentCategory): ResultWrapper<List<MedicalDocument>> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Fetching documents for category: ${category.displayName}")

                val dtos = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("user_id", userId)
                            eq("category", category.dbValue)
                        }
                        order("uploaded_at", Order.DESCENDING)
                    }
                    .decodeList<MedicalDocumentDto>()

                val documents = VaultMapper.toDomainList(dtos)
                logger.d(TAG, "Found ${documents.size} documents in category")
                ResultWrapper.Success(documents)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch documents by category", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun getDocumentsByFolder(folderName: String): ResultWrapper<List<MedicalDocument>> =
        withContext(Dispatchers.IO) {
            try {
                val userId = requireUserId()
                logger.d(TAG, "Fetching documents for folder: $folderName")

                val dtos = supabaseClient.from(TABLE_NAME)
                    .select {
                        filter {
                            eq("user_id", userId)
                            eq("folder_name", folderName)
                        }
                        order("uploaded_at", Order.DESCENDING)
                    }
                    .decodeList<MedicalDocumentDto>()

                val documents = VaultMapper.toDomainList(dtos)
                logger.d(TAG, "Found ${documents.size} documents in folder")
                ResultWrapper.Success(documents)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch documents by folder", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    // ── Sharing ──

    override suspend fun shareDocument(
        documentId: String,
        recipientProfileId: String
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val userId = requireUserId()
            logger.d(TAG, "Sharing document $documentId with profile $recipientProfileId")

            // TODO: Implement document sharing via family access table
            // This will require a shared_documents table or family_document_access table

            logger.w(TAG, "Document sharing not yet implemented")
            ResultWrapper.Error(
                AppException.UnknownException("Document sharing coming soon")
            )
        } catch (e: Exception) {
            logger.e(TAG, "Failed to share document", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    override suspend fun getSharedDocuments(): ResultWrapper<List<MedicalDocument>> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Fetching shared documents")

                // TODO: Implement fetching shared documents
                // This will query the shared_documents or family_document_access table

                logger.w(TAG, "Shared documents not yet implemented")
                ResultWrapper.Success(emptyList())
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch shared documents", e)
                ResultWrapper.Error(mapException(e))
            }
        }
}
