//
//  ToweringSpireView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

struct ToweringSpireView: View {
    @Binding var isBreathing: Bool
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Layer 1: Central Beam
            Rectangle()
                .fill(Color.cyan.opacity(0.5))
                .frame(width: 40, height: 400)
                .blur(radius: 10)
            
            // Layer 2: Floating Platforms (Infinite Scroll)
            GeometryReader { geometry in
                let height = geometry.size.height
                
                ForEach(0..<6) { i in
                    platform(at: i, height: height, width: geometry.size.width)
                }
            }
            .frame(height: 300)

            
            // Layer 3: Measurement Marks
            HStack {
                Spacer()
                VStack(spacing: 20) {
                    ForEach(0..<10) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 20, height: 2)
                    }
                }
                .offset(x: -40)
            }
            
            // Layer 4: Upward Particles
            ParticleField(count: 30, color: .cyan, speed: 2.0, scaleRange: 0.2...0.8, opacityRange: 0.2...0.6)

        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                offset = 400
            }
        }
    }
    
    private func platform(at i: Int, height: CGFloat, width: CGFloat) -> some View {
        let platformY = height - (CGFloat(i) * 80 + offset).truncatingRemainder(dividingBy: height + 80)
        let opacity = Double(1 - platformY / height)
        
        return PlatformShape()
            .fill(Color.white.opacity(0.8))
            .frame(width: 120, height: 20)
            .shadow(color: Color.cyan.opacity(0.5), radius: 10, x: 0, y: 5)
            .position(x: width / 2, y: platformY)
            .opacity(opacity)
            .scaleEffect(isBreathing ? 1.05 : 0.95)
    }
}

struct PlatformShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width / 4, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 3 / 4, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width * 3 / 4, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 4, y: rect.height))
        path.closeSubpath()
        return path
    }
}
