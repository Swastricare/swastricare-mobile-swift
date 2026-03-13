package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.profile.HealthProfileDto
import com.swastricare.health.data.remote.dto.profile.UserProfileDto
import com.swastricare.health.data.remote.dto.profile.UserSettingsDto
import com.swastricare.health.domain.model.profile.Gender
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.model.profile.ReminderFrequency
import com.swastricare.health.domain.model.profile.UserProfile
import com.swastricare.health.domain.model.profile.UserSettings
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper for converting between Profile DTOs and Domain models.
 */
object ProfileMapper {

    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val dateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    // ── HealthProfile: DTO → Domain ──

    /**
     * Maps HealthProfileDto (API/DB) to HealthProfile (Domain).
     */
    fun healthProfileToDomain(dto: HealthProfileDto): HealthProfile {
        return HealthProfile(
            id = dto.id ?: "",
            userId = dto.userId,
            fullName = dto.fullName,
            gender = Gender.fromDb(dto.gender),
            dateOfBirth = parseDate(dto.dateOfBirth),
            heightCm = dto.heightCm,
            weightKg = dto.weightKg,
            bloodType = dto.bloodType
        )
    }

    // ── HealthProfile: Domain → DTO ──

    /**
     * Maps HealthProfile (Domain) to HealthProfileDto (API/DB).
     */
    fun healthProfileToDto(profile: HealthProfile): HealthProfileDto {
        return HealthProfileDto(
            id = profile.id.ifEmpty { null },
            userId = profile.userId,
            fullName = profile.fullName,
            gender = profile.gender.dbValue,
            dateOfBirth = formatDate(profile.dateOfBirth),
            heightCm = profile.heightCm,
            weightKg = profile.weightKg,
            bloodType = profile.bloodType
        )
    }

    // ── UserProfile: DTO → Domain ──

    /**
     * Maps UserProfileDto (API/DB) to UserProfile (Domain).
     */
    fun userProfileToDomain(dto: UserProfileDto): UserProfile {
        return UserProfile(
            id = dto.id,
            email = dto.email,
            fullName = dto.fullName,
            phone = dto.phone,
            bio = dto.bio,
            avatarUrl = dto.avatarUrl,
            createdAt = parseDateTime(dto.createdAt ?: "")
        )
    }

    // ── UserSettings: DTO → Domain ──

    /**
     * Maps UserSettingsDto to UserSettings (Domain).
     */
    fun userSettingsToDomain(dto: UserSettingsDto): UserSettings {
        return UserSettings(
            notificationsEnabled = dto.notificationsEnabled,
            biometricLockEnabled = dto.biometricLockEnabled,
            healthSyncEnabled = dto.healthSyncEnabled,
            darkModeEnabled = dto.darkModeEnabled,
            reminderFrequency = ReminderFrequency.fromDb(dto.reminderFrequency)
        )
    }

    // ── UserSettings: Domain → DTO ──

    /**
     * Maps UserSettings (Domain) to UserSettingsDto.
     */
    fun userSettingsToDto(settings: UserSettings): UserSettingsDto {
        return UserSettingsDto(
            notificationsEnabled = settings.notificationsEnabled,
            biometricLockEnabled = settings.biometricLockEnabled,
            healthSyncEnabled = settings.healthSyncEnabled,
            darkModeEnabled = settings.darkModeEnabled,
            reminderFrequency = settings.reminderFrequency.dbValue
        )
    }

    // ── DateTime helpers ──

    /**
     * Parse date string (yyyy-MM-dd) to LocalDate.
     */
    private fun parseDate(date: String): LocalDate {
        return try {
            LocalDate.parse(date, dateFormatter)
        } catch (e: Exception) {
            LocalDate.now()
        }
    }

    /**
     * Format LocalDate to string (yyyy-MM-dd).
     */
    private fun formatDate(date: LocalDate): String {
        return date.format(dateFormatter)
    }

    /**
     * Parse ISO datetime string to LocalDateTime.
     */
    private fun parseDateTime(dateTime: String): LocalDateTime {
        return try {
            if (dateTime.isEmpty()) {
                LocalDateTime.now()
            } else {
                // Handle both ISO format with 'T' and space separator
                val normalized = dateTime.replace(" ", "T").take(19) // Take only date and time part
                LocalDateTime.parse(normalized, dateTimeFormatter)
            }
        } catch (e: Exception) {
            LocalDateTime.now()
        }
    }
}
