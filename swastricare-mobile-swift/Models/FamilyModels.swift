//
//  FamilyModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//

import Foundation
import SwiftUI

// MARK: - Family Group

struct FamilyGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let ownerUserId: UUID
    var inviteCode: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerUserId = "owner_user_id"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Family Member

struct FamilyMember: Codable, Identifiable, Equatable {
    let id: UUID
    let familyGroupId: UUID
    let healthProfileId: UUID
    let addedByUserId: UUID?
    var role: FamilyRole
    var canView: Bool
    var canEdit: Bool
    var canAddMedications: Bool
    var canAddAppointments: Bool
    var canViewMedicalDocuments: Bool
    var canManageMembers: Bool
    var status: MemberStatus
    var relationship: String?
    let joinedAt: Date?
    let createdAt: Date?

    // Joined from health_profiles (PostgREST embed returns these inside a nested
    // "health_profiles" object on each row — NOT at the top level).
    var fullName: String?
    var avatarUrl: String?
    var userId: UUID?

    private struct HealthProfileEmbed: Decodable {
        let full_name: String?
        let avatar_url: String?
        let user_id: UUID?
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case healthProfileId = "health_profile_id"
        case addedByUserId = "added_by_user_id"
        case role
        case canView = "can_view"
        case canEdit = "can_edit"
        case canAddMedications = "can_add_medications"
        case canAddAppointments = "can_add_appointments"
        case canViewMedicalDocuments = "can_view_medical_documents"
        case canManageMembers = "can_manage_members"
        case status, relationship
        case joinedAt = "joined_at"
        case createdAt = "created_at"
        // Top-level fallbacks (in case a future query SELECTs them directly):
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case userId = "user_id"
        // Embedded nested object from `.select("*, health_profiles(...)")`:
        case healthProfiles = "health_profiles"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyGroupId = try c.decode(UUID.self, forKey: .familyGroupId)
        healthProfileId = try c.decode(UUID.self, forKey: .healthProfileId)
        addedByUserId = try c.decodeIfPresent(UUID.self, forKey: .addedByUserId)
        role = try c.decode(FamilyRole.self, forKey: .role)
        canView = try c.decodeIfPresent(Bool.self, forKey: .canView) ?? true
        canEdit = try c.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        canAddMedications = try c.decodeIfPresent(Bool.self, forKey: .canAddMedications) ?? false
        canAddAppointments = try c.decodeIfPresent(Bool.self, forKey: .canAddAppointments) ?? false
        canViewMedicalDocuments = try c.decodeIfPresent(Bool.self, forKey: .canViewMedicalDocuments) ?? true
        canManageMembers = try c.decodeIfPresent(Bool.self, forKey: .canManageMembers) ?? false
        status = try c.decode(MemberStatus.self, forKey: .status)
        relationship = try c.decodeIfPresent(String.self, forKey: .relationship)
        joinedAt = try c.decodeIfPresent(Date.self, forKey: .joinedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        // Prefer nested health_profiles embed; fall back to top-level fields.
        let embed = try? c.decodeIfPresent(HealthProfileEmbed.self, forKey: .healthProfiles)
        fullName = embed?.full_name ?? (try? c.decodeIfPresent(String.self, forKey: .fullName))
        avatarUrl = embed?.avatar_url ?? (try? c.decodeIfPresent(String.self, forKey: .avatarUrl))
        userId = embed?.user_id ?? (try? c.decodeIfPresent(UUID.self, forKey: .userId))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyGroupId, forKey: .familyGroupId)
        try c.encode(healthProfileId, forKey: .healthProfileId)
        try c.encodeIfPresent(addedByUserId, forKey: .addedByUserId)
        try c.encode(role, forKey: .role)
        try c.encode(canView, forKey: .canView)
        try c.encode(canEdit, forKey: .canEdit)
        try c.encode(canAddMedications, forKey: .canAddMedications)
        try c.encode(canAddAppointments, forKey: .canAddAppointments)
        try c.encode(canViewMedicalDocuments, forKey: .canViewMedicalDocuments)
        try c.encode(canManageMembers, forKey: .canManageMembers)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(relationship, forKey: .relationship)
        try c.encodeIfPresent(joinedAt, forKey: .joinedAt)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(fullName, forKey: .fullName)
        try c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try c.encodeIfPresent(userId, forKey: .userId)
    }
}

// MARK: - Family Role

enum FamilyRole: String, Codable, CaseIterable {
    case owner
    case caregiver
    case viewer
    case limited

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .caregiver: return "Caregiver"
        case .viewer: return "Viewer"
        case .limited: return "Limited"
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .caregiver: return "heart.circle.fill"
        case .viewer: return "eye.fill"
        case .limited: return "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .owner: return .orange
        case .caregiver: return .blue
        case .viewer: return .green
        case .limited: return .gray
        }
    }
}

// MARK: - Member Status

enum MemberStatus: String, Codable {
    case pending
    case active
    case suspended
    case removed
}

// MARK: - Family Group Insert Record (for encoding inserts)

struct FamilyGroupInsert: Encodable {
    let ownerUserId: String
    let name: String
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case ownerUserId = "owner_user_id"
        case name
        case inviteCode = "invite_code"
    }
}

// MARK: - Family Member Insert Record (for encoding inserts)

struct FamilyMemberInsert: Encodable {
    let familyGroupId: String
    let healthProfileId: String
    let addedByUserId: String
    let role: String
    let status: String
    let canView: Bool
    let canEdit: Bool
    let canAddMedications: Bool
    let canAddAppointments: Bool
    let canViewMedicalDocuments: Bool
    let canManageMembers: Bool

    enum CodingKeys: String, CodingKey {
        case familyGroupId = "family_group_id"
        case healthProfileId = "health_profile_id"
        case addedByUserId = "added_by_user_id"
        case role, status
        case canView = "can_view"
        case canEdit = "can_edit"
        case canAddMedications = "can_add_medications"
        case canAddAppointments = "can_add_appointments"
        case canViewMedicalDocuments = "can_view_medical_documents"
        case canManageMembers = "can_manage_members"
    }
}
