//
//  LiquidGravityView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct LiquidGravityView: View {
    @Binding var isBreathing: Bool
    @State private var blobOffset: CGSize = .zero
    @State private var satelliteRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Layer 1: Gravity Grid (Floor)
            ParallaxContainer(depth: 10) {
                GridFloor()
                    .rotation3DEffect(.degrees(70), axis: (x: 1, y: 0, z: 0))
                    .offset(y: 100)
                    .opacity(0.3)
            }
            
            // Layer 2: Main Liquid Blob (Mercury)
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let wobble = sin(time * 2) * 5
                
                ZStack {
                    // Blob Body
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color(hex: "B0B0B0"), Color(hex: "606060")],
                                center: .topLeading,
                                startRadius: 10,
                                endRadius: 100
                            )
                        )
                        .frame(width: 140 + wobble, height: 140 - wobble) // Squash and stretch
                        .overlay(
                            // Reflection
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .blur(radius: 4)
                                .offset(x: -10, y: -10)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 30) // Drop shadow
                    
                    // Orbiting Droplets
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color(hex: "D0D0D0"))
                            .frame(width: 20, height: 20)
                            .offset(x: 100)
                            .rotationEffect(.degrees(Double(i) * 120 + satelliteRotation))
                    }
                }
                .scaleEffect(isBreathing ? 1.05 : 0.95)
            }
            
            // Layer 3: Gravitational Waves
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 200 + CGFloat(i * 40))
                    .scaleEffect(isBreathing ? 1.1 : 0.9)
                    .opacity(isBreathing ? 0.5 : 0.0)
                    .animation(.easeInOut(duration: 2).repeatForever().delay(Double(i) * 0.5), value: isBreathing)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                satelliteRotation = 360
            }
        }
    }
}

struct GridFloor: View {
    var body: some View {
        Path { path in
            for i in 0..<10 {
                let x = CGFloat(i) * 30
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: 300))
                
                let y = CGFloat(i) * 30
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: 300, y: y))
            }
        }
        .stroke(Color.white, lineWidth: 0.5)
        .frame(width: 300, height: 300)
    }
}
