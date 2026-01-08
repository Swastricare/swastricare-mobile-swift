//
//  OnboardingPageView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 06/01/26.
//

import SwiftUI

struct OnboardingPageView: View {
    let modelName: String
    let title: String
    let subtitle: String
    
    @State private var contentOffset: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var modelScale: CGFloat = 0.95
    @State private var modelRotation: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOffset: CGFloat = 15
    
    var body: some View {
        VStack(spacing: 50) {
            Spacer()
            
            // 3D Model Display with smooth animations
            ModelViewer(modelName: modelName)
                .frame(height: 300)
                .scaleEffect(modelScale)
                .rotation3DEffect(
                    .degrees(modelRotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .offset(y: contentOffset)
                .opacity(contentOpacity)
            
            // Text Content with smooth fade-in and slide animations
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .offset(y: titleOffset)
                    .opacity(contentOpacity)
                
                Text(subtitle)
                    .font(.system(size: 17, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .offset(y: subtitleOffset)
                    .opacity(contentOpacity * 0.95)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            // Smooth content appearance animation
            withAnimation(.linear(duration: 0.4).delay(0.1)) {
                contentOffset = 0
                contentOpacity = 1.0
                modelScale = 1.0
                titleOffset = 0
                subtitleOffset = 0
            }
            
            // Subtle continuous rotation animation
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                modelRotation = 8
            }
        }
        .onDisappear {
            // Reset animations when page disappears for smooth transition
            contentOffset = 20
            contentOpacity = 0
            modelScale = 0.95
            titleOffset = 20
            subtitleOffset = 15
        }
    }
}

#Preview {
    OnboardingPageView(
        modelName: "doc",
        title: "Track Your Health",
        subtitle: "Monitor vitals, medications, and wellness in one place"
    )
}
