//
//  OneQuestionPerScreenOnboardingView.swift
//  swastricare-mobile-swift
//
//  One Question Per Screen Onboarding Flow
//

import SwiftUI
import UIKit
import CoreLocation

struct OneQuestionPerScreenOnboardingView: View {
    @StateObject private var viewModel = OneQuestionOnboardingViewModel()
    @State private var isCompleting = false
    
    let onComplete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if isCompleting {
                OnboardingSetupLoadingView(
                    onComplete: {
                        onComplete()
                    },
                    saveAction: {
                        try await viewModel.saveOnboarding()
                    }
                )
            } else {
                ZStack {
                    // Clean Background
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea(.all)
                    
                    // Subtle ambient glow
                    GeometryReader { geo in
                        Circle()
                            .fill(Color(hex: "2E3192").opacity(colorScheme == .dark ? 0.1 : 0.03))
                            .blur(radius: 100)
                            .frame(width: 300, height: 300)
                            .position(x: geo.size.width * 0.8, y: 0)
                        
                        Circle()
                            .fill(Color(hex: "1BFFFF").opacity(colorScheme == .dark ? 0.08 : 0.02))
                            .blur(radius: 80)
                            .frame(width: 250, height: 250)
                            .position(x: 0, y: geo.size.height * 0.7)
                    }
                    .ignoresSafeArea()
                    
                    ZStack(alignment: .topTrailing) {
                        // Question Content
                        TabView(selection: $viewModel.currentQuestion) {
                            // Wrap each view to ensure proper hit testing
                            // Question 1: Full Name
                            FullNameQuestionView(formState: viewModel.formState) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    viewModel.nextQuestion()
                                }
                            }
                            .tag(OnboardingQuestion.fullName)
                            
                            // Question 2: Gender
                            GenderQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.gender)
                                .allowsHitTesting(true)
                            
                            // Question 3: Date of Birth
                            DateOfBirthQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.dateOfBirth)
                            
                            // Question 4: Height
                            HeightQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.height)
                            
                            // Question 6: Weight
                            WeightQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.weight)
                            
                            // Question 7: Primary Goal
                            PrimaryGoalQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.primaryGoal)
                            
                            // Question 8: Activity Level
                            ActivityLevelQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.activityLevel)
                            
                            // Question 9: Water Intake
                            WaterIntakeQuestionView(formState: viewModel.formState)
                                .tag(OnboardingQuestion.waterIntake)
                            
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentQuestion)
                        .allowsHitTesting(true)
                        
                        // Skip Button - Overlay at Top Right (doesn't affect layout)
                        if viewModel.isOptionalQuestion {
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            viewModel.skipQuestion()
                                        }
                                    }) {
                                        Text("Skip")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.trailing, 24)
                                    .padding(.top, 60)
                                }
                                Spacer()
                            }
                            .allowsHitTesting(true)
                        }
                        
                        // Continue Button - Fixed at Bottom
                        VStack {
                            Spacer()
                               Button(action: {
                                   if viewModel.currentQuestion == .waterIntake {
                                       completeOnboarding()
                                   } else {
                                       withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                           viewModel.nextQuestion()
                                       }
                                   }
                               }) {
                                   Text(viewModel.currentQuestion == .waterIntake ? "Complete Setup" : "Continue")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(viewModel.canProceed ? Color(hex: "2E3192") : Color.gray.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: viewModel.canProceed ? Color(hex: "2E3192").opacity(0.3) : .clear, radius: 12, y: 6)
                            }
                            .disabled(!viewModel.canProceed)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                        }
                    }
                    .ignoresSafeArea(.all, edges: .bottom)
                }
                .ignoresSafeArea(.all)
            }
        }
    }
    
    private func completeOnboarding() {
        isCompleting = true
        // The OnboardingSetupLoadingView will handle saving and call onComplete when done
    }
}

// MARK: - Progress Header

struct OneQuestionProgressHeaderView: View {
    let current: Int
    let total: Int
    let onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<min(total, 10), id: \.self) { index in
                    Capsule()
                        .fill(index <= current ? Color(hex: "2E3192") : Color.primary.opacity(0.1))
                        .frame(width: index == current ? 32 : 6, height: 6)
                        .animation(.spring, value: current)
                }
            }
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
    }
}


#Preview {
    OneQuestionPerScreenOnboardingView(onComplete: {})
}
