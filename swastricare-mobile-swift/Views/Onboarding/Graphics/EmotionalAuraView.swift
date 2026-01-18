//
//  EmotionalAuraView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct EmotionalAuraView: View {
    @Binding var isBreathing: Bool
    @State private var auraPulse: CGFloat = 1.0
    @State private var particleOffset: CGFloat = 0
    
    // Gradient that shifts over time representing "personality"
    private let auraGradient = AngularGradient(
        colors: [.blue, .purple, .orange, .blue],
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )
    
    var body: some View {
        ZStack {
            // Layer 1: Aura Field
            ForEach(0..<3) { i in
                Circle()
                    .fill(auraGradient.opacity(0.2))
                    .frame(width: 200 + CGFloat(i * 30), height: 200 + CGFloat(i * 30))
                    .blur(radius: 30)
                    .rotationEffect(.degrees(isBreathing ? 360 : 0))
                    .scaleEffect(isBreathing ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 4).repeatForever().delay(Double(i) * 0.5),
                        value: isBreathing
                    )
            }
            
            // Layer 2: Core Silhouette (Abstract Face)
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 160)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                // Eyes
                HStack(spacing: 20) {
                    Capsule().fill(.white).frame(width: 12, height: 6)
                    Capsule().fill(.white).frame(width: 12, height: 6)
                }
                .offset(y: -20)
                
                // Smile/Mouth (Morphs based on breathing)
                Capsule()
                    .trim(from: 0.4, to: 0.6)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 60, height: 40)
                    .rotationEffect(.degrees(180))
                    .offset(y: 20)
                    .scaleEffect(x: isBreathing ? 1.2 : 0.8)
            }
            .shadow(color: .white.opacity(0.5), radius: 20)
            
            // Layer 3: Emotive Particles
            ParticleField(count: 20, color: .white, speed: 0.5, scaleRange: 0.2...0.6, opacityRange: 0.4...0.9)
                .mask(Circle().frame(width: 300, height: 300))
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                particleOffset = 100
            }
        }
    }
}
