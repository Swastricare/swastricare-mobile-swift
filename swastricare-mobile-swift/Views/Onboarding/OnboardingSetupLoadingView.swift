//
//  OnboardingSetupLoadingView.swift
//  swastricare-mobile-swift
//
//  Setting Up Loading Screen After Onboarding Questions
//

import SwiftUI

struct OnboardingSetupLoadingView: View {
    let onComplete: () -> Void
    let saveAction: () async throws -> Void
    
    @State private var progress: Double = 0
    @State private var currentStep: String = "Setting up your profile..."
    @State private var hasError = false
    @State private var errorMessage: String?
    
    private let steps = [
        "Setting up your profile...",
        "Saving your health data...",
        "Configuring your dashboard...",
        "Almost done..."
    ]
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "2E3192").opacity(0.2), Color(hex: "4A90E2").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "2E3192"))
                        .symbolEffect(.pulse, options: .repeating)
                }
                
                // Progress Text
                VStack(spacing: 12) {
                    Text(currentStep)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: currentStep)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                
                // Linear Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // Progress Fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                            .animation(.linear(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .task {
            await simulateProgress()
        }
    }
    
    private func simulateProgress() async {
        // Start saving in background
        let saveTask = Task {
            do {
                try await saveAction()
            } catch {
                await MainActor.run {
                    hasError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        // Simulate progress steps while saving
        for (index, step) in steps.enumerated() {
            await MainActor.run {
                currentStep = step
                progress = Double(index + 1) / Double(steps.count)
            }
            
            // Wait a bit for each step
            try? await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds per step
            
            // On step 2 (Saving your health data), ensure save is progressing
            if index == 1 {
                // Check if save completed or wait a bit more
                _ = try? await saveTask.value
            }
        }
        
        // Ensure save is complete before finishing
        do {
            try await saveTask.value
        } catch {
            // Error already handled above
        }
        
        // Small delay before completion
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        await MainActor.run {
            if !hasError {
                onComplete()
            }
        }
    }
}

#Preview {
    OnboardingSetupLoadingView(
        onComplete: {},
        saveAction: {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    )
}
