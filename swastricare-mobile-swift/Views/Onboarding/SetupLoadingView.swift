//
//  SetupLoadingView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct SetupLoadingView: View {
    let formState: HealthProfileFormState
    let onComplete: () -> Void
    
    private let service = HealthProfileService.shared
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @State private var progress: Double = 0
    @State private var currentStep: String = "Setting up your profile..."
    @State private var hasCompleted = false
    
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
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                            .cornerRadius(4)
                            .animation(.linear(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .task {
            await setupProfile()
        }
    }
    
    private func setupProfile() async {
        // Simulate progress steps
        for (index, step) in steps.enumerated() {
            currentStep = step
            progress = Double(index + 1) / Double(steps.count)
            
            // Wait a bit for each step
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            // On last step, save to Supabase
            if index == steps.count - 1 {
                do {
                    // Get user ID from auth
                    guard let userIdString = authViewModel.currentUser?.id,
                          let userId = UUID(uuidString: userIdString) else {
                        print("❌ SetupLoadingView: No user ID found")
                        throw HealthProfileError.notAuthenticated
                    }
                    
                    print("📋 SetupLoadingView: Saving profile for user \(userId)")
                    print("📋 Form data - Name: \(formState.name), Gender: \(formState.gender?.rawValue ?? "nil")")
                    
                    // Create health profile with actual user ID
                    let healthProfile = formState.toHealthProfile(userId: userId)
                    try await service.saveHealthProfile(healthProfile)
                    
                    print("✅ SetupLoadingView: Profile saved successfully!")
                    
                    // Mark as completed in UserDefaults
                    UserDefaults.standard.set(true, forKey: "hasCompletedHealthProfile")
                    
                    // Refresh the auth profile
                    await authViewModel.fetchHealthProfile()
                    
                    // Small delay before completion
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    hasCompleted = true
                    onComplete()
                } catch {
                    // Handle error - show it but still complete
                    print("❌ SetupLoadingView: Error saving health profile: \(error)")
                    
                    // Still mark as completed to not block user
                    UserDefaults.standard.set(true, forKey: "hasCompletedHealthProfile")
                    hasCompleted = true
                    onComplete()
                }
            }
        }
    }
}
