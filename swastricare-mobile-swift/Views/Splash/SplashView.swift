//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Production Grade Premium Splash Screen
//

import SwiftUI
import Combine

struct SplashView: View {
    
    // MARK: - Animation States
    @State private var animationPhase: AnimationPhase = .initial
    
    enum AnimationPhase {
        case initial
        case logoEntrance
        case textReveal
        case fullBloom
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 1. Premium Background with Radial Energy
            PremiumBackground()
                .overlay(
                    RadialGradient(
                        colors: [
                            Color(hex: "2E3192").opacity(0.3),
                            Color.black.opacity(0.8)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 500
                    )
                    .ignoresSafeArea()
                )
            
            // 2. Rising Particles (Showcase Capability)
            ShowcaseParticlesView()
                .opacity(0.6)
                .blendMode(.screen)
            
            VStack(spacing: 32) {
                Spacer()
                
                // MARK: Logo Composition
                SplashLogoView(phase: animationPhase)
                
                // MARK: Text Composition
                SplashTextView(phase: animationPhase)
                
                Spacer()
                
                // MARK: Loading Indicator
                if animationPhase == .fullBloom {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "1BFFFF")))
                        .scaleEffect(1.4)
                        .transition(.opacity.combined(with: .scale))
                        .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            runAnimationSequence()
        }
    }
    
    // MARK: - Sequence Logic
    private func runAnimationSequence() {
        // Phase 1: Logo Entrance (Explosive Spring)
        // 1 second pause before starting animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)) {
                animationPhase = .logoEntrance
            }
        }
        
        // Phase 2: Text Reveal (Slide Up)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                animationPhase = .textReveal
            }
        }
        
        // Phase 3: Full Bloom (Shimmer, Spinner, Particles, 3D Rotation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation {
                animationPhase = .fullBloom
            }
        }
    }
}

// MARK: - Subviews

struct SplashLogoView: View {
    let phase: SplashView.AnimationPhase
    @State private var pulse = false
    @State private var rotation3D = false
    
    var body: some View {
        ZStack {
            // Complex Pulse Effect (Multi-ring)
            if phase == .fullBloom || phase == .textReveal {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [PremiumColor.hex("2E3192"), .clear, PremiumColor.hex("2E3192")]),
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 2.5 : 1.0)
                        .opacity(pulse ? 0.0 : 0.6)
                        .animation(
                            .easeOut(duration: 2.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.4),
                            value: pulse
                        )
                }
            }
            
            // Glass Container with 3D Gimbal Effect
            ZStack {
                // Outer Ring (Orbit)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 180, height: 180)
                    .rotation3DEffect(
                        .degrees(rotation3D ? 360 : 0),
                        axis: (x: 1, y: 1, z: 0)
                    )
                
                // Frosted Glass Core
                RoundedRectangle(cornerRadius: 35)
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                    .shadow(
                        color: PremiumColor.hex("2E3192").opacity(0.4),
                        radius: phase == .fullBloom ? 30 : 10,
                        x: 0,
                        y: 10
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 35)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // Icon with Neon Gradient
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "1BFFFF"), Color(hex: "2E3192")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "1BFFFF").opacity(0.6), radius: 15, x: 0, y: 0)
            }
            .scaleEffect(phase == .initial ? 0.2 : 1.0)
            .opacity(phase == .initial ? 0.0 : 1.0)
            .rotation3DEffect(
                .degrees(rotation3D ? 10 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .onAppear {
                if phase == .fullBloom || phase == .logoEntrance {
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        rotation3D = true
                    }
                    pulse = true
                }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .fullBloom {
                     pulse = true
                     withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                         rotation3D = true
                     }
                }
            }
        }
    }
}

struct SplashTextView: View {
    let phase: SplashView.AnimationPhase
    @State private var shimmerOffset: CGFloat = -200
    @State private var glitchOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Brand Name with Neon Glow
            Text("SWASTRICARE")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(hex: "1BFFFF")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(hex: "1BFFFF").opacity(0.5), radius: 10, x: 0, y: 0)
                .offset(x: glitchOffset)
                .overlay {
                    // Intense Shimmer Mask
                    if phase == .fullBloom {
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(20))
                        .offset(x: shimmerOffset)
                        .mask(
                            Text("SWASTRICARE")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                        )
                        .blendMode(.overlay)
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                shimmerOffset = 200
                            }
                            // Subtle Glitch Effect
                            withAnimation(.spring(bounce: 0.5).repeatForever(autoreverses: true)) {
                                glitchOffset = 1
                            }
                        }
                    }
                }
            
            // Tagline
            Text("Your Health Companion")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.9))
                .tracking(3)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
        }
        .opacity(phase == .initial || phase == .logoEntrance ? 0.0 : 1.0)
        .offset(y: phase == .initial || phase == .logoEntrance ? 30 : 0)
        .scaleEffect(phase == .fullBloom ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: phase)
    }
}

// MARK: - Showcase Particles

struct ShowcaseParticlesView: View {
    @State private var particles: [ShowcaseParticle] = []
    
    struct ShowcaseParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: Double
        var sway: Double
    }
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color(hex: "1BFFFF").opacity(0.6))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .blur(radius: particle.size / 3)
                }
            }
            .onReceive(timer) { _ in
                updateParticles(in: geometry.size)
            }
        }
        .ignoresSafeArea()
    }
    
    private func updateParticles(in size: CGSize) {
        // Emit new particles from bottom
        if particles.count < 30 {
            let newParticle = ShowcaseParticle(
                x: CGFloat.random(in: 0...size.width),
                y: size.height + 20,
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.4...0.9),
                speed: Double.random(in: 2...6),
                sway: Double.random(in: -1...1)
            )
            particles.append(newParticle)
        }
        
        // Move particles upwards with sway
        for i in particles.indices {
            particles[i].y -= particles[i].speed
            particles[i].x += sin(particles[i].y / 50) * particles[i].sway
            particles[i].opacity -= 0.005
        }
        
        // Remove dead particles
        particles.removeAll { $0.y < -20 || $0.opacity <= 0 }
    }
}

#Preview {
    SplashView()
}
