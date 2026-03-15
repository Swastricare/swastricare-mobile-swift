//
//  OnboardingPreviewCards.swift
//  swastricare-mobile-swift
//

import SwiftUI

// MARK: - Onboarding Color Constants

extension AppColors {
    /// Purple accent for AI screen
    static let onboardingPurple = Color(hex: "7C3AED")
    /// Sky blue accent for Vault screen
    static let onboardingSkyBlue = Color(hex: "0EA5E9")
}

// MARK: - Shared Card Style

/// Shared card chrome for all onboarding preview cards (background + clip + shadow)
private struct OnboardingCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(AppDimensions.cardPadding)
            .background(colorScheme == .dark ? AnyView(Color.clear.background(.ultraThinMaterial)) : AnyView(AppColors.cardBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.largeCardRadius))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, y: 4)
    }
}

extension View {
    fileprivate func onboardingCard() -> some View {
        modifier(OnboardingCardModifier())
    }
}

// MARK: - Screen 1: Family Health Hub Preview

struct FamilyPreviewCard: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var alertPulse: Bool = false
    @State private var badgePulse: Bool = false
    @State private var bpValue: Int = 0
    @State private var stepCount: Int = 0
    @State private var showCheckmark: Bool = false
    @State private var avatarFloat: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Family member header
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay(Text("👩").font(.system(size: 18)))
                    .shadow(color: AppColors.accentBlue.opacity(0.25), radius: 6, y: 4)
                    .offset(y: avatarFloat ? -2 : 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Amma")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Last updated 2m ago")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    if showCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "16A34A"))
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text("All Good")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "16A34A"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "DCFCE7"))
                .clipShape(Capsule())
                .scaleEffect(badgePulse ? 1.06 : 1.0)
            }

            // Stats row — animated counting numbers
            HStack(spacing: 6) {
                AnimatedStatCell(label: "Blood Pressure", value: "\(bpValue > 0 ? "\(bpValue)/80" : "—")", detail: "Normal", detailColor: AppColors.accentGreen)
                AnimatedStatCell(label: "Medications", value: showCheckmark ? "2/2 ✓" : "—", detail: "On track", detailColor: AppColors.accentGreen)
                AnimatedStatCell(label: "Hydration", value: bpValue > 0 ? "1.5L" : "—", detail: "60%", detailColor: .orange)
            }

            // Step count row — counting animation
            HStack(spacing: 6) {
                Text("👣")
                    .font(.system(size: 13))
                Text("\(stepCount > 0 ? stepCount.formatted() : "—") steps today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.accentGreen)
                    .contentTransition(.numericText())
                Spacer()
            }
            .padding(.horizontal, 4)

            // Alert row — Appa missed medication
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "D97706")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                    .overlay(Text("👴").font(.system(size: 14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Appa")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Missed evening medication")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accentRed)
                }

                Spacer()

                Text("⚠️")
                    .font(.system(size: 14))
                    .scaleEffect(alertPulse ? 1.15 : 1.0)
                    .rotationEffect(.degrees(alertPulse ? 8 : -8))
            }
            .padding(10)
            .background(AppColors.accentRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Family health dashboard showing Amma's blood pressure, medications on track, steps today, and an alert for Appa's missed medication")
        .onChange(of: isActive) { _, active in
            if active {
                startAnimations()
            } else {
                resetAnimations()
            }
        }
    }

    private func startAnimations() {
        guard !reduceMotion else {
            bpValue = 120; stepCount = 4532; showCheckmark = true
            return
        }
        // Count up BP
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            bpValue = 120
        }
        // Count up steps
        withAnimation(.easeOut(duration: 1.2).delay(0.5)) {
            stepCount = 4532
        }
        // Show checkmark
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.8)) {
            showCheckmark = true
        }
        // Continuous animations
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            alertPulse = true
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) {
            badgePulse = true
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            avatarFloat = true
        }
    }

    private func resetAnimations() {
        withAnimation(.easeInOut(duration: 0.3)) {
            alertPulse = false
            badgePulse = false
            avatarFloat = false
        }
        bpValue = 0; stepCount = 0; showCheckmark = false
    }
}

// MARK: - Animated Stat Cell

private struct AnimatedStatCell: View {
    let label: String
    let value: String
    let detail: String
    let detailColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            Text(detail)
                .font(.system(size: 8))
                .foregroundColor(detailColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Screen 2: AI Health Companion Preview

struct AIPreviewCard: View {
    @State private var typedText: String = ""
    @State private var showResponse: Bool = false
    @State private var showPills: Bool = false
    @State private var cursorVisible: Bool = true
    @State private var aiIconSpin: Double = 0

    private let fullQuestion = "My sugar is 180 after food. Normal?"
    private let aiResponse = "**180 mg/dL post-meal is slightly high.** Normal is below 140. Consult your doctor if this persists."

    var body: some View {
        VStack(spacing: 10) {
            // User message — typewriter effect
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Text(typedText)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    if !showResponse {
                        Text("|")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white.opacity(cursorVisible ? 1 : 0))
                    }
                }
                .padding(12)
                .background(AppColors.accentBlue)
                .clipShape(
                    .rect(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 16
                    )
                )
            }

            // AI response
            if showResponse {
                HStack(alignment: .top, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [AppColors.onboardingPurple, AppColors.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                        Text("✦")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(aiIconSpin))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(.init(aiResponse))
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineSpacing(3)

                        HStack(spacing: 4) {
                            Text("Swastri AI")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppColors.onboardingPurple)
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.onboardingPurple)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.9)))
            }

            // Suggestion pills
            if showPills {
                HStack(spacing: 6) {
                    SuggestionPill(text: "Sugar control tips", color: AppColors.onboardingPurple)
                    SuggestionPill(text: "Diet for diabetes", color: AppColors.onboardingPurple)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI health chat showing a question about sugar levels and a helpful medical response")
        .onAppear { startTypewriter() }
    }

    private func startTypewriter() {
        typedText = ""
        showResponse = false
        showPills = false

        // Cursor blink
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            cursorVisible.toggle()
            if showResponse { timer.invalidate() }
        }

        // Type each character
        for (i, char) in fullQuestion.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.04) {
                typedText += String(char)
            }
        }

        // Show AI response after typing finishes
        let typingDuration = 0.4 + Double(fullQuestion.count) * 0.04 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showResponse = true
            }
            // Spin AI icon
            withAnimation(.easeOut(duration: 0.6)) {
                aiIconSpin = 360
            }
        }

        // Show pills after response
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showPills = true
            }
        }
    }
}

private struct SuggestionPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Screen 3: Medical Vault Preview

struct VaultPreviewCard: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var docsVisible: [Bool] = [false, false, false, false]
    @State private var lockRotations: [Double] = [0, 0, 0, 0]
    @State private var shieldScale: CGFloat = 0.5
    @State private var shieldOpacity: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Documents slide in one by one
            if docsVisible[0] {
                DocumentRow(icon: "PDF", iconGradient: [AppColors.accentRed, Color(hex: "DC2626")], iconIsText: true, title: "Blood Report — SRL Diagnostics", subtitle: "Mar 2026 · CBC, Lipid, Thyroid", lockRotation: lockRotations[0])
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            if docsVisible[1] {
                DocumentRow(icon: "🩻", iconGradient: [AppColors.onboardingSkyBlue, Color(hex: "0284C7")], iconIsText: false, title: "X-Ray — Apollo Hospital", subtitle: "Feb 2026 · Chest X-Ray", lockRotation: lockRotations[1])
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            if docsVisible[2] {
                DocumentRow(icon: "💊", iconGradient: [AppColors.accentGreen, Color(hex: "16A34A")], iconIsText: false, title: "Prescription — Dr. Sharma", subtitle: "Jan 2026 · Diabetes Management", lockRotation: lockRotations[2])
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            if docsVisible[3] {
                DocumentRow(icon: "🧠", iconGradient: [AppColors.onboardingPurple, Color(hex: "6D28D9")], iconIsText: false, title: "MRI — Manipal Hospital", subtitle: "Dec 2025 · Brain Scan", lockRotation: lockRotations[3])
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }

            // Security badge — scales in
            HStack(spacing: 8) {
                Text("🛡️")
                    .font(.system(size: 16))
                    .scaleEffect(shieldScale)

                VStack(alignment: .leading, spacing: 1) {
                    Text("End-to-End Encrypted")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Only you and who you share with can access")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColors.onboardingSkyBlue.opacity(0.08), AppColors.accentBlue.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.onboardingSkyBlue.opacity(0.12), lineWidth: 1))
            .opacity(shieldOpacity)
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Medical vault showing 4 encrypted documents from SRL Diagnostics, Apollo Hospital, Dr. Sharma, and Manipal Hospital")
        .onChange(of: isActive) { _, active in
            if active {
                startAnimations()
            } else {
                resetAnimations()
            }
        }
    }

    private func startAnimations() {
        guard !reduceMotion else {
            docsVisible = [true, true, true, true]
            lockRotations = [0, 0, 0, 0]
            shieldScale = 1.0; shieldOpacity = 1.0
            return
        }

        // Documents slide in one by one
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    docsVisible[i] = true
                }
                // Lock icon does a little turn
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    lockRotations[i] = -15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        lockRotations[i] = 0
                    }
                }
            }
        }

        // Shield badge scales in after all docs
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                shieldScale = 1.0
                shieldOpacity = 1.0
            }
        }
    }

    private func resetAnimations() {
        docsVisible = [false, false, false, false]
        lockRotations = [0, 0, 0, 0]
        shieldScale = 0.5; shieldOpacity = 0
    }
}

private struct DocumentRow: View {
    let icon: String
    let iconGradient: [Color]
    let iconIsText: Bool
    let title: String
    let subtitle: String
    var lockRotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .overlay(
                    Group {
                        if iconIsText {
                            Text(icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(icon).font(.system(size: 16))
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(AppColors.onboardingSkyBlue)
                .rotationEffect(.degrees(lockRotation))
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Applies shimmer only when active (respects Reduce Motion)
private struct ConditionalShimmer: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.shimmer()
        } else {
            content
        }
    }
}
