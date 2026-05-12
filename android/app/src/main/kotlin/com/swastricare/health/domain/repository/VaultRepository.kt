package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.VaultDocSummary
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument

/**
 * Repository contract for Vault (Medical Documents) data.
 * Implemented in data layer.
 */
interface VaultRepository {

    // ── Document Operations ──

    /**
     * Get all documents for the current user.
     */
    suspend fun getDocuments(): ResultWrapper<List<MedicalDocument>>

    /**
     * Get a specific document by ID.
     */
    suspend fun getDocumentById(documentId: String): ResultWrapper<MedicalDocument>

    /**
     * Upload a new document.
     */
    suspend fun uploadDocument(
        fileData: ByteArray,
        fileName: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): ResultWrapper<MedicalDocument>

    /**
     * Update document metadata.
     */
    suspend fun updateDocument(
        documentId: String,
        title: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): ResultWrapper<MedicalDocument>

    /**
     * Delete a document.
     */
    suspend fun deleteDocument(documentId: String): ResultWrapper<Unit>

    /**
     * Delete multiple documents.
     */
    suspend fun deleteDocuments(documentIds: List<String>): ResultWrapper<Unit>

    // ── File Operations ──

    /**
     * Get signed URL for accessing a document file.
     */
    suspend fun getSignedUrl(path: String): ResultWrapper<String>

    /**
     * Download document file data.
     */
    suspend fun downloadDocument(documentId: String): ResultWrapper<ByteArray>

    // ── Search & Filter ──

    /**
     * Search documents by query.
     */
    suspend fun searchDocuments(query: String): ResultWrapper<List<MedicalDocument>>

    /**
     * Get documents by category.
     */
    suspend fun getDocumentsByCategory(category: DocumentCategory): ResultWrapper<List<MedicalDocument>>

    /**
     * Get documents by folder name.
     */
    suspend fun getDocumentsByFolder(folderName: String): ResultWrapper<List<MedicalDocument>>

    // ── Sharing ──

    /**
     * Share document with family member.
     */
    suspend fun shareDocument(
        documentId: String,
        recipientProfileId: String
    ): ResultWrapper<Unit>

    /**
     * Get shared documents.
     */
    suspend fun getSharedDocuments(): ResultWrapper<List<MedicalDocument>>

    // ── Family Dashboard ──

    /**
     * List a thin document summary for the target health profile, suitable
     * for the family-member dashboard. Family-via-`has_family_access` reads
     * are granted by Supabase RLS (migration 20260512000006), so caregivers
     * can call this for member profiles without owning the profile.
     */
    suspend fun listForProfile(profileId: String): ResultWrapper<List<VaultDocSummary>>
}
