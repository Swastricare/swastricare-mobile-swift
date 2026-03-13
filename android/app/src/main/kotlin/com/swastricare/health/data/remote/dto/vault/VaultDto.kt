package com.swastricare.health.data.remote.dto.vault

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for medical_documents table in Supabase.
 * Maps directly to database schema.
 */
@Serializable
data class MedicalDocumentDto(
    @SerialName("id")
    val id: String,

    @SerialName("user_id")
    val userId: String,

    @SerialName("title")
    val title: String,

    @SerialName("category")
    val category: String,

    @SerialName("file_type")
    val fileType: String,

    @SerialName("file_url")
    val fileUrl: String,

    @SerialName("file_size")
    val fileSize: Long,

    @SerialName("uploaded_at")
    val uploadedAt: String,

    @SerialName("created_at")
    val createdAt: String,

    @SerialName("updated_at")
    val updatedAt: String? = null,

    @SerialName("description")
    val description: String? = null,

    @SerialName("folder_name")
    val folderName: String? = null,

    @SerialName("document_date")
    val documentDate: String? = null,

    @SerialName("reminder_date")
    val reminderDate: String? = null,

    @SerialName("appointment_date")
    val appointmentDate: String? = null,

    @SerialName("doctor_name")
    val doctorName: String? = null,

    @SerialName("location")
    val location: String? = null,

    @SerialName("tags")
    val tags: List<String>? = null,

    @SerialName("notes")
    val notes: String? = null
)

/**
 * DTO for creating a new medical document.
 */
@Serializable
data class CreateMedicalDocumentDto(
    @SerialName("id")
    val id: String,

    @SerialName("user_id")
    val userId: String,

    @SerialName("title")
    val title: String,

    @SerialName("category")
    val category: String,

    @SerialName("file_type")
    val fileType: String,

    @SerialName("file_url")
    val fileUrl: String,

    @SerialName("file_size")
    val fileSize: Long,

    @SerialName("description")
    val description: String? = null,

    @SerialName("folder_name")
    val folderName: String? = null,

    @SerialName("document_date")
    val documentDate: String? = null,

    @SerialName("reminder_date")
    val reminderDate: String? = null,

    @SerialName("appointment_date")
    val appointmentDate: String? = null,

    @SerialName("doctor_name")
    val doctorName: String? = null,

    @SerialName("location")
    val location: String? = null,

    @SerialName("tags")
    val tags: List<String>? = null,

    @SerialName("notes")
    val notes: String? = null
)

/**
 * DTO for updating a medical document.
 */
@Serializable
data class UpdateMedicalDocumentDto(
    @SerialName("title")
    val title: String,

    @SerialName("category")
    val category: String,

    @SerialName("description")
    val description: String? = null,

    @SerialName("folder_name")
    val folderName: String? = null,

    @SerialName("document_date")
    val documentDate: String? = null,

    @SerialName("reminder_date")
    val reminderDate: String? = null,

    @SerialName("appointment_date")
    val appointmentDate: String? = null,

    @SerialName("doctor_name")
    val doctorName: String? = null,

    @SerialName("location")
    val location: String? = null,

    @SerialName("tags")
    val tags: List<String>? = null,

    @SerialName("notes")
    val notes: String? = null
)
