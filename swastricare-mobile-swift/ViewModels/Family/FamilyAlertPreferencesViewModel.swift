//
//  FamilyAlertPreferencesViewModel.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — per-(caregiver, target_health_profile_id) alert
//  preferences ViewModel. Mirrors the Android FamilyAlertPreferencesViewModel.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class FamilyAlertPreferencesViewModel: ObservableObject {

    // MARK: - Published state

    @Published var isLoading: Bool = true
    @Published var isSaving: Bool = false
    @Published var prefs: FamilyAlertPreferences?
    @Published var error: String?
    @Published var saveMessage: String?

    // MARK: - Private

    private var caregiverUserId: String?
    private var targetProfileId: String?

    // MARK: - Load

    func load(targetHealthProfileId: String) async {
        targetProfileId = targetHealthProfileId
        isLoading = true
        error = nil

        guard let callerUUID = try? await SupabaseManager.shared.client.auth.session.user.id else {
            isLoading = false
            error = "Not authenticated"
            return
        }
        let callerId = callerUUID.uuidString
        caregiverUserId = callerId

        do {
            let existing = try await FamilyAlertPreferencesRepository.shared.get(
                caregiverUserId: callerId,
                targetProfileId: targetHealthProfileId
            )
            prefs = existing ?? FamilyAlertPreferences(
                caregiverUserId: callerId,
                targetHealthProfileId: targetHealthProfileId
            )
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Mutation

    func update(_ transform: (inout FamilyAlertPreferences) -> Void) {
        guard var current = prefs else { return }
        transform(&current)
        prefs = current
    }

    // MARK: - Save

    func save() {
        guard let prefs = prefs else { return }
        isSaving = true
        saveMessage = nil
        Task {
            do {
                try await FamilyAlertPreferencesRepository.shared.upsert(prefs)
                isSaving = false
                saveMessage = "Saved"
            } catch {
                isSaving = false
                saveMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func clearSaveMessage() {
        saveMessage = nil
    }
}
