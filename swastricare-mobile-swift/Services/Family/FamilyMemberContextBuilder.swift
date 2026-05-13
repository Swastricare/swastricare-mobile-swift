//
//  FamilyMemberContextBuilder.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — builds a Markdown context block for the AI chat
//  scoped to a target family member ("today's snapshot"). Mirrors the
//  Android FamilyMemberContextBuilder.build(targetHealthProfileId).
//
//  RLS bounds visibility — any failure on a sub-read is swallowed and
//  surfaced as an empty/blank entry. If the entire builder fails (no
//  access at all), the function returns "".
//

import Foundation
import Supabase

@MainActor
final class FamilyMemberContextBuilder {
    static let shared = FamilyMemberContextBuilder()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    // MARK: - Public

    /// Builds the Markdown context. Returns an empty string on error or no access.
    func build(targetHealthProfileId: String, daysBack: Int = 7) async -> String {
        do {
            // 1. Resolve the target member's display name (from health_profiles).
            let fullName = (try? await fetchFullName(profileId: targetHealthProfileId)) ?? "this family member"

            // Date setup (UTC for queries; local for the human-readable date header).
            let now = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]

            let utcCal = Calendar(identifier: .gregorian)
            var utcCalendar = utcCal
            utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .current
            let startOfTodayUTC = utcCalendar.startOfDay(for: now)
            let startOfTomorrowUTC = utcCalendar.date(byAdding: .day, value: 1, to: startOfTodayUTC) ?? now

            let startOfTodayStr = isoFormatter.string(from: startOfTodayUTC)
            let startOfTomorrowStr = isoFormatter.string(from: startOfTomorrowUTC)

            let dateHeaderFmt = DateFormatter()
            dateHeaderFmt.dateFormat = "yyyy-MM-dd"
            dateHeaderFmt.timeZone = TimeZone.current
            let todayHeader = dateHeaderFmt.string(from: now)

            let metricDateFmt = DateFormatter()
            metricDateFmt.dateFormat = "yyyy-MM-dd"
            metricDateFmt.timeZone = TimeZone(identifier: "UTC") ?? .current
            let metricDateStr = metricDateFmt.string(from: startOfTodayUTC)

            // 2. Fire-and-forget all reads in parallel; any individual failure → nil.
            async let latestHRTask = fetchLatestHeartRate(profileId: targetHealthProfileId)
            async let sleepTask = fetchSleepHours(profileId: targetHealthProfileId, metricDate: metricDateStr)
            async let hydrationTask = fetchHydrationToday(
                profileId: targetHealthProfileId,
                fromIso: startOfTodayStr,
                toIso: startOfTomorrowStr
            )
            async let dietTask = fetchDietCaloriesToday(
                profileId: targetHealthProfileId,
                fromIso: startOfTodayStr,
                toIso: startOfTomorrowStr
            )
            async let medAdhTask = fetchMedicationAdherenceToday(
                profileId: targetHealthProfileId,
                fromIso: startOfTodayStr,
                toIso: startOfTomorrowStr
            )

            let latestHR = await latestHRTask
            let sleepHours = await sleepTask
            let hydrationMl = await hydrationTask
            let dietCalories = await dietTask
            let medSummary = await medAdhTask

            // 3. Build markdown.
            var lines: [String] = []
            lines.append("# Family member context (read-only, for AI reasoning)")
            lines.append("This conversation is about \(fullName).")
            lines.append("Today's date: \(todayHeader)")
            lines.append("")
            lines.append("## Today's snapshot")

            if let hr = latestHR {
                lines.append("- Latest heart rate: \(hr.bpm) bpm (measured \(hr.measuredAt))")
            } else {
                lines.append("- Latest heart rate: not available")
            }

            if let sleep = sleepHours {
                lines.append("- Sleep last night: \(formatHours(sleep)) hours")
            } else {
                lines.append("- Sleep last night: not available")
            }

            if let ml = hydrationMl {
                lines.append("- Hydration today: \(ml) ml")
            } else {
                lines.append("- Hydration today: not available")
            }

            if let kcal = dietCalories {
                lines.append("- Calories today: \(kcal) kcal")
            } else {
                lines.append("- Calories today: not available")
            }

            if let med = medSummary {
                let pct = med.total == 0 ? 0 : Int(round(Double(med.taken) * 100.0 / Double(med.total)))
                lines.append("- Medication adherence today: \(med.taken)/\(med.total) taken (\(pct)%)")
                if !med.missedNames.isEmpty {
                    lines.append("- Missed today: \(med.missedNames.joined(separator: ", "))")
                }
            } else {
                lines.append("- Medication adherence today: not available")
            }

            lines.append("")
            lines.append("## Notes")
            lines.append("- Caller is asking about this family member as a caregiver/family.")
            lines.append("- Be respectful, non-alarmist; suggest seeking professional medical advice for anything serious.")
            lines.append("- Don't expose specific log IDs, internal status codes, or raw data the caller didn't ask about.")

            _ = daysBack // reserved for future weekly trend rollups

            return lines.joined(separator: "\n")
        } catch {
            return ""
        }
    }

    // MARK: - Sub-reads (each returns nil on failure)

    private func fetchFullName(profileId: String) async throws -> String? {
        struct Row: Decodable { let full_name: String? }
        let rows: [Row] = try await client
            .from("health_profiles")
            .select("full_name")
            .eq("id", value: profileId)
            .limit(1)
            .execute()
            .value
        return rows.first?.full_name
    }

    private struct HeartRatePoint { let bpm: Int; let measuredAt: String }

    private func fetchLatestHeartRate(profileId: String) async -> HeartRatePoint? {
        struct Row: Decodable {
            let heart_rate: Double?
            let measured_at: String?
        }
        do {
            let rows: [Row] = try await client
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
            let rows: [Row] = try await client
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
            let rows: [Row] = try await client
                .from("hydration_logs")
                .select("amount_ml")
                .eq("health_profile_id", value: profileId)
                .gte("consumed_at", value: fromIso)
                .lt("consumed_at", value: toIso)
                .execute()
                .value
            let total = rows.reduce(0) { $0 + ($1.amount_ml ?? 0) }
            return total
        } catch {
            return nil
        }
    }

    private func fetchDietCaloriesToday(profileId: String, fromIso: String, toIso: String) async -> Int? {
        struct Row: Decodable { let calories: Double? }
        do {
            let rows: [Row] = try await client
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

    private struct MedAdherenceSummary {
        let taken: Int
        let total: Int
        let missedNames: [String]
    }

    private func fetchMedicationAdherenceToday(
        profileId: String,
        fromIso: String,
        toIso: String
    ) async -> MedAdherenceSummary? {
        struct LogRow: Decodable {
            let medication_id: String?
            let status: String?
        }
        do {
            let rows: [LogRow] = try await client
                .from("medication_logs")
                .select("medication_id, status")
                .eq("health_profile_id", value: profileId)
                .gte("scheduled_time", value: fromIso)
                .lt("scheduled_time", value: toIso)
                .execute()
                .value

            guard !rows.isEmpty else {
                return MedAdherenceSummary(taken: 0, total: 0, missedNames: [])
            }

            let total = rows.count
            let taken = rows.filter { ($0.status ?? "").lowercased() == "taken" }.count
            let missedMedIds: [String] = rows.compactMap { r in
                let s = (r.status ?? "").lowercased()
                guard (s == "missed" || s == "skipped"), let id = r.medication_id else { return nil }
                return id
            }

            var missedNames: [String] = []
            if !missedMedIds.isEmpty {
                missedNames = (try? await fetchMedicationNames(ids: Array(Set(missedMedIds)))) ?? []
            }

            return MedAdherenceSummary(taken: taken, total: total, missedNames: missedNames)
        } catch {
            return nil
        }
    }

    private func fetchMedicationNames(ids: [String]) async throws -> [String] {
        struct Row: Decodable { let id: String; let name: String? }
        guard !ids.isEmpty else { return [] }
        let rows: [Row] = try await client
            .from("medications")
            .select("id, name")
            .in("id", values: ids)
            .execute()
            .value
        return rows.compactMap { $0.name }.sorted()
    }

    // MARK: - Formatting helpers

    private func formatHours(_ hours: Double) -> String {
        if hours.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(Int(hours))
        }
        return String(format: "%.1f", hours)
    }
}
