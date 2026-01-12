//
//  ComprehensiveOnboardingModels.swift
//  swastricare-mobile-swift
//
//  Comprehensive Onboarding Models - All 24 Questions
//

import Foundation
import Combine
import CoreLocation

// MARK: - Onboarding Form State

@MainActor
class ComprehensiveOnboardingFormState: ObservableObject {
    // A) Profile Setup
    @Published var fullName: String = ""
    @Published var gender: Gender?
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var locationType: LocationType?
    @Published var city: String = ""
    @Published var location: CLLocationCoordinate2D?
    
    // B) Body Metrics
    @Published var heightUnit: MeasurementUnit = .metric
    @Published var heightCm: Double = 170
    @Published var heightFeet: Int = 5
    @Published var heightInches: Int = 7
    @Published var weightUnit: MeasurementUnit = .metric
    @Published var weightKg: Double = 70
    @Published var weightLbs: Double = 154
    @Published var bodyGoal: BodyGoal?
    
    // C) Goals
    @Published var primaryGoal: PrimaryGoal?
    @Published var trackingPreferences: Set<TrackingPreference> = []
    
    // D) Lifestyle
    @Published var activityLevel: OnboardingActivityLevel?
    @Published var sleepDuration: SleepDuration?
    @Published var dietType: DietType?
    @Published var waterIntake: WaterIntake?
    
    // E) Health
    @Published var existingConditions: Set<HealthCondition> = []
    @Published var hasRegularMedication: Bool?
    @Published var medications: [MedicationDetail] = []
    @Published var allergies: Set<AllergyType> = []
    
    // F) Family History
    @Published var familyHistory: Set<FamilyHistoryCondition> = []
    
    // G) Habits
    @Published var smoking: SmokingHabit?
    @Published var alcohol: AlcoholHabit?
    
    // H) Emergency
    @Published var emergencyContactName: String = ""
    @Published var emergencyContactPhone: String = ""
    @Published var bloodGroup: BloodGroup?
    @Published var medicalAlerts: Set<MedicalAlert> = []
    
    // I) Permissions
    @Published var notificationsEnabled: Bool = false
    @Published var healthDataSyncEnabled: Bool = false
    
    // Validation
    var canProceedFromProfileSetup: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty && 
        gender != nil && 
        (locationType != nil || locationType == .current)
    }
    
    var canProceedFromBodyMetrics: Bool {
        true // All optional except height/weight which have defaults
    }
    
    var canProceedFromGoals: Bool {
        primaryGoal != nil
    }
    
    var canProceedFromLifestyle: Bool {
        activityLevel != nil && sleepDuration != nil && dietType != nil && waterIntake != nil
    }
    
    var canProceedFromHealth: Bool {
        hasRegularMedication != nil
    }
    
    var canProceedFromMedication: Bool {
        medications.isEmpty || medications.allSatisfy { !$0.name.isEmpty && !$0.dosage.isEmpty }
    }
    
    var canProceedFromEmergency: Bool {
        !emergencyContactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !emergencyContactPhone.trimmingCharacters(in: .whitespaces).isEmpty &&
        emergencyContactPhone.count >= 10
    }
    
    // Convert to HealthProfile
    func toHealthProfile(userId: UUID) -> HealthProfile {
        let heightInCm = heightUnit == .metric ? heightCm : Double(heightFeet * 12 + heightInches) * 2.54
        let weightInKg = weightUnit == .metric ? weightKg : weightLbs * 0.453592
        
        return HealthProfile(
            userId: userId,
            fullName: fullName,
            gender: gender ?? .preferNotToSay,
            dateOfBirth: dateOfBirth,
            heightCm: heightInCm,
            weightKg: weightInKg,
            bloodType: bloodGroup?.rawValue
        )
    }
    
    // Convert to JSON for database
    func toOnboardingJSON() -> [String: Any] {
        let heightInCm = heightUnit == .metric ? heightCm : Double(heightFeet * 12 + heightInches) * 2.54
        let weightInKg = weightUnit == .metric ? weightKg : weightLbs * 0.453592
        
        var json: [String: Any] = [:]
        
        // Profile Setup
        json["full_name"] = fullName
        json["gender"] = gender?.rawValue
        json["date_of_birth"] = ISO8601DateFormatter().string(from: dateOfBirth)
        json["location_type"] = locationType?.rawValue
        json["city"] = city.isEmpty ? nil : city
        if let location = location {
            json["latitude"] = location.latitude
            json["longitude"] = location.longitude
        }
        
        // Body Metrics
        json["height_cm"] = heightInCm
        json["weight_kg"] = weightInKg
        json["body_goal"] = bodyGoal?.rawValue
        
        // Goals
        json["primary_goal"] = primaryGoal?.rawValue
        json["tracking_preferences"] = trackingPreferences.map { $0.rawValue }
        
        // Lifestyle
        json["activity_level"] = activityLevel?.rawValue
        json["sleep_duration"] = sleepDuration?.rawValue
        json["diet_type"] = dietType?.rawValue
        json["water_intake"] = waterIntake?.rawValue
        
        // Health
        json["existing_conditions"] = existingConditions.map { $0.rawValue }
        json["has_regular_medication"] = hasRegularMedication
        json["medications"] = medications.map { [
            "name": $0.name,
            "dosage": $0.dosage,
            "schedule": $0.schedule.rawValue
        ]}
        json["allergies"] = allergies.map { $0.rawValue }
        
        // Family History
        json["family_history"] = familyHistory.map { $0.rawValue }
        
        // Habits
        json["smoking"] = smoking?.rawValue
        json["alcohol"] = alcohol?.rawValue
        
        // Emergency
        json["emergency_contact_name"] = emergencyContactName
        json["emergency_contact_phone"] = emergencyContactPhone
        json["blood_group"] = bloodGroup?.rawValue
        json["medical_alerts"] = medicalAlerts.map { $0.rawValue }
        
        // Permissions
        json["notifications_enabled"] = notificationsEnabled
        json["health_data_sync_enabled"] = healthDataSyncEnabled
        
        return json
    }
}

// MARK: - Enums

enum LocationType: String, Codable, CaseIterable {
    case current = "current"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .current: return "Use current location"
        case .manual: return "Enter city manually"
        }
    }
}

enum MeasurementUnit: String, Codable, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"
}

enum BodyGoal: String, Codable, CaseIterable {
    case lose = "lose"
    case gain = "gain"
    case maintain = "maintain"
    case notSure = "not_sure"
    
    var displayName: String {
        switch self {
        case .lose: return "Lose weight"
        case .gain: return "Gain weight"
        case .maintain: return "Maintain weight"
        case .notSure: return "Not sure"
        }
    }
}

enum PrimaryGoal: String, Codable, CaseIterable {
    case trackHealth = "track_health"
    case controlSugar = "control_sugar"
    case controlBP = "control_bp"
    case improveHeartHealth = "improve_heart_health"
    case improveSleep = "improve_sleep"
    case reduceStress = "reduce_stress"
    case fitnessTracking = "fitness_tracking"
    case pregnancyCare = "pregnancy_care"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .trackHealth: return "Track health"
        case .controlSugar: return "Control sugar"
        case .controlBP: return "Control BP"
        case .improveHeartHealth: return "Improve heart health"
        case .improveSleep: return "Improve sleep"
        case .reduceStress: return "Reduce stress"
        case .fitnessTracking: return "Fitness tracking"
        case .pregnancyCare: return "Pregnancy care"
        case .other: return "Other"
        }
    }
}

enum TrackingPreference: String, Codable, CaseIterable, Hashable {
    case bp = "bp"
    case sugar = "sugar"
    case heartRate = "heart_rate"
    case spo2 = "spo2"
    case weightBMI = "weight_bmi"
    case sleep = "sleep"
    case steps = "steps"
    case temperature = "temperature"
    
    var displayName: String {
        switch self {
        case .bp: return "BP"
        case .sugar: return "Sugar"
        case .heartRate: return "Heart rate"
        case .spo2: return "SpO2"
        case .weightBMI: return "Weight & BMI"
        case .sleep: return "Sleep"
        case .steps: return "Steps"
        case .temperature: return "Temperature"
        }
    }
}

enum OnboardingActivityLevel: String, Codable, CaseIterable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case veryActive = "very_active"
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .veryActive: return "Very active"
        }
    }
}

enum SleepDuration: String, Codable, CaseIterable {
    case lessThan5 = "<5"
    case fiveToSix = "5-6"
    case sevenToEight = "7-8"
    case eightPlus = "8+"
    
    var displayName: String {
        switch self {
        case .lessThan5: return "<5 hours"
        case .fiveToSix: return "5-6 hours"
        case .sevenToEight: return "7-8 hours"
        case .eightPlus: return "8+ hours"
        }
    }
}

enum DietType: String, Codable, CaseIterable {
    case mostlyHealthy = "mostly_healthy"
    case balanced = "balanced"
    case mostlyOutside = "mostly_outside"
    case highSugar = "high_sugar"
    
    var displayName: String {
        switch self {
        case .mostlyHealthy: return "Mostly healthy"
        case .balanced: return "Balanced"
        case .mostlyOutside: return "Mostly outside"
        case .highSugar: return "High sugar"
        }
    }
}

enum WaterIntake: String, Codable, CaseIterable {
    case lessThan1L = "<1L"
    case oneToTwoL = "1-2L"
    case twoToThreeL = "2-3L"
    case threeLPlus = "3L+"
    
    var displayName: String {
        switch self {
        case .lessThan1L: return "<1L"
        case .oneToTwoL: return "1-2L"
        case .twoToThreeL: return "2-3L"
        case .threeLPlus: return "3L+"
        }
    }
}

enum HealthCondition: String, Codable, CaseIterable, Hashable {
    case diabetes = "diabetes"
    case bp = "bp"
    case thyroid = "thyroid"
    case heartDisease = "heart_disease"
    case asthma = "asthma"
    case pcos = "pcos"
    case kidney = "kidney"
    case liver = "liver"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .diabetes: return "Diabetes"
        case .bp: return "BP"
        case .thyroid: return "Thyroid"
        case .heartDisease: return "Heart disease"
        case .asthma: return "Asthma"
        case .pcos: return "PCOS"
        case .kidney: return "Kidney"
        case .liver: return "Liver"
        case .none: return "None"
        }
    }
}

struct MedicationDetail: Codable, Identifiable {
    let id = UUID()
    var name: String
    var dosage: String
    var schedule: OnboardingMedicationSchedule
    
    enum CodingKeys: String, CodingKey {
        case name, dosage, schedule
    }
}

enum OnboardingMedicationSchedule: String, Codable, CaseIterable {
    case daily = "daily"
    case twiceDaily = "twice_daily"
    case weekly = "weekly"
    case asNeeded = "as_needed"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .twiceDaily: return "Twice daily"
        case .weekly: return "Weekly"
        case .asNeeded: return "As needed"
        }
    }
}

enum AllergyType: String, Codable, CaseIterable, Hashable {
    case food = "food"
    case medication = "medication"
    case dust = "dust"
    case skin = "skin"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .food: return "Food"
        case .medication: return "Medication"
        case .dust: return "Dust"
        case .skin: return "Skin"
        case .none: return "None"
        }
    }
}

enum FamilyHistoryCondition: String, Codable, CaseIterable, Hashable {
    case diabetes = "diabetes"
    case bp = "bp"
    case heartDisease = "heart_disease"
    case stroke = "stroke"
    case cancer = "cancer"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .diabetes: return "Diabetes"
        case .bp: return "BP"
        case .heartDisease: return "Heart disease"
        case .stroke: return "Stroke"
        case .cancer: return "Cancer"
        case .none: return "None"
        }
    }
}

enum SmokingHabit: String, Codable, CaseIterable {
    case no = "no"
    case occasionally = "occasionally"
    case regularly = "regularly"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .no: return "No"
        case .occasionally: return "Occasionally"
        case .regularly: return "Regularly"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum AlcoholHabit: String, Codable, CaseIterable {
    case no = "no"
    case occasionally = "occasionally"
    case regularly = "regularly"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .no: return "No"
        case .occasionally: return "Occasionally"
        case .regularly: return "Regularly"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum BloodGroup: String, Codable, CaseIterable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case oPositive = "O+"
    case oNegative = "O-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case dontKnow = "don't_know"
    
    var displayName: String {
        switch self {
        case .aPositive: return "A+"
        case .aNegative: return "A-"
        case .bPositive: return "B+"
        case .bNegative: return "B-"
        case .oPositive: return "O+"
        case .oNegative: return "O-"
        case .abPositive: return "AB+"
        case .abNegative: return "AB-"
        case .dontKnow: return "Don't know"
        }
    }
}

enum MedicalAlert: String, Codable, CaseIterable, Hashable {
    case asthma = "asthma"
    case epilepsy = "epilepsy"
    case severeAllergy = "severe_allergy"
    case heartCondition = "heart_condition"
    case diabetes = "diabetes"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .asthma: return "Asthma"
        case .epilepsy: return "Epilepsy"
        case .severeAllergy: return "Severe allergy"
        case .heartCondition: return "Heart condition"
        case .diabetes: return "Diabetes"
        case .none: return "None"
        }
    }
}
