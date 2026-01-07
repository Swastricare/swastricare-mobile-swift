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
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack {
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
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom Controls
                VStack(spacing: 24) {
                    // Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    // Buttons
                    HStack {
                        if currentPage < 2 {
                            Button("Skip") {
                                completeOnboarding()
                            }
                            .foregroundStyle(Color.secondary)
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    currentPage += 1
                                }
                            } label: {
                                Text("Next")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.white)
                                    .frame(width: 100, height: 44)
                                    .background(Color.accentColor)
                                    .cornerRadius(22)
                            }
                        } else {
                            Button {
                                completeOnboarding()
                            } label: {
                                Text("Get Started")
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.accentColor)
                                    .cornerRadius(25)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func completeOnboarding() {
        if !AppConfig.isTestingMode {
            UserDefaults.standard.set(true, forKey: AppConfig.hasSeenOnboardingKey)
        }
        withAnimation {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
