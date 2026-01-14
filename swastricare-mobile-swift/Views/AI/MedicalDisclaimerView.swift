//
//  MedicalDisclaimerView.swift
//  swastricare-mobile-swift
//
//  Medical AI Disclaimer and Consent View
//

import SwiftUI

// MARK: - Medical Disclaimer Sheet

struct MedicalDisclaimerView: View {
    let onAcknowledge: () -> Void
    let onCancel: () -> Void
    
    @State private var hasScrolledToBottom = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Icon
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "2E3192").opacity(0.2), Color(hex: "4A90E2").opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "2E3192"))
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    // Title
                    Text("Medical AI Assistant")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    // Subtitle
                    Text("Please read and acknowledge the following before using medical AI features")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                    
                    // Disclaimer Sections
                    disclaimerSection(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Not Medical Advice",
                        content: "Information provided by Swastrica Medical AI is for educational and informational purposes only. It is NOT a substitute for professional medical advice, diagnosis, or treatment."
                    )
                    
                    disclaimerSection(
                        icon: "person.fill.checkmark",
                        iconColor: Color(hex: "2E3192"),
                        title: "Consult Healthcare Providers",
                        content: "Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay seeking it."
                    )
                    
                    disclaimerSection(
                        icon: "phone.fill",
                        iconColor: .red,
                        title: "Emergency Situations",
                        content: "If you think you may have a medical emergency, call your doctor, go to the emergency department, or call emergency services (911) immediately. Do not rely on AI for emergency medical decisions."
                    )
                    
                    disclaimerSection(
                        icon: "lock.shield.fill",
                        iconColor: .green,
                        title: "Privacy & Data",
                        content: "Your health queries are processed securely. We do not share your medical conversations with third parties. Your data is used only to improve your experience."
                    )
                    
                    disclaimerSection(
                        icon: "brain.head.profile",
                        iconColor: Color(hex: "4A90E2"),
                        title: "AI Limitations",
                        content: "AI can make mistakes. Medical AI cannot examine you physically, run tests, or access your complete medical history. Always verify important health information with a qualified professional."
                    )
                    
                    // Spacer for scroll detection
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            hasScrolledToBottom = true
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120) // Space for buttons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .overlay(alignment: .bottom) {
                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: onAcknowledge) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("I Understand & Agree")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    Text("By continuing, you acknowledge these limitations")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private func disclaimerSection(icon: String, iconColor: Color, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(content)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Emergency Alert View

struct EmergencyAlertView: View {
    let onDismiss: () -> Void
    let onCallEmergency: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Warning Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            
            Text("Emergency Detected")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text("If you or someone else is experiencing a medical emergency, please seek immediate professional help.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Call Emergency Button
                Button(action: onCallEmergency) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Call Emergency Services")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                // Emergency Numbers
                VStack(spacing: 8) {
                    emergencyNumber(country: "🇺🇸 USA", number: "911")
                    emergencyNumber(country: "🇮🇳 India", number: "108")
                    emergencyNumber(country: "🇪🇺 Europe", number: "112")
                    emergencyNumber(country: "🇬🇧 UK", number: "999")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Dismiss Button
                Button(action: onDismiss) {
                    Text("This is not an emergency")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
    }
    
    private func emergencyNumber(country: String, number: String) -> some View {
        HStack {
            Text(country)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: {
                if let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "2E3192"))
            }
        }
    }
}

// MARK: - Medical AI Badge

struct MedicalAIBadge: View {
    let isActive: Bool
    
    var body: some View {
        if isActive {
            HStack(spacing: 4) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 10))
                Text("Medical AI")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Medical Disclaimer Banner

struct MedicalDisclaimerBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "2E3192"))
            
            Text("Medical AI responses are for informational purposes only")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "2E3192").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    MedicalDisclaimerView(
        onAcknowledge: {},
        onCancel: {}
    )
}

#Preview("Emergency Alert") {
    EmergencyAlertView(
        onDismiss: {},
        onCallEmergency: {}
    )
}
