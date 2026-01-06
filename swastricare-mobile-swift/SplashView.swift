//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  Created by AI Assistant on 06/01/26.
//

import SwiftUI

struct SplashView: View {
    @State private var startAnimation = false
    @State private var circleAnimation = false
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "1A237E"), // Deep Royal Blue
                    Color(hex: "311B92"), // Deep Indigo
                    Color(hex: "006064")  // Deep Cyan
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated Circles Background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .scaleEffect(circleAnimation ? 1.2 : 1.0)
                    .offset(x: -100, y: -150)
                    .blur(radius: 50)
                
                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 250, height: 250)
                    .scaleEffect(circleAnimation ? 1.3 : 1.0)
                    .offset(x: 100, y: 150)
                    .blur(radius: 40)
            }
            
            VStack(spacing: 20) {
                // Logo Icon
                ZStack {
                    // Glass background for logo
                    RoundedRectangle(cornerRadius: 40)
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .shadow(color: .white.opacity(0.1), radius: 10, x: -5, y: -5)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Medical Cross / S Icon
                    Image(systemName: "cross.case.fill") // Fallback if no asset
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(startAnimation ? 1.0 : 0.5)
                .opacity(startAnimation ? 1.0 : 0.0)
                
                // App Name
                VStack(spacing: 5) {
                    Text("SwastriCare")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                    
                    Text("Your Personal Health Companion")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .offset(y: startAnimation ? 0 : 50)
                .opacity(startAnimation ? 1.0 : 0.0)
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                startAnimation = true
            }
            
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                circleAnimation = true
            }
            
            // Transition to main view after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = true
                }
            }
        }
    }
}
