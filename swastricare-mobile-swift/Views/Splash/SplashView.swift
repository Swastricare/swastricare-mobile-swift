//
//  SplashView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -30
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var taglineOpacity: Double = 0
    @State private var showLoading = false
    @State private var showPulseRings = false
    @State private var healthTip: String = ""
    @State private var tipOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    private let healthTips = [
        "Drinking water first thing boosts metabolism by 24%",
        "A 10-minute walk after meals improves digestion",
        "Deep breathing for 60 seconds lowers cortisol",
        "7-9 hours of sleep improves immune function by 70%",
        "Standing up every 30 minutes reduces back pain",
        "Eating slowly helps you consume 10% fewer calories",
        "Sunlight in the morning resets your circadian rhythm",
        "Laughing for 15 minutes burns up to 40 calories"
    ]

    var body: some View {
        ZStack {
            // Clean background
            PremiumBackground()

            VStack(spacing: 0) {
                Spacer()

                // Logo with glow
                ZStack {
                    // Pulse rings behind logo (aligned to logo center)
                    if showPulseRings {
                        PulseRingsView()
                            .frame(width: 240, height: 240)
                            .allowsHitTesting(false)
                    }

                    // Soft glow behind logo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "2E3192").opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale * 1.2)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .rotationEffect(.degrees(logoRotation))
                        .opacity(logoOpacity)
                        .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 20, y: 8)
                }

                Spacer().frame(height: 24)

                // App name with shimmer
                ZStack {
                    Text("SwasthiCare")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundColor(.primary)

                    // Shimmer overlay
                    Text("SwasthiCare")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white, .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 80)
                                .offset(x: shimmerOffset)
                        )
                }
                .opacity(textOpacity)
                .offset(y: textOffset)

                Spacer().frame(height: 8)

                // Tagline
                Text("Your Health Companion")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .opacity(taglineOpacity)
                    .offset(y: textOffset)

                Spacer()

                // Health tip
                if !healthTip.isEmpty {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "F59E0B"))
                            Text("Did you know?")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "F59E0B"))
                        }
                        Text(healthTip)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .opacity(tipOpacity)
                    .padding(.bottom, 16)
                }

                // Loading indicator with label
                if showLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "2E3192")))
                        Text("Preparing your health hub...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            healthTip = healthTips.randomElement() ?? healthTips[0]
            animate()
        }
    }

    private func animate() {
        // Phase 1: Logo drops in with rotation (0.0s)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
            logoOpacity = 1.0
            logoScale = 1.0
            logoRotation = 0
        }

        // Phase 2: Pulse rings appear (0.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) {
                showPulseRings = true
            }
        }

        // Phase 3: Text slides up (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }

        // Phase 4: Tagline fades in (0.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.4)) {
                taglineOpacity = 1.0
            }
        }

        // Phase 5: Shimmer sweep across title (0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 200
            }
        }

        // Phase 6: Health tip appears (0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeIn(duration: 0.4)) {
                tipOpacity = 1.0
            }
        }

        // Phase 7: Loading indicator (1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                showLoading = true
            }
        }
    }
}

// MARK: - Pulse Rings

private struct PulseRingsView: View {
    @State private var ring1Scale: CGFloat = 0.6
    @State private var ring2Scale: CGFloat = 0.6
    @State private var ring3Scale: CGFloat = 0.6
    @State private var ring1Opacity: Double = 0.4
    @State private var ring2Opacity: Double = 0.3
    @State private var ring3Opacity: Double = 0.2

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "2E3192").opacity(ring1Opacity), lineWidth: 1.5)
                .scaleEffect(ring1Scale)
            Circle()
                .stroke(Color(hex: "4A90E2").opacity(ring2Opacity), lineWidth: 1)
                .scaleEffect(ring2Scale)
            Circle()
                .stroke(Color(hex: "1BFFFF").opacity(ring3Opacity), lineWidth: 0.5)
                .scaleEffect(ring3Scale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                ring1Scale = 1.8
                ring1Opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    ring2Scale = 1.6
                    ring2Opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    ring3Scale = 1.4
                    ring3Opacity = 0
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
