//
//  DesignSystem.swift
//  swastricare-mobile-swift
//
//  Created by SwastriCare Premium on 06/01/26.
//

import SwiftUI
import UIKit

// MARK: - Premium Colors

struct PremiumColor {
    // Primary Gradients
    static let royalBlue = LinearGradient(colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sunset = LinearGradient(colors: [Color(hex: "FF512F"), Color(hex: "DD2476")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let neonGreen = LinearGradient(colors: [Color(hex: "11998e"), Color(hex: "38ef7d")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let deepPurple = LinearGradient(colors: [Color(hex: "654ea3"), Color(hex: "eaafc8")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let midnight = LinearGradient(colors: [Color(hex: "232526"), Color(hex: "414345")], startPoint: .top, endPoint: .bottom)
    
    // Hex Helper
    static func hex(_ hex: String) -> Color {
        return Color(hex: hex)
    }
}

// MARK: - Glassmorphism

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: CGFloat = 0.1
    var shadowRadius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    Color.white.opacity(opacity)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 5)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Premium Background

struct PremiumBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base Color
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            // Animated Orbs
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 350, height: 350)
                .blur(radius: 80)
                .offset(x: animate ? -100 : 100, y: animate ? -150 : -50)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
            
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: animate ? 150 : -50, y: animate ? 200 : 300)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)
            
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: animate ? -100 : 150, y: animate ? 100 : -200)
                .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate)
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Hero Header

struct HeroHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let subtitle = subtitle {
                    Text(subtitle.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundStyle(PremiumColor.deepPurple)
                }
                
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Spacer()
            
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(PremiumColor.royalBlue)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Material.ultraThin)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - Helper Components

// Color hex extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Ensure Color hex extension is available globally if not already
extension Color {
    static var theme: PremiumColor.Type { PremiumColor.self }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
