//
//  OnboardingPageView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 06/01/26.
//

import SwiftUI

struct OnboardingPageView<Content: View>: View {
    let modelName: String
    let title: String
    let subtitle: String?
    var subtext: String? = nil
    @ViewBuilder let actionView: Content
    
    init(
        modelName: String,
        title: String,
        subtitle: String? = nil,
        subtext: String? = nil,
        @ViewBuilder actionView: () -> Content = { EmptyView() }
    ) {
        self.modelName = modelName
        self.title = title
        self.subtitle = subtitle
        self.subtext = subtext
        self.actionView = actionView()
    }
    
    @State private var contentOffset: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var modelScale: CGFloat = 0.95
    @State private var modelRotation: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOffset: CGFloat = 15
    @State private var isBreathing: Bool = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Unified Graphic View (Replaces 3D Models)
            OnboardingGraphicView(
                modelName: modelName,
                isBreathing: $isBreathing
            )
            .frame(height: 300)
            .opacity(contentOpacity)
            
            // Text Content with smooth fade-in and slide animations
            VStack(spacing: 16) {
                // Split title by newlines to ensure all parts render with gradient
                VStack(spacing: 12) {
                    ForEach(title.components(separatedBy: "\n"), id: \.self) { line in
                        if !line.isEmpty {
                            Text(line)
                                .font(.system(size: 36, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                                .foregroundStyle(
                                    PremiumColor.royalBlue
                                )
                        }
                    }
                }
                .offset(y: titleOffset)
                .opacity(contentOpacity)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.secondary)
                        .lineSpacing(4)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                        .offset(y: subtitleOffset)
                        .opacity(contentOpacity * 0.95)
                }
                
                if let subtext = subtext {
                    Text(subtext)
                        .font(.system(size: 14, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.gray.opacity(0.8))
                        .padding(.top, 8)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                        .offset(y: subtitleOffset)
                        .opacity(contentOpacity * 0.8)
                }
                
                // Custom Action View
                actionView
                    .padding(.top, 20)
                    .offset(y: subtitleOffset)
                    .opacity(contentOpacity)
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
            
            // Breathing animation
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                isBreathing = true
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
