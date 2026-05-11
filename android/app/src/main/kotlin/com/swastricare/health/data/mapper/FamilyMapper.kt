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
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

object FamilyMapper {

    private val isoLocalFormatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME

    // ── FamilyGroup ──

    fun toDomain(dto: FamilyGroupDto): FamilyGroup = FamilyGroup(
        id = dto.id,
        name = dto.name,
        ownerUserId = dto.ownerUserId,
        inviteCode = dto.inviteCode,
        createdAt = dto.createdAt?.let { parseDateTime(it) }
    )

    fun toDomainList(dtos: List<FamilyGroupDto>): List<FamilyGroup> = dtos.map { toDomain(it) }

    fun toCreateDto(group: FamilyGroup, inviteCode: String? = null): CreateFamilyGroupDto =
        CreateFamilyGroupDto(
            id = group.id,
            name = group.name,
            ownerUserId = group.ownerUserId,
            inviteCode = inviteCode ?: group.inviteCode
        )

    // ── FamilyMember ──

    fun memberToDomain(dto: FamilyMemberDto): FamilyMember = FamilyMember(
        id = dto.id,
        groupId = dto.familyGroupId,
        healthProfileId = dto.healthProfileId,
        userId = dto.healthProfile?.userId,
        role = FamilyRole.fromDb(dto.role),
        fullName = dto.healthProfile?.fullName,
        avatarUrl = dto.healthProfile?.avatarUrl,
        joinedAt = dto.joinedAt?.let { parseDateTime(it) }
    )

    fun membersToDomainList(dtos: List<FamilyMemberDto>): List<FamilyMember> =
        dtos.map { memberToDomain(it) }

    // ── FamilyInvitation ──

    fun invitationToDomain(dto: FamilyInviteDto): FamilyInvitation = FamilyInvitation(
        code = dto.code,
        groupId = dto.groupId,
        groupName = dto.groupName,
        expiresAt = dto.expiresAt?.let { parseDateTime(it) }
    )

    fun invitationToDto(invitation: FamilyInvitation): FamilyInviteDto = FamilyInviteDto(
        code = invitation.code,
        groupId = invitation.groupId,
        groupName = invitation.groupName,
        expiresAt = invitation.expiresAt?.let { formatDateTime(it) }
    )

    // ── FamilyPermissions ──

    fun permissionsToDomain(dto: FamilyPermissionsDto): FamilyPermissions = FamilyPermissions(
        memberId = dto.memberId,
        canViewHealthData = dto.canViewHealthData,
        canEditHealthData = dto.canEditHealthData,
        canManageMedications = dto.canManageMedications,
        canReceiveNotifications = dto.canReceiveNotifications
    )

    fun permissionsToDto(permissions: FamilyPermissions): FamilyPermissionsDto = FamilyPermissionsDto(
        memberId = permissions.memberId,
        canViewHealthData = permissions.canViewHealthData,
        canEditHealthData = permissions.canEditHealthData,
        canManageMedications = permissions.canManageMedications,
        canReceiveNotifications = permissions.canReceiveNotifications
    )

    // ── DateTime helpers ──

    private fun parseDateTime(dateTime: String): LocalDateTime {
        // Supabase returns timestamptz like "2026-05-11T08:23:01.123456+00:00".
        return try {
            OffsetDateTime.parse(dateTime).toLocalDateTime()
        } catch (_: Exception) {
            try {
                LocalDateTime.parse(dateTime, isoLocalFormatter)
            } catch (_: Exception) {
                LocalDateTime.parse(dateTime.replace(" ", "T").substringBefore("+"), isoLocalFormatter)
            }
        }
    }

    private fun formatDateTime(dateTime: LocalDateTime): String =
        dateTime.format(isoLocalFormatter)
}
