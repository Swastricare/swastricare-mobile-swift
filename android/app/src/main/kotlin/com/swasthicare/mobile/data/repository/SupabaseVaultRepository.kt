package com.swasthicare.mobile.data.repository

import android.util.Log
import com.swasthicare.mobile.data.model.DocumentMetadata
import com.swasthicare.mobile.data.model.MedicalDocument
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import java.util.UUID
import kotlin.time.Duration.Companion.hours

/**
 * Supabase-backed Vault repository.
 * Reads/writes to `medical_documents` table and `medical-vault` storage bucket.
 * Mirrors iOS SupabaseManager.swift vault operations.
 */
class SupabaseVaultRepository(
    private val supabaseClient: SupabaseClient
) : VaultRepository {

    private val bucketName = "medical-vault"
    private val tableName = "medical_documents"

    private fun requireUserId(): String {
        return supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("User not authenticated")
    }

    // ── Fetch Documents ──

    override suspend fun getDocuments(): List<MedicalDocument> = withContext(Dispatchers.IO) {
        val userId = requireUserId()
        try {
            supabaseClient.from(tableName).select {
                filter {
                    eq("user_id", userId)
                }
                order("uploaded_at", Order.DESCENDING)
            }.decodeList<MedicalDocument>()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch documents: ${e.message}")
            throw e
        }
    }

    // ── Upload Document ──

    override suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: String,
        metadata: DocumentMetadata
    ): MedicalDocument = withContext(Dispatchers.IO) {
        val userId = requireUserId()

        // Build a unique storage path: {userId}/{UUID}_{fileName}
        val sanitizedName = sanitizeFileName(fileName)
        val uniqueFileName = "${UUID.randomUUID()}_$sanitizedName"
        val storagePath = "$userId/$uniqueFileName"

        val fileExtension = fileName.substringAfterLast('.', "dat").lowercase()

        // 1. Upload binary to storage bucket
        try {
            val bucket = supabaseClient.storage[bucketName]
            bucket.upload(storagePath, fileData, upsert = true)
        } catch (e: Exception) {
            Log.e(TAG, "Storage upload failed for path: $storagePath", e)
            throw Exception("Unable to upload to bucket $bucketName: ${e.message}")
        }

        // 2. Determine document title (folderName > metadata.name > fileName without extension)
        val documentTitle = when {
            !metadata.folderName.isNullOrEmpty() -> metadata.folderName
            metadata.name.isNotEmpty() -> metadata.name
            else -> fileName.substringBeforeLast('.', fileName)
        }

        // 3. Insert document record into database
        val document = MedicalDocument(
            userId = userId,
            title = documentTitle,
            category = category,
            fileType = fileExtension.uppercase(),
            fileUrl = storagePath,
            fileSize = fileData.size.toLong(),
            notes = metadata.description,
            description = metadata.description,
            folderName = metadata.folderName,
            documentDate = metadata.documentDate,
            reminderDate = metadata.reminderDate,
            appointmentDate = metadata.appointmentDate,
            doctorName = metadata.doctorName,
            location = metadata.location,
            tags = metadata.tags.ifEmpty { null }
        )

        try {
            supabaseClient.from(tableName).insert(document)
            Log.d(TAG, "Document uploaded successfully: $documentTitle")
            // Re-fetch to get server-generated fields (id, created_at, uploaded_at, etc.)
            // Return the first matching document with this storage path
            val inserted = supabaseClient.from(tableName).select {
                filter {
                    eq("user_id", userId)
                    eq("file_url", storagePath)
                }
            }.decodeList<MedicalDocument>().firstOrNull() ?: document
            inserted
        } catch (e: Exception) {
            Log.e(TAG, "Database insert failed for document, cleaning up storage", e)
            // Rollback: remove the uploaded file from storage
            try {
                supabaseClient.storage[bucketName].delete(storagePath)
            } catch (cleanupError: Exception) {
                Log.w(TAG, "Failed to clean up storage after DB error: ${cleanupError.message}")
            }
            throw Exception("Failed to create document record: ${e.message}")
        }
    }

    // ── Delete Document ──

    override suspend fun deleteDocument(documentId: String): Unit = withContext(Dispatchers.IO) {
        val userId = requireUserId()

        // 1. Fetch document to get fileUrl for storage cleanup
        val document = try {
            supabaseClient.from(tableName).select {
                filter {
                    eq("id", documentId)
                    eq("user_id", userId)
                }
            }.decodeList<MedicalDocument>().firstOrNull()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch document for deletion: ${e.message}")
            null
        }

        // 2. Delete from storage (if we found the document)
        if (document != null && document.fileUrl.isNotEmpty()) {
            try {
                supabaseClient.storage[bucketName].delete(document.fileUrl)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to delete from storage (continuing with DB delete): ${e.message}")
            }
        }

        // 3. Delete from database
        try {
            supabaseClient.from(tableName).delete {
                filter {
                    eq("id", documentId)
                    eq("user_id", userId)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete document from DB: ${e.message}")
            throw e
        }
    }

    // ── Signed URL ──

    override suspend fun getSignedUrl(path: String): String = withContext(Dispatchers.IO) {
        require(path.isNotEmpty()) { "Storage path must not be empty" }
        try {
            val bucket = supabaseClient.storage[bucketName]
            bucket.createSignedUrl(path = path, expiresIn = 1.hours)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create signed URL for path '$path': ${e.message}")
            throw e
        }
    }

    // ── Update Document ──

    override suspend fun updateDocument(
        documentId: String,
        title: String,
        category: String,
        notes: String?,
        tags: List<String>
    ): MedicalDocument = withContext(Dispatchers.IO) {
        val userId = requireUserId()

        val updatePayload = buildJsonObject {
            put("title", title)
            put("category", category)
            if (notes != null) put("notes", notes)
            putJsonArray("tags") {
                tags.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
            }
        }

        try {
            supabaseClient.from(tableName).update(updatePayload) {
                filter {
                    eq("id", documentId)
                    eq("user_id", userId)
                }
            }

            // Re-fetch the updated document to return fresh data
            val updated = supabaseClient.from(tableName).select {
                filter {
                    eq("id", documentId)
                    eq("user_id", userId)
                }
            }.decodeList<MedicalDocument>().firstOrNull()
                ?: throw Exception("Document not found after update")

            updated
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update document $documentId: ${e.message}")
            throw e
        }
    }

    // ── Helpers ──

    /**
     * Sanitizes filename for storage: replaces spaces with underscores and removes
     * characters that are invalid in storage keys.
     */
    private fun sanitizeFileName(fileName: String): String {
        return fileName
            .replace(" ", "_")
            .replace(Regex("[^a-zA-Z0-9._-]"), "")
            .ifEmpty { "document" }
    }

    companion object {
        private const val TAG = "VaultRepository"
    }
}
