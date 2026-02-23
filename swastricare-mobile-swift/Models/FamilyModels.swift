//
//  FamilyModels.swift
//  swastricare-mobile-swift
//
//  Family Management Models
//

import Foundation

// MARK: - Family Group

struct FamilyGroup: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerUserId: UUID
    var name: String
    var description: String?
    var allowMemberInvites: Bool
    var requireApproval: Bool
    let createdAt: Date?
    var updatedAt: Date?

    // Populated separately (not persisted)
    var memberCount: Int = 0

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

    init(
        id: UUID = UUID(),
        ownerUserId: UUID,
        name: String,
        description: String? = nil,
        allowMemberInvites: Bool = false,
        requireApproval: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        memberCount: Int = 0
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.name = name
        self.description = description
        self.allowMemberInvites = allowMemberInvites
        self.requireApproval = requireApproval
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.memberCount = memberCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerUserId = try container.decode(UUID.self, forKey: .ownerUserId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        allowMemberInvites = try container.decodeIfPresent(Bool.self, forKey: .allowMemberInvites) ?? false
        requireApproval = try container.decodeIfPresent(Bool.self, forKey: .requireApproval) ?? true
        createdAt = Self.decodeFlexibleDate(from: container, forKey: .createdAt)
        updatedAt = Self.decodeFlexibleDate(from: container, forKey: .updatedAt)
        memberCount = 0
    }

    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) { return date }
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else { return nil }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: dateString) { return date }
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) { return date }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        return dateOnly.date(from: dateString)
    }

    static func == (lhs: FamilyGroup, rhs: FamilyGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Family Member

struct FamilyMember: Codable, Identifiable, Equatable {
    let id: UUID
    let familyGroupId: UUID
    let healthProfileId: UUID
    let addedByUserId: UUID?
    var role: FamilyMemberRole
    var canView: Bool
    var canEdit: Bool
    var canAddMedications: Bool
    var canAddAppointments: Bool
    var canViewMedicalDocuments: Bool
    var canManageMembers: Bool
    var status: FamilyMemberStatus
    var relationship: String?
    let joinedAt: Date?
    let createdAt: Date?
    var updatedAt: Date?

    // Enriched from `health_profiles` (best effort)
    var memberName: String?
    var memberGender: String?
    var memberDateOfBirth: Date?

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
        case status
        case relationship
        case joinedAt = "joined_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyGroupId = try container.decode(UUID.self, forKey: .familyGroupId)
        healthProfileId = try container.decode(UUID.self, forKey: .healthProfileId)
        addedByUserId = try container.decodeIfPresent(UUID.self, forKey: .addedByUserId)

        let roleString = try container.decodeIfPresent(String.self, forKey: .role) ?? "viewer"
        role = FamilyMemberRole(rawValue: roleString) ?? .viewer

        canView = try container.decodeIfPresent(Bool.self, forKey: .canView) ?? true
        canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        canAddMedications = try container.decodeIfPresent(Bool.self, forKey: .canAddMedications) ?? false
        canAddAppointments = try container.decodeIfPresent(Bool.self, forKey: .canAddAppointments) ?? false
        canViewMedicalDocuments = try container.decodeIfPresent(Bool.self, forKey: .canViewMedicalDocuments) ?? true
        canManageMembers = try container.decodeIfPresent(Bool.self, forKey: .canManageMembers) ?? false

        let statusString = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        status = FamilyMemberStatus(rawValue: statusString) ?? .active

        relationship = try container.decodeIfPresent(String.self, forKey: .relationship)
        joinedAt = Self.decodeFlexibleDate(from: container, forKey: .joinedAt)
        createdAt = Self.decodeFlexibleDate(from: container, forKey: .createdAt)
        updatedAt = Self.decodeFlexibleDate(from: container, forKey: .updatedAt)

        memberName = nil
        memberGender = nil
        memberDateOfBirth = nil
    }

    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) { return date }
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else { return nil }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: dateString) { return date }
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) { return date }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        return dateOnly.date(from: dateString)
    }

    var displayName: String {
        if let name = memberName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let relationship = relationship?.trimmingCharacters(in: .whitespacesAndNewlines), !relationship.isEmpty {
            return relationship
        }
        return "Member"
    }
    
    var age: Int? {
        guard let dob = memberDateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }
    
    var ageString: String {
        guard let age = age else { return "" }
        return "\(age) years"
    }
    
    var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    var genderIcon: String {
        switch memberGender?.lowercased() {
        case "male": return "figure.stand"
        case "female": return "figure.stand.dress"
        default: return "person.fill"
        }
    }
    
    var roleColor: (primary: String, secondary: String) {
        switch role {
        case .owner: return ("4F46E5", "818CF8")
        case .caregiver: return ("22C55E", "86EFAC")
        case .viewer: return ("3B82F6", "93C5FD")
        case .limited: return ("6B7280", "9CA3AF")
        }
    }
    
    var permissionsSummary: String {
        var permissions: [String] = []
        if canEdit { permissions.append("Edit") }
        if canAddMedications { permissions.append("Medications") }
        if canAddAppointments { permissions.append("Appointments") }
        if canViewMedicalDocuments { permissions.append("Documents") }
        return permissions.isEmpty ? "View only" : permissions.joined(separator: ", ")
    }

    static func == (lhs: FamilyMember, rhs: FamilyMember) -> Bool {
        lhs.id == rhs.id
    }
}

enum FamilyMemberRole: String, Codable, CaseIterable {
    case owner = "owner"
    case caregiver = "caregiver"
    case viewer = "viewer"
    case limited = "limited"

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
    
    var description: String {
        switch self {
        case .owner: return "Full control over the family group"
        case .caregiver: return "Can edit health data and manage medications"
        case .viewer: return "Can view health data and documents"
        case .limited: return "Limited access to basic information"
        }
    }
}

enum FamilyMemberStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case active = "active"
    case suspended = "suspended"
    case removed = "removed"
}

// MARK: - Invites

struct FamilyInvite: Codable, Identifiable {
    let id: UUID
    let familyGroupId: UUID
    let inviteCode: String
    let invitedEmail: String?
    let invitedByUserId: UUID
    var role: FamilyMemberRole
    var status: FamilyInviteStatus
    let expiresAt: Date
    let acceptedByUserId: UUID?
    let acceptedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case inviteCode = "invite_code"
        case invitedEmail = "invited_email"
        case invitedByUserId = "invited_by_user_id"
        case role
        case status
        case expiresAt = "expires_at"
        case acceptedByUserId = "accepted_by_user_id"
        case acceptedAt = "accepted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyGroupId = try container.decode(UUID.self, forKey: .familyGroupId)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
        invitedEmail = try container.decodeIfPresent(String.self, forKey: .invitedEmail)
        invitedByUserId = try container.decode(UUID.self, forKey: .invitedByUserId)

        let roleString = try container.decodeIfPresent(String.self, forKey: .role) ?? "viewer"
        role = FamilyMemberRole(rawValue: roleString) ?? .viewer

        let statusString = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        status = FamilyInviteStatus(rawValue: statusString) ?? .pending

        expiresAt = Self.decodeFlexibleDate(from: container, forKey: .expiresAt) ?? Date().addingTimeInterval(7 * 24 * 60 * 60)
        acceptedByUserId = try container.decodeIfPresent(UUID.self, forKey: .acceptedByUserId)
        acceptedAt = Self.decodeFlexibleDate(from: container, forKey: .acceptedAt)
        createdAt = Self.decodeFlexibleDate(from: container, forKey: .createdAt)
        updatedAt = Self.decodeFlexibleDate(from: container, forKey: .updatedAt)
    }

    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) { return date }
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else { return nil }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: dateString) { return date }
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) { return date }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        return dateOnly.date(from: dateString)
    }

    var formattedExpiresAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: expiresAt, relativeTo: Date())
    }
}

enum FamilyInviteStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case expired = "expired"
    case revoked = "revoked"
}

struct FamilyInviteWithGroup: Codable, Identifiable {
    let id: UUID
    let familyGroupId: UUID
    let inviteCode: String
    let invitedEmail: String?
    let invitedByUserId: UUID
    let role: String?
    let status: String?
    let expiresAt: Date?
    let acceptedByUserId: UUID?
    let acceptedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    // Populated separately
    var familyGroup: FamilyGroupBasic?

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case inviteCode = "invite_code"
        case invitedEmail = "invited_email"
        case invitedByUserId = "invited_by_user_id"
        case role
        case status
        case expiresAt = "expires_at"
        case acceptedByUserId = "accepted_by_user_id"
        case acceptedAt = "accepted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FamilyGroupBasic: Codable {
    let id: UUID
    let name: String
    let description: String?
    let ownerUserId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ownerUserId = "owner_user_id"
    }
}

struct HealthProfileBasic: Codable {
    let id: UUID
    let userId: UUID
    let fullName: String
    let gender: String?
    let dateOfBirth: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case fullName = "full_name"
        case gender
        case dateOfBirth = "date_of_birth"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        fullName = (try? container.decodeIfPresent(String.self, forKey: .fullName)) ?? "Unknown"
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        dateOfBirth = Self.decodeFlexibleDate(from: container, forKey: .dateOfBirth)
    }

    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) { return date }
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else { return nil }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: dateString) { return date }
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) { return date }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        return dateOnly.date(from: dateString)
    }
}

