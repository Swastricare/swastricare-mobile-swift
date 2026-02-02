//
//  HeartRateDisclaimerView.swift
//  swastricare-mobile-swift
//
//  Disclaimer sheet shown before first heart rate measurement
//

import SwiftUI

struct HeartRateDisclaimerView: View {
    let onAccept: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Icon
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.red)
                        .padding(.top, 16)
                        .accessibilityHidden(true)
                    
                    // Title
                    VStack(spacing: 6) {
                        Text("Important Notice")
                            .font(.title3.bold())
                        
                        Text("Please read carefully before proceeding")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Disclaimer Cards
                    VStack(spacing: 12) {
                        disclaimerCard(
                            icon: "info.circle.fill",
                            title: "Wellness Only",
                            text: "This feature is for informational purposes only and is not a medical device.",
                            color: .blue
                        )
                        
                        disclaimerCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Not Medical Advice",
                            text: "Do not use this for diagnosis or treatment. Always consult a healthcare professional.",
                            color: .orange
                        )
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Measure")
                            .font(.subheadline.weight(.semibold))
                        
                        VStack(spacing: 0) {
                            instructionRow(step: "1", text: "Place finger gently on the back camera")
                            Divider()
                            instructionRow(step: "2", text: "Ensure the camera and flash are covered")
                            Divider()
                            instructionRow(step: "3", text: "Stay still during measurement")
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    // Accept Button
                    Button(action: onAccept) {
                        Text("I Understand & Agree")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(25)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .accessibilityLabel("I understand and agree to the terms")
                }
                .padding(.horizontal, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
    
    // MARK: - Subviews
    
    private func disclaimerCard(icon: String, title: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.red))
                .accessibilityLabel("Step \(step)")
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HeartRateDisclaimerView(onAccept: {})
}
