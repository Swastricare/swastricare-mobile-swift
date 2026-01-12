//
//  ComprehensiveOnboardingView.swift
//  swastricare-mobile-swift
//
//  Comprehensive Onboarding Flow - Main Coordinator
//

import SwiftUI
import CoreLocation

struct ComprehensiveOnboardingView: View {
    @StateObject private var viewModel = ComprehensiveOnboardingViewModel()
    @State private var showMedicationDetails = false
    @State private var isCompleting = false
    
    let onComplete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if isCompleting {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            } else {
                ZStack {
                    // Clean Background
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    
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
                    
                    VStack(spacing: 0) {
                        // Progress Header
                        if viewModel.currentScreen != .profileSetup {
                            ProgressHeaderView(
                                current: viewModel.currentScreen.rawValue,
                                total: OnboardingScreen.allCases.count,
                                onBack: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        viewModel.previousScreen()
                                    }
                                }
                            )
                            .padding(.top, 60)
                            .padding(.horizontal, 24)
                        }
                        
                        // Screen Content
                        TabView(selection: $viewModel.currentScreen) {
                            ProfileSetupScreen(formState: $viewModel.formState, viewModel: viewModel)
                                .tag(OnboardingScreen.profileSetup)
                            
                            BodyMetricsScreen(formState: $viewModel.formState)
                                .tag(OnboardingScreen.bodyMetrics)
                            
                            GoalsScreen(formState: $viewModel.formState)
                                .tag(OnboardingScreen.goals)
                            
                            LifestyleScreen(formState: $viewModel.formState)
                                .tag(OnboardingScreen.lifestyle)
                            
                            HealthScreen(formState: $viewModel.formState, viewModel: viewModel)
                                .tag(OnboardingScreen.health)
                            
                            MedicationDetailsScreen(formState: $viewModel.formState)
                                .tag(OnboardingScreen.medicationDetails)
                            
                            HabitsScreen(formState: $viewModel.formState)
                                .tag(OnboardingScreen.habits)
                            
                            PermissionsScreen(formState: $viewModel.formState)
                                .tag(OnboardingScreen.permissions)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentScreen)
                        
                        // Bottom Actions
                        if viewModel.currentScreen != .profileSetup {
                            BottomActionsView(
                                canProceed: viewModel.canProceed,
                                isOptional: viewModel.isOptionalScreen,
                                isLastScreen: viewModel.currentScreen == .permissions,
                                onNext: {
                                    if viewModel.currentScreen == .permissions {
                                        completeOnboarding()
                                    } else {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            viewModel.nextScreen()
                                        }
                                    }
                                },
                                onSkip: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        viewModel.skipScreen()
                                    }
                                }
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                            .padding(.top, 20)
                        }
                    }
                }
            }
        }
    }
    
    private func completeOnboarding() {
        isCompleting = true
        
        Task {
            do {
                try await viewModel.saveOnboarding()
                await MainActor.run {
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isCompleting = false
                    // Show error
                    print("Error saving onboarding: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Progress Header

struct ProgressHeaderView: View {
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
                ForEach(0..<total, id: \.self) { index in
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

// MARK: - Bottom Actions

struct BottomActionsView: View {
    let canProceed: Bool
    let isOptional: Bool
    let isLastScreen: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onNext) {
                Text(isLastScreen ? "Complete Setup" : "Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canProceed ? Color(hex: "2E3192") : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: canProceed ? Color(hex: "2E3192").opacity(0.3) : .clear, radius: 12, y: 6)
            }
            .disabled(!canProceed)
            
            if isOptional {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Screen Base Components

struct ScreenTitleView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 17))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Option Button Style

struct OptionButton<Content: View>: View {
    let isSelected: Bool
    let content: Content
    let action: () -> Void
    
    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                content
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "2E3192"))
                        .font(.system(size: 22))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "2E3192").opacity(0.1) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Multi-Select Option

struct MultiSelectOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        OptionButton(isSelected: isSelected, action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Single Select Option

struct SingleSelectOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        OptionButton(isSelected: isSelected, action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    ComprehensiveOnboardingView(onComplete: {})
}
