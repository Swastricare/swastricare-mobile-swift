//
//  OnboardingGraphicView.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 06/01/26.
//

import SwiftUI

struct OnboardingGraphicView: View {
    let modelName: String
    @Binding var isBreathing: Bool
    
    var body: some View {
        switch modelName {
        case "intro":
            AIOrbAvatarView(isBreathing: $isBreathing)
        case "device":
            DeviceScanView(isBreathing: $isBreathing)
        case "existing":
            ExistingUserView(isBreathing: $isBreathing)
        case "doc":
            VitalFlowView(isBreathing: $isBreathing)
        case "love":
            NeuralSynapseView(isBreathing: $isBreathing)
        case "vault":
            CrystalShieldView(isBreathing: $isBreathing)
        case "cosmic":
            CosmicTimelineView(isBreathing: $isBreathing)
        case "liquid":
            LiquidGravityView(isBreathing: $isBreathing)
        case "spire":
            ToweringSpireView(isBreathing: $isBreathing)
        case "prism":
            SpectrumPrismView(isBreathing: $isBreathing)
        case "aura":
            EmotionalAuraView(isBreathing: $isBreathing)
        default:
            EmptyView()
        }
    }
}

// MARK: - Screen 1: The Avatar (Intro)

struct AIOrbAvatarView: View {
    @Binding var isBreathing: Bool
    @State private var isRotating = false
    
    var body: some View {
        ZStack {
            // Outer Glow
            OrbGlowView(isBreathing: isBreathing)
            
            // Rings (Dual Gyroscopic)
            OrbRingView(isRotating: isRotating)
            
            // Core Orb
            OrbCoreView(isBreathing: isBreathing)
        }
        .onAppear {
            // Continuous rotation
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

// MARK: - Screen 2: Vital Flow (Health)

struct VitalFlowView: View {
    @Binding var isBreathing: Bool
    @State private var wavePhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(PremiumColor.sunset.opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .scaleEffect(isBreathing ? 1.1 : 0.9)
            
            // Orbiting ECG Ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "FF512F").opacity(0.8), Color(hex: "DD2476").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 10])
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(wavePhase))
            
            // Central Liquid Drop (Heart)
            Image(systemName: "heart.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF512F"), Color(hex: "DD2476")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(hex: "FF512F").opacity(0.5), radius: 15, x: 0, y: 5)
                .scaleEffect(isBreathing ? 1.1 : 0.95)
                .overlay(
                    Image(systemName: "heart.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.white.opacity(0.3))
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .rotationEffect(.degrees(45))
                                .offset(x: -20, y: -20)
                        )
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                wavePhase = 360
            }
        }
    }
}

// MARK: - Device Scan (Hardware)

struct DeviceScanView: View {
    @Binding var isBreathing: Bool
    @State private var scanOffset: CGFloat = -80
    
    private let frameColor = Color(hex: "1BFFFF").opacity(0.7)
    private let scanStart = Color(hex: "38ef7d").opacity(0.0)
    private let scanMid = Color(hex: "38ef7d").opacity(0.7)
    private let scanEnd = Color(hex: "38ef7d").opacity(0.0)
    
    var body: some View {
        ZStack {
            // Ambient Glow
            Circle()
                .fill(Color(hex: "38ef7d").opacity(0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 50)
                .scaleEffect(isBreathing ? 1.08 : 0.95)
            
            // Phone Wireframe
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(frameColor, lineWidth: 2)
                .frame(width: 140, height: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(frameColor.opacity(0.25), lineWidth: 6)
                        .blur(radius: 6)
                )
            
            // Scanning Laser
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [scanStart, scanMid, scanEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 120, height: 28)
                .offset(y: scanOffset)
                .blendMode(.screen)
            
            // Circuit Nodes
            node(offsetX: -60, offsetY: -90)
            node(offsetX: 60, offsetY: -90)
            node(offsetX: -60, offsetY: 90)
            node(offsetX: 60, offsetY: 90)
        }
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: true)) {
                scanOffset = 80
            }
        }
    }
    
    private func node(offsetX: CGFloat, offsetY: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: "38ef7d"))
            .frame(width: 10, height: 10)
            .shadow(color: Color(hex: "38ef7d").opacity(0.6), radius: 6)
            .scaleEffect(isBreathing ? 1.1 : 0.9)
            .offset(x: offsetX, y: offsetY)
    }
}

// MARK: - Screen 2: Existing User

struct ExistingUserView: View {
    @Binding var isBreathing: Bool
    @State private var sway: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Ambient Glow
            Circle()
                .fill(PremiumColor.royalBlue.opacity(0.15))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .scaleEffect(isBreathing ? 1.08 : 0.95)
            
            // Two door panels
            HStack(spacing: 24) {
                doorPanel(title: "Existing")
                    .rotationEffect(.degrees(-sway))
                
                doorPanel(title: "New")
                    .rotationEffect(.degrees(sway))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                sway = 6
            }
        }
    }
    
    private func doorPanel(title: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color(hex: "1BFFFF").opacity(0.7), lineWidth: 2)
            .frame(width: 90, height: 150)
            .overlay(
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "1BFFFF").opacity(0.8))
                        .frame(width: 10, height: 10)
                        .offset(x: 28)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "1BFFFF").opacity(0.9))
                }
            )
            .shadow(color: Color(hex: "1BFFFF").opacity(0.2), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Screen 3: Neural Synapse (AI)

struct NeuralSynapseView: View {
    @Binding var isBreathing: Bool
    @State private var rotation: CGFloat = 0
    
    // Explicit neon green gradient
    private let neonGradient = LinearGradient(
        colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(Color(hex: "38ef7d").opacity(0.15))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .scaleEffect(isBreathing ? 1.1 : 0.9)
            
            // Central Brain/Chip Core
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color(hex: "38ef7d").opacity(0.4), radius: 20, x: 0, y: 0)
                .rotationEffect(.degrees(45))
                .scaleEffect(isBreathing ? 1.05 : 0.95)
            
            // Orbiting Nodes
            ForEach(0..<3) { i in
                Circle()
                    .stroke(neonGradient.opacity(0.5), lineWidth: 1)
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(Double(i) * 60 + rotation))
                    .overlay(
                        Circle()
                            .fill(Color(hex: "38ef7d"))
                            .frame(width: 12, height: 12)
                            .shadow(color: .white, radius: 5)
                            .offset(y: -90)
                            .rotationEffect(.degrees(Double(i) * 60 + rotation))
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Screen 4: Crystal Shield (Vault)

struct CrystalShieldView: View {
    @Binding var isBreathing: Bool
    @State private var rotation: CGFloat = 0
    
    private let shieldGradient = LinearGradient(
        colors: [Color(hex: "654ea3"), Color(hex: "eaafc8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(Color(hex: "654ea3").opacity(0.2))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .scaleEffect(isBreathing ? 1.1 : 0.9)
            
            // Rotating Hexagonal Layers
            Image(systemName: "hexagon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .foregroundStyle(shieldGradient.opacity(0.3))
                .rotationEffect(.degrees(rotation))
            
            Image(systemName: "hexagon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .foregroundStyle(shieldGradient.opacity(0.6))
                .rotationEffect(.degrees(-rotation * 1.5))
            
            // Central Lock
            Image(systemName: "lock.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(shieldGradient)
                .shadow(color: Color(hex: "654ea3").opacity(0.5), radius: 15, x: 0, y: 5)
                .scaleEffect(isBreathing ? 1.05 : 0.95)
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Orb Subcomponents

private struct OrbGlowView: View {
    let isBreathing: Bool
    
    var body: some View {
        ZStack {
            // Primary intense glow
            Circle()
                .fill(PremiumColor.royalBlue.opacity(0.4))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .scaleEffect(isBreathing ? 1.1 : 0.9)
            
            // Secondary ambient glow (larger)
            Circle()
                .fill(Color(hex: "1BFFFF").opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .scaleEffect(isBreathing ? 1.15 : 0.95)
                .opacity(isBreathing ? 0.5 : 0.2)
        }
    }
}

private struct OrbRingView: View {
    let isRotating: Bool
    
    // Explicit colors
    private let c1 = Color(hex: "1BFFFF").opacity(0.9)
    private let c2 = Color(hex: "2E3192").opacity(0.1)
    private let c3 = Color(hex: "1BFFFF").opacity(0.9)
    
    var body: some View {
        ZStack {
            // Inner Orbit (Clockwise)
            Circle()
                .stroke(
                    LinearGradient(colors: [c1, c2, c3], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
            
            // Outer Tech Ring (Counter-Rotating, Dashed)
            Circle()
                .stroke(
                    LinearGradient(colors: [c3, c2, c1], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [40, 60])
                )
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(isRotating ? -180 : 0)) // Slower reverse rotation
                .opacity(0.7)
        }
    }
}

private struct OrbCoreView: View {
    let isBreathing: Bool
    
    // Explicit colors
    private let centerColor = Color(hex: "1BFFFF") // Cyan
    private let midColor = Color(hex: "2E3192")    // Royal Blue
    
    var body: some View {
        ZStack {
            // Main Sphere
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [centerColor, midColor]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: midColor.opacity(0.6), radius: 25, x: 0, y: 0)
            
            // Specular Highlight (Reflection)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: 120, height: 120)
                .offset(x: -25, y: -25)
                .blur(radius: 12)
                .mask(Circle().frame(width: 140, height: 140))
        }
        .scaleEffect(isBreathing ? 1.05 : 0.98)
    }
}
