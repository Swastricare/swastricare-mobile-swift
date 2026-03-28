//
//  OnboardingView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var skipOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var isAnimating: Bool = false
    @State private var getStartedGlow: Bool = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let totalPages = 3
    private let buttonWidth: CGFloat = 180
    private let buttonHeight: CGFloat = 52

    /// Per-screen accent colors for the narrative color progression
    private static let accentColors: [Color] = [
        AppColors.accentBlue,          // Screen 1: Indigo
        AppColors.onboardingPurple,    // Screen 2: Purple
        AppColors.onboardingSkyBlue,   // Screen 3: Sky Blue
    ]

    private var currentAccent: Color {
        Self.accentColors[currentPage]
    }

    var body: some View {
        ZStack {
            // Background
            PremiumBackground()

            VStack(spacing: 0) {
                // Top bar: page counter (left) + skip button (right)
                HStack {
                    Text("\(currentPage + 1) of \(totalPages)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                        .padding(.top, 12)
                        .opacity(skipOpacity)

                    Spacer()

                    // Skip button — hidden on last page
                    if currentPage < totalPages - 1 {
                        Button {
                            guard !isAnimating else { return }
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .disabled(isAnimating)
                        .opacity(skipOpacity)
                        .padding(.trailing, 24)
                        .padding(.top, 12)
                    } else {
                        // Invisible spacer to keep layout stable
                        Color.clear
                            .frame(width: 40, height: 20)
                            .padding(.trailing, 24)
                            .padding(.top, 12)
                    }
                }

                // Pages
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        pageIndex: 0,
                        totalPages: totalPages,
                        title: "Care for your family,",
                        highlightedTitle: "from anywhere",
                        subtitle: "Monitor Amma's BP, track Appa's medications, and get instant alerts — all from your phone.",
                        accentColor: Self.accentColors[0],
                        backgroundTint: Color(hex: "EEF2FF"),
                        isActive: currentPage == 0
                    ) {
                        FamilyPreviewCard(isActive: currentPage == 0)
                    }
                    .tag(0)

                    OnboardingPageView(
                        pageIndex: 1,
                        totalPages: totalPages,
                        title: "Your health AI,",
                        highlightedTitle: "always ready",
                        subtitle: "Ask about symptoms, medications, or diet in English or Hindi. Powered by medical AI.",
                        accentColor: Self.accentColors[1],
                        backgroundTint: Color(hex: "F3E8FF"),
                        isActive: currentPage == 1
                    ) {
                        AIPreviewCard()
                    }
                    .tag(1)

                    OnboardingPageView(
                        pageIndex: 2,
                        totalPages: totalPages,
                        title: "Your reports,",
                        highlightedTitle: "safe forever",
                        subtitle: "Store prescriptions, lab results, and X-rays. Share with any doctor in seconds.",
                        accentColor: Self.accentColors[2],
                        backgroundTint: Color(hex: "E0F2FE"),
                        isActive: currentPage == 2
                    ) {
                        VaultPreviewCard(isActive: currentPage == 2)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)
                .disabled(isAnimating)
                .allowsHitTesting(!isAnimating)
                .onChange(of: currentPage) { _, _ in
                    guard !reduceMotion else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                // Bottom controls
                VStack(spacing: 20) {
                    // Page indicator dots with glow
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? currentAccent : Color.primary.opacity(0.2))
                                .frame(
                                    width: currentPage == index ? 20 : 6,
                                    height: 6
                                )
                                .shadow(
                                    color: currentPage == index ? currentAccent.opacity(0.4) : .clear,
                                    radius: currentPage == index ? 6 : 0,
                                    y: 0
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage < totalPages - 1 {
                        Button {
                            guard !isAnimating else { return }
                            isAnimating = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                currentPage += 1
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                guard !isOnboardingComplete else { return }
                                isAnimating = false
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: buttonWidth, height: buttonHeight)
                                .background(currentAccent)
                                .clipShape(Capsule())
                                .shadow(color: currentAccent.opacity(0.3), radius: 12, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isAnimating)
                        .opacity(buttonOpacity)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                guard !isAnimating else { return }
                                isAnimating = true
                                completeOnboarding()
                            } label: {
                                Text("Get Started")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: buttonWidth, height: buttonHeight)
                                    .background(
                                        LinearGradient(
                                            colors: [AppColors.accentBlue, AppColors.onboardingSkyBlue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: AppColors.accentBlue.opacity(getStartedGlow ? 0.5 : 0.2), radius: getStartedGlow ? 20 : 10, y: 7)
                                    .scaleEffect(getStartedGlow ? 1.02 : 1.0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isAnimating)
                            .opacity(buttonOpacity)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    getStartedGlow = true
                                }
                            }

                            // Privacy note — only on last page
                            Text("Your data stays on your device. We never sell your information.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .opacity(buttonOpacity)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            let delay: Double = reduceMotion ? 0 : 1.0
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                skipOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(reduceMotion ? 0 : 0.4)) {
                buttonOpacity = 1.0
            }
        }
        .trackScreen("Onboarding")
    }

    // MARK: - Completion

    private func completeOnboarding() {
        AppAnalyticsService.shared.logOnboardingComplete()
        withAnimation(.easeOut(duration: 0.2)) {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
