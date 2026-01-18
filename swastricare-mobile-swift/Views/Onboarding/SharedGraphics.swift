//
//  SharedGraphics.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 17/01/26.
//

import SwiftUI

// MARK: - Reusable Particle Emitter
struct ParticleField: View {
    var count: Int = 20
    var color: Color = .white
    var speed: Double = 1.0
    var scaleRange: ClosedRange<CGFloat> = 0.5...1.5
    var opacityRange: ClosedRange<Double> = 0.3...0.8
    var active: Bool = true
    
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var speedX: CGFloat
        var speedY: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
            .onChange(of: active) { _, isActive in
                if isActive {
                    createParticles(in: geometry.size)
                }
            }
        }
        .drawingGroup() // Use Metal for performance
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                scale: CGFloat.random(in: scaleRange),
                opacity: Double.random(in: opacityRange),
                speedX: CGFloat.random(in: -0.5...0.5) * speed,
                speedY: CGFloat.random(in: -0.5...0.5) * speed
            )
        }
        
        // Start continuous animation
        startAnimation(in: size)
    }
    
    private func startAnimation(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard active else { return }
            
            for i in 0..<particles.count {
                particles[i].x += particles[i].speedX
                particles[i].y += particles[i].speedY
                
                // Wrap around
                if particles[i].x < 0 { particles[i].x = size.width }
                if particles[i].x > size.width { particles[i].x = 0 }
                if particles[i].y < 0 { particles[i].y = size.height }
                if particles[i].y > size.height { particles[i].y = 0 }
                
                // Twinkle effect
                if Int.random(in: 0...20) == 0 {
                    particles[i].opacity = Double.random(in: opacityRange)
                }
            }
        }
    }
}

// MARK: - Reusable Glow Layer
struct GlowLayer: View {
    var color: Color
    var radius: CGFloat = 50
    var opacity: Double = 0.3
    var isBreathing: Bool = false
    
    @State private var breatheScale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .blur(radius: radius)
            .scaleEffect(isBreathing ? breatheScale : 1.0)
            .onAppear {
                if isBreathing {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        breatheScale = 1.2
                    }
                }
            }
    }
}

// MARK: - Parallax Container
// Simple gyroscope-like effect using device motion (simulated with continuous gentle sway)
struct ParallaxContainer<Content: View>: View {
    var content: Content
    var depth: CGFloat = 10
    
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    
    init(depth: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.depth = depth
        self.content = content()
    }
    
    var body: some View {
        content
            .offset(x: offsetX, y: offsetY)
            .onAppear {
                // Continuous sway animation simulating handheld movement
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    offsetX = depth
                }
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    offsetY = depth / 2
                }
            }
    }
}
