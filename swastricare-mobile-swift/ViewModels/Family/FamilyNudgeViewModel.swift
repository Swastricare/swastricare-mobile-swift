//
//  FamilyNudgeViewModel.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — ViewModel powering the nudge bottom sheet.
//  Resolves the recipient's user id from their health profile, then sends
//  preset or custom nudges via FamilyNudgeRepository.
//
//  Mirrors the Android FamilyNudgeViewModel.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class FamilyNudgeViewModel: ObservableObject {

    // MARK: - Event

    enum Event {
        case success(deliveredViaPush: Bool, reason: String?)
        case failure(message: String)
    }

    // MARK: - State

    struct State {
        var memberName: String = ""
        var recipientUserId: String?
        var targetHealthProfileId: String = ""
        var customMessage: String = ""
        var isSending: Bool = false
        var event: Event?
    }

    @Published var state = State()

    // MARK: - Dependencies

    private let supabase = SupabaseManager.shared
    private let repo = FamilyNudgeRepository.shared

    // MARK: - Init

    /// Resolves the target family member (name + owner user id) so we can send
    /// nudges. Uses the same family group lookup flow as the dashboard.
    func initialize(targetHealthProfileId: String) async {
        state.targetHealthProfileId = targetHealthProfileId

        do {
            // 1. Find the caller's family group, then the target member row
            //    (FamilyMember carries fullName via embedded health_profiles).
            if let group = try await supabase.fetchMyFamilyGroup() {
                let members = try await supabase.fetchFamilyMembers(groupId: group.id)
                if let target = members.first(where: {
                    $0.healthProfileId.uuidString.lowercased() == targetHealthProfileId.lowercased()
                }) {
                    state.memberName = target.fullName ?? ""
                }
            }

            // 2. Resolve the recipient's auth user id by looking up health_profiles
            //    directly (FamilyMember doesn't carry user_id).
            struct ProfileRow: Decodable { let user_id: String? }
            let rows: [ProfileRow] = try await supabase.client
                .from("health_profiles")
                .select("user_id")
                .eq("id", value: targetHealthProfileId)
                .limit(1)
                .execute()
                .value
            if let uid = rows.first?.user_id, !uid.isEmpty {
                state.recipientUserId = uid
            }
        } catch {
            // Leave recipientUserId nil → sheet shows "Resolving member…" hint.
            // Don't surface as an Event because there's nothing the user can do.
        }
    }

    // MARK: - Inputs

    func setCustomMessage(_ text: String) {
        state.customMessage = String(text.prefix(200))
    }

    func clearEvent() {
        state.event = nil
    }

    // MARK: - Send

    func sendPreset(_ preset: NudgePreset) {
        guard let recipient = state.recipientUserId else {
            state.event = .failure(message: "Member not loaded")
            return
        }
        state.isSending = true
        state.event = nil
        Task {
            do {
                let resp = try await repo.sendPreset(
                    recipientUserId: recipient,
                    targetProfileId: state.targetHealthProfileId,
                    preset: preset,
                    isCritical: false
                )
                state.isSending = false
                state.event = .success(deliveredViaPush: resp.delivered, reason: resp.reason)
                state.customMessage = ""
            } catch {
                state.isSending = false
                state.event = .failure(message: error.localizedDescription)
            }
        }
    }

    func sendCustom() {
        let msg = state.customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else {
            state.event = .failure(message: "Message cannot be empty")
            return
        }
        guard let recipient = state.recipientUserId else {
            state.event = .failure(message: "Member not loaded")
            return
        }
        state.isSending = true
        state.event = nil
        Task {
            do {
                let resp = try await repo.sendCustom(
                    recipientUserId: recipient,
                    targetProfileId: state.targetHealthProfileId,
                    message: msg,
                    category: "CHECKIN",
                    isCritical: false
                )
                state.isSending = false
                state.event = .success(deliveredViaPush: resp.delivered, reason: resp.reason)
                state.customMessage = ""
            } catch {
                state.isSending = false
                state.event = .failure(message: error.localizedDescription)
            }
        }
    }
}
