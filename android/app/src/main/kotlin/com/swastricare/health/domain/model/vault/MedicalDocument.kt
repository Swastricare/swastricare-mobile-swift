package com.swastricare.health.domain.model.vault

import java.time.LocalDateTime

/**
 * Domain model for a medical document.
 * Pure business model with no Android/Framework dependencies.
 */
data class MedicalDocument(
    val id: String,
    val userId: String,
    val title: String,
    val category: DocumentCategory,
    val fileType: String,
    val fileUrl: String,
    val fileSize: Long,
    val uploadedAt: LocalDateTime,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime? = null,
    val metadata: DocumentMetadata? = null
) {
    /**
     * Business logic: Get file extension.
     */
    fun getFileExtension(): String = fileType.lowercase()

    /**
     * Business logic: Check if document is an image.
     */
    fun isImage(): Boolean = fileType.lowercase() in listOf("jpg", "jpeg", "png", "gif", "bmp", "webp")

    /**
     * Business logic: Check if document is a PDF.
     */
    fun isPdf(): Boolean = fileType.lowercase() == "pdf"

    /**
     * Business logic: Get formatted file size.
     */
    fun getFormattedFileSize(): String {
        return when {
            fileSize < 1024 -> "$fileSize B"
            fileSize < 1024 * 1024 -> "${fileSize / 1024} KB"
            else -> "${fileSize / (1024 * 1024)} MB"
        }
    }

    /**
     * Business logic: Check if document has appointment.
     */
    fun hasAppointment(): Boolean = metadata?.appointmentDate != null
}

/**
 * Domain model for document metadata.
 */
data class DocumentMetadata(
    val description: String? = null,
    val folderName: String? = null,
    val documentDate: LocalDateTime? = null,
    val reminderDate: LocalDateTime? = null,
    val appointmentDate: LocalDateTime? = null,
    val doctorName: String? = null,
    val location: String? = null,
    val tags: List<String> = emptyList(),
    val notes: String? = null
) {
    /**
     * Business logic: Check if metadata has any date fields.
     */
    fun hasDates(): Boolean = documentDate != null || reminderDate != null || appointmentDate != null

    /**
     * Business logic: Check if metadata has doctor information.
     */
    fun hasDoctorInfo(): Boolean = doctorName != null || location != null
}

/**
 * Domain enum for document categories.
 */
enum class DocumentCategory(val displayName: String, val iconName: String, val colorHex: Long) {
    PRESCRIPTIONS("Prescriptions", "medication", 0xFFFF5252),
    LAB_REPORTS("Lab Reports", "science", 0xFF448AFF),
    IMAGING("Imaging", "image", 0xFF7C4DFF),
    INSURANCE("Insurance", "verified_user", 0xFF4CAF50),
    VACCINATIONS("Vaccinations", "vaccines", 0xFFFFC107),
    OTHER("Other", "folder", 0xFF9E9E9E);

    companion object {
        /**
         * Get category from display name string.
         */
        fun fromDisplayName(name: String): DocumentCategory {
            return entries.find { it.displayName.equals(name, ignoreCase = true) } ?: OTHER
        }

        /**
         * Get category from database value.
         */
        fun fromDb(value: String): DocumentCategory {
            return entries.find { it.name.equals(value, ignoreCase = true) } ?: OTHER
        }
    }

    /**
     * Get database value.
     */
    val dbValue: String get() = name
}
