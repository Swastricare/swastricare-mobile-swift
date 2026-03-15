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

    // Joined from health_profiles
    var fullName: String?
    var avatarUrl: String?

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
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
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
