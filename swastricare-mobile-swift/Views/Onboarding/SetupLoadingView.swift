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
    
    @Environment(\.dismiss) private var dismiss
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
    
    private let darkText = Color(hex: "0F172A")
    private let mutedText = Color(hex: "6B7280")
    private let cardBg = Color(hex: "F0FBF8")

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image.androidImage("setting up screen illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                Text(currentStep.replacingOccurrences(of: "...", with: ""))
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(darkText)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)

                Spacer().frame(height: 8)

                Text("Please wait...")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(mutedText)

                Spacer().frame(height: 28)

                // Progress bar with trailing percentage
                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: "E5E7EB")).frame(height: 6)
                            Capsule()
                                .fill(AppColors.aiTeal)
                                .frame(width: max(0, geo.size.width * progress), height: 6)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)

                    Text("\(Int(progress * 100))%")
                        .font(.poppins(.semiBold, size: 13))
                        .foregroundColor(AppColors.aiTeal)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 28)

                // Data safe badge
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.aiTeal)
                            .frame(width: 36, height: 36)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your data is safe")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(darkText)
                        Text("We're securely personalising your experience for better health insights.")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(mutedText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 24)
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
                    
                    // Call onComplete - parent view will handle dismissal
                    // The questionnaire view is already hidden when showSetup is true
                    await MainActor.run {
                        onComplete()
                    }
                } catch {
                    // Handle error - show it but still complete
                    print("❌ SetupLoadingView: Error saving health profile: \(error)")
                    
                    // Still mark as completed to not block user
                    UserDefaults.standard.set(true, forKey: "hasCompletedHealthProfile")
                    hasCompleted = true
                    
                    // Call onComplete - parent view will handle dismissal
                    // The questionnaire view is already hidden when showSetup is true
                    await MainActor.run {
                        onComplete()
                    }
                }
            }
        }
    }
}
