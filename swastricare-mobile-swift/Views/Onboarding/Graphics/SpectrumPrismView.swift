//
//  SpectrumPrismView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct SpectrumPrismView: View {
    @Binding var isBreathing: Bool
    @State private var rotation: Double = 0
    @State private var hueRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Layer 1: Ambient Spectrum Glow
            GlowLayer(color: .white, radius: 60, opacity: 0.2, isBreathing: isBreathing)
            
            // Layer 2: White Light Beam (Input)
            Rectangle()
                .fill(
                    LinearGradient(colors: [.clear, .white.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 4, height: 150)
                .rotationEffect(.degrees(-45))
                .offset(x: -60, y: -60)
                .blur(radius: 2)
            
            // Layer 3: The Prism (Glass Geometry)
            ZStack {
                PolygonShape(sides: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        PolygonShape(sides: 3)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(isBreathing ? 1.05 : 0.95)
                
                // Internal Reflections
                PolygonShape(sides: 3)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-rotation * 2))
            }
            .shadow(color: .white.opacity(0.2), radius: 10)
            
            // Layer 4: Rainbow Dispersion (Output)
            ForEach(0..<7) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hue: Double(i)/7.0, saturation: 0.8, brightness: 1.0), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 3, height: 150)
                    .rotationEffect(.degrees(135 + Double(i) * 5))
                    .offset(x: 60, y: 60)
                    .opacity(0.6)
                    .hueRotation(.degrees(hueRotation))
            }
            
            // Layer 5: Identity Orbs (Floating)
            ParallaxContainer(depth: 15) {
                ZStack {
                    Circle().fill(Color.pink.opacity(0.4)).frame(width: 20, height: 20).offset(x: 80, y: 20)
                    Circle().fill(Color.blue.opacity(0.4)).frame(width: 15, height: 15).offset(x: 40, y: 80)
                    Circle().fill(Color.purple.opacity(0.4)).frame(width: 25, height: 25).offset(x: 90, y: 60)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                hueRotation = 360
            }
        }
    }
}

struct PolygonShape: Shape {
    var sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        let angle = 2.0 * .pi / Double(sides)
        
        for i in 0..<sides {
            let x = center.x + radius * cos(CGFloat(i) * angle - .pi / 2)
            let y = center.y + radius * sin(CGFloat(i) * angle - .pi / 2)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}
