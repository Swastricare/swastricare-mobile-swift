//
//  ReferralViewModel.swift
//  swastricare-mobile-swift
//

import Foundation
import Combine

@MainActor
final class ReferralViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isAIUnlocked: Bool = false
    @Published private(set) var referralCode: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var showCodeEntry: Bool = false
    @Published var enteredCode: String = ""
    @Published private(set) var isApplyingCode: Bool = false
    @Published private(set) var applyCodeError: String?

    // MARK: - Dependencies

    private let referralService: ReferralServiceProtocol

    // MARK: - Cache Keys

    private static let aiUnlockedKey = "referral_ai_unlocked"
    private static let referralCodeKey = "referral_code"

    // MARK: - Init

    init(referralService: ReferralServiceProtocol = ReferralService.shared) {
        self.referralService = referralService
        self.isAIUnlocked = UserDefaults.standard.bool(forKey: Self.aiUnlockedKey)
        self.referralCode = UserDefaults.standard.string(forKey: Self.referralCodeKey)
        observeDeepLinkReferral()
    }

    // MARK: - Deep Link Observation

    private func observeDeepLinkReferral() {
        NotificationCenter.default.addObserver(
            forName: .deepLinkReferral,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let code = notification.userInfo?[DeepLinkUserInfoKey.referralCode] as? String, !code.isEmpty {
                self.enteredCode = code
                Task { @MainActor in
                    await self.applyEnteredCode()
                }
            }
        }
    }

    // MARK: - Load State

    func loadReferralState() async {
        if referralCode == nil {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            // Check AI unlock status
            let unlocked = try await referralService.checkAIUnlocked()
            isAIUnlocked = unlocked
            UserDefaults.standard.set(unlocked, forKey: Self.aiUnlockedKey)

            if unlocked {
                // Already unlocked, no need to fetch code
                return
            }

            // Get or create referral code
            let code = try await referralService.getOrCreateReferralCode()
            referralCode = code
            UserDefaults.standard.set(code, forKey: Self.referralCodeKey)
            print("Referral code loaded: \(code)")
        } catch {
            print("Failed to load referral state: \(error)")
            // If we have no cached code, show error
            if referralCode == nil {
                errorMessage = "Unable to load referral code. Please check your connection and try again."
            }
        }
    }

    // MARK: - Apply Code

    func applyEnteredCode() async {
        let code = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            applyCodeError = "Please enter a referral code."
            return
        }

        isApplyingCode = true
        applyCodeError = nil
        defer { isApplyingCode = false }

        do {
            let success = try await referralService.applyReferralCode(code)
            if success {
                showCodeEntry = false
                enteredCode = ""
                // Reload referral state so isAIUnlocked gets updated
                await loadReferralState()
            } else {
                applyCodeError = "Invalid referral code. Please check and try again."
            }
        } catch {
            applyCodeError = UserFriendlyError.message(from: error)
        }
    }

    // MARK: - Sign Out Cleanup

    func clearOnSignOut() {
        isAIUnlocked = false
        referralCode = nil
        isLoading = false
        errorMessage = nil
        showCodeEntry = false
        enteredCode = ""
        isApplyingCode = false
        applyCodeError = nil
        UserDefaults.standard.removeObject(forKey: Self.aiUnlockedKey)
        UserDefaults.standard.removeObject(forKey: Self.referralCodeKey)
    }
}
