//
//  MenstruationService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles menstrual cycle CRUD operations with Supabase menstrual_cycles table
//

import Foundation

// MARK: - Menstruation Service Protocol

protocol MenstruationServiceProtocol {
    func fetchCycles(limit: Int) async throws -> [MenstrualCycle]
    func fetchCurrentCycle() async throws -> MenstrualCycle?
    func startPeriod(date: Date, flow: FlowIntensity?) async throws -> MenstrualCycle
    func endPeriod(cycleId: UUID, endDate: Date) async throws -> MenstrualCycle
    func updateCycle(_ cycle: MenstrualCycle) async throws -> MenstrualCycle
    func deleteCycle(id: UUID) async throws
    func logDailySymptoms(cycleId: UUID, symptoms: [String], painLevel: Int?, mood: String?, energyLevel: Int?, flow: FlowIntensity?) async throws
    func calculatePrediction(from cycles: [MenstrualCycle]) -> CyclePrediction?
    func calculateInsights(from cycles: [MenstrualCycle]) -> CycleInsights?
}

// MARK: - Menstruation Service Implementation

final class MenstruationService: MenstruationServiceProtocol {

    static let shared = MenstruationService()

    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Helpers

    private func getHealthProfileId() async throws -> UUID {
        guard let userId = try? await supabase.client.auth.session.user.id else {
            throw MenstruationError.notAuthenticated
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
            throw MenstruationError.noHealthProfile
        }
        return profileId
    }

    // MARK: - Cycles

    func fetchCycles(limit: Int = 12) async throws -> [MenstrualCycle] {
        let profileId = try await getHealthProfileId()

        let cycles: [MenstrualCycle] = try await supabase.client
            .from("menstrual_cycles")
            .select()
            .eq("health_profile_id", value: profileId.uuidString)
            .order("period_start", ascending: false)
            .limit(limit)
            .execute()
            .value

        print("🩸 Fetched \(cycles.count) menstrual cycles")
        return cycles
    }

    func fetchCurrentCycle() async throws -> MenstrualCycle? {
        let profileId = try await getHealthProfileId()

        let cycles: [MenstrualCycle] = try await supabase.client
            .from("menstrual_cycles")
            .select()
            .eq("health_profile_id", value: profileId.uuidString)
            .is("period_end", value: "null")
            .order("period_start", ascending: false)
            .limit(1)
            .execute()
            .value

        return cycles.first
    }

    func startPeriod(date: Date, flow: FlowIntensity?) async throws -> MenstrualCycle {
        let profileId = try await getHealthProfileId()

        struct InsertPayload: Encodable {
            let health_profile_id: UUID
            let period_start: Date
            let flow_intensity: String?
            let symptoms: [String]
        }

        let payload = InsertPayload(
            health_profile_id: profileId,
            period_start: date,
            flow_intensity: flow?.rawValue,
            symptoms: []
        )

        let cycle: MenstrualCycle = try await supabase.client
            .from("menstrual_cycles")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        print("🩸 Started period tracking on \(date)")
        return cycle
    }

    func endPeriod(cycleId: UUID, endDate: Date) async throws -> MenstrualCycle {
        struct UpdatePayload: Encodable {
            let period_end: Date
            let period_length: Int?
        }

        // Calculate period length
        let cycles: [MenstrualCycle] = try await supabase.client
            .from("menstrual_cycles")
            .select()
            .eq("id", value: cycleId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let current = cycles.first else {
            throw MenstruationError.cycleNotFound
        }

        let periodLength = Calendar.current.dateComponents([.day], from: current.periodStart, to: endDate).day.map { $0 + 1 }

        let payload = UpdatePayload(
            period_end: endDate,
            period_length: periodLength
        )

        let updated: MenstrualCycle = try await supabase.client
            .from("menstrual_cycles")
            .update(payload)
            .eq("id", value: cycleId.uuidString)
            .select()
            .single()
            .execute()
            .value

        print("🩸 Ended period tracking, length: \(periodLength ?? 0) days")
        return updated
    }

    func updateCycle(_ cycle: MenstrualCycle) async throws -> MenstrualCycle {
        struct UpdatePayload: Encodable {
            let flow_intensity: String?
            let symptoms: [String]
            let pain_level: Int?
            let mood: String?
            let energy_level: Int?
            let notes: String?
            let ovulation_date: Date?
            let basal_body_temp: Double?
            let cervical_mucus: String?
        }

        let payload = UpdatePayload(
            flow_intensity: cycle.flowIntensity?.rawValue,
            symptoms: cycle.symptoms,
            pain_level: cycle.painLevel,
            mood: cycle.mood,
            energy_level: cycle.energyLevel,
            notes: cycle.notes,
            ovulation_date: cycle.ovulationDate,
            basal_body_temp: cycle.basalBodyTemp,
            cervical_mucus: cycle.cervicalMucus
        )

        let updated: MenstrualCycle = try await supabase.client
            .from("menstrual_cycles")
            .update(payload)
            .eq("id", value: cycle.id.uuidString)
            .select()
            .single()
            .execute()
            .value

        print("🩸 Updated cycle: \(cycle.id)")
        return updated
    }

    func deleteCycle(id: UUID) async throws {
        try await supabase.client
            .from("menstrual_cycles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        print("🩸 Deleted cycle: \(id)")
    }

    func logDailySymptoms(cycleId: UUID, symptoms: [String], painLevel: Int?, mood: String?, energyLevel: Int?, flow: FlowIntensity?) async throws {
        struct UpdatePayload: Encodable {
            let symptoms: [String]
            let pain_level: Int?
            let mood: String?
            let energy_level: Int?
            let flow_intensity: String?
        }

        let payload = UpdatePayload(
            symptoms: symptoms,
            pain_level: painLevel,
            mood: mood,
            energy_level: energyLevel,
            flow_intensity: flow?.rawValue
        )

        try await supabase.client
            .from("menstrual_cycles")
            .update(payload)
            .eq("id", value: cycleId.uuidString)
            .execute()

        print("🩸 Logged daily symptoms for cycle: \(cycleId)")
    }

    // MARK: - Predictions

    func calculatePrediction(from cycles: [MenstrualCycle]) -> CyclePrediction? {
        let completedCycles = cycles.filter { $0.periodEnd != nil }
        guard completedCycles.count >= 2 else { return nil }

        let calendar = Calendar.current
        var cycleLengths: [Int] = []
        var periodLengths: [Int] = []

        // Calculate cycle lengths (time between consecutive period starts)
        let sorted = completedCycles.sorted { $0.periodStart < $1.periodStart }
        for i in 1..<sorted.count {
            if let days = calendar.dateComponents([.day], from: sorted[i-1].periodStart, to: sorted[i].periodStart).day {
                cycleLengths.append(days)
            }
        }

        // Calculate period lengths
        for cycle in completedCycles {
            if let length = cycle.computedPeriodLength ?? cycle.periodLength {
                periodLengths.append(length)
            }
        }

        guard !cycleLengths.isEmpty else { return nil }

        let avgCycleLength = cycleLengths.reduce(0, +) / cycleLengths.count
        let avgPeriodLength = periodLengths.isEmpty ? 5 : periodLengths.reduce(0, +) / periodLengths.count

        // Use the most recent period to predict next
        guard let mostRecent = sorted.last else { return nil }

        let nextPeriodStart = calendar.date(byAdding: .day, value: avgCycleLength, to: mostRecent.periodStart) ?? Date()
        let nextOvulation = calendar.date(byAdding: .day, value: avgCycleLength - 14, to: mostRecent.periodStart)
        let fertileStart = nextOvulation.flatMap { calendar.date(byAdding: .day, value: -5, to: $0) }
        let fertileEnd = nextOvulation.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }

        // Confidence based on regularity
        let stdDev = standardDeviation(cycleLengths)
        let confidence = max(0.3, min(1.0, 1.0 - (stdDev / Double(avgCycleLength))))

        return CyclePrediction(
            nextPeriodStart: nextPeriodStart,
            nextOvulation: nextOvulation,
            fertileWindowStart: fertileStart,
            fertileWindowEnd: fertileEnd,
            averageCycleLength: avgCycleLength,
            averagePeriodLength: avgPeriodLength,
            confidence: confidence
        )
    }

    func calculateInsights(from cycles: [MenstrualCycle]) -> CycleInsights? {
        guard !cycles.isEmpty else { return nil }

        let completed = cycles.filter { $0.periodEnd != nil }
        let calendar = Calendar.current

        // Average cycle length
        let sorted = completed.sorted { $0.periodStart < $1.periodStart }
        var cycleLengths: [Int] = []
        for i in 1..<sorted.count {
            if let days = calendar.dateComponents([.day], from: sorted[i-1].periodStart, to: sorted[i].periodStart).day {
                cycleLengths.append(days)
            }
        }
        let avgCycleLength = cycleLengths.isEmpty ? 28 : cycleLengths.reduce(0, +) / cycleLengths.count

        // Average period length
        let periodLengths = completed.compactMap { $0.computedPeriodLength ?? $0.periodLength }
        let avgPeriodLength = periodLengths.isEmpty ? 5 : periodLengths.reduce(0, +) / periodLengths.count

        // Most common symptoms
        var symptomCounts: [PeriodSymptom: Int] = [:]
        for cycle in cycles {
            for symptomStr in cycle.symptoms {
                if let symptom = PeriodSymptom(rawValue: symptomStr) {
                    symptomCounts[symptom, default: 0] += 1
                }
            }
        }
        let topSymptoms = symptomCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }

        // Average pain
        let painLevels = cycles.compactMap { $0.painLevel }
        let avgPain = painLevels.isEmpty ? 0 : Double(painLevels.reduce(0, +)) / Double(painLevels.count)

        // Regularity
        let regularity: String
        if cycleLengths.isEmpty {
            regularity = "Not enough data"
        } else {
            let stdDev = standardDeviation(cycleLengths)
            if stdDev <= 2 {
                regularity = "Regular"
            } else if stdDev <= 5 {
                regularity = "Slightly Irregular"
            } else {
                regularity = "Irregular"
            }
        }

        return CycleInsights(
            averageCycleLength: avgCycleLength,
            averagePeriodLength: avgPeriodLength,
            mostCommonSymptoms: topSymptoms,
            averagePainLevel: avgPain,
            cycleRegularity: regularity,
            totalCyclesLogged: cycles.count
        )
    }

    // MARK: - Math Helpers

    private func standardDeviation(_ values: [Int]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Menstruation Error

enum MenstruationError: LocalizedError {
    case notAuthenticated
    case noHealthProfile
    case cycleNotFound
    case activeCycleExists
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to track cycles."
        case .noHealthProfile: return "No health profile found. Complete your profile first."
        case .cycleNotFound: return "Cycle not found."
        case .activeCycleExists: return "An active period is already being tracked."
        case .networkError(let msg): return msg
        }
    }
}
