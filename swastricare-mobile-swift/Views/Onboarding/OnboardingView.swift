//
//  OnboardingView.swift
//  swastricare-mobile-swift
//
//  Redesigned to pixel-match Android OnboardingScreen.kt
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let totalPages = 3

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: logo (left) + skip (right) — mirrors Android TopBar
                OnboardingTopBar(
                    showSkip: currentPage < totalPages - 1,
                    onSkip: { completeOnboarding() }
                )

                // Pager — mirrors Android HorizontalPager
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        pageIndex: 0,
                        illustrationName: "onboarding illustration",
                        isFamilyHero: true,
                        titlePrefix: "Your family's ",
                        titleItalic: "health",
                        titleSeparator: ",\n",
                        titleHighlight: "all in one place",
                        subtitle: "Track health records, manage appointments, get reminders and care better—together.",
                        isActive: currentPage == 0
                    ) {
                        OnboardingFeatureCards()
                    }
                    .tag(0)

                    OnboardingPageView(
                        pageIndex: 1,
                        illustrationName: "onboarding 1",
                        isFamilyHero: false,
                        titlePrefix: "Your ",
                        titleItalic: "Health",
                        titleSeparator: ",\n",
                        titleHighlight: "All in One Place",
                        subtitle: "Track, manage, and improve your health with personalized insights and smart tools.",
                        isActive: currentPage == 1
                    ) {
                        EmptyView()
                    }
                    .tag(1)

                    OnboardingPageView(
                        pageIndex: 2,
                        illustrationName: "onboarding2",
                        isFamilyHero: false,
                        titlePrefix: "Smarter ",
                        titleItalic: "Insights",
                        titleSeparator: ",\n",
                        titleHighlight: "Better You",
                        subtitle: "Get AI-powered insights, reminders, and support that help you build healthy habits effortlessly.",
                        isActive: currentPage == 2
                    ) {
                        EmptyView()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    guard !reduceMotion else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                // Bottom controls — mirrors Android BottomControls
                OnboardingBottomControls(
                    pageCount: totalPages,
                    currentPage: currentPage,
                    isLast: currentPage == totalPages - 1,
                    onContinue: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if currentPage == totalPages - 1 {
                            completeOnboarding()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                currentPage += 1
                            }
                        }
                    },
                    onSignIn: { completeOnboarding() }
                )
            }
        }
        .trackScreen("Onboarding")
    }

    private func completeOnboarding() {
        AppAnalyticsService.shared.logOnboardingComplete()
        withAnimation(.easeOut(duration: 0.2)) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Top Bar

private struct OnboardingTopBar: View {
    let showSkip: Bool
    let onSkip: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            // Logo
            HStack(spacing: 8) {
                Image.androidIcon("swastricare icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Swasthi")
                            .font(.poppins(.bold, size: 20))
                            .foregroundColor(Color(hex: "0F172A"))
                        Text("Care")
                            .font(.poppins(.bold, size: 20))
                            .foregroundColor(AppColors.aiTeal)
                    }
                    Text("Your Family, Our Care")
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(Color(hex: "6B7280"))
                }
            }

            Spacer()

            // Skip button — invisible when not shown to keep layout stable
            Button(action: onSkip) {
                Text("Skip")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(AppColors.aiTeal)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            }
            .opacity(showSkip ? 1 : 0)
            .disabled(!showSkip)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Bottom Controls

private struct OnboardingBottomControls: View {
    let pageCount: Int
    let currentPage: Int
    let isLast: Bool
    let onContinue: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Animated dots
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    let selected = currentPage == i
                    Capsule()
                        .fill(selected ? AppColors.aiTeal : AppColors.aiTeal.opacity(0.18))
                        .frame(width: selected ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }

            // Primary CTA
            OnboardingPrimaryButton(
                label: isLast ? "Get Started" : "Continue",
                action: onContinue
            )

            // Sign in row
            HStack(spacing: 0) {
                Text("Already have an account? ")
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "6B7280"))
                Button(action: onSignIn) {
                    Text("Sign In")
                        .font(.poppins(.bold, size: 13))
                        .foregroundColor(AppColors.aiTeal)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Primary CTA Button (solid AITeal)

struct OnboardingPrimaryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.poppins(.bold, size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppColors.aiTeal)
                .clipShape(Capsule())
                .shadow(color: AppColors.aiTeal.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
