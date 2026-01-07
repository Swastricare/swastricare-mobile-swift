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
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 3D Model Display
            ModelViewer(modelName: modelName)
                .frame(height: 300)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .blur(radius: 20)
                )
            
            // Text Content
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primary)
                
                Text(subtitle)
                    .font(.system(size: 18, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
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
