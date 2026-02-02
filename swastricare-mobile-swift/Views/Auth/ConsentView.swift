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
                AppAnalyticsService.shared.logConsentAccepted()
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
                                title: "Service Description",
                                content: "Swastricare provides health tracking, medication reminders, AI-powered insights (including image analysis for meals, workouts, and supplements), secure document storage, and heart rate measurement using your device camera. We may modify or discontinue the service at any time."
                            )
                            
                            termsSection(
                                number: "2",
                                title: "Medical Disclaimer",
                                content: "The information provided is for general purposes only and is not medical advice. AI-generated insights (including chat responses, health analysis, image analysis, and text generation) are for informational purposes only and should not replace professional medical advice. Always consult with your physician for medical concerns and before making health decisions. We are not responsible for the accuracy of AI-generated insights or any health decisions made based on them."
                            )
                            
                            termsSection(
                                number: "3",
                                title: "AI Features & Third-Party Services",
                                content: "By using our AI features (chat assistant, health analysis, image analysis, text generation), you consent to your data being processed by Google Gemini API. This includes: chat messages and conversation history, health metrics (steps, heart rate, sleep, calories, etc.), and images. Your data is processed according to Google's privacy policy and terms of service. We are not responsible for the accuracy, reliability, or appropriateness of AI-generated responses or insights. AI responses may contain errors or be unsuitable for your specific situation."
                            )
                            
                            termsSection(
                                number: "4",
                                title: "User Responsibilities",
                                content: "You are responsible for maintaining account security and using the app lawfully. Do not use the app for illegal or unauthorized purposes. You are responsible for ensuring you have the right to upload any images or documents, and that they do not violate any laws or third-party rights."
                            )
                            
                            termsSection(
                                number: "5",
                                title: "Limitation of Liability",
                                content: "Swastricare is not liable for indirect, incidental, or consequential damages. We do not guarantee the accuracy of all information in the app, including AI-generated insights. We are not liable for any health decisions made based on information provided by the app."
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
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.system(size: 16, weight: .semibold))
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(3)
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
                        
                        // Sections
                        Group {
                            privacySection(
                                icon: "person.text.rectangle",
                                title: "Information We Collect",
                                items: [
                                    "Personal information (name, email) when you create an account",
                                    "Health profile information (name, gender, date of birth, height, weight, blood type)",
                                    "Health data from Apple HealthKit (with your permission) - We READ: activity data (steps, exercise time, distance, calories, stand hours), vital signs (heart rate, blood pressure), body measurements (weight), sleep data, and hydration data. We WRITE: heart rate measurements from our camera-based detector and water intake data you log in the app",
                                    "Location data: We access your location to fetch local weather data to personalize your daily hydration goals based on temperature and climate conditions",
                                    "Images from your photo library for medical document storage",
                                    "Images captured via camera for heart rate measurement",
                                    "Images analyzed using AI for meal, workout, and supplement insights",
                                    "Audio/voice recordings for AI Assistant voice input (with your permission)",
                                    "Documents and images you store in the secure vault",
                                    "Medication and hydration data you enter"
                                ]
                            )
                            
                            privacySection(
                                icon: "photo.fill",
                                title: "Image Collection & Analysis",
                                items: [
                                    "Photo Library: We access your photo library to upload medical documents and images to your secure vault",
                                    "Camera: We use your device camera to detect blood flow through your fingertip for heart rate measurement. Camera frames are processed locally and not stored",
                                    "AI Image Analysis: Images you upload for meal, workout, or supplement analysis are processed using Google Gemini Vision API. Images are sent to Google for analysis, and results are stored securely in our database",
                                    "Document Storage: Images and documents you upload to the medical vault are stored securely in our encrypted storage system"
                                ]
                            )
                            
                            privacySection(
                                icon: "sparkles",
                                title: "AI Features & Data Processing",
                                items: [
                                    "AI Chat Assistant: Your chat messages and conversation history are sent to Google Gemini API to generate responses. Conversations are stored in our database for context and improvement",
                                    "AI Health Analysis: Your health metrics (steps, heart rate, sleep, calories, exercise, blood pressure, weight) are sent to Google Gemini API for analysis and personalized insights. Analysis results are stored securely",
                                    "AI Image Analysis: Images for meal, workout, and supplement analysis are sent to Google Gemini Vision API. Analysis results are stored in our database",
                                    "AI Text Generation: Your health data may be sent to Google Gemini API to generate daily summaries, weekly reports, and goal suggestions. Generated content is stored securely",
                                    "All AI processing is performed by Google Gemini API. Your data is processed according to Google's privacy policy and terms of service",
                                    "AI-generated insights are for informational purposes only and should not replace professional medical advice"
                                ]
                            )
                            
                            privacySection(
                                icon: "gearshape.2",
                                title: "How We Use Your Information",
                                items: [
                                    "Provide personalized health insights and recommendations using AI",
                                    "Analyze images for meal nutrition, workout form, and supplement information using AI",
                                    "Generate health summaries, reports, and goal suggestions using AI",
                                    "Process chat conversations to provide AI-powered health assistance",
                                    "Improve our AI health assistant based on usage patterns",
                                    "Sync your data securely across devices",
                                    "Provide medication reminders and hydration tracking"
                                ]
                            )
                            
                            privacySection(
                                icon: "heart.text.square.fill",
                                title: "Apple HealthKit Integration",
                                items: [
                                    "We READ health data: steps, exercise time, distance, calories burned, stand hours, heart rate, blood pressure, weight, sleep data, and water intake from your Apple HealthKit",
                                    "We WRITE health data: heart rate measurements taken with our camera-based detector and water intake data you log in the app are saved to your Apple HealthKit",
                                    "All HealthKit access requires your explicit permission through iOS system prompts",
                                    "You can revoke HealthKit access at any time through iOS Settings > Privacy & Security > Health > Swastricare",
                                    "HealthKit data syncing is optional and can be disabled in app settings"
                                ]
                            )
                            
                            privacySection(
                                icon: "building.2",
                                title: "Third-Party Services",
                                items: [
                                    "Google Gemini API: Processes your chat messages, health metrics, and images using AI to provide health insights, analysis, and recommendations. Models used: Gemini 3 Flash Preview (chat & health analysis), Gemini 1.5 Flash (image analysis), Gemini Pro (text generation)",
                                    "Supabase: Provides secure cloud storage and database services for your health data, documents, and app data",
                                    "Apple HealthKit: Provides secure access to health data stored on your device (with your explicit permission). Data stays on your device and is only accessed with your consent"
                                ]
                            )
                            
                            privacySection(
                                icon: "lock.fill",
                                title: "Data Security",
                                items: [
                                    "All data is encrypted in transit and at rest",
                                    "Biometric authentication protects sensitive features",
                                    "Industry-standard security protocols",
                                    "Images sent to third-party services are processed securely and in accordance with their privacy policies"
                                ]
                            )
                            
                            privacySection(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Data Sharing",
                                items: [
                                    "We never sell your personal data",
                                    "Health data is not shared with advertisers",
                                    "Data is shared with service providers under strict contracts and privacy agreements:",
                                    "  • Google Gemini API: Processes chat messages, health metrics, and images for AI-powered insights and analysis",
                                    "  • Supabase: Provides secure cloud storage and database services for your health data and documents",
                                    "All third-party services are required to maintain data confidentiality and security",
                                    "Your conversations, health metrics, and images sent to Google Gemini are processed according to Google's privacy policy"
                                ]
                            )
                            
                            privacySection(
                                icon: "hand.point.up.braille",
                                title: "Your Rights",
                                items: [
                                    "Access and download your data",
                                    "Request account and data deletion",
                                    "Update or correct your information anytime",
                                    "Withdraw consent for data processing",
                                    "Request information about what data we have collected about you"
                                ]
                            )
                            
                            privacySection(
                                icon: "envelope",
                                title: "Contact Us",
                                items: [
                                    "Privacy concerns: privacy@swastricare.com",
                                    "Support: support@swastricare.com"
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
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
