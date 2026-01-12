//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var showLoading = false
    
    var body: some View {
        ZStack {
            // Clean background
            PremiumBackground()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                // App name
                Text("SwasthiCare")
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .opacity(textOpacity)
                
                // Tagline
                Text("Your Health Companion")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .opacity(textOpacity)
                
                Spacer()
                
                // Loading indicator
                if showLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "2E3192")))
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            animate()
        }
    }
    
    private func animate() {
        // Logo fade in with subtle scale
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text appears after logo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.5)) {
                textOpacity = 1.0
            }
        }
        
        // Show loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.3)) {
                showLoading = true
            }
        }
    }
}

#Preview {
    SplashView()
}
