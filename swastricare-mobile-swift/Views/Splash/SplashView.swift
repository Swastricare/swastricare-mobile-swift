//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct SplashView: View {
    
    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            PremiumBackground()
            
            VStack(spacing: 24) {
                // Logo
                ZStack {
                    // Glow effect - adapts to theme
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: colorScheme == .dark ? [
                                    Color(hex: "2E3192").opacity(0.3),
                                    Color.clear
                                ] : [
                                    Color(hex: "2E3192").opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 120
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    // Logo background
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Material.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40)
                                .stroke(
                                    colorScheme == .dark 
                                        ? Color.white.opacity(0.2) 
                                        : Color.black.opacity(0.1),
                                    lineWidth: 0.5
                                )
                        )
                    
                    // Logo icon
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "654ea3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // App Name
                VStack(spacing: 8) {
                    Text("Swastricare")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .primary : Color(hex: "2E3192"))
                    
                    Text("Your Health Companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(opacity)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "2E3192")))
                    .scaleEffect(1.2)
                    .opacity(opacity)
                    .padding(.top, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            isAnimating = true
        }
    }
}

#Preview {
    SplashView()
}

