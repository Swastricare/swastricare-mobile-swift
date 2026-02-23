//
//  FamilyService.swift
//  swastricare-mobile-swift
//
//  Family Management Service - Supabase CRUD Operations
//

import Foundation
import Supabase

// MARK: - Protocol

protocol FamilyServiceProtocol {
    // Groups
    func fetchFamilyGroups() async throws -> [FamilyGroup]
    func fetchSharedFamilyGroups() async throws -> [FamilyGroup]
    func createFamilyGroup(name: String, description: String?) async throws -> FamilyGroup
    func updateFamilyGroup(_ group: FamilyGroup) async throws -> FamilyGroup
    func deleteFamilyGroup(groupId: UUID) async throws

    // Members
    func fetchFamilyMembers(groupId: UUID) async throws -> [FamilyMember]
    func updateMemberRole(memberId: UUID, role: FamilyMemberRole) async throws
    func updateMemberPermissions(memberId: UUID, permissions: MemberPermissions) async throws
    func removeMember(memberId: UUID) async throws
    func addDependentMember(groupId: UUID, healthProfileId: UUID, relationship: String?) async throws -> FamilyMember

    // Invites
    func createInvite(groupId: UUID, role: FamilyMemberRole, email: String?) async throws -> FamilyInvite
    func fetchInvitesForGroup(groupId: UUID) async throws -> [FamilyInvite]
    func lookupInvite(code: String) async throws -> FamilyInviteWithGroup
    func acceptInvite(code: String) async throws -> FamilyGroup
    func revokeInvite(inviteId: UUID) async throws
}

// MARK: - Member Permissions

struct MemberPermissions: Codable {
    var canView: Bool
    var canEdit: Bool
    var canAddMedications: Bool
    var canAddAppointments: Bool
    var canViewMedicalDocuments: Bool
    var canManageMembers: Bool
    
    static let viewer = MemberPermissions(
        canView: true, canEdit: false, canAddMedications: false,
        canAddAppointments: false, canViewMedicalDocuments: true, canManageMembers: false
    )
    
    static let caregiver = MemberPermissions(
        canView: true, canEdit: true, canAddMedications: true,
        canAddAppointments: true, canViewMedicalDocuments: true, canManageMembers: false
    )
    
    static let limited = MemberPermissions(
        canView: true, canEdit: false, canAddMedications: false,
        canAddAppointments: false, canViewMedicalDocuments: false, canManageMembers: false
    )
}

// MARK: - Implementation

final class FamilyService: FamilyServiceProtocol {
    static let shared = FamilyService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    // MARK: - Groups

    func fetchFamilyGroups() async throws -> [FamilyGroup] {
        guard let userId = try? await client.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }

        let groups: [FamilyGroup] = try await client
            .from("family_groups")
            .select()
            .eq("owner_user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        var result: [FamilyGroup] = []
        for var group in groups {
            group.memberCount = try await fetchMemberCount(groupId: group.id)
            result.append(group)
        }

        return result
    }

    func fetchSharedFamilyGroups() async throws -> [FamilyGroup] {
        guard let userId = try? await client.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }

        // Prefer primary profile when available, fallback to any.
        guard let healthProfileId = try await fetchPrimaryHealthProfileId(for: userId) else {
            return []
        }

        struct MembershipRow: Decodable { let family_group_id: UUID }
        let memberships: [MembershipRow] = try await client
            .from("family_members")
            .select("family_group_id")
            .eq("health_profile_id", value: healthProfileId.uuidString)
            .eq("status", value: "active")
            .execute()
            .value

        let groupIds = Array(Set(memberships.map(\.family_group_id)))
        if groupIds.isEmpty { return [] }

        let basics: [FamilyGroupBasic] = try await client
            .from("family_groups")
            .select("id, name, description, owner_user_id")
            .in("id", values: groupIds.map { $0.uuidString })
            .execute()
            .value

        var groups: [FamilyGroup] = []
        for basic in basics where basic.ownerUserId != userId {
            var group = FamilyGroup(
                id: basic.id,
                ownerUserId: basic.ownerUserId,
                name: basic.name,
                description: basic.description
            )
            group.memberCount = try await fetchMemberCount(groupId: basic.id)
            groups.append(group)
        }

        return groups
    }

    func createFamilyGroup(name: String, description: String?) async throws -> FamilyGroup {
        guard let userId = try? await client.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }

        struct NewGroup: Encodable {
            let owner_user_id: UUID
            let name: String
            let description: String?
            let allow_member_invites: Bool
            let require_approval: Bool
            let created_at: Date
            let updated_at: Date
        }

        let payload = NewGroup(
            owner_user_id: userId,
            name: name,
            description: description,
            allow_member_invites: false,
            require_approval: true,
            created_at: Date(),
            updated_at: Date()
        )

        var inserted: FamilyGroup = try await client
            .from("family_groups")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        inserted.memberCount = try await fetchMemberCount(groupId: inserted.id)
        return inserted
    }

    func updateFamilyGroup(_ group: FamilyGroup) async throws -> FamilyGroup {
        struct GroupUpdate: Encodable {
            let name: String
            let description: String?
            let allow_member_invites: Bool
            let require_approval: Bool
            let updated_at: Date
        }
        
        let payload = GroupUpdate(
            name: group.name,
            description: group.description,
            allow_member_invites: group.allowMemberInvites,
            require_approval: group.requireApproval,
            updated_at: Date()
        )
        
        let updated: FamilyGroup = try await client
            .from("family_groups")
            .update(payload)
            .eq("id", value: group.id.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    func deleteFamilyGroup(groupId: UUID) async throws {
        try await client
            .from("family_groups")
            .delete()
            .eq("id", value: groupId.uuidString)
            .execute()
    }

    private func fetchMemberCount(groupId: UUID) async throws -> Int {
        struct CountRow: Decodable { let id: UUID }
        let members: [CountRow] = try await client
            .from("family_members")
            .select("id")
            .eq("family_group_id", value: groupId.uuidString)
            .eq("status", value: "active")
            .execute()
            .value
        return members.count
    }

    // MARK: - Members

    func fetchFamilyMembers(groupId: UUID) async throws -> [FamilyMember] {
        var members: [FamilyMember] = try await client
            .from("family_members")
            .select()
            .eq("family_group_id", value: groupId.uuidString)
            .neq("status", value: "removed")
            .order("created_at", ascending: true)
            .execute()
            .value

        // Best-effort profile enrichment (does not require FK embedding)
        do {
            let profileIds = Array(Set(members.map(\.healthProfileId)))
            if !profileIds.isEmpty {
                let profiles: [HealthProfileBasic] = try await client
                    .from("health_profiles")
                    .select("id, user_id, full_name, gender, date_of_birth")
                    .in("id", values: profileIds.map { $0.uuidString })
                    .execute()
                    .value

                let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
                for i in members.indices {
                    if let p = byId[members[i].healthProfileId] {
                        members[i].memberName = p.fullName
                        members[i].memberGender = p.gender
                        members[i].memberDateOfBirth = p.dateOfBirth
                    }
                }
            }
        } catch {
            // Keep members usable even if full profile decode fails (e.g., DOB decoding).
            print("⚠️ FamilyService: profile enrichment failed - \(error)")

            do {
                let profileIds = Array(Set(members.map(\.healthProfileId)))
                struct NameRow: Decodable {
                    let id: UUID
                    let full_name: String?
                    let gender: String?
                }
                let rows: [NameRow] = try await client
                    .from("health_profiles")
                    .select("id, full_name, gender")
                    .in("id", values: profileIds.map { $0.uuidString })
                    .execute()
                    .value

                let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
                for i in members.indices {
                    if let p = byId[members[i].healthProfileId] {
                        if let name = p.full_name, !name.isEmpty { members[i].memberName = name }
                        members[i].memberGender = members[i].memberGender ?? p.gender
                    }
                }
            } catch {
                print("⚠️ FamilyService: fallback name enrichment failed - \(error)")
            }
        }

        return members
    }
    
    func updateMemberRole(memberId: UUID, role: FamilyMemberRole) async throws {
        let permissions: MemberPermissions
        switch role {
        case .owner, .caregiver:
            permissions = .caregiver
        case .viewer:
            permissions = .viewer
        case .limited:
            permissions = .limited
        }
        
        struct RoleUpdate: Encodable {
            let role: String
            let can_view: Bool
            let can_edit: Bool
            let can_add_medications: Bool
            let can_add_appointments: Bool
            let can_view_medical_documents: Bool
            let can_manage_members: Bool
            let updated_at: Date
        }
        
        let payload = RoleUpdate(
            role: role.rawValue,
            can_view: permissions.canView,
            can_edit: permissions.canEdit,
            can_add_medications: permissions.canAddMedications,
            can_add_appointments: permissions.canAddAppointments,
            can_view_medical_documents: permissions.canViewMedicalDocuments,
            can_manage_members: permissions.canManageMembers,
            updated_at: Date()
        )
        
        try await client
            .from("family_members")
            .update(payload)
            .eq("id", value: memberId.uuidString)
            .execute()
    }
    
    func updateMemberPermissions(memberId: UUID, permissions: MemberPermissions) async throws {
        struct PermissionsUpdate: Encodable {
            let can_view: Bool
            let can_edit: Bool
            let can_add_medications: Bool
            let can_add_appointments: Bool
            let can_view_medical_documents: Bool
            let can_manage_members: Bool
            let updated_at: Date
        }
        
        let payload = PermissionsUpdate(
            can_view: permissions.canView,
            can_edit: permissions.canEdit,
            can_add_medications: permissions.canAddMedications,
            can_add_appointments: permissions.canAddAppointments,
            can_view_medical_documents: permissions.canViewMedicalDocuments,
            can_manage_members: permissions.canManageMembers,
            updated_at: Date()
        )
        
        try await client
            .from("family_members")
            .update(payload)
            .eq("id", value: memberId.uuidString)
            .execute()
    }
    
    func removeMember(memberId: UUID) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let updated_at: Date
        }
        
        let payload = StatusUpdate(status: "removed", updated_at: Date())
        
        try await client
            .from("family_members")
            .update(payload)
            .eq("id", value: memberId.uuidString)
            .execute()
    }
    
    func addDependentMember(groupId: UUID, healthProfileId: UUID, relationship: String?) async throws -> FamilyMember {
        guard let userId = try? await client.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }
        
        struct NewMember: Encodable {
            let family_group_id: UUID
            let health_profile_id: UUID
            let added_by_user_id: UUID
            let role: String
            let can_view: Bool
            let can_edit: Bool
            let can_add_medications: Bool
            let can_add_appointments: Bool
            let can_view_medical_documents: Bool
            let can_manage_members: Bool
            let status: String
            let relationship: String?
            let joined_at: Date
            let created_at: Date
            let updated_at: Date
        }
        
        let payload = NewMember(
            family_group_id: groupId,
            health_profile_id: healthProfileId,
            added_by_user_id: userId,
            role: FamilyMemberRole.viewer.rawValue,
            can_view: true,
            can_edit: false,
            can_add_medications: false,
            can_add_appointments: false,
            can_view_medical_documents: true,
            can_manage_members: false,
            status: "active",
            relationship: relationship,
            joined_at: Date(),
            created_at: Date(),
            updated_at: Date()
        )
        
        let member: FamilyMember = try await client
            .from("family_members")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        
        return member
    }

    // MARK: - Invites

    func createInvite(groupId: UUID, role: FamilyMemberRole, email: String? = nil) async throws -> FamilyInvite {
        guard let userId = try? await client.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }

        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<8).compactMap { _ in chars.randomElement() })
        let expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)

        struct NewInvite: Encodable {
            let family_group_id: UUID
            let invite_code: String
            let invited_email: String?
            let invited_by_user_id: UUID
            let role: String
            let status: String
            let expires_at: Date
            let created_at: Date
            let updated_at: Date
        }

        let payload = NewInvite(
            family_group_id: groupId,
            invite_code: code,
            invited_email: email,
            invited_by_user_id: userId,
            role: role.rawValue,
            status: "pending",
            expires_at: expiresAt,
            created_at: Date(),
            updated_at: Date()
        )

        let inserted: FamilyInvite = try await client
            .from("family_invites")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return inserted
    }

    func fetchInvitesForGroup(groupId: UUID) async throws -> [FamilyInvite] {
        let invites: [FamilyInvite] = try await client
            .from("family_invites")
            .select()
            .eq("family_group_id", value: groupId.uuidString)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        return invites
    }

    func lookupInvite(code: String) async throws -> FamilyInviteWithGroup {
        // Fetch invite row
        var invite: FamilyInviteWithGroup = try await client
            .from("family_invites")
            .select()
            .eq("invite_code", value: code.uppercased())
            .eq("status", value: "pending")
            .single()
            .execute()
            .value

        // Fetch group basics separately (best effort).
        do {
            let group: FamilyGroupBasic = try await client
                .from("family_groups")
                .select("id, name, description, owner_user_id")
                .eq("id", value: invite.familyGroupId.uuidString)
                .single()
                .execute()
                .value
            invite.familyGroup = group
        } catch {
            print("⚠️ FamilyService: group lookup for invite failed - \(error)")
        }

        return invite
    }

    func acceptInvite(code: String) async throws -> FamilyGroup {
        guard let userId = try? await client.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }

        let invite = try await lookupInvite(code: code)
        if let expiresAt = invite.expiresAt, Date() > expiresAt {
            throw FamilyServiceError.inviteExpired
        }

        guard let healthProfileId = try await fetchPrimaryHealthProfileId(for: userId) else {
            throw FamilyServiceError.noHealthProfile
        }

        // Already a member?
        struct MemberCheck: Decodable { let id: UUID }
        let existing: [MemberCheck] = try await client
            .from("family_members")
            .select("id")
            .eq("family_group_id", value: invite.familyGroupId.uuidString)
            .eq("health_profile_id", value: healthProfileId.uuidString)
            .neq("status", value: "removed")
            .execute()
            .value
        if !existing.isEmpty { throw FamilyServiceError.alreadyMember }

        // Create membership
        struct NewMember: Encodable {
            let family_group_id: UUID
            let health_profile_id: UUID
            let added_by_user_id: UUID
            let role: String
            let can_view: Bool
            let can_edit: Bool
            let can_add_medications: Bool
            let can_add_appointments: Bool
            let can_view_medical_documents: Bool
            let can_manage_members: Bool
            let status: String
            let relationship: String?
            let joined_at: Date
            let created_at: Date
            let updated_at: Date
        }

        let role = FamilyMemberRole(rawValue: invite.role ?? "viewer") ?? .viewer
        let payload = NewMember(
            family_group_id: invite.familyGroupId,
            health_profile_id: healthProfileId,
            added_by_user_id: invite.invitedByUserId,
            role: role.rawValue,
            can_view: true,
            can_edit: role == .caregiver,
            can_add_medications: role == .caregiver,
            can_add_appointments: role == .caregiver,
            can_view_medical_documents: role != .limited,
            can_manage_members: false,
            status: "active",
            relationship: nil,
            joined_at: Date(),
            created_at: Date(),
            updated_at: Date()
        )

        try await client
            .from("family_members")
            .insert(payload)
            .execute()

        // Update invite
        struct InviteUpdate: Encodable {
            let status: String
            let accepted_by_user_id: UUID
            let accepted_at: Date
            let updated_at: Date
        }
        let update = InviteUpdate(
            status: "accepted",
            accepted_by_user_id: userId,
            accepted_at: Date(),
            updated_at: Date()
        )

        try await client
            .from("family_invites")
            .update(update)
            .eq("id", value: invite.id.uuidString)
            .execute()

        // Return group
        let group: FamilyGroup = try await client
            .from("family_groups")
            .select()
            .eq("id", value: invite.familyGroupId.uuidString)
            .single()
            .execute()
            .value

        return group
    }

    func revokeInvite(inviteId: UUID) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let updated_at: Date
        }
        let update = StatusUpdate(status: "revoked", updated_at: Date())
        try await client
            .from("family_invites")
            .update(update)
            .eq("id", value: inviteId.uuidString)
            .execute()
    }

    // MARK: - Helpers

    private func fetchPrimaryHealthProfileId(for userId: UUID) async throws -> UUID? {
        struct ProfileIdRow: Decodable { let id: UUID }

        var rows: [ProfileIdRow] = try await client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_primary", value: true)
            .limit(1)
            .execute()
            .value

        if rows.isEmpty {
            rows = try await client
                .from("health_profiles")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
        }

        return rows.first?.id
    }
}

// MARK: - Errors

enum FamilyServiceError: LocalizedError {
    case notAuthenticated
    case inviteExpired
    case alreadyMember
    case noHealthProfile

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to manage family"
        case .inviteExpired:
            return "This invite has expired"
        case .alreadyMember:
            return "You are already a member of this family group"
        case .noHealthProfile:
            return "Please complete your health profile first"
        }
    }
}

