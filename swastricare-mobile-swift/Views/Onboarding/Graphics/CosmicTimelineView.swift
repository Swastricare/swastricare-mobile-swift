//
//  CosmicTimelineView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct CosmicTimelineView: View {
    @Binding var isBreathing: Bool
    @State private var rotation: Double = 0
    @State private var spiralRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Layer 1: Deep Space Nebula (Parallax)
            ParallaxContainer(depth: 15) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "2E3192").opacity(0.3), .clear], center: .center, startRadius: 50, endRadius: 150))
                        .frame(width: 300, height: 300)
                        .blur(radius: 40)
                    
                    ParticleField(count: 40, color: .white.opacity(0.6), speed: 0.2, scaleRange: 0.5...1.0, opacityRange: 0.2...0.6)
                        .frame(width: 300, height: 300)
                }
            }
            
            // Layer 2: Spiral Timeline (Rotating)
            ZStack {
                ForEach(0..<8) { i in
                    SpiralArm(index: i)
                        .rotationEffect(.degrees(Double(i) * 45 + spiralRotation))
                }
            }
            .scaleEffect(isBreathing ? 1.05 : 0.95)
            .rotation3DEffect(.degrees(20), axis: (x: 1, y: 0, z: 0))
            
            // Layer 3: Central Sun (User Birth Moment)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FF8C00").opacity(0.5), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                
                Circle()
                    .fill(.white)
                    .frame(width: 40, height: 40)
                    .blur(radius: 5)
                    .overlay(Circle().stroke(Color(hex: "FFD700"), lineWidth: 2))
            }
            .scaleEffect(isBreathing ? 1.2 : 1.0)
            
            // Layer 4: Floating "Events" (Parallax Foreground)
            ParallaxContainer(depth: -20) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.6)).frame(width: 8, height: 8).offset(x: 80, y: -60)
                    Circle().fill(Color.purple.opacity(0.6)).frame(width: 6, height: 6).offset(x: -70, y: 50)
                    Circle().fill(Color.cyan.opacity(0.6)).frame(width: 10, height: 10).offset(x: 40, y: 90)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                spiralRotation = 360
            }
        }
    }
}

struct SpiralArm: View {
    let index: Int
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 100, y: 100), control: CGPoint(x: 50, y: 0))
        }
        .stroke(
            LinearGradient(
                colors: [.clear, Color(hex: "1BFFFF").opacity(Double(index) * 0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 10])
        )
        .frame(width: 100, height: 100)
        .offset(x: 50, y: 50)
    }
}
