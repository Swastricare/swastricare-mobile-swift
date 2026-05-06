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
                                        colors: [AppColors.aiTeal.opacity(0.2), Color(hex: "4A90E2").opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "cross.case.fill")
                                .font(.poppins(.regular, size: 36))
                                .foregroundColor(AppColors.aiTeal)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    // Title
                    Text("Medical AI Assistant")
                        .font(.poppins(.bold, size: 24))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Subtitle
                    Text("Please read and acknowledge the following before using medical AI features")
                        .font(.poppins(.regular, size: 15))
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
                        iconColor: AppColors.aiTeal,
                        title: "Consult Healthcare Providers",
                        content: "Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay seeking it."
                    )
                    
                    disclaimerSection(
                        icon: "phone.fill",
                        iconColor: .red,
                        title: "Emergency Situations",
                        content: "If you think you may have a medical emergency, call your doctor, go to the emergency department, or call emergency services immediately. Do not rely on AI for emergency medical decisions."
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
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppColors.aiTeal, Color(hex: "4A90E2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    Text("By continuing, you acknowledge these limitations")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
        }
        .trackScreen("MedicalDisclaimer")
    }

    private func disclaimerSection(icon: String, iconColor: Color, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.poppins(.regular, size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.primary)

                Text(content)
                    .font(.poppins(.regular, size: 14))
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
                    .font(.poppins(.regular, size: 40))
                    .foregroundColor(.red)
            }

            Text("Emergency Detected")
                .font(.poppins(.bold, size: 22))
                .foregroundColor(.primary)

            Text("If you or someone else is experiencing a medical emergency, please seek immediate professional help.")
                .font(.poppins(.regular, size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Emergency Numbers
                VStack(spacing: 8) {
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
                        .font(.poppins(.regular, size: 15))
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
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: {
                if let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(number)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(AppColors.aiTeal)
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
                    .font(.poppins(.regular, size: 10))
                Text("Medical AI")
                    .font(.poppins(.medium, size: 10))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [AppColors.aiTeal, Color(hex: "4A90E2")],
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
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner content
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "info.circle.fill" : "info.circle")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(AppColors.aiTeal)

                    if isExpanded {
                        Text("Medical AI responses are for informational purposes only")
                            .font(.poppins(.regular, size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Medical disclaimer")
                            .font(.poppins(.medium, size: 11))
                            .foregroundColor(AppColors.aiTeal)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.poppins(.semiBold, size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(AppColors.aiTeal.opacity(isExpanded ? 0.08 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.poppins(.regular, size: 10))
                            .foregroundColor(.orange)
                        Text("Always consult healthcare professionals for medical advice")
                            .font(.poppins(.regular, size: 10))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.aiTeal.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .onAppear {
            // Auto-collapse after 3 seconds on first show
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if isExpanded && !UserDefaults.standard.bool(forKey: "ai_medical_banner_interacted") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                }
            }
        }
        .onChange(of: isExpanded) { _, _ in
            // Mark as interacted so it doesn't auto-collapse again
            UserDefaults.standard.set(true, forKey: "ai_medical_banner_interacted")
        }
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
