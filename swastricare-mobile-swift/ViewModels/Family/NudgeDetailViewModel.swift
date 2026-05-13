//
//  NudgeDetailViewModel.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — drives the NudgeDetailView shown when a recipient taps
//  an FCM push notification (swastricareapp://nudge/{id}). Mirrors the Android
//  NudgeDetailViewModel.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class NudgeDetailViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var nudge: NudgeDetail?
    @Published var error: String?
    @Published var isActing: Bool = false

    func load(id: String) async {
        isLoading = true
        error = nil
        do {
            let detail = try await FamilyNudgeRepository.shared.fetchById(id: id)
            if let detail = detail {
                nudge = detail
            } else {
                error = "Nudge not found"
            }
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func markActedOn(onDone: @escaping () -> Void) {
        guard let id = nudge?.id else { return }
        isActing = true
        Task {
            try? await FamilyNudgeRepository.shared.markActedOn(id: id)
            isActing = false
            onDone()
        }
    }

    func dismissNudge(onDone: @escaping () -> Void) {
        guard let id = nudge?.id else { return }
        isActing = true
        Task {
            try? await FamilyNudgeRepository.shared.dismiss(id: id)
            isActing = false
            onDone()
        }
    }
}
