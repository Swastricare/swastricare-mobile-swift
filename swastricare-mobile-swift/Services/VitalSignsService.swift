//
//  VitalSignsService.swift
//  swastricare-mobile-swift
//
//  Service for saving vital signs measurements to Supabase and HealthKit
//

import Foundation
import HealthKit
import Supabase
import PostgREST
import Auth

// MARK: - Vital Signs Service Protocol

protocol VitalSignsServiceProtocol {
    func saveHeartRate(_ reading: HeartRateReading) async throws -> SavedVitalSign
    func fetchRecentHeartRateReadings(limit: Int) async throws -> [SavedVitalSign]
    func saveToHealthKit(bpm: Int, date: Date) async throws
}

// MARK: - Vital Signs Service Implementation

final class VitalSignsService: VitalSignsServiceProtocol {
    
    static let shared = VitalSignsService()
    
    private let supabaseManager = SupabaseManager.shared
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // MARK: - Save Heart Rate to Supabase
    
    func saveHeartRate(_ reading: HeartRateReading) async throws -> SavedVitalSign {
        // Get current user's health profile ID
        guard let healthProfileId = try await getHealthProfileId() else {
            throw VitalSignsError.notAuthenticated
        }
        
        let vitalSign = VitalSignRecord(
            healthProfileId: healthProfileId,
            measuredAt: reading.timestamp,
            heartRate: reading.bpm,
            measurementContext: "at_rest",
            deviceUsed: reading.deviceUsed,
            notes: "Measured using camera-based PPG. Confidence: \(String(format: "%.0f", reading.confidence * 100))%"
        )
        
        // Insert into vital_signs table
        let saved: SavedVitalSign = try await supabaseManager.client
            .from("vital_signs")
            .insert(vitalSign)
            .select()
            .single()
            .execute()
            .value
        
        return saved
    }
    
    // MARK: - Fetch Recent Readings
    
    func fetchRecentHeartRateReadings(limit: Int = 10) async throws -> [SavedVitalSign] {
        guard let healthProfileId = try await getHealthProfileId() else {
            throw VitalSignsError.notAuthenticated
        }
        
        let readings: [SavedVitalSign] = try await supabaseManager.client
            .from("vital_signs")
            .select()
            .eq("health_profile_id", value: healthProfileId.uuidString)
            .not("heart_rate", operator: .is, value: "null")
            .order("measured_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return readings
    }
    
    // MARK: - HealthKit Integration
    
    func saveToHealthKit(bpm: Int, date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw VitalSignsError.healthKitNotAvailable
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw VitalSignsError.healthKitNotAvailable
        }
        
        // Check authorization
        let authStatus = healthStore.authorizationStatus(for: heartRateType)
        if authStatus != .sharingAuthorized {
            // Request authorization
            try await requestHeartRateWriteAuthorization()
            // After requesting, check again
            let newAuthStatus = healthStore.authorizationStatus(for: heartRateType)
            guard newAuthStatus == .sharingAuthorized else {
                throw VitalSignsError.healthKitNotAuthorized
            }
        }
        
        // Create quantity
        let quantity = HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: Double(bpm))
        
        // Create sample
        let sample = HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: date,
            end: date
        )
        
        // Save to HealthKit
        try await healthStore.save(sample)
    }
    
    // MARK: - Request HealthKit Authorization
    
    func requestHeartRateWriteAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw VitalSignsError.healthKitNotAvailable
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw VitalSignsError.healthKitNotAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: [heartRateType], read: [heartRateType])
    }
    
    // MARK: - Helpers
    
    private func getHealthProfileId() async throws -> UUID? {
        guard let userId = try? await supabaseManager.client.auth.session.user.id else {
            return nil
        }
        
        // Fetch health profile for user
        struct HealthProfile: Codable {
            let id: UUID
        }
        
        let profiles: [HealthProfile] = try await supabaseManager.client
            .from("health_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        
        return profiles.first?.id
    }
}

// MARK: - Errors

enum VitalSignsError: LocalizedError {
    case notAuthenticated
    case saveFailed
    case healthKitNotAvailable
    case healthKitNotAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to save vital signs."
        case .saveFailed:
            return "Failed to save vital sign data."
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .healthKitNotAuthorized:
            return "HealthKit authorization is required to save heart rate data."
        }
    }
}

// MARK: - Data Models

struct VitalSignRecord: Codable {
    let healthProfileId: UUID
    let measuredAt: Date
    let heartRate: Int
    let measurementContext: String
    let deviceUsed: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case healthProfileId = "health_profile_id"
        case measuredAt = "measured_at"
        case heartRate = "heart_rate"
        case measurementContext = "measurement_context"
        case deviceUsed = "device_used"
        case notes
    }
}

struct SavedVitalSign: Codable, Identifiable {
    let id: UUID
    let healthProfileId: UUID
    let measuredAt: Date
    let heartRate: Int?
    let bloodPressureSystolic: Int?
    let bloodPressureDiastolic: Int?
    let oxygenSaturation: Double?
    let temperatureCelsius: Double?
    let respiratoryRate: Int?
    let measurementContext: String?
    let deviceUsed: String?
    let notes: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthProfileId = "health_profile_id"
        case measuredAt = "measured_at"
        case heartRate = "heart_rate"
        case bloodPressureSystolic = "blood_pressure_systolic"
        case bloodPressureDiastolic = "blood_pressure_diastolic"
        case oxygenSaturation = "oxygen_saturation"
        case temperatureCelsius = "temperature_celsius"
        case respiratoryRate = "respiratory_rate"
        case measurementContext = "measurement_context"
        case deviceUsed = "device_used"
        case notes
        case createdAt = "created_at"
    }
}
