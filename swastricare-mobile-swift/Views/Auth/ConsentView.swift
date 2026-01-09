//
//  ConsentView.swift
//  swastricare-mobile-swift
//
//  Terms & Conditions and Privacy Policy Consent Screen
//

import SwiftUI

struct ConsentView: View {
    
    @Binding var hasAcceptedConsent: Bool
    
    // MARK: - State
    
    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedDataProcessing = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    @State private var appearAnimation = false
    @State private var checkmarkScale: [Bool] = [false, false, false]
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var allAccepted: Bool {
        acceptedTerms && acceptedPrivacy && acceptedDataProcessing
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : -20)
                
                Spacer()
                    .frame(height: 32)
                
                // Consent Cards
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Terms Card
                        consentCard(
                            icon: "doc.text.fill",
                            iconGradient: PremiumColor.royalBlue,
                            title: "Terms of Service",
                            description: "I agree to the Terms of Service and conditions of using Swastricare",
                            isAccepted: $acceptedTerms,
                            index: 0,
                            onReadMore: { showTermsSheet = true }
                        )
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appearAnimation)
                        
                        // Privacy Card
                        consentCard(
                            icon: "lock.shield.fill",
                            iconGradient: PremiumColor.neonGreen,
                            title: "Privacy Policy",
                            description: "I have read and agree to the Privacy Policy regarding my personal data",
                            isAccepted: $acceptedPrivacy,
                            index: 1,
                            onReadMore: { showPrivacySheet = true }
                        )
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)
                        
                        // Data Processing Card
                        consentCard(
                            icon: "heart.text.square.fill",
                            iconGradient: PremiumColor.sunset,
                            title: "Health Data Processing",
                            description: "I consent to processing of my health data to provide personalized insights",
                            isAccepted: $acceptedDataProcessing,
                            index: 2,
                            onReadMore: nil
                        )
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Bottom Section
                bottomSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)
            }
        }
        .onAppear {
            withAnimation {
                appearAnimation = true
            }
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsContentView()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyContentView()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // Simple Icon
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(PremiumColor.royalBlue)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Before You Begin")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Please review and accept our policies")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Consent Card
    
    private func consentCard(
        icon: String,
        iconGradient: LinearGradient,
        title: String,
        description: String,
        isAccepted: Binding<Bool>,
        index: Int,
        onReadMore: (() -> Void)?
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAccepted.wrappedValue.toggle()
                if isAccepted.wrappedValue {
                    checkmarkScale[index] = true
                    // Reset for bounce effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            checkmarkScale[index] = false
                        }
                    }
                }
            }
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 16) {
                // Simple Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconGradient)
                    .frame(width: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let onReadMore = onReadMore {
                            Button {
                                onReadMore()
                            } label: {
                                Text("Read")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Simple Checkbox
                Image(systemName: isAccepted.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isAccepted.wrappedValue ? .accentColor : .secondary.opacity(0.3))
                    .scaleEffect(checkmarkScale[index] ? 1.2 : 1.0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // Improves tap area
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Divider
            Divider()
                .padding(.horizontal, 20)
            
            // Agree All Button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    let newValue = !allAccepted
                    acceptedTerms = newValue
                    acceptedPrivacy = newValue
                    acceptedDataProcessing = newValue
                    
                    if newValue {
                        for i in 0..<3 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                                checkmarkScale[i] = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        checkmarkScale[i] = false
                                    }
                                }
                            }
                        }
                    }
                }
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Text(allAccepted ? "Unselect All" : "Agree All")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.accentColor)
            }
            
            // Continue Button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Save consent acceptance
                    UserDefaults.standard.set(true, forKey: AppConfig.hasAcceptedConsentKey)
                    hasAcceptedConsent = true
                }
                // Success haptic
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        allAccepted ? Color.accentColor : Color.gray.opacity(0.3)
                    )
                    .cornerRadius(12)
            }
            .disabled(!allAccepted)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            // Disclaimer
            Text("You can withdraw consent anytime in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
        }
    }
}

// MARK: - Terms Content View

struct TermsContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(PremiumColor.royalBlue)
                                
                                Text("Terms of Service")
                                    .font(.system(size: 24, weight: .bold))
                            }
                            
                            Text("Last updated: January 2026")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        Divider()
                        
                        // Sections
                        Group {
                            termsSection(
                                number: "1",
                                title: "Acceptance of Terms",
                                content: """
                                By accessing or using Swastricare, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the application.
                                
                                These terms apply to all users of the app, including without limitation users who are browsers, customers, and contributors of content.
                                """
                            )
                            
                            termsSection(
                                number: "2",
                                title: "Description of Service",
                                content: """
                                Swastricare provides health tracking, medication reminders, AI-powered health insights, and secure document storage services. The app integrates with Apple HealthKit to provide comprehensive health monitoring.
                                
                                We reserve the right to modify or discontinue the service at any time without prior notice.
                                """
                            )
                            
                            termsSection(
                                number: "3",
                                title: "Medical Disclaimer",
                                content: """
                                The information provided by Swastricare is for general informational purposes only and should not be considered as medical advice.
                                
                                Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay seeking it because of something you have read in this app.
                                """
                            )
                            
                            termsSection(
                                number: "4",
                                title: "User Responsibilities",
                                content: """
                                You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.
                                
                                You must not use the app for any illegal or unauthorized purpose, nor may you violate any laws in your jurisdiction.
                                """
                            )
                            
                            termsSection(
                                number: "5",
                                title: "Intellectual Property",
                                content: """
                                All content, features, and functionality of Swastricare, including but not limited to text, graphics, logos, and software, are the exclusive property of Swastricare and are protected by international copyright, trademark, and other intellectual property laws.
                                """
                            )
                            
                            termsSection(
                                number: "6",
                                title: "Limitation of Liability",
                                content: """
                                Swastricare and its affiliates shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service.
                                
                                We do not guarantee the accuracy, completeness, or usefulness of any information in the app.
                                """
                            )
                            
                            termsSection(
                                number: "7",
                                title: "Governing Law",
                                content: """
                                These Terms shall be governed and construed in accordance with the laws of India, without regard to its conflict of law provisions.
                                
                                Any disputes arising under these terms will be resolved in the courts of India.
                                """
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func termsSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Privacy Content View

struct PrivacyContentView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(PremiumColor.neonGreen)
                                
                                Text("Privacy Policy")
                                    .font(.system(size: 24, weight: .bold))
                            }
                            
                            Text("Last updated: January 2026")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        Divider()
                        
                        // Privacy commitment card
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Privacy Matters")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("We are committed to protecting your personal health information.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Sections
                        Group {
                            privacySection(
                                icon: "person.text.rectangle",
                                title: "Information We Collect",
                                items: [
                                    "Personal information (name, email) when you create an account",
                                    "Health data from Apple HealthKit (with your explicit permission)",
                                    "Medication and hydration tracking data you enter",
                                    "Documents you choose to store in the secure vault"
                                ]
                            )
                            
                            privacySection(
                                icon: "gearshape.2",
                                title: "How We Use Your Information",
                                items: [
                                    "To provide personalized health insights and recommendations",
                                    "To send medication and hydration reminders",
                                    "To improve our AI health assistant's accuracy",
                                    "To sync your data securely across devices"
                                ]
                            )
                            
                            privacySection(
                                icon: "lock.fill",
                                title: "Data Security",
                                items: [
                                    "All data is encrypted in transit and at rest",
                                    "Biometric authentication protects sensitive features",
                                    "We use industry-standard security protocols",
                                    "Regular security audits and updates"
                                ]
                            )
                            
                            privacySection(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Data Sharing",
                                items: [
                                    "We never sell your personal data to third parties",
                                    "Health data is not shared with advertisers",
                                    "Data may be shared with service providers under strict contracts",
                                    "We may disclose data if required by law"
                                ]
                            )
                            
                            privacySection(
                                icon: "hand.point.up.braille",
                                title: "Your Rights",
                                items: [
                                    "Access and download your personal data",
                                    "Request deletion of your account and data",
                                    "Opt-out of non-essential data processing",
                                    "Update or correct your information anytime"
                                ]
                            )
                            
                            privacySection(
                                icon: "envelope",
                                title: "Contact Us",
                                items: [
                                    "For privacy concerns: privacy@swastricare.com",
                                    "For support: support@swastricare.com",
                                    "Response within 48 business hours"
                                ]
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func privacySection(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .padding(.top, 2)
                        
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 38)
        }
    }
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
