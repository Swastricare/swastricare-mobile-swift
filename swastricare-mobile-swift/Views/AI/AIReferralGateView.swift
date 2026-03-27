//
//  AIReferralGateView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct AIReferralGateView: View {

    @ObservedObject var viewModel: ReferralViewModel

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 60)

                    // AI Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.accentBlue.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accentBlue, AppColors.onboardingPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Title
                    VStack(spacing: 10) {
                        Text("Unlock SwasthiCare AI")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Refer a friend to unlock AI — free, forever")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // How it works
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How it works")
                            .font(.system(size: 18, weight: .semibold))

                        howItWorksStep(number: "1", title: "Share your code", subtitle: "Send your unique code to a friend")
                        howItWorksStep(number: "2", title: "Friend signs up", subtitle: "They join SwasthiCare using your code")
                        howItWorksStep(number: "3", title: "AI unlocked!", subtitle: "You get lifetime access to SwasthiCare AI")
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppDimensions.cardRadius))

                    // Referral code display
                    if let code = viewModel.referralCode {
                        VStack(spacing: 12) {
                            Text("Your referral code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack {
                                Text(code)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .tracking(4)

                                Button {
                                    UIPasteboard.general.string = code
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.accentBlue)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else if viewModel.isLoading {
                        ProgressView("Loading your referral code...")
                            .padding(16)
                    } else if viewModel.errorMessage != nil {
                        VStack(spacing: 12) {
                            Text("Could not load referral code")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                Task { await viewModel.loadReferralState() }
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.accentBlue)
                        }
                        .padding(16)
                    }

                    // Share button (primary CTA)
                    if let code = viewModel.referralCode {
                        ShareLink(
                            item: "Hey! I'm using SwasthiCare — a personal health companion app. Join using my referral code: \(code)\n\nDownload SwasthiCare: https://apps.apple.com/app/swasthicare/id6740091498"
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Share with a Friend")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accentBlue, AppColors.onboardingPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    // "I have a referral code" secondary action
                    Button {
                        viewModel.showCodeEntry = true
                    } label: {
                        Text("I have a referral code")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.accentBlue)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $viewModel.showCodeEntry) {
            referralCodeEntrySheet
        }
    }

    // MARK: - How It Works Step

    private func howItWorksStep(number: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [AppColors.accentBlue, AppColors.onboardingPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Code Entry Sheet

    private var referralCodeEntrySheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter Referral Code")
                    .font(.system(size: 22, weight: .bold))

                Text("Enter the code your friend shared with you")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("e.g. SYA7K2", text: $viewModel.enteredCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                if let error = viewModel.applyCodeError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accentRed)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await viewModel.applyEnteredCode()
                    }
                } label: {
                    HStack {
                        if viewModel.isApplyingCode {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Apply Code")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.enteredCode.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isApplyingCode)

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        viewModel.showCodeEntry = false
                        viewModel.enteredCode = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
