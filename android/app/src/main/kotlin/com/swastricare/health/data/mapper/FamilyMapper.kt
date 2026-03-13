package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.family.CreateFamilyGroupDto
import com.swastricare.health.data.remote.dto.family.CreateFamilyMemberDto
import com.swastricare.health.data.remote.dto.family.FamilyGroupDto
import com.swastricare.health.data.remote.dto.family.FamilyInviteDto
import com.swastricare.health.data.remote.dto.family.FamilyMemberDto
import com.swastricare.health.data.remote.dto.family.FamilyPermissionsDto
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyInvitation
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyPermissions
import com.swastricare.health.domain.model.FamilyRole
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper for converting between Family DTOs and Domain models.
 */
object FamilyMapper {

    private val isoFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    // ── FamilyGroup: DTO → Domain ──

    /**
     * Maps FamilyGroupDto (API/DB) to FamilyGroup (Domain).
     */
    fun toDomain(dto: FamilyGroupDto): FamilyGroup {
        return FamilyGroup(
            id = dto.id,
            name = dto.name,
            createdBy = dto.createdBy,
            inviteCode = dto.inviteCode,
            createdAt = dto.createdAt?.let { parseDateTime(it) }
        )
    }

    /**
     * Maps list of FamilyGroupDto to domain models.
     */
    fun toDomainList(dtos: List<FamilyGroupDto>): List<FamilyGroup> {
        return dtos.map { toDomain(it) }
    }

    // ── FamilyGroup: Domain → DTO ──

    /**
     * Maps FamilyGroup (Domain) to CreateFamilyGroupDto (API).
     */
    fun toCreateDto(group: FamilyGroup): CreateFamilyGroupDto {
        return CreateFamilyGroupDto(
            id = group.id,
            name = group.name,
            createdBy = group.createdBy
        )
    }

    // ── FamilyMember: DTO → Domain ──

    /**
     * Maps FamilyMemberDto (API/DB) to FamilyMember (Domain).
     */
    fun memberToDomain(dto: FamilyMemberDto): FamilyMember {
        return FamilyMember(
            id = dto.id,
            groupId = dto.groupId,
            userId = dto.userId,
            role = FamilyRole.fromDb(dto.role),
            fullName = dto.fullName,
            avatarUrl = dto.avatarUrl,
            joinedAt = dto.joinedAt?.let { parseDateTime(it) }
        )
    }

    /**
     * Maps list of FamilyMemberDto to domain models.
     */
    fun membersToDomainList(dtos: List<FamilyMemberDto>): List<FamilyMember> {
        return dtos.map { memberToDomain(it) }
    }

    // ── FamilyMember: Domain → DTO ──

    /**
     * Maps FamilyMember (Domain) to CreateFamilyMemberDto (API).
     */
    fun memberToCreateDto(member: FamilyMember): CreateFamilyMemberDto {
        return CreateFamilyMemberDto(
            id = member.id,
            groupId = member.groupId,
            userId = member.userId,
            role = member.role.dbValue,
            fullName = member.fullName
        )
    }

    // ── FamilyInvitation: DTO → Domain ──

    /**
     * Maps FamilyInviteDto to FamilyInvitation (Domain).
     */
    fun invitationToDomain(dto: FamilyInviteDto): FamilyInvitation {
        return FamilyInvitation(
            code = dto.code,
            groupId = dto.groupId,
            groupName = dto.groupName,
            expiresAt = dto.expiresAt?.let { parseDateTime(it) }
        )
    }

    // ── FamilyInvitation: Domain → DTO ──

    /**
     * Maps FamilyInvitation (Domain) to FamilyInviteDto.
     */
    fun invitationToDto(invitation: FamilyInvitation): FamilyInviteDto {
        return FamilyInviteDto(
            code = invitation.code,
            groupId = invitation.groupId,
            groupName = invitation.groupName,
            expiresAt = invitation.expiresAt?.let { formatDateTime(it) }
        )
    }

    // ── FamilyPermissions: DTO → Domain ──

    /**
     * Maps FamilyPermissionsDto to FamilyPermissions (Domain).
     */
    fun permissionsToDomain(dto: FamilyPermissionsDto): FamilyPermissions {
        return FamilyPermissions(
            memberId = dto.memberId,
            canViewHealthData = dto.canViewHealthData,
            canEditHealthData = dto.canEditHealthData,
            canManageMedications = dto.canManageMedications,
            canReceiveNotifications = dto.canReceiveNotifications
        )
    }

    // ── FamilyPermissions: Domain → DTO ──

    /**
     * Maps FamilyPermissions (Domain) to FamilyPermissionsDto.
     */
    fun permissionsToDto(permissions: FamilyPermissions): FamilyPermissionsDto {
        return FamilyPermissionsDto(
            memberId = permissions.memberId,
            canViewHealthData = permissions.canViewHealthData,
            canEditHealthData = permissions.canEditHealthData,
            canManageMedications = permissions.canManageMedications,
            canReceiveNotifications = permissions.canReceiveNotifications
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
