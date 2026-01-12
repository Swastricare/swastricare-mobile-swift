package com.swasthicare.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class MedicalDocument(
    val id: String? = null,
    @SerialName("user_id")
    val userId: String? = null,
    val title: String,
    val category: String,
    @SerialName("file_type")
    val fileType: String,
    @SerialName("file_url")
    val fileUrl: String,
    @SerialName("file_size")
    val fileSize: Long,
    @SerialName("uploaded_at")
    val uploadedAt: String? = null,
    val notes: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
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
    val location: String? = null,
    val tags: List<String>? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)

data class DocumentMetadata(
    val name: String,
    val description: String? = null,
    val folderName: String? = null,
    val documentDate: String? = null,
    val reminderDate: String? = null,
    val appointmentDate: String? = null,
    val doctorName: String? = null,
    val location: String? = null,
    val tags: List<String> = emptyList()
)
