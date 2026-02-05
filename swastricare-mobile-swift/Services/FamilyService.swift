//
//  FamilyService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles family group, member, and emergency contact operations with Supabase
//

import Foundation

// MARK: - Family Service Protocol

protocol FamilyServiceProtocol {
    // Groups
    func fetchMyGroups() async throws -> [FamilyGroup]
    func createGroup(name: String, description: String?) async throws -> FamilyGroup
    func updateGroup(_ group: FamilyGroup) async throws -> FamilyGroup
    func deleteGroup(id: UUID) async throws

    // Members
    func fetchMembers(groupId: UUID) async throws -> [FamilyMember]
    func addMember(groupId: UUID, healthProfileId: UUID, role: FamilyRole, relationship: String?) async throws -> FamilyMember
    func updateMemberRole(memberId: UUID, role: FamilyRole, permissions: MemberPermissions) async throws
    func updateMemberStatus(memberId: UUID, status: FamilyMemberStatus) async throws
    func removeMember(memberId: UUID) async throws

    // Emergency Contacts
    func fetchEmergencyContacts() async throws -> [EmergencyContact]
    func addEmergencyContact(_ contact: EmergencyContact) async throws -> EmergencyContact
    func updateEmergencyContact(_ contact: EmergencyContact) async throws -> EmergencyContact
    func deleteEmergencyContact(id: UUID) async throws

    // Health Summaries
    func fetchMemberHealthSummary(healthProfileId: UUID) async throws -> MemberHealthSummary?
}

// MARK: - Family Service Implementation

final class FamilyService: FamilyServiceProtocol {

    static let shared = FamilyService()

    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Groups

    func fetchMyGroups() async throws -> [FamilyGroup] {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            throw FamilyError.notAuthenticated
        }

        let groups: [FamilyGroup] = try await supabase.client
            .from("family_groups")
            .select()
            .eq("owner_user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return groups
    }

    func createGroup(name: String, description: String?) async throws -> FamilyGroup {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            throw FamilyError.notAuthenticated
        }

        struct CreatePayload: Encodable {
            let owner_user_id: UUID
            let name: String
            let description: String?
        }

        let payload = CreatePayload(owner_user_id: userId, name: name, description: description)

        let group: FamilyGroup = try await supabase.client
            .from("family_groups")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return group
    }

    func updateGroup(_ group: FamilyGroup) async throws -> FamilyGroup {
        struct UpdatePayload: Encodable {
            let name: String
            let description: String?
            let allow_member_invites: Bool
            let require_approval: Bool
        }

        let payload = UpdatePayload(
            name: group.name,
            description: group.description,
            allow_member_invites: group.allowMemberInvites,
            require_approval: group.requireApproval
        )

        let updated: FamilyGroup = try await supabase.client
            .from("family_groups")
            .update(payload)
            .eq("id", value: group.id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    func deleteGroup(id: UUID) async throws {
        try await supabase.client
            .from("family_groups")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Members

    func fetchMembers(groupId: UUID) async throws -> [FamilyMember] {
        let members: [FamilyMember] = try await supabase.client
            .from("family_members")
            .select()
            .eq("family_group_id", value: groupId.uuidString)
            .neq("status", value: "removed")
            .order("created_at", ascending: true)
            .execute()
            .value

        return members
    }

    func addMember(groupId: UUID, healthProfileId: UUID, role: FamilyRole, relationship: String?) async throws -> FamilyMember {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            throw FamilyError.notAuthenticated
        }

        let defaultPermissions = MemberPermissions.defaults(for: role)

        struct AddPayload: Encodable {
            let family_group_id: UUID
            let health_profile_id: UUID
            let added_by_user_id: UUID
            let role: String
            let relationship: String?
            let status: String
            let can_view: Bool
            let can_edit: Bool
            let can_add_medications: Bool
            let can_add_appointments: Bool
            let can_view_medical_documents: Bool
            let can_manage_members: Bool
        }

        let payload = AddPayload(
            family_group_id: groupId,
            health_profile_id: healthProfileId,
            added_by_user_id: userId,
            role: role.rawValue,
            relationship: relationship,
            status: FamilyMemberStatus.active.rawValue,
            can_view: defaultPermissions.canView,
            can_edit: defaultPermissions.canEdit,
            can_add_medications: defaultPermissions.canAddMedications,
            can_add_appointments: defaultPermissions.canAddAppointments,
            can_view_medical_documents: defaultPermissions.canViewMedicalDocuments,
            can_manage_members: defaultPermissions.canManageMembers
        )

        let member: FamilyMember = try await supabase.client
            .from("family_members")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return member
    }

    func updateMemberRole(memberId: UUID, role: FamilyRole, permissions: MemberPermissions) async throws {
        struct UpdatePayload: Encodable {
            let role: String
            let can_view: Bool
            let can_edit: Bool
            let can_add_medications: Bool
            let can_add_appointments: Bool
            let can_view_medical_documents: Bool
            let can_manage_members: Bool
        }

        let payload = UpdatePayload(
            role: role.rawValue,
            can_view: permissions.canView,
            can_edit: permissions.canEdit,
            can_add_medications: permissions.canAddMedications,
            can_add_appointments: permissions.canAddAppointments,
            can_view_medical_documents: permissions.canViewMedicalDocuments,
            can_manage_members: permissions.canManageMembers
        )

        try await supabase.client
            .from("family_members")
            .update(payload)
            .eq("id", value: memberId.uuidString)
            .execute()
    }

    func updateMemberStatus(memberId: UUID, status: FamilyMemberStatus) async throws {
        struct StatusPayload: Encodable {
            let status: String
        }

        try await supabase.client
            .from("family_members")
            .update(StatusPayload(status: status.rawValue))
            .eq("id", value: memberId.uuidString)
            .execute()
    }

    func removeMember(memberId: UUID) async throws {
        try await updateMemberStatus(memberId: memberId, status: .removed)
    }

    // MARK: - Emergency Contacts

    func fetchEmergencyContacts() async throws -> [EmergencyContact] {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            throw FamilyError.notAuthenticated
        }

        struct ProfileId: Decodable { let id: UUID }

        let profiles: [ProfileId] = try await supabase.client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_primary", value: true)
            .limit(1)
            .execute()
            .value

        guard let profileId = profiles.first?.id else {
            throw FamilyError.noHealthProfile
        }

        let contacts: [EmergencyContact] = try await supabase.client
            .from("emergency_contacts")
            .select()
            .eq("health_profile_id", value: profileId.uuidString)
            .order("priority", ascending: true)
            .execute()
            .value

        return contacts
    }

    func addEmergencyContact(_ contact: EmergencyContact) async throws -> EmergencyContact {
        let saved: EmergencyContact = try await supabase.client
            .from("emergency_contacts")
            .insert(contact)
            .select()
            .single()
            .execute()
            .value

        return saved
    }

    func updateEmergencyContact(_ contact: EmergencyContact) async throws -> EmergencyContact {
        let updated: EmergencyContact = try await supabase.client
            .from("emergency_contacts")
            .update(contact)
            .eq("id", value: contact.id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    func deleteEmergencyContact(id: UUID) async throws {
        try await supabase.client
            .from("emergency_contacts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Member Health Summary

    func fetchMemberHealthSummary(healthProfileId: UUID) async throws -> MemberHealthSummary? {
        // Fetch the health profile basic info
        struct ProfileInfo: Decodable {
            let id: UUID
            let full_name: String
            let avatar_url: String?
        }

        let profiles: [ProfileInfo] = try await supabase.client
            .from("health_profiles")
            .select("id, full_name, avatar_url")
            .eq("id", value: healthProfileId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let profile = profiles.first else { return nil }

        return MemberHealthSummary(
            memberId: profile.id,
            profileName: profile.full_name,
            avatarURL: profile.avatar_url,
            relationship: nil,
            lastUpdated: Date()
        )
    }
}

// MARK: - Family Error

enum FamilyError: LocalizedError {
    case notAuthenticated
    case noHealthProfile
    case groupNotFound
    case memberNotFound
    case permissionDenied
    case duplicateMember
    case cannotRemoveOwner
    case invalidInvite
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to manage family."
        case .noHealthProfile: return "No health profile found. Complete your profile first."
        case .groupNotFound: return "Family group not found."
        case .memberNotFound: return "Family member not found."
        case .permissionDenied: return "You don't have permission for this action."
        case .duplicateMember: return "This person is already a family member."
        case .cannotRemoveOwner: return "The group owner cannot be removed."
        case .invalidInvite: return "This invite is invalid or has expired."
        case .networkError(let msg): return msg
        }
    }
}
