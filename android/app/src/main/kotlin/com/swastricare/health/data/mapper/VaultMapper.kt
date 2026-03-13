package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.vault.CreateMedicalDocumentDto
import com.swastricare.health.data.remote.dto.vault.MedicalDocumentDto
import com.swastricare.health.data.remote.dto.vault.UpdateMedicalDocumentDto
import com.swastricare.health.domain.model.vault.DocumentCategory
import com.swastricare.health.domain.model.vault.DocumentMetadata
import com.swastricare.health.domain.model.vault.MedicalDocument
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper for converting between Vault DTOs and Domain models.
 */
object VaultMapper {

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    // ── Document: DTO → Domain ──

    /**
     * Maps MedicalDocumentDto (API/DB) to MedicalDocument (Domain).
     */
    fun toDomain(dto: MedicalDocumentDto): MedicalDocument {
        val metadata = if (hasMetadata(dto)) {
            DocumentMetadata(
                description = dto.description,
                folderName = dto.folderName,
                documentDate = dto.documentDate?.let { parseDateTime(it) },
                reminderDate = dto.reminderDate?.let { parseDateTime(it) },
                appointmentDate = dto.appointmentDate?.let { parseDateTime(it) },
                doctorName = dto.doctorName,
                location = dto.location,
                tags = dto.tags ?: emptyList(),
                notes = dto.notes
            )
        } else {
            null
        }

        return MedicalDocument(
            id = dto.id,
            userId = dto.userId,
            title = dto.title,
            category = DocumentCategory.fromDb(dto.category),
            fileType = dto.fileType,
            fileUrl = dto.fileUrl,
            fileSize = dto.fileSize,
            uploadedAt = parseDateTime(dto.uploadedAt),
            createdAt = parseDateTime(dto.createdAt),
            updatedAt = dto.updatedAt?.let { parseDateTime(it) },
            metadata = metadata
        )
    }

    /**
     * Maps list of DTOs to domain models.
     */
    fun toDomainList(dtos: List<MedicalDocumentDto>): List<MedicalDocument> {
        return dtos.map { toDomain(it) }
    }

    /**
     * Check if DTO has any metadata fields populated.
     */
    private fun hasMetadata(dto: MedicalDocumentDto): Boolean {
        return dto.description != null ||
                dto.folderName != null ||
                dto.documentDate != null ||
                dto.reminderDate != null ||
                dto.appointmentDate != null ||
                dto.doctorName != null ||
                dto.location != null ||
                !dto.tags.isNullOrEmpty() ||
                dto.notes != null
    }

    // ── Document: Domain → Create DTO ──

    /**
     * Maps MedicalDocument creation request to CreateMedicalDocumentDto.
     */
    fun toCreateDto(
        userId: String,
        title: String,
        category: DocumentCategory,
        fileType: String,
        fileUrl: String,
        fileSize: Long,
        metadata: DocumentMetadata
    ): CreateMedicalDocumentDto {
        return CreateMedicalDocumentDto(
            id = java.util.UUID.randomUUID().toString(),
            userId = userId,
            title = title,
            category = category.dbValue,
            fileType = fileType,
            fileUrl = fileUrl,
            fileSize = fileSize,
            description = metadata.description,
            folderName = metadata.folderName,
            documentDate = metadata.documentDate?.let { formatDateTime(it) },
            reminderDate = metadata.reminderDate?.let { formatDateTime(it) },
            appointmentDate = metadata.appointmentDate?.let { formatDateTime(it) },
            doctorName = metadata.doctorName,
            location = metadata.location,
            tags = metadata.tags.ifEmpty { null },
            notes = metadata.notes
        )
    }

    // ── Document: Domain → Update DTO ──

    /**
     * Maps document update request to UpdateMedicalDocumentDto.
     */
    fun toUpdateDto(
        title: String,
        category: DocumentCategory,
        metadata: DocumentMetadata
    ): UpdateMedicalDocumentDto {
        return UpdateMedicalDocumentDto(
            title = title,
            category = category.dbValue,
            description = metadata.description,
            folderName = metadata.folderName,
            documentDate = metadata.documentDate?.let { formatDateTime(it) },
            reminderDate = metadata.reminderDate?.let { formatDateTime(it) },
            appointmentDate = metadata.appointmentDate?.let { formatDateTime(it) },
            doctorName = metadata.doctorName,
            location = metadata.location,
            tags = metadata.tags.ifEmpty { null },
            notes = metadata.notes
        )
    }

    // ── DateTime helpers ──

    /**
     * Parse ISO datetime string to LocalDateTime.
     */
    private fun parseDateTime(dateTime: String): LocalDateTime {
        return try {
            LocalDateTime.parse(dateTime, isoFormatter)
        } catch (e: Exception) {
            // Fallback: try with 'T' separator if missing
            try {
                LocalDateTime.parse(dateTime.replace(" ", "T"), isoFormatter)
            } catch (e2: Exception) {
                // Last resort: try parsing with zone info stripped
                val cleaned = dateTime.substringBefore("+").substringBefore("Z").replace(" ", "T")
                LocalDateTime.parse(cleaned, isoFormatter)
            }
        }
    }

    /**
     * Format LocalDateTime to ISO string.
     */
    private fun formatDateTime(dateTime: LocalDateTime): String {
        return dateTime.format(isoFormatter)
    }
}
