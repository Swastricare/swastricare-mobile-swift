//
//  ReferralCodeEntryView.swift
//  swastricare-mobile-swift
//
//  Referral Code Entry Screen - shown once after signup, before health profile
//

import SwiftUI

struct ReferralCodeEntryView: View {
    @StateObject private var viewModel = DependencyContainer.shared.authViewModel
    @State private var referralCode: String
    @State private var isApplying: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false
    @Environment(\.colorScheme) var colorScheme

    let pendingCode: String?
    let onComplete: () -> Void

    init(pendingCode: String?, onComplete: @escaping () -> Void) {
        self.pendingCode = pendingCode
        self.onComplete = onComplete
        // Initialize the code from pending code if available
        _referralCode = State(initialValue: pendingCode ?? "")
    }

    var body: some View {
        ZStack {
            // Rich gradient background (matches auth screens)
            AuthGradientBackground()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: max(60, geo.safeAreaInsets.top + 20))

                        // MARK: - Icon
                        ZStack {
                            // Subtle glow
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: "11998e").opacity(0.25),
                                            Color(hex: "11998e").opacity(0.0)
                                        ],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 70
                                    )
                                )
                                .frame(width: 140, height: 140)

                            // Icon
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(hex: "11998e").opacity(0.3), radius: 15, y: 8)
                        }
                        .padding(.bottom, 32)

                        // MARK: - Header
                        VStack(spacing: 8) {
                            Text("Got a Referral Code?")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)

                            Text("Enter the code shared by your friend")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 40)

                        // MARK: - Form Card
                        VStack(spacing: 20) {
                            // Referral Code Input
                            VStack(alignment: .leading, spacing: 10) {
                                Text("REFERRAL CODE")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(0.8)

                                HStack(spacing: 12) {
                                    Image(systemName: "ticket.fill")
                                        .foregroundColor(Color(hex: "11998e"))
                                        .frame(width: 20)
                                        .font(.system(size: 16))

                                    TextField("Enter code", text: $referralCode)
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled(true)
                                        .tint(Color(hex: "11998e"))
                                        .disabled(isApplying || showSuccess)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.04)
                                        : Color.primary.opacity(0.035)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            referralCode.isEmpty
                                                ? Color.primary.opacity(0.06)
                                                : Color(hex: "11998e").opacity(0.6),
                                            lineWidth: referralCode.isEmpty ? 0.5 : 1.5
                                        )
                                )
                            }

                            // Error/Success message
                            if let error = errorMessage, !showSuccess {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 14))
                                    Text(error)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(AppColors.accentRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppColors.accentRed.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            if showSuccess {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Referral code applied successfully!")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(AppColors.accentGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppColors.accentGreen.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            // Apply Button
                            Button(action: { Task { await applyCode() } }) {
                                if isApplying {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(showSuccess ? "Continue" : "Apply Code")
                                }
                            }
                            .buttonStyle(
                                AuthPrimaryButtonStyle(
                                    isEnabled: showSuccess || (!referralCode.isEmpty && !isApplying)
                                )
                            )
                            .disabled(!showSuccess && (referralCode.isEmpty || isApplying))
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25),
                                    lineWidth: 0.5
                                )
                        )
                        .padding(.horizontal, 20)

                        // Skip Button
                        if !showSuccess {
                            Button(action: skip) {
                                Text("Skip for now")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 20)
                            .disabled(isApplying)
                        }

                        Spacer()
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    // MARK: - Actions

    private func applyCode() async {
        // If already successful, just proceed
        if showSuccess {
            onComplete()
            return
        }

        let code = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !code.isEmpty else {
            errorMessage = "Please enter a referral code"
            return
        }

        isApplying = true
        errorMessage = nil

        do {
            let success = try await ReferralService.shared.applyReferralCode(code)

            if success {
                await MainActor.run {
                    showSuccess = true
                    errorMessage = nil
                }

                // Auto-proceed after showing success
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                await MainActor.run {
                    onComplete()
                }
            } else {
                await MainActor.run {
                    errorMessage = "Invalid or expired referral code"
                    isApplying = false
                }
            }
        } catch {
            await MainActor.run {
                // Map error to user-friendly message
                if error.localizedDescription.lowercased().contains("network") ||
                   error.localizedDescription.lowercased().contains("connection") {
                    errorMessage = "Network error. Please check your connection."
                } else if error.localizedDescription.lowercased().contains("self") {
                    errorMessage = "You can't use your own referral code"
                } else {
                    errorMessage = "Invalid referral code. Please try again."
                }
                isApplying = false
            }
        }
    }

    private func skip() {
        onComplete()
    }
}

#Preview {
    ReferralCodeEntryView(pendingCode: nil) {
        print("Completed")
    }
}
