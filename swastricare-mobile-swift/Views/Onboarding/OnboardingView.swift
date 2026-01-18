//
//  OnboardingView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 06/01/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var buttonOpacity: Double = 0.0
    @State private var isAnimating: Bool = false
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var weightKg: Double = 70.0
    @State private var heightCm: Double = 170.0
    @State private var selectedGender: Gender?
    @State private var selectedTone: AITone?
    
    // Disable swipe on input pages to prevent accidental page changes
    private var isSwipeDisabled: Bool {
        currentPage >= 4 && currentPage <= 8
    }
    
    private var canProceedFromCurrentPage: Bool {
        switch currentPage {
        case 4:
            return dateOfBirth <= Date()
        case 5:
            return weightKg > 0
        case 6:
            return heightCm > 0
        case 7:
            return selectedGender != nil
        case 8:
            return selectedTone != nil
        default:
            return true
        }
    }
    
    private let totalPages = 9
    private let buttonWidth: CGFloat = 160
    private let buttonHeight: CGFloat = 54
    
    var body: some View {
        ZStack {
            // Background
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Skip Button - Top Right
                HStack {
                    Spacer()
                    Button(action: {
                        guard !isAnimating else { return }
                        completeOnboarding()
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                    .disabled(isAnimating)
                    .opacity(buttonOpacity)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                    .animation(.linear(duration: 0.3).delay(0.1), value: buttonOpacity)
                }
                
                // Page Content
                let deviceName = DeviceModelHelper.deviceModelName()
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        modelName: "intro",
                        title: "hi \n\ni'm swastica!",
                        subtitle: "the ai that learns you, to care for you.",
                        // subtext: "finally, one app for all your health needs"
                    )
                    .tag(0)
                    
                    OnboardingPageView(
                        modelName: "existing",
                        title: "are you an\nexisting user?",
                        // subtitle: "quick question"
                    ) {
                        HStack(spacing: 20) {
                            Button(action: {
                                // Existing user: exit onboarding and go to login flow
                                handleExistingUser()
                            }) {
                                Text("yes, i'm back")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 140)
                                    .frame(height: 50)
                                    .background(PremiumColor.royalBlue)
                                    .clipShape(Capsule())
                                    .shadow(color: PremiumColor.hex("2E3192").opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            
                            Button(action: {
                                // New user: continue to the 3rd page
                                withAnimation {
                                    currentPage = 2
                                }
                            }) {
                                Text("no, i'm new")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 140)
                                    .frame(height: 50)
                                    .liquidGlassCapsule()
                            }
                        }
                    }
                    .tag(1)
                    
                    OnboardingPageView(
                        modelName: "device",
                        title: "Personalized for your \(deviceName)",
                        subtitle: "Tuning your health experience for accurate insights",
                        subtext: "Sign in with Apple to start instantly on this device."
                    ) {
                        AuthSocialButton(icon: "apple.logo", title: "Sign in with Apple") {
                            Task {
                                await authViewModel.signInWithApple()
                                if authViewModel.isAuthenticated {
                                    withAnimation {
                                        currentPage = 3
                                    }
                                }
                            }
                        }
                    }
                    .tag(2)
                    
                    OnboardingPageView(
                        modelName: "doc",
                        title: "Track Your Health",
                        subtitle: "Monitor vitals, medications, and wellness in one place",
                        subtext: "Signed in as \(authViewModel.userName)\n\(authViewModel.userEmail ?? "Email not available")"
                    )
                    .tag(3)
                    
                    OnboardingPageView(
                        modelName: "cosmic",
                        title: "Mark Your Wellness Milestone",
                        subtitle: "Your birthday helps us craft insights that fit your era"
                    ) {
                        CreativeDatePicker(date: $dateOfBirth)
                            .padding(.horizontal, 24)
                    }
                    .tag(4)
                    
                    OnboardingPageView(
                        modelName: "liquid",
                        title: "Your Weight",
                        subtitle: "Used to tailor hydration and wellness guidance"
                    ) {
                        InteractiveRulerPicker(
                            value: $weightKg,
                            range: 30...200,
                            unit: "kg"
                        )
                        .padding(.horizontal, 24)
                    }
                    .tag(5)
                    
                    OnboardingPageView(
                        modelName: "spire",
                        title: "Your Height",
                        subtitle: "Improves accuracy for health and activity tracking"
                    ) {
                        InteractiveRulerPicker(
                            value: $heightCm,
                            range: 100...250,
                            unit: "cm"
                        )
                        .padding(.horizontal, 24)
                    }
                    .tag(6)
                    
                    OnboardingPageView(
                        modelName: "prism",
                        title: "How do you identify?",
                        subtitle: "This helps us personalize your health insights"
                    ) {
                        CreativeGenderPicker(selectedGender: $selectedGender)
                    }
                    .tag(7)
                    
                    OnboardingPageView(
                        modelName: "aura",
                        title: "Choose Your AI's Vibe",
                        subtitle: "How should Swastrica talk to you?"
                    ) {
                        AITonePicker(selectedTone: $selectedTone)
                    }
                    .tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.linear(duration: 0.3), value: currentPage)
                .disabled(isAnimating)
                .allowsHitTesting(!isAnimating)
                .gesture(isSwipeDisabled ? DragGesture() : nil)
                
                // Bottom Controls
                VStack(spacing: 24) {
                    // Page Indicator
                    HStack(spacing: 10) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.accentColor : Color.primary.opacity(0.3))
                                .frame(
                                    width: currentPage == index ? 24 : 8,
                                    height: 8
                                )
                                .animation(.linear(duration: 0.2), value: currentPage)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Centered Button
                    HStack {
                        Spacer()
                        
                        if currentPage < totalPages - 1 {
                            // Next Button - Centered
                            Button {
                                guard !isAnimating else { return }
                                guard canProceedFromCurrentPage else { return }
                                isAnimating = true
                                withAnimation(.linear(duration: 0.3)) {
                                    currentPage += 1
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    isAnimating = false
                                }
                            } label: {
                                Text(currentPage == 0 ? "let's begin →" : "Next")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: buttonWidth, height: buttonHeight)
                                    .background(Color.accentColor)
                                    .cornerRadius(buttonHeight / 2)
                                    .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: buttonHeight / 2)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isAnimating || !canProceedFromCurrentPage)
                            .opacity(buttonOpacity)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.linear(duration: 0.3).delay(0.1), value: buttonOpacity)
                        } else {
                            // Get Started Button - Centered (last page only)
                            Button {
                                guard !isAnimating else { return }
                                isAnimating = true
                                saveHealthProfileAndComplete()
                            } label: {
                                Text("Get Started")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: buttonWidth, height: buttonHeight)
                                    .background(Color.accentColor)
                                    .cornerRadius(buttonHeight / 2)
                                    .shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 7)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: buttonHeight / 2)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isAnimating || !canProceedFromCurrentPage)
                            .opacity(buttonOpacity)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.linear(duration: 0.2), value: currentPage)
                            .animation(.linear(duration: 0.3).delay(0.1), value: buttonOpacity)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Simple fade-in for buttons
            withAnimation(.linear(duration: 0.3).delay(0.2)) {
                buttonOpacity = 1.0
            }
        }
        .onChange(of: currentPage) { oldValue, newValue in
            // Only disable interaction if button was clicked, not when swiping
            // Don't change opacity during swipe
        }
    }
    
    private func completeOnboarding() {
        if !AppConfig.isTestingMode {
            UserDefaults.standard.set(true, forKey: AppConfig.hasSeenOnboardingKey)
        }
        withAnimation(.linear(duration: 0.2)) {
            isOnboardingComplete = true
        }
    }

    private func saveHealthProfileAndComplete() {
        Task {
            defer { isAnimating = false }
            guard authViewModel.isAuthenticated else {
                completeOnboarding()
                return
            }
            
            let userId = UUID(uuidString: authViewModel.currentUser?.id ?? "") ?? UUID()
            
            let profile = HealthProfile(
                userId: userId,
                fullName: authViewModel.userName,
                gender: selectedGender ?? .preferNotToSay,
                dateOfBirth: dateOfBirth,
                heightCm: heightCm,
                weightKg: weightKg,
                bloodType: nil
            )
            
            do {
                try await HealthProfileService.shared.saveHealthProfile(profile)
                await authViewModel.fetchHealthProfile()
            } catch {
                print("⚠️ Failed to save health profile from onboarding: \(error.localizedDescription)")
            }
            
            completeOnboarding()
        }
    }
    
    private func handleExistingUser() {
        if !AppConfig.isTestingMode {
            // Mark as returning user so onboarding doesn't show again
            UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
        }
        completeOnboarding()
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
