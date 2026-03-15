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

    var body: some View {
        VStack(spacing: 12) {
            // Family member header
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [AppColors.accentBlue, AppColors.onboardingPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay(Text("👩").font(.system(size: 18)))
                    .shadow(color: AppColors.accentBlue.opacity(0.25), radius: 6, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Amma")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Last updated 2m ago")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("All Good")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "16A34A"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "DCFCE7"))
                    .clipShape(Capsule())
                    .scaleEffect(badgePulse ? 1.06 : 1.0)
                    .accessibilityLabel("Status: All Good")
            }

            // Stats row
            HStack(spacing: 6) {
                StatCell(label: "Blood Pressure", value: "120/80", detail: "Normal", detailColor: AppColors.accentGreen)
                StatCell(label: "Medications", value: "2/2 ✓", detail: "On track", detailColor: AppColors.accentGreen)
                StatCell(label: "Hydration", value: "1.5L", detail: "60%", detailColor: .orange)
            }

            // Step count row
            HStack(spacing: 6) {
                Text("👣")
                    .font(.system(size: 13))
                Text("4,532 steps today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.accentGreen)
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
            }
            .padding(10)
            .background(AppColors.accentRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Family health dashboard showing Amma's blood pressure at 120 over 80, medications on track, 4532 steps today, and an alert for Appa's missed medication")
        .onChange(of: isActive) { _, active in
            guard !reduceMotion else { return }
            if active {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    alertPulse = true
                }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) {
                    badgePulse = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    alertPulse = false
                    badgePulse = false
                }
            }
        }
    }
}

// MARK: - Stat Cell (reused within FamilyPreviewCard)

private struct StatCell: View {
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
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
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
    var body: some View {
        VStack(spacing: 10) {
            // User message
            HStack {
                Spacer()
                Text("My sugar level is 180 after food. Is that normal?")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
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
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [AppColors.onboardingPurple, AppColors.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                        .overlay(Text("✦").font(.system(size: 12)).foregroundColor(.white))

                    Text("Swastri AI")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(AppColors.onboardingPurple)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("**180 mg/dL post-meal is slightly high.** Normal post-meal is below 140. Consult your doctor if this persists.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineSpacing(3)

                    HStack(spacing: 4) {
                        Text("Recommendation:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.onboardingPurple)
                        Text("Monitor daily for a week.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Quick suggestion pills
            HStack(spacing: 6) {
                SuggestionPill(text: "What foods reduce BP?", color: AppColors.onboardingPurple)
                SuggestionPill(text: "When to see a doctor?", color: AppColors.onboardingPurple)
                SuggestionPill(text: "Sugar control tips", color: AppColors.onboardingPurple)
                Spacer()
            }
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI health chat showing a question about post-meal blood sugar at 180 mg/dL and a helpful medical response with follow-up suggestions")
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

    /// Only shimmer when active and motion is allowed
    private var shouldShimmer: Bool {
        isActive && !reduceMotion
    }

    var body: some View {
        VStack(spacing: 8) {
            DocumentRow(
                icon: "PDF",
                iconGradient: [AppColors.accentRed, Color(hex: "DC2626")],
                iconIsText: true,
                title: "Blood Report — SRL Diagnostics",
                subtitle: "Mar 2026 · CBC, Lipid, Thyroid"
            )
            DocumentRow(
                icon: "🩻",
                iconGradient: [AppColors.onboardingSkyBlue, Color(hex: "0284C7")],
                iconIsText: false,
                title: "X-Ray — Apollo Hospital",
                subtitle: "Feb 2026 · Chest X-Ray"
            )
            DocumentRow(
                icon: "💊",
                iconGradient: [AppColors.accentGreen, Color(hex: "16A34A")],
                iconIsText: false,
                title: "Prescription — Dr. Sharma",
                subtitle: "Jan 2026 · Diabetes Management"
            )
            DocumentRow(
                icon: "scan",
                iconGradient: [AppColors.onboardingPurple, Color(hex: "6D28D9")],
                iconIsText: false,
                isSFSymbol: true,
                sfSymbolName: "waveform.path.ecg.rectangle",
                title: "MRI — Manipal Hospital",
                subtitle: "Dec 2025 · Brain MRI"
            )

            // Security badge
            HStack(spacing: 8) {
                Text("🛡️").font(.system(size: 16))

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
            .modifier(ConditionalShimmer(active: shouldShimmer))
        }
        .onboardingCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Medical vault showing blood report from SRL Diagnostics, X-ray from Apollo Hospital, prescription from Dr. Sharma, and MRI from Manipal Hospital, all end-to-end encrypted")
    }
}

private struct DocumentRow: View {
    let icon: String
    let iconGradient: [Color]
    let iconIsText: Bool
    var isSFSymbol: Bool = false
    var sfSymbolName: String = ""
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .overlay(
                    Group {
                        if isSFSymbol {
                            Image(systemName: sfSymbolName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        } else if iconIsText {
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
