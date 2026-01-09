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
    var name: String
    var gender: Gender
    var dateOfBirth: Date
    var height: Double
    var heightUnit: HeightUnit
    var weight: Double
    var weightUnit: WeightUnit
    var exerciseLevel: ExerciseLevel
    var foodIntakeLevel: FoodIntakeLevel
    var hasChronicConditions: Bool
    var chronicConditions: [String]
    var takesMedications: Bool
    var medications: [String]
    var allergies: [String]
    var bloodType: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case gender
        case dateOfBirth = "date_of_birth"
        case height
        case heightUnit = "height_unit"
        case weight
        case weightUnit = "weight_unit"
        case exerciseLevel = "exercise_level"
        case foodIntakeLevel = "food_intake_level"
        case hasChronicConditions = "has_chronic_conditions"
        case chronicConditions = "chronic_conditions"
        case takesMedications = "takes_medications"
        case medications
        case allergies
        case bloodType = "blood_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID? = nil,
        userId: UUID,
        name: String,
        gender: Gender,
        dateOfBirth: Date,
        height: Double,
        heightUnit: HeightUnit,
        weight: Double,
        weightUnit: WeightUnit,
        exerciseLevel: ExerciseLevel,
        foodIntakeLevel: FoodIntakeLevel,
        hasChronicConditions: Bool = false,
        chronicConditions: [String] = [],
        takesMedications: Bool = false,
        medications: [String] = [],
        allergies: [String] = [],
        bloodType: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.gender = gender
        self.dateOfBirth = dateOfBirth
        self.height = height
        self.heightUnit = heightUnit
        self.weight = weight
        self.weightUnit = weightUnit
        self.exerciseLevel = exerciseLevel
        self.foodIntakeLevel = foodIntakeLevel
        self.hasChronicConditions = hasChronicConditions
        self.chronicConditions = chronicConditions
        self.takesMedications = takesMedications
        self.medications = medications
        self.allergies = allergies
        self.bloodType = bloodType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Custom Decoding for flexible date formats
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        gender = try container.decode(Gender.self, forKey: .gender)
        height = try container.decode(Double.self, forKey: .height)
        heightUnit = try container.decode(HeightUnit.self, forKey: .heightUnit)
        weight = try container.decode(Double.self, forKey: .weight)
        weightUnit = try container.decode(WeightUnit.self, forKey: .weightUnit)
        exerciseLevel = try container.decode(ExerciseLevel.self, forKey: .exerciseLevel)
        foodIntakeLevel = try container.decode(FoodIntakeLevel.self, forKey: .foodIntakeLevel)
        hasChronicConditions = try container.decode(Bool.self, forKey: .hasChronicConditions)
        chronicConditions = try container.decode([String].self, forKey: .chronicConditions)
        takesMedications = try container.decode(Bool.self, forKey: .takesMedications)
        medications = try container.decode([String].self, forKey: .medications)
        allergies = try container.decode([String].self, forKey: .allergies)
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
        try container.encode(name, forKey: .name)
        try container.encode(gender, forKey: .gender)
        try container.encode(height, forKey: .height)
        try container.encode(heightUnit, forKey: .heightUnit)
        try container.encode(weight, forKey: .weight)
        try container.encode(weightUnit, forKey: .weightUnit)
        try container.encode(exerciseLevel, forKey: .exerciseLevel)
        try container.encode(foodIntakeLevel, forKey: .foodIntakeLevel)
        try container.encode(hasChronicConditions, forKey: .hasChronicConditions)
        try container.encode(chronicConditions, forKey: .chronicConditions)
        try container.encode(takesMedications, forKey: .takesMedications)
        try container.encode(medications, forKey: .medications)
        try container.encode(allergies, forKey: .allergies)
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

enum HeightUnit: String, Codable, CaseIterable {
    case cm = "cm"
    case feet = "feet"
    case inches = "inches"
    
    var displayName: String {
        switch self {
        case .cm: return "cm"
        case .feet: return "ft"
        case .inches: return "in"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"
    
    var displayName: String {
        switch self {
        case .kg: return "kg"
        case .lbs: return "lbs"
        }
    }
}

enum ExerciseLevel: String, Codable, CaseIterable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light Activity"
        case .moderate: return "Moderate Activity"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Little to no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise, physical job"
        }
    }
}

enum FoodIntakeLevel: String, Codable, CaseIterable {
    case veryLow = "very_low"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
    
    var description: String {
        switch self {
        case .veryLow: return "Less than 1200 calories/day"
        case .low: return "1200-1500 calories/day"
        case .moderate: return "1500-2000 calories/day"
        case .high: return "2000-2500 calories/day"
        case .veryHigh: return "More than 2500 calories/day"
        }
    }
}

// MARK: - Health Profile Form State

@MainActor
class HealthProfileFormState: ObservableObject {
    @Published var name: String = ""
    @Published var gender: Gender?
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var height: Double = 170
    @Published var heightUnit: HeightUnit = .cm
    @Published var weight: Double = 70
    @Published var weightUnit: WeightUnit = .kg
    @Published var exerciseLevel: ExerciseLevel?
    @Published var foodIntakeLevel: FoodIntakeLevel?
    @Published var hasChronicConditions: Bool = false
    @Published var chronicConditions: [String] = []
    @Published var takesMedications: Bool = false
    @Published var medications: [String] = []
    @Published var allergies: [String] = []
    @Published var bloodType: String = ""
    
    var isValid: Bool {
        !name.isEmpty &&
        gender != nil &&
        exerciseLevel != nil &&
        foodIntakeLevel != nil
    }
    
    func toHealthProfile(userId: UUID) -> HealthProfile {
        HealthProfile(
            userId: userId,
            name: name,
            gender: gender ?? .preferNotToSay,
            dateOfBirth: dateOfBirth,
            height: height,
            heightUnit: heightUnit,
            weight: weight,
            weightUnit: weightUnit,
            exerciseLevel: exerciseLevel ?? .sedentary,
            foodIntakeLevel: foodIntakeLevel ?? .moderate,
            hasChronicConditions: hasChronicConditions,
            chronicConditions: chronicConditions,
            takesMedications: takesMedications,
            medications: medications,
            allergies: allergies,
            bloodType: bloodType.isEmpty ? nil : bloodType
        )
    }
}
