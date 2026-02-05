//
//  FamilySharingModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Family sharing and group management data structures
//

import Foundation
import SwiftUI

// MARK: - Family Role

enum FamilyRole: String, Codable, CaseIterable, Identifiable {
    case owner = "owner"
    case caregiver = "caregiver"
    case viewer = "viewer"
    case limited = "limited"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .caregiver: return "Caregiver"
        case .viewer: return "Viewer"
        case .limited: return "Limited"
        }
    }

    var description: String {
        switch self {
        case .owner: return "Full access. Can manage members and all data."
        case .caregiver: return "Can view and edit health data, manage medications."
        case .viewer: return "Can view health data and documents."
        case .limited: return "Restricted view of selected data only."
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .caregiver: return "heart.circle.fill"
        case .viewer: return "eye.fill"
        case .limited: return "eye.slash.fill"
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

// MARK: - Family Member Status

enum FamilyMemberStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "pending"
    case active = "active"
    case suspended = "suspended"
    case removed = "removed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .active: return "Active"
        case .suspended: return "Suspended"
        case .removed: return "Removed"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .active: return "checkmark.circle.fill"
        case .suspended: return "pause.circle.fill"
        case .removed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .yellow
        case .active: return .green
        case .suspended: return .orange
        case .removed: return .red
        }
    }
}

// MARK: - Relationship Type

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case spouse = "spouse"
    case parent = "parent"
    case child = "child"
    case sibling = "sibling"
    case grandparent = "grandparent"
    case grandchild = "grandchild"
    case guardian = "guardian"
    case caretaker = "caretaker"
    case friend = "friend"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spouse: return "Spouse / Partner"
        case .parent: return "Parent"
        case .child: return "Child"
        case .sibling: return "Sibling"
        case .grandparent: return "Grandparent"
        case .grandchild: return "Grandchild"
        case .guardian: return "Guardian"
        case .caretaker: return "Caretaker"
        case .friend: return "Friend"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .spouse: return "heart.fill"
        case .parent: return "figure.and.child.holdinghands"
        case .child: return "figure.child"
        case .sibling: return "person.2.fill"
        case .grandparent: return "figure.walk"
        case .grandchild: return "figure.child"
        case .guardian: return "shield.fill"
        case .caretaker: return "hands.and.sparkles.fill"
        case .friend: return "person.crop.circle.badge.checkmark"
        case .other: return "person.crop.circle"
        }
    }
}

// MARK: - Member Permissions

struct MemberPermissions: Codable, Equatable {
    var canView: Bool
    var canEdit: Bool
    var canAddMedications: Bool
    var canAddAppointments: Bool
    var canViewMedicalDocuments: Bool
    var canManageMembers: Bool

    init(
        canView: Bool = true,
        canEdit: Bool = false,
        canAddMedications: Bool = false,
        canAddAppointments: Bool = false,
        canViewMedicalDocuments: Bool = true,
        canManageMembers: Bool = false
    ) {
        self.canView = canView
        self.canEdit = canEdit
        self.canAddMedications = canAddMedications
        self.canAddAppointments = canAddAppointments
        self.canViewMedicalDocuments = canViewMedicalDocuments
        self.canManageMembers = canManageMembers
    }

    enum CodingKeys: String, CodingKey {
        case canView = "can_view"
        case canEdit = "can_edit"
        case canAddMedications = "can_add_medications"
        case canAddAppointments = "can_add_appointments"
        case canViewMedicalDocuments = "can_view_medical_documents"
        case canManageMembers = "can_manage_members"
    }

    /// Default permissions for a given role
    static func defaults(for role: FamilyRole) -> MemberPermissions {
        switch role {
        case .owner:
            return MemberPermissions(
                canView: true, canEdit: true,
                canAddMedications: true, canAddAppointments: true,
                canViewMedicalDocuments: true, canManageMembers: true
            )
        case .caregiver:
            return MemberPermissions(
                canView: true, canEdit: true,
                canAddMedications: true, canAddAppointments: true,
                canViewMedicalDocuments: true, canManageMembers: false
            )
        case .viewer:
            return MemberPermissions(
                canView: true, canEdit: false,
                canAddMedications: false, canAddAppointments: false,
                canViewMedicalDocuments: true, canManageMembers: false
            )
        case .limited:
            return MemberPermissions(
                canView: true, canEdit: false,
                canAddMedications: false, canAddAppointments: false,
                canViewMedicalDocuments: false, canManageMembers: false
            )
        }
    }
}

// MARK: - Family Group

struct FamilyGroup: Identifiable, Codable, Equatable {
    let id: UUID
    let ownerUserId: UUID
    var name: String
    var description: String?
    var allowMemberInvites: Bool
    var requireApproval: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerUserId: UUID,
        name: String = "My Family",
        description: String? = nil,
        allowMemberInvites: Bool = false,
        requireApproval: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.name = name
        self.description = description
        self.allowMemberInvites = allowMemberInvites
        self.requireApproval = requireApproval
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case name
        case description
        case allowMemberInvites = "allow_member_invites"
        case requireApproval = "require_approval"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Family Member

struct FamilyMember: Identifiable, Codable, Equatable {
    let id: UUID
    let familyGroupId: UUID
    let healthProfileId: UUID
    let addedByUserId: UUID?
    var role: FamilyRole
    var permissions: MemberPermissions
    var status: FamilyMemberStatus
    var relationship: String?
    let joinedAt: Date
    let createdAt: Date
    var updatedAt: Date

    // Joined data (populated from queries)
    var profileName: String?
    var profileAvatarURL: String?
    var profileDateOfBirth: Date?
    var profileGender: String?

    init(
        id: UUID = UUID(),
        familyGroupId: UUID,
        healthProfileId: UUID,
        addedByUserId: UUID? = nil,
        role: FamilyRole = .viewer,
        permissions: MemberPermissions = MemberPermissions(),
        status: FamilyMemberStatus = .pending,
        relationship: String? = nil,
        joinedAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        profileName: String? = nil,
        profileAvatarURL: String? = nil,
        profileDateOfBirth: Date? = nil,
        profileGender: String? = nil
    ) {
        self.id = id
        self.familyGroupId = familyGroupId
        self.healthProfileId = healthProfileId
        self.addedByUserId = addedByUserId
        self.role = role
        self.permissions = permissions
        self.status = status
        self.relationship = relationship
        self.joinedAt = joinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.profileName = profileName
        self.profileAvatarURL = profileAvatarURL
        self.profileDateOfBirth = profileDateOfBirth
        self.profileGender = profileGender
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case healthProfileId = "health_profile_id"
        case addedByUserId = "added_by_user_id"
        case role
        case status
        case relationship
        case joinedAt = "joined_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // Flattened permissions (matches DB columns)
        case canView = "can_view"
        case canEdit = "can_edit"
        case canAddMedications = "can_add_medications"
        case canAddAppointments = "can_add_appointments"
        case canViewMedicalDocuments = "can_view_medical_documents"
        case canManageMembers = "can_manage_members"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyGroupId = try container.decode(UUID.self, forKey: .familyGroupId)
        healthProfileId = try container.decode(UUID.self, forKey: .healthProfileId)
        addedByUserId = try container.decodeIfPresent(UUID.self, forKey: .addedByUserId)
        role = try container.decode(FamilyRole.self, forKey: .role)
        status = try container.decode(FamilyMemberStatus.self, forKey: .status)
        relationship = try container.decodeIfPresent(String.self, forKey: .relationship)
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        // Decode flattened permissions
        permissions = MemberPermissions(
            canView: try container.decodeIfPresent(Bool.self, forKey: .canView) ?? true,
            canEdit: try container.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false,
            canAddMedications: try container.decodeIfPresent(Bool.self, forKey: .canAddMedications) ?? false,
            canAddAppointments: try container.decodeIfPresent(Bool.self, forKey: .canAddAppointments) ?? false,
            canViewMedicalDocuments: try container.decodeIfPresent(Bool.self, forKey: .canViewMedicalDocuments) ?? true,
            canManageMembers: try container.decodeIfPresent(Bool.self, forKey: .canManageMembers) ?? false
        )

        // Joined profile data not in DB columns — set nil
        profileName = nil
        profileAvatarURL = nil
        profileDateOfBirth = nil
        profileGender = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(familyGroupId, forKey: .familyGroupId)
        try container.encode(healthProfileId, forKey: .healthProfileId)
        try container.encodeIfPresent(addedByUserId, forKey: .addedByUserId)
        try container.encode(role, forKey: .role)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(relationship, forKey: .relationship)
        try container.encode(joinedAt, forKey: .joinedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Flatten permissions
        try container.encode(permissions.canView, forKey: .canView)
        try container.encode(permissions.canEdit, forKey: .canEdit)
        try container.encode(permissions.canAddMedications, forKey: .canAddMedications)
        try container.encode(permissions.canAddAppointments, forKey: .canAddAppointments)
        try container.encode(permissions.canViewMedicalDocuments, forKey: .canViewMedicalDocuments)
        try container.encode(permissions.canManageMembers, forKey: .canManageMembers)
    }

    /// Display name with fallback
    var displayName: String {
        profileName ?? "Family Member"
    }

    /// Age computed from date of birth
    var age: Int? {
        guard let dob = profileDateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    /// Relationship type enum if parseable
    var relationshipType: RelationshipType? {
        guard let relationship else { return nil }
        return RelationshipType(rawValue: relationship)
    }
}

// MARK: - Emergency Contact

struct EmergencyContact: Identifiable, Codable, Equatable {
    let id: UUID
    let healthProfileId: UUID
    var name: String
    var relationship: String
    var phonePrimary: String
    var phoneSecondary: String?
    var email: String?
    var address: String?
    var city: String?
    var priority: Int
    var canMakeMedicalDecisions: Bool
    var hasMedicalPowerOfAttorney: Bool
    var bestTimeToCall: String?
    var languages: [String]?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        healthProfileId: UUID,
        name: String,
        relationship: String,
        phonePrimary: String,
        phoneSecondary: String? = nil,
        email: String? = nil,
        address: String? = nil,
        city: String? = nil,
        priority: Int = 1,
        canMakeMedicalDecisions: Bool = false,
        hasMedicalPowerOfAttorney: Bool = false,
        bestTimeToCall: String? = nil,
        languages: [String]? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.healthProfileId = healthProfileId
        self.name = name
        self.relationship = relationship
        self.phonePrimary = phonePrimary
        self.phoneSecondary = phoneSecondary
        self.email = email
        self.address = address
        self.city = city
        self.priority = priority
        self.canMakeMedicalDecisions = canMakeMedicalDecisions
        self.hasMedicalPowerOfAttorney = hasMedicalPowerOfAttorney
        self.bestTimeToCall = bestTimeToCall
        self.languages = languages
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case name
        case relationship
        case phonePrimary = "phone_primary"
        case phoneSecondary = "phone_secondary"
        case email
        case address
        case city
        case priority
        case canMakeMedicalDecisions = "can_make_medical_decisions"
        case hasMedicalPowerOfAttorney = "has_medical_power_of_attorney"
        case bestTimeToCall = "best_time_to_call"
        case languages
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Formatted phone for display
    var formattedPhone: String {
        phonePrimary
    }

    /// Relationship type enum if parseable
    var relationshipType: RelationshipType? {
        RelationshipType(rawValue: relationship)
    }

    /// Priority label
    var priorityLabel: String {
        switch priority {
        case 1: return "Primary"
        case 2: return "Secondary"
        default: return "Contact #\(priority)"
        }
    }
}

// MARK: - Family Group with Members

struct FamilyGroupWithMembers: Identifiable, Equatable {
    let group: FamilyGroup
    let members: [FamilyMember]

    var id: UUID { group.id }
    var name: String { group.name }

    var activeMembers: [FamilyMember] {
        members.filter { $0.status == .active }
    }

    var pendingMembers: [FamilyMember] {
        members.filter { $0.status == .pending }
    }

    var memberCount: Int {
        activeMembers.count
    }
}

// MARK: - Invite

struct FamilyInvite: Identifiable, Equatable {
    let id: UUID
    let familyGroupId: UUID
    let groupName: String
    let invitedByName: String?
    let role: FamilyRole
    let relationship: String?
    let createdAt: Date

    var isExpired: Bool {
        // Invites expire after 7 days
        let expiryDate = createdAt.addingTimeInterval(7 * 24 * 3600)
        return Date() > expiryDate
    }

    var expiresIn: String {
        let expiryDate = createdAt.addingTimeInterval(7 * 24 * 3600)
        let remaining = expiryDate.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }
        let days = Int(remaining / 86400)
        if days > 0 { return "\(days)d remaining" }
        let hours = Int(remaining / 3600)
        return "\(hours)h remaining"
    }
}

// MARK: - Family Data State

enum FamilyDataState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Member Health Summary

struct MemberHealthSummary: Identifiable, Equatable {
    let memberId: UUID
    let profileName: String
    let avatarURL: String?
    let relationship: String?
    var stepsToday: Int?
    var heartRate: Int?
    var medicationAdherence: Double?
    var hydrationProgress: Double?
    var lastUpdated: Date?

    var id: UUID { memberId }

    var adherencePercentageText: String? {
        guard let adherence = medicationAdherence else { return nil }
        return String(format: "%.0f%%", adherence * 100)
    }

    var hydrationPercentageText: String? {
        guard let progress = hydrationProgress else { return nil }
        return String(format: "%.0f%%", progress * 100)
    }
}
