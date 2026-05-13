//
//  FamilyMemberDashboardViewModel.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — per-member dashboard ViewModel.
//  Mirrors the Android FamilyMemberDashboardViewModel: loads the target
//  member's vitals, sleep, hydration, today's medication doses, calories,
//  and vault docs in parallel, then exposes a single State struct.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class FamilyMemberDashboardViewModel: ObservableObject {

    // MARK: - State

    struct State {
        var isLoading: Bool = true
        var error: String?
        var member: FamilyMember?
        var canEdit: Bool = false

        // Vitals
        var latestHeartRateBpm: Int?
        var heartRateMeasuredAt: String?
        var sleepHours: Double?

        // Today's medications
        var doses: [MedicationDoseSummary] = []
        var adherencePercent: Int = 0

        // Today's other
        var hydrationMl: Int = 0
        var hydrationGoalMl: Int = 2500
        var caloriesToday: Int = 0

        // Vault
        var vaultDocs: [VaultDocSummary] = []
        var vaultDocCount: Int { vaultDocs.count }
    }

    @Published var state = State()

    // MARK: - Models

    /// Mirrors Android MedicationDoseSummary — used by the dose list.
    struct MedicationDoseSummary: Identifiable, Equatable {
        let id: String           // logId or synthesized "synth-<medicationId>-<scheduledAt>"
        let logId: String?
        let medicationId: String
        let medicationName: String
        let scheduledAt: String  // ISO
        let status: String       // 'taken'|'skipped'|'missed'|'late'|'early'|'pending'
    }

    // MARK: - Private

    private let supabase = SupabaseManager.shared

    // MARK: - Load

    func load(targetHealthProfileId: String) async {
        state.isLoading = true
        state.error = nil

        do {
            // 1. Ensure user is signed in.
            guard (try? await supabase.client.auth.session) != nil else {
                state.error = "Not signed in"
                state.isLoading = false
                return
            }

            // 2. Resolve the caller's family group.
            guard let group = try await supabase.fetchMyFamilyGroup() else {
                state.error = "Not in any family group"
                state.isLoading = false
                return
            }

            // 3. Fetch all members (with health_profiles embed for fullName + avatar).
            let members = try await supabase.fetchFamilyMembers(groupId: group.id)

            // 4. Identify target.
            guard let targetMember = members.first(where: {
                $0.healthProfileId.uuidString.lowercased() == targetHealthProfileId.lowercased()
            }) else {
                state.error = "Member not found in family"
                state.isLoading = false
                return
            }

            // 5. Resolve caller's member record (for role + canEdit).
            let callerMember = try? await supabase.fetchMyFamilyMember(groupId: group.id)
            let canEdit: Bool = {
                guard let role = callerMember?.role else { return false }
                return role == .owner || role == .caregiver
            }()

            // 6. Date setup (UTC for ranged queries, today for metric_date).
            let now = Date()
            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withInternetDateTime]

            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(identifier: "UTC") ?? .current
            let startOfTodayUTC = utcCal.startOfDay(for: now)
            let startOfTomorrowUTC = utcCal.date(byAdding: .day, value: 1, to: startOfTodayUTC) ?? now
            let fromIso = isoFmt.string(from: startOfTodayUTC)
            let toIso = isoFmt.string(from: startOfTomorrowUTC)

            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            dateFmt.timeZone = TimeZone(identifier: "UTC") ?? .current
            let metricDateStr = dateFmt.string(from: startOfTodayUTC)

            // 6. Parallel data fetch.
            async let hrTask = fetchLatestHeartRate(profileId: targetHealthProfileId)
            async let sleepTask = fetchSleepHours(profileId: targetHealthProfileId, metricDate: metricDateStr)
            async let hydrationTask = fetchHydrationToday(profileId: targetHealthProfileId, fromIso: fromIso, toIso: toIso)
            async let caloriesTask = fetchDietCaloriesToday(profileId: targetHealthProfileId, fromIso: fromIso, toIso: toIso)
            async let vaultTask = fetchVault(profileId: targetHealthProfileId)
            async let dosesTask = fetchDosesForToday(
                profileId: targetHealthProfileId,
                fromIso: fromIso,
                toIso: toIso,
                today: startOfTodayUTC
            )

            let hr = await hrTask
            let sleepHours = await sleepTask
            let hydrationMl = await hydrationTask
            let caloriesToday = await caloriesTask
            let vault = await vaultTask
            let doses = await dosesTask

            let adherencePercent: Int = {
                guard !doses.isEmpty else { return 0 }
                let taken = doses.filter { $0.status.lowercased() == "taken" }.count
                return Int(round(Double(taken) * 100.0 / Double(doses.count)))
            }()

            // 7. Commit.
            state = State(
                isLoading: false,
                error: nil,
                member: targetMember,
                canEdit: canEdit,
                latestHeartRateBpm: hr?.bpm,
                heartRateMeasuredAt: hr?.measuredAt,
                sleepHours: sleepHours,
                doses: doses,
                adherencePercent: adherencePercent,
                hydrationMl: hydrationMl ?? 0,
                hydrationGoalMl: 2500,
                caloriesToday: caloriesToday ?? 0,
                vaultDocs: vault
            )
        } catch {
            state.error = UserFriendlyError.message(from: error)
            state.isLoading = false
        }
    }

    // MARK: - Signed URL for vault docs

    /// Returns a temporary viewer URL for the given storage path.
    func resolveVaultDocURL(path: String) async -> URL? {
        do {
            return try await supabase.getSignedURL(storagePath: path, expiresIn: 3600)
        } catch {
            return nil
        }
    }

    // MARK: - Sub-reads

    private struct HeartRatePoint { let bpm: Int; let measuredAt: String }

    private func fetchLatestHeartRate(profileId: String) async -> HeartRatePoint? {
        struct Row: Decodable {
            let heart_rate: Double?
            let measured_at: String?
        }
        do {
            let rows: [Row] = try await supabase.client
                .from("vital_signs")
                .select("heart_rate, measured_at")
                .eq("health_profile_id", value: profileId)
                .not("heart_rate", operator: .is, value: "null")
                .order("measured_at", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first, let bpm = row.heart_rate, let at = row.measured_at else {
                return nil
            }
            return HeartRatePoint(bpm: Int(bpm.rounded()), measuredAt: at)
        } catch {
            return nil
        }
    }

    private func fetchSleepHours(profileId: String, metricDate: String) async -> Double? {
        struct Row: Decodable { let sleep_hours: Double? }
        do {
            let rows: [Row] = try await supabase.client
                .from("daily_health_metrics")
                .select("sleep_hours")
                .eq("health_profile_id", value: profileId)
                .eq("metric_date", value: metricDate)
                .limit(1)
                .execute()
                .value
            return rows.first?.sleep_hours
        } catch {
            return nil
        }
    }

    private func fetchHydrationToday(profileId: String, fromIso: String, toIso: String) async -> Int? {
        struct Row: Decodable { let amount_ml: Int? }
        do {
            let rows: [Row] = try await supabase.client
                .from("hydration_logs")
                .select("amount_ml")
                .eq("health_profile_id", value: profileId)
                .gte("consumed_at", value: fromIso)
                .lt("consumed_at", value: toIso)
                .execute()
                .value
            return rows.reduce(0) { $0 + ($1.amount_ml ?? 0) }
        } catch {
            return nil
        }
    }

    private func fetchDietCaloriesToday(profileId: String, fromIso: String, toIso: String) async -> Int? {
        struct Row: Decodable { let calories: Double? }
        do {
            let rows: [Row] = try await supabase.client
                .from("diet_logs")
                .select("calories")
                .eq("health_profile_id", value: profileId)
                .gte("logged_at", value: fromIso)
                .lt("logged_at", value: toIso)
                .execute()
                .value
            let total = rows.reduce(0.0) { $0 + ($1.calories ?? 0) }
            return Int(total.rounded())
        } catch {
            return nil
        }
    }

    private func fetchVault(profileId: String) async -> [VaultDocSummary] {
        do {
            return try await supabase.listVaultForProfile(profileId)
        } catch {
            return []
        }
    }

    // MARK: - Doses (logs ∪ synthetic from schedules)

    private struct EmbeddedMed: Decodable {
        let id: String?
        let name: String?
    }

    private struct MedicationLogRow: Decodable {
        let id: String
        let medication_id: String?
        let scheduled_time: String?
        let status: String?
        let medications: EmbeddedMed?
    }

    private struct ScheduleRow: Decodable {
        let id: String?
        let medication_id: String
        let time_of_day: String   // "HH:mm:ss"
        let schedule_type: String?
        let is_active: Bool?
    }

    private struct MedNameRow: Decodable {
        let id: String
        let name: String?
    }

    private func fetchDosesForToday(
        profileId: String,
        fromIso: String,
        toIso: String,
        today: Date
    ) async -> [MedicationDoseSummary] {
        do {
            // 1. Today's logs joined with medication name.
            let logs: [MedicationLogRow] = (try? await supabase.client
                .from("medication_logs")
                .select("id, scheduled_time, status, medication_id, medications(id, name)")
                .eq("health_profile_id", value: profileId)
                .gte("scheduled_time", value: fromIso)
                .lt("scheduled_time", value: toIso)
                .execute()
                .value) ?? []

            // 2. Active daily schedules for this profile.
            let schedules: [ScheduleRow] = (try? await supabase.client
                .from("medication_schedules")
                .select("id, medication_id, time_of_day, schedule_type, is_active")
                .eq("health_profile_id", value: profileId)
                .eq("is_active", value: true)
                .eq("schedule_type", value: "daily")
                .execute()
                .value) ?? []

            // 3. Resolve medication names for any unknown medication_ids.
            let allIds: Set<String> = Set(
                logs.compactMap { $0.medication_id } +
                schedules.map { $0.medication_id }
            )
            var medsById: [String: String] = [:]
            // Seed names from log embed first.
            for row in logs {
                if let id = row.medication_id, let n = row.medications?.name {
                    medsById[id] = n
                }
            }
            let missingIds = allIds.subtracting(medsById.keys)
            if !missingIds.isEmpty {
                if let nameRows: [MedNameRow] = try? await supabase.client
                    .from("medications")
                    .select("id, name")
                    .in("id", values: Array(missingIds))
                    .execute()
                    .value {
                    for r in nameRows {
                        if let n = r.name { medsById[r.id] = n }
                    }
                }
            }

            // 4. Map log rows.
            let logSummaries: [MedicationDoseSummary] = logs.compactMap { row in
                guard let medId = row.medication_id else { return nil }
                return MedicationDoseSummary(
                    id: row.id,
                    logId: row.id,
                    medicationId: medId,
                    medicationName: medsById[medId] ?? row.medications?.name ?? "Medication",
                    scheduledAt: row.scheduled_time ?? "",
                    status: (row.status ?? "pending").lowercased()
                )
            }

            // 5. Synthesise expected doses for each active daily schedule, skipping
            //    any that already have a matching log within ±60 minutes.
            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withInternetDateTime]

            // Local calendar for combining today's date with schedule's time_of_day.
            let localCal = Calendar.current
            let todayComponents = localCal.dateComponents([.year, .month, .day], from: today)

            var synthetic: [MedicationDoseSummary] = []
            for sched in schedules {
                // Parse "HH:mm:ss" prefix
                let hms = String(sched.time_of_day.prefix(8))
                let parts = hms.split(separator: ":")
                guard parts.count >= 2,
                      let h = Int(parts[0]),
                      let m = Int(parts[1]) else { continue }
                let s = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0

                var expectedComponents = todayComponents
                expectedComponents.hour = h
                expectedComponents.minute = m
                expectedComponents.second = s
                guard let expectedAt = localCal.date(from: expectedComponents) else { continue }

                // Match against existing logs (same med id, within ±60 min).
                let matched: MedicationLogRow? = logs.first(where: { log in
                    guard log.medication_id == sched.medication_id,
                          let ts = log.scheduled_time,
                          let parsed = isoFmt.date(from: ts) else { return false }
                    return abs(parsed.timeIntervalSince(expectedAt)) <= 60 * 60
                })

                if matched != nil { continue }

                let synthIso = isoFmt.string(from: expectedAt)
                synthetic.append(
                    MedicationDoseSummary(
                        id: "synth-\(sched.medication_id)-\(synthIso)",
                        logId: nil,
                        medicationId: sched.medication_id,
                        medicationName: medsById[sched.medication_id] ?? "Medication",
                        scheduledAt: synthIso,
                        status: "pending"
                    )
                )
            }

            let merged = (logSummaries + synthetic).sorted { $0.scheduledAt < $1.scheduledAt }
            return merged
        }
    }
}
