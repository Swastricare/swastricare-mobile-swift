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
                VStack(spacing: 24) {
                    // Header Icon
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 20)
                        .accessibilityHidden(true)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Important Notice")
                            .font(.title2.bold())
                        
                        Text("Please read carefully before proceeding")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Disclaimer Cards
                    VStack(spacing: 16) {
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to Measure")
                            .font(.headline)
                        
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
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.red)
                            .cornerRadius(28)
                    }
                    .padding(.vertical, 20)
                    .accessibilityLabel("I understand and agree to the terms")
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
    
    // MARK: - Subviews
    
    private func disclaimerCard(icon: String, title: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(spacing: 16) {
            Text(step)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.secondary))
                .accessibilityLabel("Step \(step)")
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HeartRateDisclaimerView(onAccept: {})
}
