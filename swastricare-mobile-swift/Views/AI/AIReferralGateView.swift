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
                            .font(.poppins(.medium, size: 44))
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
                            .font(.poppins(.bold, size: 28))
                            .multilineTextAlignment(.center)

                        Text("Refer a friend to unlock AI — free, forever")
                            .font(.poppins(.medium, size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // How it works
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How it works")
                            .font(.poppins(.semiBold, size: 18))

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
                                .font(.poppins(.medium, size: 14))
                                .foregroundColor(.secondary)

                            HStack {
                                Text(code)
                                    .font(.poppins(.bold, size: 28))
                                    .tracking(4)

                                Button {
                                    UIPasteboard.general.string = code
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.poppins(.regular, size: 16))
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
                                .font(.poppins(.regular, size: 14))
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                Task { await viewModel.loadReferralState() }
                            }
                            .font(.poppins(.semiBold, size: 15))
                            .foregroundColor(AppColors.accentBlue)
                        }
                        .padding(16)
                    }

                    // Share button (primary CTA)
                    if let code = viewModel.referralCode {
                        ShareLink(
                            item: "Hey! I'm using SwasthiCare — a personal health companion app. Join using my referral code: \(code)\n\nDownload SwasthiCare: https://apps.apple.com/in/app/swastricare/id6757637229"
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.poppins(.semiBold, size: 18))
                                Text("Share with a Friend")
                                    .font(.poppins(.semiBold, size: 18))
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

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .trackScreen("AIReferralGate")
    }

    // MARK: - How It Works Step

    private func howItWorksStep(number: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.poppins(.bold, size: 16))
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
                    .font(.poppins(.semiBold, size: 15))
                Text(subtitle)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

}
