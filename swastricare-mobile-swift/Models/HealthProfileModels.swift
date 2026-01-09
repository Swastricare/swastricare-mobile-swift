//
//  HealthProfileModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//

import Foundation
import Combine

// MARK: - Health Profile Model

struct HealthProfile: Codable {
    let id: UUID?
    let userId: UUID
    var fullName: String
    var gender: Gender
    var dateOfBirth: Date
    var heightCm: Double
    var weightKg: Double
    var bloodType: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case fullName = "full_name"
        case gender
        case dateOfBirth = "date_of_birth"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case bloodType = "blood_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID? = nil,
        userId: UUID,
        fullName: String,
        gender: Gender,
        dateOfBirth: Date,
        heightCm: Double,
        weightKg: Double,
        bloodType: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.fullName = fullName
        self.gender = gender
        self.dateOfBirth = dateOfBirth
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bloodType = bloodType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Custom Decoding for flexible date formats
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        fullName = try container.decode(String.self, forKey: .fullName)
        gender = try container.decode(Gender.self, forKey: .gender)
        heightCm = try container.decode(Double.self, forKey: .heightCm)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        bloodType = try container.decodeIfPresent(String.self, forKey: .bloodType)
        
        // Decode dates with flexible format handling
        dateOfBirth = Self.decodeFlexibleDate(from: container, forKey: .dateOfBirth) ?? Date()
        createdAt = Self.decodeFlexibleDate(from: container, forKey: .createdAt)
        updatedAt = Self.decodeFlexibleDate(from: container, forKey: .updatedAt)
    }
    
    // MARK: - Custom Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(gender, forKey: .gender)
        try container.encode(heightCm, forKey: .heightCm)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encodeIfPresent(bloodType, forKey: .bloodType)
        
        // Encode dateOfBirth as date-only string (PostgreSQL date type)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        try container.encode(formatter.string(from: dateOfBirth), forKey: .dateOfBirth)
        
        // Encode timestamps normally
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    // MARK: - Flexible Date Decoder Helper
    
    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // Try decoding as Date first (ISO8601 full format)
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        
        // Try decoding as string and parse manually
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else {
            return nil
        }
        
        // Try ISO8601 with fractional seconds
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try date-only format (YYYY-MM-DD)
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
}

// MARK: - Enums

enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}


// MARK: - Health Profile Form State

@MainActor
class HealthProfileFormState: ObservableObject {
    @Published var name: String = ""
    @Published var gender: Gender?
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var heightCm: Double = 170
    @Published var weightKg: Double = 70
    @Published var bloodType: String = ""
    
    var isValid: Bool {
        !name.isEmpty && gender != nil
    }
    
    func toHealthProfile(userId: UUID) -> HealthProfile {
        HealthProfile(
            userId: userId,
            fullName: name,
            gender: gender ?? .preferNotToSay,
            dateOfBirth: dateOfBirth,
            heightCm: heightCm,
            weightKg: weightKg,
            bloodType: bloodType.isEmpty ? nil : bloodType
        )
    }
}
