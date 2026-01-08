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
    
    private let totalPages = 3
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
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        modelName: "doc",
                        title: "Track Your Health",
                        subtitle: "Monitor vitals, medications, and wellness in one place"
                    )
                    .tag(0)
                    
                    OnboardingPageView(
                        modelName: "love",
                        title: "AI Swastrica",
                        subtitle: "Your personal health companion powered by AI"
                    )
                    .tag(1)
                    
                    OnboardingPageView(
                        modelName: "vault",
                        title: "Private & Secure",
                        subtitle: "Keep your medical documents safe and encrypted"
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.linear(duration: 0.3), value: currentPage)
                .disabled(isAnimating)
                .allowsHitTesting(!isAnimating)
                
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
                                isAnimating = true
                                withAnimation(.linear(duration: 0.3)) {
                                    currentPage += 1
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    isAnimating = false
                                }
                            } label: {
                                Text("Next")
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
                            .disabled(isAnimating)
                            .opacity(buttonOpacity)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.linear(duration: 0.3).delay(0.1), value: buttonOpacity)
                        } else {
                            // Get Started Button - Centered (last page only)
                            Button {
                                guard !isAnimating else { return }
                                isAnimating = true
                                completeOnboarding()
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
                            .disabled(isAnimating)
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
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
