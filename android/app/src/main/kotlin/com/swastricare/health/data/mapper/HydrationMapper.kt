package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.hydration.CreateHydrationEntryDto
import com.swastricare.health.data.remote.dto.hydration.HydrationEntryDto
import com.swastricare.health.data.remote.dto.hydration.HydrationPreferencesDto
import com.swastricare.health.domain.model.hydration.ActivityLevel
import com.swastricare.health.domain.model.hydration.DrinkType
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.model.hydration.HydrationPreferences
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper for converting between Hydration DTOs and Domain models.
 */
object HydrationMapper {

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    // ── Entry: DTO → Domain ──

    /**
     * Maps HydrationEntryDto (API/DB) to HydrationEntry (Domain).
     */
    fun toDomain(dto: HydrationEntryDto): HydrationEntry {
        val drinkType = DrinkType.fromDb(dto.beverageType)
        val effectiveMl = (dto.amountMl * dto.hydrationFactor).toInt()

        return HydrationEntry(
            id = dto.id,
            drinkType = drinkType,
            amountMl = dto.amountMl,
            effectiveMl = effectiveMl,
            consumedAt = parseDateTime(dto.consumedAt),
            notes = dto.notes,
            synced = true // Cloud entries are always synced
        )
    }

    /**
     * Maps list of DTOs to domain models.
     */
    fun toDomainList(dtos: List<HydrationEntryDto>): List<HydrationEntry> {
        return dtos.map { toDomain(it) }
    }

    // ── Entry: Domain → DTO ──

    /**
     * Maps HydrationEntry (Domain) to CreateHydrationEntryDto (API).
     */
    fun toCreateDto(entry: HydrationEntry, profileId: String): CreateHydrationEntryDto {
        return CreateHydrationEntryDto(
            id = entry.id,
            healthProfileId = profileId,
            beverageType = entry.drinkType.dbValue,
            amountMl = entry.amountMl,
            consumedAt = formatDateTime(entry.consumedAt),
            notes = entry.notes,
            hydrationFactor = entry.drinkType.hydrationMultiplier
        )
    }

    /**
     * Maps list of domain entries to DTOs.
     */
    fun toCreateDtoList(entries: List<HydrationEntry>, profileId: String): List<CreateHydrationEntryDto> {
        return entries.map { toCreateDto(it, profileId) }
    }

    // ── Preferences: DTO → Domain ──

    /**
     * Maps HydrationPreferencesDto to HydrationPreferences (Domain).
     */
    fun preferencesToDomain(dto: HydrationPreferencesDto): HydrationPreferences {
        return HydrationPreferences(
            activityLevel = ActivityLevel.fromDb(dto.activityLevel),
            weightKg = dto.weightKg,
            customGoalMl = dto.customGoalMl
        )
    }

    // ── Preferences: Domain → DTO ──

    /**
     * Maps HydrationPreferences (Domain) to HydrationPreferencesDto.
     */
    fun preferencesToDto(prefs: HydrationPreferences): HydrationPreferencesDto {
        return HydrationPreferencesDto(
            activityLevel = prefs.activityLevel.dbValue,
            weightKg = prefs.weightKg,
            customGoalMl = prefs.customGoalMl
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
            LocalDateTime.parse(dateTime.replace(" ", "T"), isoFormatter)
        }
    }

    /**
     * Format LocalDateTime to ISO string.
     */
    private fun formatDateTime(dateTime: LocalDateTime): String {
        return dateTime.format(isoFormatter)
    }
}
