//
//  OnboardingPreviewCards.swift
//  swastricare-mobile-swift
//
//  Redesigned to pixel-match Android OnboardingScreen / OnboardingPreviewCards.
//

import SwiftUI

// MARK: - Onboarding Color Constants

extension AppColors {
    /// Purple accent for AI chat bubble
    static let onboardingPurple = Color(hex: "7C3AED")
    /// Sky blue accent for Vault screen
    static let onboardingSkyBlue = Color(hex: "0EA5E9")
}

// MARK: - Shared Card Chrome (white, subtle border, rounded)

private struct OnboardingCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func onboardingCard() -> some View {
        modifier(OnboardingCardModifier())
    }
}

// MARK: - Page 0: Feature Cards (mirrors Android FeatureCard grid)

struct OnboardingFeatureCards: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            FeatureCard(
                imageName: "smart health records",
                title: "Smart Health Records",
                description: "Store and access your family's health records securely."
            )
            FeatureCard(
                imageName: "appoinments made easy",
                title: "Appointments Made Easy",
                description: "Book, manage and get reminders for all your appointments."
            )
            FeatureCard(
                imageName: "secure & private",
                title: "Secure & Private",
                description: "Your data is encrypted and 100% private. Always protected."
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FeatureCard: View {
    let imageName: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image.androidImage(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)

            Text(title)
                .font(.poppins(.bold, size: 12))
                .foregroundColor(Color(hex: "0F172A"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            Text(description)
                .font(.poppins(.regular, size: 10))
                .foregroundColor(Color(hex: "6B7280"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Page 1: AI Health Companion Preview

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
            // User message — typewriter
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Text(typedText)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.white)
                    if !showResponse {
                        Text("|")
                            .font(.poppins(.light, size: 12))
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
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.onboardingPurple, AppColors.accentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                        Text("✦")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(aiIconSpin))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(.init(aiResponse))
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.primary)
                            .lineSpacing(3)

                        HStack(spacing: 4) {
                            Text("Swastri AI")
                                .font(.poppins(.bold, size: 9))
                                .foregroundColor(AppColors.onboardingPurple)
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.onboardingPurple)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.03))
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

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            cursorVisible.toggle()
            if showResponse { timer.invalidate() }
        }

        for (i, char) in fullQuestion.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.04) {
                typedText += String(char)
            }
        }

        let typingDuration = 0.4 + Double(fullQuestion.count) * 0.04 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showResponse = true
            }
            withAnimation(.easeOut(duration: 0.6)) {
                aiIconSpin = 360
            }
        }

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
            .font(.poppins(.regular, size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Vault Preview Card (page 2 on Android, page 2 on iOS)

struct VaultPreviewCard: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var docsVisible: [Bool] = [false, false, false, false]
    @State private var lockRotations: [Double] = [0, 0, 0, 0]
    @State private var shieldScale: CGFloat = 0.5
    @State private var shieldOpacity: Double = 0

    var body: some View {
        VStack(spacing: 8) {
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

            // Security badge
            HStack(spacing: 8) {
                Text("🛡️")
                    .font(.system(size: 16))
                    .scaleEffect(shieldScale)

                VStack(alignment: .leading, spacing: 1) {
                    Text("End-to-End Encrypted")
                        .font(.poppins(.semiBold, size: 11))
                        .foregroundColor(.primary)
                    Text("Only you and who you share with can access")
                        .font(.poppins(.regular, size: 9))
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
        .accessibilityLabel("Medical vault showing 4 encrypted documents")
        .onChange(of: isActive) { _, active in
            if active { startAnimations() } else { resetAnimations() }
        }
    }

    private func startAnimations() {
        guard !reduceMotion else {
            docsVisible = [true, true, true, true]
            lockRotations = [0, 0, 0, 0]
            shieldScale = 1.0; shieldOpacity = 1.0
            return
        }
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    docsVisible[i] = true
                }
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
                                .font(.poppins(.bold, size: 11))
                                .foregroundColor(.white)
                        } else {
                            Text(icon).font(.system(size: 16))
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins(.semiBold, size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.poppins(.regular, size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(AppColors.onboardingSkyBlue)
                .rotationEffect(.degrees(lockRotation))
        }
        .padding(10)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Activity Preview Card (kept for future use)

struct ActivityPreviewCard: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var stepProgress: CGFloat = 0
    @State private var stepCount: Int = 0
    @State private var distanceAnim: Double = 0
    @State private var caloriesAnim: Double = 0

    private let stepGoal = 10000
    private let stepTarget = 6840
    private let weekBars: [CGFloat] = [0.45, 0.72, 0.58, 0.91, 0.64, 0.48, 0.684]
    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    private let green = AppColors.accentGreen

    var body: some View {
        VStack(spacing: 16) {
            // Circular ring
            ZStack {
                Circle()
                    .stroke(green.opacity(0.15), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(stepCount)")
                        .font(.poppins(.bold, size: 22))
                        .foregroundColor(green)
                        .contentTransition(.numericText())
                    Text("/ 10,000")
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                    Text("steps")
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Weekly bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<days.count, id: \.self) { i in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i == days.count - 1 ? green : green.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: weekBars[i] * (isActive ? 36 : 0))
                        Text(days[i])
                            .font(.poppins(.regular, size: 8))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.8).delay(Double(i) * 0.08 + 0.3), value: isActive)
                }
            }
            .frame(height: 48)

            // Stats row
            HStack {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f km", distanceAnim))
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(green)
                    Text("Distance")
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                }
                Divider().frame(height: 32)
                VStack(spacing: 2) {
                    Text("\(Int(caloriesAnim)) kcal")
                        .font(.poppins(.bold, size: 16))
                        .foregroundColor(green)
                    Text("Calories")
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onboardingCard()
        .onChange(of: isActive) { _, active in
            if active { startAnimations() } else { resetAnimations() }
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.2).delay(0.1)) {
            stepProgress = CGFloat(stepTarget) / CGFloat(stepGoal)
        }
        withAnimation(.easeOut(duration: 1.2).delay(0.1)) {
            stepCount = stepTarget
        }
        withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
            distanceAnim = 4.2
            caloriesAnim = 312
        }
    }

    private func resetAnimations() {
        stepProgress = 0
        stepCount = 0
        distanceAnim = 0
        caloriesAnim = 0
    }
}
