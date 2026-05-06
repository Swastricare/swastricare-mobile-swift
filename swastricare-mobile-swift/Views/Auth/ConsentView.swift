//
//  ConsentView.swift
//  swastricare-mobile-swift
//
//  Redesigned to pixel-match Android ConsentScreen.kt
//  • Pure white background
//  • terms and condition icon hero image
//  • Single agreed toggle (not three separate cards)
//  • AITeal gradient CTA
//

import SwiftUI

private let consentDarkText  = Color(hex: "0F172A")
private let consentMutedText = Color(hex: "6B7280")
private let consentSubtleBorder = Color.black.opacity(0.06)

struct ConsentView: View {

    @Binding var hasAcceptedConsent: Bool

    // MARK: - State

    @State private var agreed = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    @State private var checkScale: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Hero illustration
                Image.androidImage("terms and condition icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Spacer().frame(height: 8)

                // Title
                Text("Terms & Conditions")
                    .font(.poppins(.bold, size: 26))
                    .foregroundColor(consentDarkText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 6)

                // Subtitle with teal brand name
                (
                    Text("Please read and accept the terms to continue using ")
                        .foregroundColor(consentMutedText)
                    + Text("Swastricare")
                        .foregroundColor(AppColors.aiTeal)
                        .fontWeight(.semibold)
                    + Text(".")
                        .foregroundColor(consentMutedText)
                )
                .font(.poppins(.regular, size: 13))
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Consent list items
                VStack(spacing: 10) {
                    ConsentListItem(
                        systemIcon: "shield.fill",
                        title: "Privacy Policy",
                        description: "Learn how we collect, use and protect your data.",
                        onTap: { showPrivacySheet = true }
                    )
                    ConsentListItem(
                        systemIcon: "doc.text.fill",
                        title: "Terms of Use",
                        description: "Understand the rules and guidelines for using our app.",
                        onTap: { showTermsSheet = true }
                    )
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 18)

                // Agreement row
                AgreementRow(
                    checked: agreed,
                    checkScale: checkScale,
                    onToggle: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            agreed.toggle()
                            if agreed {
                                checkScale = 1.2
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        checkScale = 1.0
                                    }
                                }
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    onTermsClick: { showTermsSheet = true },
                    onPrivacyClick: { showPrivacySheet = true }
                )
                .padding(.horizontal, 20)

                Spacer().frame(height: 14)

                // Accept & Continue button
                AcceptContinueButton(enabled: agreed) {
                    UserDefaults.standard.set(true, forKey: AppConfig.hasAcceptedConsentKey)
                    AppAnalyticsService.shared.logConsentAccepted()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasAcceptedConsent = true
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 10)

                // Security note
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(consentMutedText)
                    Text("Your data is safe with us")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(consentMutedText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsContentView()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyContentView()
        }
        .trackScreen("Consent")
    }
}

// MARK: - Consent List Item

private struct ConsentListItem: View {
    let systemIcon: String
    let title: String
    let description: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.aiTeal.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: systemIcon)
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.aiTeal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.poppins(.semiBold, size: 14))
                        .foregroundColor(consentDarkText)
                    Text(description)
                        .font(.poppins(.regular, size: 11))
                        .foregroundColor(consentMutedText)
                        .lineSpacing(3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(consentMutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(consentSubtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Agreement Row

private struct AgreementRow: View {
    let checked: Bool
    let checkScale: CGFloat
    let onToggle: () -> Void
    let onTermsClick: () -> Void
    let onPrivacyClick: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 10) {
                // Custom checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(checked ? AppColors.aiTeal : Color.clear)
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            checked ? AppColors.aiTeal : consentMutedText.opacity(0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkScale)
                    }
                }

                // Annotated text
                (
                    Text("I have read and agree to the ")
                        .foregroundColor(consentDarkText)
                    + Text("Terms of Use")
                        .foregroundColor(AppColors.aiTeal)
                        .fontWeight(.semibold)
                    + Text("\nand ")
                        .foregroundColor(consentDarkText)
                    + Text("Privacy Policy")
                        .foregroundColor(AppColors.aiTeal)
                        .fontWeight(.semibold)
                )
                .font(.poppins(.regular, size: 13))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Accept & Continue Button

private struct AcceptContinueButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                Text("Accept & Continue")
                    .font(.poppins(.bold, size: 16))
                    .foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(enabled ? AppColors.aiTeal : Color.gray.opacity(0.3))
            .clipShape(Capsule())
            .shadow(
                color: enabled ? AppColors.aiTeal.opacity(0.35) : .clear,
                radius: 12, y: 6
            )
        }
        .disabled(!enabled)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Terms Content View

struct TermsContentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Close button
                        HStack {
                            Text("Terms of Service")
                                .font(.poppins(.bold, size: 22))
                                .foregroundColor(consentDarkText)
                            Spacer()
                        }
                        .padding(.top, 8)

                        Text(termsText)
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(consentDarkText.opacity(0.8))
                            .lineSpacing(5)

                        Spacer().frame(height: 16)

                        Button(action: { dismiss() }) {
                            Text("Close")
                                .font(.poppins(.semiBold, size: 15))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.aiTeal)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private let termsText = """
SwastriCare Terms of Service

Last updated: April 2026

1. ACCEPTANCE OF TERMS
By downloading, installing, or using SwastriCare, you agree to these Terms of Service.

2. USE OF SERVICE
SwastriCare is a personal health tracking app. You must be at least 13 years old to use this app. You are responsible for maintaining the confidentiality of your account.

3. HEALTH DISCLAIMER
SwastriCare provides general health information and tracking tools only. It is NOT a medical device and should NOT be used for medical diagnosis or treatment. Always consult a qualified healthcare professional for medical advice.

4. AI FEATURES
Swastri AI provides health insights using AI models. These are for informational purposes only and may not always be accurate. Never make medical decisions based solely on AI suggestions.

5. USER DATA
You retain ownership of all health data you enter. We process your data as described in our Privacy Policy.

6. TERMINATION
We may suspend or terminate your account for violation of these terms. You may delete your account at any time from Profile settings.
"""
}

// MARK: - Privacy Content View

struct PrivacyContentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Privacy Policy")
                                .font(.poppins(.bold, size: 22))
                                .foregroundColor(consentDarkText)
                            Spacer()
                        }
                        .padding(.top, 8)

                        Text(privacyText)
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(consentDarkText.opacity(0.8))
                            .lineSpacing(5)

                        Spacer().frame(height: 16)

                        Button(action: { dismiss() }) {
                            Text("Close")
                                .font(.poppins(.semiBold, size: 15))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.aiTeal)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private let privacyText = """
SwastriCare Privacy Policy

Last updated: April 2026

DATA WE COLLECT
• Health data: steps, heart rate, calories, medication logs, diet entries, menstrual cycle data
• Profile data: name, date of birth, gender, height, weight, blood type
• Documents: medical records you upload to your Vault
• Usage data: app interactions for improving the experience

HOW WE USE YOUR DATA
• To display your health dashboard and trends
• To power Swastri AI health insights (processed by Google Gemini/MedGemma)
• To sync data across your devices via Supabase

DATA STORAGE
• All data is stored on Supabase servers (AWS ap-south-1 region, India)
• We comply with India's Digital Personal Data Protection Act (DPDPA) 2023
• Data is encrypted in transit and at rest

YOUR RIGHTS
• Access: View all your data in the app
• Delete: Delete your account and all data from Profile settings
• Export: Contact support for a data export
• Correction: Update your profile data at any time

THIRD PARTIES
• Google Gemini/MedGemma: processes AI queries (no data stored)
• Firebase: analytics and crash reporting
• HealthKit: syncs with iOS health data (with your permission)

CONTACT
For privacy concerns, contact: privacy@swastricare.com
"""
}

// MARK: - Preview

#Preview {
    ConsentView(hasAcceptedConsent: .constant(false))
}

#Preview("Terms") {
    TermsContentView()
}

#Preview("Privacy") {
    PrivacyContentView()
}
